/**
 * Experiments view — independent of the language-latest dashboard.
 *
 * Data: public/data/experiments/index.json (+ per-id .json.gz), produced by
 * dashboard/scripts/sync-experiments.py from each experiment.yaml / results.json.
 * New folders appear automatically after sync.
 */
import './experiments.css';

const CATALOG_URL = 'data/experiments/index.json';
const LANG_LABELS = {
  csharp: 'C#',
  rust: 'Rust',
  go: 'Go',
  python: 'Python',
  javascript: 'JavaScript',
  c: 'C',
  java: 'Java',
  cpp: 'C++',
  swift: 'Swift',
};

const TIER_CLASS = {
  fastest: 'exp-tier-similar',
  similar: 'exp-tier-similar',
  close: 'exp-tier-close',
  slower: 'exp-tier-slower',
};

function langLabel(id) {
  return LANG_LABELS[id] || id;
}

function formatKind(value) {
  if (Array.isArray(value)) return value.join(', ');
  if (value == null || value === '') return '—';
  return String(value);
}

function formatUs(ns) {
  if (ns == null || Number.isNaN(Number(ns))) return '—';
  const us = Number(ns) / 1000;
  if (us >= 1000) return us.toLocaleString(undefined, { maximumFractionDigits: 0 });
  if (us >= 100) return us.toFixed(1);
  if (us >= 10) return us.toFixed(2);
  return us.toFixed(3);
}

function formatBytes(n) {
  if (n == null || n === '') return '—';
  const v = Number(n);
  if (Number.isNaN(v)) return '—';
  return v.toLocaleString();
}

async function fetchJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  return res.json();
}

