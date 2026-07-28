import { initCharts, updateCharts, setChartLogScale, getChartLogScale, exportScatterPng, exportBarPng } from './charts.js';
import {
  formatSig,
  formatIntGrouped,
  formatMetricCell,
  formatRelativeCell,
  scalesFromGroups,
  metricHeaderLabel,
  metricKind,
  formatOpsCompact,
  formatTimeCompact,
} from './format.js';

const SETTINGS_KEY = 'serializer-dashboard-settings-v2';

const GROUP_META_KEYS = new Set(['serializer', 'test_data', 'mode', 'language']);
const SUITE_TYPE_IDS = ['message', 'document', 'telemetry', 'strings', 'event'];

function fixtureKey(g) {
  const raw = String(g?.test_data ?? '');
  const base = raw.replace(/(@n=\d+)+$/i, '') || raw;
  let n = g?.data_type_instance_count;
  if (n == null || n === '') {
    const m = raw.match(/@n=(\d+)(?:@n=\d+)*$/i);
    if (m) n = Number(m[1]);
  }
  if (n != null && n !== '' && Number(n) > 0) {
    return `${base}@n=${Number(n)}`;
  }
  return base;
}

function baseTypeId(key) {
  if (!key) return '';
  const i = String(key).indexOf('@n=');
  return i >= 0 ? String(key).slice(0, i) : String(key);
}

function pickPreferredFixture(options) {
  if (!options || !options.length) return '';
  const preferred = [];
  for (const id of SUITE_TYPE_IDS) {
    preferred.push(`${id}@n=1`, id, `${id}@n=100`);
  }
  for (const p of preferred) {
    if (options.includes(p)) return p;
  }
  const cleaned = options.filter((o) => SUITE_TYPE_IDS.includes(baseTypeId(o)));
  return cleaned[0] || options[0] || '';
}

const LANGUAGE_CATALOG = [
  { id: 'csharp', label: 'C#' },
  { id: 'rust', label: 'Rust' },
  { id: 'go', label: 'Go' },
  { id: 'python', label: 'Python' },
  { id: 'javascript', label: 'JavaScript' },
  { id: 'c', label: 'C' },
  { id: 'java', label: 'Java' },
  { id: 'cpp', label: 'C++' },
  { id: 'swift', label: 'Swift' },
];

const CROSS_LANG_METRICS = [
  { key: 'avg_ops_per_sec', label: 'Ops/s', higherIsBetter: true },
  { key: 'avg_time_total_ns', label: 'Total latency', higherIsBetter: false },
  { key: 'avg_time_ser_ns', label: 'Ser latency', higherIsBetter: false },
  { key: 'avg_time_deser_ns', label: 'Deser latency', higherIsBetter: false },
  { key: 'total_median_ns', label: 'Median total', higherIsBetter: false },
  { key: 'median_size_bytes', label: 'Median size', higherIsBetter: false },
  { key: 'mean_fidelity', label: 'Fidelity', higherIsBetter: true },
  { key: 'mean_memory_peak_bytes', label: 'Peak memory', higherIsBetter: false },
  { key: 'runs', label: 'Samples', higherIsBetter: null },
  { key: 'total_cv', label: 'Total CV', higherIsBetter: false },
];

const DEFAULT_SELECTED_METRICS = [
  'avg_ops_per_sec',
  'avg_time_total_ns',
  'avg_time_ser_ns',
  'avg_time_deser_ns',
  'total_median_ns',
  'total_ci_low_ns',
  'total_ci_high_ns',
  'median_size_bytes',
  'mean_fidelity',
  'mean_memory_peak_bytes',
  'runs',
  'serializer_version',
];

let state = {
  currentLanguage: 'csharp',
  currentTestData: '',
  currentMode: '',
  displayMetric: 'ops',
  searchQuery: '',
  sortKey: 'serializer',
  sortDirection: 'asc',
  allGroups: [],
  filteredGroups: [],
  paretoSerializerNames: [],
  serializerNames: [],
  detailSerializers: [],
  availableMetrics: [],
  selectedMetrics: [...DEFAULT_SELECTED_METRICS],
  compareBaseline: '',
  compareScope: 'same', // 'same' | 'cross'

  crossLangGroupsByLang: {},
  xlTestData: '',
  xlMode: '',
  xlSelected: [],
  xlSelectionMode: 'pareto',
  xlBaselineKey: '', // "lang|serializer"

  currentRunId: '',
  currentRunConfigs: {},
  currentRunErrors: '',
  currentRunCsv: '',
  historicalRuns: {},
  logsAvailable: null, // null unknown, true/false after probe
  chartLogScale: false,
  crossLangLoaded: false,
};

function languageLabel(langId) {
  return LANGUAGE_CATALOG.find((l) => l.id === langId)?.label || langId;
}

function populateLanguageSelect() {
  const sel = document.getElementById('lang-select');
  if (!sel) return;
  const prev = sel.value || state.currentLanguage;
  sel.innerHTML = '';
  for (const lang of LANGUAGE_CATALOG) {
    const opt = document.createElement('option');
    opt.value = lang.id;
    opt.textContent = lang.label;
    sel.appendChild(opt);
  }
  if ([...sel.options].some((o) => o.value === prev)) {
    sel.value = prev;
  } else if (sel.options.length) {
    sel.value = sel.options[0].value;
    state.currentLanguage = sel.value;
  }
}

document.addEventListener('DOMContentLoaded', async () => {
  populateLanguageSelect();
  applySavedSettings(loadSettings());
  applyUrlParams();
  setupEventListeners();
  initCharts();
  applyUiFromState();
  await loadHistoryList();
  await probeLogsAvailability();
  await loadLanguageData(state.currentLanguage);
  // Lazy: do not load all langs until cross-lang compare is opened
  if (state.compareScope === 'cross') {
    await ensureCrossLangLoaded();
  }
  syncUrlFromState();
});

