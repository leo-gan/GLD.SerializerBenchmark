/**
 * Experiment figure catalog — PR 1 implements L1, W1, S0/S1 for opted-in ids.
 * Do not import charts.js or main.js.
 */
import { formatSig, formatIntGrouped, formatRelativeCell, LATENCY_US } from './format.js';
import { escapeHtml } from './page.js';
import { exportChartPngWithBg, isDarkTheme } from './theme.js';
import {
  compareLabel,
  competingRows,
  displayTier,
  isShapeSkip,
  mixedLanguages,
  normalizeShow,
  peerRows,
  rowsForShow,
  seriesStdUs,
  SHOW_VALUES,
  skipReason,
  sortRows,
  splitSortKey,
  totalStdUs,
} from './exp-export.js';

export const GRAPH_PROTOTYPE_IDS = new Set([
  '01-sensor-list-size',
  '02-compression-size',
  '03-memory-vs-stream',
  '04-fortran-ffi-tax',
]);

const KIND_AXIS = {
  document: 'one order',
  message: 'flat record',
  telemetry: 'sensor readings',
  event: 'one event',
  strings: 'list of words',
};

const SERIES_PALETTE_LIGHT = [
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

const SERIES_PALETTE_DARK = [
  { fill: '#7eb6ff', ink: '#a8cbff', bg: '#273549' },
  { fill: '#d7a88a', ink: '#e7c4ae', bg: '#372d29' },
  { fill: '#4dd0e1', ink: '#80deea', bg: '#22363c' },
  { fill: '#fdd663', ink: '#fde293', bg: '#383223' },
  { fill: '#90a4ae', ink: '#cfd8dc', bg: '#2c333b' },
  { fill: '#bcaaa4', ink: '#d7ccc8', bg: '#342e2d' },
  { fill: '#4fc3f7', ink: '#81d4fa', bg: '#213544' },
  { fill: '#c8a28b', ink: '#e0c2b0', bg: '#362c28' },
  { fill: '#b0bec5', ink: '#dce4e8', bg: '#2e343c' },
  { fill: '#26c6da', ink: '#80deea', bg: '#21353b' },
];

function paletteAt(i) {
  const list = isDarkTheme() ? SERIES_PALETTE_DARK : SERIES_PALETTE_LIGHT;
  return list[i % list.length];
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

function expTheme() {
  if (isDarkTheme()) {
    return {
      dark: true,
      gridColor: 'rgba(255, 255, 255, 0.08)',
      tickColor: '#a8b0be',
      valueLabelColor: '#e8eaed',
      skipLabelColor: '#9aa0a6',
      surfaceRgb: [33, 37, 47],
      whiskerInk: 'rgba(232, 234, 237, 0.85)',
      whiskerOnBright: '#181b22',
      whiskerOnDark: '#ffffff',
      hatchBg: '#383223',
      hatchStroke: '#fdd663',
      tierFill: {
        fastest: 'rgba(102, 187, 106, 0.88)',
        similar: 'rgba(102, 187, 106, 0.52)',
        closeFallback: 'rgba(253, 214, 99, 0.85)',
        slower: 'rgba(242, 139, 130, 0.82)',
        other: 'rgba(168, 176, 190, 0.35)',
      },
      tierStroke: {
        skip: 'rgba(168, 176, 190, 0.55)',
        fastest: '#81c995',
        close: '#fdd663',
        slower: '#f28b82',
        other: '#9aa0a6',
      },
      write: { fill: '#7eb6ff', border: '#90caf9', ink: '#a8cbff', bg: '#273549' },
      read: { fill: '#b388ff', ink: '#d1b3ff', bg: '#332847' },
      n1: { fill: '#7eb6ff', ink: '#a8cbff', bg: '#273549' },
      n100: { fill: '#d7a88a', ink: '#e7c4ae', bg: '#372d29' },
      compress: {
        raw: { fill: '#9aa0a6', ink: '#cfd4dc', bg: '#2d323d' },
        gzip: { fill: '#64b5f6', ink: '#90caf9', bg: '#253549' },
        zstd: { fill: '#ce93d8', ink: '#e1bee7', bg: '#352941' },
      },
      chipDefaultBg: '#2a2f3c',
      tooltip: {
        backgroundColor: 'rgba(16, 18, 24, 0.97)',
        titleColor: '#ffffff',
        bodyColor: '#ffffff',
        borderColor: '#4b5368',
        borderWidth: 1,
        padding: 10,
        bodyFont: fontStyle,
        titleFont: { ...fontStyle, weight: 'bold' },
      },
    };
  }
  return {
    dark: false,
    gridColor: 'rgba(0, 0, 0, 0.06)',
    tickColor: '#5f6368',
    valueLabelColor: '#202124',
    skipLabelColor: '#80868b',
    surfaceRgb: [255, 255, 255],
    whiskerInk: 'rgba(32, 33, 36, 0.72)',
    whiskerOnBright: 'rgba(32, 33, 36, 0.72)',
    whiskerOnDark: '#ffffff',
    hatchBg: '#fef7e0',
    hatchStroke: '#b06000',
    tierFill: {
      fastest: 'rgba(30, 142, 62, 0.90)',
      similar: 'rgba(30, 142, 62, 0.55)',
      closeFallback: 'rgba(249, 171, 0, 0.85)',
      slower: 'rgba(217, 48, 37, 0.78)',
      other: 'rgba(95, 99, 104, 0.35)',
    },
    tierStroke: {
      skip: 'rgba(128, 134, 139, 0.55)',
      fastest: '#1e8e3e',
      close: '#b06000',
      slower: '#d93025',
      other: '#5f6368',
    },
    /** Write vs read series — not green/red (those mean faster/slower). */
    write: { fill: '#7eb6ff', border: '#1565c0', ink: '#1565c0', bg: '#e3f2fd' },
    read: { fill: '#4a148c', ink: '#4a148c', bg: '#f3e5f5' },
    /** One series against another. The write/read pair is a different chart. */
    n1: { fill: '#7eb6ff', ink: '#1565c0', bg: '#e3f2fd' },
    n100: { fill: '#5d4037', ink: '#3e2723', bg: '#efebe9' },
    compress: {
      raw: { fill: '#5f6368', ink: '#3c4043', bg: '#eceff1' },
      gzip: { fill: '#1565c0', ink: '#1565c0', bg: '#e3f2fd' },
      zstd: { fill: '#6a1b9a', ink: '#4a148c', bg: '#f3e5f5' },
    },
    chipDefaultBg: '#f1f3f4',
    tooltip: {
      backgroundColor: 'rgba(32, 33, 36, 0.95)',
      titleColor: '#ffffff',
      bodyColor: '#ffffff',
      borderColor: '#dadce0',
      borderWidth: 1,
      padding: 10,
      bodyFont: fontStyle,
      titleFont: { ...fontStyle, weight: 'bold' },
    },
  };
}

const L1_CAPTION =
  'The bar is the <strong>middle</strong> time (median). The whisker is <strong>approximate spread</strong>, reconstructed from the published confidence interval of the <strong>mean</strong> (the same reconstruction the table’s Spread column uses). It is not yet the sample standard deviation of the trials. A short whisker means a stable number. Two bars whose whiskers heavily overlap are usually “about the same.”';

/** @type {import('chart.js').Chart[]} */
const chartInstances = [];
/** @type {Record<string, import('chart.js').Chart>} */
const chartsByKey = {};
const experimentBag = { list: chartInstances, keys: chartsByKey };
const compareBag = { list: [], keys: {} };
let activeBag = experimentBag;
const hatchPatterns = { light: null, dark: null };

/** User-facing title of the grouped write/read chart. */
export const SPLIT_CHART_TITLE = 'Write and Read';

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
  return exportChartPngWithBg(chartsByKey[which]);
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

function seriesKey(row) {
  if (row?.language) return `${row.language}\0${row.library || ''}`;
  return String(row?.library || '');
}

function seriesLabel(row) {
  return row?.label || (row?.language ? `${langAxis(row.language)} · ${row.library}` : String(row?.library || ''));
}

function uniqueSeriesKeys(rows) {
  const seen = [];
  const have = new Set();
  for (const row of rows || []) {
    const key = seriesKey(row);
    if (!key || have.has(key)) continue;
    have.add(key);
    seen.push({ key, label: seriesLabel(row), language: row.language, library: row.library });
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
export function figureTypesFor(id, rows, allRows, _opts = {}) {
  const view = rows || [];
  const types = [];
  if (id === '01-sensor-list-size') {
    types.push('C1');
    return types;
  }
  if (id === '02-compression-size') {
    types.push('S2');
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
  const name = String(row.label || row.library || '');
  if ((prefix + name).length <= 22) return [prefix + name];
  const parts = splitLibraryName(name).map(clipTickPiece).slice(0, 2);
  if (!parts.length) return [prefix.trim()];
  parts[0] = prefix + parts[0];
  return parts;
}

function plotHeight(n, compact = false) {
  return Math.max(280, n * (compact ? 26 : 36) + 48);
}

function bestCompared(rows, key) {
  const nums = competingRows(rows)
    .map((r) => Number(r[key]))
    .filter(Number.isFinite);
  return nums.length ? Math.min(...nums) : null;
}

function bestComparedPeers(row, rows, key) {
  return bestCompared(peerRows(row, rows), key);
}

const LANG_AXIS = {
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

function langAxis(id) {
  return LANG_AXIS[id] || String(id || '');
}

function rowTitle(row) {
  if (!row) return '';
  const name = row.label || row.library || '';
  return row.version ? `${name}  ${row.version}` : name;
}

function createHatch(bg, stroke) {
  const c = document.createElement('canvas');
  c.width = 8;
  c.height = 8;
  const g = c.getContext('2d');
  g.fillStyle = bg;
  g.fillRect(0, 0, 8, 8);
  g.strokeStyle = stroke;
  g.lineWidth = 1;
  g.beginPath();
  g.moveTo(0, 8);
  g.lineTo(8, 0);
  g.stroke();
  return g.createPattern(c, 'repeat');
}

function getHatch(t) {
  const key = t.dark ? 'dark' : 'light';
  if (!hatchPatterns[key] && typeof document !== 'undefined') {
    hatchPatterns[key] = createHatch(t.hatchBg, t.hatchStroke);
  }
  return hatchPatterns[key];
}

function l1Fill(row, rows) {
  const t = expTheme();
  const tier = displayTier(row, rows);
  if (tier === 'skip') return 'transparent';
  if (tier === 'fastest') return t.tierFill.fastest;
  if (tier === 'similar') return t.tierFill.similar;
  if (tier === 'close') return getHatch(t) || t.tierFill.closeFallback;
  if (tier === 'slower') return t.tierFill.slower;
  return t.tierFill.other;
}

function l1Stroke(row, rows) {
  const t = expTheme();
  const tier = displayTier(row, rows);
  if (tier === 'skip') return t.tierStroke.skip;
  if (tier === 'fastest' || tier === 'similar') return t.tierStroke.fastest;
  if (tier === 'close') return t.tierStroke.close;
  if (tier === 'slower') return t.tierStroke.slower;
  return t.tierStroke.other;
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

function colorLuminance(color, bgRgb = [255, 255, 255]) {
  const s = String(color || '').trim();
  const hex = s.match(/^#([0-9a-f]{6})$/i);
  const rgb = s.match(/^rgba?\(\s*([\d.]+)\s*,\s*([\d.]+)\s*,\s*([\d.]+)(?:\s*,\s*([\d.]+))?\s*\)$/i);
  let r;
  let g;
  let b;
  let a = 1;
  if (hex) {
    const n = parseInt(hex[1], 16);
    r = (n >> 16) & 255;
    g = (n >> 8) & 255;
    b = n & 255;
  } else if (rgb) {
    r = Number(rgb[1]);
    g = Number(rgb[2]);
    b = Number(rgb[3]);
    if (rgb[4] != null) a = Number(rgb[4]);
  } else {
    return bgRgb[0] < 128 ? 0.1 : 1;
  }
  r = r * a + bgRgb[0] * (1 - a);
  g = g * a + bgRgb[1] * (1 - a);
  b = b * a + bgRgb[2] * (1 - a);
  const lin = (c) => {
    const x = c / 255;
    return x <= 0.04045 ? x / 12.92 : ((x + 0.055) / 1.055) ** 2.4;
  };
  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

function barFillColor(dataset, index) {
  const bg = dataset?.backgroundColor;
  if (Array.isArray(bg)) return bg[index];
  return typeof bg === 'string' ? bg : '';
}

function strokeWhiskerPath(ctx, x0, x1, y, cap) {
  ctx.beginPath();
  ctx.moveTo(x0, y);
  ctx.lineTo(x1, y);
  ctx.moveTo(x0, y - cap);
  ctx.lineTo(x0, y + cap);
  ctx.moveTo(x1, y - cap);
  ctx.lineTo(x1, y + cap);
  ctx.stroke();
}

function strokeErrorBars(chart, stds, datasetIndex) {
  const { ctx } = chart;
  const meta = chart.getDatasetMeta(datasetIndex);
  if (!meta?.data) return;
  const xScale = chart.scales.x;
  if (!xScale) return;
  const dataset = chart.data.datasets[datasetIndex];
  const values = dataset?.data || [];
  const area = chart.chartArea;
  const t = expTheme();
  ctx.save();
  ctx.lineCap = 'butt';
  meta.data.forEach((el, i) => {
    const std = stds[i];
    if (std == null || !Number.isFinite(std)) return;
    // Grouped bars do not keep .parsed after layout. The dataset value is the median.
    const fromElement = parsedX(el);
    const median = Number.isFinite(fromElement) ? fromElement : Number(values[i]);
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
    const lum = colorLuminance(barFillColor(dataset, i), t.surfaceRgb);
    const needsOnBarContrast = t.dark ? lum > 0.35 : lum < 0.12;
    if (!needsOnBarContrast || !area || !Number.isFinite(el.x)) {
      ctx.strokeStyle = t.whiskerInk;
      ctx.lineWidth = 1.5;
      strokeWhiskerPath(ctx, x0, x1, y, cap);
      return;
    }
    // Paint the on-bar half in contrasting ink and keep the tail on the plot surface.
    const tip = el.x;
    const bandTop = y - cap - 3;
    const bandHeight = cap * 2 + 6;
    ctx.save();
    ctx.beginPath();
    ctx.rect(area.left, bandTop, Math.max(0, tip - area.left), bandHeight);
    ctx.clip();
    ctx.strokeStyle = t.dark ? t.whiskerOnBright : t.whiskerOnDark;
    ctx.lineWidth = 2.25;
    strokeWhiskerPath(ctx, x0, x1, y, cap);
    ctx.restore();
    ctx.save();
    ctx.beginPath();
    ctx.rect(tip, bandTop, Math.max(0, area.right - tip), bandHeight);
    ctx.clip();
    ctx.strokeStyle = t.whiskerInk;
    ctx.lineWidth = 1.5;
    strokeWhiskerPath(ctx, x0, x1, y, cap);
    ctx.restore();
  });
  ctx.restore();
}

function makeErrorBarsPlugin(stds, datasetIndex = 0) {
  const layers = Array.isArray(datasetIndex)
    ? datasetIndex.map((index, i) => ({ stds: stds[i] || [], index }))
    : [{ stds, index: datasetIndex }];
  return {
    id: 'expErrorBars',
    afterDatasetsDraw(chart) {
      layers.forEach((layer) => strokeErrorBars(chart, layer.stds, layer.index));
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
      const t = expTheme();
      ctx.save();
      ctx.font = "11px 'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif";
      ctx.textBaseline = 'middle';
      ctx.fillStyle = t.valueLabelColor;
      meta.data.forEach((el, i) => {
        const row = rows[i];
        const median = parsedX(el);
        if (!Number.isFinite(median)) return;
        if (row && isShapeSkip(row)) {
          const text = skipReason(row)?.short || 'left out of ranking';
          let x = Math.max(el.x, xScale.getPixelForValue(median)) + 16;
          ctx.fillStyle = t.skipLabelColor;
          if (x + ctx.measureText(text).width > area.right) {
            x = area.right - ctx.measureText(text).width;
          }
          ctx.fillText(text, x, el.y);
          ctx.fillStyle = t.valueLabelColor;
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

function figureHtml({ title, helpHtml, pngId, height, canvasLabel, toolbarHtml = '', scroll = false }) {
  const plot = `<div class="exp-figure-plot" style="height:${height}px">
        <canvas role="img" aria-label="${escapeHtml(canvasLabel)}"></canvas>
      </div>`;
  return `
    <section class="exp-figure glass-panel">
      <div class="chart-header">
        <h3 class="chart-title">${escapeHtml(title)}</h3>
        <div class="exp-figure-actions">
          ${toolbarHtml}
          ${pngId ? `<button type="button" class="tab-btn chart-tool-btn" id="${pngId}" title="Download PNG">PNG</button>` : ''}
        </div>
      </div>
      <p class="exp-figure-help">${helpHtml}</p>
      ${scroll ? `<div class="exp-figure-scroll">${plot}</div>` : plot}
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
  const t = expTheme();
  return {
    min: 0,
    stacked: false,
    title: {
      display: true,
      text: title,
      color: t.tickColor,
      font: { ...fontStyle, weight: 'bold' },
    },
    grid: { color: t.gridColor },
    ticks: {
      color: t.tickColor,
      font: fontStyle,
      callback: (value) => tickFmt(value),
    },
  };
}

function commonScaleY(rows) {
  const t = expTheme();
  const wide = mixedLanguages(rows) || (rows || []).some((r) => r.label);
  return {
    stacked: false,
    grid: { display: false },
    afterFit(scale) {
      scale.width = Math.max(scale.width, wide ? 188 : 148);
    },
    ticks: {
      color: t.tickColor,
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
  const best = bestTotal ?? bestComparedPeers(row, rows, 'total_median_ns');
  lines.push(`Write + read   ${ratioText(row.total_median_ns, best, 'total_median_ns')}`);
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
  activeBag.list.push(chart);
  if (key) activeBag.keys[key] = chart;
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

function mountRelative(canvas, rows) {
  const values = rows.map((r) => {
    const best = bestComparedPeers(r, rows, 'total_median_ns');
    const v = Number(r.total_median_ns);
    if (!Number.isFinite(v) || !Number.isFinite(best) || best <= 0) return null;
    return v / best;
  });
  const stds = rows.map((r) => {
    const std = totalStdUs(r);
    const best = bestComparedPeers(r, rows, 'total_median_ns');
    if (std == null || !Number.isFinite(best) || best <= 0) return null;
    return std / (best / 1000);
  });
  return makeBarChart(
    canvas,
    {
      type: 'bar',
      plugins: [
        makeErrorBarsPlugin(stds, 0),
        makeValueLabelsPlugin({ rows, stds, format: (v) => `${formatSig(v, 2)}×`, datasetIndex: 0 }),
      ],
      data: {
        labels: rows.map((r) => r.label || r.library),
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
        layout: { padding: { right: 72, left: 4, top: 4, bottom: 4 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...expTheme().tooltip,
            callbacks: {
              title: (items) => rowTitle(rows[items[0]?.dataIndex]),
              label: (item) => l1TooltipLines(rows[item.dataIndex], null, rows),
            },
          },
        },
        scales: {
          x: {
            ...commonScaleX('× that language’s fastest', (v) => `${formatSig(v, 2)}×`),
            suggestedMax: suggestedMax(values, stds),
          },
          y: commonScaleY(rows),
        },
      },
    },
    'relative'
  );
}

function mountLatency(canvas, rows, lang) {
  const stds = rows.map(totalStdUs);
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
          ...expTheme().tooltip,
          callbacks: {
            title: (items) => rowTitle(rows[items[0]?.dataIndex]),
            label: (item) => l1TooltipLines(rows[item.dataIndex], null, rows),
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

function seriesValuesUs(rows, key) {
  return rows.map((r) => {
    const n = Number(r[key]);
    return Number.isFinite(n) ? n / 1000 : null;
  });
}

function mountSplit(canvas, rows, { write = true, read = true } = {}) {
  const grouped = write && read;
  const barPercentage = grouped ? 0.9 : 0.72;
  const categoryPercentage = grouped ? 0.65 : 0.8;
  const datasets = [];
  const stdLayers = [];
  const stdIndexes = [];
  const scaleValues = [];
  const scaleStds = [];
  const pushSeries = (label, key, kind, style) => {
    const values = seriesValuesUs(rows, key);
    const stds = rows.map((r) => seriesStdUs(r, kind));
    datasets.push({
      label,
      data: values,
      ...style,
      borderRadius: 3,
      barPercentage,
      categoryPercentage,
    });
    stdLayers.push(stds);
    stdIndexes.push(datasets.length - 1);
    values.forEach((v, i) => {
      scaleValues.push(v);
      scaleStds.push(stds[i]);
    });
  };
  const t = expTheme();
  if (write) {
    pushSeries('Write', 'write_median_ns', 'write', {
      backgroundColor: t.write.fill,
      borderColor: t.write.border,
      borderWidth: 1,
    });
  }
  if (read) {
    pushSeries('Read', 'read_median_ns', 'read', {
      backgroundColor: t.read.fill,
    });
  }
  if (!datasets.length) return null;
  const stdByLabel = {};
  datasets.forEach((dataset, i) => {
    stdByLabel[dataset.label] = stdLayers[i];
  });
  return makeBarChart(
    canvas,
    {
    type: 'bar',
    plugins: [makeErrorBarsPlugin(stdLayers, stdIndexes)],
    data: {
      labels: rows.map((r) => seriesLabel(r)),
      datasets,
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
          ...t.tooltip,
          callbacks: {
            title: (items) => rowTitle(rows[items[0]?.dataIndex]),
            label: (item) => {
              const name = item.dataset.label;
              const v = item.parsed.x;
              const lines = [`${name}  ${Number.isFinite(v) ? formatSig(v) : '—'} µs`];
              const std = (stdByLabel[name] || [])[item.dataIndex];
              if (std != null && Number.isFinite(std)) lines.push(`Spread (std)  ${formatSig(std)} µs`);
              return lines;
            },
          },
        },
      },
      scales: {
        x: {
          ...commonScaleX('µs', formatSig),
          stacked: false,
          suggestedMax: suggestedMax(scaleValues, scaleStds),
        },
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
      labels: sorted.map((r) => r.label || r.library),
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
          ...expTheme().tooltip,
          callbacks: {
            title: (items) => rowTitle(sorted[items[0]?.dataIndex]),
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
  const back = bg || expTheme().chipDefaultBg;
  return `<span class="exp-chip exp-series-key" style="color:${text};background:${back}"><span class="exp-swatch" style="background:${fill};width:0.85rem;height:0.85rem" aria-hidden="true"></span>${escapeHtml(label)}</span>`;
}

function mountCompress(canvas, rows) {
  const t = expTheme();
  const sorted = sortRowsBySize(rows);
  const showZstd = sorted.some((r) => r.size_zstd_bytes != null);
  const datasets = [
    {
      label: 'Raw',
      data: sorted.map((r) => Number(r.size_bytes)),
      backgroundColor: t.compress.raw.fill,
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    },
    {
      label: 'gzip',
      data: sorted.map((r) => Number(r.size_gzip_bytes)),
      backgroundColor: t.compress.gzip.fill,
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    },
  ];
  if (showZstd) {
    datasets.push({
      label: 'zstd',
      data: sorted.map((r) => Number(r.size_zstd_bytes)),
      backgroundColor: t.compress.zstd.fill,
      borderRadius: 3,
      barPercentage: 0.9,
      categoryPercentage: 0.7,
    });
  }
  return makeBarChart(
    canvas,
    {
      type: 'bar',
      data: { labels: sorted.map((r) => r.label || r.library), datasets },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        layout: { padding: { right: 24, left: 4, top: 4, bottom: 4 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...t.tooltip,
            callbacks: {
              title: (items) => rowTitle(sorted[items[0]?.dataIndex]),
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

function mountSizeVsPoints(canvas, rows, { byLanguage = false } = {}) {
  const t = expTheme();
  const points = uniqueValues(rows, 'points')
    .map(Number)
    .filter(Number.isFinite)
    .sort((a, b) => a - b);
  const seriesIds = byLanguage ? uniqueValues(rows, 'language') : uniqueValues(rows, 'library');
  const datasets = seriesIds.map((id, i) => ({
    label: byLanguage ? langAxis(id) : String(id),
    data: points.map((p) => {
      if (byLanguage) {
        const slice = rows.filter(
          (r) => r.language === id && Number(r.points) === p && Number.isFinite(Number(r.size_bytes))
        );
        const pool = competingRows(slice);
        const sizes = (pool.length ? pool : slice).map((r) => Number(r.size_bytes));
        return sizes.length ? Math.min(...sizes) : null;
      }
      const row = rows.find((r) => String(r.library) === String(id) && Number(r.points) === p);
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
            ...t.tooltip,
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
            title: { display: true, text: 'sensor readings', color: t.tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: t.gridColor },
            ticks: { color: t.tickColor, font: fontStyle },
          },
          y: {
            min: 0,
            title: { display: true, text: 'bytes', color: t.tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: t.gridColor },
            ticks: { color: t.tickColor, font: fontStyle, callback: (v) => formatIntGrouped(v) },
          },
        },
      },
    },
    'curve'
  );
}

function mountLatencyVsN(canvas, rows) {
  const t = expTheme();
  const keys = [];
  const byKey = new Map();
  for (const row of rows) {
    const key = seriesKey(row);
    if (!byKey.has(key)) {
      byKey.set(key, {});
      keys.push(key);
    }
    byKey.get(key)[String(row.n)] = row;
  }
  const sorted = [...keys].sort((a, b) => {
    const ta = Number(byKey.get(a)['1']?.total_median_ns) || 1e18;
    const tb = Number(byKey.get(b)['1']?.total_median_ns) || 1e18;
    return ta - tb;
  });
  const proxy = sorted.map((key) => {
    const row = byKey.get(key)['1'] || byKey.get(key)['100'] || { library: key };
    return { ...row, label: seriesLabel(row) };
  });
  const series = [
    { n: '1', label: '1 record', color: t.n1.fill },
    { n: '100', label: '100 records', color: t.n100.fill },
  ];
  const datasets = series.map((s) => ({
    label: s.label,
    data: sorted.map((key) => {
      const v = Number(byKey.get(key)[s.n]?.total_median_ns);
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
      data: { labels: proxy.map((r) => r.label || r.library), datasets },
      options: {
        indexAxis: 'y',
        responsive: true,
        maintainAspectRatio: false,
        animation: false,
        layout: { padding: { right: 24, left: 4, top: 4, bottom: 4 } },
        plugins: {
          legend: { display: false },
          tooltip: {
            ...t.tooltip,
            callbacks: {
              title: (items) => rowTitle(proxy[items[0]?.dataIndex]),
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
  const t = expTheme();
  const kinds = uniqueValues(rows, 'kind');
  const series = uniqueSeriesKeys(rows);
  const byLang = mixedLanguages(rows);
  const rankByKind = new Map();
  for (const kind of kinds) {
    const ranks = new Map();
    const timed = rows.filter(
      (r) => String(r.kind) === String(kind) && Number.isFinite(Number(r.total_median_ns))
    );
    const groups = byLang ? uniqueValues(timed, 'language') : [null];
    for (const lang of groups) {
      const slice = timed
        .filter((r) => (lang == null ? true : r.language === lang))
        .sort((a, b) => Number(a.total_median_ns) - Number(b.total_median_ns));
      slice.forEach((r, i) => ranks.set(seriesKey(r), i + 1));
    }
    rankByKind.set(String(kind), ranks);
  }
  const labels = kinds.map((k) => KIND_AXIS[k] || String(k));
  const datasets = series.map((s, i) => ({
    label: s.label,
    data: kinds.map((kind) => rankByKind.get(String(kind))?.get(s.key) ?? null),
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
            ...t.tooltip,
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
            title: { display: true, text: 'record shape', color: t.tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: t.gridColor },
            ticks: { color: t.tickColor, font: fontStyle },
          },
          y: {
            reverse: true,
            min: 1,
            title: { display: true, text: 'rank (1 = fastest)', color: t.tickColor, font: { ...fontStyle, weight: 'bold' } },
            grid: { color: t.gridColor },
            ticks: { color: t.tickColor, font: fontStyle, stepSize: 1 },
          },
        },
      },
    },
    'ranks'
  );
}

function showToolsHtml(selectId, show) {
  const cur = normalizeShow(show);
  const options = SHOW_VALUES
    .map((v) => `<option value="${escapeHtml(v)}"${v === cur ? ' selected' : ''}>${escapeHtml(v)}</option>`)
    .join('');
  return `<div class="exp-figure-tools">
    <label class="filter-label" for="${selectId}">Show</label>
    <div class="select-wrapper">
      <select id="${selectId}" aria-label="Show">${options}</select>
    </div>
    <span class="exp-figure-tools-note">Top is fastest. Bottom is slowest.</span>
  </div>`;
}

function seriesToggleHtml(prefix, writeOn, readOn) {
  const button = (suffix, on, label) => {
    const pressed = on ? 'true' : 'false';
    const active = on ? ' active' : '';
    return `<button type="button" class="tab-btn chart-tool-btn${active}" id="${prefix}-${suffix}" aria-pressed="${pressed}">${label}</button>`;
  };
  return `<div class="exp-series-toggles" role="group" aria-label="Write and Read">${button('write', writeOn, 'Write')}${button('read', readOn, 'Read')}</div>`;
}

function splitHelp(writeOn, readOn) {
  const t = expTheme();
  const chips = [];
  if (writeOn) chips.push(seriesChip('Write', t.write.fill, t.write.ink, t.write.bg));
  if (readOn) chips.push(seriesChip('Read', t.read.fill, t.read.ink, t.read.bg));
  const sort =
    writeOn && readOn ? 'Sorted by write + read.' : writeOn ? 'Sorted by write.' : 'Sorted by read.';
  return `${chips.join(' ')} ${sort} The whisker is the spread of that bar, drawn the same way as on Write + read.`;
}

function emptyFigure(title) {
  return `<section class="exp-figure glass-panel"><h3 class="chart-title">${escapeHtml(title)}</h3><p class="chart-empty">No rows for this Show value.</p></section>`;
}

function visibleSeries(writeOn, readOn) {
  const write = writeOn !== false;
  const read = readOn !== false;
  if (!write && !read) return { writeOn: true, readOn: true };
  return { writeOn: write, readOn: read };
}

/**
 * Write + read and Write and Read. Inserted where the first of those figures belongs.
 * @param {string[]} parts
 * @param {Function[]} builders
 */
function appendWriteRead(parts, builders, cfg) {
  const {
    l1Rows,
    w1Rows,
    showL1,
    showW1,
    writeOn,
    readOn,
    crossLang,
    lang,
    pngLatency,
    pngSplit,
    togglePrefix,
    scroll,
    toolsSelectId,
    show,
    lead,
    caption,
  } = cfg;
  if (lead) parts.push(`<p class="section-help compare-figures-lead">${lead}</p>`);
  if (toolsSelectId) parts.push(showToolsHtml(toolsSelectId, show));
  const allAxisNote = crossLang
    ? ' Every language shares this <strong>microsecond</strong> axis, so you can compare runtimes. Color is still vs that language’s fastest.'
    : '';
  if (showL1) {
    if (!l1Rows.length) {
      parts.push(emptyFigure('Write + read (µs)'));
    } else {
      const allSkipped = competingRows(l1Rows).length === 0;
      parts.push(
        figureHtml({
          title: 'Write + read (µs)',
          helpHtml: `${caption || L1_CAPTION}${allAxisNote}${allSkipped ? ' Nothing in this filter is in the comparison.' : ''}`,
          pngId: pngLatency,
          height: plotHeight(Math.max(l1Rows.length, 4), crossLang),
          canvasLabel: `Horizontal bar chart of write-plus-read time in microseconds for ${lang}, whiskers show spread`,
          scroll,
        })
      );
      parts.push(legendHtml(l1Rows));
      builders.push((canvas) => mountLatency(canvas, l1Rows, lang));
    }
  }
  if (showW1) {
    if (!w1Rows.length) {
      parts.push(emptyFigure(SPLIT_CHART_TITLE));
    } else {
      const what = writeOn && readOn ? 'write time and read time' : writeOn ? 'write time' : 'read time';
      parts.push(
        figureHtml({
          title: SPLIT_CHART_TITLE,
          helpHtml: splitHelp(writeOn, readOn),
          pngId: pngSplit,
          height: plotHeight(Math.max(w1Rows.length, 4), crossLang),
          canvasLabel: `Bar chart of ${what} in microseconds for ${lang}, whiskers show spread`,
          toolbarHtml: togglePrefix ? seriesToggleHtml(togglePrefix, writeOn, readOn) : '',
          scroll,
        })
      );
      builders.push((canvas) => mountSplit(canvas, w1Rows, { write: writeOn, read: readOn }));
    }
  }
}

/**
 * @param {HTMLElement} mount
 * @param {{ id: string, meta: object, lang: string, io: string, kind: string, n: string, rows: object[], allRows?: object[], crossLang?: boolean, show?: string, writeOn?: boolean, readOn?: boolean }} ctx
 */
export function mountExperimentFigures(mount, ctx) {
  if (!mount) return;
  const rows = sortRows(ctx.rows || []);
  const allRows = ctx.allRows || rows;
  const match = { io: ctx.io, kind: ctx.kind, n: ctx.n };
  const crossLang = Boolean(ctx.crossLang);

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

  const types = figureTypesFor(ctx.id, rows, allRows, { crossLang });
  const lang = crossLang ? 'every language' : ctx.lang || 'this language';
  const h = plotHeight(Math.max(rows.length, 4), crossLang);
  const parts = [];
  const builders = [];
  const series = visibleSeries(ctx.writeOn, ctx.readOn);
  const show = normalizeShow(ctx.show);
  const l1Rows = rowsForShow(rows, show, 'total_median_ns');
  const w1Rows = rowsForShow(rows, show, splitSortKey(series));
  const sizeRows = types.includes('L1') ? l1Rows : w1Rows;
  let latencyPlaced = false;
  let sizePlaced = false;

  for (const type of types) {
    if (type === 'L1' || type === 'W1') {
      if (!latencyPlaced) {
        latencyPlaced = true;
        appendWriteRead(parts, builders, {
          l1Rows,
          w1Rows,
          showL1: types.includes('L1'),
          showW1: types.includes('W1'),
          writeOn: series.writeOn,
          readOn: series.readOn,
          crossLang,
          lang,
          pngLatency: 'exp-png-latency',
          pngSplit: 'exp-png-split',
          togglePrefix: 'exp-toggle',
          scroll: false,
          toolsSelectId: 'exp-show',
          show,
        });
      }
    } else if (type === 'S0' || type === 'S1') {
      if (sizePlaced) continue;
      sizePlaced = true;
      const treatment = sizeTreatment(sizeRows);
      if (treatment.kind === 'S0') {
        parts.push(`<p class="exp-size-callout">${escapeHtml(treatment.text)}</p>`);
      } else if (treatment.kind === 'S1') {
        parts.push(
          figureHtml({
            title: 'Size (bytes)',
            helpHtml: 'Smaller is more compact.',
            pngId: 'exp-png-size',
            height: plotHeight(Math.max(sizeRows.length, 4), crossLang),
            canvasLabel: `Horizontal bar chart of payload size in bytes for ${lang}`,
          })
        );
        builders.push((canvas) => mountSize(canvas, sizeRows));
      }
    } else if (type === 'S2') {
      const c = expTheme().compress;
      parts.push(
        figureHtml({
          title: 'Size raw and after compression (bytes)',
          helpHtml: `${seriesChip('Raw', c.raw.fill, c.raw.ink, c.raw.bg)} ${seriesChip('gzip', c.gzip.fill, c.gzip.ink, c.gzip.bg)} ${seriesChip('zstd', c.zstd.fill, c.zstd.ink, c.zstd.bg)}`,
          pngId: 'exp-png-compress',
          height: h,
          canvasLabel: `Grouped bar chart of raw, gzip, and zstd size in bytes for ${lang}`,
        })
      );
      builders.push((canvas) => mountCompress(canvas, rows));
    } else if (type === 'C1') {
      const curveRows = rowsMatching(allRows, match, { n: true, kind: true });
      const byLanguage = crossLang && uniqueValues(curveRows, 'language').length > 1;
      const series = byLanguage ? uniqueValues(curveRows, 'language').map(langAxis) : uniqueValues(curveRows, 'library');
      parts.push(
        figureHtml({
          title: byLanguage ? 'Smallest size vs how many sensor readings' : 'Size vs how many sensor readings',
          helpHtml: byLanguage
            ? `Each line is one language’s <strong>smallest</strong> payload. Size is the fair number across languages. The 128-byte and 512-byte marks are common packet limits.<br>${libraryChips(series)}`
            : `Each line is one library. Smaller is more compact. The 128-byte and 512-byte marks are common packet limits.<br>${libraryChips(series)}`,
          pngId: 'exp-png-curve',
          height: Math.max(320, 160 + series.length * 12),
          canvasLabel: byLanguage
            ? 'Line chart of smallest payload size versus number of sensor readings in each language'
            : `Line chart of payload size versus number of sensor readings for ${lang}`,
        })
      );
      builders.push((canvas) => mountSizeVsPoints(canvas, curveRows, { byLanguage }));
    } else if (type === 'C2') {
      const t = expTheme();
      const pairRows = rowsMatching(allRows, match, { n: true });
      const nSeries = uniqueSeriesKeys(pairRows).length;
      parts.push(
        figureHtml({
          title: 'One record vs one hundred (µs)',
          helpHtml: `${seriesChip('1 record', t.n1.fill, t.n1.ink, t.n1.bg)} ${seriesChip('100 records', t.n100.fill, t.n100.ink, t.n100.bg)}${crossLang ? ' Every language shares this microsecond axis.' : ''}`,
          pngId: 'exp-png-vsn',
          height: plotHeight(nSeries, crossLang),
          canvasLabel: `Grouped bar chart of write-plus-read time at n=1 and n=100 for ${lang}`,
        })
      );
      builders.push((canvas) => mountLatencyVsN(canvas, pairRows));
    } else if (type === 'R1') {
      const rankRows = rowsMatching(allRows, match, { kind: true });
      const series = uniqueSeriesKeys(rankRows);
      parts.push(
        figureHtml({
          title: 'Does the rank hold if the record changes?',
          helpHtml: `Each line is one library${crossLang ? ' in one language' : ''}. Rank 1 is fastest <em>in that language</em>. Lines that cross mean the winner depends on the record shape.<br>${libraryChips(series.map((s) => s.label))}`,
          pngId: 'exp-png-ranks',
          height: Math.max(340, 140 + series.length * 16),
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

function clearBag(bag) {
  for (const chart of bag.list) {
    try {
      chart.destroy();
    } catch (_) {
      /* already gone */
    }
  }
  bag.list.length = 0;
  for (const k of Object.keys(bag.keys)) delete bag.keys[k];
}

export function destroyCompareFigures() {
  clearBag(compareBag);
}

export function resizeCompareFigures() {
  for (const chart of compareBag.list) {
    try {
      chart.resize();
    } catch (_) {
      /* hidden or already gone */
    }
  }
}

export function compareFigurePng(which) {
  return exportChartPngWithBg(compareBag.keys[which]);
}

/**
 * Compare page: the same Write + read and Write and Read charts.
 * `rows` use the experiment row shape (write_median_ns, read_median_ns, total_median_ns).
 */
export function mountCompareLatency(mount, rows, opts = {}) {
  destroyCompareFigures();
  if (!mount) return;
  const list = rows || [];
  const series = visibleSeries(opts.writeOn, opts.readOn);
  const show = normalizeShow(opts.show);
  const crossLang = Boolean(opts.crossLang);
  const lang = opts.lang || (crossLang ? 'every language' : 'this language');
  if (typeof globalThis.Chart === 'undefined') {
    mount.innerHTML = `
      <div class="exp-figure glass-panel" style="position:relative;min-height:8rem">
        <p class="chart-empty">Graphs need Chart.js (CDN).</p>
      </div>`;
    return;
  }
  const parts = [];
  const builders = [];
  if (!list.length) {
    if (opts.lead) parts.push(`<p class="section-help compare-figures-lead">${opts.lead}</p>`);
    parts.push(showToolsHtml(opts.selectId || 'compare-show', show));
    parts.push(`<div class="exp-figure glass-panel"><p class="chart-empty">No measured serializers in this filter.</p></div>`);
    mount.innerHTML = parts.join('');
    return;
  }
  const prev = activeBag;
  activeBag = compareBag;
  try {
    appendWriteRead(parts, builders, {
      l1Rows: rowsForShow(list, show, 'total_median_ns'),
      w1Rows: rowsForShow(list, show, splitSortKey(series)),
      showL1: true,
      showW1: true,
      writeOn: series.writeOn,
      readOn: series.readOn,
      crossLang,
      lang,
      pngLatency: opts.pngLatency || 'compare-png-latency',
      pngSplit: opts.pngSplit || 'compare-png-split',
      togglePrefix: opts.togglePrefix || 'compare-toggle',
      scroll: opts.scroll !== false,
      toolsSelectId: opts.selectId || 'compare-show',
      show,
      lead: opts.lead || '',
      caption:
        'The bar is the <strong>middle</strong> time (median). The whisker is the <strong>spread</strong> (standard deviation) of the trials kept by Samples. A short whisker means a stable number.',
    });
    mount.innerHTML = parts.join('');
    const canvases = [...mount.querySelectorAll('canvas')];
    builders.forEach((build, i) => build(canvases[i]));
  } catch (err) {
    console.warn('compare figures', err);
    const p = document.createElement('p');
    p.className = 'exp-figure-help';
    p.textContent = `Chart failed: ${err.message}`;
    mount.appendChild(p);
  } finally {
    activeBag = prev;
  }
}
