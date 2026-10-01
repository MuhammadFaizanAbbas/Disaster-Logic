(() => {
  const storageKey = 'disaster-logic-theme';
  let theme = 'light';

  function apply(value, persist = false) {
    theme = value === 'dark' ? 'dark' : 'light';
    document.documentElement.dataset.theme = theme;
    document.querySelector('meta[name="theme-color"]')?.setAttribute('content', theme === 'dark' ? '#101927' : '#1d3046');
    document.querySelectorAll('[data-action="theme"]').forEach(button => {
      button.setAttribute('aria-checked', String(theme === 'dark'));
    });
    if (persist) {
      try { localStorage.setItem(storageKey, theme); } catch { /* Private browsing can restrict storage. */ }
    }
  }

  try { theme = localStorage.getItem(storageKey) === 'dark' ? 'dark' : 'light'; } catch { /* Keep the default. */ }
  apply(theme);
  window.AdminTheme = Object.freeze({
    current: () => theme,
    toggle: () => apply(theme === 'dark' ? 'light' : 'dark', true)
  });
  window.addEventListener('storage', event => {
    if (event.key === storageKey || event.key === null) apply(event.newValue);
  });
})();