function loadSettings() {
  try {
    const raw = localStorage.getItem(SETTINGS_KEY);
    if (!raw) {
      // migrate v1
      const v1 = localStorage.getItem('serializer-dashboard-settings-v1');
      if (v1) return JSON.parse(v1);
      return null;
    }
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
    detailSerializers: state.detailSerializers,
    selectedMetrics: state.selectedMetrics,
    compareBaseline: state.compareBaseline,
    compareScope: state.compareScope,
    xlTestData: state.xlTestData,
    xlMode: state.xlMode,
    xlSelected: state.xlSelected,
    xlSelectionMode: state.xlSelectionMode,
    xlBaselineKey: state.xlBaselineKey,
    chartLogScale: state.chartLogScale,
  };
  try {
    localStorage.setItem(SETTINGS_KEY, JSON.stringify(payload));
  } catch (e) {
    console.warn('Could not persist dashboard settings:', e);
  }
  syncUrlFromState();
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
  if (Array.isArray(saved.detailSerializers)) {
    state.detailSerializers = saved.detailSerializers.filter((s) => typeof s === 'string');
  } else if (typeof saved.detailSerializer === 'string' && saved.detailSerializer) {
    state.detailSerializers = [saved.detailSerializer];
  }
  if (Array.isArray(saved.selectedMetrics) && saved.selectedMetrics.length > 0) {
    state.selectedMetrics = saved.selectedMetrics.filter((k) => typeof k === 'string');
  }
  if (typeof saved.compareBaseline === 'string') state.compareBaseline = saved.compareBaseline;
  // migrate old compareA as baseline
  if (!state.compareBaseline && typeof saved.compareA === 'string') {
    state.compareBaseline = saved.compareA;
  }
  if (saved.compareScope === 'same' || saved.compareScope === 'cross') {
    state.compareScope = saved.compareScope;
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
  if (typeof saved.xlBaselineKey === 'string') state.xlBaselineKey = saved.xlBaselineKey;
  if (typeof saved.chartLogScale === 'boolean') {
    state.chartLogScale = saved.chartLogScale;
    setChartLogScale(state.chartLogScale);
  }
}

function applyUrlParams() {
  const p = new URLSearchParams(window.location.search);
  if (p.has('lang')) state.currentLanguage = p.get('lang');
  if (p.has('data')) state.currentTestData = p.get('data');
  if (p.has('mode')) state.currentMode = p.get('mode');
  if (p.get('metric') === 'ops' || p.get('metric') === 'time') state.displayMetric = p.get('metric');
  if (p.get('scope') === 'cross' || p.get('scope') === 'same') state.compareScope = p.get('scope');
  if (p.has('baseline')) state.compareBaseline = p.get('baseline');
  if (p.has('log')) state.chartLogScale = p.get('log') === '1';
  setChartLogScale(state.chartLogScale);
}

function syncUrlFromState() {
  try {
    const p = new URLSearchParams();
    p.set('lang', state.currentLanguage);
    if (state.currentTestData) p.set('data', state.currentTestData);
    if (state.currentMode) p.set('mode', state.currentMode);
    p.set('metric', state.displayMetric);
    if (state.compareScope === 'cross') p.set('scope', 'cross');
    if (state.compareBaseline) p.set('baseline', state.compareBaseline);
    if (state.chartLogScale) p.set('log', '1');
    const qs = p.toString();
    const url = `${window.location.pathname}${qs ? `?${qs}` : ''}${window.location.hash || ''}`;
    window.history.replaceState(null, '', url);
  } catch (_) {
    /* ignore */
  }
}

function applyUiFromState() {
  const langSel = document.getElementById('lang-select');
  if (langSel && [...langSel.options].some((o) => o.value === state.currentLanguage)) {
    langSel.value = state.currentLanguage;
  }

  document.getElementById('btn-ops-sec')?.classList.toggle('active', state.displayMetric === 'ops');
  document.getElementById('btn-time-ns')?.classList.toggle('active', state.displayMetric === 'time');
  document.getElementById('btn-chart-log')?.classList.toggle('active', state.chartLogScale);

  const search = document.getElementById('table-search');
  if (search) search.value = state.searchQuery || '';

  updateSortIndicators();
  applyCompareScopeUi();
}

function updateSortIndicators() {
  document.querySelectorAll('#analytics-table th').forEach((th) => {
    th.classList.remove('sort-asc', 'sort-desc');
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
    sortTh.classList.add(state.sortDirection === 'asc' ? 'sort-asc' : 'sort-desc');
  }
}

function applyCompareScopeUi() {
  const same = state.compareScope === 'same';
  document.getElementById('btn-compare-same')?.classList.toggle('active', same);
  document.getElementById('btn-compare-xl')?.classList.toggle('active', !same);
  const sameFilters = document.getElementById('compare-same-filters');
  const xlFilters = document.getElementById('compare-xl-filters');
  const checklist = document.getElementById('detail-serializer-checklist');
  const xlPanel = document.getElementById('xl-add-panel');
  const disclaimer = document.getElementById('compare-xl-disclaimer');
  const badge = document.getElementById('compare-scope-badge');
  const serAll = document.getElementById('detail-ser-select-all');
  const serNone = document.getElementById('detail-ser-select-none');

  if (sameFilters) sameFilters.hidden = !same;
  if (xlFilters) xlFilters.hidden = same;
  if (checklist) checklist.hidden = !same;
  if (xlPanel) xlPanel.hidden = same;
  if (disclaimer) disclaimer.hidden = same;
  if (serAll) serAll.hidden = !same;
  if (serNone) serNone.hidden = !same;
  if (badge) {
    badge.textContent = same ? 'Same language' : 'Cross-language';
    badge.className = same ? 'badge badge-cyan' : 'badge badge-slate';
  }
}

function setupEventListeners() {
  // Mobile nav
  const navToggle = document.getElementById('nav-toggle');
  const mainNav = document.getElementById('main-nav');
  navToggle?.addEventListener('click', () => {
    const open = mainNav?.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });

  document.getElementById('lang-select')?.addEventListener('change', async (e) => {
    state.currentLanguage = e.target.value;
    saveSettings();
    await loadLanguageData(state.currentLanguage);
  });

  document.getElementById('data-select')?.addEventListener('change', (e) => {
    state.currentTestData = e.target.value;
    saveSettings();
    filterAndRefresh();
  });

  document.getElementById('mode-select')?.addEventListener('change', (e) => {
    state.currentMode = e.target.value;
    saveSettings();
    filterAndRefresh();
  });

  document.getElementById('btn-ops-sec')?.addEventListener('click', () => setViewMetric('ops'));
  document.getElementById('btn-time-ns')?.addEventListener('click', () => setViewMetric('time'));

  document.getElementById('btn-chart-log')?.addEventListener('click', () => {
    state.chartLogScale = !state.chartLogScale;
    setChartLogScale(state.chartLogScale);
    document.getElementById('btn-chart-log')?.classList.toggle('active', state.chartLogScale);
    saveSettings();
    updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  });

  document.getElementById('btn-export-scatter')?.addEventListener('click', () => {
    const url = exportScatterPng();
    if (url) downloadDataUrl(url, `scatter-${state.currentLanguage}.png`);
  });
  document.getElementById('btn-export-bar')?.addEventListener('click', () => {
    const url = exportBarPng();
    if (url) downloadDataUrl(url, `ranking-${state.currentLanguage}.png`);
  });

  document.getElementById('table-search')?.addEventListener('input', (e) => {
    state.searchQuery = e.target.value.toLowerCase().trim();
    saveSettings();
    renderTable();
  });

  const headers = [
    { id: 'th-serializer', key: 'serializer' },
    { id: 'th-ops', key: 'avg_ops_per_sec' },
    { id: 'th-total-ns', key: 'avg_time_total_ns' },
    { id: 'th-ser-ns', key: 'avg_time_ser_ns' },
    { id: 'th-deser-ns', key: 'avg_time_deser_ns' },
    { id: 'th-size', key: 'median_size_bytes' },
  ];
  headers.forEach((h) => {
    const el = document.getElementById(h.id);
    if (el) el.addEventListener('click', () => handleTableSort(h.key));
  });

  document.getElementById('compare-baseline-select')?.addEventListener('change', (e) => {
    state.compareBaseline = e.target.value;
    saveSettings();
    renderCompareMatrix();
  });

  document.getElementById('btn-compare-same')?.addEventListener('click', () => {
    state.compareScope = 'same';
    applyCompareScopeUi();
    saveSettings();
    renderCompareMatrix();
  });

  document.getElementById('btn-compare-xl')?.addEventListener('click', async () => {
    state.compareScope = 'cross';
    applyCompareScopeUi();
    saveSettings();
    await ensureCrossLangLoaded();
    renderCompareMatrix();
  });

  document.getElementById('detail-ser-select-all')?.addEventListener('click', () => {
    state.detailSerializers = [...state.serializerNames];
    saveSettings();
    renderDetailSerializerChecklist();
    renderCompareMatrix();
  });

  document.getElementById('detail-ser-select-none')?.addEventListener('click', () => {
    state.detailSerializers = state.compareBaseline ? [state.compareBaseline] : [];
    saveSettings();
    renderDetailSerializerChecklist();
    renderCompareMatrix();
  });

  document.getElementById('metrics-select-all')?.addEventListener('click', () => {
    state.selectedMetrics = [...state.availableMetrics];
    saveSettings();
    renderMetricsChecklist();
    renderCompareMatrix();
  });

  document.getElementById('metrics-select-none')?.addEventListener('click', () => {
    state.selectedMetrics = [];
    saveSettings();
    renderMetricsChecklist();
    renderCompareMatrix();
  });

  document.getElementById('metrics-select-default')?.addEventListener('click', () => {
    state.selectedMetrics = DEFAULT_SELECTED_METRICS.filter((k) =>
      state.availableMetrics.includes(k)
    );
    if (state.selectedMetrics.length === 0) {
      state.selectedMetrics = state.availableMetrics.slice(0, 12);
    }
    saveSettings();
    renderMetricsChecklist();
    renderCompareMatrix();
  });

  // Cross-lang filters
  document.getElementById('xl-data-select')?.addEventListener('change', (e) => {
    state.xlTestData = e.target.value;
    if (state.xlSelectionMode === 'pareto') applyCrossLangParetoSelection();
    else pruneCrossLangSelection();
    refreshCrossLangAddSerializerOptions();
    renderCrossLangSelection();
    updateXlBaselineSelect();
    renderCompareMatrix();
    saveSettings();
  });

  document.getElementById('xl-mode-select')?.addEventListener('change', (e) => {
    state.xlMode = e.target.value;
    if (state.xlSelectionMode === 'pareto') applyCrossLangParetoSelection();
    else pruneCrossLangSelection();
    refreshCrossLangAddSerializerOptions();
    renderCrossLangSelection();
    updateXlBaselineSelect();
    renderCompareMatrix();
    saveSettings();
  });

  document.getElementById('xl-reset-pareto')?.addEventListener('click', () => {
    state.xlSelectionMode = 'pareto';
    applyCrossLangParetoSelection();
    renderCrossLangSelection();
    updateXlBaselineSelect();
    renderCompareMatrix();
    saveSettings();
  });

  document.getElementById('xl-add-lang')?.addEventListener('change', () => {
    refreshCrossLangAddSerializerOptions();
  });

  document.getElementById('xl-add-btn')?.addEventListener('click', () => {
    const lang = document.getElementById('xl-add-lang').value;
    const serializer = document.getElementById('xl-add-serializer').value;
    if (!lang || !serializer) return;
    if (state.xlSelected.some((x) => x.lang === lang && x.serializer === serializer)) {
      showNotification('Already selected for comparison.', 'info');
      return;
    }
    const group = findCrossLangGroup(lang, serializer);
    if (!group) {
      showNotification('No data for that serializer under the current fixture / mode.', 'error');
      return;
    }
    state.xlSelectionMode = 'custom';
    state.xlSelected = [...state.xlSelected, { lang, serializer }];
    renderCrossLangSelection();
    updateXlBaselineSelect();
    renderCompareMatrix();
    saveSettings();
  });

  document.getElementById('compare-xl-baseline-select')?.addEventListener('change', (e) => {
    state.xlBaselineKey = e.target.value;
    saveSettings();
    renderCompareMatrix();
  });

  document.getElementById('btn-copy-roster-md')?.addEventListener('click', () => copyRosterMarkdown());
  document.getElementById('btn-copy-compare-md')?.addEventListener('click', () => copyCompareMarkdown());

  // Nav smooth scroll
  document.querySelectorAll('.nav-links a').forEach((link) => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href && href.startsWith('#')) {
        e.preventDefault();
        document.querySelectorAll('.nav-links li').forEach((li) => li.classList.remove('active'));
        link.parentElement.classList.add('active');
        document.getElementById(href.slice(1))?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        // close mobile nav
        document.getElementById('main-nav')?.classList.remove('open');
        document.getElementById('nav-toggle')?.setAttribute('aria-expanded', 'false');
      }
    });
  });

  // Upload
  const dropZone = document.getElementById('drop-zone');
  const fileInput = document.getElementById('file-input');
  dropZone?.addEventListener('click', () => fileInput?.click());
  fileInput?.addEventListener('change', (e) => handleFileUpload(e.target.files[0]));
  ['dragenter', 'dragover'].forEach((ev) => {
    dropZone?.addEventListener(ev, (e) => {
      e.preventDefault();
      dropZone.classList.add('dragover');
    });
  });
  ['dragleave', 'drop'].forEach((ev) => {
    dropZone?.addEventListener(ev, (e) => {
      e.preventDefault();
      dropZone.classList.remove('dragover');
    });
  });
  dropZone?.addEventListener('drop', (e) => handleFileUpload(e.dataTransfer.files[0]));

  // History
  document.getElementById('history-run-select')?.addEventListener('change', (e) => {
    const disabled = !e.target.value || state.logsAvailable === false;
    ['download-csv-btn', 'download-config-btn', 'download-error-btn', 'load-history-btn'].forEach(
      (id) => {
        const b = document.getElementById(id);
        if (b) b.disabled = disabled;
      }
    );
  });

  document.getElementById('download-csv-btn')?.addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      triggerDownload(
        logsUrl(`${state.currentLanguage}/${runId}.csv`),
        `${state.currentLanguage}_${runId}.csv`
      );
    }
  });

  document.getElementById('download-config-btn')?.addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      downloadFileWithFallback(
        logsUrl(`${state.currentLanguage}/${runId}.configs.json`),
        logsUrl(`${state.currentLanguage}/${runId}.environment.json`),
        `${state.currentLanguage}_${runId}.configs.json`
      );
    }
  });

  document.getElementById('download-error-btn')?.addEventListener('click', () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) {
      downloadFileWithFallback(
        logsUrl(`${state.currentLanguage}/${runId}.errors.csv`),
        null,
        `${state.currentLanguage}_${runId}.errors.csv`
      );
    }
  });

  document.getElementById('load-history-btn')?.addEventListener('click', async () => {
    const runId = document.getElementById('history-run-select').value;
    if (runId) await loadHistoricalRunIntoDashboard(runId);
  });
}

