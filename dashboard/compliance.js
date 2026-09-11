/**
 * Compliance view — spec-quality counterpart to Overview timings.
 *
 * Data: public/data/compliance.json from dashboard/scripts/sync-compliance.py
 * (fed by ./scripts/run-compliance.sh). Results live here, not in MkDocs pages.
 */
import './compliance.css';
import { serializerDisplayName } from './format.js';

const DATA_URL = 'data/compliance.json.gz';
const DATA_URL_PLAIN = 'data/compliance.json';
const ALL_LANG = 'all';
const NO_SPEC = 'no-spec';
const FORMAT_LABELS = {
  json: 'JSON',
  yaml: 'YAML',
  toml: 'TOML',
  cbor: 'CBOR',
  msgpack: 'MessagePack',
  protobuf: 'Protocol Buffers',
  avro: 'Avro',
  bson: 'BSON',
  flatbuffers: 'FlatBuffers',
  ion: 'Amazon Ion',
  ubjson: 'UBJSON',
  smile: 'Smile',
  thrift: 'Thrift',
  capnp: "Cap'n Proto",
  bond: 'Bond',
  bebop: 'Bebop',
  hocon: 'HOCON',
  plist: 'Property List',
  zon: 'ZON',
  [NO_SPEC]: 'No public spec',
};

/** Bench serializers with no citable interchange spec. Names match language Overview tables. */
const NO_SPEC_SERIALIZERS = {
  python: ['pickle', 'cloudpickle', 'dill'],
  javascript: ['v8-serializer', 'devalue', 'sia', 'bser'],
  go: ['encoding/gob', 'kelindar/binary'],
  java: ['java-serialization', 'fory', 'hessian', 'kryo', 'protostuff'],
  kotlin: ['fory', 'kryo', 'protostuff'],
  csharp: [
    'BinaryPack',
    'Ceras',
    'ExtendedXmlSerializer',
    'FsPickler',
    'GroBuf',
    'Hyperion',
    'MemoryPack',
    'Migrant',
    'MS Binary',
    'NetSerializer',
    'ServiceStack',
    'SharpSerializer',
    'ZeroFormatter',
  ],
  rust: ['bincode', 'bitcode', 'nanoserde', 'postcard', 'rkyv', 'speedy'],
  c: ['custom-binary', 'ubj'],
  cpp: ['bitsery', 'boost_serialization', 'cereal', 'cista', 'custom_binary', 'yas', 'zpp_bits'],
  swift: ['BinaryCodable'],
  php: ['serialize', 'igbinary'],
  zig: ['comptime-bin', 's2s'],
};
const LANG_LABELS = {
  csharp: 'C#',
  rust: 'Rust',
  go: 'Go',
  python: 'Python',
  javascript: 'JavaScript',
  c: 'C',
  java: 'Java',
  kotlin: 'Kotlin',
  mojo: 'Mojo',
  php: 'PHP',
  cpp: 'C++',
  swift: 'Swift',
  zig: 'Zig',
};

let payload = null;
let loadError = null;
/** language → { serializer name → version from latest bench stats } */
let benchVersions = null;
let ui = {
  lang: '',
  format: 'json',
  serializer: '',
  panel: null,
};

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function langLabel(id) {
  if (id === ALL_LANG) return 'All';
  return LANG_LABELS[id] || id;
}

function serializerOf(row) {
  return row?.serializer || row?.adapter || '';
}

function serializerLabel(row) {
  const name = serializerOf(row);
  const fromRow = row?.serializer_version == null ? '' : String(row.serializer_version).trim();
  const ver =
    fromRow && fromRow !== 'unknown' && fromRow !== '—'
      ? fromRow
      : benchVersion(String(row?.language || payload?.language || ''), name);
  return serializerDisplayName(name, ver);
}

function benchVersion(language, name) {
  return benchVersions?.[language]?.[name] || '';
}

function noSpecLabel(entry, { withLang = false } = {}) {
  const name = serializerDisplayName(entry.serializer, benchVersion(entry.language, entry.serializer));
  return withLang ? `${langLabel(entry.language)} · ${name}` : name;
}

