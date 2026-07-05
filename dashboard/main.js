import { initCharts, updateCharts } from './charts.js';

const SETTINGS_KEY = 'serializer-dashboard-settings-v1';

/** Keys that identify a group, not metrics. */
const GROUP_META_KEYS = new Set(['serializer', 'test_data', 'mode', 'language']);

const LANGUAGE_CATALOG = [
  { id: 'csharp', label: 'C#' },
  { id: 'rust', label: 'Rust' },
  { id: 'go', label: 'Go' },
  { id: 'python', label: 'Python' },
  { id: 'javascript', label: 'JavaScript' },
  { id: 'c', label: 'C' },
];

/** Metrics shown as rows in the cross-language matrix. */
const CROSS_LANG_METRICS = [
  { key: 'avg_ops_per_sec', label: 'Ops/Sec', higherIsBetter: true },
  { key: 'avg_time_total_ns', label: 'Total latency', higherIsBetter: false },
  { key: 'avg_time_ser_ns', label: 'Ser latency', higherIsBetter: false },
  { key: 'avg_time_deser_ns', label: 'Deser latency', higherIsBetter: false },
  { key: 'total_median_ns', label: 'Median total', higherIsBetter: false },
  { key: 'median_size_bytes', label: 'Median size', higherIsBetter: false },
  { key: 'mean_fidelity', label: 'Fidelity', higherIsBetter: true },
  { key: 'runs', label: 'Samples', higherIsBetter: null },
];

/** Default checklist when no saved selection exists. */
const DEFAULT_SELECTED_METRICS = [
  'avg_ops_per_sec',
  'avg_time_total_ns',
  'avg_time_ser_ns',
  'avg_time_deser_ns',
  'total_median_ns',
  'ser_median_ns',
  'deser_median_ns',
  'median_size_bytes',
  'size_median_bytes',
  'runs',
  'mean_fidelity',
  'serializer_version',
];

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
  detailSerializers: [], // multi-select for Serializer Metrics table
  availableMetrics: [], // all metric field ids in loaded data
  selectedMetrics: [...DEFAULT_SELECTED_METRICS],

  // Cross-language comparison
  crossLangGroupsByLang: {}, // langId -> groups[]
  xlTestData: '',
  xlMode: '', // normalized: 'bytes' | 'stream' | other
  xlSelected: [], // [{ lang, serializer }]
  xlSelectionMode: 'pareto', // 'pareto' | 'custom'

  // Historical data state
  currentRunId: '',
  currentRunConfigs: {},
  currentRunErrors: '',
  currentRunCsv: '',
  historicalRuns: {} // Maps language -> array of runIds
};

// Initialize elements
document.addEventListener('DOMContentLoaded', async () => {
  applySavedSettings(loadSettings());
  setupEventListeners();
  initCharts();
  applyUiFromState();
  await loadHistoryList();
  await Promise.all([
    loadLanguageData(state.currentLanguage),
    loadAllLanguagesForCrossCompare(),
  ]);
});

function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) return null;
    return JSON.parse(raw);
  } catch (e) {
    console.warn('Could not read saved dashboard settings:', e);
    return null;
  }
}

function saveSettings() {
  const payload = {
    currentLanguage: state.currentLanguage,
    currentTestData: state.currentTestData,
    currentMode: state.currentMode,
    displayMetric: state.displayMetric,
    searchQuery: state.searchQuery,
    sortKey: state.sortKey,
    sortDirection: state.sortDirection,
    compareA: state.compareA,
    compareB: state.compareB,
    detailSerializers: state.detailSerializers,
    selectedMetrics: state.selectedMetrics,
    xlTestData: state.xlTestData,
    xlMode: state.xlMode,
    xlSelected: state.xlSelected,
    xlSelectionMode: state.xlSelectionMode,
  };
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(payload));
  } catch (e) {
    console.warn('Could not persist dashboard settings:', e);
  }
}

