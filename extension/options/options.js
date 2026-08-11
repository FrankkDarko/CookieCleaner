const api = globalThis.browser ?? globalThis.chrome;

/* ---------- presets: sensitive sites + official session-revocation pages ---------- */

const PRESETS = [
  { id: "discord",   label: "Discord",    domains: ["discord.com"], revoke: "https://discord.com/channels/@me" },
  { id: "google",    label: "Google / Gmail", domains: ["google.com", "google.fr", "gmail.com", "youtube.com"], revoke: "https://myaccount.google.com/device-activity" },
  { id: "microsoft", label: "Microsoft / Outlook", domains: ["live.com", "microsoft.com", "outlook.com", "microsoftonline.com"], revoke: "https://account.microsoft.com/devices" },
  { id: "steam",     label: "Steam",      domains: ["steampowered.com", "steamcommunity.com"], revoke: "https://store.steampowered.com/account/authorizeddevices" },
  { id: "paypal",    label: "PayPal",     domains: ["paypal.com"], revoke: "https://www.paypal.com/myaccount/security" },
  { id: "facebook",  label: "Facebook",   domains: ["facebook.com", "messenger.com"], revoke: "https://accountscenter.facebook.com/password_and_security" },
  { id: "instagram", label: "Instagram",  domains: ["instagram.com"], revoke: "https://accountscenter.instagram.com/password_and_security" },
  { id: "x",         label: "X / Twitter", domains: ["x.com", "twitter.com"], revoke: "https://x.com/settings/sessions" },
  { id: "tiktok",    label: "TikTok",     domains: ["tiktok.com"], revoke: null },
  { id: "amazon",    label: "Amazon",     domains: ["amazon.fr", "amazon.com"], revoke: null },
  { id: "netflix",   label: "Netflix",    domains: ["netflix.com"], revoke: "https://www.netflix.com/ManageDevices" },
  { id: "reddit",    label: "Reddit",     domains: ["reddit.com"], revoke: null },
  { id: "twitch",    label: "Twitch",     domains: ["twitch.tv"], revoke: "https://www.twitch.tv/settings/security" },
  { id: "github",    label: "GitHub",     domains: ["github.com"], revoke: "https://github.com/settings/sessions" },
  { id: "linkedin",  label: "LinkedIn",   domains: ["linkedin.com"], revoke: null }
];

const DEFAULTS = {
  mode: "list", sites: [], whitelist: [],
  intervalMinutes: 360, cleanOnStartup: false, cleanStorage: true,
  journal: [], hibpKey: "", lang: "auto"
};

let cfg = { ...DEFAULTS };