async function fetchGzipJson(url) {
  const res = await fetch(url);
  if (!res.ok) throw new Error(`${url}: ${res.status}`);
  const buf = await res.arrayBuffer();
  const bytes = new Uint8Array(buf);
  const isGzip = bytes.length >= 2 && bytes[0] === 0x1f && bytes[1] === 0x8b;
  if (!isGzip) {
    return JSON.parse(new TextDecoder().decode(bytes));
  }
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

function parseHash() {
  const raw = (window.location.hash || '').replace(/^#/, '');
  if (raw === 'experiments') return { view: 'list', id: null };
  if (raw.startsWith('experiments/')) {
    const id = decodeURIComponent(raw.slice('experiments/'.length)).replace(/\/+$/, '');
    return { view: id ? 'detail' : 'list', id: id || null };
  }
  return { view: 'suite', id: null };
}

function setHash(id) {
  const next = id ? `#experiments/${id}` : '#experiments';
  if (window.location.hash !== next) window.location.hash = next;
  else render();
}

function unique(rows, key) {
  const seen = [];
  const have = new Set();
  for (const row of rows) {
    const v = row?.[key];
    if (v == null || v === '') continue;
    const s = String(v);
    if (have.has(s)) continue;
    have.add(s);
    seen.push(v);
  }
  return seen;
}

function rowsFor(langBlock, filters) {
  const rows = Array.isArray(langBlock?.rows) ? langBlock.rows : [];
  return rows.filter((row) => {
    if (filters.kind && String(row.kind ?? '') !== filters.kind) return false;
    if (filters.n && String(row.n ?? '') !== filters.n) return false;
    if (filters.io && String(row.io ?? '') !== filters.io) return false;
    return true;
  });
}

function pickDefault(values, preferred) {
  if (!values.length) return '';
  if (preferred != null && preferred !== '') {
    const want = Array.isArray(preferred) ? preferred[0] : preferred;
    const hit = values.find((v) => String(v) === String(want));
    if (hit != null) return String(hit);
  }
  return String(values[0]);
}

function matchingTopGroup(langBlock, filters) {
  const groups = [];
  if (Array.isArray(langBlock?.top_groups)) groups.push(...langBlock.top_groups);
  if (langBlock?.top_group) groups.push(langBlock.top_group);
  if (!groups.length) return null;
  const hit = groups.find((g) => {
    if (filters.kind && g.kind != null && String(g.kind) !== filters.kind) return false;
    if (filters.n && g.n != null && String(g.n) !== filters.n) return false;
    if (filters.io && g.io != null && String(g.io) !== filters.io) return false;
    return true;
  });
  return hit || groups[0];
}

let catalog = null;
let catalogError = null;
let payloadCache = new Map();
let ui = {
  lang: '',
  kind: '',
  n: '',
  io: '',
};

async function loadCatalog() {
  if (catalog || catalogError) return;
  try {
    catalog = await fetchJson(CATALOG_URL);
  } catch (err) {
    catalogError = err;
  }
}

async function loadPayload(id, payloadPath) {
  if (payloadCache.has(id)) return payloadCache.get(id);
  const url = payloadPath || `experiments/${id}.json.gz`;
  const data = await fetchGzipJson(`data/${url.replace(/^data\//, '')}`);
  payloadCache.set(id, data);
  return data;
}

function setExperimentsView(on) {
  document.body.classList.toggle('dash-view-experiments', on);
  document.querySelectorAll('.section-nav a').forEach((link) => {
    const href = link.getAttribute('href') || '';
    const isExp = href === '#experiments' || href.startsWith('#experiments/');
    link.parentElement?.classList.toggle('active', on ? isExp : !isExp && link.parentElement.classList.contains('active'));
  });
  const expLink = document.getElementById('nav-experiments-link');
  if (expLink) expLink.parentElement?.classList.toggle('active', on);
  if (on) {
    document.querySelectorAll('.section-nav li').forEach((li) => {
      if (li.querySelector('#nav-experiments-link')) return;
      li.classList.remove('active');
    });
    window.scrollTo({ top: 0, behavior: 'auto' });
  }
}

function renderList(root) {
  const items = catalog?.experiments || [];
  root.innerHTML = `
    <div class="exp-header">
      <h2 class="chart-title">Experiments</h2>
      <p class="section-help">
        Each item is one question from the lab notebook.
        Compare libraries <strong>inside one language</strong> — not write times across languages.
        New experiment folders appear here after <code>sync-experiments.py</code>.
      </p>
    </div>
    <div class="exp-list" role="list">
      ${items
        .map((exp) => {
          const langs = (exp.languages || [])
            .filter((l) => l.status === 'ok' || l.status === 'planned')
            .map((l) => langLabel(l.id))
            .join(' · ');
          const status = exp.has_results
            ? `<span class="badge badge-cyan">${(exp.languages || []).filter((l) => l.status === 'ok').length} language${(exp.languages || []).filter((l) => l.status === 'ok').length === 1 ? '' : 's'}</span>`
            : `<span class="badge badge-slate">No results yet</span>`;
          return `
            <button type="button" class="exp-card glass-panel" data-exp-id="${exp.id}" role="listitem" ${exp.has_results ? '' : 'data-planned="1"'}>
              <span class="exp-card-num">${exp.number != null ? exp.number : '—'}</span>
              <span class="exp-card-body">
                <span class="exp-card-title">${escapeHtml(exp.question || exp.title)}</span>
                <span class="exp-card-meta">${escapeHtml(langs || '—')}${exp.generated_at ? ` · ${escapeHtml(String(exp.generated_at).slice(0, 10))}` : ''}</span>
              </span>
              ${status}
            </button>`;
        })
        .join('')}
    </div>
    ${!items.length ? `<p class="section-help">No experiment folders found.</p>` : ''}
  `;
  root.querySelectorAll('.exp-card[data-exp-id]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (btn.getAttribute('data-planned') === '1') return;
      setHash(btn.getAttribute('data-exp-id'));
    });
  });
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function selectHtml(id, label, values, current) {
  if (values.length <= 1) return '';
  const opts = values
    .map((v) => {
      const s = String(v);
      return `<option value="${escapeHtml(s)}"${s === current ? ' selected' : ''}>${escapeHtml(s)}</option>`;
    })
    .join('');
  return `
    <label class="filter-label" for="${id}">${escapeHtml(label)}</label>
    <div class="select-wrapper">
      <select id="${id}" aria-label="${escapeHtml(label)}">${opts}</select>
    </div>`;
}

function renderTopGroup(group) {
  if (!group) return '';
  const similar = group.similar || [];
  const close = group.close || [];
  const front = group.time_size_front || [];
  return `
    <div class="exp-groups">
      <p class="section-help">
        Groups vs the fastest on <strong>this sample</strong> (Cliff’s delta).
        Not a single winner — a different record can change the order.
      </p>
      <div class="exp-group-row">
        <span class="exp-group-label">Similar</span>
        ${similar.map((n) => `<span class="exp-chip exp-tier-similar">${escapeHtml(n)}</span>`).join('') || '<span class="exp-chip exp-chip-empty">—</span>'}
      </div>
      <div class="exp-group-row">
        <span class="exp-group-label">Close</span>
        ${close.map((n) => `<span class="exp-chip exp-tier-close">${escapeHtml(n)}</span>`).join('') || '<span class="exp-chip exp-chip-empty">—</span>'}
      </div>
      ${
        front.length
          ? `<div class="exp-group-row">
              <span class="exp-group-label">Time/size front</span>
              ${front.map((n) => `<span class="exp-chip">${escapeHtml(n)}</span>`).join('')}
            </div>`
          : ''
      }
    </div>`;
}

