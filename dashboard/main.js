import { initCharts, updateCharts } from './charts.js';

// State Management
let state = {
  currentLanguage: 'csharp',
  currentTestData: '',
  currentMode: '',
  displayMetric: 'ops', // 'ops' or 'time'
  searchQuery: '',
  sortKey: 'serializer',
  sortDirection: 'asc', // 'asc' or 'desc'
  allGroups: [], // All serializer runs for the loaded file
  filteredGroups: [], // Filtered by test_data and mode
  paretoSerializerNames: [], // Names of Pareto-optimal serializers
  serializerNames: [], // Names of all serializers in filtered group
  compareA: '',
  compareB: '',
  
  // Historical data state
  currentRunId: '',
  currentRunConfigs: {},
  currentRunErrors: '',
  currentRunCsv: '',
  historicalRuns: {} // Maps language -> array of runIds
};

// Initialize elements
document.addEventListener('DOMContentLoaded', async () => {
  setupEventListeners();
  initCharts();
  await loadHistoryList();
  await loadLanguageData(state.currentLanguage);
});

function setupEventListeners() {
  // Selectors
  document.getElementById('lang-select').addEventListener('change', async (e) => {
    state.currentLanguage = e.target.value;
    await loadLanguageData(state.currentLanguage);
  });

  document.getElementById('data-select').addEventListener('change', (e) => {
    state.currentTestData = e.target.value;
    filterAndRefresh();
  });

  document.getElementById('mode-select').addEventListener('change', (e) => {
    state.currentMode = e.target.value;
    filterAndRefresh();
  });

  // Toggle View Tabs
  document.getElementById('btn-ops-sec').addEventListener('click', (e) => {
    setViewMetric('ops');
  });

  document.getElementById('btn-time-ns').addEventListener('click', (e) => {
    setViewMetric('time');
  });

  // Search Input
  document.getElementById('table-search').addEventListener('input', (e) => {
    state.searchQuery = e.target.value.toLowerCase().trim();
    renderTable();
  });

  // Table Sorting
  const headers = [
    { id: 'th-serializer', key: 'serializer' },
    { id: 'th-ops', key: 'avg_ops_per_sec' },
    { id: 'th-total-ns', key: 'avg_time_total_ns' },
    { id: 'th-ser-ns', key: 'avg_time_ser_ns' },
    { id: 'th-deser-ns', key: 'avg_time_deser_ns' },
    { id: 'th-size', key: 'median_size_bytes' }
  ];

  headers.forEach(h => {
    const el = document.getElementById(h.id);
    if (el) {
      el.addEventListener('click', () => handleTableSort(h.key, el));
    }
  });

  // Comparison Selects
  document.getElementById('compare-a-select').addEventListener('change', (e) => {
    state.compareA = e.target.value;
    updateComparison();
  });

  document.getElementById('compare-b-select').addEventListener('change', (e) => {
    state.compareB = e.target.value;
    updateComparison();
  });

  // Navigation Links for Smooth Scrolling
  const navLinks = document.querySelectorAll('.nav-links a');
  navLinks.forEach(link => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href && href.startsWith('#')) {
        e.preventDefault();
        // Remove active class
        document.querySelectorAll('.nav-links li').forEach(li => li.classList.remove('active'));
        link.parentElement.classList.add('active');
        
        const targetId = href.substring(1);
        const targetElement = document.getElementById(targetId);
        if (targetElement) {
          targetElement.scrollIntoView({ behavior: 'smooth', block: 'start' });
        }
      }
    });
  });

  // Drag and Drop Upload Setup
  const dropZone = document.getElementById('drop-zone');
  const fileInput = document.getElementById('file-input');

  dropZone.addEventListener('click', () => fileInput.click());
  fileInput.addEventListener('change', (e) => handleFileUpload(e.target.files[0]));

  ['dragenter', 'dragover'].forEach(eventName => {
    dropZone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropZone.classList.add('dragover');
    }, false);
  });

  ['dragleave', 'drop'].forEach(eventName => {
    dropZone.addEventListener(eventName, (e) => {
      e.preventDefault();
      dropZone.classList.remove('dragover');
    }, false);
  });

  dropZone.addEventListener('drop', (e) => {
    const dt = e.dataTransfer;
    const files = dt.files;
    handleFileUpload(files[0]);
  });

  // History Actions Setup
  document.getElementById('history-run-select').addEventListener('change', (e) => {
    const runId = e.target.value;
    const disabled = !runId;
    document.getElementById('download-csv-btn').disabled = disabled;
    document.getElementById('download-config-btn').disabled = disabled;
    document.getElementById('download-error-btn').disabled = disabled;
    document.getElementById('load-history-btn').disabled = disabled;
  });

  document.getElementById('download-csv-btn').addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      triggerDownload(`/logs/${state.currentLanguage}/${runId}.csv`, `${state.currentLanguage}_${runId}.csv`);
    }
  });

  document.getElementById('download-config-btn').addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      const url = `/logs/${state.currentLanguage}/${runId}.configs.json`;
      const fallbackUrl = `/logs/${state.currentLanguage}/${runId}.environment.json`;
      downloadFileWithFallback(url, fallbackUrl, `${state.currentLanguage}_${runId}.configs.json`);
    }
  });

  document.getElementById('download-error-btn').addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      const url = `/logs/${state.currentLanguage}/${runId}.errors.csv`;
      downloadFileWithFallback(url, null, `${state.currentLanguage}_${runId}.errors.csv`);
    }
  });

  document.getElementById('load-history-btn').addEventListener('click', async () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      await loadHistoricalRunIntoDashboard(runId);
    }
  });
}

