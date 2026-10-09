import React from 'react';

/*
 * Theme controller.
 *
 * Light is the product default: branch staff work under overhead fluorescents
 * and customers check balances in daylight. Dark is a real peer theme, not an
 * inversion, and it exists because the manager and auditor consoles get long
 * evening sessions.
 *
 * Three states, not two. 'system' is the default so the app respects the OS
 * until the user makes an explicit choice, and a stored choice then wins.
 */

const STORAGE_KEY = 'aurabank.theme';
const ThemeContext = React.createContext(null);

const THEME_VERSION_KEY = 'aurabank.theme_v3';
const read = () => {
  try {
    const migrated = localStorage.getItem(THEME_VERSION_KEY);
    if (!migrated) {
      localStorage.setItem(THEME_VERSION_KEY, '1');
      localStorage.setItem(STORAGE_KEY, 'light');
      return 'light';
    }
    const saved = localStorage.getItem(STORAGE_KEY);
    return saved === 'dark' ? 'dark' : 'light';
  } catch {
    return 'light';
  }
};

const systemPrefersDark = () =>
  typeof window !== 'undefined' &&
  window.matchMedia?.('(prefers-color-scheme: dark)').matches;

export function ThemeProvider({ children }) {
  const [preference, setPreference] = React.useState(read);

  // The attribute lives on <html>, so the token block in index.css switches
  // once for the whole document. No section can opt out of the active theme.
  const resolved = preference === 'system' ? (systemPrefersDark() ? 'dark' : 'light') : preference;

  React.useEffect(() => {
    document.documentElement.dataset.theme = resolved;
    document.documentElement.style.colorScheme = resolved;
    if (resolved === 'dark') {
      document.documentElement.classList.add('dark');
    } else {
      document.documentElement.classList.remove('dark');
    }
  }, [resolved]);

  // Track OS changes while the preference is still 'system'.
  React.useEffect(() => {
    if (preference !== 'system') return;
    const query = window.matchMedia('(prefers-color-scheme: dark)');
    const onChange = () => setPreference('system');
    query.addEventListener('change', onChange);
    return () => query.removeEventListener('change', onChange);
  }, [preference]);

  const update = React.useCallback((next) => {
    setPreference(next);
    try {
      localStorage.setItem(STORAGE_KEY, next);
    } catch {
      /* Private browsing: the theme simply does not persist. */
    }
  }, []);

  const value = React.useMemo(
    () => ({ preference, resolved, setTheme: update }),
    [preference, resolved, update]
  );

  return <ThemeContext.Provider value={value}>{children}</ThemeContext.Provider>;
}

export function useTheme() {
  const context = React.useContext(ThemeContext);
  if (!context) throw new Error('useTheme must be used within a ThemeProvider');
  return context;
}