function applySavedSettings(saved) {
  if (!saved || typeof saved !== 'object') return;

  if (typeof saved.currentLanguage === 'string' && saved.currentLanguage) {
    state.currentLanguage = saved.currentLanguage;
  }
  if (typeof saved.currentTestData === 'string') state.currentTestData = saved.currentTestData;
  if (typeof saved.currentMode === 'string') state.currentMode = saved.currentMode;
  if (saved.displayMetric === 'ops' || saved.displayMetric === 'time') {
    state.displayMetric = saved.displayMetric;
  }
  if (typeof saved.searchQuery === 'string') state.searchQuery = saved.searchQuery;
  if (typeof saved.sortKey === 'string' && saved.sortKey) state.sortKey = saved.sortKey;
  if (saved.sortDirection === 'asc' || saved.sortDirection === 'desc') {
    state.sortDirection = saved.sortDirection;
  }
  if (typeof saved.compareA === 'string') state.compareA = saved.compareA;
  if (typeof saved.compareB === 'string') state.compareB = saved.compareB;
  // Multi-select (new) with migration from single detailSerializer
  if (Array.isArray(saved.detailSerializers)) {
    state.detailSerializers = saved.detailSerializers.filter((s) => typeof s === 'string');
  } else if (typeof saved.detailSerializer === 'string' && saved.detailSerializer) {
    state.detailSerializers = [saved.detailSerializer];
  }
  if (Array.isArray(saved.selectedMetrics) && saved.selectedMetrics.length > 0) {
    state.selectedMetrics = saved.selectedMetrics.filter((k) => typeof k === 'string');
  }
  if (typeof saved.xlTestData === 'string') state.xlTestData = saved.xlTestData;
  if (typeof saved.xlMode === 'string') state.xlMode = saved.xlMode;
  if (saved.xlSelectionMode === 'pareto' || saved.xlSelectionMode === 'custom') {
    state.xlSelectionMode = saved.xlSelectionMode;
  }
  if (Array.isArray(saved.xlSelected)) {
    state.xlSelected = saved.xlSelected
      .filter((x) => x && typeof x.lang === 'string' && typeof x.serializer === 'string')
      .map((x) => ({ lang: x.lang, serializer: x.serializer }));
  }
}

/** Sync non-data-dependent controls from state (before/after data load). */
function applyUiFromState() {
  const langSel = document.getElementById('lang-select');
  if (langSel && [...langSel.options].some((o) => o.value === state.currentLanguage)) {
    langSel.value = state.currentLanguage;
  }

  document.getElementById('btn-ops-sec').classList.toggle('active', state.displayMetric === 'ops');
  document.getElementById('btn-time-ns').classList.toggle('active', state.displayMetric === 'time');

  const search = document.getElementById('table-search');
  if (search) search.value = state.searchQuery || '';

  // Restore sort indicator on multi-serializer table headers
  document.querySelectorAll('#analytics-table th').forEach((th) => {
    th.className = '';
  });
  const sortHeaderMap = {
    serializer: 'th-serializer',
    avg_ops_per_sec: 'th-ops',
    avg_time_total_ns: 'th-total-ns',
    avg_time_ser_ns: 'th-ser-ns',
    avg_time_deser_ns: 'th-deser-ns',
    median_size_bytes: 'th-size',
  };
  const sortTh = document.getElementById(sortHeaderMap[state.sortKey]);
  if (sortTh) {
    sortTh.className = state.sortDirection === 'asc' ? 'sort-asc' : 'sort-desc';
  }
}