// Load available historical runs index
async function loadHistoryList() {
  try {
    const response = await fetch('data/available_runs.json');
    if (!response.ok) throw new Error("Could not fetch available runs index");
    state.historicalRuns = await response.json();
  } catch (e) {
    console.error("History runs not indexable (or offline):", e);
  }
}

// Populate the history dropdown for the current language
function updateHistoryUIForLanguage() {
  const select = document.getElementById('history-run-select');
  select.innerHTML = '<option value="">-- Select Run ID --</option>';
  
  const runs = state.historicalRuns[state.currentLanguage] || [];
  runs.forEach(runId => {
    const opt = document.createElement('option');
    opt.value = runId;
    opt.textContent = runId + (runId === state.currentRunId ? ' (Currently Active)' : '');
    select.appendChild(opt);
  });

  // Reset buttons
  select.value = '';
  document.getElementById('download-csv-btn').disabled = true;
  document.getElementById('download-config-btn').disabled = true;
  document.getElementById('download-error-btn').disabled = true;
  document.getElementById('load-history-btn').disabled = true;
}

// Load packed compressed run data (.json.gz)
async function loadLanguageData(lang) {
  const url = `data/${lang}_latest.json.gz`;
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Could not load stats for ${lang}`);
    
    let payload;
    // Check if the response is already decompressed (e.g. Content-Encoding handled by browser)
    try {
      const clonedResponse = response.clone();
      payload = await clonedResponse.json();
    } catch (e) {
      // Fallback: manually decompress using DecompressionStream
      try {
        const ds = new DecompressionStream('gzip');
        const decompressedStream = response.body.pipeThrough(ds);
        const text = await new Response(decompressedStream).text();
        payload = JSON.parse(text);
      } catch (decompError) {
        throw new Error(`Failed to parse or decompress payload: ${decompError.message}`);
      }
    }

    state.currentRunId = payload.run_id;
    state.currentRunConfigs = payload.configs;
    state.currentRunErrors = payload.errors;
    state.currentRunCsv = payload.csv_data;

    processStatsData(payload.stats);
    updateHistoryUIForLanguage();
  } catch (error) {
    console.error(error);
    showNotification(`Error loading ${lang} stats. Please run sync script first.`, 'error');
  }
}

// Load historical raw run dynamically into dashboard
async function loadHistoricalRunIntoDashboard(runId) {
  const csvUrl = `/logs/${state.currentLanguage}/${runId}.csv`;
  const configUrl = `/logs/${state.currentLanguage}/${runId}.configs.json`;
  const fallbackConfigUrl = `/logs/${state.currentLanguage}/${runId}.environment.json`;

  showNotification(`Loading historical run ${runId}...`, 'info');

  try {
    // 1. Fetch CSV
    const csvRes = await fetch(csvUrl);
    if (!csvRes.ok) throw new Error(`Could not fetch raw CSV for run ${runId}`);
    const csvText = await csvRes.text();

    // 2. Fetch Config
    let configs = {};
    try {
      let confRes = await fetch(configUrl);
      if (!confRes.ok) confRes = await fetch(fallbackConfigUrl);
      if (confRes.ok) configs = await confRes.json();
    } catch (e) {
      console.warn("Failed to load configs sidecar for history run:", e);
    }

    // 3. Parse CSV and aggregate stats dynamically
    const records = parseCSV(csvText);
    const groups = aggregateCSVRecords(records);

    if (groups.length === 0) {
      throw new Error("No valid serializer records found in parsed CSV.");
    }

    state.currentRunId = runId;
    state.currentRunConfigs = configs;
    state.currentRunCsv = csvText;
    state.currentRunErrors = ''; // Cleared for historical local

    // Swap datasets
    processStatsData({ groups });
    
    // Update active indicators
    document.getElementById('history-run-select').value = runId;
    document.getElementById('load-history-btn').disabled = false;

    showNotification(`Successfully loaded run ${runId} into Dashboard!`, 'success');
  } catch (error) {
    console.error("Error loading historical run:", error);
    showNotification(`Failed to load historical run: ${error.message}`, 'error');
  }
}

function processStatsData(statsObj) {
  state.allGroups = statsObj.groups || [];
  
  // Extract unique Test Data and Modes
  const testDataOptions = [...new Set(state.allGroups.map(g => g.test_data))];
  const modeOptions = [...new Set(state.allGroups.map(g => g.mode))];

  // Populate Dropdowns
  populateSelect('data-select', testDataOptions);
  populateSelect('mode-select', modeOptions);

  // Set default filters
  state.currentTestData = testDataOptions[0] || '';
  state.currentMode = modeOptions[0] || '';

  document.getElementById('data-select').value = state.currentTestData;
  document.getElementById('mode-select').value = state.currentMode;

  filterAndRefresh();
}

function populateSelect(id, options) {
  const select = document.getElementById(id);
  select.innerHTML = '';
  options.forEach(opt => {
    const el = document.createElement('option');
    el.value = opt;
    el.textContent = opt;
    select.appendChild(el);
  });
}

// Filter dataset based on selected test_data & mode
function filterAndRefresh() {
  state.filteredGroups = state.allGroups.filter(g => 
    g.test_data === state.currentTestData && g.mode === state.currentMode
  );

  // Re-calculate Pareto frontier dynamically
  calculateParetoFrontier();

  // Populate comparison pickers
  state.serializerNames = state.filteredGroups.map(g => g.serializer).sort();
  populateCompareSelectors();

  // Update summary widgets
  updateKPIs();

  // Render visualizations
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);

  // Render Table
  renderTable();
  
  // Update Side-by-side comparison
  updateComparison();
}

function setViewMetric(metric) {
  state.displayMetric = metric;
  
  // Update Active Button Style
  document.getElementById('btn-ops-sec').classList.toggle('active', metric === 'ops');
  document.getElementById('btn-time-ns').classList.toggle('active', metric === 'time');

  // Redraw charts & table
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
}

// Pareto Frontier Calculation
function calculateParetoFrontier() {
  const paretoNames = [];
  const groups = state.filteredGroups;

  for (let g of groups) {
    let dominated = false;
    for (let other of groups) {
      if (other === g) continue;
      
      const otherTime = other.avg_time_total_ns;
      const otherSize = other.median_size_bytes;
      const gTime = g.avg_time_total_ns;
      const gSize = g.median_size_bytes;

      if ((otherTime <= gTime && otherSize < gSize) || (otherTime < gTime && otherSize <= gSize)) {
        dominated = true;
        break;
      }
    }
    if (!dominated) {
      paretoNames.push(g.serializer);
    }
  }
  state.paretoSerializerNames = paretoNames;
}

// Update KPI cards
function updateKPIs() {
  const total = state.filteredGroups.length;
  document.getElementById('kpi-total').textContent = total;

  if (total === 0) {
    document.getElementById('kpi-fastest').textContent = '-';
    document.getElementById('kpi-fastest-val').textContent = 'Speed: -';
    document.getElementById('kpi-compact').textContent = '-';
    document.getElementById('kpi-compact-val').textContent = 'Size: -';
    document.getElementById('kpi-pareto').textContent = '-';
    return;
  }

  // Find Fastest (min avg_time_total_ns)
  const fastest = [...state.filteredGroups].sort((a, b) => a.avg_time_total_ns - b.avg_time_total_ns)[0];
  document.getElementById('kpi-fastest').textContent = fastest.serializer;
  document.getElementById('kpi-fastest-val').textContent = `Total: ${formatTime(fastest.avg_time_total_ns)} (${formatOps(fastest.avg_ops_per_sec)})`;

  // Find Most Compact (min median_size_bytes)
  const compact = [...state.filteredGroups].sort((a, b) => a.median_size_bytes - b.median_size_bytes)[0];
  document.getElementById('kpi-compact').textContent = compact.serializer;
  document.getElementById('kpi-compact-val').textContent = `Size: ${compact.median_size_bytes} Bytes`;

  // Pareto optimal count
  document.getElementById('kpi-pareto').textContent = `${state.paretoSerializerNames.length} / ${total}`;
}

// Compare Selectors setup
function populateCompareSelectors() {
  const selA = document.getElementById('compare-a-select');
  const selB = document.getElementById('compare-b-select');

  selA.innerHTML = '';
  selB.innerHTML = '';

  state.serializerNames.forEach(name => {
    const optA = document.createElement('option');
    const optB = document.createElement('option');
    optA.value = optA.textContent = name;
    optB.value = optB.textContent = name;
    selA.appendChild(optA);
    selB.appendChild(optB);
  });

  // Pick defaults
  if (state.serializerNames.length > 0) {
    state.compareA = state.serializerNames[0];
    state.compareB = state.serializerNames[Math.min(1, state.serializerNames.length - 1)];
    selA.value = state.compareA;
    selB.value = state.compareB;
  }
}

// Update Side by side comparison UI
function updateComparison() {
  const serializerA = state.filteredGroups.find(g => g.serializer === state.compareA);
  const serializerB = state.filteredGroups.find(g => g.serializer === state.compareB);

  if (!serializerA || !serializerB) {
    clearComparisonUI();
    return;
  }

  updateMetricUI('compare-total-val', 'compare-total-diff', serializerA.avg_time_total_ns, serializerB.avg_time_total_ns, 'ns', true);
  updateMetricUI('compare-ser-val', 'compare-ser-diff', serializerA.avg_time_ser_ns, serializerB.avg_time_ser_ns, 'ns', true);
  updateMetricUI('compare-deser-val', 'compare-deser-diff', serializerA.avg_time_deser_ns, serializerB.avg_time_deser_ns, 'ns', true);
  updateMetricUI('compare-throughput-val', 'compare-throughput-diff', serializerA.avg_ops_per_sec, serializerB.avg_ops_per_sec, 'ops', false);
  updateMetricUI('compare-size-val', 'compare-size-diff', serializerA.median_size_bytes, serializerB.median_size_bytes, 'bytes', true);
}

function updateMetricUI(valId, diffId, valA, valB, type, isLowerBetter) {
  const valEl = document.getElementById(valId);
  const diffEl = document.getElementById(diffId);

  let displayA = '', displayB = '';
  if (type === 'ns') {
    displayA = formatTime(valA);
    displayB = formatTime(valB);
  } else if (type === 'ops') {
    displayA = formatOps(valA);
    displayB = formatOps(valB);
  } else {
    displayA = `${valA} B`;
    displayB = `${valB} B`;
  }

  valEl.textContent = `${displayB}`;

  if (valA === 0 || valB === 0 || valA === null || valB === null) {
    diffEl.textContent = 'N/A';
    diffEl.className = 'compare-diff diff-neutral';
    return;
  }

  const pct = ((valB - valA) / valA) * 100;
  const isBetter = isLowerBetter ? pct < 0 : pct > 0;
  const absPct = Math.abs(pct).toFixed(1);

  if (pct === 0) {
    diffEl.textContent = 'Equal';
    diffEl.className = 'compare-diff diff-neutral';
  } else if (isBetter) {
    diffEl.textContent = `-${absPct}% (Better)`;
    diffEl.className = 'compare-diff diff-positive';
    if (!isLowerBetter) diffEl.textContent = `+${absPct}% (Better)`;
  } else {
    diffEl.textContent = `+${absPct}% (Worse)`;
    diffEl.className = 'compare-diff diff-negative';
    if (!isLowerBetter) diffEl.textContent = `-${absPct}% (Worse)`;
  }
}

function clearComparisonUI() {
  ['compare-total-val', 'compare-ser-val', 'compare-deser-val', 'compare-throughput-val', 'compare-size-val'].forEach(id => {
    document.getElementById(id).textContent = '-';
  });
  ['compare-total-diff', 'compare-ser-diff', 'compare-deser-diff', 'compare-throughput-diff', 'compare-size-diff'].forEach(id => {
    document.getElementById(id).textContent = '-';
    document.getElementById(id).className = 'compare-diff diff-neutral';
  });
}

// Table Sorting
function handleTableSort(key, el) {
  if (state.sortKey === key) {
    state.sortDirection = state.sortDirection === 'asc' ? 'desc' : 'asc';
  } else {
    state.sortKey = key;
    state.sortDirection = 'desc';
  }

  document.querySelectorAll('th').forEach(th => th.className = '');
  el.className = state.sortDirection === 'asc' ? 'sort-asc' : 'sort-desc';

  renderTable();
}

function renderTable() {
  const tbody = document.getElementById('table-body');
  tbody.innerHTML = '';

  let rows = state.filteredGroups.filter(g => 
    g.serializer.toLowerCase().includes(state.searchQuery)
  );

  rows.sort((a, b) => {
    let valA = a[state.sortKey];
    let valB = b[state.sortKey];

    if (valA === null || valA === undefined) return 1;
    if (valB === null || valB === undefined) return -1;

    if (typeof valA === 'string') {
      return state.sortDirection === 'asc' ? valA.localeCompare(valB) : valB.localeCompare(valA);
    } else {
      return state.sortDirection === 'asc' ? valA - valB : valB - valA;
    }
  });

  if (rows.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="7" style="text-align: center; color: var(--text-muted);">No serializers match search query</td>`;
    tbody.appendChild(tr);
    return;
  }

  rows.forEach(r => {
    const tr = document.createElement('tr');
    const isOptimal = state.paretoSerializerNames.includes(r.serializer);
    
    tr.innerHTML = `
      <td><strong>${r.serializer}</strong></td>
      <td>${formatOps(r.avg_ops_per_sec)}</td>
      <td>${formatTime(r.avg_time_total_ns)}</td>
      <td>${formatTime(r.avg_time_ser_ns)}</td>
      <td>${formatTime(r.avg_time_deser_ns)}</td>
      <td>${r.median_size_bytes} Bytes</td>
      <td>
        ${isOptimal 
          ? '<span class="badge badge-cyan">Optimal</span>' 
          : '<span class="badge badge-purple" style="opacity: 0.4;">Compromised</span>'}
      </td>
    `;
    tbody.appendChild(tr);
  });
}

