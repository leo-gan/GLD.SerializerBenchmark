/**
 * Experiments view — independent of the language-latest dashboard.
 *
 * Data: public/data/experiments/index.json (+ per-id .json.gz), produced by
 * dashboard/scripts/sync-experiments.py from each experiment.yaml / results.json.
 * New folders appear automatically after sync.
 */
import './experiments.css';
import { formatSig, formatRelativeCell, formatIntGrouped } from './format.js';
import {
  compareLabel,
  competingRows,
  copyText,
  displayTier,
  downloadDataUrl,
  downloadText,
  exportStem,
  isShapeSkip,
  rowsToDelimited,
  skipReason,
  totalStdUs,
} from './exp-export.js';
import {
  destroyExperimentFigures,
  figuresToPng,
  mountExperimentFigures,
  sizeTreatment,
  usesExperimentGraphs,
} from './exp-charts.js';

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
const KIND_LABELS = {
  document: 'one order',
  message: 'flat record',
  telemetry: 'sensor readings',
  event: 'one event',
  strings: 'list of words',
};
const LATENCY_SCALE = { latency: { unit: 'µs', divisor: 1e3, header: 'µs' } };

function langLabel(id) {
  return LANG_LABELS[id] || id;
}

function kindLabel(value) {
  if (Array.isArray(value)) return value.map(kindLabel).join(', ');
  if (value == null || value === '') return '—';
  return KIND_LABELS[value] || String(value);
}

function compareClass(row, rows) {
  const tier = displayTier(row, rows);
  if (tier === 'skip') return 'exp-row-skip';
  if (tier === 'fastest') return 'exp-row-fastest';
  if (tier === 'similar') return 'exp-row-similar';
  if (tier === 'close') return 'exp-row-close';
  if (tier === 'slower') return 'exp-row-slower';
  return '';
}

function ratioCell(valueNs, bestNs, key) {
  if (valueNs == null || bestNs == null) return '<td class="num">—</td>';
  const { text, className } = formatRelativeCell(valueNs, bestNs, false, LATENCY_SCALE, key);
  return `<td class="${className}">${escapeHtml(text)}</td>`;
}

function sizeCell(value, best) {
  if (value == null || best == null) {
    return `<td class="num">${value == null ? '—' : formatIntGrouped(value)}</td>`;
  }
  const { text, className } = formatRelativeCell(value, best, false, {}, 'size_bytes');
  return `<td class="${className}">${escapeHtml(text)}</td>`;
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
    if (filters.io) {
      const gio = g.io == null || g.io === '' ? 'memory' : String(g.io);
      if (gio !== String(filters.io)) return false;
    }
    return true;
  });
  if (hit) return hit;
  if (filters.io) return null;
  return groups[0];
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

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function selectHtml(id, label, values, current, labelFn) {
  if (values.length <= 1) return '';
  const opts = values
    .map((v) => {
      const s = String(v);
      const text = labelFn ? labelFn(v) : s;
      return `<option value="${escapeHtml(s)}"${s === current ? ' selected' : ''}>${escapeHtml(text)}</option>`;
    })
    .join('');
  return `
    <label class="filter-label" for="${id}">${escapeHtml(label)}</label>
    <div class="select-wrapper">
      <select id="${id}" aria-label="${escapeHtml(label)}">${opts}</select>
    </div>`;
}

