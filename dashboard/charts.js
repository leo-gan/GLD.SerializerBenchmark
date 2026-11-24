import {
  formatOpsCompact,
  formatTimeCompact,
  formatIntGrouped,
  formatSig,
  chooseLatencyUnit,
} from './format.js';
import { serializerSourceUrl } from './serializer-sources.js';
import { exportChartPngWithBg, isDarkTheme } from './theme.js';

function openSerializerSource(language, name) {
  const url = serializerSourceUrl(language, name);
  if (url) window.open(url, '_blank', 'noopener,noreferrer');
}

function rowKey(g) {
  return g?.chart_key || g?.serializer;
}

function rowLabel(g) {
  return g?.chart_label || g?.serializer;
}

let scatterChartInstance = null;
let barChartInstance = null;

const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11,
};

function chartPalette() {
  if (isDarkTheme()) {
    return {
      gridColor: 'rgba(255, 255, 255, 0.08)',
      zeroGridColor: 'rgba(232, 234, 237, 0.35)',
      tickColor: '#a8b0be',
      frontierLine: 'rgba(138, 180, 248, 0.55)',
      paretoFill: '#8ab4f8',
      paretoPointBorder: '#21252f',
      paretoLabel: '#8ab4f8',
      dominatedFill: 'rgba(168, 176, 190, 0.42)',
      dominatedBorder: 'rgba(255, 255, 255, 0.14)',
      speedPareto: 'rgba(138, 180, 248, 0.9)',
      speedDom: 'rgba(138, 180, 248, 0.3)',
      speedParetoBorder: '#8ab4f8',
      speedDomBorder: 'rgba(138, 180, 248, 0.5)',
      sizePareto: 'rgba(129, 201, 149, 0.88)',
      sizeDom: 'rgba(129, 201, 149, 0.28)',
      sizeParetoBorder: '#81c995',
      sizeDomBorder: 'rgba(129, 201, 149, 0.48)',
      tooltipBg: 'rgba(16, 18, 24, 0.97)',
      tooltipBorder: '#4b5368',
    };
  }
  return {
    gridColor: 'rgba(0, 0, 0, 0.06)',
    zeroGridColor: 'rgba(32, 33, 36, 0.35)',
    tickColor: '#5f6368',
    frontierLine: 'rgba(26, 115, 232, 0.5)',
    paretoFill: '#1a73e8',
    paretoPointBorder: '#ffffff',
    paretoLabel: '#1a73e8',
    dominatedFill: 'rgba(95, 99, 104, 0.35)',
    dominatedBorder: 'rgba(0, 0, 0, 0.08)',
    speedPareto: 'rgba(26, 115, 232, 0.9)',
    speedDom: 'rgba(26, 115, 232, 0.28)',
    speedParetoBorder: '#1a73e8',
    speedDomBorder: 'rgba(26, 115, 232, 0.45)',
    sizePareto: 'rgba(30, 142, 62, 0.9)',
    sizeDom: 'rgba(30, 142, 62, 0.28)',
    sizeParetoBorder: '#1e8e3e',
    sizeDomBorder: 'rgba(30, 142, 62, 0.45)',
    tooltipBg: 'rgba(32, 33, 36, 0.95)',
    tooltipBorder: '#dadce0',
  };
}

/** @type {{ logScale: boolean, rankSort: 'speed' | 'size' }} */
let chartOptions = { logScale: false, rankSort: 'speed' };

export function initCharts() {
  // charts created on first data
}

export function setChartLogScale(enabled) {
  chartOptions.logScale = !!enabled;
}

export function getChartLogScale() {
  return chartOptions.logScale;
}

/** Ranking chart row order: 'speed' (ops/latency) or 'size' (median bytes, compact first). */
export function setRankSort(sort) {
  chartOptions.rankSort = sort === 'size' ? 'size' : 'speed';
}

export function getRankSort() {
  return chartOptions.rankSort;
}

function updateScatterHelp(metric) {
  const help = document.getElementById('scatter-help');
  if (!help) return;
  const right =
    metric === 'ops'
      ? '<strong>Right</strong> = faster (higher ops/s).'
      : '<strong>Right</strong> = slower (higher total latency).';
  help.innerHTML =
    'Each point is one serializer. ' +
    `${right} <strong>Up</strong> = larger payload. ` +
    'Highlighted = Pareto (no other library is both faster and smaller).';
}