// Upload Handler
function handleFileUpload(file) {
  if (!file) return;
  
  const status = document.getElementById('upload-status');
  status.style.display = 'block';
  status.style.color = 'var(--text-secondary)';
  status.textContent = `Analyzing ${file.name}...`;

  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = JSON.parse(e.target.result);
      if (!data.groups || !Array.isArray(data.groups)) {
        throw new Error("Invalid stats format. Missing 'groups' array.");
      }
      
      processStatsData(data);
      
      status.style.color = 'var(--accent-green)';
      status.textContent = `Successfully loaded ${file.name}!`;
      showNotification(`Loaded ${file.name} successfully.`, 'success');
      
      document.getElementById('lang-select').value = '';
    } catch (err) {
      status.style.color = 'var(--accent-red)';
      status.textContent = `Failed: ${err.message}`;
      showNotification(`Upload failed: ${err.message}`, 'error');
    }
  };
  
  reader.readAsText(file);
}

// Dynamic CSV parsing and aggregations
function parseCSV(text) {
  const lines = text.split('\n').map(line => line.trim()).filter(line => line.length > 0);
  if (lines.length === 0) return [];
  
  const headers = parseCSVLine(lines[0]);
  const records = [];
  
  for (let i = 1; i < lines.length; i++) {
    const values = parseCSVLine(lines[i]);
    if (values.length !== headers.length) continue;
    
    const rec = {};
    for (let j = 0; j < headers.length; j++) {
      rec[headers[j]] = values[j];
    }
    records.push(rec);
  }
  return records;
}