function renderWhyExperiments() {
  return `
    <details class="exp-howto exp-why glass-panel" open>
      <summary>Why experiments, if the Dashboard already has every number?</summary>
      <p>
        The main Dashboard is the <strong>full warehouse</strong>: every library, every record shape.
        That is the right place to browse. It is the wrong place to pick a library for a real service
        by sorting on speed.
      </p>
      <p>
        The fastest row in the big table may be a library you <strong>cannot use</strong>.
        It might write bytes that only one language can read.
        It might drop field names so partners cannot parse the text.
        It might be built for a file you write once, not for a web request you write on every click.
        The Dashboard will still put it first, because it is fast.
      </p>
      <p>
        An experiment starts with a <strong>decision</strong>, not a sort.
        Example: “We must keep JSON on the public website. Which JSON library is fast enough?”
        We keep only the libraries that could be the answer. We time one shared record.
        We write down what we would give up.
      </p>
      <p>
        Think of a grocery store and a recipe. The store has every product — that is the main Dashboard.
        The recipe lists only what you need for dinner, and why — that is an experiment.
        You need both. The store does not tell you what to cook.
      </p>
      <p>
        Concrete traps the big table does not prevent:
      </p>
      <ul>
        <li><strong>Different jobs in one list.</strong> JSON, compact bytes, and a Python-only format can share a table. “What is fastest?” is not one question.</li>
        <li><strong>A tiny gap looks like a winner.</strong> 1.7 µs vs 1.8 µs is not a reason to rewrite a service.</li>
        <li><strong>Your constraint is invisible.</strong> If browsers must keep JSON, the big table still shows every format.</li>
        <li><strong>One record is not one hundred.</strong> The winner at 1 can lose at 100.</li>
        <li><strong>Numbers without a story.</strong> “Binary is faster” is how teams break a public website.</li>
      </ul>
      <p>
        We do not run a second benchmark. We cut the same numbers down to a fair contest
        and put the story next to them.
        <a href="../experiments/">Longer notes</a>
      </p>
    </details>`;
}