function logsUrl(path) {
  // Relative to dashboard base (Vite base: './')
  return `logs/${path}`;
}

async function probeLogsAvailability() {
  try {
    // Try a lightweight probe against available_runs path sibling
    const runs = state.historicalRuns[state.currentLanguage];
    if (!runs || !runs.length) {
      state.logsAvailable = false;
    } else {
      const probe = await fetch(logsUrl(`${state.currentLanguage}/${runs[0]}.csv`), {
        method: 'HEAD',
      });
      state.logsAvailable = probe.ok;
    }
  } catch {
    state.logsAvailable = false;
  }
  const localNote = document.getElementById('history-local-note');
  const pagesNote = document.getElementById('history-pages-note');
  if (localNote) localNote.hidden = state.logsAvailable === false;
  if (pagesNote) pagesNote.hidden = state.logsAvailable !== false;
  if (state.logsAvailable === false) {
    ['download-csv-btn', 'download-config-btn', 'download-error-btn', 'load-history-btn'].forEach(
      (id) => {
        const b = document.getElementById(id);
        if (b) b.disabled = true;
      }
    );
  }
}

async function loadHistoryList() {
  try {
    const response = await fetch('data/available_runs.json');
    if (!response.ok) throw new Error('Could not fetch available runs index');
    state.historicalRuns = await response.json();
  } catch (e) {
    console.error('History runs not indexable (or offline):', e);
  }
}