function normalizeDomain(input) {
  return String(input).trim().toLowerCase()
    .replace(/^https?:\/\//, "").replace(/\/.*$/, "")
    .replace(/^\.+/, "").replace(/^www\./, "");
}

async function save(partial) {
  Object.assign(cfg, partial);
  await api.storage.local.set(partial);
  if ("intervalMinutes" in partial) {
    await api.runtime.sendMessage({ cmd: "reschedule" });
  }
}

/* ---------- chips rendering ---------- */

function renderChips(containerId, list, storageKey) {
  const el = document.getElementById(containerId);
  el.innerHTML = "";
  for (const site of list) {
    const chip = document.createElement("span");
    chip.className = "chip";
    chip.textContent = site;
    const x = document.createElement("span");
    x.className = "x";
    x.textContent = "×";
    x.title = t("optRemove") || "Remove";
    x.addEventListener("click", async () => {
      await save({ [storageKey]: cfg[storageKey].filter((s) => s !== site) });
      render();
    });
    chip.appendChild(x);
    el.appendChild(chip);
  }
}

function renderPresets() {
  const el = document.getElementById("presetChips");
  el.innerHTML = "";
  for (const p of PRESETS) {
    const active = p.domains.every((d) => cfg.sites.includes(d));
    const btn = document.createElement("button");
    btn.className = "preset" + (active ? " active" : "");
    btn.textContent = (active ? "✓ " : "+ ") + p.label;
    btn.addEventListener("click", async () => {
      const sites = active
        ? cfg.sites.filter((s) => !p.domains.includes(s))
        : [...new Set([...cfg.sites, ...p.domains])];
      await save({ sites });
      render();
    });
    el.appendChild(btn);
  }
}

function renderRevokeLinks() {
  const el = document.getElementById("revokeLinks");
  el.innerHTML = "";
  const relevant = PRESETS.filter(
    (p) => p.revoke && p.domains.some((d) => cfg.sites.includes(d))
  );
  if (!relevant.length) {
    const hint = document.createElement("span");
    hint.className = "muted";
    hint.textContent = t("optRevokeNone") || "Add sites above to see their revocation pages.";
    el.appendChild(hint);
    return;
  }
  for (const p of relevant) {
    const a = document.createElement("a");
    a.className = "chip";
    a.href = p.revoke;
    a.target = "_blank";
    a.rel = "noopener";
    a.textContent = "↗ " + p.label;
    a.style.textDecoration = "none";
    el.appendChild(a);
  }
}

function renderJournal() {
  const list = document.getElementById("journalList");
  const empty = document.getElementById("journalEmpty");
  list.innerHTML = "";
  empty.style.display = cfg.journal.length ? "none" : "block";
  for (const e of cfg.journal) {
    const li = document.createElement("li");
    const when = new Date(e.ts).toLocaleString();
    const triggerLabel = t("optTrigger_" + e.trigger) || e.trigger;
    const left = document.createElement("span");
    left.textContent = `${when} · ${triggerLabel}`;
    const right = document.createElement("span");
    right.className = "muted";
    right.textContent = `${e.cookies} cookies · ${e.hosts} ${t("optHosts") || "sites"}`;
    li.append(left, right);
    list.appendChild(li);
  }
}

function render() {
  document.getElementById("langSelect").value = cfg.lang;
  document.querySelector(`input[name="mode"][value="${cfg.mode}"]`).checked = true;
  document.getElementById("sitesCard").style.display = cfg.mode === "list" ? "" : "none";
  document.getElementById("whitelistCard").style.display = cfg.mode === "all" ? "" : "none";
  document.getElementById("interval").value = String(cfg.intervalMinutes);
  document.getElementById("cleanOnStartup").checked = cfg.cleanOnStartup;
  document.getElementById("cleanStorage").checked = cfg.cleanStorage;
  document.getElementById("hibpKey").value = cfg.hibpKey;
  renderChips("siteChips", cfg.sites, "sites");
  renderChips("whitelistChips", cfg.whitelist, "whitelist");
  renderPresets();
  renderRevokeLinks();
  renderJournal();
}

/* ---------- list add handlers ---------- */

function bindAdd(inputId, buttonId, storageKey) {
  const input = document.getElementById(inputId);
  const add = async () => {
    const domain = normalizeDomain(input.value);
    if (!domain || !domain.includes(".")) return;
    if (!cfg[storageKey].includes(domain)) {
      await save({ [storageKey]: [...cfg[storageKey], domain] });
    }
    input.value = "";
    render();
  };
  document.getElementById(buttonId).addEventListener("click", add);
  input.addEventListener("keydown", (e) => { if (e.key === "Enter") add(); });
}

bindAdd("siteInput", "addSite", "sites");
bindAdd("whitelistInput", "addWhitelist", "whitelist");

/* ---------- settings handlers ---------- */

document.getElementById("langSelect").addEventListener("change", async (e) => {
  await save({ lang: e.target.value });
  location.reload();
});
document.querySelectorAll('input[name="mode"]').forEach((r) =>
  r.addEventListener("change", async () => {
    await save({ mode: r.value });
    render();
  })
);
document.getElementById("interval").addEventListener("change", (e) =>
  save({ intervalMinutes: Number(e.target.value) })
);
document.getElementById("cleanOnStartup").addEventListener("change", (e) =>
  save({ cleanOnStartup: e.target.checked })
);
document.getElementById("cleanStorage").addEventListener("change", (e) =>
  save({ cleanStorage: e.target.checked })
);

/* ---------- HIBP: email check ---------- */

document.getElementById("checkEmail").addEventListener("click", async () => {
  const email = document.getElementById("leakEmail").value.trim();
  const out = document.getElementById("leakResult");
  out.className = "";
  out.textContent = "";
  if (!email || !email.includes("@")) return;

  if (!cfg.hibpKey) {
    // No API key: open the HIBP website instead (free path).
    api.tabs.create({ url: "https://haveibeenpwned.com/account/" + encodeURIComponent(email) });
    return;
  }

  out.textContent = "…";
  try {
    const res = await fetch(
      "https://haveibeenpwned.com/api/v3/breachedaccount/" +
        encodeURIComponent(email) + "?truncateResponse=false",
      { headers: { "hibp-api-key": cfg.hibpKey } }
    );
    if (res.status === 404) {
      out.className = "ok";
      out.textContent = "✓ " + (t("optLeakNone") || "No known breach for this address.");
    } else if (res.status === 200) {
      const breaches = await res.json();
      const names = breaches.slice(0, 10).map((b) => `${b.Name} (${b.BreachDate})`).join(", ");
      out.className = "warn";
      out.textContent = `⚠ ${breaches.length} ${t("optLeakFound") || "breach(es) found:"} ${names}${breaches.length > 10 ? "…" : ""}`;
    } else if (res.status === 401) {
      out.className = "warn";
      out.textContent = t("optApiBadKey") || "Invalid API key.";
    } else if (res.status === 429) {
      out.className = "warn";
      out.textContent = t("optApiRate") || "Rate limited — wait a few seconds.";
    } else {
      out.className = "warn";
      out.textContent = `HTTP ${res.status}`;
    }
  } catch {
    out.className = "warn";
    out.textContent = t("optNetError") || "Network error.";
  }
});

/* ---------- HIBP: anonymous password check (k-anonymity) ---------- */

document.getElementById("checkPwd").addEventListener("click", async () => {
  const pwd = document.getElementById("leakPwd").value;
  const out = document.getElementById("pwdResult");
  out.className = "";
  if (!pwd) return;
  out.textContent = "…";
  try {
    const data = new TextEncoder().encode(pwd);
    const digest = await crypto.subtle.digest("SHA-1", data);
    const hash = [...new Uint8Array(digest)]
      .map((b) => b.toString(16).padStart(2, "0")).join("").toUpperCase();
    const prefix = hash.slice(0, 5);
    const suffix = hash.slice(5);
    const res = await fetch("https://api.pwnedpasswords.com/range/" + prefix, {
      headers: { "Add-Padding": "true" }
    });
    const body = await res.text();
    const line = body.split("\n").find((l) => l.startsWith(suffix));
    const count = line ? parseInt(line.split(":")[1], 10) : 0;
    if (count > 0) {
      out.className = "warn";
      out.textContent = `⚠ ${t("optPwdFound") || "This password appears in"} ${count.toLocaleString()} ${t("optPwdFoundEnd") || "known breaches. Do not use it."}`;
    } else {
      out.className = "ok";
      out.textContent = "✓ " + (t("optPwdNotFound") || "Not found in known breaches.");
    }
  } catch {
    out.className = "warn";
    out.textContent = t("optNetError") || "Network error.";
  }
  document.getElementById("leakPwd").value = "";
});

/* ---------- API key ---------- */

document.getElementById("saveKey").addEventListener("click", async () => {
  const key = document.getElementById("hibpKey").value.trim();
  await save({ hibpKey: key });
  const out = document.getElementById("apiResult");
  out.className = "ok";
  out.textContent = "✓ " + (t("optSaved") || "Saved.");
  setTimeout(() => (out.textContent = ""), 2000);
});

/* ---------- journal ---------- */

document.getElementById("clearJournal").addEventListener("click", async () => {
  await save({ journal: [] });
  render();
});

/* ---------- init ---------- */

(async () => {
  await i18nReady;
  cfg = await api.storage.local.get(DEFAULTS);
  render();
})();

// Live-refresh the journal if a cleanup happens while the page is open.
api.storage.onChanged.addListener((changes, area) => {
  if (area === "local" && changes.journal) {
    cfg.journal = changes.journal.newValue ?? [];
    renderJournal();
  }
});