function setupEventListeners() {
  // Selectors
  document.getElementById('lang-select').addEventListener('change', async (e) => {
    state.currentLanguage = e.target.value;
    saveSettings();
    await loadLanguageData(state.currentLanguage);
  });

  document.getElementById('data-select').addEventListener('change', (e) => {
    state.currentTestData = e.target.value;
    saveSettings();
    filterAndRefresh();
  });

  document.getElementById('mode-select').addEventListener('change', (e) => {
    state.currentMode = e.target.value;
    saveSettings();
    filterAndRefresh();
  });

  // Toggle View Tabs
  document.getElementById('btn-ops-sec').addEventListener('click', () => {
    setViewMetric('ops');
  });

  document.getElementById('btn-time-ns').addEventListener('click', () => {
    setViewMetric('time');
  });

  // Search Input
  document.getElementById('table-search').addEventListener('input', (e) => {
    state.searchQuery = e.target.value.toLowerCase().trim();
    saveSettings();
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
    saveSettings();
    updateComparison();
  });

  document.getElementById('compare-b-select').addEventListener('change', (e) => {
    state.compareB = e.target.value;
    saveSettings();
    updateComparison();
  });

  // Multi-serializer metrics explorer
  document.getElementById('detail-ser-select-all').addEventListener('click', () => {
    state.detailSerializers = [...state.serializerNames];
    saveSettings();
    renderDetailSerializerChecklist();
    renderSerializerMetricsTable();
  });

  document.getElementById('detail-ser-select-none').addEventListener('click', () => {
    state.detailSerializers = [];
    saveSettings();
    renderDetailSerializerChecklist();
    renderSerializerMetricsTable();
  });

  document.getElementById('metrics-select-all').addEventListener('click', () => {
    state.selectedMetrics = [...state.availableMetrics];
    saveSettings();
    renderMetricsChecklist();
    renderSerializerMetricsTable();
  });

  document.getElementById('metrics-select-none').addEventListener('click', () => {
    state.selectedMetrics = [];
    saveSettings();
    renderMetricsChecklist();
    renderSerializerMetricsTable();
  });

  document.getElementById('metrics-select-default').addEventListener('click', () => {
    state.selectedMetrics = DEFAULT_SELECTED_METRICS.filter((k) =>
      state.availableMetrics.includes(k)
    );
    if (state.selectedMetrics.length === 0) {
      state.selectedMetrics = state.availableMetrics.slice(0, 12);
    }
    saveSettings();
    renderMetricsChecklist();
    renderSerializerMetricsTable();
  });

  // Cross-language comparison
  document.getElementById('xl-data-select').addEventListener('change', (e) => {
    state.xlTestData = e.target.value;
    if (state.xlSelectionMode === 'pareto') {
      applyCrossLangParetoSelection();
    } else {
      pruneCrossLangSelection();
    }
    refreshCrossLangAddSerializerOptions();
    renderCrossLangSelection();
    renderCrossLangTable();
    saveSettings();
  });

  document.getElementById('xl-mode-select').addEventListener('change', (e) => {
    state.xlMode = e.target.value;
    if (state.xlSelectionMode === 'pareto') {
      applyCrossLangParetoSelection();
    } else {
      pruneCrossLangSelection();
    }
    refreshCrossLangAddSerializerOptions();
    renderCrossLangSelection();
    renderCrossLangTable();
    saveSettings();
  });

  document.getElementById('xl-reset-pareto').addEventListener('click', () => {
    state.xlSelectionMode = 'pareto';
    applyCrossLangParetoSelection();
    renderCrossLangSelection();
    renderCrossLangTable();
    updateCrossLangBadge();
    saveSettings();
  });

  document.getElementById('xl-add-lang').addEventListener('change', () => {
    refreshCrossLangAddSerializerOptions();
  });

  document.getElementById('xl-add-btn').addEventListener('click', () => {
    const lang = document.getElementById('xl-add-lang').value;
    const serializer = document.getElementById('xl-add-serializer').value;
    if (!lang || !serializer) return;
    const exists = state.xlSelected.some(
      (x) => x.lang === lang && x.serializer === serializer
    );
    if (exists) {
      showNotification('Already selected for comparison.', 'info');
      return;
    }
    // Only add if a matching group exists under current filters
    const group = findCrossLangGroup(lang, serializer);
    if (!group) {
      showNotification('No data for that serializer under the current Test Data / Mode.', 'error');
      return;
    }
    state.xlSelectionMode = 'custom';
    state.xlSelected = [...state.xlSelected, { lang, serializer }];
    renderCrossLangSelection();
    renderCrossLangTable();
    updateCrossLangBadge();
    saveSettings();
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

  // Prefer saved filters when still valid for this dataset
  if (!testDataOptions.includes(state.currentTestData)) {
    state.currentTestData = testDataOptions[0] || '';
  }
  if (!modeOptions.includes(state.currentMode)) {
    state.currentMode = modeOptions[0] || '';
  }

  document.getElementById('data-select').value = state.currentTestData;
  document.getElementById('mode-select').value = state.currentMode;

  state.availableMetrics = discoverMetricKeys(state.allGroups);
  // Keep only selected metrics that still exist; if none left, fall back to defaults
  state.selectedMetrics = state.selectedMetrics.filter((k) =>
    state.availableMetrics.includes(k)
  );
  if (state.selectedMetrics.length === 0) {
    state.selectedMetrics = DEFAULT_SELECTED_METRICS.filter((k) =>
      state.availableMetrics.includes(k)
    );
    if (state.selectedMetrics.length === 0) {
      state.selectedMetrics = state.availableMetrics.slice(0, 12);
    }
  }

  renderMetricsChecklist();
  filterAndRefresh();
  saveSettings();
}

function discoverMetricKeys(groups) {
  const keys = new Set();
  for (const g of groups) {
    if (!g || typeof g !== 'object') continue;
    for (const k of Object.keys(g)) {
      if (!GROUP_META_KEYS.has(k)) keys.add(k);
    }
  }
  return [...keys].sort((a, b) => a.localeCompare(b));
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
  populateDetailSerializerSelect();

  // Update summary widgets
  updateKPIs();

  // Render visualizations
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);

  // Render Table
  renderTable();

  // Update Side-by-side comparison
  updateComparison();

  // Single-serializer metrics table
  renderSerializerMetricsTable();

  saveSettings();
}

function setViewMetric(metric) {
  state.displayMetric = metric;

  // Update Active Button Style
  document.getElementById('btn-ops-sec').classList.toggle('active', metric === 'ops');
  document.getElementById('btn-time-ns').classList.toggle('active', metric === 'time');

  // Redraw charts & table
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  saveSettings();
}

// Pareto Frontier Calculation (minimize latency + size)
function isParetoDominated(g, groups) {
  const gTime = g.avg_time_total_ns;
  const gSize = g.median_size_bytes;
  if (gTime == null || gSize == null) return true;

  for (const other of groups) {
    if (other === g) continue;
    const otherTime = other.avg_time_total_ns;
    const otherSize = other.median_size_bytes;
    if (otherTime == null || otherSize == null) continue;
    if (
      (otherTime <= gTime && otherSize < gSize) ||
      (otherTime < gTime && otherSize <= gSize)
    ) {
      return true;
    }
  }
  return false;
}

function paretoOptimalGroups(groups) {
  return groups.filter((g) => !isParetoDominated(g, groups));
}

function calculateParetoFrontier() {
  state.paretoSerializerNames = paretoOptimalGroups(state.filteredGroups).map(
    (g) => g.serializer
  );
}

// ---------- Cross-language comparison ----------

function languageLabel(langId) {
  return LANGUAGE_CATALOG.find((l) => l.id === langId)?.label || langId;
}

/** Normalize mode labels across languages (bytes/string vs stream/Stream). */
function normalizeMode(mode) {
  const s = String(mode || '').toLowerCase();
  if (s === 'stream') return 'stream';
  if (s === 'bytes' || s === 'string' || s === 'buffer') return 'bytes';
  return s;
}

function modeDisplayLabel(norm) {
  if (norm === 'bytes') return 'bytes (buffer)';
  if (norm === 'stream') return 'stream';
  return norm;
}

async function fetchStatsGroups(langId) {
  // Prefer plain JSON (no gzip edge cases); fall back to packed gz used by main dash.
  const urls = [`data/stats_${langId}_latest.json`, `data/${langId}_latest.json.gz`];
  for (const url of urls) {
    try {
      const response = await fetch(url);
      if (!response.ok) continue;

      let payload;
      try {
        payload = await response.clone().json();
      } catch {
        const ds = new DecompressionStream('gzip');
        const text = await new Response(response.body.pipeThrough(ds)).text();
        payload = JSON.parse(text);
      }

      const groups = payload.groups || payload.stats?.groups || [];
      if (Array.isArray(groups) && groups.length) {
        return groups.map((g) => ({
          ...g,
          language: g.language || langId,
        }));
      }
    } catch (e) {
      console.warn(`Cross-lang load failed for ${langId} via ${url}:`, e);
    }
  }
  return [];
}

async function loadAllLanguagesForCrossCompare() {
  const entries = await Promise.all(
    LANGUAGE_CATALOG.map(async (lang) => [lang.id, await fetchStatsGroups(lang.id)])
  );
  state.crossLangGroupsByLang = Object.fromEntries(entries);

  const loaded = entries.filter(([, g]) => g.length > 0).map(([id]) => id);
  if (loaded.length === 0) {
    console.warn('No cross-language stats loaded.');
  }

  initCrossLangControls();
  if (state.xlSelectionMode === 'pareto' || state.xlSelected.length === 0) {
    applyCrossLangParetoSelection();
  } else {
    pruneCrossLangSelection();
    if (state.xlSelected.length === 0) {
      applyCrossLangParetoSelection();
    }
  }
  renderCrossLangSelection();
  renderCrossLangTable();
  updateCrossLangBadge();
  saveSettings();
}

function allCrossLangGroups() {
  return Object.values(state.crossLangGroupsByLang).flat();
}

function initCrossLangControls() {
  const all = allCrossLangGroups();
  const testDataOptions = [...new Set(all.map((g) => g.test_data).filter(Boolean))].sort();
  const modeOptions = [...new Set(all.map((g) => normalizeMode(g.mode)).filter(Boolean))].sort();

  populateSelect('xl-data-select', testDataOptions);
  const modeSel = document.getElementById('xl-mode-select');
  modeSel.innerHTML = '';
  modeOptions.forEach((m) => {
    const opt = document.createElement('option');
    opt.value = m;
    opt.textContent = modeDisplayLabel(m);
    modeSel.appendChild(opt);
  });

  // Prefer saved / common defaults
  const preferredTd = ['Person', 'SimpleObject', 'Integer'];
  if (!testDataOptions.includes(state.xlTestData)) {
    state.xlTestData =
      preferredTd.find((t) => testDataOptions.includes(t)) || testDataOptions[0] || '';
  }
  if (!modeOptions.includes(state.xlMode)) {
    state.xlMode = modeOptions.includes('bytes')
      ? 'bytes'
      : modeOptions[0] || '';
  }

  document.getElementById('xl-data-select').value = state.xlTestData;
  modeSel.value = state.xlMode;

  // Language add picker
  const langSel = document.getElementById('xl-add-lang');
  langSel.innerHTML = '';
  LANGUAGE_CATALOG.forEach((lang) => {
    const groups = state.crossLangGroupsByLang[lang.id] || [];
    if (!groups.length) return;
    const opt = document.createElement('option');
    opt.value = lang.id;
    opt.textContent = lang.label;
    langSel.appendChild(opt);
  });

  refreshCrossLangAddSerializerOptions();
}

function filterGroupsForCrossLang(groups) {
  return groups.filter(
    (g) =>
      g.test_data === state.xlTestData &&
      normalizeMode(g.mode) === state.xlMode
  );
}

function findCrossLangGroup(lang, serializer) {
  const groups = filterGroupsForCrossLang(state.crossLangGroupsByLang[lang] || []);
  return groups.find((g) => g.serializer === serializer) || null;
}

function applyCrossLangParetoSelection() {
  const selected = [];
  for (const lang of LANGUAGE_CATALOG) {
    const groups = filterGroupsForCrossLang(state.crossLangGroupsByLang[lang.id] || []);
    if (!groups.length) continue;
    const pareto = paretoOptimalGroups(groups);
    // Stable order: fastest total first within language
    pareto
      .slice()
      .sort(
        (a, b) =>
          (a.avg_time_total_ns ?? Infinity) - (b.avg_time_total_ns ?? Infinity)
      )
      .forEach((g) => {
        selected.push({ lang: lang.id, serializer: g.serializer });
      });
  }
  state.xlSelected = selected;
  state.xlSelectionMode = 'pareto';
}

function pruneCrossLangSelection() {
  state.xlSelected = state.xlSelected.filter((x) => findCrossLangGroup(x.lang, x.serializer));
}

function refreshCrossLangAddSerializerOptions() {
  const lang = document.getElementById('xl-add-lang').value;
  const serSel = document.getElementById('xl-add-serializer');
  serSel.innerHTML = '';

  const groups = filterGroupsForCrossLang(state.crossLangGroupsByLang[lang] || []);
  const names = [...new Set(groups.map((g) => g.serializer))].sort((a, b) =>
    a.localeCompare(b)
  );

  if (!names.length) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = '— no serializers —';
    serSel.appendChild(opt);
    return;
  }

  names.forEach((name) => {
    const opt = document.createElement('option');
    opt.value = name;
    opt.textContent = name;
    serSel.appendChild(opt);
  });
}