function formatLabel(id) {
  return FORMAT_LABELS[id] || id;
}

function parseHash() {
  const raw = (window.location.hash || '').replace(/^#/, '');
  return raw === 'compliance' || raw.startsWith('compliance/');
}

function setComplianceView(on) {
  document.body.classList.toggle('dash-view-compliance', on);
  const link = document.getElementById('nav-compliance-link');
  if (link) link.parentElement?.classList.toggle('active', on);
  if (on) {
    document.querySelectorAll('.section-nav li').forEach((li) => {
      if (li.querySelector('#nav-compliance-link')) return;
      li.classList.remove('active');
    });
    window.scrollTo({ top: 0, behavior: 'auto' });
  }
}

async function loadBenchVersions() {
  if (benchVersions) return benchVersions;
  benchVersions = {};
  await Promise.all(
    Object.keys(LANG_LABELS).map(async (lang) => {
      try {
        const doc = await fetchJsonMaybeGzip(`data/stats_${lang}_latest.json.gz`);
        const map = {};
        for (const g of doc.groups || []) {
          const name = g?.serializer;
          const ver = g?.serializer_version;
          if (!name || map[name]) continue;
          if (ver) map[name] = String(ver);
        }
        benchVersions[lang] = map;
      } catch {
        benchVersions[lang] = {};
      }
    }),
  );
  return benchVersions;
}

async function fetchJsonMaybeGzip(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  const buf = await res.arrayBuffer();
  const bytes = new Uint8Array(buf);
  const isGzip = bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b;
  if (!isGzip) return JSON.parse(new TextDecoder().decode(bytes));
  if (typeof DecompressionStream === 'undefined') {
    throw new Error('gzip payload but DecompressionStream is unavailable');
  }
  const ds = new DecompressionStream('gzip');
  const writer = ds.writable.getWriter();
  writer.write(bytes);
  writer.close();
  const text = await new Response(ds.readable).text();
  return JSON.parse(text);
}

async function loadPayload() {
  if (payload || loadError) return;
  try {
    try {
      payload = await fetchJsonMaybeGzip(DATA_URL);
    } catch (err) {
      payload = await fetchJsonMaybeGzip(DATA_URL_PLAIN);
    }
  } catch (err) {
    loadError = err;
  }
}

function unique(rows, keyFn) {
  const seen = [];
  const have = new Set();
  for (const row of rows) {
    const v = typeof keyFn === 'function' ? keyFn(row) : row?.[keyFn];
    if (v == null || v === '') continue;
    const s = String(v);
    if (have.has(s)) continue;
    have.add(s);
    seen.push(s);
  }
  return seen;
}

function rateClass(rate) {
  if (rate == null) return 'cmp-cell-empty';
  if (rate >= 0.999) return 'cmp-cell-ok';
  if (rate >= 0.85) return 'cmp-cell-warn';
  return 'cmp-cell-bad';
}

function pct(rate) {
  if (rate == null) return '—';
  return `${Math.round(rate * 100)}%`;
}

function languageIds() {
  const fromPayload = Array.isArray(payload?.languages) ? payload.languages.map(String) : [];
  const fromRows = unique(payload?.results || [], 'language');
  const fromNoSpec = Object.keys(NO_SPEC_SERIALIZERS);
  const fromSuite = Object.keys(LANG_LABELS);
  const ids = [];
  const have = new Set();
  for (const id of [...fromPayload, ...fromRows, ...fromNoSpec, ...fromSuite]) {
    if (!id || have.has(id)) continue;
    have.add(id);
    ids.push(id);
  }
  return ids.length ? ids : ['python'];
}

function noSpecEntries(lang) {
  if (!lang || lang === ALL_LANG) {
    return Object.entries(NO_SPEC_SERIALIZERS).flatMap(([language, names]) =>
      names.map((serializer) => ({ language, serializer })),
    );
  }
  return (NO_SPEC_SERIALIZERS[lang] || []).map((serializer) => ({ language: lang, serializer }));
}

function noSpecKey(entry) {
  return `${entry.language}|${entry.serializer}`;
}

function rowsForLang() {
  const rows = Array.isArray(payload?.results) ? payload.results : [];
  if (!ui.lang || ui.lang === ALL_LANG) return rows;
  return rows.filter((row) => String(row.language || payload.language || 'python') === ui.lang);
}

function matrixForLang() {
  const matrix = Array.isArray(payload?.matrix) ? payload.matrix : [];
  if (!ui.lang || ui.lang === ALL_LANG) return matrix;
  return matrix.filter((cell) => String(cell.language || payload.language || 'python') === ui.lang);
}

function selectHtml(id, label, values, current, labelFn) {
  const opts = ['<option value="">All</option>']
    .concat(
      values.map((v) => {
        const sel = v === current ? ' selected' : '';
        const text = labelFn ? labelFn(v) : v;
        return `<option value="${escapeHtml(v)}"${sel}>${escapeHtml(text)}</option>`;
      }),
    )
    .join('');
  return `<label class="cmp-filter">${escapeHtml(label)}
    <select id="${id}">${opts}</select></label>`;
}

function renderEmpty(root, message) {
  root.innerHTML = `
    <div class="cmp-header">
      <h2 class="chart-title">Compliance</h2>
      <p class="section-help">${message}</p>
    </div>`;
}

function quoteSource(row) {
  const raw = row.input == null ? '' : String(row.input);
  if (row.input_encoding === 'hex') return `hex ${raw}`;
  return JSON.stringify(raw);
}

function failureText(row) {
  const expect = row.expect;
  const observed = row.observed || row.detail || '';
  if (expect === 'reject' && row.outcome === 'fail') {
    return `The serializer accepted this input. The spec requires a reject (${row.requirement || 'MUST NOT'}).`;
  }
  if (expect === 'accept' && row.outcome === 'fail') {
    if (/Error|error/.test(observed)) {
      return `The serializer rejected this input. The spec requires accept (${row.requirement || 'MUST'}).`;
    }
    return `Decoded value does not match the catalog. ${observed}`;
  }
  return row.detail || observed || 'Did not match the cited rule.';
}

function specHtml(row) {
  const label = [row.section, row.section_title].filter(Boolean).join(' — ') || 'Spec';
  if (!row.section_url) return escapeHtml(label);
  return `<a href="${escapeHtml(row.section_url)}" target="_blank" rel="noopener noreferrer">${escapeHtml(label)}</a>`;
}

function documentUrl(url) {
  const raw = String(url || '').trim();
  if (!raw.startsWith('http')) return '';
  const hash = raw.indexOf('#');
  return hash === -1 ? raw : raw.slice(0, hash);
}

function columnSpecUrl(column, rows) {
  if (column.standard_url && String(column.standard_url).startsWith('http')) {
    return String(column.standard_url);
  }
  const forCol = rows.filter((row) => String(row.standard) === column.key);
  const suiteUrl = forCol.find((row) => String(row.standard_url || '').startsWith('http'));
  if (suiteUrl) return String(suiteUrl.standard_url);
  const sectionUrl = forCol.find((row) => String(row.section_url || '').startsWith('http'));
  return documentUrl(sectionUrl?.section_url);
}

function columnTitleHtml(column, rows) {
  const label = escapeHtml(column.standard);
  const href = columnSpecUrl(column, rows);
  if (!href) return label;
  return `<a class="cmp-col-spec" href="${escapeHtml(href)}" target="_blank" rel="noopener noreferrer" title="Open the published standard">${label}</a>`;
}

function renderFailCard(row) {
  return `
    <article class="cmp-fail-card">
      <h4 class="cmp-fail-id">${escapeHtml(row.title || row.id)}</h4>
      <p class="cmp-fail-meta">${escapeHtml(row.id)} · ${escapeHtml(serializerLabel(row))} · ${escapeHtml(row.standard || '')}</p>
      <dl class="cmp-fail-dl">
        <dt>Source</dt>
        <dd><pre>${escapeHtml(quoteSource(row))}</pre></dd>
        <dt>Output</dt>
        <dd><pre>${escapeHtml(row.observed || row.detail || '—')}</pre></dd>
        <dt>Failure</dt>
        <dd>${escapeHtml(failureText(row))}${row.paragraph ? ` <span class="cmp-rule">${escapeHtml(row.paragraph)}</span>` : ''}</dd>
        <dt>Spec</dt>
        <dd>${specHtml(row)}</dd>
      </dl>
    </article>`;
}

function renderNoSpecHeatmap() {
  const entries = noSpecEntries(ui.lang).filter((e) => {
    if (!ui.serializer) return true;
    return ui.serializer === e.serializer || ui.serializer === noSpecKey(e);
  });
  if (!entries.length) {
    return '<p class="section-help">No language-native or private-binary serializers listed for this language.</p>';
  }
  const multiLang = ui.lang === ALL_LANG && languageIds().length > 1;
  const body = entries
    .map((e) => {
      const label = noSpecLabel(e, { withLang: multiLang });
      return `<tr><th scope="row">${escapeHtml(label)}</th></tr>`;
    })
    .join('');
  return `
    <div class="table-container cmp-heat-wrap">
      <table class="data-table cmp-heat cmp-heat-list">
        <thead><tr><th>Serializer</th></tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>`;
}

function renderHeatmap(matrix) {
  if (ui.format === NO_SPEC) return renderNoSpecHeatmap();
  if (!matrix.length) return '<p class="section-help">No matrix cells for this language.</p>';
  const filtered = matrix.filter((c) => {
    if (ui.format && String(c.format) !== ui.format) return false;
    if (ui.serializer && serializerOf(c) !== ui.serializer) return false;
    return true;
  });
  if (!filtered.length) {
    return '<p class="section-help">No results for this standard.</p><div id="cmp-fail-panel" class="cmp-fail-panel" hidden></div>';
  }
  const serializers = unique(filtered, serializerOf);
  const columns = [];
  const colKey = new Set();
  for (const cell of filtered) {
    const key = String(cell.standard || '');
    if (!key || colKey.has(key)) continue;
    colKey.add(key);
    columns.push({
      key,
      standard: cell.standard,
      version: cell.version,
      standard_url: cell.standard_url || '',
    });
  }
  const caseRows = rowsForLang();
  const head = columns.map((c) => `<th>${columnTitleHtml(c, caseRows)}</th>`).join('');
  const multiLang = ui.lang === ALL_LANG && languageIds().length > 1;
  const body = serializers
    .map((ser) => {
      const sample = filtered.find((m) => serializerOf(m) === ser) || {};
      const tds = columns
        .map((col) => {
          const matches = filtered.filter(
            (m) => serializerOf(m) === ser && String(m.standard) === col.key,
          );
          if (!matches.length) return '<td class="cmp-cell-empty">—</td>';
          const passed = matches.reduce((n, c) => n + (c.passed || 0), 0);
          const failed = matches.reduce((n, c) => n + (c.failed || 0), 0);
          const total = matches.reduce((n, c) => n + (c.total || 0), 0);
          const judged = passed + failed;
          const rate = judged ? passed / judged : null;
          return `<td class="${rateClass(rate)}">
            <button type="button" class="cmp-cell-btn" data-cmp-ser="${escapeHtml(ser)}" data-cmp-std="${escapeHtml(col.key)}">
              ${escapeHtml(pct(rate))} / ${passed}/${total}
            </button>
          </td>`;
        })
        .join('');
      let label = serializerLabel(sample);
      if (multiLang) label = `${langLabel(sample.language || '')} · ${label}`;
      return `<tr><th scope="row">${escapeHtml(label)}</th>${tds}</tr>`;
    })
    .join('');
  return `
    <div class="table-container cmp-heat-wrap">
      <table class="data-table cmp-heat">
        <thead><tr><th>Serializer</th>${head}</tr></thead>
        <tbody>${body}</tbody>
      </table>
    </div>
    <div id="cmp-fail-panel" class="cmp-fail-panel" hidden></div>`;
}

function openCellPanel(serializer, standard) {
  const rows = rowsForLang().filter(
    (row) =>
      serializerOf(row) === serializer &&
      String(row.standard) === standard &&
      (!ui.format || String(row.format) === ui.format),
  );
  const fails = rows.filter((row) => row.outcome === 'fail' || row.outcome === 'error');
  const panel = document.getElementById('cmp-fail-panel');
  if (!panel) return;
  ui.panel = { serializer, standard };
  ui.serializer = serializer;
  const sample = rows[0] || {};
  const heading = `${serializerLabel(sample) || serializer} × ${standard}`;
  if (!fails.length) {
    panel.hidden = false;
    panel.innerHTML = `
      <div class="cmp-fail-head">
        <h3>${escapeHtml(heading)}</h3>
        <button type="button" class="tab-btn" id="cmp-fail-close">Close</button>
      </div>
      <p class="section-help">No failures in this cell (${rows.length} case${rows.length === 1 ? '' : 's'} passed or skipped).</p>`;
    document.getElementById('cmp-fail-close')?.addEventListener('click', closeCellPanel);
    panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
    return;
  }
  panel.hidden = false;
  panel.innerHTML = `
    <div class="cmp-fail-head">
      <h3>${escapeHtml(heading)} — ${fails.length} failure${fails.length === 1 ? '' : 's'}</h3>
      <button type="button" class="tab-btn" id="cmp-fail-close">Close</button>
    </div>
    ${fails.map(renderFailCard).join('')}`;
  document.getElementById('cmp-fail-close')?.addEventListener('click', closeCellPanel);
  panel.scrollIntoView({ behavior: 'smooth', block: 'nearest' });
}

function closeCellPanel() {
  ui.panel = null;
  const panel = document.getElementById('cmp-fail-panel');
  if (panel) {
    panel.hidden = true;
    panel.innerHTML = '';
  }
}

function kpisFrom(rows) {
  let passed = 0;
  let failed = 0;
  let skipped = 0;
  let errors = 0;
  for (const row of rows) {
    if (row.outcome === 'pass') passed += 1;
    else if (row.outcome === 'fail') failed += 1;
    else if (row.outcome === 'skip') skipped += 1;
    else errors += 1;
  }
  return { passed, failed, skipped, errors, total: rows.length };
}

function renderLangTabs(tabIds) {
  if (!tabIds.length) return '';
  return `
    <div class="exp-lang-tabs tabs" role="tablist" aria-label="Language">
      ${tabIds
        .map((id) => {
          const active = id === ui.lang ? ' active' : '';
          return `<button type="button" class="tab-btn${active}" data-cmp-lang="${escapeHtml(id)}">${escapeHtml(langLabel(id))}</button>`;
        })
        .join('')}
    </div>`;
}

function renderMain(root) {
  const langIds = languageIds();
  const tabIds = langIds.length ? [...langIds, ALL_LANG] : [ALL_LANG];
  if (!ui.lang || !tabIds.includes(ui.lang)) ui.lang = langIds[0] || ALL_LANG;

  const langRows = rowsForLang();
  const noSpec = ui.format === NO_SPEC;
  const kpis = noSpec ? { passed: 0, failed: 0, skipped: 0, errors: 0, total: 0 } : kpisFrom(langRows);
  const judged = kpis.passed + kpis.failed;
  const rate = judged ? kpis.passed / judged : null;
  // Catalog families, not whatever the last run happened to emit.
  const liveFormats = new Set(unique(langRows, 'format'));
  const formats = Object.keys(FORMAT_LABELS);
  const noSpecList = noSpecEntries(ui.lang);
  const serializers = noSpec
    ? (ui.lang === ALL_LANG ? noSpecList.map(noSpecKey) : noSpecList.map((e) => e.serializer))
    : unique(langRows.filter((r) => !ui.format || r.format === ui.format), serializerOf);
  const matrix = matrixForLang();

  root.innerHTML = `
    <div class="cmp-header">
      <h2 class="chart-title">Compliance</h2>
      <p class="section-help">
        Spec quality for the same serializers the suite benches. Live numbers live here,
        not on the documentation pages.
        <a href="../compliance/">How the catalog is built</a>
      </p>
    </div>
    <p class="cmp-scope">${escapeHtml(payload.scope?.note || '')}</p>
    ${renderLangTabs(tabIds)}
    <p class="cmp-meta">
      ${escapeHtml(ui.lang === ALL_LANG ? 'All languages' : langLabel(ui.lang))}
      ${
        noSpec
          ? ` · ${noSpecList.length} serializer${noSpecList.length === 1 ? '' : 's'} · not scored`
          : ` · ${kpis.passed} pass · ${kpis.failed} fail · ${escapeHtml(pct(rate))} pass rate · ${kpis.total} checks`
      }
      · ${escapeHtml(payload.generated_at || '')}
      · source ${escapeHtml(payload.source || 'compliance.json')}
    </p>
    <div class="cmp-filters">
      ${selectHtml('cmp-filter-standard', 'Standard', formats, ui.format, (id) => {
        const label = formatLabel(id);
        if (id === NO_SPEC || liveFormats.has(id)) return label;
        return `${label} (no live results)`;
      })}
      ${selectHtml('cmp-filter-serializer', 'Serializer', serializers, ui.serializer, (name) => {
        if (noSpec) {
          if (name.includes('|')) {
            const [lang, ser] = name.split('|');
            return noSpecLabel({ language: lang, serializer: ser }, { withLang: true });
          }
          const hit = noSpecList.find((e) => e.serializer === name);
          return hit ? noSpecLabel(hit) : name;
        }
        const sample = langRows.find((r) => serializerOf(r) === name);
        return sample ? serializerLabel(sample) : name;
      })}
    </div>
    <h3 class="cmp-kicker">${noSpec ? 'Serializers with no public interchange spec' : 'Pass rate by serializer × standard version'}</h3>
    <p class="section-help">${
      noSpec
        ? 'These codecs are language-native or library-private. There is no citable MUST / MUST NOT document, so this view is a group list only — no pass/fail cells.'
        : 'Standard is the catalog family (JSON, YAML, Protocol Buffers, …). Columns are that family’s versions. A family with no live rows for this language is listed as empty — run <code>./scripts/run-compliance.sh</code> to fill it. Click a cell to open that serializer’s failures for that version.'
    }</p>
    ${renderHeatmap(matrix)}
  `;

  root.querySelectorAll('[data-cmp-lang]').forEach((btn) => {
    btn.addEventListener('click', () => {
      ui.lang = btn.getAttribute('data-cmp-lang') || '';
      ui.serializer = '';
      ui.panel = null;
      render();
    });
  });
  document.getElementById('cmp-filter-standard')?.addEventListener('change', (e) => {
    ui.format = e.target.value;
    ui.serializer = '';
    ui.panel = null;
    render();
  });
  document.getElementById('cmp-filter-serializer')?.addEventListener('change', (e) => {
    ui.serializer = e.target.value;
    render();
  });
  root.querySelectorAll('.cmp-cell-btn').forEach((btn) => {
    btn.addEventListener('click', () => {
      openCellPanel(btn.getAttribute('data-cmp-ser') || '', btn.getAttribute('data-cmp-std') || '');
    });
  });
}

async function render() {
  const root = document.getElementById('compliance');
  if (!root) return;
  const on = parseHash();
  setComplianceView(on);
  if (!on) return;
  await loadPayload();
  if (loadError) {
    renderEmpty(
      root,
      `No compliance payload yet. From the repo root run <code>./scripts/run-compliance.sh</code>
      (${escapeHtml(loadError.message)}).`,
    );
    return;
  }
  if (!payload || !Array.isArray(payload.results)) {
    renderEmpty(root, 'Compliance payload is empty.');
    return;
  }
  await loadBenchVersions();
  renderMain(root);
}

function bindNav() {
  document.querySelectorAll('.section-nav a').forEach((link) => {
    link.addEventListener('click', () => {
      const href = link.getAttribute('href') || '';
      if (href === '#compliance' || href.startsWith('#compliance/')) {
        setComplianceView(true);
        if (window.location.hash !== href) window.location.hash = href;
        else queueMicrotask(render);
      } else {
        setComplianceView(false);
        if ((window.location.hash || '').startsWith('#compliance')) {
          history.replaceState(null, '', href);
        }
      }
    });
  });
  window.addEventListener('hashchange', render);
}

bindNav();
render();
