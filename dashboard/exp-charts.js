/**
 * Experiment figure catalog — PR 1 implements L1, W1, S0/S1 for opted-in ids.
 * Do not import charts.js or main.js.
 */
import { formatSig, formatIntGrouped, formatRelativeCell, LATENCY_US } from './format.js';
import {
  compareLabel,
  competingRows,
  displayTier,
  isShapeSkip,
  skipReason,
  sortRows,
  totalStdUs,
} from './exp-export.js';

export const GRAPH_PROTOTYPE_IDS = new Set([
  '01-json-library-bakeoff',
  '02-flat-record-formats',
  '03-one-language-store',
  '04-sensor-list-size',
  '05-event-log-formats',
  '06-document-db-formats',
  '07-write-once-read-many',
  '08-human-files',
  '09-compression-size',
  '10-one-vs-hundred',
  '11-memory-vs-stream',
  '12-format-vs-library',
  '13-ranking-accident',
]);

const KIND_AXIS = {
  document: 'one order',
  message: 'flat record',
  telemetry: 'sensor readings',
  event: 'one event',
  strings: 'list of words',
};

const SERIES_PALETTE = [
  { fill: '#7eb6ff', ink: '#1565c0', bg: '#e3f2fd' },
  { fill: '#5d4037', ink: '#3e2723', bg: '#efebe9' },
  { fill: '#00838f', ink: '#006064', bg: '#e0f7fa' },
  { fill: '#f9a825', ink: '#f57f17', bg: '#fff8e1' },
  { fill: '#546e7a', ink: '#37474f', bg: '#eceff1' },
  { fill: '#8d6e63', ink: '#4e342e', bg: '#efebe9' },
  { fill: '#0288d1', ink: '#01579b', bg: '#e1f5fe' },
  { fill: '#6d4c41', ink: '#3e2723', bg: '#efebe9' },
  { fill: '#455a64', ink: '#263238', bg: '#eceff1' },
  { fill: '#00acc1', ink: '#006064', bg: '#e0f7fa' },
];

function paletteAt(i) {
  return SERIES_PALETTE[i % SERIES_PALETTE.length];
}

function libraryChips(names) {
  return (names || []).map((name, i) => {
    const p = paletteAt(i);
    return seriesChip(String(name), p.fill, p.ink, p.bg);
  }).join(' ');
}

const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11,
};
const gridColor = 'rgba(0, 0, 0, 0.06)';
const tickColor = '#5f6368';
/** Write vs read series — not green/red (those mean faster/slower). */
const SERIES_WRITE = '#7eb6ff';
const SERIES_READ = '#4a148c';
/** Experiment 10: one vs a hundred — not the write/read pair (those were too close). */
const SERIES_N1 = '#7eb6ff';
const SERIES_N100 = '#5d4037';
const tooltipChrome = {
  backgroundColor: 'rgba(32, 33, 36, 0.95)',
  titleColor: '#ffffff',
  bodyColor: '#ffffff',
  borderColor: '#dadce0',
  borderWidth: 1,
  padding: 10,
  bodyFont: fontStyle,
  titleFont: { ...fontStyle, weight: 'bold' },
};

const L1_CAPTION =
  'The bar is the <strong>middle</strong> time (median). The whisker is <strong>approximate spread</strong>, reconstructed from the published confidence interval of the <strong>mean</strong> (the same reconstruction the table’s Spread column uses). It is not yet the sample standard deviation of the trials. A short whisker means a stable number. Two bars whose whiskers heavily overlap are usually “about the same.”';

/** @type {import('chart.js').Chart[]} */
const chartInstances = [];
/** @type {Record<string, import('chart.js').Chart>} */
const chartsByKey = {};
let hatchPattern = null;

export function usesExperimentGraphs(id) {
  return GRAPH_PROTOTYPE_IDS.has(id);
}

export function destroyExperimentFigures() {
  for (const chart of chartInstances) {
    try {
      chart.destroy();
    } catch (_) {
      /* already gone */
    }
  }
  chartInstances.length = 0;
  for (const k of Object.keys(chartsByKey)) delete chartsByKey[k];
}

export function figuresToPng(which) {
  const chart = chartsByKey[which];
  if (!chart) return null;
  return chart.toBase64Image('image/png', 1);
}

function hasFiniteSeries(rows, key) {
  return (rows || []).some((r) => Number.isFinite(Number(r[key])));
}

function uniqueValues(rows, key) {
  const seen = [];
  const have = new Set();
  for (const row of rows || []) {
    const v = row?.[key];
    if (v == null || v === '') continue;
    const s = String(v);
    if (have.has(s)) continue;
    have.add(s);
    seen.push(v);
  }
  return seen;
}

