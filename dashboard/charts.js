import { formatOpsCompact, formatTimeCompact, formatIntGrouped, formatSig } from './format.js';

let scatterChartInstance = null;
let barChartInstance = null;

const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11,
};

const gridColor = 'rgba(0, 0, 0, 0.06)';
const tickColor = '#5f6368';

/** @type {{ logScale: boolean }} */
let chartOptions = { logScale: false };

export function initCharts() {
  // no-op; charts created on first data
}

export function setChartLogScale(enabled) {
  chartOptions.logScale = !!enabled;
}

export function getChartLogScale() {
  return chartOptions.logScale;
}

export function updateCharts(groups, paretoNames, metric) {
  updateScatterChart(groups, paretoNames, metric);
  updateBarChart(groups, paretoNames, metric);
  // Update ranking chart title if present
  const title = document.getElementById('bar-chart-title');
  if (title) {
    title.textContent =
      metric === 'ops' ? 'Throughput & Size Ranking' : 'Latency & Size Ranking';
  }
}

export function exportScatterPng() {
  if (!scatterChartInstance) return null;
  return scatterChartInstance.toBase64Image('image/png', 1);
}

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
    // Log scale requires positive values
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
            // Labels only for Pareto to reduce clutter
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

function updateBarChart(groups, paretoNames, metric) {
  const canvas = document.getElementById('bar-chart');
  if (!canvas) return;
  const ctx = canvas.getContext('2d');
  if (barChartInstance) barChartInstance.destroy();

  const isOps = metric === 'ops';

  const sortedGroups = [...groups]
    .filter((g) => g && (isOps ? g.avg_ops_per_sec : g.avg_time_total_ns) != null)
    .sort((a, b) =>
      isOps
        ? b.avg_ops_per_sec - a.avg_ops_per_sec
        : a.avg_time_total_ns - b.avg_time_total_ns
    )
    .slice(0, 15);

  const labels = sortedGroups.map((g) => g.serializer);
  const primary = sortedGroups.map((g) =>
    isOps ? g.avg_ops_per_sec : g.avg_time_total_ns
  );
  const sizes = sortedGroups.map((g) => g.median_size_bytes ?? 0);

  const primaryColors = sortedGroups.map((g) =>
    paretoNames.includes(g.serializer) ? 'rgba(26, 115, 232, 0.85)' : '#e8eaed'
  );
  const primaryBorders = sortedGroups.map((g) =>
    paretoNames.includes(g.serializer) ? '#1a73e8' : '#bdc1c6'
  );
  const sizeColors = sortedGroups.map((g) =>
    paretoNames.includes(g.serializer) ? 'rgba(30, 142, 62, 0.55)' : 'rgba(95, 99, 104, 0.25)'
  );

  barChartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels,
      datasets: [
        {
          label: isOps ? 'Ops/s' : 'Latency (ns)',
          data: primary,
          backgroundColor: primaryColors,
          borderColor: primaryBorders,
          borderWidth: 1,
          borderRadius: 2,
          xAxisID: 'x',
          order: 1,
        },
        {
          label: 'Size (bytes)',
          data: sizes,
          backgroundColor: sizeColors,
          borderColor: 'rgba(30, 142, 62, 0.4)',
          borderWidth: 1,
          borderRadius: 2,
          xAxisID: 'x1',
          order: 2,
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
          labels: { color: tickColor, font: fontStyle, boxWidth: 12 },
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
              const i = context.dataIndex;
              const g = sortedGroups[i];
              if (context.datasetIndex === 0) {
                return isOps
                  ? ` Throughput: ${formatOpsCompact(context.raw)}`
                  : ` Latency: ${formatTimeCompact(context.raw)}`;
              }
              return ` Size: ${formatIntGrouped(context.raw)} bytes`;
            },
            afterBody: (items) => {
              const i = items[0]?.dataIndex;
              const g = sortedGroups[i];
              if (!g) return [];
              return [
                `Throughput: ${formatOpsCompact(g.avg_ops_per_sec)}`,
                `Latency: ${formatTimeCompact(g.avg_time_total_ns)}`,
                `Size: ${formatIntGrouped(g.median_size_bytes)} bytes`,
              ];
            },
          },
        },
      },
      scales: {
        x: {
          position: 'bottom',
          grid: { color: gridColor },
          title: {
            display: true,
            text: isOps ? 'Ops/s' : 'Latency (ns)',
            color: tickColor,
            font: fontStyle,
          },
          ticks: {
            color: tickColor,
            font: fontStyle,
            callback: (value) => (isOps ? formatOpsCompact(value) : formatTimeCompact(value)),
          },
        },
        // Chart.js horizontal bar: category on y, values on x — dual value axes:
        // use top x axis for size via x1
        x1: {
          position: 'top',
          grid: { drawOnChartArea: false },
          title: {
            display: true,
            text: 'Size (bytes)',
            color: tickColor,
            font: fontStyle,
          },
          ticks: {
            color: tickColor,
            font: fontStyle,
            callback: (v) => formatIntGrouped(v),
          },
        },
        y: {
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
