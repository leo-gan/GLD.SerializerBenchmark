import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import {
  applyTheme,
  getTheme,
  isDarkTheme,
  onThemeChange,
  paletteForTheme,
  paletteStorageKey,
  readStoredTheme,
  siteRootPathname,
  themeFromPalette,
  toggleTheme,
  writeStoredTheme,
} from '../theme.js';

const here = dirname(fileURLToPath(import.meta.url));

function memoryStorage(initial = {}) {
  const map = new Map(Object.entries(initial));
  return {
    getItem: (k) => (map.has(k) ? map.get(k) : null),
    setItem: (k, v) => map.set(k, String(v)),
    dump: () => Object.fromEntries(map.entries()),
  };
}

test('siteRootPathname resolves Dashboard paths to the MkDocs Material root scope', () => {
  assert.equal(siteRootPathname('/GLD.SerializerBenchmark/dashboard/'), '/GLD.SerializerBenchmark/');
  assert.equal(siteRootPathname('/GLD.SerializerBenchmark/dashboard'), '/GLD.SerializerBenchmark/');
  assert.equal(
    siteRootPathname('/GLD.SerializerBenchmark/dashboard/index.html'),
    '/GLD.SerializerBenchmark/'
  );
  assert.equal(siteRootPathname('/dashboard/'), '/');
  assert.equal(siteRootPathname('/dashboard/index.html'), '/');
  assert.equal(siteRootPathname('/'), '/');
  assert.equal(siteRootPathname('/index.html'), '/');
});

test('paletteStorageKey matches MkDocs Material __md_scope + .__palette', () => {
  assert.equal(
    paletteStorageKey('/GLD.SerializerBenchmark/dashboard/'),
    '/GLD.SerializerBenchmark/.__palette'
  );
  assert.equal(paletteStorageKey('/dashboard/'), '/.__palette');
  assert.equal(paletteStorageKey('/'), '/.__palette');
});

test('themeFromPalette decodes MkDocs Material default and slate palettes', () => {
  assert.equal(
    themeFromPalette({
      index: 0,
      color: { media: '', scheme: 'default', primary: 'indigo', accent: 'deep-purple' },
    }),
    'light'
  );
  assert.equal(
    themeFromPalette({
      index: 1,
      color: { media: '', scheme: 'slate', primary: 'indigo', accent: 'deep-purple' },
    }),
    'dark'
  );
  assert.equal(themeFromPalette({ index: 1 }), 'dark');
  assert.equal(themeFromPalette({ index: 0 }), 'light');
  assert.equal(themeFromPalette(null), 'light');
  assert.equal(themeFromPalette({}), 'light');
});

test('paletteForTheme emits the exact mkdocs.yml palette structure', () => {
  assert.deepEqual(paletteForTheme('light'), {
    index: 0,
    color: {
      media: '',
      scheme: 'default',
      primary: 'indigo',
      accent: 'deep-purple',
    },
  });
  assert.deepEqual(paletteForTheme('dark'), {
    index: 1,
    color: {
      media: '',
      scheme: 'slate',
      primary: 'indigo',
      accent: 'deep-purple',
    },
  });
});

test('readStoredTheme and writeStoredTheme round-trip under the shared docs key', () => {
  const storage = memoryStorage();
  const path = '/GLD.SerializerBenchmark/dashboard/';

  assert.equal(readStoredTheme(storage, path), 'light');

  writeStoredTheme('dark', storage, path);
  assert.equal(readStoredTheme(storage, path), 'dark');
  const saved = JSON.parse(storage.getItem('/GLD.SerializerBenchmark/.__palette'));
  assert.equal(saved.index, 1);
  assert.equal(saved.color.scheme, 'slate');

  writeStoredTheme('light', storage, path);
  assert.equal(readStoredTheme(storage, path), 'light');
  const savedLight = JSON.parse(storage.getItem('/GLD.SerializerBenchmark/.__palette'));
  assert.equal(savedLight.index, 0);
  assert.equal(savedLight.color.scheme, 'default');
});

test('readStoredTheme falls back to light on corrupt or throwing storage', () => {
  const corrupt = memoryStorage({ '/.__palette': '{not json' });
  assert.equal(readStoredTheme(corrupt, '/'), 'light');

  const broken = {
    getItem() {
      throw new Error('denied');
    },
    setItem() {
      throw new Error('quota');
    },
  };
  assert.equal(readStoredTheme(broken, '/'), 'light');
  assert.doesNotThrow(() => writeStoredTheme('dark', broken, '/'));
});

test('applyTheme and toggleTheme update document dataset, toggle button, storage, and listeners', () => {
  const prevDoc = globalThis.document;
  const prevWin = globalThis.window;
  const prevStorage = globalThis.localStorage;
  const storage = memoryStorage();
  const attrs = new Map();
  const labelEl = { textContent: 'Dark mode' };
  const btn = {
    setAttribute: (k, v) => attrs.set(k, v),
    getAttribute: (k) => attrs.get(k),
    querySelector: (sel) => (sel === '.theme-toggle-label' ? labelEl : null),
  };
  const rootEl = { dataset: {} };
  globalThis.document = {
    documentElement: rootEl,
    getElementById: (id) => (id === 'theme-toggle' ? btn : null),
  };
  globalThis.window = { location: { pathname: '/GLD.SerializerBenchmark/dashboard/' } };
  globalThis.localStorage = storage;

  const events = [];
  const off = onThemeChange((t) => events.push(t));
  try {
    applyTheme('light', { persist: false, notify: false });
    assert.equal(getTheme(), 'light');
    assert.equal(isDarkTheme(), false);
    assert.equal(attrs.get('aria-label'), 'Switch to dark mode');
    assert.equal(attrs.get('aria-pressed'), 'false');

    toggleTheme();
    assert.equal(getTheme(), 'dark');
    assert.equal(isDarkTheme(), true);
    assert.equal(rootEl.dataset.theme, 'dark');
    assert.equal(attrs.get('aria-label'), 'Switch to light mode');
    assert.equal(attrs.get('aria-pressed'), 'true');
    assert.equal(labelEl.textContent, 'Light mode');
    assert.deepEqual(events, ['dark']);
    assert.equal(
      JSON.parse(storage.getItem('/GLD.SerializerBenchmark/.__palette')).color.scheme,
      'slate'
    );

    toggleTheme();
    assert.equal(getTheme(), 'light');
    assert.deepEqual(events, ['dark', 'light']);
    assert.equal(
      JSON.parse(storage.getItem('/GLD.SerializerBenchmark/.__palette')).color.scheme,
      'default'
    );
  } finally {
    off();
    globalThis.document = prevDoc;
    globalThis.window = prevWin;
    globalThis.localStorage = prevStorage;
  }
});

test('index.html includes the theme toggle button and pre-paint palette bootstrap', () => {
  const html = readFileSync(join(here, '..', 'index.html'), 'utf8');
  assert.match(html, /id="theme-toggle"/);
  assert.match(html, /\.__palette/);
  assert.match(html, /dataset\.theme\s*=\s*'dark'/);
  const css = readFileSync(join(here, '..', 'index.css'), 'utf8');
  assert.match(css, /:root\[data-theme="dark"\]/);
  assert.match(css, /color-scheme:\s*dark/);
});