function renderTable(rows) {
  const showKind = unique(rows, 'kind').length > 1;
  const showN = unique(rows, 'n').length > 1;
  const showIo = unique(rows, 'io').length > 1;
  const showGzip = rows.some((r) => r.size_gzip_bytes != null);
  const showZstd = rows.some((r) => r.size_zstd_bytes != null);
  const sorted = [...rows].sort((a, b) => {
    const ac = a.in_comparison === false ? 1 : 0;
    const bc = b.in_comparison === false ? 1 : 0;
    if (ac !== bc) return ac - bc;
    return (Number(a.total_median_ns) || 1e18) - (Number(b.total_median_ns) || 1e18);
  });
  const head = `
    <tr>
      <th class="str">Library</th>
      ${showKind ? '<th class="str">Data type</th>' : ''}
      ${showN ? '<th class="num">N</th>' : ''}
      ${showIo ? '<th class="str">I/O</th>' : ''}
      <th class="num">Write (µs)</th>
      <th class="num">Read (µs)</th>
      <th class="num">Total (µs)</th>
      <th class="num">Size</th>
      ${showGzip ? '<th class="num">gzip</th>' : ''}
      ${showZstd ? '<th class="num">zstd</th>' : ''}
      <th class="str">Group</th>
    </tr>`;
  const body = sorted
    .map((row) => {
      const tier = row.cliffs_label || row.tier || '';
      const cls = TIER_CLASS[row.tier] || TIER_CLASS[tier] || '';
      const skipped = row.in_comparison === false;
      return `
        <tr class="${cls}${skipped ? ' exp-row-skip' : ''}">
          <td class="str">${escapeHtml(row.library)}${row.version ? `<span class="exp-ver">${escapeHtml(row.version)}</span>` : ''}</td>
          ${showKind ? `<td class="str">${escapeHtml(row.kind ?? '')}</td>` : ''}
          ${showN ? `<td class="num">${escapeHtml(row.n ?? '')}</td>` : ''}
          ${showIo ? `<td class="str">${escapeHtml(row.io ?? '')}</td>` : ''}
          <td class="num">${formatUs(row.write_median_ns)}</td>
          <td class="num">${formatUs(row.read_median_ns)}</td>
          <td class="num">${formatUs(row.total_median_ns)}</td>
          <td class="num">${formatBytes(row.size_bytes)}</td>
          ${showGzip ? `<td class="num">${formatBytes(row.size_gzip_bytes)}</td>` : ''}
          ${showZstd ? `<td class="num">${formatBytes(row.size_zstd_bytes)}</td>` : ''}
          <td class="str">${escapeHtml(skipped ? 'not compared' : tier || '—')}</td>
        </tr>`;
    })
    .join('');
  return `
    <div class="table-container">
      <table class="data-table exp-table">
        <thead>${head}</thead>
        <tbody>${body || '<tr><td colspan="8">No rows for this filter.</td></tr>'}</tbody>
      </table>
    </div>`;
}

