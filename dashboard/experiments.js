/**
 * Experiments view — independent of the language-latest dashboard.
 *
 * Data: public/data/experiments/index.json (+ per-id .json.gz), produced by
 * dashboard/scripts/sync-experiments.py from each experiment.yaml / results.json.
 * New folders appear automatically after sync.
 */
import './experiments.css';
import { escapeHtml, fetchJsonMaybeGzip } from './page.js';
import { formatSig, formatRelativeCell, formatIntGrouped } from './format.js';
import { loadSerializerSources, serializerNameHtml } from './serializer-sources.js';
import {
  ALL_LANG,
  compareLabel,
  competingRows,
  copyText,
  displayTier,
  downloadDataUrl,
  downloadText,
  exportStem,
  flattenLanguageRows,
  isAllLang,
  isShapeSkip,
  librariesByDisplayTier,
  mixedLanguages,
  peerRows,
  rowsToDelimited,
  toggleSeries,
  totalStdUs,
} from './exp-export.js';
import { formatExperimentsHash, parseExperimentsHash } from './dash-hash.js';
import {
  destroyExperimentFigures,
  figuresToPng,
  mountExperimentFigures,
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
  kotlin: 'Kotlin',
  mojo: 'Mojo',
  php: 'PHP',
  cpp: 'C++',
  swift: 'Swift',
  zig: 'Zig',
  fortran: 'Fortran',
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

function parseHash() {
  return parseExperimentsHash(window.location.hash);
}

function setHash(id, lang = '') {
  const next = formatExperimentsHash({ id: id || '', lang: lang || '' });
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
let graphUi = {
  show: 'all',
  writeOn: true,
  readOn: true,
};

async function loadCatalog() {
  if (catalog || catalogError) return;
  try {
    catalog = await fetchJsonMaybeGzip(CATALOG_URL);
  } catch (err) {
    catalogError = err;
  }
}

async function loadPayload(id, payloadPath) {
  if (payloadCache.has(id)) return payloadCache.get(id);
  const url = payloadPath || `experiments/${id}.json.gz`;
  const data = await fetchJsonMaybeGzip(`data/${url.replace(/^data\//, '')}`);
  payloadCache.set(id, data);
  return data;
}

function setExperimentsView(on) {
  document.body.classList.toggle('dash-view-experiments', on);
  if (on) {
    document.body.classList.remove('dash-view-overview', 'dash-view-compare', 'dash-view-compliance');
  }
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

function experimentSwitcherHtml(selectedId) {
  const items = (catalog?.experiments || []).filter((exp) => exp.has_results);
  const options = ['<option value="" class="std-opt-all">All experiments</option>'].concat(
    items.map((exp) => {
      const title = exp.title || exp.question || exp.id;
      const selected = exp.id === selectedId ? ' selected' : '';
      return `<option value="${escapeHtml(exp.id)}"${selected}>${escapeHtml(title)}</option>`;
    }),
  );
  return `
    <div class="exp-switch">
      <label class="filter-label" for="experiment-select">Experiment</label>
      <div class="select-wrapper">
        <select id="experiment-select" class="${selectedId ? '' : 'std-select-all'}" aria-label="Experiment">${options.join('')}</select>
      </div>
    </div>`;
}

function bindExperimentSwitcher(root) {
  root.querySelector('#experiment-select')?.addEventListener('change', (event) => {
    setHash(event.target.value || '');
  });
}

function renderWhyExperiments() {
  return `
    <details class="exp-inline">
      <summary>Why experiments, if the Dashboard already has every number?</summary>
      <p>
        Overview and Compare already hold one standard, one data type, one record or one hundred,
        write time, read time, and raw size. Compliance holds spec pass and fail.
      </p>
      <p>
        An experiment remains when those pages do not hold the cell: a sensor list that grows,
        size after gzip and zstd, a real stream against a copied one, or the Fortran call
        over the same C library.
      </p>
      <p><a href="../experiments/">Longer notes</a></p>
    </details>`;
}

function renderHowToRead({ mode, id } = { mode: 'table' }) {
  if (mode === 'list') {
    return `
    <details class="exp-inline">
      <summary>How to read the numbers</summary>
      <ul>
        <li>Times are the <strong>middle</strong> value (median), in microseconds. Smaller is better.</li>
        <li>Each experiment page shows <strong>graphs</strong> of the same numbers, plus <strong>Download CSV</strong> or <strong>Show numbers as a table</strong> for the grid.</li>
        <li>On a graph page, <strong>Download CSV</strong> or <strong>Show numbers as a table</strong> gives you the grid.</li>
        <li><strong>Vs fastest</strong> is Fastest · About the same · A bit slower · Clearly slower — not simply Winner / Loser.</li>
        <li>The <strong>All</strong> tab puts every language on the same microsecond axis so you can compare runtimes. Color is still vs that language’s fastest.</li>
        <li>A single-language tab is one contest inside that runtime.</li>
      </ul>
      <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
  }
  if (mode === 'graphs') {
    return `
    <details class="exp-read-fold">
      <summary>How to read these graphs.</summary>
      <ul class="exp-read">
      <li>The <strong>bar</strong> is the middle time (median), in microseconds. Smaller is faster.</li>
      <li>The <strong>whisker</strong> on <strong>Write + read</strong> is <strong>approximate spread</strong>, reconstructed from the published confidence interval of the mean — the same reconstruction the table’s Spread column uses. It is not yet the sample standard deviation. After results publish <code>total_std_ns</code>, we will draw that.</li>
      <li>A cell-style <code>15.9 (1.2×)</code> still appears in the tooltip and in the table: 15.9 µs, 1.2 times the fastest compared library.</li>
      <li><strong>Vs fastest</strong> is still Fastest · About the same · A bit slower · Clearly slower — same chips as today, also encoded as color + glyph.</li>
      <li>On the <strong>All</strong> tab the bars use the same <strong>microsecond</strong> axis as a language tab, so you can compare languages. Color and “Vs fastest” stay vs that language’s fastest.</li>
      <li>A single-language tab is one contest inside that runtime.</li>
      <li><strong>Show</strong> keeps the fastest rows (top), the slowest rows (bottom), or every row.</li>
      <li><strong>Write and Read</strong> can show write, read, or both. It sorts by the series that is on. With both on, it sorts by write + read. Each bar has the same whisker as Write + read: the spread of that write or that read.</li>
      <li>Some experiments add a size, compression, or rank chart when that is the question.</li>
      <li><strong>Download CSV</strong> or open <strong>Show numbers as a table</strong> for the grid.</li>
    </ul>
    <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
  }
  return `
    <details class="exp-read-fold">
      <summary>How to read this table.</summary>
      <ul class="exp-read">
        <li>Times are the <strong>middle</strong> value, in microseconds. Smaller is better.</li>
        <li>A cell like <code>15.9 (1.2×)</code> means 15.9, and <strong>1.2 times</strong> the fastest row. Green is better. Red is worse.</li>
        <li><strong>Vs fastest</strong> is not simply Winner / Loser. Two libraries can be too close to call on this sample:
          <strong>Fastest</strong> · <strong>About the same</strong> · <strong>A bit slower</strong> · <strong>Clearly slower</strong>.</li>
        <li><strong>Good trade-off</strong> means nobody is both faster and smaller.</li>
        <li><strong>Trials</strong> is how many timed runs we kept. <strong>Spread (std)</strong> is how much those times bounced around.</li>
        <li>On the <strong>All</strong> tab, times are on one microsecond scale so you can compare languages. <strong>Vs fastest</strong> in the table is still vs that language’s fastest.</li>
        <li>A single-language tab is one contest inside that runtime.</li>
      </ul>
      <p><a href="../experiments/">Full experiment notes</a></p>
    </details>`;
}

function previewCaption(preview) {
  const bits = [kindLabel(preview.kind)];
  const values = preview.record && preview.record.values;
  if (Array.isArray(values)) {
    const more = values.find((item) => item && typeof item === 'object' && item._more);
    const count = more ? values.filter((item) => !(item && item._more)).length + more._more : values.length;
    bits.push(`${count} numbers`);
  }
  if (preview.how_many > 1) bits.push(`${preview.how_many} records in one write, first record shown`);
  else bits.push('n=1');
  return bits.join(' · ');
}

function renderSample(meta) {
  const previews = meta.sample_preview || [];
  if (!previews.length) return '';
  const summary = previews.length === 1 ? 'Sample record (n=1)' : 'Sample records (n=1)';
  return `
    <details class="exp-sample">
      <summary>${summary}</summary>
      ${previews
        .map((preview) => `
            <p class="section-help">${escapeHtml(previewCaption(preview))}</p>
            <pre class="exp-sample-pre">${escapeHtml(JSON.stringify(preview.record, null, 2))}</pre>`)
        .join('')}
    </details>`;
}

function renderStory(meta, howToMode, question) {
  const story = meta.story || {};
  const sample = renderSample(meta);
  const howTo = howToMode ? renderHowToRead({ mode: howToMode }) : '';
  const title = (meta.title || question || '').trim();
  const lead = question && question.trim() !== title ? question.trim() : '';
  const why = [lead, story.why].filter(Boolean).join(' ');
  const tradeoff = story.tradeoff
    ? `<p><strong>Trade-off.</strong> ${escapeHtml(story.tradeoff)}</p>`
    : '';
  const tradeField = tradeoff || howTo
    ? `<div class="exp-tradeoff">${tradeoff}${howTo}</div>`
    : '';
  if (!why && !story.example && !sample && !tradeField) return '';
  return `
    <div class="exp-story glass-panel">
      ${why ? `<p><strong>Why we ran this.</strong> ${escapeHtml(why)}</p>` : ''}
      ${story.example ? `<p><strong>Example.</strong> ${escapeHtml(story.example)}</p>` : ''}
      ${sample}
      ${tradeField}
    </div>`;
}

function chips(names, cls) {
  if (!names || !names.length) return '<span class="exp-chip exp-chip-empty">—</span>';
  return names.map((n) => `<span class="exp-chip ${cls}">${escapeHtml(n)}</span>`).join('');
}

function bestAmong(row, rows, key) {
  const nums = competingRows(peerRows(row, rows))
    .map((r) => Number(r[key]))
    .filter(Number.isFinite);
  return nums.length ? Math.min(...nums) : null;
}

function renderTopGroup(group, rows) {
  if (!group && !rows.length) return '';
  // Chips follow the table's Vs fastest column. Stored top_group.close is often [].
  const tiers = librariesByDisplayTier(rows);
  const fastestNames = tiers.fastest.length ? tiers.fastest : group?.reference ? [group.reference] : [];
  const similar = tiers.similar.filter((n) => !fastestNames.includes(n));
  const close = tiers.close;
  const slower = tiers.slower;
  const front = group?.time_size_front?.length
    ? group.time_size_front
    : rows.filter((r) => r.on_time_size_front).map((r) => r.library);
  const skipped = rows.filter((r) => isShapeSkip(r));
  return `
    <div class="exp-groups glass-panel">
      <p class="section-help">
        How they compare <strong>on this sample</strong>. This is not simply Winner / Loser — two libraries can be too close to call.
      </p>
      <div class="exp-group-row">
        <span class="exp-group-label">Fastest</span>
        ${chips(fastestNames, 'exp-tier-similar')}
      </div>
      <div class="exp-group-row">
        <span class="exp-group-label">About the same</span>
        ${chips(similar, 'exp-tier-similar')}
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
            </p>`
          : ''
      }
    </div>`;
}

function renderTable(rows) {
  const showLang = mixedLanguages(rows) || rows.some((r) => r.language);
  const showKind = unique(rows, 'kind').length > 1;
  const showN = unique(rows, 'n').length > 1;
  const showIo = unique(rows, 'io').length > 1;
  const showGzip = rows.some((r) => r.size_gzip_bytes != null);
  const showZstd = rows.some((r) => r.size_zstd_bytes != null);
  const sorted = [...rows].sort((a, b) => {
    if (showLang && a.language !== b.language) {
      const langs = unique(rows, 'language').map(String);
      return langs.indexOf(String(a.language || '')) - langs.indexOf(String(b.language || ''));
    }
    const ac = isShapeSkip(a) ? 1 : 0;
    const bc = isShapeSkip(b) ? 1 : 0;
    if (ac !== bc) return ac - bc;
    return (Number(a.total_median_ns) || 1e18) - (Number(b.total_median_ns) || 1e18);
  });

  const head = `
    <tr>
      ${showLang ? '<th class="str">Language</th>' : ''}
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
      <th class="str" title="Fastest, about the same, a bit slower, or clearly slower — vs that language’s fastest on this sample. Not simply Winner / Loser.">Vs fastest</th>
    </tr>`;
  const body = sorted
    .map((row) => {
      const skipped = isShapeSkip(row);
      const std = totalStdUs(row);
      const trials =
        row.runs != null
          ? `${formatIntGrouped(row.runs)}${row.runs_raw ? ` of ${formatIntGrouped(row.runs_raw)}` : ''}`
          : '—';
      const bestWrite = bestAmong(row, sorted, 'write_median_ns');
      const bestRead = bestAmong(row, sorted, 'read_median_ns');
      const bestTotal = bestAmong(row, sorted, 'total_median_ns');
      const sizePool = showLang ? competingRows(sorted) : competingRows(peerRows(row, sorted));
      const minSize = (key) => {
        const nums = sizePool.map((r) => Number(r[key])).filter(Number.isFinite);
        return nums.length ? Math.min(...nums) : null;
      };
      const bestSize = minSize('size_bytes');
      const bestGzip = minSize('size_gzip_bytes');
      const bestZstd = minSize('size_zstd_bytes');
      return `
        <tr class="${compareClass(row, sorted)}">
          ${showLang ? `<td class="str">${escapeHtml(langLabel(row.language))}</td>` : ''}
          <td class="str">${serializerNameHtml(row.language, row.library, row.library)}${row.version ? `<span class="exp-ver">${escapeHtml(row.version)}</span>` : ''}</td>
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

function bindGraphControls(root) {
  root.querySelector('#exp-show')?.addEventListener('change', (e) => {
    graphUi.show = e.target.value;
    render();
  });
  const toggle = (which) => () => {
    const next = toggleSeries(graphUi.writeOn, graphUi.readOn, which);
    if (next.writeOn === graphUi.writeOn && next.readOn === graphUi.readOn) return;
    graphUi.writeOn = next.writeOn;
    graphUi.readOn = next.readOn;
    render();
  };
  root.querySelector('#exp-toggle-write')?.addEventListener('click', toggle('write'));
  root.querySelector('#exp-toggle-read')?.addEventListener('click', toggle('read'));
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
  ['latency', 'relative', 'split', 'size', 'compress', 'curve', 'vsn', 'ranks'].forEach((which) => {
    root.querySelector(`#exp-png-${which}`)?.addEventListener('click', pngClick(which));
  });
}

function renderList(root) {
  const items = catalog?.experiments || [];
  replaceExperimentsHtml(root, `
    <div class="exp-header">
      <h2 class="chart-title">Experiments</h2>
      <p class="section-help">
        Each item is <strong>one question</strong> — a fair slice of the big Dashboard, not a second set of clocks.
        Open <strong>All</strong> to see every language on one microsecond axis.
      </p>
      ${renderWhyExperiments()}
      ${renderHowToRead({ mode: 'list' })}
    </div>
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

async function renderDetail(root, id, locLang = '') {
  destroyExperimentFigures();
  const meta = (catalog?.experiments || []).find((e) => e.id === id);
  if (!meta) {
    replaceExperimentsHtml(
      root,
      `
      ${experimentSwitcherHtml('')}
      <p class="section-help">Unknown experiment <code>${escapeHtml(id)}</code>.</p>`
    );
    bindExperimentSwitcher(root);
    return;
  }
  if (!meta.has_results) {
    replaceExperimentsHtml(
      root,
      `
      <div class="exp-header">
        ${experimentSwitcherHtml('')}
        <h2 class="chart-title">${escapeHtml(meta.title || meta.question)}</h2>
        ${renderStory(meta, '', meta.question || '')}
        <p class="section-help">No results yet.</p>
      </div>`
    );
    bindExperimentSwitcher(root);
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
      ${experimentSwitcherHtml(id)}
      <p class="section-help">Could not load results: ${escapeHtml(err.message)}</p>`
    );
    bindExperimentSwitcher(root);
    return;
  }
  const langIds = Object.keys(data.languages || {}).filter((k) => data.languages[k]?.status === 'ok');
  const tabIds = langIds.length ? [...langIds, ALL_LANG] : [];
  if (locLang && tabIds.includes(locLang)) ui.lang = locLang;
  if (!ui.lang || !tabIds.includes(ui.lang)) ui.lang = langIds[0] || '';
  const wantHash = formatExperimentsHash({ id, lang: ui.lang });
  if (ui.lang && window.location.hash !== wantHash) {
    try {
      window.history.replaceState(null, '', `${window.location.pathname}${window.location.search}${wantHash}`);
    } catch {
      /* ignore */
    }
  }
  const crossLang = isAllLang(ui.lang);
  const langBlock = crossLang
    ? {
        status: 'ok',
        language: ALL_LANG,
        rows: flattenLanguageRows(data.languages, langIds).map((r) => ({
          ...r,
          label: `${langLabel(r.language)} · ${r.library}`,
        })),
      }
    : data.languages?.[ui.lang] || {};
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
  const group = crossLang ? null : matchingTopGroup(langBlock, filters);
  const graphs = usesExperimentGraphs(id);
  const howToMode = graphs ? 'graphs' : 'table';
  const resultsHtml = graphs
    ? `${renderFiguresMount()}${renderDownloadBar()}${renderNumbersDetails(filtered)}`
    : renderTable(filtered);
  const groupHtml = crossLang ? '' : renderTopGroup(group, filtered);

  replaceExperimentsHtml(
    root,
    `
    <div class="exp-header">
      ${experimentSwitcherHtml(id)}
      <h2 class="chart-title">${escapeHtml(meta.title || data.question || meta.question)}</h2>
    </div>
    ${renderStory(meta, howToMode, meta.question || data.question || '')}
    <div class="exp-lang-tabs tabs" role="tablist" aria-label="Language">
      ${tabIds
        .map((idLang) => {
          const label = isAllLang(idLang) ? 'All' : langLabel(idLang);
          return `<button type="button" class="tab-btn${idLang === ui.lang ? ' active' : ''}" data-exp-lang="${escapeHtml(idLang)}">${escapeHtml(label)}</button>`;
        })
        .join('')}
    </div>
    <div class="filter-group exp-filters">
      ${selectHtml('exp-kind', 'Record', kinds, ui.kind, kindLabel)}
      ${selectHtml('exp-n', 'How many', ns, ui.n)}
      ${selectHtml('exp-io', 'How written', ios, ui.io, (v) => (v === 'memory' ? 'in memory' : v))}
    </div>
    ${groupHtml}
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
      allRows: allRows,
      lang: ui.lang,
      io: filters.io || ui.io,
      kind: filters.kind || ui.kind,
      n: filters.n || ui.n,
      crossLang,
      show: graphUi.show,
      writeOn: graphUi.writeOn,
      readOn: graphUi.readOn,
    });
    wireExportControls(root, exportCtx);
    bindGraphControls(root);
  }
  bindExperimentSwitcher(root);
  root.querySelectorAll('[data-exp-lang]').forEach((btn) => {
    btn.addEventListener('click', () => {
      ui.lang = btn.getAttribute('data-exp-lang') || '';
      ui.kind = '';
      ui.n = '';
      ui.io = '';
      setHash(id, ui.lang);
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
  await loadCatalog();
  if (loc.view === 'suite') return;
  await loadSerializerSources();
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
  await renderDetail(root, loc.id, loc.lang);
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