export function updateCharts(groups, paretoNames, metric) {
  updateScatterHelp(metric);
  updateScatterChart(groups, paretoNames, metric);
  updateBarChart(groups, paretoNames, metric);
  const title = document.getElementById('bar-chart-title');
  if (title) {
    title.textContent =
      metric === 'ops' ? 'Throughput & Size Ranking' : 'Latency & Size Ranking';
  }
  const help = document.getElementById('ranking-help');
  if (help) {
    const primaryRight = metric === 'ops' ? 'ops/s' : 'latency';
    const sortLabel =
      chartOptions.rankSort === 'size'
        ? 'sorted by size (most compact first)'
        : metric === 'ops'
          ? 'sorted by ops/s (highest first)'
          : 'sorted by latency (lowest first)';
    help.innerHTML =
      `Single diverging chart, <strong>${sortLabel}</strong>: ` +
      `<span class="rank-legend-size">◀ size</span> left · ` +
      `<span class="rank-legend-speed">${primaryRight} ▶</span> right. ` +
      `Each side is normalized to the chart max (100); hover for absolute values. ` +
      `Solid bars are the Pareto front: no other row in this filter is both faster and smaller.`;
  }
}

export function resizeCharts() {
  scatterChartInstance?.resize();
  barChartInstance?.resize();
}

export function exportScatterPng() {
  return exportChartPngWithBg(scatterChartInstance);
}

/** Prefer primary ranking chart for PNG export. */
export function exportBarPng() {
  return exportChartPngWithBg(barChartInstance);
}

function updateScatterChart(groups, paretoNames, metric) {
  const canvas = document.getElementById('scatter-chart');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  if (scatterChartInstance) scatterChartInstance.destroy();

  const isOps = metric === 'ops';
  const paretoPoints = [];
  const standardPoints = [];

  groups.forEach((g) => {
    const xVal = isOps ? g.avg_ops_per_sec : g.avg_time_total_ns;
    const yVal = g.median_size_bytes;
    if (xVal == null || yVal == null || !Number.isFinite(xVal) || !Number.isFinite(yVal)) return;
    if (chartOptions.logScale && xVal <= 0) return;
    const point = {
      x: xVal,
      y: yVal,
      label: rowLabel(g),
      serializer: g.serializer,
      language: g.language,
      ops: g.avg_ops_per_sec,
      time: g.avg_time_total_ns,
      onFrontier: paretoNames.includes(rowKey(g)),
    };
    if (point.onFrontier) paretoPoints.push(point);
    else standardPoints.push(point);
  });

  // Axis title unit must match tick scale (raw values stay in ns / ops/s).
  const latencyNs = isOps
    ? []
    : [...standardPoints, ...paretoPoints].map((p) => p.time).filter((v) => Number.isFinite(v));
  const latencyScale = chooseLatencyUnit(latencyNs);
  const xAxisTitle = isOps
    ? 'Throughput (ops/s)'
    : `Total latency (${latencyScale.unit})`;
  const formatXTick = (value) => {
    if (isOps) return formatOpsCompact(value);
    if (value == null || !Number.isFinite(value)) return '';
    return formatSig(value / latencyScale.divisor);
  };

  const sortedPareto = [...paretoPoints].sort((a, b) => a.y - b.y);
  const frontierLineData = [];
  for (let i = 0; i < sortedPareto.length; i++) {
    frontierLineData.push({ x: sortedPareto[i].x, y: sortedPareto[i].y });
    if (i < sortedPareto.length - 1) {
      frontierLineData.push({ x: sortedPareto[i + 1].x, y: sortedPareto[i].y });
    }
  }

  const xType = chartOptions.logScale ? 'logarithmic' : 'linear';
  const pal = chartPalette();

  scatterChartInstance = new Chart(ctx, {
    type: 'scatter',
    data: {
      datasets: [
        {
          label: 'Frontier Line',
          data: frontierLineData,
          type: 'line',
          showLine: true,
          borderColor: pal.frontierLine,
          borderWidth: 1.5,
          borderDash: [5, 5],
          pointRadius: 0,
          fill: false,
          stepped: true,
          order: 3,
        },
        {
          label: 'Pareto Optimal',
          data: paretoPoints,
          backgroundColor: pal.paretoFill,
          borderColor: pal.paretoPointBorder,
          borderWidth: 1.5,
          pointRadius: 7,
          pointHoverRadius: 9,
          pointStyle: 'rectRot',
          order: 1,
        },
        {
          label: 'Dominated',
          data: standardPoints,
          backgroundColor: pal.dominatedFill,
          borderColor: pal.dominatedBorder,
          borderWidth: 1,
          pointRadius: 4,
          pointHoverRadius: 6,
          order: 2,
        },
      ],
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_evt, elements) => {
        const el = elements && elements[0];
        if (!el) return;
        const p = scatterChartInstance?.data?.datasets?.[el.datasetIndex]?.data?.[el.index];
        if (p?.serializer || p?.label) openSerializerSource(p.language, p.serializer || p.label);
      },
      plugins: {
        legend: {
          labels: {
            color: pal.tickColor,
            font: fontStyle,
            filter: (item) => item.text !== 'Frontier Line',
          },
        },
        tooltip: {
          backgroundColor: pal.tooltipBg,
          titleColor: '#ffffff',
          bodyColor: '#ffffff',
          borderColor: pal.tooltipBorder,
          borderWidth: 1,
          padding: 8,
          bodyFont: fontStyle,
          titleFont: { ...fontStyle, weight: 'bold' },
          callbacks: {
            label: (context) => {
              const p = context.raw;
              if (!p?.label) return '';
              const src = serializerSourceUrl(p.language, p.label);
              return [
                `Serializer: ${p.label}`,
                `Throughput: ${formatOpsCompact(p.ops)}`,
                `Latency: ${formatTimeCompact(p.time)}`,
                `Size: ${formatIntGrouped(p.y)} bytes`,
                p.onFrontier
                  ? 'On Pareto frontier'
                  : isOps
                    ? 'Dominated on ops/s and size'
                    : 'Dominated on latency and size',
                src ? `Source: ${src}` : '',
              ].filter(Boolean);
            },
          },
        },
      },
      scales: {
        x: {
          type: xType,
          title: {
            display: true,
            text: xAxisTitle,
            color: pal.tickColor,
            font: { ...fontStyle, weight: 'bold' },
          },
          grid: { color: pal.gridColor },
          ticks: {
            color: pal.tickColor,
            font: fontStyle,
            callback: (value) => formatXTick(value),
          },
        },
        y: {
          title: {
            display: true,
            text: 'Serialized size (bytes)',
            color: pal.tickColor,
            font: { ...fontStyle, weight: 'bold' },
          },
          grid: { color: pal.gridColor },
          ticks: {
            color: pal.tickColor,
            font: fontStyle,
            callback: (v) => formatIntGrouped(v),
          },
        },
      },
    },
    plugins: [
      {
        id: 'pointLabels',
        afterDatasetsDraw(chart) {
          const { ctx: c } = chart;
          c.save();
          c.textAlign = 'center';
          chart.data.datasets.forEach((dataset, datasetIndex) => {
            if (datasetIndex === 0) return;
            const isPareto = datasetIndex === 1;
            if (!isPareto) return;
            c.font = 'bold 10px "Roboto", -apple-system, sans-serif';
            c.fillStyle = pal.paretoLabel;
            const meta = chart.getDatasetMeta(datasetIndex);
            meta.data.forEach((element, index) => {
              const dataPoint = dataset.data[index];
              if (dataPoint?.label) {
                c.fillText(dataPoint.label, element.x, element.y - 10);
              }
            });
          });
          c.restore();
        },
      },
    ],
  });
}