function updateHistoryUIForLanguage() {
  const select = document.getElementById('history-run-select');
  if (!select) return;
  select.innerHTML = '<option value="">— Select run ID —</option>';
  const runs = state.historicalRuns[state.currentLanguage] || [];
  runs.forEach((runId) => {
    const opt = document.createElement('option');
    opt.value = runId;
    opt.textContent = runId + (runId === state.currentRunId ? ' (currently active)' : '');
    select.appendChild(opt);
  });
  select.value = '';
  ['download-csv-btn', 'download-config-btn', 'download-error-btn', 'load-history-btn'].forEach(
    (id) => {
      const b = document.getElementById(id);
      if (b) b.disabled = true;
    }
  );
}

async function loadLanguageData(lang) {
  const url = `data/${lang}_latest.json.gz`;
  try {
    const response = await fetch(url);
    if (!response.ok) throw new Error(`Could not load stats for ${lang}`);

    let payload;
    try {
      payload = await response.clone().json();
    } catch {
      const ds = new DecompressionStream('gzip');
      const text = await new Response(response.body.pipeThrough(ds)).text();
      payload = JSON.parse(text);
    }

    state.currentRunId = payload.run_id;
    state.currentRunConfigs = payload.configs || {};
    state.currentRunErrors = payload.errors || '';
    state.currentRunCsv = payload.csv_data || '';

    processStatsData(payload.stats);
    updateRunMeta();
    updateHistoryUIForLanguage();
  } catch (error) {
    console.error(error);
    showNotification(`Error loading ${lang} stats. Please run sync script first.`, 'error');
    setKpiEmpty('No data');
  }
}

function updateRunMeta() {
  const el = document.getElementById('run-meta');
  const text = document.getElementById('run-meta-text');
  if (!el || !text) return;
  const cfg = state.currentRunConfigs || {};
  const env = cfg.environment || {};
  const git = env.git || {};
  const cpu = env.cpu || {};
  const runtimes = env.runtimes || {};
  const dataset = cfg.dataset || {};
  const parts = [];
  if (state.currentRunId) parts.push(`run ${state.currentRunId}`);
  if (git.commit) parts.push(`commit ${git.commit}${git.dirty ? '*' : ''}`);
  if (cpu.model) parts.push(cpu.model);
  const rtKey =
    state.currentLanguage === 'csharp'
      ? 'dotnet'
      : state.currentLanguage === 'javascript'
        ? 'node'
        : state.currentLanguage === 'cpp'
          ? 'g++'
          : state.currentLanguage === 'c'
            ? 'gcc'
            : state.currentLanguage;
  if (runtimes[rtKey]) parts.push(String(runtimes[rtKey]).split('\n')[0]);
  if (dataset.seed != null) parts.push(`seed ${dataset.seed}`);
  if (parts.length) {
    text.textContent = parts.join(' · ');
    el.hidden = false;
  } else {
    el.hidden = true;
  }
}

async function loadHistoricalRunIntoDashboard(runId) {
  const csvUrl = logsUrl(`${state.currentLanguage}/${runId}.csv`);
  const configUrl = logsUrl(`${state.currentLanguage}/${runId}.configs.json`);
  const fallbackConfigUrl = logsUrl(`${state.currentLanguage}/${runId}.environment.json`);

  showNotification(`Loading historical run ${runId}…`, 'info');
  try {
    const csvRes = await fetch(csvUrl);
    if (!csvRes.ok) throw new Error(`Could not fetch raw CSV for run ${runId}`);
    const csvText = await csvRes.text();

    let configs = {};
    try {
      let confRes = await fetch(configUrl);
      if (!confRes.ok) confRes = await fetch(fallbackConfigUrl);
      if (confRes.ok) configs = await confRes.json();
    } catch (e) {
      console.warn('Failed to load configs sidecar for history run:', e);
    }

    const records = parseCSV(csvText);
    const groups = aggregateCSVRecords(records);
    if (groups.length === 0) throw new Error('No valid serializer records found in parsed CSV.');

    state.currentRunId = runId;
    state.currentRunConfigs = configs;
    state.currentRunCsv = csvText;
    state.currentRunErrors = '';
    processStatsData({ groups });
    updateRunMeta();
    showNotification(`Successfully loaded run ${runId}`, 'success');
  } catch (error) {
    console.error(error);
    showNotification(`Failed to load historical run: ${error.message}`, 'error');
  }
}

function processStatsData(statsObj) {
  state.allGroups = (statsObj.groups || []).map((g) => ({
    ...g,
    test_data: fixtureKey(g),
  }));

  const testDataOptions = [
    ...new Set(
      state.allGroups
        .map((g) => g.test_data)
        .filter((k) => k && SUITE_TYPE_IDS.includes(baseTypeId(k)))
    ),
  ].sort();
  const modeOptions = [...new Set(state.allGroups.map((g) => g.mode))];

  populateSelect('data-select', testDataOptions);
  populateSelect('mode-select', modeOptions);

  if (!testDataOptions.includes(state.currentTestData)) {
    state.currentTestData = pickPreferredFixture(testDataOptions);
  }
  if (!modeOptions.includes(state.currentMode)) {
    state.currentMode = modeOptions[0] || '';
  }

  const dataSel = document.getElementById('data-select');
  const modeSel = document.getElementById('mode-select');
  if (dataSel) dataSel.value = state.currentTestData;
  if (modeSel) modeSel.value = state.currentMode;

  discoverMetricKeys(state.allGroups);
  filterAndRefresh();
}

function discoverMetricKeys(groups) {
  const keys = new Set();
  for (const g of groups) {
    for (const k of Object.keys(g)) {
      if (!GROUP_META_KEYS.has(k) && k !== 'data_type_instance_count') keys.add(k);
    }
  }
  state.availableMetrics = [...keys].sort();
  // Keep selected intersection; fill defaults if empty
  state.selectedMetrics = state.selectedMetrics.filter((k) => state.availableMetrics.includes(k));
  if (!state.selectedMetrics.length) {
    state.selectedMetrics = DEFAULT_SELECTED_METRICS.filter((k) =>
      state.availableMetrics.includes(k)
    );
  }
}

function populateSelect(id, options) {
  const sel = document.getElementById(id);
  if (!sel) return;
  const prev = sel.value;
  sel.innerHTML = '';
  options.forEach((o) => {
    const opt = document.createElement('option');
    opt.value = o;
    opt.textContent = o;
    sel.appendChild(opt);
  });
  if (options.includes(prev)) sel.value = prev;
}

function filterAndRefresh() {
  state.filteredGroups = state.allGroups.filter(
    (g) => g.test_data === state.currentTestData && g.mode === state.currentMode
  );
  state.serializerNames = [
    ...new Set(state.filteredGroups.map((g) => g.serializer)),
  ].sort((a, b) => a.localeCompare(b));

  calculateParetoFrontier();

  // Baseline default
  if (!state.compareBaseline || !state.serializerNames.includes(state.compareBaseline)) {
    state.compareBaseline =
      state.paretoSerializerNames[0] || state.serializerNames[0] || '';
  }

  // Detail serializers default: baseline + a few others
  state.detailSerializers = state.detailSerializers.filter((s) =>
    state.serializerNames.includes(s)
  );
  if (!state.detailSerializers.length) {
    state.detailSerializers = state.serializerNames.slice(0, Math.min(6, state.serializerNames.length));
  }
  if (state.compareBaseline && !state.detailSerializers.includes(state.compareBaseline)) {
    state.detailSerializers = [state.compareBaseline, ...state.detailSerializers];
  }

  updateKPIs();
  populateBaselineSelect();
  renderDetailSerializerChecklist();
  renderMetricsChecklist();
  renderTable();
  renderCompareMatrix();
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  updateSortIndicators();
  saveSettings();
}

