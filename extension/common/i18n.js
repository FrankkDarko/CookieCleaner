/* Applies _locales messages to any element tagged with data-i18n / data-i18n-placeholder. */
(() => {
  const api = globalThis.browser ?? globalThis.chrome;
  const t = (key) => api.i18n.getMessage(key);

  document.querySelectorAll("[data-i18n]").forEach((el) => {
    const msg = t(el.dataset.i18n);
    if (msg) el.textContent = msg;
  });
  document.querySelectorAll("[data-i18n-placeholder]").forEach((el) => {
    const msg = t(el.dataset.i18nPlaceholder);
    if (msg) el.placeholder = msg;
  });

  globalThis.t = t;
})();