/**
 * Single diverging (butterfly) horizontal bar chart:
 * - Right (blue): throughput or latency, normalized 0..100 vs chart max
 * - Left (green): median size, normalized 0..-100 vs chart max
 * Absolute values only in tooltips — avoids dual-axis collisions.
 */
function updateBarChart(groups, paretoNames, metric) {
  const canvas = document.getElementById('bar-chart');
  if (!canvas) return;
  if (barChartInstance) barChartInstance.destroy();

  const isOps = metric === 'ops';
  const sortBySize = chartOptions.rankSort === 'size';

  const sortedGroups = [...groups]
    .filter((g) => {
      if (!g) return false;
      if (g.median_size_bytes == null && sortBySize) return false;
      return isOps ? g.avg_ops_per_sec != null : g.avg_time_total_ns != null;
    })
    .sort((a, b) => {
      if (sortBySize) {
        // Compact first (ascending size); tie-break by speed
        const ds = (a.median_size_bytes ?? 0) - (b.median_size_bytes ?? 0);
        if (ds !== 0) return ds;
      }
      return isOps
        ? b.avg_ops_per_sec - a.avg_ops_per_sec
        : a.avg_time_total_ns - b.avg_time_total_ns;
    })
    .slice(0, 15);

  const labels = sortedGroups.map((g) => rowLabel(g));
  const primaryRaw = sortedGroups.map((g) =>
    isOps ? g.avg_ops_per_sec : g.avg_time_total_ns
  );
  const sizeRaw = sortedGroups.map((g) => Number(g.median_size_bytes) || 0);

  const maxPrimary = Math.max(...primaryRaw.filter((v) => Number.isFinite(v) && v > 0), 1);
  const maxSize = Math.max(...sizeRaw.filter((v) => Number.isFinite(v) && v > 0), 1);

  // Normalized: speed → +0..100, size → -0..-100 (diverging from center)
  const speedNorm = primaryRaw.map((v) =>
    Number.isFinite(v) && maxPrimary > 0 ? (v / maxPrimary) * 100 : 0
  );
  const sizeNorm = sizeRaw.map((v) =>
    Number.isFinite(v) && maxSize > 0 ? -(v / maxSize) * 100 : 0
  );

  const pal = chartPalette();

  const speedColors = sortedGroups.map((g) =>
    paretoNames.includes(rowKey(g)) ? pal.speedPareto : pal.speedDom
  );
  const sizeColors = sortedGroups.map((g) =>
    paretoNames.includes(rowKey(g)) ? pal.sizePareto : pal.sizeDom
  );

  barChartInstance = new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      // Legend order matches plot: size left (←), then speed/latency right (→).
      datasets: [
        {
          label: 'Size (←)',
          data: sizeNorm,
          backgroundColor: sizeColors,
          borderColor: sortedGroups.map((g) =>
            paretoNames.includes(rowKey(g)) ? pal.sizeParetoBorder : pal.sizeDomBorder
          ),
          borderWidth: 1,
          borderRadius: 3,
          barPercentage: 0.9,
          categoryPercentage: 0.75,
        },
        {
          label: isOps ? 'Ops/s (→)' : 'Latency (→)',
          data: speedNorm,
          backgroundColor: speedColors,
          borderColor: sortedGroups.map((g) =>
            paretoNames.includes(rowKey(g)) ? pal.speedParetoBorder : pal.speedDomBorder
          ),
          borderWidth: 1,
          borderRadius: 3,
          barPercentage: 0.9,
          categoryPercentage: 0.75,
        },
      ],
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      onClick: (_evt, elements) => {
        const el = elements && elements[0];
        if (!el) return;
        const g = sortedGroups[el.index];
        if (g) openSerializerSource(g.language, g.serializer);
      },
      plugins: {
        legend: {
          display: true,
          position: 'top',
          align: 'end',
          labels: {
            color: pal.tickColor,
            font: fontStyle,
            boxWidth: 12,
            usePointStyle: true,
            pointStyle: 'rectRounded',
          },
        },
        tooltip: {
          backgroundColor: pal.tooltipBg,
          titleColor: '#ffffff',
          bodyColor: '#ffffff',
          borderColor: pal.tooltipBorder,
          borderWidth: 1,
          padding: 10,
          bodyFont: fontStyle,
          titleFont: { ...fontStyle, weight: 'bold' },
          callbacks: {
            label: (context) => {
              const g = sortedGroups[context.dataIndex];
              if (!g) return '';
              const pct = Math.abs(context.raw).toFixed(0);
              // dataset 0 = size (left), 1 = speed/latency (right)
              if (context.datasetIndex === 0) {
                return `Size: ${formatIntGrouped(g.median_size_bytes)} bytes  (${pct}% of max in chart)`;
              }
              const abs = isOps
                ? formatOpsCompact(g.avg_ops_per_sec)
                : formatTimeCompact(g.avg_time_total_ns);
              return isOps
                ? `Ops/s: ${abs}  (${pct}% of max in chart)`
                : `Latency: ${abs}  (${pct}% of max in chart)`;
            },
            afterBody: (items) => {
              const g = sortedGroups[items[0]?.dataIndex];
              if (!g) return [];
              return [
                paretoNames.includes(rowKey(g))
                  ? 'Pareto optimal'
                  : isOps
                    ? 'Dominated on ops/s and size'
                    : 'Dominated on latency and size',
              ];
            },
          },
        },
      },
      scales: {
        x: {
          stacked: false,
          min: -100,
          max: 100,
          grid: {
            color: (ctx) =>
              ctx.tick.value === 0 ? pal.zeroGridColor : pal.gridColor,
            lineWidth: (ctx) => (ctx.tick.value === 0 ? 1.5 : 1),
          },
          title: {
            display: true,
            text: isOps
              ? '◀ larger size          normalized % of chart max          higher ops/s ▶'
              : '◀ larger size          normalized % of chart max          higher latency ▶',
            color: pal.tickColor,
            font: { ...fontStyle, size: 10 },
          },
          ticks: {
            color: pal.tickColor,
            font: fontStyle,
            stepSize: 25,
            callback: (value) => {
              if (value === 0) return '0';
              const a = Math.abs(value);
              if (value < 0) return `${a}%`; // size side
              return `${a}%`;
            },
          },
        },
        y: {
          stacked: false,
          grid: { display: false },
          ticks: {
            color: pal.tickColor,
            font: { ...fontStyle, weight: 'bold' },
            autoSkip: false,
          },
        },
      },
    },
  });
}

