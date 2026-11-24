/**
 * Dashboard light/dark theme manager synced with the MkDocs Material docs site.
 *
 * MkDocs Material stores its active palette at `<site-root>.__palette` in
 * localStorage (see mkdocs.yml: index 0 = default/light, index 1 = slate/dark).
 * Reading and writing the same key keeps Docs and Dashboard in sync across
 * navigation and open tabs.
 */

const PALETTE_KEY_SUFFIX = '.__palette';

/** @type {Set<(theme: 'light' | 'dark') => void>} */
const listeners = new Set();
let initialized = false;

/**
 * Derive the MkDocs site-root pathname from a Dashboard URL pathname.
 * Examples:
 * - '/GLD.SerializerBenchmark/dashboard/' -> '/GLD.SerializerBenchmark/'
 * - '/GLD.SerializerBenchmark/dashboard/index.html' -> '/GLD.SerializerBenchmark/'
 * - '/dashboard/' -> '/'
 * - '/' (Vite dev server) -> '/'
 */
export function siteRootPathname(pathname = '/') {
  const clean = String(pathname || '/').replace(/\/index\.html$/i, '/');
  const dashMatch = clean.match(/^(.*)\/dashboard\/?$/);
  const root = dashMatch
    ? `${dashMatch[1]}/`
    : clean.endsWith('/')
      ? clean
      : clean.slice(0, clean.lastIndexOf('/') + 1);
  return root.startsWith('/') ? root : `/${root}`;
}

export function paletteStorageKey(pathname = '/') {
  return `${siteRootPathname(pathname)}${PALETTE_KEY_SUFFIX}`;
}

/** @returns {'light' | 'dark'} */
export function themeFromPalette(palette) {
  if (!palette || typeof palette !== 'object') return 'light';
  const scheme = palette.color?.scheme;
  if (scheme === 'slate') return 'dark';
  if (scheme === 'default') return 'light';
  return palette.index === 1 ? 'dark' : 'light';
}

/** Build the exact palette object MkDocs Material expects (see mkdocs.yml). */
export function paletteForTheme(theme) {
  const dark = theme === 'dark';
  return {
    index: dark ? 1 : 0,
    color: {
      media: '',
      scheme: dark ? 'slate' : 'default',
      primary: 'indigo',
      accent: 'deep-purple',
    },
  };
}

function currentPathname(pathname) {
  if (pathname != null) return pathname;
  return typeof window !== 'undefined' ? window.location.pathname : '/';
}

/** @returns {'light' | 'dark'} */
export function readStoredTheme(storage = globalThis.localStorage, pathname) {
  if (!storage) return 'light';
  try {
    const raw = storage.getItem(paletteStorageKey(currentPathname(pathname)));
    if (!raw) return 'light';
    return themeFromPalette(JSON.parse(raw));
  } catch (_) {
    return 'light';
  }
}

export function writeStoredTheme(theme, storage = globalThis.localStorage, pathname) {
  if (!storage) return;
  try {
    storage.setItem(
      paletteStorageKey(currentPathname(pathname)),
      JSON.stringify(paletteForTheme(theme))
    );
  } catch (_) {
    /* private mode or quota */
  }
}

/** @returns {'light' | 'dark'} */
export function getTheme() {
  if (typeof document === 'undefined') return 'light';
  return document.documentElement?.dataset?.theme === 'dark' ? 'dark' : 'light';
}

export function isDarkTheme() {
  return getTheme() === 'dark';
}

function syncToggleButton(theme) {
  if (typeof document === 'undefined') return;
  const btn = document.getElementById('theme-toggle');
  if (!btn) return;
  const dark = theme === 'dark';
  const label = dark ? 'Switch to light mode' : 'Switch to dark mode';
  btn.setAttribute('aria-label', label);
  btn.setAttribute('title', label);
  btn.setAttribute('aria-pressed', dark ? 'true' : 'false');
  const textEl = btn.querySelector('.theme-toggle-label');
  if (textEl) textEl.textContent = dark ? 'Light mode' : 'Dark mode';
}

/** @param {'light' | 'dark'} theme */
export function applyTheme(theme, { persist = false, notify = true } = {}) {
  const next = theme === 'dark' ? 'dark' : 'light';
  const prev = getTheme();
  if (typeof document !== 'undefined' && document.documentElement) {
    document.documentElement.dataset.theme = next;
  }
  syncToggleButton(next);
  if (persist) writeStoredTheme(next);
  if (notify && next !== prev) {
    for (const fn of listeners) {
      try {
        fn(next);
      } catch (err) {
        console.warn('theme listener error', err);
      }
    }
  }
  return next;
}

export function toggleTheme() {
  return applyTheme(isDarkTheme() ? 'light' : 'dark', { persist: true, notify: true });
}

/** @param {(theme: 'light' | 'dark') => void} fn */
export function onThemeChange(fn) {
  listeners.add(fn);
  return () => listeners.delete(fn);
}

/** Initialize theme state, header button listener, and cross-tab sync. */
export function initTheme() {
  if (initialized) {
    syncToggleButton(getTheme());
    return getTheme();
  }
  initialized = true;
  const initial = readStoredTheme();
  applyTheme(initial, { persist: false, notify: false });

  if (typeof document !== 'undefined') {
    const btn = document.getElementById('theme-toggle');
    btn?.addEventListener('click', () => {
      toggleTheme();
    });
  }

  if (typeof window !== 'undefined') {
    window.addEventListener('storage', (e) => {
      if (e.key !== paletteStorageKey()) return;
      const next = e.newValue ? themeFromPalette(safeParse(e.newValue)) : 'light';
      applyTheme(next, { persist: false, notify: true });
    });
  }
  return initial;
}

function safeParse(raw) {
  try {
    return JSON.parse(raw);
  } catch (_) {
    return null;
  }
}

/** Render a Chart.js instance onto an opaque surface-colored PNG data URL. */
export function exportChartPngWithBg(chart) {
  if (!chart) return null;
  const src = chart.canvas;
  if (!src || typeof document === 'undefined') {
    return chart.toBase64Image('image/png', 1);
  }
  const out = document.createElement('canvas');
  out.width = src.width;
  out.height = src.height;
  const ctx = out.getContext('2d');
  if (!ctx) return chart.toBase64Image('image/png', 1);
  const bg =
    getComputedStyle(document.documentElement).getPropertyValue('--bg-surface').trim() ||
    (isDarkTheme() ? '#21252f' : '#ffffff');
  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, out.width, out.height);
  ctx.drawImage(src, 0, 0);
  return out.toDataURL('image/png', 1);
}
