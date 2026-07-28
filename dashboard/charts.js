import { formatOpsCompact, formatTimeCompact, formatIntGrouped } from './format.js';

let scatterChartInstance = null;
let barChartInstance = null;

const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11,
};

const gridColor = 'rgba(0, 0, 0, 0.06)';
const tickColor = '#5f6368';

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

export function updateCharts(groups, paretoNames, metric) {
  updateScatterChart(groups, paretoNames, metric);
  updateBarChart(groups, paretoNames, metric);
  const title = document.getElementById('bar-chart-title');
  if (title) {
    title.textContent =
      metric === 'ops' ? 'Throughput & Size Ranking' : 'Latency & Size Ranking';
  }
  const help = document.getElementById('ranking-help');
  if (help) {
    const sortLabel =
      chartOptions.rankSort === 'size'
        ? 'sorted by size (most compact first)'
        : metric === 'ops'
          ? 'sorted by throughput (fastest first)'
          : 'sorted by latency (lowest first)';
    help.innerHTML =
      `Single diverging chart, <strong>${sortLabel}</strong>: ` +
      `<span class="rank-legend-size">◀ size</span> left · ` +
      `<span class="rank-legend-speed">speed ▶</span> right. ` +
      `Each side is normalized to the chart max (100); hover for absolute values.`;
  }
}

export function exportScatterPng() {
  if (!scatterChartInstance) return null;
  return scatterChartInstance.toBase64Image('image/png', 1);
}