function setViewMetric(metric) {
  state.displayMetric = metric;
  document.getElementById('btn-ops-sec')?.classList.toggle('active', metric === 'ops');
  document.getElementById('btn-time-ns')?.classList.toggle('active', metric === 'time');
  saveSettings();
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
}

function isParetoDominated(g, groups) {
  const gOps = g.avg_ops_per_sec;
  const gSize = g.median_size_bytes;
  if (gOps == null || gSize == null) return true;
  return groups.some((other) => {
    if (other === g) return false;
    const oOps = other.avg_ops_per_sec;
    const oSize = other.median_size_bytes;
    if (oOps == null || oSize == null) return false;
    const betterOrEqualOps = oOps >= gOps;
    const betterOrEqualSize = oSize <= gSize;
    const strictlyBetter = oOps > gOps || oSize < gSize;
    return betterOrEqualOps && betterOrEqualSize && strictlyBetter;
  });
}

function paretoOptimalGroups(groups) {
  return groups.filter((g) => !isParetoDominated(g, groups));
}

function calculateParetoFrontier() {
  state.paretoSerializerNames = paretoOptimalGroups(state.filteredGroups).map((g) => g.serializer);
}

// ---------- Cross-language ----------

function normalizeMode(mode) {
  const m = String(mode || '').toLowerCase();
  if (m === 'string' || m === 'bytes' || m === 'byte') return 'bytes';
  if (m === 'stream') return 'stream';
  return m;
}

function modeDisplayLabel(norm) {
  if (norm === 'bytes') return 'bytes / string';
  if (norm === 'stream') return 'stream';
  return norm || '—';
}

async function fetchStatsGroups(langId) {
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
          test_data: fixtureKey(g),
        }));
      }
    } catch (e) {
      console.warn(`Cross-lang load failed for ${langId} via ${url}:`, e);
    }
  }
  return [];
}

async function ensureCrossLangLoaded() {
  if (state.crossLangLoaded) {
    initCrossLangControls();
    return;
  }
  showNotification('Loading cross-language stats…', 'info');
  const entries = await Promise.all(
    LANGUAGE_CATALOG.map(async (lang) => [lang.id, await fetchStatsGroups(lang.id)])
  );
  state.crossLangGroupsByLang = Object.fromEntries(entries);
  state.crossLangLoaded = true;
  initCrossLangControls();
  if (state.xlSelectionMode === 'pareto' || state.xlSelected.length === 0) {
    applyCrossLangParetoSelection();
  } else {
    pruneCrossLangSelection();
  }
  renderCrossLangSelection();
  updateXlBaselineSelect();
}

function allCrossLangGroups() {
  return Object.values(state.crossLangGroupsByLang).flat();
}

function initCrossLangControls() {
  const all = allCrossLangGroups();
  const fixtures = [
    ...new Set(
      all.map((g) => g.test_data).filter((k) => k && SUITE_TYPE_IDS.includes(baseTypeId(k)))
    ),
  ].sort();
  const modes = [...new Set(all.map((g) => normalizeMode(g.mode)).filter(Boolean))].sort();

  populateSelect('xl-data-select', fixtures);
  const modeSel = document.getElementById('xl-mode-select');
  if (modeSel) {
    modeSel.innerHTML = '';
    modes.forEach((m) => {
      const opt = document.createElement('option');
      opt.value = m;
      opt.textContent = modeDisplayLabel(m);
      modeSel.appendChild(opt);
    });
  }

  if (!fixtures.includes(state.xlTestData)) {
    state.xlTestData = pickPreferredFixture(fixtures);
  }
  if (!modes.includes(state.xlMode)) {
    state.xlMode = modes.includes('bytes') ? 'bytes' : modes[0] || '';
  }
  const xd = document.getElementById('xl-data-select');
  const xm = document.getElementById('xl-mode-select');
  if (xd) xd.value = state.xlTestData;
  if (xm) xm.value = state.xlMode;

  const langSel = document.getElementById('xl-add-lang');
  if (langSel) {
    langSel.innerHTML = '';
    LANGUAGE_CATALOG.forEach((l) => {
      const opt = document.createElement('option');
      opt.value = l.id;
      opt.textContent = l.label;
      langSel.appendChild(opt);
    });
  }
  refreshCrossLangAddSerializerOptions();
}

function filterGroupsForCrossLang(groups) {
  return groups.filter(
    (g) =>
      g.test_data === state.xlTestData && normalizeMode(g.mode) === state.xlMode
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
    const pareto = paretoOptimalGroups(groups)
      .sort((a, b) => b.avg_ops_per_sec - a.avg_ops_per_sec)
      .slice(0, 2);
    pareto.forEach((g) => selected.push({ lang: lang.id, serializer: g.serializer }));
  }
  state.xlSelected = selected;
  state.xlSelectionMode = 'pareto';
  if (selected.length && !state.xlBaselineKey) {
    state.xlBaselineKey = `${selected[0].lang}|${selected[0].serializer}`;
  }
}

function pruneCrossLangSelection() {
  state.xlSelected = state.xlSelected.filter((x) => findCrossLangGroup(x.lang, x.serializer));
}

function refreshCrossLangAddSerializerOptions() {
  const lang = document.getElementById('xl-add-lang')?.value;
  const serSel = document.getElementById('xl-add-serializer');
  if (!serSel || !lang) return;
  const groups = filterGroupsForCrossLang(state.crossLangGroupsByLang[lang] || []);
  const names = [...new Set(groups.map((g) => g.serializer))].sort((a, b) =>
    a.localeCompare(b)
  );
  serSel.innerHTML = '';
  names.forEach((n) => {
    const opt = document.createElement('option');
    opt.value = n;
    opt.textContent = n;
    serSel.appendChild(opt);
  });
}

function renderCrossLangSelection() {
  const host = document.getElementById('xl-selection-chips');
  if (!host) return;
  host.innerHTML = '';
  if (!state.xlSelected.length) {
    const empty = document.createElement('span');
    empty.style.color = 'var(--text-muted)';
    empty.style.fontSize = '0.85rem';
    empty.textContent = 'No serializers selected. Seed Pareto best or add one.';
    host.appendChild(empty);
    return;
  }
  state.xlSelected.forEach((x) => {
    const chip = document.createElement('span');
    chip.className = 'xl-chip';
    chip.textContent = `${languageLabel(x.lang)} / ${x.serializer}`;
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.textContent = '×';
    btn.setAttribute('aria-label', `Remove ${x.serializer}`);
    btn.addEventListener('click', () => {
      state.xlSelectionMode = 'custom';
      state.xlSelected = state.xlSelected.filter(
        (y) => !(y.lang === x.lang && y.serializer === x.serializer)
      );
      renderCrossLangSelection();
      updateXlBaselineSelect();
      renderCompareMatrix();
      saveSettings();
    });
    chip.appendChild(btn);
    host.appendChild(chip);
  });
}