function updateCrossLangBadge() {
  const badge = document.getElementById('cross-lang-badge');
  if (!badge) return;
  if (state.xlSelectionMode === 'pareto') {
    badge.textContent = 'Pareto best';
    badge.className = 'badge badge-cyan';
  } else {
    badge.textContent = 'Custom selection';
    badge.className = 'badge badge-purple';
  }
}

function renderCrossLangSelection() {
  const host = document.getElementById('xl-selection-chips');
  if (!host) return;
  host.innerHTML = '';

  updateCrossLangBadge();

  if (!state.xlSelected.length) {
    const empty = document.createElement('span');
    empty.style.color = 'var(--text-muted)';
    empty.style.fontSize = '0.85rem';
    empty.textContent = 'No serializers selected. Reset to Pareto best or add one.';
    host.appendChild(empty);
    return;
  }

  // Annotate which are currently Pareto under the active filters
  const paretoKeys = new Set();
  for (const lang of LANGUAGE_CATALOG) {
    const groups = filterGroupsForCrossLang(state.crossLangGroupsByLang[lang.id] || []);
    paretoOptimalGroups(groups).forEach((g) => {
      paretoKeys.add(`${lang.id}|${g.serializer}`);
    });
  }

  state.xlSelected.forEach((item, idx) => {
    const key = `${item.lang}|${item.serializer}`;
    const chip = document.createElement('span');
    chip.className = 'xl-chip' + (paretoKeys.has(key) ? ' pareto-chip' : '');
    chip.title = paretoKeys.has(key)
      ? 'On Pareto front for this language / filter'
      : 'Not on Pareto front for this language / filter';

    const label = document.createElement('span');
    label.className = 'xl-chip-label';
    label.textContent = `${languageLabel(item.lang)} · ${item.serializer}`;

    const remove = document.createElement('button');
    remove.type = 'button';
    remove.className = 'xl-chip-remove';
    remove.setAttribute('aria-label', `Remove ${item.serializer}`);
    remove.textContent = '×';
    remove.addEventListener('click', () => {
      state.xlSelectionMode = 'custom';
      state.xlSelected = state.xlSelected.filter((_, i) => i !== idx);
      renderCrossLangSelection();
      renderCrossLangTable();
      saveSettings();
    });

    chip.appendChild(label);
    chip.appendChild(remove);
    host.appendChild(chip);
  });
}

