// Chart instances
let scatterChartInstance = null;
let barChartInstance = null;

// Google Material style constants
const fontStyle = {
  family: "'Roboto', -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif",
  size: 11
};

const gridColor = 'rgba(0, 0, 0, 0.06)';
const tickColor = '#5f6368';

export function initCharts() {
  console.log("Material visualizations engine initialized.");
}

export function updateCharts(groups, paretoNames, metric) {
  updateScatterChart(groups, paretoNames, metric);
  updateBarChart(groups, paretoNames, metric);
}

function updateScatterChart(groups, paretoNames, metric) {
  const ctx = document.getElementById('scatter-chart').getContext('2d');
  if (scatterChartInstance) {
    scatterChartInstance.destroy();
  }

  const isOps = metric === 'ops';

  const paretoPoints = [];
  const standardPoints = [];

  groups.forEach(g => {
    const xVal = isOps ? g.avg_ops_per_sec : g.avg_time_total_ns;
    const yVal = g.median_size_bytes;
    const point = {
      x: xVal,
      y: yVal,
      label: g.serializer,
      ops: g.avg_ops_per_sec,
      time: g.avg_time_total_ns
    };

    if (paretoNames.includes(g.serializer)) {
      paretoPoints.push(point);
    } else {
      standardPoints.push(point);
    }
  });

  const sortedPareto = [...paretoPoints].sort((a, b) => a.y - b.y);

  const frontierLineData = [];
  for (let i = 0; i < sortedPareto.length; i++) {
    frontierLineData.push({ x: sortedPareto[i].x, y: sortedPareto[i].y });
    if (i < sortedPareto.length - 1) {
      frontierLineData.push({ x: sortedPareto[i+1].x, y: sortedPareto[i].y });
    }
  }

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
          order: 3
        },
        {
          label: 'Pareto Optimal',
          data: paretoPoints,
          backgroundColor: '#1a73e8', // Google Blue
          borderColor: '#ffffff',
          borderWidth: 1.5,
          pointRadius: 7,
          pointHoverRadius: 9,
          pointStyle: 'rectRot',
          order: 1
        },
        {
          label: 'Sub-Optimal',
          data: standardPoints,
          backgroundColor: 'rgba(95, 99, 104, 0.4)', // Slate gray
          borderColor: 'rgba(0, 0, 0, 0.1)',
          borderWidth: 1,
          pointRadius: 5,
          pointHoverRadius: 7,
          order: 2
        }
      ]
    },
    options: {
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: {
          labels: {
            color: tickColor,
            font: fontStyle,
            filter: function(item) {
              return item.text !== 'Frontier Line';
            }
          }
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
            label: function(context) {
              const p = context.raw;
              if (!p.label) return '';
              return [
                `Serializer: ${p.label}`,
                `Throughput: ${formatOps(p.ops)}`,
                `Latency: ${formatTime(p.time)}`,
                `Size: ${p.y} Bytes`
              ];
            }
          }
        }
      },
      scales: {
        x: {
          title: {
            display: true,
            text: isOps ? 'Throughput (Operations / Second)' : 'Total Latency (Nanoseconds)',
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' }
          },
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
            font: fontStyle,
            callback: function(value) {
              return isOps ? formatOps(value) : formatTime(value);
            }
          }
        },
        y: {
          title: {
            display: true,
            text: 'Serialized Size (Bytes)',
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' }
          },
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
            font: fontStyle
          }
        }
      }
    },
    plugins: [{
      id: 'pointLabels',
      afterDatasetsDraw(chart) {
        const {ctx} = chart;
        ctx.save();
        ctx.textAlign = 'center';
        
        chart.data.datasets.forEach((dataset, datasetIndex) => {
          // Dataset 0 is the Frontier Line (ignore it)
          if (datasetIndex === 0) return;
          
          const isPareto = datasetIndex === 1;
          ctx.font = isPareto 
            ? 'bold 10px "Roboto", -apple-system, sans-serif' 
            : '400 9px "Roboto", -apple-system, sans-serif';
          ctx.fillStyle = isPareto ? '#1a73e8' : '#80868b';
          
          const meta = chart.getDatasetMeta(datasetIndex);
          meta.data.forEach((element, index) => {
            const dataPoint = dataset.data[index];
            if (dataPoint && dataPoint.label) {
              const xPos = element.x;
              const yPos = element.y - (isPareto ? 10 : 8);
              ctx.fillText(dataPoint.label, xPos, yPos);
            }
          });
        });
        ctx.restore();
      }
    }]
  });
}

function updateBarChart(groups, paretoNames, metric) {
  const ctx = document.getElementById('bar-chart').getContext('2d');
  if (barChartInstance) {
    barChartInstance.destroy();
  }

  const isOps = metric === 'ops';

  const sortedGroups = [...groups].sort((a, b) => {
    return isOps 
      ? b.avg_ops_per_sec - a.avg_ops_per_sec
      : a.avg_time_total_ns - b.avg_time_total_ns;
  }).slice(0, 15);

  const labels = sortedGroups.map(g => g.serializer);
  const data = sortedGroups.map(g => isOps ? g.avg_ops_per_sec : g.avg_time_total_ns);

  const backgroundColors = sortedGroups.map(g => 
    paretoNames.includes(g.serializer) 
      ? 'rgba(26, 115, 232, 0.85)' // Google Blue
      : '#e8eaed' // High-contrast Material gray
  );
  
  const borderColors = sortedGroups.map(g => 
    paretoNames.includes(g.serializer) ? '#1a73e8' : '#bdc1c6'
  );

  barChartInstance = new Chart(ctx, {
    type: 'bar',
    data: {
      labels: labels,
      datasets: [{
        label: isOps ? 'Ops/Sec' : 'Latency (ns)',
        data: data,
        backgroundColor: backgroundColors,
        borderColor: borderColors,
        borderWidth: 1,
        borderRadius: 2
      }]
    },
    options: {
      indexAxis: 'y',
      responsive: true,
      maintainAspectRatio: false,
      plugins: {
        legend: { display: false },
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
            label: function(context) {
              const val = context.raw;
              return isOps 
                ? ` Throughput: ${formatOps(val)}`
                : ` Latency: ${formatTime(val)}`;
            }
          }
        }
      },
      scales: {
        x: {
          grid: { color: gridColor },
          ticks: {
            color: tickColor,
            font: fontStyle,
            callback: function(value) {
              return isOps ? formatOps(value) : formatTime(value);
            }
          }
        },
        y: {
          grid: { display: false },
          ticks: {
            color: tickColor,
            font: { ...fontStyle, weight: 'bold' },
            autoSkip: false
          }
        }
      }
    }
  });
}

function formatTime(ns) {
  if (ns === null || ns === undefined) return '-';
  if (ns < 1000) return `${ns.toFixed(0)}ns`;
  if (ns < 1000000) return `${(ns / 1000).toFixed(1)}µs`;
  return `${(ns / 1000000).toFixed(2)}ms`;
}

function formatOps(ops) {
  if (ops === null || ops === undefined) return '-';
  if (ops < 1000) return `${ops.toFixed(0)}/s`;
  if (ops < 1000000) return `${(ops / 1000).toFixed(0)}K/s`;
  return `${(ops / 1000000).toFixed(2)}M/s`;
}
