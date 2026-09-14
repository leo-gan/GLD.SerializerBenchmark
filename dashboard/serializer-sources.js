/**
 * Source-repo links for every registered serializer.
 *
 * Data: public/data/serializer-sources.json (authored by
 * dashboard/scripts/write-serializer-sources.py from
 * config/serializer-sources.json).
 *
 * Use serializerNameHtml() anywhere a serializer name is shown as HTML
 * so the visible name is a link to the library source.
 */

const DATA_URL = 'data/serializer-sources.json';

/** @type {Record<string, Record<string, { source_url: string, version?: string, specifics?: string }>>} */
let languages = {};
let loadPromise = null;

export function loadSerializerSources() {
  if (!loadPromise) {
    loadPromise = fetch(DATA_URL)
      .then((res) => (res.ok ? res.json() : { languages: {} }))
      .then((data) => {
        languages =
          data && typeof data.languages === 'object' && data.languages
            ? data.languages
            : {};
      })
      .catch(() => {
        languages = {};
      });
  }
  return loadPromise;
}

/** Install a pre-parsed catalog (tests). */
export function setSerializerSources(data) {
  languages =
    data && typeof data.languages === 'object' && data.languages
      ? data.languages
      : {};
}

export function serializerSourceUrl(language, name) {
  if (!language || name == null || name === '') return '';
  const entry = languages[String(language)]?.[String(name)];
  const url = entry && entry.source_url;
  return typeof url === 'string' ? url : '';
}

/** Last measured SerializerVersion from the catalog, or ''. */
export function serializerVersion(language, name) {
  if (!language || name == null || name === '') return '';
  const entry = languages[String(language)]?.[String(name)];
  const ver = entry && entry.version;
  return typeof ver === 'string' ? ver : '';
}

export function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

/**
 * HTML for a serializer name. When a source URL is known the name is an
 * external link; otherwise it is escaped text.
 *
 * @param {string} language dashboard language id (python, csharp, …)
 * @param {string} name CSV / log SerializerName
 * @param {string} [displayText] visible text (e.g. name:version)
 * @param {{ strong?: boolean, className?: string }} [opts]
 */
export function serializerNameHtml(language, name, displayText, opts = {}) {
  const text = displayText == null || displayText === '' ? String(name ?? '') : String(displayText);
  if (!text) return '—';
  const inner = opts.strong ? `<strong>${escapeHtml(text)}</strong>` : escapeHtml(text);
  const url = serializerSourceUrl(language, name);
  if (!url) return inner;
  const cls = opts.className ? `serializer-link ${opts.className}` : 'serializer-link';
  return `<a class="${cls}" href="${escapeHtml(url)}" target="_blank" rel="noopener noreferrer">${inner}</a>`;
}

/** Wrap an existing DOM text node / element content with a source link. */
export function linkSerializerElement(el, language, name) {
  if (!el) return;
  const url = serializerSourceUrl(language, name);
  if (!url) return;
  if (el.tagName === 'A') {
    el.href = url;
    el.target = '_blank';
    el.rel = 'noopener noreferrer';
    el.classList.add('serializer-link');
    return;
  }
  const a = document.createElement('a');
  a.className = 'serializer-link';
  a.href = url;
  a.target = '_blank';
  a.rel = 'noopener noreferrer';
  while (el.firstChild) a.appendChild(el.firstChild);
  el.appendChild(a);
}