function rowsMatching(rows, match = {}, ignore = {}) {
  return (rows || []).filter((r) => {
    if (!ignore.io && match.io && String(r.io ?? '') !== String(match.io)) return false;
    if (!ignore.kind && match.kind && String(r.kind ?? '') !== String(match.kind)) return false;
    if (!ignore.n && match.n && String(r.n ?? '') !== String(match.n)) return false;
    return true;
  });
}

/**
 * Which figures to draw. Special experiments get a story-specific hero;
 * the rest reuse L1 / W1 / S0 / S1.
 */
export function figureTypesFor(id, rows, allRows) {
  const view = rows || [];
  const types = [];
  if (id === '07-write-once-read-many') {
    if (hasFiniteSeries(view, 'write_median_ns') && hasFiniteSeries(view, 'read_median_ns')) types.push('W1');
    const t = sizeTreatment(view);
    if (t.kind === 'S1' || t.kind === 'S0') types.push(t.kind);
    return types;
  }
  if (id === '04-sensor-list-size') {
    types.push('C1');
    return types;
  }
  if (id === '09-compression-size') {
    types.push('S2');
    return types;
  }
  if (id === '10-one-vs-hundred') {
    types.push('C2');
    types.push('L1');
    return types;
  }
  if (id === '13-ranking-accident') {
    types.push('R1');
    types.push('L1');
    return types;
  }
  types.push('L1');
  if (hasFiniteSeries(view, 'write_median_ns') && hasFiniteSeries(view, 'read_median_ns')) types.push('W1');
  const t = sizeTreatment(view);
  if (t.kind === 'S1' || t.kind === 'S0') types.push(t.kind);
  return types;
}

function comparedSizes(rows) {
  return competingRows(rows).filter((r) => Number.isFinite(Number(r.size_bytes)));
}

export function sizeTreatment(rows) {
  const c = comparedSizes(rows);
  const sizes = [...new Set(c.map((r) => Number(r.size_bytes)))];
  const skips = rows.filter((r) => isShapeSkip(r));
  const gz = c.map((r) => r.size_gzip_bytes);
  const gzipNote =
    gz.length && gz.every((g) => g != null && Number(g) === Number(gz[0]))
      ? ` (${formatIntGrouped(gz[0])} after gzip)`
      : '';
  const skipNote =
    skips.length === 1 && skips[0].writes_named_fields === false
      ? ` ${skips[0].library} also ran (${formatIntGrouped(skips[0].size_bytes)} B). By design it writes a JSON list, not {"id": …}, so we do not rank it here.`
      : skips.length === 1
        ? ` ${skips[0].library} ran; we do not rank it in this contest.`
        : '';
  if (sizes.length <= 1 && c.length) {
    return {
      kind: 'S0',
      text: `Named JSON ${formatIntGrouped(sizes[0])} B${gzipNote}.${skipNote}`,
    };
  }
  if (sizes.length > 1) return { kind: 'S1' };
  return { kind: 'none' };
}

export function glyphFor(row, rows) {
  const tier = displayTier(row, rows);
  if (tier === 'skip') return '⬚';
  if (tier === 'fastest') return '●';
  if (tier === 'similar') return '○';
  if (tier === 'close') return '▬';
  if (tier === 'slower') return '×';
  return '·';
}

function clipTickPiece(s) {
  return s.length > 18 ? `${s.slice(0, 17)}…` : s;
}

function splitLibraryName(name) {
  const bySlash = name.split('/');
  if (bySlash.length > 1) {
    return [`${bySlash[0]}/`, bySlash.slice(1).join('/')];
  }
  const bySpace = name.split(/\s+/).filter(Boolean);
  if (bySpace.length > 1) {
    return [bySpace[0], bySpace.slice(1).join(' ')];
  }
  return [name];
}

export function wrapYTick(row, rows) {
  const prefix = `${glyphFor(row, rows)} `;
  const name = String(row.library || '');
  if ((prefix + name).length <= 22) return [prefix + name];
  const parts = splitLibraryName(name).map(clipTickPiece).slice(0, 2);
  if (!parts.length) return [prefix.trim()];
  parts[0] = prefix + parts[0];
  return parts;
}

function plotHeight(n) {
  return Math.max(280, n * 36 + 48);
}