function renderCrossLangTable() {
  const thead = document.getElementById('xl-compare-head');
  const tbody = document.getElementById('xl-compare-body');
  if (!thead || !tbody) return;

  thead.innerHTML = '';
  tbody.innerHTML = '';

  const headerRow = document.createElement('tr');
  const metricTh = document.createElement('th');
  metricTh.textContent = 'Metric';
  headerRow.appendChild(metricTh);

  const columns = state.xlSelected.map((item) => ({
    ...item,
    group: findCrossLangGroup(item.lang, item.serializer),
  }));

  columns.forEach((col) => {
    const th = document.createElement('th');
    th.innerHTML = `<span class="xl-col-lang">${escapeHtml(languageLabel(col.lang))}</span><span class="xl-col-name">${escapeHtml(col.serializer)}</span>`;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);

  if (!columns.length) {
    const tr = document.createElement('tr');
    tr.innerHTML =
      '<td colspan="1" style="text-align:center;color:var(--text-muted);">Select serializers to compare across languages</td>';
    tbody.appendChild(tr);
    return;
  }

  CROSS_LANG_METRICS.forEach((metric) => {
    // Skip metric row if every column is missing that field entirely
    const values = columns.map((c) =>
      c.group && c.group[metric.key] != null ? Number(c.group[metric.key]) : null
    );
    if (values.every((v) => v === null || Number.isNaN(v))) return;

    let bestVal = null;
    if (metric.higherIsBetter === true || metric.higherIsBetter === false) {
      values.forEach((v) => {
        if (v === null || Number.isNaN(v)) return;
        if (
          bestVal === null ||
          (metric.higherIsBetter ? v > bestVal : v < bestVal)
        ) {
          bestVal = v;
        }
      });
    }

    const tr = document.createElement('tr');
    const tdLabel = document.createElement('td');
    tdLabel.textContent = metric.label;
    tr.appendChild(tdLabel);

    values.forEach((v) => {
      const td = document.createElement('td');
      if (v === null || Number.isNaN(v)) {
        td.textContent = '—';
        td.className = 'xl-missing';
      } else {
        td.textContent = formatMetricValue(metric.key, v);
        // Highlight every column that ties for best (not only the first).
        if (bestVal !== null && v === bestVal) td.classList.add('xl-best');
      }
      tr.appendChild(td);
    });
    tbody.appendChild(tr);
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
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

  if (state.serializerNames.length === 0) {
    state.compareA = '';
    state.compareB = '';
    return;
  }

  // Prefer previously chosen serializers when still present
  if (!state.serializerNames.includes(state.compareA)) {
    state.compareA = state.serializerNames[0];
  }
  if (!state.serializerNames.includes(state.compareB)) {
    state.compareB = state.serializerNames[Math.min(1, state.serializerNames.length - 1)];
  }

  selA.value = state.compareA;
  selB.value = state.compareB;
}

/** Metric family for checklist + table grouping. */
const METRIC_GROUP_ORDER = [
  'Run & quality',
  'Throughput',
  'Serialization',
  'Deserialization',
  'Total latency',
  'Size',
  'Comparisons',
  'Other',
];

function metricGroupName(key) {
  if (
    [
      'runs',
      'runs_raw',
      'warmup_skipped',
      'outliers_removed',
      'serializer_version',
      'mean_fidelity',
      'mean_memory_peak_bytes',
    ].includes(key)
  ) {
    return 'Run & quality';
  }
  if (
    key.includes('ops_per_sec') ||
    key.endsWith('_ops_mean') ||
    key.endsWith('_ops_median') ||
    key.endsWith('_ops_p95') ||
    key === 'min_ops_per_sec' ||
    key === 'max_ops_per_sec'
  ) {
    return 'Throughput';
  }
  if (key.startsWith('ser_') || key === 'avg_time_ser_ns') return 'Serialization';
  if (key.startsWith('deser_') || key === 'avg_time_deser_ns') return 'Deserialization';
  if (key.startsWith('total_') || key === 'avg_time_total_ns') return 'Total latency';
  if (key.startsWith('size_') || key === 'median_size_bytes') return 'Size';
  if (
    key.includes('effect_') ||
    key.includes('baseline') ||
    key.includes('fastest') ||
    key.includes('speedup')
  ) {
    return 'Comparisons';
  }
  return 'Other';
}

/** Higher is better for highlighting multi-serializer metric rows; null = no highlight. */
function metricHigherIsBetter(key) {
  if (
    key.includes('cliffs_label') ||
    key.includes('baseline_serializer') ||
    key.includes('fastest_in_group') ||
    key === 'serializer_version' ||
    key.includes('cliffs_delta') ||
    key.includes('hedges_g')
  ) {
    return null;
  }
  if (
    key.includes('ops_per_sec') ||
    key.endsWith('_ops_mean') ||
    key.endsWith('_ops_median') ||
    key.endsWith('_ops_p95') ||
    key === 'min_ops_per_sec' ||
    key === 'max_ops_per_sec' ||
    key === 'mean_fidelity' ||
    key.includes('speedup')
  ) {
    return true;
  }
  if (
    key.endsWith('_ns') ||
    key.endsWith('_bytes') ||
    key.includes('size_') ||
    key.endsWith('_cv') ||
    key.includes('_var_') ||
    key.includes('_std_') ||
    key.includes('_mad_')
  ) {
    return false;
  }
  return null;
}

function groupMetrics(keys) {
  const buckets = new Map(METRIC_GROUP_ORDER.map((g) => [g, []]));
  keys.forEach((k) => {
    const g = metricGroupName(k);
    if (!buckets.has(g)) buckets.set(g, []);
    buckets.get(g).push(k);
  });
  for (const arr of buckets.values()) arr.sort((a, b) => a.localeCompare(b));
  return METRIC_GROUP_ORDER
    .map((name) => ({ name, keys: buckets.get(name) || [] }))
    .filter((g) => g.keys.length > 0);
}

function populateDetailSerializerSelect() {
  // Keep only still-valid serializers; default to first if empty
  state.detailSerializers = state.detailSerializers.filter((s) =>
    state.serializerNames.includes(s)
  );
  if (state.detailSerializers.length === 0 && state.serializerNames.length > 0) {
    state.detailSerializers = [state.serializerNames[0]];
  }
  renderDetailSerializerChecklist();
}

function renderDetailSerializerChecklist() {
  const container = document.getElementById('detail-serializer-checklist');
  if (!container) return;

  container.innerHTML = '';
  const selected = new Set(state.detailSerializers);

  if (!state.serializerNames.length) {
    const empty = document.createElement('span');
    empty.style.color = 'var(--text-muted)';
    empty.style.fontSize = '0.8rem';
    empty.textContent = 'No serializers for this filter';
    container.appendChild(empty);
    return;
  }

  state.serializerNames.forEach((name) => {
    const label = document.createElement('label');
    label.className = 'metric-check-item';
    label.title = name;

    const input = document.createElement('input');
    input.type = 'checkbox';
    input.value = name;
    input.checked = selected.has(name);
    input.addEventListener('change', () => {
      if (input.checked) {
        if (!state.detailSerializers.includes(name)) {
          state.detailSerializers = [...state.detailSerializers, name].sort((a, b) =>
            a.localeCompare(b)
          );
        }
      } else {
        state.detailSerializers = state.detailSerializers.filter((s) => s !== name);
      }
      saveSettings();
      renderSerializerMetricsTable();
    });

    const span = document.createElement('span');
    span.textContent = name;

    label.appendChild(input);
    label.appendChild(span);
    container.appendChild(label);
  });
}

function renderMetricsChecklist() {
  const container = document.getElementById('metrics-checklist');
  if (!container) return;

  container.innerHTML = '';
  const selected = new Set(state.selectedMetrics);
  const groups = groupMetrics(state.availableMetrics);

  groups.forEach((group) => {
    const block = document.createElement('div');
    block.className = 'metric-group-block';

    const title = document.createElement('div');
    title.className = 'metric-group-title';

    const titleText = document.createElement('span');
    titleText.textContent = `${group.name} (${group.keys.length})`;

    const groupBtn = document.createElement('button');
    groupBtn.type = 'button';
    groupBtn.className = 'metric-group-toggle';
    const allOn = group.keys.every((k) => selected.has(k));
    groupBtn.textContent = allOn ? 'Clear' : 'All';
    groupBtn.addEventListener('click', () => {
      if (allOn) {
        state.selectedMetrics = state.selectedMetrics.filter((k) => !group.keys.includes(k));
      } else {
        const set = new Set(state.selectedMetrics);
        group.keys.forEach((k) => set.add(k));
        state.selectedMetrics = [...set].sort((a, b) => a.localeCompare(b));
      }
      saveSettings();
      renderMetricsChecklist();
      renderSerializerMetricsTable();
    });

    title.appendChild(titleText);
    title.appendChild(groupBtn);
    block.appendChild(title);

    const items = document.createElement('div');
    items.className = 'metric-group-items';

    group.keys.forEach((key) => {
      const label = document.createElement('label');
      label.className = 'metric-check-item';
      label.title = key;

      const input = document.createElement('input');
      input.type = 'checkbox';
      input.value = key;
      input.checked = selected.has(key);
      input.addEventListener('change', () => {
        if (input.checked) {
          if (!state.selectedMetrics.includes(key)) {
            state.selectedMetrics = [...state.selectedMetrics, key].sort((a, b) =>
              a.localeCompare(b)
            );
          }
        } else {
          state.selectedMetrics = state.selectedMetrics.filter((k) => k !== key);
        }
        saveSettings();
        renderSerializerMetricsTable();
      });

      const span = document.createElement('span');
      span.textContent = metricLabel(key);

      label.appendChild(input);
      label.appendChild(span);
      items.appendChild(label);
    });

    block.appendChild(items);
    container.appendChild(block);
  });
}

function renderSerializerMetricsTable() {
  const thead = document.getElementById('serializer-metrics-head');
  const tbody = document.getElementById('serializer-metrics-body');
  if (!thead || !tbody) return;

  thead.innerHTML = '';
  tbody.innerHTML = '';

  const serializers = state.detailSerializers.filter((s) =>
    state.serializerNames.includes(s)
  );
  const columns = serializers.map((name) => ({
    name,
    group: state.filteredGroups.find((g) => g.serializer === name) || null,
  }));

  const headerRow = document.createElement('tr');
  const metricTh = document.createElement('th');
  metricTh.textContent = 'Metric';
  headerRow.appendChild(metricTh);
  columns.forEach((col) => {
    const th = document.createElement('th');
    th.textContent = col.name;
    headerRow.appendChild(th);
  });
  thead.appendChild(headerRow);

  const colCount = Math.max(1, columns.length + 1);

  if (!columns.length) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="${colCount}" style="text-align:center;color:var(--text-muted);">Select one or more serializers</td>`;
    tbody.appendChild(tr);
    return;
  }

  const selectedKeys = state.selectedMetrics.filter((k) =>
    state.availableMetrics.includes(k)
  );
  if (!selectedKeys.length) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="${colCount}" style="text-align:center;color:var(--text-muted);">Select at least one metric in the checklist</td>`;
    tbody.appendChild(tr);
    return;
  }

  const groups = groupMetrics(selectedKeys);
  groups.forEach((group) => {
    const groupRow = document.createElement('tr');
    groupRow.className = 'metric-group-row';
    const groupTd = document.createElement('td');
    groupTd.colSpan = colCount;
    groupTd.textContent = group.name;
    groupRow.appendChild(groupTd);
    tbody.appendChild(groupRow);

    group.keys.forEach((key) => {
      const values = columns.map((c) => {
        if (!c.group || c.group[key] === undefined || c.group[key] === null) return null;
        const v = c.group[key];
        return typeof v === 'number' ? v : v;
      });

      const higherIsBetter = metricHigherIsBetter(key);
      let bestVal = null;
      if (higherIsBetter === true || higherIsBetter === false) {
        values.forEach((v) => {
          if (typeof v !== 'number' || !Number.isFinite(v)) return;
          if (
            bestVal === null ||
            (higherIsBetter ? v > bestVal : v < bestVal)
          ) {
            bestVal = v;
          }
        });
      }

      const tr = document.createElement('tr');
      const tdKey = document.createElement('td');
      tdKey.textContent = key;
      tdKey.title = metricLabel(key);
      tr.appendChild(tdKey);

      values.forEach((v) => {
        const td = document.createElement('td');
        if (v === null || v === undefined) {
          td.textContent = '—';
          td.className = 'sm-missing';
        } else {
          td.textContent = formatMetricValue(key, v);
          // Highlight every tied best value when comparing multiple serializers.
          if (
            columns.length > 1 &&
            typeof v === 'number' &&
            bestVal !== null &&
            v === bestVal
          ) {
            td.classList.add('sm-best');
          }
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
  });
}

function metricLabel(key) {
  // Short readable label for checklist; full field id stays in the table.
  return key
    .replace(/_ns$/g, ' (ns)')
    .replace(/_bytes$/g, ' (B)')
    .replace(/_per_sec$/g, '/s')
    .replace(/_/g, ' ');
}

function formatMetricValue(key, value) {
  if (value === null || value === undefined || value === '') return '—';
  if (typeof value === 'boolean') return value ? 'true' : 'false';
  if (typeof value === 'string') return value;

  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return String(value);
    if (key.endsWith('_ns')) return formatTime(value);
    if (
      key.includes('ops_per_sec') ||
      key.endsWith('_ops_mean') ||
      key.endsWith('_ops_median') ||
      key.endsWith('_ops_p95')
    ) {
      return formatOps(value);
    }
    if (key.endsWith('_bytes') || key.startsWith('size_')) {
      if (Math.abs(value) >= 1000) {
        return `${value.toLocaleString(undefined, { maximumFractionDigits: 2 })} B`;
      }
      return `${Number.isInteger(value) ? value : value.toFixed(4)} B`;
    }
    if (Number.isInteger(value)) return String(value);
    return Number(value.toPrecision(8)).toString();
  }

  return String(value);
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

  document.querySelectorAll('#analytics-table th').forEach(th => th.className = '');
  el.className = state.sortDirection === 'asc' ? 'sort-asc' : 'sort-desc';

  saveSettings();
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
