/*
 * Custom i18n loader: the native chrome.i18n system always follows the browser
 * UI language, so to support a manual language choice we load the _locales
 * JSON files ourselves. Native chrome.i18n stays as fallback (and still handles
 * the store-facing extension description).
 *
 * Exposes: t(key) and the promise i18nReady (resolves once the DOM is translated).
 */
(() => {
  const api = globalThis.browser ?? globalThis.chrome;
  const SUPPORTED = ["en", "fr", "es", "de", "it"];
  let messages = {};

  globalThis.t = (key) => messages[key]?.message ?? api.i18n.getMessage(key) ?? "";

  function apply() {
    document.querySelectorAll("[data-i18n]").forEach((el) => {
      const msg = t(el.dataset.i18n);
      if (msg) el.textContent = msg;
    });
    document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
      const msg = t(el.dataset.i18nPlaceholder);
      if (msg) el.placeholder = msg;
    });
  }

  async function load() {
    const { lang } = await api.storage.local.get({ lang: "auto" });
    let locale = lang;
    if (!SUPPORTED.includes(locale)) {
      const ui = (api.i18n.getUILanguage() || "en").toLowerCase().split("-")[0];
      locale = SUPPORTED.includes(ui) ? ui : "en";
    }
    try {
      const res = await fetch(api.runtime.getURL(`_locales/${locale}/messages.json`));
      messages = await res.json();
    } catch {
      messages = {};
    }
    apply();
  }

  globalThis.i18nReady = load();
})();