async function renderDetail(root, id) {
  const meta = (catalog?.experiments || []).find((e) => e.id === id);
  if (!meta) {
    root.innerHTML = `
      <p class="section-help">Unknown experiment <code>${escapeHtml(id)}</code>.</p>
      <button type="button" class="tab-btn" id="exp-back">All experiments</button>`;
    root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
    return;
  }
  if (!meta.has_results) {
    root.innerHTML = `
      <div class="exp-header">
        <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
        <h2 class="chart-title">${escapeHtml(meta.question || meta.title)}</h2>
        <p class="section-help">No results.json yet. Re-run the experiment, then sync.</p>
      </div>`;
    root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
    return;
  }
  root.innerHTML = `<p class="section-help">Loading ${escapeHtml(id)}…</p>`;
  let data;
  try {
    data = await loadPayload(id, meta.payload);
  } catch (err) {
    root.innerHTML = `
      <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
      <p class="section-help">Could not load results: ${escapeHtml(err.message)}</p>`;
    root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
    return;
  }
  const langIds = Object.keys(data.languages || {}).filter((k) => data.languages[k]?.status === 'ok');
  if (!ui.lang || !langIds.includes(ui.lang)) ui.lang = langIds[0] || '';
  const langBlock = data.languages?.[ui.lang] || {};
  const allRows = langBlock.rows || [];
  const kinds = unique(allRows, 'kind').map(String);
  const ns = unique(allRows, 'n').map(String);
  const ios = unique(allRows, 'io').map(String);
  if (!ui.kind || !kinds.includes(ui.kind)) ui.kind = pickDefault(kinds, data.sample?.kind);
  if (!ui.n || !ns.includes(ui.n)) ui.n = pickDefault(ns, data.sample?.n);
  if (!ui.io || !ios.includes(ui.io)) ui.io = pickDefault(ios, data.cleaning?.main_io === 'memory' ? 'memory' : data.cleaning?.main_io);
  const filters = {
    kind: kinds.length > 1 ? ui.kind : '',
    n: ns.length > 1 ? ui.n : '',
    io: ios.length > 1 ? ui.io : '',
  };
  const filtered = rowsFor(langBlock, filters);
  const group = matchingTopGroup(langBlock, filters);
  const sampleBits = [
    data.sample?.kind != null ? `data type ${formatKind(data.sample.kind)}` : '',
    data.sample?.n != null ? `N=${formatKind(data.sample.n)}` : '',
    data.cleaning?.filter_id ? `samples ${data.cleaning.filter_id}` : '',
  ]
    .filter(Boolean)
    .join(' · ');

  root.innerHTML = `
    <div class="exp-header">
      <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
      <p class="exp-kicker">Experiment ${meta.number != null ? meta.number : ''}</p>
      <h2 class="chart-title">${escapeHtml(data.question || meta.question || meta.title)}</h2>
      <p class="section-help">${escapeHtml(sampleBits)}${data.generated_at ? ` · ${escapeHtml(String(data.generated_at).slice(0, 10))}` : ''}</p>
    </div>
    <div class="exp-lang-tabs tabs" role="tablist" aria-label="Language">
      ${langIds
        .map(
          (idLang) =>
            `<button type="button" class="tab-btn${idLang === ui.lang ? ' active' : ''}" data-exp-lang="${escapeHtml(idLang)}">${escapeHtml(langLabel(idLang))}</button>`
        )
        .join('')}
    </div>
    <p class="section-help">Times are median microseconds on this sample. Do not compare write times across languages.</p>
    <div class="filter-group exp-filters">
      ${selectHtml('exp-kind', 'Data type', kinds, ui.kind)}
      ${selectHtml('exp-n', 'N', ns, ui.n)}
      ${selectHtml('exp-io', 'I/O', ios, ui.io)}
    </div>
    ${renderTopGroup(group)}
    ${renderTable(filtered)}
  `;
  root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
  root.querySelectorAll('[data-exp-lang]').forEach((btn) => {
    btn.addEventListener('click', () => {
      ui.lang = btn.getAttribute('data-exp-lang') || '';
      ui.kind = '';
      ui.n = '';
      ui.io = '';
      render();
    });
  });
  root.querySelector('#exp-kind')?.addEventListener('change', (e) => {
    ui.kind = e.target.value;
    render();
  });
  root.querySelector('#exp-n')?.addEventListener('change', (e) => {
    ui.n = e.target.value;
    render();
  });
  root.querySelector('#exp-io')?.addEventListener('change', (e) => {
    ui.io = e.target.value;
    render();
  });
}

async function render() {
  const root = document.getElementById('experiments');
  if (!root) return;
  const loc = parseHash();
  setExperimentsView(loc.view !== 'suite');
  if (loc.view === 'suite') return;
  await loadCatalog();
  if (catalogError) {
    root.innerHTML = `
      <div class="exp-header">
        <h2 class="chart-title">Experiments</h2>
        <p class="section-help">
          Catalog missing. From the repo root run
          <code>python3 dashboard/scripts/sync-experiments.py</code>
          (${escapeHtml(catalogError.message)}).
        </p>
      </div>`;
    return;
  }
  if (loc.view === 'list') {
    ui = { lang: '', kind: '', n: '', io: '' };
    renderList(root);
    return;
  }
  await renderDetail(root, loc.id);
}

function bindNav() {
  document.querySelectorAll('.section-nav a').forEach((link) => {
    link.addEventListener('click', () => {
      const href = link.getAttribute('href') || '';
      if (href === '#experiments' || href.startsWith('#experiments/')) {
        setExperimentsView(true);
        if (window.location.hash !== href) window.location.hash = href;
        else queueMicrotask(render);
      } else {
        setExperimentsView(false);
        if ((window.location.hash || '').startsWith('#experiments')) {
          history.replaceState(null, '', href);
        }
      }
    });
  });
  window.addEventListener('hashchange', render);
}

export function initExperiments() {
  bindNav();
  render();
}

initExperiments();