function updateXlBaselineSelect() {
  const sel = document.getElementById('compare-xl-baseline-select');
  if (!sel) return;
  sel.innerHTML = '';
  state.xlSelected.forEach((x) => {
    const opt = document.createElement('option');
    opt.value = `${x.lang}|${x.serializer}`;
    opt.textContent = `${languageLabel(x.lang)} / ${x.serializer}`;
    sel.appendChild(opt);
  });
  if (
    state.xlBaselineKey &&
    state.xlSelected.some((x) => `${x.lang}|${x.serializer}` === state.xlBaselineKey)
  ) {
    sel.value = state.xlBaselineKey;
  } else if (state.xlSelected.length) {
    state.xlBaselineKey = `${state.xlSelected[0].lang}|${state.xlSelected[0].serializer}`;
    sel.value = state.xlBaselineKey;
  } else {
    state.xlBaselineKey = '';
  }
}

// ---------- KPIs / tables ----------

function setKpiEmpty(msg) {
  document.getElementById('kpi-total').textContent = '0';
  document.getElementById('kpi-fastest').textContent = msg || 'No data for this filter';
  document.getElementById('kpi-fastest-val').textContent = 'Select another fixture or mode';
  document.getElementById('kpi-compact').textContent = msg || 'No data for this filter';
  document.getElementById('kpi-compact-val').textContent = 'Select another fixture or mode';
  document.getElementById('kpi-pareto').textContent = '—';
}

function updateKPIs() {
  const total = state.filteredGroups.length;
  document.getElementById('kpi-total').textContent = formatIntGrouped(total);

  if (total === 0) {
    setKpiEmpty('No data for this filter');
    return;
  }

  const fastest = [...state.filteredGroups].sort(
    (a, b) => a.avg_time_total_ns - b.avg_time_total_ns
  )[0];
  document.getElementById('kpi-fastest').textContent = fastest.serializer;
  document.getElementById('kpi-fastest-val').textContent =
    `${formatTimeCompact(fastest.avg_time_total_ns)} · ${formatOpsCompact(fastest.avg_ops_per_sec)}`;

  const compact = [...state.filteredGroups].sort(
    (a, b) => a.median_size_bytes - b.median_size_bytes
  )[0];
  document.getElementById('kpi-compact').textContent = compact.serializer;
  document.getElementById('kpi-compact-val').textContent =
    `${formatIntGrouped(compact.median_size_bytes)} bytes`;

  document.getElementById('kpi-pareto').textContent =
    `${state.paretoSerializerNames.length} / ${total}`;
}

function populateBaselineSelect() {
  const sel = document.getElementById('compare-baseline-select');
  if (!sel) return;
  sel.innerHTML = '';
  state.serializerNames.forEach((name) => {
    const opt = document.createElement('option');
    opt.value = name;
    opt.textContent = name + (state.paretoSerializerNames.includes(name) ? ' ★' : '');
    sel.appendChild(opt);
  });
  if (state.compareBaseline && state.serializerNames.includes(state.compareBaseline)) {
    sel.value = state.compareBaseline;
  } else if (state.serializerNames.length) {
    sel.value = state.serializerNames[0];
    state.compareBaseline = sel.value;
  }
}

function metricHigherIsBetter(key) {
  if (
    key.includes('ops') ||
    key.includes('fidelity') ||
    key === 'runs' ||
    key === 'fastest_in_group'
  ) {
    return true;
  }
  if (
    key.includes('time') ||
    key.endsWith('_ns') ||
    key.includes('size') ||
    key.includes('bytes') ||
    key.includes('cv') ||
    key.includes('mad') ||
    key.includes('std') ||
    key.includes('memory')
  ) {
    return false;
  }
  return null;
}

function metricGroupName(key) {
  if (key.includes('ops')) return 'Throughput';
  if (key.startsWith('ser_') || key.includes('time_ser')) return 'Serialize';
  if (key.startsWith('deser_') || key.includes('time_deser')) return 'Deserialize';
  if (key.startsWith('total_') || key.includes('time_total')) return 'Total time';
  if (key.includes('size') || key.includes('bytes') || key.includes('memory')) return 'Size & memory';
  if (key.includes('fidelity') || key.includes('effect')) return 'Quality';
  if (key.includes('run') || key.includes('warmup') || key.includes('outlier')) return 'Samples';
  return 'Other';
}

function groupMetrics(keys) {
  const map = new Map();
  keys.forEach((k) => {
    const g = metricGroupName(k);
    if (!map.has(g)) map.set(g, []);
    map.get(g).push(k);
  });
  return [...map.entries()].map(([name, ks]) => ({ name, keys: ks }));
}

function metricLabel(key) {
  return key
    .replace(/_ns$/g, '')
    .replace(/_bytes$/g, '')
    .replace(/_per_sec$/g, '')
    .replace(/_/g, ' ');
}

function renderDetailSerializerChecklist() {
  const container = document.getElementById('detail-serializer-checklist');
  if (!container) return;
  container.innerHTML = '';
  if (!state.serializerNames.length) {
    container.textContent = 'No serializers for this filter';
    return;
  }
  state.serializerNames.forEach((name) => {
    const label = document.createElement('label');
    label.className = 'metrics-check-item';
    const cb = document.createElement('input');
    cb.type = 'checkbox';
    cb.checked = state.detailSerializers.includes(name);
    cb.addEventListener('change', () => {
      if (cb.checked) {
        if (!state.detailSerializers.includes(name)) {
          state.detailSerializers = [...state.detailSerializers, name];
        }
      } else {
        state.detailSerializers = state.detailSerializers.filter((s) => s !== name);
      }
      saveSettings();
      renderCompareMatrix();
    });
    label.appendChild(cb);
    label.appendChild(document.createTextNode(` ${name}`));
    container.appendChild(label);
  });
}

function renderMetricsChecklist() {
  const container = document.getElementById('metrics-checklist');
  if (!container) return;
  container.innerHTML = '';
  const groups = groupMetrics(state.availableMetrics);
  groups.forEach((group) => {
    const title = document.createElement('div');
    title.className = 'metrics-group-title';
    title.textContent = group.name;
    container.appendChild(title);
    group.keys.forEach((key) => {
      const label = document.createElement('label');
      label.className = 'metrics-check-item';
      const cb = document.createElement('input');
      cb.type = 'checkbox';
      cb.checked = state.selectedMetrics.includes(key);
      cb.addEventListener('change', () => {
        if (cb.checked) {
          if (!state.selectedMetrics.includes(key)) {
            state.selectedMetrics = [...state.selectedMetrics, key];
          }
        } else {
          state.selectedMetrics = state.selectedMetrics.filter((k) => k !== key);
        }
        saveSettings();
        renderCompareMatrix();
      });
      label.appendChild(cb);
      label.appendChild(document.createTextNode(` ${metricLabel(key)}`));
      label.title = key;
      container.appendChild(label);
    });
  });
}

function handleTableSort(key) {
  if (state.sortKey === key) {
    state.sortDirection = state.sortDirection === 'asc' ? 'desc' : 'asc';
  } else {
    state.sortKey = key;
    state.sortDirection = key === 'serializer' ? 'asc' : 'desc';
  }
  updateSortIndicators();
  saveSettings();
  renderTable();
}

