const api = globalThis.browser ?? globalThis.chrome;

function fmtTime(ts) {
  if (!ts) return t("popupNever") || "Never";
  const d = new Date(ts);
  const today = new Date().toDateString() === d.toDateString();
  return today
    ? d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" })
    : d.toLocaleDateString(undefined, { day: "2-digit", month: "2-digit" }) +
      " " + d.toLocaleTimeString(undefined, { hour: "2-digit", minute: "2-digit" });
}

async function refresh() {
  const cfg = await api.storage.local.get({
    mode: "list", sites: [], whitelist: [], lastClean: null
  });

  document.getElementById("lastClean").textContent = fmtTime(cfg.lastClean?.ts);
  document.getElementById("lastCount").textContent =
    cfg.lastClean ? String(cfg.lastClean.cookies) : "—";
  document.getElementById("siteCount").textContent =
    cfg.mode === "all" ? (t("popupAllSites") || "All") : String(cfg.sites.length);

  try {
    const alarm = await api.alarms.get("cookiecleaner-periodic");
    document.getElementById("nextClean").textContent =
      alarm ? fmtTime(alarm.scheduledTime) : "—";
  } catch {
    document.getElementById("nextClean").textContent = "—";
  }
}

document.getElementById("cleanNow").addEventListener("click", async () => {
  const btn = document.getElementById("cleanNow");
  const result = document.getElementById("result");
  btn.disabled = true;
  result.textContent = "…";
  try {
    const entry = await api.runtime.sendMessage({ cmd: "cleanNow" });
    result.className = "ok";
    result.textContent = `✓ ${entry.cookies} ${t("popupCookiesRemoved") || "cookies removed"}`;
  } catch {
    result.className = "warn";
    result.textContent = t("popupError") || "Error";
  }
  btn.disabled = false;
  refresh();
});

document.getElementById("openOptions").addEventListener("click", (e) => {
  e.preventDefault();
  api.runtime.openOptionsPage();
});

i18nReady.then(refresh);