function renderHowToRead({ mode } = { mode: 'table' }) {
  if (mode === 'list') {
    return `
    <details class="exp-howto glass-panel">
      <summary>How to read the numbers</summary>
      <ul>
        <li>Times are the <strong>middle</strong> value (median), in microseconds. Smaller is better.</li>
        <li>Most experiments still show a <strong>table</strong>. Experiment 1 shows <strong>graphs</strong> of the same numbers.</li>
        <li>On a graph page, <strong>Download CSV</strong> or <strong>Show numbers as a table</strong> gives you the grid.</li>
        <li><strong>Vs fastest</strong> is Fastest · About the same · A bit slower · Clearly slower — not simply Winner / Loser.</li>
        <li>Compare libraries <strong>inside one language</strong>.</li>
      </ul>
      <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
  }
  if (mode === 'graphs') {
    return `
    <details class="exp-howto glass-panel">
      <summary>How to read these graphs</summary>
      <ul>
        <li>The <strong>bar</strong> is the middle time (median), in microseconds. Smaller is faster.</li>
        <li>The <strong>whisker</strong> is <strong>approximate spread</strong>, reconstructed from the published confidence interval of the mean — the same reconstruction the table’s Spread column uses. It is not yet the sample standard deviation. After results publish <code>total_std_ns</code>, we will draw that.</li>
        <li>A cell-style <code>15.9 (1.2×)</code> still appears in the tooltip and in the table: 15.9 µs, 1.2 times the fastest compared library.</li>
        <li><strong>Vs fastest</strong> is still Fastest · About the same · A bit slower · Clearly slower — same chips as today, also encoded as color + glyph.</li>
        <li>Compare libraries <strong>inside one language</strong>.</li>
        <li>This experiment shows only libraries that write <strong>named JSON</strong> — an object like <code>{"id": 1, "status": "ok"}</code>. A library that writes a JSON list is not the same public-API payload, so it is not on this page.</li>
        <li><strong>Download CSV</strong> or open <strong>Show numbers as a table</strong> for the grid.</li>
      </ul>
      <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
  }
  return `
    <details class="exp-howto glass-panel">
      <summary>How to read this table</summary>
      <ul>
        <li>Times are the <strong>middle</strong> value, in microseconds. Smaller is better.</li>
        <li>A cell like <code>15.9 (1.2×)</code> means 15.9, and <strong>1.2 times</strong> the fastest row. Green is better. Red is worse.</li>
        <li><strong>Vs fastest</strong> is not simply Winner / Loser. Two libraries can be too close to call on this sample:
          <strong>Fastest</strong> · <strong>About the same</strong> · <strong>A bit slower</strong> · <strong>Clearly slower</strong>.</li>
        <li><strong>Good trade-off</strong> means nobody is both faster and smaller.</li>
        <li><strong>Trials</strong> is how many timed runs we kept. <strong>Spread (std)</strong> is how much those times bounced around.</li>
        <li>Compare libraries <strong>inside one language</strong>. Do not compare write times across languages.</li>
      </ul>
      <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
}

function renderStory(meta) {
  const story = meta.story || {};
  if (!story.why && !story.example && !story.tradeoff) return '';
  return `
    <div class="exp-story glass-panel">
      ${story.why ? `<p><strong>Why we ran this.</strong> ${escapeHtml(story.why)}</p>` : ''}
      ${story.example ? `<p><strong>Example.</strong> ${escapeHtml(story.example)}</p>` : ''}
      ${story.tradeoff ? `<p><strong>Trade-off.</strong> ${escapeHtml(story.tradeoff)}</p>` : ''}
    </div>`;
}

function renderSample(meta) {
  const previews = meta.sample_preview || [];
  if (!previews.length) return '';
  return `
    <details class="exp-sample glass-panel">
      <summary>The data we timed (${previews.length === 1 ? 'one record' : `${previews.length} records`})</summary>
      ${previews
        .map((p) => {
          const rec = { ...p.record };
          if (rec && rec.items && rec.items.some((it) => it && it._more)) {
            /* keep as stored */
          }
          return `
            <p class="section-help">${escapeHtml(kindLabel(p.kind))}${p.how_many > 1 ? ` · ${p.how_many} records in one write (first record shown)` : ''}</p>
            <pre class="exp-sample-pre">${escapeHtml(JSON.stringify(p.record, null, 2))}</pre>`;
        })
        .join('')}
    </details>`;
}

function chips(names, cls) {
  if (!names || !names.length) return '<span class="exp-chip exp-chip-empty">—</span>';
  return names.map((n) => `<span class="exp-chip ${cls}">${escapeHtml(n)}</span>`).join('');
}

function renderTopGroup(group, rows) {
  if (!group && !rows.length) return '';
  const similar = group?.similar || rows.filter((r) => displayTier(r, rows) === 'similar' || displayTier(r, rows) === 'fastest').map((r) => r.library);
  const close = group?.close || rows.filter((r) => displayTier(r, rows) === 'close').map((r) => r.library);
  const slower = rows.filter((r) => displayTier(r, rows) === 'slower').map((r) => r.library);
  const front = group?.time_size_front || rows.filter((r) => r.on_time_size_front).map((r) => r.library);
  const fastest = group?.reference || rows.find((r) => displayTier(r, rows) === 'fastest')?.library;
  const skipped = rows.filter((r) => isShapeSkip(r));
  return `
    <div class="exp-groups glass-panel">
      <p class="section-help">
        How they compare <strong>on this sample</strong>. This is not simply Winner / Loser — two libraries can be too close to call.
      </p>
      <div class="exp-group-row">
        <span class="exp-group-label">Fastest</span>
        ${chips(fastest ? [fastest] : [], 'exp-tier-similar')}
      </div>
      <div class="exp-group-row">
        <span class="exp-group-label">About the same</span>
        ${chips(similar.filter((n) => n !== fastest), 'exp-tier-similar')}
      </div>
      <div class="exp-group-row">
        <span class="exp-group-label">A bit slower</span>
        ${chips(close, 'exp-tier-close')}
      </div>
      <div class="exp-group-row">
        <span class="exp-group-label">Clearly slower</span>
        ${chips(slower, 'exp-tier-slower')}
      </div>
      ${
        front.length
          ? `<div class="exp-group-row">
              <span class="exp-group-label" title="Nobody is both faster and smaller">Good trade-off</span>
              ${chips(front, '')}
            </div>`
          : ''
      }
      ${
        skipped.length
          ? `<p class="section-help exp-shape-note">
              Hollow bar${skipped.length === 1 ? '' : 's'}
              (${skipped.map((r) => escapeHtml(r.library)).join(', ')}):
              timed OK, but ${skipped.length === 1 ? 'this library writes' : 'these libraries write'} a JSON
              <em>list</em> <code>[…]</code>, not a named object <code>{"id": …}</code>.
              That is not what <strong>Stream</strong> means — Stream is only “write as if to a file.”
              We do not rank the list against named JSON.
            </p>`
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
    const ac = isShapeSkip(a) ? 1 : 0;
    const bc = isShapeSkip(b) ? 1 : 0;
    if (ac !== bc) return ac - bc;
    return (Number(a.total_median_ns) || 1e18) - (Number(b.total_median_ns) || 1e18);
  });
  const compared = competingRows(sorted);
  const minOf = (key) => {
    const nums = compared.map((r) => Number(r[key])).filter(Number.isFinite);
    return nums.length ? Math.min(...nums) : null;
  };
  const bestTotal = minOf('total_median_ns');
  const bestWrite = minOf('write_median_ns');
  const bestRead = minOf('read_median_ns');
  const bestSize = minOf('size_bytes');
  const bestGzip = minOf('size_gzip_bytes');
  const bestZstd = minOf('size_zstd_bytes');

  const head = `
    <tr>
      <th class="str">Library</th>
      ${showKind ? '<th class="str">Record</th>' : ''}
      ${showN ? '<th class="num">How many</th>' : ''}
      ${showIo ? '<th class="str">How written</th>' : ''}
      <th class="num">Write (µs)</th>
      <th class="num">Read (µs)</th>
      <th class="num">Total (µs)</th>
      <th class="num">Spread (std)</th>
      <th class="num">Size</th>
      ${showGzip ? '<th class="num">After gzip</th>' : ''}
      ${showZstd ? '<th class="num">After zstd</th>' : ''}
      <th class="num">Trials</th>
      <th class="str" title="Fastest, about the same, a bit slower, or clearly slower — on this sample. Not simply Winner / Loser.">Vs fastest</th>
    </tr>`;
  const body = sorted
    .map((row) => {
      const skipped = isShapeSkip(row);
      const std = totalStdUs(row);
      const trials =
        row.runs != null
          ? `${formatIntGrouped(row.runs)}${row.runs_raw ? ` of ${formatIntGrouped(row.runs_raw)}` : ''}`
          : '—';
      return `
        <tr class="${compareClass(row, sorted)}">
          <td class="str">${escapeHtml(row.library)}${row.version ? `<span class="exp-ver">${escapeHtml(row.version)}</span>` : ''}</td>
          ${showKind ? `<td class="str">${escapeHtml(kindLabel(row.kind))}</td>` : ''}
          ${showN ? `<td class="num">${escapeHtml(row.n ?? '')}</td>` : ''}
          ${showIo ? `<td class="str">${escapeHtml(row.io === 'memory' ? 'in memory' : row.io ?? '')}</td>` : ''}
          ${skipped ? `<td class="num">${formatSig(Number(row.write_median_ns) / 1000)}</td>` : ratioCell(row.write_median_ns, bestWrite, 'write_median_ns')}
          ${skipped ? `<td class="num">${formatSig(Number(row.read_median_ns) / 1000)}</td>` : ratioCell(row.read_median_ns, bestRead, 'read_median_ns')}
          ${skipped ? `<td class="num">${formatSig(Number(row.total_median_ns) / 1000)}</td>` : ratioCell(row.total_median_ns, bestTotal, 'total_median_ns')}
          <td class="num">${std == null ? '—' : formatSig(std)}</td>
          ${skipped ? `<td class="num">${formatIntGrouped(row.size_bytes)}</td>` : sizeCell(row.size_bytes, bestSize)}
          ${showGzip ? (skipped ? `<td class="num">${formatIntGrouped(row.size_gzip_bytes)}</td>` : sizeCell(row.size_gzip_bytes, bestGzip)) : ''}
          ${showZstd ? (skipped ? `<td class="num">${formatIntGrouped(row.size_zstd_bytes)}</td>` : sizeCell(row.size_zstd_bytes, bestZstd)) : ''}
          <td class="num">${trials}</td>
          <td class="str">${escapeHtml(compareLabel(row, sorted))}</td>
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

function replaceExperimentsHtml(root, html) {
  destroyExperimentFigures();
  root.innerHTML = html;
}

function renderFiguresMount() {
  return `<div id="exp-figures"></div>`;
}

function renderDownloadBar() {
  return `
    <div class="exp-download">
      <button type="button" class="tab-btn chart-tool-btn" id="exp-dl-csv">Download CSV</button>
      <button type="button" class="tab-btn chart-tool-btn" id="exp-copy-tsv">Copy TSV</button>
      <span id="exp-status" role="status"></span>
    </div>`;
}

function renderNumbersDetails(rows) {
  return `
    <details class="exp-numbers glass-panel">
      <summary>Show numbers as a table</summary>
      ${renderTable(rows)}
    </details>`;
}

function setExpStatus(root, msg) {
  const el = root.querySelector('#exp-status');
  if (el) el.textContent = msg || '';
}

function wireExportControls(root, ctx) {
  const stem = (extra) => exportStem({ id: ctx.id, lang: ctx.lang, io: ctx.io, extra });
  root.querySelector('#exp-dl-csv')?.addEventListener('click', () => {
    try {
      downloadText(`${stem()}.csv`, rowsToDelimited(ctx.rows, { delimiter: ',' }), 'text/csv;charset=utf-8');
      setExpStatus(root, '');
    } catch (err) {
      setExpStatus(root, 'Download failed');
    }
  });
  root.querySelector('#exp-copy-tsv')?.addEventListener('click', () => {
    copyText(rowsToDelimited(ctx.rows, { delimiter: '\t' }))
      .then(() => setExpStatus(root, 'Table copied'))
      .catch(() => setExpStatus(root, 'Clipboard unavailable'));
  });
  const pngClick = (which) => () => {
    const url = figuresToPng(which);
    if (!url) {
      setExpStatus(root, 'Download failed');
      return;
    }
    downloadDataUrl(url, `${stem(which)}.png`);
    setExpStatus(root, '');
  };
  root.querySelector('#exp-png-latency')?.addEventListener('click', pngClick('latency'));
  root.querySelector('#exp-png-split')?.addEventListener('click', pngClick('split'));
  const pngSize = root.querySelector('#exp-png-size');
  if (pngSize) {
    if (sizeTreatment(ctx.rows).kind !== 'S1') pngSize.hidden = true;
    else pngSize.addEventListener('click', pngClick('size'));
  }
}

function renderList(root) {
  const items = catalog?.experiments || [];
  replaceExperimentsHtml(root, `
    <div class="exp-header">
      <h2 class="chart-title">Experiments</h2>
      <p class="section-help">
        Each item is <strong>one question</strong> — a fair slice of the big Dashboard, not a second set of clocks.
        Compare libraries inside one language.
      </p>
    </div>
    ${renderWhyExperiments()}
    ${renderHowToRead({ mode: 'list' })}
    <div class="exp-list" role="list">
      ${items
        .map((exp) => {
          const nOk = (exp.languages || []).filter((l) => l.status === 'ok').length;
          const status = exp.has_results
            ? `<span class="badge badge-cyan">${nOk} language${nOk === 1 ? '' : 's'}</span>`
            : `<span class="badge badge-slate">No results yet</span>`;
          return `
            <button type="button" class="exp-card glass-panel" data-exp-id="${exp.id}" role="listitem" ${exp.has_results ? '' : 'data-planned="1"'}>
              <span class="exp-card-num">${exp.number != null ? exp.number : '—'}</span>
              <span class="exp-card-body">
                <span class="exp-card-title">${escapeHtml(exp.title || exp.question)}</span>
                <span class="exp-card-meta">${escapeHtml(exp.question || '')}</span>
              </span>
              ${status}
            </button>`;
        })
        .join('')}
    </div>
    ${!items.length ? `<p class="section-help">No experiment folders found.</p>` : ''}
  `);
  root.querySelectorAll('.exp-card[data-exp-id]').forEach((btn) => {
    btn.addEventListener('click', () => {
      if (btn.getAttribute('data-planned') === '1') return;
      setHash(btn.getAttribute('data-exp-id'));
    });
  });
}

async function renderDetail(root, id) {
  destroyExperimentFigures();
  const meta = (catalog?.experiments || []).find((e) => e.id === id);
  if (!meta) {
    replaceExperimentsHtml(
      root,
      `
      <p class="section-help">Unknown experiment <code>${escapeHtml(id)}</code>.</p>
      <button type="button" class="tab-btn" id="exp-back">All experiments</button>`
    );
    root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
    return;
  }
  if (!meta.has_results) {
    replaceExperimentsHtml(
      root,
      `
      <div class="exp-header">
        <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
        <h2 class="chart-title">${escapeHtml(meta.title || meta.question)}</h2>
        ${renderStory(meta)}
        <p class="section-help">No results yet.</p>
      </div>`
    );
    root.querySelector('#exp-back')?.addEventListener('click', () => setHash(null));
    return;
  }
  replaceExperimentsHtml(root, `<p class="section-help">Loading ${escapeHtml(id)}…</p>`);
  let data;
  try {
    data = await loadPayload(id, meta.payload);
  } catch (err) {
    replaceExperimentsHtml(
      root,
      `
      <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
      <p class="section-help">Could not load results: ${escapeHtml(err.message)}</p>`
    );
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
  const filtered = rowsFor(langBlock, filters).filter((row) =>
    id === '01-json-library-bakeoff' ? !isShapeSkip(row) : true
  );
  const group = matchingTopGroup(langBlock, filters);
  const graphs = usesExperimentGraphs(id);
  const howToMode = graphs ? 'graphs' : 'table';
  const resultsHtml = graphs
    ? `${renderFiguresMount()}${renderDownloadBar()}${renderNumbersDetails(filtered)}`
    : renderTable(filtered);

  replaceExperimentsHtml(
    root,
    `
    <div class="exp-header">
      <button type="button" class="tab-btn exp-back" id="exp-back">All experiments</button>
      <p class="exp-kicker">Experiment ${meta.number != null ? meta.number : ''}</p>
      <h2 class="chart-title">${escapeHtml(meta.title || data.question || meta.question)}</h2>
      <p class="section-help">${escapeHtml(meta.question || data.question || '')}</p>
      <p class="section-help">This is a fair slice of the main Dashboard for one decision, not extra clocks. <a href="#experiments">Why we keep experiments separate</a></p>
    </div>
    ${renderStory(meta)}
    ${renderHowToRead({ mode: howToMode })}
    ${renderSample(meta)}
    <div class="exp-lang-tabs tabs" role="tablist" aria-label="Language">
      ${langIds
        .map(
          (idLang) =>
            `<button type="button" class="tab-btn${idLang === ui.lang ? ' active' : ''}" data-exp-lang="${escapeHtml(idLang)}">${escapeHtml(langLabel(idLang))}</button>`
        )
        .join('')}
    </div>
    <div class="filter-group exp-filters">
      ${selectHtml('exp-kind', 'Record', kinds, ui.kind, kindLabel)}
      ${selectHtml('exp-n', 'How many', ns, ui.n)}
      ${selectHtml('exp-io', 'How written', ios, ui.io, (v) => (v === 'memory' ? 'in memory' : v))}
    </div>
    ${renderTopGroup(group, filtered)}
    ${resultsHtml}
  `
  );
  if (graphs) {
    const exportCtx = { id, lang: ui.lang, io: filters.io, rows: filtered };
    if (typeof globalThis.Chart === 'undefined') {
      root.querySelector('.exp-numbers')?.setAttribute('open', '');
      setExpStatus(root, 'Graphs need Chart.js (CDN). The table below has the same numbers.');
    }
    mountExperimentFigures(root.querySelector('#exp-figures'), {
      id,
      meta,
      rows: filtered,
      lang: ui.lang,
      io: filters.io,
    });
    wireExportControls(root, exportCtx);
  }
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
  destroyExperimentFigures();
  const root = document.getElementById('experiments');
  if (!root) return;
  const loc = parseHash();
  setExperimentsView(loc.view !== 'suite');
  if (loc.view === 'suite') return;
  await loadCatalog();
  if (catalogError) {
    replaceExperimentsHtml(
      root,
      `
      <div class="exp-header">
        <h2 class="chart-title">Experiments</h2>
        <p class="section-help">
          Catalog missing. From the repo root run
          <code>python3 dashboard/scripts/sync-experiments.py</code>
          (${escapeHtml(catalogError.message)}).
        </p>
      </div>`
    );
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
