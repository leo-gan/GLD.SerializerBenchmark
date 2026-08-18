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

export const GRAPH_PROTOTYPE_IDS = new Set(['01-json-library-bakeoff']);

const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11,
};
const gridColor = 'rgba(0, 0, 0, 0.06)';
const tickColor = '#5f6368';
/** Write vs read series — not green/red (those mean faster/slower). */
const SERIES_WRITE = '#7eb6ff';
const SERIES_READ = '#4a148c';
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
let latencyChart = null;
let splitChart = null;
let sizeChart = null;
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
  latencyChart = null;
  splitChart = null;
  sizeChart = null;
}

export function figuresToPng(which) {
  const chart = which === 'latency' ? latencyChart : which === 'split' ? splitChart : sizeChart;
  if (!chart) return null;
  return chart.toBase64Image('image/png', 1);
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
  lines.push(`Vs fastest  ${compareLabel(row, rows)}`);
  return lines;
}

function makeBarChart(canvas, config) {
  const ctx = canvas.getContext ? canvas.getContext('2d') : canvas;
  const chart = new globalThis.Chart(ctx, config);
  chartInstances.push(chart);
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
  return makeBarChart(canvas, {
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
  });
}

function mountSplit(canvas, rows) {
  return makeBarChart(canvas, {
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
  });
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
  return makeBarChart(canvas, {
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
  });
}

function hasFiniteSeries(rows, key) {
  return rows.some((r) => Number.isFinite(Number(r[key])));
}

/**
 * @param {HTMLElement} mount
 * @param {{ id: string, meta: object, lang: string, io: string, rows: object[] }} ctx
 */
export function mountExperimentFigures(mount, ctx) {
  if (!mount) return;
  const rows = sortRows(ctx.rows || []);
  latencyChart = null;
  splitChart = null;
  sizeChart = null;

  if (!rows.length) {
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

  const allSkipped = competingRows(rows).length === 0;
  const lang = ctx.lang || 'this language';
  const h = plotHeight(rows.length);
  const parts = [];

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

  const showW1 = hasFiniteSeries(rows, 'write_median_ns') && hasFiniteSeries(rows, 'read_median_ns');
  if (showW1) {
    parts.push(
      figureHtml({
        title: 'Write and read, separately',
        helpHtml: `<span class="exp-chip exp-series-write" style="--exp-series:${SERIES_WRITE};--exp-series-ink:#1565c0"><span class="exp-swatch" aria-hidden="true"></span>Write</span> <span class="exp-chip exp-series-read" style="--exp-series:${SERIES_READ};--exp-series-ink:#4a148c"><span class="exp-swatch" aria-hidden="true"></span>Read</span>`,
        pngId: 'exp-png-split',
        height: h,
        canvasLabel: `Grouped bar chart of write time and read time in microseconds for ${lang}`,
      })
    );
  }

  const treatment = sizeTreatment(rows);
  if (treatment.kind === 'S0') {
    parts.push(`<p class="exp-size-callout">${escapeHtml(treatment.text)}</p>`);
  } else if (treatment.kind === 'S1') {
    parts.push(
      figureHtml({
        title: 'Size (bytes)',
        helpHtml: 'Smaller is more compact. Compared libraries only share a color key with the time charts.',
        pngId: 'exp-png-size',
        height: h,
        canvasLabel: `Horizontal bar chart of payload size in bytes for ${lang}`,
      })
    );
  }

  mount.innerHTML = parts.join('');
  const canvases = [...mount.querySelectorAll('canvas')];
  let i = 0;
  try {
    latencyChart = mountLatency(canvases[i++], rows, lang);
    if (showW1) splitChart = mountSplit(canvases[i++], rows);
    if (treatment.kind === 'S1') sizeChart = mountSize(canvases[i++], rows);
  } catch (err) {
    const plot = mount.querySelectorAll('.exp-figure-plot')[showW1 && !splitChart ? 1 : 0];
    if (plot) {
      const p = document.createElement('p');
      p.className = 'exp-figure-help';
      p.textContent = `Chart failed: ${err.message}`;
      plot.appendChild(p);
    }
    console.warn('experiment figures', err);
  }
}