function escapeHtml(s) {
  return String(s ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function bestCompared(rows, key) {
  const nums = competingRows(rows)
    .map((r) => Number(r[key]))
    .filter(Number.isFinite);
  return nums.length ? Math.min(...nums) : null;
}

function createHatch(color = '#b06000') {
  const c = document.createElement('canvas');
  c.width = 8;
  c.height = 8;
  const g = c.getContext('2d');
  g.fillStyle = '#fef7e0';
  g.fillRect(0, 0, 8, 8);
  g.strokeStyle = color;
  g.lineWidth = 1;
  g.beginPath();
  g.moveTo(0, 8);
  g.lineTo(8, 0);
  g.stroke();
  return g.createPattern(c, 'repeat');
}

function getHatch() {
  if (!hatchPattern && typeof document !== 'undefined') {
    hatchPattern = createHatch('#b06000');
  }
  return hatchPattern;
}

function l1Fill(row, rows) {
  const tier = displayTier(row, rows);
  if (tier === 'skip') return 'transparent';
  if (tier === 'fastest') return 'rgba(30, 142, 62, 0.90)';
  if (tier === 'similar') return 'rgba(30, 142, 62, 0.55)';
  if (tier === 'close') return getHatch() || 'rgba(249, 171, 0, 0.85)';
  if (tier === 'slower') return 'rgba(217, 48, 37, 0.78)';
  return 'rgba(95, 99, 104, 0.35)';
}

function l1Stroke(row, rows) {
  const tier = displayTier(row, rows);
  if (tier === 'skip') return 'rgba(128, 134, 139, 0.55)';
  if (tier === 'fastest' || tier === 'similar') return '#1e8e3e';
  if (tier === 'close') return '#b06000';
  if (tier === 'slower') return '#d93025';
  return '#5f6368';
}

function l1BorderDash(row) {
  if (isShapeSkip(row)) return [3, 2];
  if (totalStdUs(row) == null) return [4, 3];
  return [];
}

function parsedX(el) {
  if (Number.isFinite(el?.parsed?.x)) return el.parsed.x;
  if (Number.isFinite(el?.$context?.parsed?.x)) return el.$context.parsed.x;
  return null;
}

function makeErrorBarsPlugin(stds, datasetIndex = 0) {
  return {
    id: 'expErrorBars',
    afterDatasetsDraw(chart) {
      const { ctx } = chart;
      const meta = chart.getDatasetMeta(datasetIndex);
      if (!meta?.data) return;
      const xScale = chart.scales.x;
      if (!xScale) return;
      ctx.save();
      ctx.strokeStyle = 'rgba(32, 33, 36, 0.72)';
      ctx.lineWidth = 1.5;
      meta.data.forEach((el, i) => {
        const std = stds[i];
        if (std == null || !Number.isFinite(std)) return;
        const median = parsedX(el);
        if (!Number.isFinite(median)) return;
        let x0 = xScale.getPixelForValue(Math.max(0, median - std));
        let x1 = xScale.getPixelForValue(median + std);
        if (Math.abs(x1 - x0) < 4) {
          const mid = xScale.getPixelForValue(median);
          x0 = mid - 2;
          x1 = mid + 2;
        }
        const cap = 3.5;
        const y = el.y;
        ctx.beginPath();
        ctx.moveTo(x0, y);
        ctx.lineTo(x1, y);
        ctx.moveTo(x0, y - cap);
        ctx.lineTo(x0, y + cap);
        ctx.moveTo(x1, y - cap);
        ctx.lineTo(x1, y + cap);
        ctx.stroke();
      });
      ctx.restore();
    },
  };
}

function makeValueLabelsPlugin({ rows = [], stds = [], format = formatSig, datasetIndex = 0 } = {}) {
  return {
    id: 'expBarValueLabels',
    afterDatasetsDraw(chart) {
      const { ctx } = chart;
      const meta = chart.getDatasetMeta(datasetIndex);
      if (!meta?.data) return;
      const xScale = chart.scales.x;
      const area = chart.chartArea;
      if (!xScale || !area) return;
      ctx.save();
      ctx.font = "11px 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
      ctx.textBaseline = 'middle';
      ctx.fillStyle = '#202124';
      meta.data.forEach((el, i) => {
        const row = rows[i];
        const median = parsedX(el);
        if (!Number.isFinite(median)) return;
        if (row && isShapeSkip(row)) {
          const text = skipReason(row)?.short || 'left out of ranking';
          let x = Math.max(el.x, xScale.getPixelForValue(median)) + 16;
          ctx.fillStyle = '#80868b';
          if (x + ctx.measureText(text).width > area.right) {
            x = area.right - ctx.measureText(text).width;
          }
          ctx.fillText(text, x, el.y);
          ctx.fillStyle = '#202124';
          return;
        }
        let right = el.x;
        const std = stds[i];
        if (std != null && Number.isFinite(std)) {
          right = Math.max(right, xScale.getPixelForValue(median + std));
        }
        const text = format(median);
        let x = right + 8;
        if (x + ctx.measureText(text).width > area.right) {
          x = area.right - ctx.measureText(text).width;
        }
        ctx.fillText(text, x, el.y);
      });
      ctx.restore();
    },
  };
}

function figureHtml({ title, helpHtml, pngId, height, canvasLabel }) {
  return `
    <section class="exp-figure glass-panel">
      <div class="chart-header">
        <h3 class="chart-title">${escapeHtml(title)}</h3>
        ${pngId ? `<button type="button" class="tab-btn chart-tool-btn" id="${pngId}" title="Download PNG">PNG</button>` : ''}
      </div>
      <p class="exp-figure-help">${helpHtml}</p>
      <div class="exp-figure-plot" style="height:${height}px">
        <canvas role="img" aria-label="${escapeHtml(canvasLabel)}"></canvas>
      </div>
    </section>`;
}

function legendHtml(rows) {
  const skips = (rows || []).filter((r) => isShapeSkip(r));
  const skipChip = skips.length ? '⬚ Writes a JSON list' : '';
  return `
    <div class="exp-legend">
      <span class="exp-chip exp-tier-similar">● Fastest</span>
      <span class="exp-chip exp-tier-similar">○ About the same</span>
      <span class="exp-chip exp-tier-close">▬ A bit slower</span>
      <span class="exp-chip exp-tier-slower">× Clearly slower</span>
      ${skipChip ? `<span class="exp-chip" title="Timed, but not the same job as the ranked bars">${escapeHtml(skipChip)}</span>` : ''}
    </div>`;
}

function commonScaleX(title, tickFmt) {
  return {
    min: 0,
    stacked: false,
    title: {
      display: true,
      text: title,
      color: tickColor,
      font: { ...fontStyle, weight: 'bold' },
    },
    grid: { color: gridColor },
    ticks: {
      color: tickColor,
      font: fontStyle,
      callback: (value) => tickFmt(value),
    },
  };
}

function commonScaleY(rows) {
  return {
    stacked: false,
    grid: { display: false },
    afterFit(scale) {
      scale.width = Math.max(scale.width, 148);
    },
    ticks: {
      color: tickColor,
      font: fontStyle,
      autoSkip: false,
      callback(_value, index) {
        const row = rows[index];
        return row ? wrapYTick(row, rows) : '';
      },
    },
  };
}

function ratioText(valueNs, bestNs, key) {
  const us = formatSig(Number(valueNs) / 1000);
  if (valueNs == null || bestNs == null) return `${us} µs`;
  const rel = formatRelativeCell(valueNs, bestNs, false, { latency: LATENCY_US }, key);
  if (rel.ratio == null) return `${us} µs`;
  return `${us} µs  (${formatSig(rel.ratio, 2)}×)`;
}

function l1TooltipLines(row, bestTotal, rows) {
  const lines = [];
  const skip = skipReason(row);
  if (skip) lines.push(skip.detail);
  lines.push(`Write + read   ${ratioText(row.total_median_ns, bestTotal, 'total_median_ns')}`);
  const std = totalStdUs(row);
  lines.push(std == null ? 'Spread unknown (not enough trials to reconstruct).' : `Spread (std)   ${formatSig(std)} µs`);
  const w = Number(row.write_median_ns);
  const r = Number(row.read_median_ns);
  const wr = [];
  if (Number.isFinite(w)) wr.push(`Write  ${formatSig(w / 1000)} µs`);
  if (Number.isFinite(r)) wr.push(`Read  ${formatSig(r / 1000)} µs`);
  if (wr.length) lines.push(wr.join(' · '));
  if (row.size_bytes != null) {
    let size = `Size   ${formatIntGrouped(row.size_bytes)} B`;
    if (Number.isFinite(Number(row.size_gzip_bytes))) {
      size += `  (${formatIntGrouped(row.size_gzip_bytes)} after gzip)`;
    }
    lines.push(size);
  }
  if (row.runs != null) {
    lines.push(`Trials ${formatIntGrouped(row.runs)}${row.runs_raw ? ` of ${formatIntGrouped(row.runs_raw)}` : ''}`);
  }
  if (row.stream_kind) {
    const kind =
      row.stream_kind === 'real'
        ? 'real stream'
        : row.stream_kind === 'copied'
          ? 'copied onto a stream'
          : row.stream_kind === 'text_on_stream' || row.stream_kind === 'text on a stream'
            ? 'text on a stream'
            : String(row.stream_kind);
    lines.push(`How written  ${kind}`);
  }
  lines.push(`Vs fastest  ${compareLabel(row, rows)}`);
  return lines;
}

function makeBarChart(canvas, config, key) {
  const ctx = canvas.getContext ? canvas.getContext('2d') : canvas;
  const chart = new globalThis.Chart(ctx, config);
  chartInstances.push(chart);
  if (key) chartsByKey[key] = chart;
  return chart;
}

function suggestedMax(values, stds = []) {
  let m = 0;
  values.forEach((v, i) => {
    if (!Number.isFinite(v)) return;
    const s = Number.isFinite(stds[i]) ? stds[i] : 0;
    m = Math.max(m, v + s);
  });
  return m > 0 ? m * 1.12 : undefined;
}

function mountLatency(canvas, rows, lang) {
  const stds = rows.map(totalStdUs);
  const bestTotal = bestCompared(rows, 'total_median_ns');
  const values = rows.map((r) => Number(r.total_median_ns) / 1000);
  return makeBarChart(
    canvas,
    {
    type: 'bar',
    plugins: [
      makeErrorBarsPlugin(stds, 0),
      makeValueLabelsPlugin({ rows, stds, format: formatSig, datasetIndex: 0 }),
    ],
    data: {
      labels: rows.map((r) => r.library),
      datasets: [
        {
          data: values,
          backgroundColor: rows.map((r) => l1Fill(r, rows)),
          borderColor: rows.map((r) => l1Stroke(r, rows)),
          borderWidth: 1.5,
          borderDash: (ctx) => l1BorderDash(rows[ctx.dataIndex] || {}),
          borderRadius: 3,
          barPercentage: 0.72,
          categoryPercentage: 0.8,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      layout: { padding: { right: 108, left: 4, top: 4, bottom: 4 } },
      plugins: {
        legend: { display: false },
        tooltip: {
          ...tooltipChrome,
          callbacks: {
            title: (items) => {
              const row = rows[items[0]?.dataIndex];
              if (!row) return '';
              return row.version ? `${row.library}  ${row.version}` : row.library;
            },
            label: (item) => l1TooltipLines(rows[item.dataIndex], bestTotal, rows),
          },
        },
      },
      scales: {
        x: { ...commonScaleX('µs', formatSig), suggestedMax: suggestedMax(values, stds) },
        y: commonScaleY(rows),
      },
    },
    },
    'latency'
  );
}

function mountSplit(canvas, rows) {
  return makeBarChart(
    canvas,
    {
    type: 'bar',
    data: {
      labels: rows.map((r) => r.library),
      datasets: [
        {
          label: 'Write',
          data: rows.map((r) => Number(r.write_median_ns) / 1000),
          backgroundColor: SERIES_WRITE,
          borderColor: '#1565c0',
          borderWidth: 1,
          borderRadius: 3,
          barPercentage: 0.9,
          categoryPercentage: 0.65,
        },
        {
          label: 'Read',
          data: rows.map((r) => Number(r.read_median_ns) / 1000),
          backgroundColor: SERIES_READ,
          borderRadius: 3,
          barPercentage: 0.9,
          categoryPercentage: 0.65,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      layout: { padding: { right: 16, left: 4, top: 4, bottom: 4 } },
      plugins: {
        legend: { display: false },
        tooltip: {
          ...tooltipChrome,
          callbacks: {
            title: (items) => {
              const row = rows[items[0]?.dataIndex];
              return row?.library || '';
            },
            label: (item) => {
              const name = item.dataset.label;
              const v = item.parsed.x;
              return `${name}  ${Number.isFinite(v) ? formatSig(v) : '—'} µs`;
            },
          },
        },
      },
      scales: {
        x: { ...commonScaleX('µs', formatSig), stacked: false },
        y: { ...commonScaleY(rows), stacked: false },
      },
    },
    },
    'split'
  );
}

function sortRowsBySize(rows) {
  return [...rows].sort((a, b) => {
    const as = isShapeSkip(a) ? 1 : 0;
    const bs = isShapeSkip(b) ? 1 : 0;
    if (as !== bs) return as - bs;
    return (Number(a.size_bytes) || 1e18) - (Number(b.size_bytes) || 1e18);
  });
}

function mountSize(canvas, rows) {
  const sorted = sortRowsBySize(rows);
  const bestSize = bestCompared(sorted, 'size_bytes');
  return makeBarChart(
    canvas,
    {
    type: 'bar',
    plugins: [makeValueLabelsPlugin({ rows: sorted, stds: [], format: formatIntGrouped, datasetIndex: 0 })],
    data: {
      labels: sorted.map((r) => r.library),
      datasets: [
        {
          data: sorted.map((r) => Number(r.size_bytes)),
          backgroundColor: sorted.map((r) => l1Fill(r, sorted)),
          borderColor: sorted.map((r) => l1Stroke(r, sorted)),
          borderWidth: 1.5,
          borderDash: (ctx) => (isShapeSkip(sorted[ctx.dataIndex] || {}) ? [3, 2] : []),
          borderRadius: 3,
          barPercentage: 0.72,
          categoryPercentage: 0.8,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      animation: false,
      layout: { padding: { right: 72, left: 4, top: 4, bottom: 4 } },
      plugins: {
        legend: { display: false },
        tooltip: {
          ...tooltipChrome,
          callbacks: {
            title: (items) => sorted[items[0]?.dataIndex]?.library || '',
            label: (item) => {
              const row = sorted[item.dataIndex];
              const rel = formatRelativeCell(row.size_bytes, bestSize, false, {}, 'size_bytes');
              return `Size   ${rel.text}`;
            },
          },
        },
      },
      scales: {
        x: commonScaleX('bytes', formatIntGrouped),
        y: commonScaleY(sorted),
      },
    },
    },
    'size'
  );
}

function seriesChip(label, fill, ink, bg) {
  const text = ink || fill;
  const back = bg || '#f1f3f4';
  return `<span class="exp-chip exp-series-key" style="color:${text};background:${back}"><span class="exp-swatch" style="background:${fill};width:0.85rem;height:0.85rem" aria-hidden="true"></span>${escapeHtml(label)}</span>`;
}

function mountCompress(canvas, rows) {
  const sorted = sortRowsBySize(rows);
  const showZstd = sorted.some((r) => r.size_zstd_bytes != null);
  const datasets = [
    {
      label: 'Raw',
      data: sorted.map((r) => Number(r.size_bytes)),
      backgroundColor: '#5f6368',
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    },
    {
      label: 'gzip',
      data: sorted.map((r) => Number(r.size_gzip_bytes)),
      backgroundColor: '#1565c0',
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    },
  ];
  if (showZstd) {
    datasets.push({
      label: 'zstd',
      data: sorted.map((r) => Number(r.size_zstd_bytes)),
      backgroundColor: '#6a1b9a',
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    });
  }
  return makeBarChart(
    canvas,
    {
      type: 'bar',
      data: { labels: sorted.map((r) => r.library), datasets },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        layout: { padding: { right: 24, left: 4, top: 4, bottom: 4 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...tooltipChrome,
            callbacks: {
              title: (items) => sorted[items[0]?.dataIndex]?.library || '',
              label: (item) => {
                const v = item.parsed.x;
                return `${item.dataset.label}  ${Number.isFinite(v) ? formatIntGrouped(v) : '—'} B`;
              },
            },
          },
        },
        scales: {
          x: { ...commonScaleX('bytes', formatIntGrouped), stacked: false },
          y: { ...commonScaleY(sorted), stacked: false },
        },
      },
    },
    'compress'
  );
}

function mountSizeVsPoints(canvas, rows) {
  const points = uniqueValues(rows, 'points')
    .map(Number)
    .filter(Number.isFinite)
    .sort((a, b) => a - b);
  const libs = uniqueValues(rows, 'library');
  const datasets = libs.map((lib, i) => ({
    label: String(lib),
    data: points.map((p) => {
      const row = rows.find((r) => String(r.library) === String(lib) && Number(r.points) === p);
      const v = Number(row?.size_bytes);
      return Number.isFinite(v) ? v : null;
    }),
    borderColor: paletteAt(i).fill,
    backgroundColor: paletteAt(i).fill,
    tension: 0.15,
    spanGaps: true,
  }));
  return makeBarChart(
    canvas,
    {
      type: 'line',
      data: { labels: points.map(String), datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            ...tooltipChrome,
            callbacks: {
              label: (item) => {
                const v = item.parsed.y;
                return `${item.dataset.label}  ${Number.isFinite(v) ? formatIntGrouped(v) : '—'} B`;
              },
            },
          },
        },
        scales: {
          x: {
            title: { display: true, text: 'sensor readings', color: tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: gridColor },
            ticks: { color: tickColor, font: fontStyle },
          },
          y: {
            min: 0,
            title: { display: true, text: 'bytes', color: tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: gridColor },
            ticks: { color: tickColor, font: fontStyle, callback: (v) => formatIntGrouped(v) },
          },
        },
      },
    },
    'curve'
  );
}

function mountLatencyVsN(canvas, rows) {
  const libs = [];
  const byLib = new Map();
  for (const row of rows) {
    const name = String(row.library || '');
    if (!byLib.has(name)) {
      byLib.set(name, {});
      libs.push(name);
    }
    byLib.get(name)[String(row.n)] = row;
  }
  const sorted = [...libs].sort((a, b) => {
    const ta = Number(byLib.get(a)['1']?.total_median_ns) || 1e18;
    const tb = Number(byLib.get(b)['1']?.total_median_ns) || 1e18;
    return ta - tb;
  });
  const proxy = sorted.map((name) => byLib.get(name)['1'] || byLib.get(name)['100'] || { library: name });
  const series = [
    { n: '1', label: '1 record', color: SERIES_N1 },
    { n: '100', label: '100 records', color: SERIES_N100 },
  ];
  const datasets = series.map((s) => ({
    label: s.label,
    data: sorted.map((name) => {
      const v = Number(byLib.get(name)[s.n]?.total_median_ns);
      return Number.isFinite(v) ? v / 1000 : null;
    }),
    backgroundColor: s.color,
    borderRadius: 3,
    barPercentage: 0.9,
    categoryPercentage: 0.7,
  }));
  return makeBarChart(
    canvas,
    {
      type: 'bar',
      data: { labels: sorted, datasets },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        layout: { padding: { right: 24, left: 4, top: 4, bottom: 4 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...tooltipChrome,
            callbacks: {
              title: (items) => sorted[items[0]?.dataIndex] || '',
              label: (item) => {
                const v = item.parsed.x;
                return `${item.dataset.label}  ${Number.isFinite(v) ? formatSig(v) : '—'} µs`;
              },
            },
          },
        },
        scales: {
          x: { ...commonScaleX('µs', formatSig), stacked: false },
          y: { ...commonScaleY(proxy), stacked: false },
        },
      },
    },
    'vsn'
  );
}

function mountRankSlope(canvas, rows) {
  const kinds = uniqueValues(rows, 'kind');
  const libs = uniqueValues(rows, 'library');
  const rankByKind = new Map();
  for (const kind of kinds) {
    const slice = rows
      .filter((r) => String(r.kind) === String(kind) && Number.isFinite(Number(r.total_median_ns)))
      .sort((a, b) => Number(a.total_median_ns) - Number(b.total_median_ns));
    const ranks = new Map();
    slice.forEach((r, i) => ranks.set(String(r.library), i + 1));
    rankByKind.set(String(kind), ranks);
  }
  const labels = kinds.map((k) => KIND_AXIS[k] || String(k));
  const datasets = libs.map((lib, i) => ({
    label: String(lib),
    data: kinds.map((kind) => rankByKind.get(String(kind))?.get(String(lib)) ?? null),
    borderColor: paletteAt(i).fill,
    backgroundColor: paletteAt(i).fill,
    tension: 0.1,
    spanGaps: true,
  }));
  return makeBarChart(
    canvas,
    {
      type: 'line',
      data: { labels, datasets },
      options: {
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        plugins: {
          legend: { display: false },
          tooltip: {
            ...tooltipChrome,
            callbacks: {
              label: (item) => {
                const v = item.parsed.y;
                return `${item.dataset.label}  rank ${Number.isFinite(v) ? v : '—'}`;
              },
            },
          },
        },
        scales: {
          x: {
            title: { display: true, text: 'record shape', color: tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: gridColor },
            ticks: { color: tickColor, font: fontStyle },
          },
          y: {
            reverse: true,
            min: 1,
            title: { display: true, text: 'rank (1 = fastest)', color: tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: gridColor },
            ticks: { color: tickColor, font: fontStyle, stepSize: 1 },
          },
        },
      },
    },
    'ranks'
  );
}

/**
 * @param {HTMLElement} mount
 * @param {{ id: string, meta: object, lang: string, io: string, kind: string, n: string, rows: object[], allRows?: object[] }} ctx
 */
export function mountExperimentFigures(mount, ctx) {
  if (!mount) return;
  const rows = sortRows(ctx.rows || []);
  const allRows = ctx.allRows || rows;
  const match = { io: ctx.io, kind: ctx.kind, n: ctx.n };

  if (!rows.length && !allRows.length) {
    mount.innerHTML = `
      <div class="exp-figure glass-panel" style="position:relative;min-height:8rem">
        <p class="chart-empty">No rows for this filter.</p>
      </div>`;
    return;
  }

  if (typeof globalThis.Chart === 'undefined') {
    mount.innerHTML = `
      <div class="exp-figure glass-panel" style="position:relative;min-height:8rem">
        <p class="chart-empty">Graphs need Chart.js (CDN). The table below has the same numbers.</p>
      </div>`;
    return;
  }

  const types = figureTypesFor(ctx.id, rows, allRows);
  const lang = ctx.lang || 'this language';
  const h = plotHeight(Math.max(rows.length, 4));
  const parts = [];
  const builders = [];

  const writeReadHelp = `${seriesChip('Write', SERIES_WRITE, '#1565c0', '#e3f2fd')} ${seriesChip('Read', SERIES_READ, '#4a148c', '#f3e5f5')}`;

  for (const type of types) {
    if (type === 'L1') {
      const allSkipped = competingRows(rows).length === 0;
      parts.push(
        figureHtml({
          title: 'Write + read (µs)',
          helpHtml: `${L1_CAPTION}${allSkipped ? ' Nothing in this filter is in the comparison.' : ''}`,
          pngId: 'exp-png-latency',
          height: h,
          canvasLabel: `Horizontal bar chart of write-plus-read time in microseconds for ${lang}, whiskers show spread`,
        })
      );
      parts.push(legendHtml(rows));
      builders.push((canvas) => mountLatency(canvas, rows, lang));
    } else if (type === 'W1') {
      parts.push(
        figureHtml({
          title: 'Write and read, separately',
          helpHtml: writeReadHelp,
          pngId: 'exp-png-split',
          height: h,
          canvasLabel: `Grouped bar chart of write time and read time in microseconds for ${lang}`,
        })
      );
      builders.push((canvas) => mountSplit(canvas, rows));
    } else if (type === 'S0') {
      parts.push(`<p class="exp-size-callout">${escapeHtml(sizeTreatment(rows).text)}</p>`);
    } else if (type === 'S1') {
      parts.push(
        figureHtml({
          title: 'Size (bytes)',
          helpHtml: 'Smaller is more compact.',
          pngId: 'exp-png-size',
          height: h,
          canvasLabel: `Horizontal bar chart of payload size in bytes for ${lang}`,
        })
      );
      builders.push((canvas) => mountSize(canvas, rows));
    } else if (type === 'S2') {
      parts.push(
        figureHtml({
          title: 'Size raw and after compression (bytes)',
          helpHtml: `${seriesChip('Raw', '#5f6368', '#3c4043', '#eceff1')} ${seriesChip('gzip', '#1565c0', '#1565c0', '#e3f2fd')} ${seriesChip('zstd', '#6a1b9a', '#4a148c', '#f3e5f5')}`,
          pngId: 'exp-png-compress',
          height: h,
          canvasLabel: `Grouped bar chart of raw, gzip, and zstd size in bytes for ${lang}`,
        })
      );
      builders.push((canvas) => mountCompress(canvas, rows));
    } else if (type === 'C1') {
      const curveRows = rowsMatching(allRows, match, { n: true, kind: true });
      const nLib = uniqueValues(curveRows, 'library').length;
      parts.push(
        figureHtml({
          title: 'Size vs how many sensor readings',
          helpHtml: `Each line is one library. Smaller is more compact. The 128-byte and 512-byte marks are common packet limits.<br>${libraryChips(uniqueValues(curveRows, 'library'))}`,
          pngId: 'exp-png-curve',
          height: Math.max(320, 160 + nLib * 12),
          canvasLabel: `Line chart of payload size versus number of sensor readings for ${lang}`,
        })
      );
      builders.push((canvas) => mountSizeVsPoints(canvas, curveRows));
    } else if (type === 'C2') {
      const pairRows = rowsMatching(allRows, match, { n: true });
      const nLib = uniqueValues(pairRows, 'library').length;
      parts.push(
        figureHtml({
          title: 'One record vs one hundred (µs)',
          helpHtml: `${seriesChip('1 record', SERIES_N1, '#1565c0', '#e3f2fd')} ${seriesChip('100 records', SERIES_N100, '#3e2723', '#efebe9')}`,
          pngId: 'exp-png-vsn',
          height: plotHeight(nLib),
          canvasLabel: `Grouped bar chart of write-plus-read time at n=1 and n=100 for ${lang}`,
        })
      );
      builders.push((canvas) => mountLatencyVsN(canvas, pairRows));
    } else if (type === 'R1') {
      const rankRows = rowsMatching(allRows, match, { kind: true });
      const nLib = uniqueValues(rankRows, 'library').length;
      parts.push(
        figureHtml({
          title: 'Does the rank hold if the record changes?',
          helpHtml: `Each line is one library. Rank 1 is fastest. Lines that cross mean the winner depends on the record shape.<br>${libraryChips(uniqueValues(rankRows, 'library'))}`,
          pngId: 'exp-png-ranks',
          height: Math.max(340, 140 + nLib * 16),
          canvasLabel: `Slopegraph of library rank across record shapes for ${lang}`,
        })
      );
      builders.push((canvas) => mountRankSlope(canvas, rankRows));
    }
  }

  if (!parts.length) {
    mount.innerHTML = `
      <div class="exp-figure glass-panel" style="position:relative;min-height:8rem">
        <p class="chart-empty">No rows for this filter.</p>
      </div>`;
    return;
  }

  mount.innerHTML = parts.join('');
  const canvases = [...mount.querySelectorAll('canvas')];
  try {
    builders.forEach((build, i) => build(canvases[i]));
  } catch (err) {
    const plot = mount.querySelector('.exp-figure-plot');
    if (plot) {
      const p = document.createElement('p');
      p.className = 'exp-figure-help';
      p.textContent = `Chart failed: ${err.message}`;
      plot.appendChild(p);
    }
    console.warn('experiment figures', err);
  }
}