/** Prefer primary ranking chart for PNG export. */
export function exportBarPng() {
  if (!barChartInstance) return null;
  return barChartInstance.toBase64Image('image/png', 1);
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
      label: g.serializer,
      ops: g.avg_ops_per_sec,
      time: g.avg_time_total_ns,
      onFrontier: paretoNames.includes(g.serializer),
    };
    if (point.onFrontier) paretoPoints.push(point);
    else standardPoints.push(point);
  });

  const sortedPareto = [...paretoPoints].sort((a, b) => a.y - b.y);
  const frontierLineData = [];
  for (let i = 0; i < sortedPareto.length; i++) {
    frontierLineData.push({ x: sortedPareto[i].x, y: sortedPareto[i].y });
    if (i < sortedPareto.length - 1) {
      frontierLineData.push({ x: sortedPareto[i + 1].x, y: sortedPareto[i].y });
    }
  }

  const xType = chartOptions.logScale ? 'logarithmic' : 'linear';

  scatterChartInstance = new Chart(ctx, {
    type: 'scatter',
    data: {
      datasets: [
        {
          label: 'Frontier Line',
          data: frontierLineData,
          type: 'line',
          showLine: true,
          borderColor: 'rgba(26, 115, 232, 0.5)',
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
          backgroundColor: '#1a73e8',
          borderColor: '#ffffff',
          borderWidth: 1.5,
          pointRadius: 7,
          pointHoverRadius: 9,
          pointStyle: 'rectRot',
          order: 1,
        },
        {
          label: 'Dominated',
          data: standardPoints,
          backgroundColor: 'rgba(95, 99, 104, 0.35)',
          borderColor: 'rgba(0, 0, 0, 0.08)',
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
      plugins: {
        legend: {
          labels: {
            color: tickColor,
            font: fontStyle,
            filter: (item) => item.text !== 'Frontier Line',
          },
        },
        tooltip: {
          backgroundColor: 'rgba(32, 33, 36, 0.95)',
          titleColor: '#ffffff',
          bodyColor: '#ffffff',
          borderColor: '#dadce0',
          borderWidth: 1,
          padding: 8,
          bodyFont: fontStyle,
          titleFont: { ...fontStyle, weight: 'bold' },
          callbacks: {
            label: (context) => {
              const p = context.raw;
              if (!p?.label) return '';
              return [
                `Serializer: ${p.label}`,
                `Throughput: ${formatOpsCompact(p.ops)}`,
                `Latency: ${formatTimeCompact(p.time)}`,
                `Size: ${formatIntGrouped(p.y)} bytes`,
                p.onFrontier ? 'On Pareto frontier' : 'Dominated on speed/size',
              ];
            },
          },
        },
      },
      scales: {
        x: {
          type: xType,
          title: {
            display: true,
            text: isOps ? 'Throughput (ops/s)' : 'Total latency (ns)',
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' },
          },
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
            font: fontStyle,
            callback: (value) => (isOps ? formatOpsCompact(value) : formatTimeCompact(value)),
          },
        },
        y: {
          title: {
            display: true,
            text: 'Serialized size (bytes)',
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' },
          },
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
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
            c.fillStyle = '#1a73e8';
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

  const labels = sortedGroups.map((g) => g.serializer);
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

  const speedColors = sortedGroups.map((g) =>
    paretoNames.includes(g.serializer) ? 'rgba(26, 115, 232, 0.9)' : 'rgba(26, 115, 232, 0.28)'
  );
  const sizeColors = sortedGroups.map((g) =>
    paretoNames.includes(g.serializer) ? 'rgba(30, 142, 62, 0.9)' : 'rgba(30, 142, 62, 0.28)'
  );

  barChartInstance = new Chart(canvas.getContext('2d'), {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: isOps ? 'Ops/s (→)' : 'Latency (→)',
          data: speedNorm,
          backgroundColor: speedColors,
          borderColor: sortedGroups.map((g) =>
            paretoNames.includes(g.serializer) ? '#1a73e8' : 'rgba(26, 115, 232, 0.45)'
          ),
          borderWidth: 1,
          borderRadius: 3,
          barPercentage: 0.9,
          categoryPercentage: 0.75,
        },
        {
          label: 'Size (←)',
          data: sizeNorm,
          backgroundColor: sizeColors,
          borderColor: sortedGroups.map((g) =>
            paretoNames.includes(g.serializer) ? '#1e8e3e' : 'rgba(30, 142, 62, 0.45)'
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
      plugins: {
        legend: {
          display: true,
          position: 'top',
          align: 'end',
          labels: {
            color: tickColor,
            font: fontStyle,
            boxWidth: 12,
            usePointStyle: true,
            pointStyle: 'rectRounded',
          },
        },
        tooltip: {
          backgroundColor: 'rgba(32, 33, 36, 0.95)',
          titleColor: '#ffffff',
          bodyColor: '#ffffff',
          borderColor: '#dadce0',
          borderWidth: 1,
          padding: 10,
          bodyFont: fontStyle,
          titleFont: { ...fontStyle, weight: 'bold' },
          callbacks: {
            label: (context) => {
              const g = sortedGroups[context.dataIndex];
              if (!g) return '';
              if (context.datasetIndex === 0) {
                const abs = isOps
                  ? formatOpsCompact(g.avg_ops_per_sec)
                  : formatTimeCompact(g.avg_time_total_ns);
                const pct = Math.abs(context.raw).toFixed(0);
                return isOps
                  ? `Ops/s: ${abs}  (${pct}% of max in chart)`
                  : `Latency: ${abs}  (${pct}% of max in chart)`;
              }
              const pct = Math.abs(context.raw).toFixed(0);
              return `Size: ${formatIntGrouped(g.median_size_bytes)} bytes  (${pct}% of max in chart)`;
            },
            afterBody: (items) => {
              const g = sortedGroups[items[0]?.dataIndex];
              if (!g) return [];
              return [
                paretoNames.includes(g.serializer) ? 'Pareto optimal' : 'Dominated on speed/size',
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
              ctx.tick.value === 0 ? 'rgba(32, 33, 36, 0.35)' : gridColor,
            lineWidth: (ctx) => (ctx.tick.value === 0 ? 1.5 : 1),
          },
          title: {
            display: true,
            text: isOps
              ? '◀ larger size          normalized % of chart max          higher ops/s ▶'
              : '◀ larger size          normalized % of chart max          higher latency ▶',
            color: tickColor,
            font: { ...fontStyle, size: 10 },
          },
          ticks: {
            color: tickColor,
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
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' },
            autoSkip: false,
          },
        },
      },
    },
  });
}