function parseCSVLine(line) {
  const result = [];
  let current = '';
  let inQuotes = false;
  
  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      inQuotes = !inQuotes;
    } else if (char === ',' && !inQuotes) {
      result.push(current.trim());
      current = '';
    } else {
      current += char;
    }
  }
  result.push(current.trim());
  return result;
}

function aggregateCSVRecords(records) {
  const groups = {};
  
  records.forEach(r => {
    const serializer = r.SerializerName || r.serializer || '';
    const testData = r.TestDataName || r.test_data || '';
    const mode = r.StringOrStream || r.mode || '';
    
    if (!serializer || !testData || !mode) return;
    
    const key = `${serializer}|${testData}|${mode}`;
    if (!groups[key]) {
      groups[key] = {
        serializer,
        test_data: testData,
        mode,
        timesSer: [],
        timesDeser: [],
        timesTotal: [],
        sizes: [],
        opsSec: []
      };
    }
    
    const tSer = parseFloat(r.TimeSer || r.time_ser || 0);
    const tDeser = parseFloat(r.TimeDeser || r.time_deser || 0);
    const tTotal = parseFloat(r.TimeSerAndDeser || r.time_total || 0) || (tSer + tDeser);
    const size = parseFloat(r.Size || r.size || 0);
    const ops = parseFloat(r.OpPerSecSerAndDeser || r.ops_sec || 0);
    
    groups[key].timesSer.push(tSer);
    groups[key].timesDeser.push(tDeser);
    groups[key].timesTotal.push(tTotal);
    groups[key].sizes.push(size);
    groups[key].opsSec.push(ops);
  });
  
  const resultGroups = [];
  Object.values(groups).forEach(g => {
    const avgTotal = mean(g.timesTotal);
    const avgOps = mean(g.opsSec) || (1e9 / avgTotal);
    
    resultGroups.push({
      serializer: g.serializer,
      test_data: g.test_data,
      mode: g.mode,
      avg_time_ser_ns: mean(g.timesSer),
      avg_time_deser_ns: mean(g.timesDeser),
      avg_time_total_ns: avgTotal,
      median_size_bytes: median(g.sizes),
      avg_ops_per_sec: avgOps,
      runs: g.timesTotal.length
    });
  });
  
  return resultGroups;
}