function renderTable() {
  const tbody = document.getElementById('table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  let rows = state.filteredGroups.filter((g) =>
    (g.serializer || '').toLowerCase().includes(state.searchQuery)
  );

  rows.sort((a, b) => {
    let valA = a[state.sortKey];
    let valB = b[state.sortKey];
    if (valA === null || valA === undefined) return 1;
    if (valB === null || valB === undefined) return -1;
    if (typeof valA === 'string') {
      return state.sortDirection === 'asc'
        ? valA.localeCompare(valB)
        : valB.localeCompare(valA);
    }
    return state.sortDirection === 'asc' ? valA - valB : valB - valA;
  });

  // Update header units from visible data
  const scales = scalesFromGroups(rows);
  const thOps = document.getElementById('th-ops');
  const thTotal = document.getElementById('th-total-ns');
  const thSer = document.getElementById('th-ser-ns');
  const thDeser = document.getElementById('th-deser-ns');
  if (thOps) thOps.textContent = scales.ops.header;
  if (thTotal) thTotal.textContent = `Total latency (${scales.latency.header})`;
  if (thSer) thSer.textContent = `Ser latency (${scales.latency.header})`;
  if (thDeser) thDeser.textContent = `Deser latency (${scales.latency.header})`;

  if (rows.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML =
      '<td colspan="7" style="text-align:center;color:var(--text-muted);">No serializers match search query</td>';
    tbody.appendChild(tr);
    return;
  }

  rows.forEach((r) => {
    const tr = document.createElement('tr');
    const isOptimal = state.paretoSerializerNames.includes(r.serializer);
    const tdName = document.createElement('td');
    tdName.className = 'str';
    tdName.innerHTML = `<strong>${escapeHtml(r.serializer)}</strong>`;
    tr.appendChild(tdName);

    const cells = [
      ['num', formatMetricCell('avg_ops_per_sec', r.avg_ops_per_sec, scales)],
      ['num', formatMetricCell('avg_time_total_ns', r.avg_time_total_ns, scales)],
      ['num', formatMetricCell('avg_time_ser_ns', r.avg_time_ser_ns, scales)],
      ['num', formatMetricCell('avg_time_deser_ns', r.avg_time_deser_ns, scales)],
      ['num', formatMetricCell('median_size_bytes', r.median_size_bytes, scales)],
    ];
    cells.forEach(([cls, text]) => {
      const td = document.createElement('td');
      td.className = cls;
      td.textContent = text;
      tr.appendChild(td);
    });

    const tdOpt = document.createElement('td');
    tdOpt.className = 'status';
    tdOpt.innerHTML = isOptimal
      ? '<span class="badge badge-cyan">Optimal</span>'
      : '<span class="badge badge-slate">Dominated</span>';
    tr.appendChild(tdOpt);
    tbody.appendChild(tr);
  });
}

