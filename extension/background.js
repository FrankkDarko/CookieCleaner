/*
 * CookieCleaner — background script.
 * Runs as a service worker on Chromium and as an event page on Firefox,
 * so no state is kept in memory: everything lives in storage.local.
 */

const api = globalThis.browser ?? globalThis.chrome;
const IS_FIREFOX = typeof globalThis.browser !== "undefined";

const ALARM_PERIODIC = "cookiecleaner-periodic";
const ALARM_BADGE = "cookiecleaner-badge";
const JOURNAL_MAX = 50;

const DEFAULTS = {
  mode: "list",            // "list" = clean chosen sites | "all" = clean everything except whitelist
  sites: [],
  whitelist: [],
  intervalMinutes: 360,
  cleanOnStartup: false,
  cleanStorage: true,      // also purge localStorage / IndexedDB (Discord-style tokens)
  journal: [],
  lastClean: null
};

async function getConfig() {
  return api.storage.local.get(DEFAULTS);
}

/* ---------- domain helpers ---------- */

function normalizeDomain(input) {
  return String(input)
    .trim()
    .toLowerCase()
    .replace(/^https?:\/\//, "")
    .replace(/\/.*$/, "")
    .replace(/^\.+/, "")
    .replace(/^www\./, "");
}

function cookieMatchesSite(cookieDomain, site) {
  const host = cookieDomain.replace(/^\./, "").toLowerCase();
  return host === site || host.endsWith("." + site);
}

/* ---------- cookie removal ---------- */

async function getAllCookies() {
  // partitionKey: {} also returns partitioned (CHIPS) cookies on Chromium.
  try {
    return await api.cookies.getAll({ partitionKey: {} });
  } catch {
    return api.cookies.getAll({});
  }
}

async function removeCookie(cookie) {
  const url =
    (cookie.secure ? "https://" : "http://") +
    cookie.domain.replace(/^\./, "") +
    cookie.path;
  const details = { url, name: cookie.name, storeId: cookie.storeId };
  if (cookie.partitionKey) details.partitionKey = cookie.partitionKey;
  try {
    await api.cookies.remove(details);
    return true;
  } catch {
    return false;
  }
}

/* ---------- site storage purge (localStorage / IndexedDB) ---------- */

async function purgeSiteStorage(hostnames, excludedHostnames) {
  if (!hostnames.length && !excludedHostnames) return;
  const dataTypes = { localStorage: true, indexedDB: true };

  try {
    if (IS_FIREFOX) {
      // Firefox scopes removal with `hostnames`.
      await api.browsingData.remove({ hostnames }, dataTypes);
    } else if (excludedHostnames) {
      // "all except" mode on Chromium: purge everything but the whitelist.
      const excludeOrigins = excludedHostnames.flatMap((h) => [
        `https://${h}`, `https://www.${h}`, `http://${h}`, `http://www.${h}`
      ]);
      await api.browsingData.remove({ excludeOrigins }, dataTypes);
    } else {
      const origins = hostnames.flatMap((h) => [`https://${h}`, `http://${h}`]);
      await api.browsingData.remove({ origins }, dataTypes);
    }
  } catch {
    // Some engines reject indexedDB scoping — retry with localStorage only.
    try {
      const scope = IS_FIREFOX ? { hostnames } : { origins: hostnames.map((h) => `https://${h}`) };
      await api.browsingData.remove(scope, { localStorage: true });
    } catch {
      /* storage purge is best-effort */
    }
  }
}

/* ---------- main cleanup ---------- */

async function cleanNow(trigger = "manual") {
  const cfg = await getConfig();
  const all = await getAllCookies();

  let toRemove = [];
  let excludedHostnames = null;

  if (cfg.mode === "all") {
    const keep = cfg.whitelist.map(normalizeDomain).filter(Boolean);
    toRemove = all.filter((c) => !keep.some((s) => cookieMatchesSite(c.domain, s)));
    excludedHostnames = keep;
  } else {
    const sites = cfg.sites.map(normalizeDomain).filter(Boolean);
    toRemove = sites.length
      ? all.filter((c) => sites.some((s) => cookieMatchesSite(c.domain, s)))
      : [];
  }

  let removed = 0;
  const hostnames = new Set();
  for (const cookie of toRemove) {
    if (await removeCookie(cookie)) {
      removed++;
      const host = cookie.domain.replace(/^\./, "");
      hostnames.add(host);
      if (!host.startsWith("www.")) hostnames.add("www." + host);
    }
  }

  // In list mode, always include the configured sites so tokens in
  // localStorage are wiped even when no cookie was present anymore.
  if (cfg.mode === "list") {
    for (const s of cfg.sites.map(normalizeDomain).filter(Boolean)) {
      hostnames.add(s);
      hostnames.add("www." + s);
    }
  }

  if (cfg.cleanStorage) {
    await purgeSiteStorage(
      [...hostnames],
      cfg.mode === "all" && !IS_FIREFOX ? excludedHostnames : null
    );
  }

  const entry = {
    ts: Date.now(),
    trigger,
    mode: cfg.mode,
    cookies: removed,
    hosts: hostnames.size
  };
  const journal = [entry, ...cfg.journal].slice(0, JOURNAL_MAX);
  await api.storage.local.set({ journal, lastClean: entry });

  await showBadge(removed);
  return entry;
}

/* ---------- badge feedback ---------- */

async function showBadge(count) {
  try {
    await api.action.setBadgeBackgroundColor({ color: "#2f9e63" });
    await api.action.setBadgeText({ text: count > 999 ? "999+" : String(count) });
    api.alarms.create(ALARM_BADGE, { when: Date.now() + 60_000 });
  } catch {
    /* badge is cosmetic */
  }
}

/* ---------- scheduling ---------- */

async function reschedule() {
  const cfg = await getConfig();
  await api.alarms.clear(ALARM_PERIODIC);
  if (cfg.intervalMinutes > 0) {
    api.alarms.create(ALARM_PERIODIC, {
      periodInMinutes: cfg.intervalMinutes,
      delayInMinutes: cfg.intervalMinutes
    });
  }
}

/* ---------- events ---------- */

api.runtime.onInstalled.addListener(() => {
  reschedule();
});

api.runtime.onStartup.addListener(async () => {
  const cfg = await getConfig();
  if (cfg.cleanOnStartup) await cleanNow("startup");
  await reschedule();
});

api.alarms.onAlarm.addListener((alarm) => {
  if (alarm.name === ALARM_PERIODIC) cleanNow("auto");
  if (alarm.name === ALARM_BADGE) api.action.setBadgeText({ text: "" });
});

api.runtime.onMessage.addListener((msg, _sender, sendResponse) => {
  if (msg?.cmd === "cleanNow") {
    cleanNow("manual").then(sendResponse);
    return true;
  }
  if (msg?.cmd === "reschedule") {
    reschedule().then(() => sendResponse(true));
    return true;
  }
});