function mean(arr) {
  if (arr.length === 0) return 0;
  return arr.reduce((sum, val) => sum + val, 0) / arr.length;
}

function median(arr) {
  if (arr.length === 0) return 0;
  const sorted = [...arr].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 !== 0 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}

// Download helpers
function triggerDownload(url, filename) {
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

async function downloadFileWithFallback(url, fallbackUrl, filename) {
  try {
    const res = await fetch(url);
    if (res.ok) {
      triggerDownload(url, filename);
    } else if (fallbackUrl) {
      const fbRes = await fetch(fallbackUrl);
      if (fbRes.ok) {
        // Change suffix to environment json
        const fbFilename = filename.replace('.configs.json', '.environment.json');
        triggerDownload(fallbackUrl, fbFilename);
      } else {
        showNotification("File not found on local server.", "error");
      }
    } else {
      showNotification("File not found on local server.", "error");
    }
  } catch (e) {
    showNotification("Download failed: " + e.message, "error");
  }
}

// Helpers
function formatTime(ns) {
  if (ns === null || ns === undefined) return '-';
  if (ns < 1000) return `${ns.toFixed(0)}ns`;
  if (ns < 1000000) return `${(ns / 1000).toFixed(2)}µs`;
  return `${(ns / 1000000).toFixed(2)}ms`;
}

function formatOps(ops) {
  if (ops === null || ops === undefined) return '-';
  if (ops < 1000) return `${ops.toFixed(0)}/s`;
  if (ops < 1000000) return `${(ops / 1000).toFixed(1)}K/s`;
  return `${(ops / 1000000).toFixed(2)}M/s`;
}

function showNotification(msg, type) {
  const notif = document.createElement('div');
  notif.style.position = 'fixed';
  notif.style.bottom = '2rem';
  notif.style.right = '2rem';
  notif.style.padding = '1rem 1.5rem';
  notif.style.borderRadius = '8px';
  notif.style.color = '#fff';
  notif.style.zIndex = '10000';
  notif.style.backdropFilter = 'blur(10px)';
  notif.style.boxShadow = '0 10px 30px rgba(0,0,0,0.5)';
  notif.style.fontSize = '0.95rem';
  notif.style.transition = 'opacity 0.3s ease';
  
  if (type === 'error') {
    notif.style.background = 'rgba(239, 68, 68, 0.8)';
    notif.style.border = '1px solid rgba(239, 68, 68, 0.3)';
  } else if (type === 'info') {
    notif.style.background = 'rgba(59, 130, 246, 0.8)';
    notif.style.border = '1px solid rgba(59, 130, 246, 0.3)';
  } else {
    notif.style.background = 'rgba(16, 185, 129, 0.8)';
    notif.style.border = '1px solid rgba(16, 185, 129, 0.3)';
  }
  
  notif.textContent = msg;
  document.body.appendChild(notif);
  
  setTimeout(() => {
    notif.style.opacity = '0';
    setTimeout(() => notif.remove(), 300);
  }, 4000);
}