function renderCompareMatrix() {
  const thead = document.getElementById('serializer-metrics-head');
  const tbody = document.getElementById('serializer-metrics-body');
  if (!thead || !tbody) return;
  thead.innerHTML = '';
  tbody.innerHTML = '';

  /** @type {{ key: string, label: string, group: object|null, isBaseline: boolean }[]} */
  let columns = [];

  if (state.compareScope === 'same') {
    const names = state.detailSerializers.filter((s) => state.serializerNames.includes(s));
    // Baseline first
    const ordered = [];
    if (state.compareBaseline && names.includes(state.compareBaseline)) {
      ordered.push(state.compareBaseline);
    }
    names.forEach((n) => {
      if (!ordered.includes(n)) ordered.push(n);
    });
    columns = ordered.map((name) => ({
      key: name,
      label: name,
      group: state.filteredGroups.find((g) => g.serializer === name) || null,
      isBaseline: name === state.compareBaseline,
    }));
  } else {
    const ordered = [...state.xlSelected];
    // baseline first
    const bi = ordered.findIndex((x) => `${x.lang}|${x.serializer}` === state.xlBaselineKey);
    if (bi > 0) {
      const [b] = ordered.splice(bi, 1);
      ordered.unshift(b);
    }
    columns = ordered.map((x) => ({
      key: `${x.lang}|${x.serializer}`,
      label: `${languageLabel(x.lang)} / ${x.serializer}`,
      group: findCrossLangGroup(x.lang, x.serializer),
      isBaseline: `${x.lang}|${x.serializer}` === state.xlBaselineKey,
    }));
  }

  const headerRow = document.createElement('tr');
  const metricTh = document.createElement('th');
  metricTh.className = 'str';
  metricTh.textContent = 'Metric';
  headerRow.appendChild(metricTh);
  columns.forEach((col) => {
    const th = document.createElement('th');
    th.className = 'num' + (col.isBaseline ? ' baseline-col' : '');
    th.textContent = col.isBaseline ? `${col.label} (baseline)` : col.label;
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

  // Metrics: use selected; if cross-lang prefer known keys that exist
  let selectedKeys = state.selectedMetrics.filter((k) => state.availableMetrics.includes(k));
  if (state.compareScope === 'cross') {
    // Union of keys from available metrics defaults that appear in any column
    const crossKeys = CROSS_LANG_METRICS.map((m) => m.key).filter((k) =>
      columns.some((c) => c.group && c.group[k] != null)
    );
    selectedKeys = state.selectedMetrics.length
      ? state.selectedMetrics.filter((k) => columns.some((c) => c.group && c.group[k] != null))
      : crossKeys;
    if (!selectedKeys.length) selectedKeys = crossKeys;
  }

  if (!selectedKeys.length) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="${colCount}" style="text-align:center;color:var(--text-muted);">Select at least one metric</td>`;
    tbody.appendChild(tr);
    return;
  }

  const groupsForScale = columns.map((c) => c.group).filter(Boolean);
  const scales = scalesFromGroups(groupsForScale, selectedKeys);
  const baselineCol = columns.find((c) => c.isBaseline) || columns[0];

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
      const tr = document.createElement('tr');
      const tdKey = document.createElement('td');
      tdKey.className = 'str';
      tdKey.textContent = metricHeaderLabel(key, scales);
      tdKey.title = key;
      tr.appendChild(tdKey);

      const baselineVal =
        baselineCol?.group && baselineCol.group[key] != null ? baselineCol.group[key] : null;
      const higherIsBetter = metricHigherIsBetter(key);

      columns.forEach((col) => {
        const td = document.createElement('td');
        const v =
          col.group && col.group[key] !== undefined && col.group[key] !== null
            ? col.group[key]
            : null;
        if (v === null) {
          td.textContent = '—';
          td.className = 'num sm-missing';
        } else if (col.isBaseline || typeof v !== 'number' || typeof baselineVal !== 'number') {
          td.textContent = formatMetricCell(key, v, scales);
          td.className = 'num';
        } else {
          const rel = formatRelativeCell(v, baselineVal, higherIsBetter, scales, key);
          td.textContent = rel.text;
          td.className = rel.className;
        }
        tr.appendChild(td);
      });
      tbody.appendChild(tr);
    });
  });
}

function escapeHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;');
}

function copyRosterMarkdown() {
  const scales = scalesFromGroups(state.filteredGroups);
  const rows = [...state.filteredGroups].sort((a, b) =>
    a.serializer.localeCompare(b.serializer)
  );
  const lines = [
    `| Serializer | ${scales.ops.header} | Total (${scales.latency.header}) | Size (bytes) | Frontier |`,
    `|---|---:|---:|---:|:---:|`,
  ];
  rows.forEach((r) => {
    const opt = state.paretoSerializerNames.includes(r.serializer) ? 'Optimal' : '';
    lines.push(
      `| ${r.serializer} | ${formatMetricCell('avg_ops_per_sec', r.avg_ops_per_sec, scales)} | ${formatMetricCell('avg_time_total_ns', r.avg_time_total_ns, scales)} | ${formatMetricCell('median_size_bytes', r.median_size_bytes, scales)} | ${opt} |`
    );
  });
  copyText(lines.join('\n'), 'Roster Markdown copied');
}

function copyCompareMarkdown() {
  const table = document.getElementById('serializer-metrics-table');
  if (!table) return;
  const rows = [...table.querySelectorAll('tr')];
  const md = rows
    .map((tr) => {
      const cells = [...tr.children].map((td) => td.textContent.trim().replace(/\|/g, '\\|'));
      return `| ${cells.join(' | ')} |`;
    })
    .filter((line) => !line.includes('Throughput') || line.startsWith('| Metric'));
  // simpler: all rows
  const all = rows.map((tr) => {
    const cells = [...tr.children].map((td) => td.textContent.trim().replace(/\|/g, '\\|'));
    if (tr.classList.contains('metric-group-row')) {
      return `\n**${cells[0]}**\n`;
    }
    return `| ${cells.join(' | ')} |`;
  });
  copyText(all.join('\n'), 'Compare Markdown copied');
}

async function copyText(text, okMsg) {
  try {
    await navigator.clipboard.writeText(text);
    showNotification(okMsg || 'Copied', 'success');
  } catch {
    showNotification('Clipboard unavailable', 'error');
  }
}

function handleFileUpload(file) {
  if (!file) return;
  const status = document.getElementById('upload-status');
  if (status) {
    status.style.display = 'block';
    status.style.color = 'var(--text-secondary)';
    status.textContent = `Analyzing ${file.name}…`;
  }
  const reader = new FileReader();
  reader.onload = (e) => {
    try {
      const data = JSON.parse(e.target.result);
      if (!data.groups || !Array.isArray(data.groups)) {
        throw new Error("Invalid stats format. Missing 'groups' array.");
      }
      processStatsData(data);
      if (status) {
        status.style.color = 'var(--color-green)';
        status.textContent = `Successfully loaded ${file.name}`;
      }
      showNotification(`Loaded ${file.name} successfully.`, 'success');
    } catch (err) {
      if (status) {
        status.style.color = 'var(--color-red)';
        status.textContent = `Failed: ${err.message}`;
      }
      showNotification(`Upload failed: ${err.message}`, 'error');
    }
  };
  reader.readAsText(file);
}

function parseCSV(text) {
  const lines = text.trim().split(/\r?\n/);
  if (lines.length < 2) return [];
  const headers = parseCSVLine(lines[0]);
  const records = [];
  for (let i = 1; i < lines.length; i++) {
    if (!lines[i].trim()) continue;
    const values = parseCSVLine(lines[i]);
    const rec = {};
    headers.forEach((h, idx) => {
      rec[h] = values[idx];
    });
    records.push(rec);
  }
  return records;
}

function parseCSVLine(line) {
  const result = [];
  let cur = '';
  let inQuotes = false;
  for (let i = 0; i < line.length; i++) {
    const ch = line[i];
    if (ch === '"') {
      if (inQuotes && line[i + 1] === '"') {
        cur += '"';
        i++;
      } else inQuotes = !inQuotes;
    } else if (ch === ',' && !inQuotes) {
      result.push(cur);
      cur = '';
    } else cur += ch;
  }
  result.push(cur);
  return result;
}

function aggregateCSVRecords(records) {
  const map = new Map();
  for (const r of records) {
    const serializer = r.Serializer || r.serializer;
    const test_data = r.TestData || r.test_data || r.DataType;
    const mode = r.Mode || r.mode || 'bytes';
    if (!serializer) continue;
    const key = `${serializer}|${test_data}|${mode}`;
    if (!map.has(key)) {
      map.set(key, {
        serializer,
        test_data,
        mode,
        times: [],
        ser: [],
        deser: [],
        sizes: [],
        ops: [],
        fidelities: [],
      });
    }
    const g = map.get(key);
    const total = Number(r.TotalTimeNs || r.total_time_ns || r.TimeNs);
    const ser = Number(r.SerTimeNs || r.ser_time_ns);
    const deser = Number(r.DeserTimeNs || r.deser_time_ns);
    const size = Number(r.SizeBytes || r.size_bytes || r.PayloadSize);
    const ops = Number(r.OpsPerSec || r.ops_per_sec);
    const fid = Number(r.FidelityScore || r.fidelity);
    if (Number.isFinite(total)) g.times.push(total);
    if (Number.isFinite(ser)) g.ser.push(ser);
    if (Number.isFinite(deser)) g.deser.push(deser);
    if (Number.isFinite(size)) g.sizes.push(size);
    if (Number.isFinite(ops)) g.ops.push(ops);
    if (Number.isFinite(fid)) g.fidelities.push(fid);
  }

  const groups = [];
  for (const g of map.values()) {
    if (!g.times.length && !g.ops.length) continue;
    const avg_time_total_ns = mean(g.times);
    const avg_ops_per_sec =
      g.ops.length > 0 ? mean(g.ops) : avg_time_total_ns > 0 ? 1e9 / avg_time_total_ns : 0;
    groups.push({
      serializer: g.serializer,
      test_data: g.test_data,
      mode: g.mode,
      avg_time_total_ns,
      avg_time_ser_ns: mean(g.ser),
      avg_time_deser_ns: mean(g.deser),
      avg_ops_per_sec,
      median_size_bytes: median(g.sizes),
      mean_fidelity: g.fidelities.length ? mean(g.fidelities) : null,
      runs: Math.max(g.times.length, g.ops.length),
    });
  }
  return groups;
}

function mean(arr) {
  if (!arr || !arr.length) return null;
  return arr.reduce((a, b) => a + b, 0) / arr.length;
}

function median(arr) {
  if (!arr || !arr.length) return null;
  const s = [...arr].sort((a, b) => a - b);
  const m = Math.floor(s.length / 2);
  return s.length % 2 ? s[m] : (s[m - 1] + s[m]) / 2;
}

function triggerDownload(url, filename) {
  const a = document.createElement('a');
  a.href = url;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

function downloadDataUrl(dataUrl, filename) {
  const a = document.createElement('a');
  a.href = dataUrl;
  a.download = filename;
  document.body.appendChild(a);
  a.click();
  a.remove();
}

async function downloadFileWithFallback(url, fallbackUrl, filename) {
  try {
    let res = await fetch(url);
    if (!res.ok && fallbackUrl) res = await fetch(fallbackUrl);
    if (!res.ok) throw new Error('Download failed');
    const blob = await res.blob();
    const obj = URL.createObjectURL(blob);
    triggerDownload(obj, filename);
    URL.revokeObjectURL(obj);
  } catch (e) {
    showNotification('Download failed: ' + e.message, 'error');
  }
}

function showNotification(msg, type) {
  const notif = document.createElement('div');
  notif.style.position = 'fixed';
  notif.style.bottom = '2rem';
  notif.style.right = '2rem';
  notif.style.padding = '0.85rem 1.25rem';
  notif.style.borderRadius = '8px';
  notif.style.color = '#fff';
  notif.style.zIndex = '10000';
  notif.style.fontSize = '0.9rem';
  notif.style.boxShadow = '0 8px 24px rgba(0,0,0,0.2)';
  notif.textContent = msg;
  if (type === 'error') notif.style.background = 'rgba(217, 48, 37, 0.92)';
  else if (type === 'info') notif.style.background = 'rgba(26, 115, 232, 0.92)';
  else notif.style.background = 'rgba(30, 142, 62, 0.92)';
  document.body.appendChild(notif);
  setTimeout(() => {
    notif.style.opacity = '0';
    notif.style.transition = 'opacity 0.3s';
    setTimeout(() => notif.remove(), 300);
  }, 2800);
}
