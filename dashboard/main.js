/**
 * Dashboard UI terminology: always say **data type** (test_data control label).
 * Never use "fixture" in user-visible copy, notifications, KPIs, or export notes.
 * Internal helpers may still say fixture* in identifiers until renamed.
 */
import {
  initCharts,
  updateCharts,
  setChartLogScale,
  getChartLogScale,
  setRankSort,
  getRankSort,
  exportScatterPng,
  exportBarPng,
} from './charts.js';
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
  formatOpsCell,
  chooseLatencyUnit,
  chooseOpsUnit,
  serializerLabelFromGroup,
} from './format.js';

const SETTINGS_KEY = 'serializer-dashboard-settings-v2';
/** localStorage: hide first-visit orientation banner when set to "1". */
const ORIENTATION_KEY = 'serializer-dashboard-orientation-dismissed-v1';

const GROUP_META_KEYS = new Set([
  'serializer',
  'test_data',
  'mode',
  'language',
  'filter',
  'variants',
  'serializer_version',
  'type_config_hash',
  'StreamMode',
  'compounded',
  'compound_parts',
]);
const SUITE_TYPE_IDS = ['message', 'document', 'telemetry', 'strings', 'event'];

/** Named sample-filter policies (must match analysis FILTER_POLICY_IDS). */
const FILTER_POLICY_FALLBACK = {
  all: {
    id: 'all',
    label: 'All trials (post-warmup)',
    description:
      'Every measured repetition after warmup. No IQR drop and no winsorization.',
  },
  'iqr_1.5': {
    id: 'iqr_1.5',
    label: 'IQR k=1.5 (strict / default)',
    description:
      'Paired Tukey fences (k=1.5) on ser/deser/total; drop if outlier on any.',
  },
  iqr_3: {
    id: 'iqr_3',
    label: 'IQR k=3 (loose)',
    description: 'Same paired IQR rule with k=3 (only extreme stalls removed).',
  },
  winsorize_5_95: {
    id: 'winsorize_5_95',
    label: 'Winsorize 5–95%',
    description: 'Clip ser/deser/total at 5th–95th percentiles; n unchanged.',
  },
};
const DEFAULT_FILTER_POLICY = 'iqr_1.5';
const FILTER_POLICY_ORDER = ['all', 'iqr_1.5', 'iqr_3', 'winsorize_5_95'];

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
  { id: 'c', label: 'C' },
  { id: 'csharp', label: 'C#' },
  { id: 'cpp', label: 'C++' },
  { id: 'go', label: 'Go' },
  { id: 'java', label: 'Java' },
  { id: 'javascript', label: 'JavaScript' },
  { id: 'kotlin', label: 'Kotlin' },
  { id: 'python', label: 'Python' },
  { id: 'rust', label: 'Rust' },
  { id: 'swift', label: 'Swift' },
];

const CROSS_LANG_METRICS = [
  { key: 'avg_ops_per_sec', label: 'Ops/s', higherIsBetter: true },
  { key: 'avg_time_total_ns', label: 'Total latency (mean)', higherIsBetter: false },
  { key: 'avg_time_ser_ns', label: 'Ser latency', higherIsBetter: false },
  { key: 'avg_time_deser_ns', label: 'Deser latency', higherIsBetter: false },
  { key: 'total_median_ns', label: 'Median total', higherIsBetter: false },
  { key: 'total_p95_ns', label: 'Total p95', higherIsBetter: false },
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
  'total_p95_ns',
  'total_ci_low_ns',
  'total_ci_high_ns',
  'median_size_bytes',
  'mean_fidelity',
  'mean_memory_peak_bytes',
  'runs',
  'serializer_version',
];

/** Max serializer columns in Compare matrix (baseline counts). */
const MAX_COMPARE_COLUMNS = 8;

/** Metric presets for Compare catalog. */
const METRIC_PRESETS = {
  defaults: DEFAULT_SELECTED_METRICS,
  latency: [
    'avg_time_total_ns',
    'avg_time_ser_ns',
    'avg_time_deser_ns',
    'total_median_ns',
    'total_p95_ns',
    'total_p50_ns',
    'total_p99_ns',
    'total_ci_low_ns',
    'total_ci_high_ns',
    'total_cv',
    'ser_median_ns',
    'deser_median_ns',
  ],
  size: ['median_size_bytes', 'mean_memory_peak_bytes', 'mean_fidelity', 'runs'],
};

/** Open metric accordion groups (name -> bool). */
const metricAccordionOpen = {};

let state = {
  currentLanguage: 'csharp',
  currentTestData: '',
  currentMode: '',
  displayMetric: 'ops', // charts / ranking toolbar
  /** Detailed Analytics only: 'ops' | 'time' (independent of displayMetric). */
  rosterMetric: 'ops',
  rankSort: 'speed', // 'speed' | 'size' for ranking chart
  searchQuery: '',
  sortKey: 'serializer',
  sortDirection: 'asc',
  allGroups: [],
  /** @type {Record<string, object[]>} policy id → full group list for current language */
  groupsByPolicy: {},
  /** @type {Record<string, object>} policy catalog from export or fallback */
  filterPolicies: { ...FILTER_POLICY_FALLBACK },
  filterPolicy: DEFAULT_FILTER_POLICY,
  defaultFilterPolicy: DEFAULT_FILTER_POLICY,
  filteredGroups: [],
  paretoSerializerNames: [],
  serializerNames: [],
  detailSerializers: [],
  availableMetrics: [],
  selectedMetrics: [...DEFAULT_SELECTED_METRICS],
  compareBaseline: '',
  compareScope: 'same', // 'same' | 'cross'

  /** @type {Record<string, Record<string, object[]>>} lang → policy → groups */
  crossLangGroupsByLangPolicy: {},
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
  const sels = [
    document.getElementById('lang-select'),
    document.getElementById('same-lang-select'),
  ].filter(Boolean);
  if (!sels.length) return;
  const prev = state.currentLanguage;
  sels.forEach((sel) => {
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
    }
  });
  if (sels[0] && ![...sels[0].options].some((o) => o.value === state.currentLanguage)) {
    state.currentLanguage = sels[0].value;
  }
}

/** Keep toolbar + Compare same-language filters in sync. */
function syncLanguageSelects() {
  ['lang-select', 'same-lang-select'].forEach((id) => {
    const el = document.getElementById(id);
    if (el && [...el.options].some((o) => o.value === state.currentLanguage)) {
      el.value = state.currentLanguage;
    }
  });
}

function syncFixtureModeSelects() {
  ['data-select', 'same-data-select'].forEach((id) => {
    const el = document.getElementById(id);
    if (el && [...el.options].some((o) => o.value === state.currentTestData)) {
      el.value = state.currentTestData;
    }
  });
  ['mode-select', 'same-mode-select'].forEach((id) => {
    const el = document.getElementById(id);
    if (el && [...el.options].some((o) => o.value === state.currentMode)) {
      el.value = state.currentMode;
    }
  });
}

document.addEventListener('DOMContentLoaded', async () => {
  populateLanguageSelect();
  applySavedSettings(loadSettings());
  applyUrlParams();
  setupEventListeners();
  setupOrientationBanner();
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

/** Dismissible first-visit tip (visible by default; hidden after Got it). */
function setupOrientationBanner() {
  const banner = document.getElementById('orientation-banner');
  const btn = document.getElementById('orientation-dismiss');
  if (!banner) return;
  let dismissed = false;
  try {
    dismissed = localStorage.getItem(ORIENTATION_KEY) === '1';
  } catch (_) {
    /* private mode */
  }
  if (dismissed) banner.hidden = true;
  btn?.addEventListener('click', () => {
    banner.hidden = true;
    try {
      localStorage.setItem(ORIENTATION_KEY, '1');
    } catch (_) {
      /* ignore */
    }
  });
}

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
    rosterMetric: state.rosterMetric,
    rankSort: state.rankSort,
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
    filterPolicy: state.filterPolicy,
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
  if (typeof saved.currentMode === 'string') {
    state.currentMode = normalizeMode(saved.currentMode) || saved.currentMode;
  }
  if (saved.displayMetric === 'ops' || saved.displayMetric === 'time') {
    state.displayMetric = saved.displayMetric;
  }
  if (saved.rosterMetric === 'ops' || saved.rosterMetric === 'time') {
    state.rosterMetric = saved.rosterMetric;
  }
  if (saved.rankSort === 'speed' || saved.rankSort === 'size') {
    state.rankSort = saved.rankSort;
    setRankSort(state.rankSort);
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
  if (typeof saved.filterPolicy === 'string' && saved.filterPolicy) {
    state.filterPolicy = saved.filterPolicy;
  }
  if (typeof saved.chartLogScale === 'boolean') {
    state.chartLogScale = saved.chartLogScale;
    setChartLogScale(state.chartLogScale);
  }
}

function applyUrlParams() {
  const p = new URLSearchParams(window.location.search);
  if (p.has('lang')) state.currentLanguage = p.get('lang');
  if (p.has('data')) state.currentTestData = p.get('data');
  if (p.has('mode')) state.currentMode = normalizeMode(p.get('mode')) || p.get('mode');
  if (p.get('metric') === 'ops' || p.get('metric') === 'time') state.displayMetric = p.get('metric');
  if (p.get('scope') === 'cross' || p.get('scope') === 'same') state.compareScope = p.get('scope');
  if (p.has('baseline')) state.compareBaseline = p.get('baseline');
  if (p.has('log')) state.chartLogScale = p.get('log') === '1';
  if (p.get('rank') === 'size' || p.get('rank') === 'speed') {
    state.rankSort = p.get('rank');
    setRankSort(state.rankSort);
  }
  if (p.has('policy')) state.filterPolicy = p.get('policy');
  const sers = p.getAll('ser').filter(Boolean);
  if (sers.length) state.detailSerializers = sers.slice(0, MAX_COMPARE_COLUMNS);
  setChartLogScale(state.chartLogScale);
}

function syncUrlFromState() {
  try {
    const p = new URLSearchParams();
    p.set('lang', state.currentLanguage);
    if (state.currentTestData) p.set('data', state.currentTestData);
    const mode = normalizeMode(state.currentMode) || state.currentMode;
    if (mode) p.set('mode', mode);
    p.set('metric', state.displayMetric);
    if (state.compareScope === 'cross') p.set('scope', 'cross');
    if (state.compareBaseline) p.set('baseline', state.compareBaseline);
    if (state.chartLogScale) p.set('log', '1');
    if (state.rankSort === 'size') p.set('rank', 'size');
    if (state.filterPolicy && state.filterPolicy !== DEFAULT_FILTER_POLICY) {
      p.set('policy', state.filterPolicy);
    }
    const sers = (state.detailSerializers || []).filter(Boolean).slice(0, MAX_COMPARE_COLUMNS);
    for (const s of sers) p.append('ser', s);
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
  document.getElementById('btn-roster-ops')?.classList.toggle('active', state.rosterMetric === 'ops');
  document.getElementById('btn-roster-latency')?.classList.toggle('active', state.rosterMetric === 'time');
  document.getElementById('btn-chart-log')?.classList.toggle('active', state.chartLogScale);
  document.getElementById('btn-rank-sort-speed')?.classList.toggle('active', state.rankSort !== 'size');
  document.getElementById('btn-rank-sort-size')?.classList.toggle('active', state.rankSort === 'size');
  setRankSort(state.rankSort);
  updateRankSortPrimaryLabel();

  const search = document.getElementById('table-search');
  if (search) search.value = state.searchQuery || '';

  updateSortIndicators();
  applyCompareScopeUi();
}

/** Rank-sort primary button: Ops/s vs Latency (not generic "Speed"). */
function updateRankSortPrimaryLabel() {
  const btn = document.getElementById('btn-rank-sort-speed');
  if (!btn) return;
  if (state.displayMetric === 'time') {
    btn.textContent = 'Latency';
    btn.title = 'Sort by latency (lowest first)';
  } else {
    btn.textContent = 'Ops/s';
    btn.title = 'Sort by ops/s (highest first)';
  }
}


function updateSortIndicators() {
  document.querySelectorAll('#analytics-table th').forEach((th) => {
    th.classList.remove('sort-asc', 'sort-desc');
  });
  const sortHeaderMap = {
    serializer: 'th-serializer',
    ops_median: 'th-ops-median',
    ops_std: 'th-ops-std',
    ops_p95: 'th-ops-p95',
    ops_p99: 'th-ops-p99',
    total_median_ns: 'th-lat-median',
    total_std_ns: 'th-lat-std',
    total_p95_ns: 'th-lat-p95',
    total_p99_ns: 'th-lat-p99',
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
  const samePanel = document.getElementById('compare-same-panel');
  const xlPanel = document.getElementById('xl-add-panel');
  const sameChips = document.getElementById('same-selection-chips');
  const xlChips = document.getElementById('xl-selection-chips');
  const disclaimer = document.getElementById('compare-xl-disclaimer');
  const badge = document.getElementById('compare-scope-badge');
  const serAll = document.getElementById('detail-ser-select-all');
  const seedPareto = document.getElementById('xl-reset-pareto');

  if (sameFilters) sameFilters.hidden = !same;
  if (xlFilters) xlFilters.hidden = same;
  if (samePanel) samePanel.hidden = !same;
  if (xlPanel) xlPanel.hidden = same;
  if (sameChips) sameChips.hidden = !same;
  if (xlChips) xlChips.hidden = same;
  if (disclaimer) disclaimer.hidden = same;
  if (serAll) serAll.hidden = !same;
  if (seedPareto) seedPareto.hidden = same;
  if (badge) {
    badge.hidden = true; // status line + Same/Cross tabs already convey mode
  }
  updateCompareStatusLine();
}

function updateCompareStatusLine() {
  const el = document.getElementById('compare-status-line');
  const countEl = document.getElementById('compare-selected-count');
  const metricsEl = document.getElementById('metrics-selected-count');
  let n = 0;
  if (state.compareScope === 'same') {
    n = state.detailSerializers.filter((s) => state.serializerNames.includes(s)).length;
  } else {
    n = state.xlSelected.length;
  }
  const m = state.selectedMetrics.filter((k) =>
    state.availableMetrics.length ? state.availableMetrics.includes(k) : true
  ).length;
  if (el) {
    const serLabel = n === 1 ? 'serializer' : 'serializers';
    const metLabel = m === 1 ? 'metric' : 'metrics';
    el.textContent = `${n} ${serLabel} · ${m} ${metLabel}`;
  }
  if (countEl) countEl.textContent = String(n);
  if (metricsEl) metricsEl.textContent = String(m);
}

function setupEventListeners() {
  document.getElementById('filter-policy-select')?.addEventListener('change', (e) => {
    setFilterPolicy(e.target.value);
  });

  const runConfigToggle = document.getElementById('run-config-toggle');
  const runConfigPanel = document.getElementById('run-config-panel');
  runConfigToggle?.addEventListener('click', () => {
    const open = runConfigToggle.getAttribute('aria-expanded') === 'true';
    const next = !open;
    runConfigToggle.setAttribute('aria-expanded', next ? 'true' : 'false');
    if (runConfigPanel) runConfigPanel.hidden = !next;
  });

  // Mobile nav
  const navToggle = document.getElementById('nav-toggle');
  const mainNav = document.getElementById('main-nav');
  navToggle?.addEventListener('click', () => {
    const open = mainNav?.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', open ? 'true' : 'false');
  });

  const onLanguageChange = async (e) => {
    state.currentLanguage = e.target.value;
    syncLanguageSelects();
    saveSettings();
    await loadLanguageData(state.currentLanguage);
  };
  document.getElementById('lang-select')?.addEventListener('change', onLanguageChange);
  document.getElementById('same-lang-select')?.addEventListener('change', onLanguageChange);

  const onDataChange = (e) => {
    state.currentTestData = e.target.value;
    syncFixtureModeSelects();
    saveSettings();
    filterAndRefresh();
  };
  document.getElementById('data-select')?.addEventListener('change', onDataChange);
  document.getElementById('same-data-select')?.addEventListener('change', onDataChange);

  const onModeChange = (e) => {
    state.currentMode = e.target.value;
    syncFixtureModeSelects();
    saveSettings();
    filterAndRefresh();
  };
  document.getElementById('mode-select')?.addEventListener('change', onModeChange);
  document.getElementById('same-mode-select')?.addEventListener('change', onModeChange);

  document.getElementById('btn-ops-sec')?.addEventListener('click', () => setViewMetric('ops'));
  document.getElementById('btn-time-ns')?.addEventListener('click', () => setViewMetric('time'));

  document.getElementById('btn-roster-ops')?.addEventListener('click', () => setRosterMetric('ops'));
  document.getElementById('btn-roster-latency')?.addEventListener('click', () => setRosterMetric('time'));

  document.getElementById('btn-chart-log')?.addEventListener('click', () => {
    state.chartLogScale = !state.chartLogScale;
    setChartLogScale(state.chartLogScale);
    document.getElementById('btn-chart-log')?.classList.toggle('active', state.chartLogScale);
    saveSettings();
    updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  });

  const setRankingSort = (sort) => {
    state.rankSort = sort === 'size' ? 'size' : 'speed';
    setRankSort(state.rankSort);
    document.getElementById('btn-rank-sort-speed')?.classList.toggle('active', state.rankSort === 'speed');
    document.getElementById('btn-rank-sort-size')?.classList.toggle('active', state.rankSort === 'size');
    updateRankSortPrimaryLabel();
    saveSettings();
    updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  };
  document.getElementById('btn-rank-sort-speed')?.addEventListener('click', () => setRankingSort('speed'));
  document.getElementById('btn-rank-sort-size')?.addEventListener('click', () => setRankingSort('size'));

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
    { id: 'th-ops-median', key: 'ops_median' },
    { id: 'th-ops-std', key: 'ops_std' },
    { id: 'th-ops-p95', key: 'ops_p95' },
    { id: 'th-ops-p99', key: 'ops_p99' },
    { id: 'th-lat-median', key: 'total_median_ns' },
    { id: 'th-lat-std', key: 'total_std_ns' },
    { id: 'th-lat-p95', key: 'total_p95_ns' },
    { id: 'th-lat-p99', key: 'total_p99_ns' },
    { id: 'th-size', key: 'median_size_bytes' },
  ];
  headers.forEach((h) => {
    const el = document.getElementById(h.id);
    if (el) el.addEventListener('click', () => handleTableSort(h.key));
  });

  const onBaselineChange = (e) => {
    state.compareBaseline = e.target.value;
    // Keep roster + compare pickers in sync
    const otherIds = ['compare-baseline-select', 'roster-baseline-select'];
    otherIds.forEach((id) => {
      const el = document.getElementById(id);
      if (el && el !== e.target && [...el.options].some((o) => o.value === state.compareBaseline)) {
        el.value = state.compareBaseline;
      }
    });
    // Ensure baseline is in compare selection
    if (
      state.compareScope === 'same' &&
      state.compareBaseline &&
      !state.detailSerializers.includes(state.compareBaseline)
    ) {
      state.detailSerializers = [state.compareBaseline, ...state.detailSerializers].slice(
        0,
        MAX_COMPARE_COLUMNS
      );
    }
    saveSettings();
    renderSameSelectionChips();
    populateSameSerAddSelect();
    renderTable();
    renderCompareMatrix();
  };
  document.getElementById('compare-baseline-select')?.addEventListener('change', onBaselineChange);
  document.getElementById('roster-baseline-select')?.addEventListener('change', onBaselineChange);

  document.getElementById('btn-compare-same')?.addEventListener('click', () => {
    state.compareScope = 'same';
    applyCompareScopeUi();
    renderSameSelectionChips();
    populateSameSerAddSelect();
    saveSettings();
    renderCompareMatrix();
  });

  document.getElementById('btn-compare-xl')?.addEventListener('click', async () => {
    state.compareScope = 'cross';
    applyCompareScopeUi();
    saveSettings();
    await ensureCrossLangLoaded();
    renderCrossLangSelection();
    renderCompareMatrix();
  });

  document.getElementById('detail-ser-select-all')?.addEventListener('click', () => {
    // Same-language only: add all (capped)
    state.detailSerializers = state.serializerNames.slice(0, MAX_COMPARE_COLUMNS);
    if (
      state.compareBaseline &&
      !state.detailSerializers.includes(state.compareBaseline) &&
      state.serializerNames.includes(state.compareBaseline)
    ) {
      state.detailSerializers = [
        state.compareBaseline,
        ...state.detailSerializers.filter((s) => s !== state.compareBaseline),
      ].slice(0, MAX_COMPARE_COLUMNS);
    }
    saveSettings();
    renderSameSelectionChips();
    populateSameSerAddSelect();
    renderCompareMatrix();
    updateCompareStatusLine();
  });

  document.getElementById('detail-ser-select-none')?.addEventListener('click', () => {
    if (state.compareScope === 'same') {
      state.detailSerializers = state.compareBaseline ? [state.compareBaseline] : [];
      renderSameSelectionChips();
      populateSameSerAddSelect();
    } else {
      state.xlSelected = [];
      state.xlSelectionMode = 'custom';
      renderCrossLangSelection();
      updateXlBaselineSelect();
    }
    saveSettings();
    renderCompareMatrix();
    updateCompareStatusLine();
  });

  document.getElementById('same-ser-search')?.addEventListener('input', () => {
    populateSameSerAddSelect();
  });

  document.getElementById('same-ser-add-btn')?.addEventListener('click', () => {
    addSameLanguageSerializer(document.getElementById('same-ser-add-select')?.value);
  });

  document.getElementById('same-ser-add-select')?.addEventListener('keydown', (e) => {
    if (e.key === 'Enter') {
      e.preventDefault();
      addSameLanguageSerializer(e.target.value);
    }
  });

  document.getElementById('metrics-select-all')?.addEventListener('click', () => {
    state.selectedMetrics = [...state.availableMetrics];
    setMetricsPresetActive('custom');
    openMetricsPanel(true);
    saveSettings();
    renderMetricsChecklist();
    renderCompareMatrix();
    updateCompareStatusLine();
  });

  document.getElementById('metrics-select-none')?.addEventListener('click', () => {
    state.selectedMetrics = [];
    setMetricsPresetActive('custom');
    openMetricsPanel(true);
    saveSettings();
    renderMetricsChecklist();
    renderCompareMatrix();
    updateCompareStatusLine();
  });

  document.getElementById('metrics-select-default')?.addEventListener('click', () => {
    applyMetricPreset('defaults');
  });
  document.getElementById('metrics-preset-latency')?.addEventListener('click', () => {
    applyMetricPreset('latency');
  });
  document.getElementById('metrics-preset-size')?.addEventListener('click', () => {
    applyMetricPreset('size');
  });
  document.getElementById('metrics-edit-toggle')?.addEventListener('click', () => {
    const body = document.getElementById('metrics-panel-body');
    const open = body && body.hidden;
    openMetricsPanel(!!open);
    setMetricsPresetActive('custom');
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
    updateCompareStatusLine();
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
    updateCompareStatusLine();
  });

  document.getElementById('xl-reset-pareto')?.addEventListener('click', () => {
    state.xlSelectionMode = 'pareto';
    applyCrossLangParetoSelection();
    // Cap columns for readability
    if (state.xlSelected.length > MAX_COMPARE_COLUMNS) {
      state.xlSelected = state.xlSelected.slice(0, MAX_COMPARE_COLUMNS);
    }
    renderCrossLangSelection();
    updateXlBaselineSelect();
    refreshCrossLangAddSerializerOptions();
    renderCompareMatrix();
    saveSettings();
    updateCompareStatusLine();
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
    if (state.xlSelected.length >= MAX_COMPARE_COLUMNS) {
      showNotification(`At most ${MAX_COMPARE_COLUMNS} serializers in Compare.`, 'info');
      return;
    }
    const group = findCrossLangGroup(lang, serializer);
    if (!group) {
      showNotification('No data for that serializer under the current data type / mode.', 'error');
      return;
    }
    state.xlSelectionMode = 'custom';
    state.xlSelected = [...state.xlSelected, { lang, serializer }];
    renderCrossLangSelection();
    updateXlBaselineSelect();
    refreshCrossLangAddSerializerOptions();
    renderCompareMatrix();
    saveSettings();
    updateCompareStatusLine();
  });

  document.getElementById('compare-xl-baseline-select')?.addEventListener('change', (e) => {
    state.xlBaselineKey = e.target.value;
    saveSettings();
    renderCrossLangSelection();
    renderCompareMatrix();
  });

  document.getElementById('btn-copy-roster-md')?.addEventListener('click', () => copyRosterMarkdown());
  document.getElementById('btn-copy-compare-md')?.addEventListener('click', () => copyCompareMarkdown());

  // Section-nav smooth scroll; close mobile drawer on any nav click
  const closeMobileNav = () => {
    document.getElementById('main-nav')?.classList.remove('open');
    document.getElementById('nav-toggle')?.setAttribute('aria-expanded', 'false');
  };

  document.querySelectorAll('.section-nav a').forEach((link) => {
    link.addEventListener('click', (e) => {
      const href = link.getAttribute('href');
      if (href && href.startsWith('#')) {
        e.preventDefault();
        document.querySelectorAll('.section-nav li').forEach((li) => li.classList.remove('active'));
        link.parentElement.classList.add('active');
        document.getElementById(href.slice(1))?.scrollIntoView({ behavior: 'smooth', block: 'start' });
        closeMobileNav();
      }
    });
  });

  document.querySelectorAll('.site-links a').forEach((link) => {
    link.addEventListener('click', () => closeMobileNav());
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

/**
 * Fetch JSON or gzip-JSON from a URL.
 * @param {string} url
 * @returns {Promise<object|null>}
 */
async function fetchJsonMaybeGzip(url) {
  const res = await fetch(url);
  if (!res.ok) return null;
  try {
    return await res.clone().json();
  } catch {
    const ds = new DecompressionStream('gzip');
    const text = await new Response(res.body.pipeThrough(ds)).text();
    return JSON.parse(text);
  }
}

/**
 * Prefer standalone multi-policy stats (gzip first); fall back to embedded stats.
 * @param {string} lang
 * @param {object|null} gzStats
 */
async function loadStatsObjectForLanguage(lang, gzStats) {
  const urls = [
    `data/stats_${lang}_latest.json.gz`,
    `data/stats_${lang}_latest.json`,
  ];
  for (const statsUrl of urls) {
    try {
      const obj = await fetchJsonMaybeGzip(statsUrl);
      if (obj && (obj.groups_by_policy || obj.groups)) return obj;
    } catch (e) {
      console.warn(`Could not load ${statsUrl}:`, e);
    }
  }
  return gzStats || { groups: [] };
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

    const statsObj = await loadStatsObjectForLanguage(lang, payload.stats);
    processStatsData(statsObj);
    updateRunMeta();
    updateHistoryUIForLanguage();
  } catch (error) {
    console.error(error);
    // Last resort: stats-only file without gz package
    try {
      const statsObj = await loadStatsObjectForLanguage(lang, null);
      if (statsObj.groups?.length || statsObj.groups_by_policy) {
        processStatsData(statsObj);
        updateRunMeta();
        updateHistoryUIForLanguage();
        return;
      }
    } catch (_) {
      /* ignore */
    }
    showNotification(`Error loading ${lang} stats. Please run sync script first.`, 'error');
    setKpiEmpty('No data');
  }
}

function formatHostMemory(mem) {
  const bytes = mem?.total_bytes ?? mem?.total ?? null;
  if (typeof bytes !== 'number' || !Number.isFinite(bytes) || bytes <= 0) return null;
  const gib = bytes / (1024 ** 3);
  if (gib >= 10) return `${Math.round(gib)} GiB RAM`;
  return `${formatSig(gib, 3)} GiB RAM`;
}

function updateRunMeta() {
  const el = document.getElementById('run-meta');
  const text = document.getElementById('run-meta-text');
  if (!el || !text) return;
  const cfg = state.currentRunConfigs || {};
  const env = cfg.environment || cfg; // packed env sometimes flat
  const cpu = env.cpu || {};
  const mem = env.memory || {};
  const runtimes = env.runtimes || {};
  const dataset = cfg.dataset || {};
  const parts = [];
  // Run id is the provenance key for this payload (not git commit — can disagree with other runs).
  if (state.currentRunId) parts.push(`run ${state.currentRunId}`);
  if (cpu.model) {
    const cores = cpu.logical_cores || cpu.cpu_count;
    parts.push(cores ? `${cpu.model} (${cores} threads)` : cpu.model);
  }
  const ram = formatHostMemory(mem);
  if (ram) parts.push(ram);
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
  const rtLabel =
    {
      csharp: '.NET',
      javascript: 'Node',
      python: 'Python',
      rust: 'rustc',
      go: 'Go',
      java: 'Java',
      kotlin: 'Kotlin',
      c: 'gcc',
      cpp: 'g++',
      swift: 'Swift',
    }[state.currentLanguage] || 'runtime';
  if (runtimes[rtKey]) {
    // Strip redundant product name if the version string already starts with it
    let ver = String(runtimes[rtKey]).split('\n')[0].trim();
    ver = ver.replace(/^rustc\s+/i, '').replace(/^go\s+version\s+/i, 'go ');
    parts.push(`${rtLabel} ${ver}`);
  }
  if (dataset.seed != null) parts.push(`seed ${dataset.seed}`);
  if (parts.length) {
    text.textContent = parts.join(' · ');
    el.hidden = false;
  } else {
    el.hidden = true;
  }
  updateRunConfigPanel();
}

const RUNTIME_KEY_BY_LANG = {
  python: 'python',
  csharp: 'dotnet',
  javascript: 'node',
  rust: 'rustc',
  go: 'go',
  c: 'gcc',
  cpp: 'g++',
  java: 'java',
  kotlin: 'java',
  swift: 'swift',
};

function firstLine(value) {
  return String(value ?? '')
    .split('\n')[0]
    .trim();
}

function formatConfigRam(mem) {
  const bytes = mem?.total_bytes ?? mem?.total ?? null;
  if (typeof bytes !== 'number' || !Number.isFinite(bytes) || bytes <= 0) return '';
  return `${(bytes / 1024 ** 3).toFixed(1)} GiB`;
}

function formatConfigRuntimes(runtimes, lang) {
  if (!runtimes || typeof runtimes !== 'object') return '';
  const prefer = [];
  const k = RUNTIME_KEY_BY_LANG[(lang || '').toLowerCase()];
  if (k && runtimes[k] != null && runtimes[k] !== '') {
    prefer.push(`${k}=${firstLine(runtimes[k])}`);
  }
  for (const [rk, rv] of Object.entries(runtimes).slice(0, 4)) {
    if (k && rk === k) continue;
    if (rv == null || rv === '') continue;
    prefer.push(`${rk}=${firstLine(rv)}`);
  }
  return prefer.slice(0, 3).join(', ');
}

function appendConfigRow(dl, term, value) {
  if (value == null || value === '') return;
  const dt = document.createElement('dt');
  dt.textContent = term;
  const dd = document.createElement('dd');
  if (value instanceof Node) {
    dd.appendChild(value);
  } else {
    dd.textContent = String(value);
  }
  dl.appendChild(dt);
  dl.appendChild(dd);
}

function buildSerializerNameList(items) {
  const ul = document.createElement('ul');
  ul.className = 'run-config-serializers';
  const list = Array.isArray(items) ? items : [];
  for (const it of list.slice(0, 40)) {
    if (!it || typeof it !== 'object') continue;
    const name = it.name;
    if (name == null || name === '') continue;
    const li = document.createElement('li');
    const ver = it.version || '';
    li.textContent = ver ? `${name} @ ${ver}` : String(name);
    ul.appendChild(li);
  }
  if (list.length > 40) {
    const more = document.createElement('li');
    more.textContent = `… (${list.length - 40} more)`;
    ul.appendChild(more);
  }
  return ul.childElementCount ? ul : null;
}

function updateRunConfigPanel() {
  const panel = document.getElementById('run-config-panel');
  if (!panel) return;
  while (panel.firstChild) panel.removeChild(panel.firstChild);

  const cfg = state.currentRunConfigs || {};
  const env = cfg.environment && typeof cfg.environment === 'object' ? cfg.environment : cfg;
  const os = env.os || {};
  const cpu = env.cpu || {};
  const mem = env.memory || {};
  const git = env.git || {};
  const dataset = cfg.dataset || {};
  const ser = cfg.serializers || {};
  const run = cfg.run || {};
  const lang = cfg.language || state.currentLanguage || '';

  const dl = document.createElement('dl');
  dl.className = 'run-config-list';

  const runId = state.currentRunId || cfg.benchmark_ts || '';
  appendConfigRow(dl, 'run', runId);
  appendConfigRow(dl, 'language', lang);
  if (os.system) {
    appendConfigRow(dl, 'os', `${os.system} ${os.release || ''}`.trim());
  }
  if (cpu.model) {
    const cores = cpu.logical_cores || cpu.cpu_count;
    appendConfigRow(dl, 'cpu', cores ? `${cpu.model} (${cores} threads)` : cpu.model);
  }
  appendConfigRow(dl, 'ram', formatConfigRam(mem));
  appendConfigRow(dl, 'runtimes', formatConfigRuntimes(env.runtimes, lang));
  if (git.commit) {
    appendConfigRow(dl, 'git', `${git.commit}${git.dirty ? ' dirty' : ''}`);
  }
  if (dataset.seed != null && dataset.seed !== '') {
    appendConfigRow(dl, 'seed', dataset.seed);
  }
  if (dataset.mode) {
    appendConfigRow(dl, 'mode', dataset.mode);
  }
  if (dataset.warmup_repetitions != null) {
    appendConfigRow(dl, 'warmup_reps', dataset.warmup_repetitions);
  }
  const serCount = ser.count != null ? ser.count : Array.isArray(ser.items) ? ser.items.length : null;
  if (serCount != null) {
    appendConfigRow(dl, 'serializers', serCount);
  }
  if (run.metrics_profile) {
    appendConfigRow(dl, 'metrics_profile', run.metrics_profile);
  }

  const fixtures = Array.isArray(dataset.fixtures) ? dataset.fixtures : [];
  const typeNames = fixtures
    .filter((f) => f && typeof f === 'object' && f.name)
    .map((f) => f.name);
  if (typeNames.length) {
    appendConfigRow(dl, 'Data types (config)', typeNames.join(', '));
  }

  const serList = buildSerializerNameList(ser.items);
  if (serList) {
    appendConfigRow(dl, 'Serializers (from CSV)', serList);
  }

  if (env.machine_id) {
    appendConfigRow(dl, 'machine_id', env.machine_id);
  }

  if (dl.childElementCount) {
    panel.appendChild(dl);
  } else {
    const empty = document.createElement('p');
    empty.className = 'run-config-empty';
    empty.textContent = 'No sidecar config found for this run.';
    panel.appendChild(empty);
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

const GROUP_IDENTITY_KEYS = new Set([
  'serializer',
  'test_data',
  'type_config_hash',
  'data_type_instance_count',
  'mode',
  'language',
  'serializer_version',
  'StreamMode',
  'variants',
]);

/**
 * Expand schema 2.2 identity+variants groups into flat per-policy rows.
 * Merges catalog label/description into each filter block (export omits them).
 * @param {object[]} slimGroups
 * @param {Record<string, object>} catalog
 * @returns {Record<string, object[]>}
 */
function expandVariantGroups(slimGroups, catalog) {
  /** @type {Record<string, object[]>} */
  const byPolicy = {};
  for (const g of slimGroups) {
    const variants = g.variants;
    if (!variants || typeof variants !== 'object') continue;
    const identity = {};
    for (const [k, v] of Object.entries(g)) {
      if (!GROUP_IDENTITY_KEYS.has(k) || k === 'variants') continue;
      identity[k] = v;
    }
    // Always copy known identity fields even if null
    for (const k of [
      'serializer',
      'test_data',
      'type_config_hash',
      'data_type_instance_count',
      'mode',
      'language',
      'serializer_version',
    ]) {
      if (k in g) identity[k] = g[k];
    }
    if (g.StreamMode != null) identity.StreamMode = g.StreamMode;

    for (const [pid, metrics] of Object.entries(variants)) {
      if (!metrics || typeof metrics !== 'object') continue;
      const cat = catalog[pid] || FILTER_POLICY_FALLBACK[pid] || {};
      const filter = { ...(metrics.filter || {}) };
      if (filter.label == null && cat.label) filter.label = cat.label;
      if (filter.description == null && cat.description) filter.description = cat.description;
      if (filter.policy == null) filter.policy = pid;
      const row = {
        ...identity,
        ...metrics,
        filter,
        test_data: fixtureKey({ ...identity, ...metrics }),
      };
      if (!byPolicy[pid]) byPolicy[pid] = [];
      byPolicy[pid].push(row);
    }
  }
  return byPolicy;
}

/**
 * Normalize a stats export (schema 2.0 / 2.1 / 2.2) into groupsByPolicy.
 * @param {object} statsObj
 * @returns {{ groupsByPolicy: Record<string, object[]>, defaultPolicy: string, catalog: object }}
 */
function normalizeStatsPayload(statsObj) {
  const raw = statsObj || {};
  const catalog = {
    ...FILTER_POLICY_FALLBACK,
    ...(raw.filter_policies && typeof raw.filter_policies === 'object'
      ? raw.filter_policies
      : {}),
  };
  const defaultPolicy =
    typeof raw.default_filter_policy === 'string' && raw.default_filter_policy
      ? raw.default_filter_policy
      : DEFAULT_FILTER_POLICY;

  const mapGroups = (list) =>
    (Array.isArray(list) ? list : []).map((g) => ({
      ...g,
      test_data: fixtureKey(g),
    }));

  /** @type {Record<string, object[]>} */
  let groupsByPolicy = {};

  // Schema 2.2: identity once + variants
  const rawGroups = Array.isArray(raw.groups) ? raw.groups : [];
  const isSlimVariants =
    rawGroups.length > 0 &&
    rawGroups.some((g) => g && typeof g === 'object' && g.variants && typeof g.variants === 'object');

  if (isSlimVariants) {
    groupsByPolicy = expandVariantGroups(rawGroups, catalog);
  } else if (raw.groups_by_policy && typeof raw.groups_by_policy === 'object') {
    // Schema 2.1
    for (const [pid, list] of Object.entries(raw.groups_by_policy)) {
      groupsByPolicy[pid] = mapGroups(list);
    }
  }

  // Schema 2.0 / fallback: flat groups = single policy
  if (!Object.keys(groupsByPolicy).length && rawGroups.length) {
    groupsByPolicy[defaultPolicy] = mapGroups(rawGroups);
  } else if (rawGroups.length && !isSlimVariants && !groupsByPolicy[defaultPolicy]?.length) {
    groupsByPolicy[defaultPolicy] = mapGroups(rawGroups);
  }

  return { groupsByPolicy, defaultPolicy, catalog };
}

function processStatsData(statsObj) {
  const { groupsByPolicy, defaultPolicy, catalog } = normalizeStatsPayload(statsObj);
  state.groupsByPolicy = groupsByPolicy;
  state.defaultFilterPolicy = defaultPolicy;
  state.filterPolicies = catalog;

  // Keep selection if still available; else fall back to export default
  const available = Object.keys(groupsByPolicy);
  if (!available.includes(state.filterPolicy)) {
    state.filterPolicy = available.includes(defaultPolicy)
      ? defaultPolicy
      : available[0] || DEFAULT_FILTER_POLICY;
  }

  applyFilterPolicyToAllGroups({ refreshSelectors: true });
  populateFilterPolicySelect();
  syncLanguageSelects();
  syncFixtureModeSelects();
  discoverMetricKeys(state.allGroups);
  filterAndRefresh();
}

/** Bind state.allGroups from the active filter policy. */
function applyFilterPolicyToAllGroups({ refreshSelectors = false } = {}) {
  const pid = state.filterPolicy;
  const groups =
    state.groupsByPolicy[pid] ||
    state.groupsByPolicy[state.defaultFilterPolicy] ||
    state.groupsByPolicy[DEFAULT_FILTER_POLICY] ||
    [];
  state.allGroups = groups;

  if (refreshSelectors) {
    const discovered = discoverFixtureOptions(state.allGroups);
    const testDataOptions = discovered.all;
    const modeOptions = [
      ...new Set(state.allGroups.map((g) => normalizeMode(g.mode)).filter(Boolean)),
    ];

    populateFixtureSelect(testDataOptions);
    populateFixtureSelect(testDataOptions, {
      selectId: 'same-data-select',
      previous: state.currentTestData,
    });
    populateSelect('mode-select', modeOptions, modeDisplayLabel);
    populateSelect('same-mode-select', modeOptions, modeDisplayLabel);

    if (!testDataOptions.includes(state.currentTestData)) {
      state.currentTestData =
        pickPreferredFixture(discovered.natural) || testDataOptions[0] || '';
    }
    const wantMode = normalizeMode(state.currentMode) || state.currentMode;
    if (modeOptions.includes(wantMode)) {
      state.currentMode = wantMode;
    } else {
      state.currentMode = modeOptions[0] || '';
    }
  }
}

function populateFilterPolicySelect() {
  const sel = document.getElementById('filter-policy-select');
  if (!sel) return;
  const available = FILTER_POLICY_ORDER.filter((id) => state.groupsByPolicy[id]?.length);
  const extras = Object.keys(state.groupsByPolicy).filter((id) => !available.includes(id));
  const ids = available.length ? [...available, ...extras] : Object.keys(state.groupsByPolicy);

  sel.innerHTML = '';
  if (!ids.length) {
    const opt = document.createElement('option');
    opt.value = DEFAULT_FILTER_POLICY;
    opt.textContent = FILTER_POLICY_FALLBACK[DEFAULT_FILTER_POLICY]?.label || DEFAULT_FILTER_POLICY;
    sel.appendChild(opt);
    sel.disabled = true;
    return;
  }
  sel.disabled = ids.length <= 1;
  for (const id of ids) {
    const meta = state.filterPolicies[id] || FILTER_POLICY_FALLBACK[id] || { label: id };
    const opt = document.createElement('option');
    opt.value = id;
    opt.textContent = meta.label || id;
    sel.appendChild(opt);
  }
  if (ids.includes(state.filterPolicy)) sel.value = state.filterPolicy;
  else {
    state.filterPolicy = ids[0];
    sel.value = ids[0];
  }
}

function setFilterPolicy(policyId) {
  if (!policyId) return;
  if (!(policyId in state.groupsByPolicy)) {
    showNotification(`Sample policy “${policyId}” not in this export.`, 'error');
    return;
  }
  state.filterPolicy = policyId;
  applyFilterPolicyToAllGroups({ refreshSelectors: false });
  discoverMetricKeys(state.allGroups);
  if (state.crossLangLoaded) {
    rebuildCrossLangForPolicy();
  }
  filterAndRefresh();
  if (state.compareScope === 'cross') {
    renderCrossLangSelection();
    renderCompareMatrix();
  }
}

function updateFilterPolicyMeta() {
  const el = document.getElementById('filter-policy-meta');
  const text = document.getElementById('filter-policy-meta-text');
  if (!el || !text) return;

  const pid = state.filterPolicy;
  const catalog = state.filterPolicies[pid] || FILTER_POLICY_FALLBACK[pid] || {};
  const sample = state.filteredGroups[0] || state.allGroups[0];
  const f = sample?.filter || {};

  const removed = state.filteredGroups.length
    ? state.filteredGroups.reduce((a, g) => a + (Number(g.outliers_removed) || 0), 0)
    : state.allGroups.reduce((a, g) => a + (Number(g.outliers_removed) || 0), 0);
  const clipped = state.filteredGroups.length
    ? state.filteredGroups.reduce((a, g) => a + (Number(g.values_clipped) || 0), 0)
    : state.allGroups.reduce((a, g) => a + (Number(g.values_clipped) || 0), 0);
  const kept = state.filteredGroups.length
    ? state.filteredGroups.reduce((a, g) => a + (Number(g.runs) || 0), 0)
    : null;

  const criteriaBits = [];
  const method = f.method || catalog.outlier_method;
  if (method) criteriaBits.push(`method=${method}`);
  if (f.iqr_k != null || catalog.iqr_k != null) {
    criteriaBits.push(`k=${f.iqr_k ?? catalog.iqr_k}`);
  }
  if (f.winsorize_percentiles || catalog.winsorize_percentiles) {
    const w = f.winsorize_percentiles || catalog.winsorize_percentiles;
    criteriaBits.push(`clip=${Array.isArray(w) ? w.join('–') : w}%`);
  }
  if (f.paired === true || catalog.paired === true) criteriaBits.push('paired ser/deser/total');
  if (f.exclude_warmup !== false && catalog.exclude_warmup !== false) {
    criteriaBits.push('warmup excluded');
  }
  if (f.min_samples_for_outlier_filter != null || catalog.min_samples_for_outlier_filter != null) {
    criteriaBits.push(
      `min_n=${f.min_samples_for_outlier_filter ?? catalog.min_samples_for_outlier_filter}`
    );
  }
  if (f.fence_total_low_ns != null && f.fence_total_high_ns != null && sample) {
    criteriaBits.push(
      `e.g. total fences [${formatTimeCompact(f.fence_total_low_ns)}, ${formatTimeCompact(f.fence_total_high_ns)}] on ${sample.serializer}`
    );
  }

  const statsBits = [];
  if (kept != null) statsBits.push(`${formatIntGrouped(kept)} trials kept (current data type)`);
  if (removed > 0) statsBits.push(`${formatIntGrouped(removed)} reps removed (sum over rows)`);
  if (clipped > 0) statsBits.push(`${formatIntGrouped(clipped)} reps clipped (winsorize, sum)`);

  const desc = catalog.description || f.description || '';
  text.innerHTML =
    `<strong>Samples: ${catalog.label || pid}</strong>` +
    (desc ? ` — ${desc}` : '') +
    (criteriaBits.length
      ? `<br><span class="fp-criteria">Criteria: ${criteriaBits.join(' · ')}</span>`
      : '') +
    (statsBits.length
      ? `<br><span class="fp-criteria">This view: ${statsBits.join(' · ')}</span>`
      : '');
  el.hidden = false;
}

function discoverMetricKeys(groups) {
  const keys = new Set();
  for (const g of groups) {
    for (const k of Object.keys(g)) {
      if (GROUP_META_KEYS.has(k) || k === 'data_type_instance_count') continue;
      if (typeof g[k] === 'object' && g[k] !== null) continue; // skip filter blocks etc.
      keys.add(k);
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

function populateSelect(id, options, labelFn) {
  const sel = document.getElementById(id);
  if (!sel) return;
  const prev = sel.value;
  sel.innerHTML = '';
  options.forEach((o) => {
    const opt = document.createElement('option');
    opt.value = o;
    opt.textContent = typeof labelFn === 'function' ? labelFn(o) : o;
    sel.appendChild(opt);
  });
  if (options.includes(prev)) sel.value = prev;
}

/**
 * Test Data select with grouped synthetic data-type labels.
 * @param {string[]} options
 * @param {{ selectId?: string, previous?: string }} [cfg]
 */
function populateFixtureSelect(options, cfg = {}) {
  const selectId = cfg.selectId || 'data-select';
  const sel = document.getElementById(selectId);
  if (!sel) return;
  const prev = cfg.previous != null ? cfg.previous : sel.value || state.currentTestData;
  sel.innerHTML = '';

  const natural = options.filter((o) => parseFixtureSelection(o).kind === 'natural');
  const batchCompound = options.filter((o) => parseFixtureSelection(o).kind === 'batch_compound');
  const allTypes = options.filter((o) => parseFixtureSelection(o).kind === 'all_n');
  const allAll = options.filter((o) => parseFixtureSelection(o).kind === 'all_all');

  const addOpt = (o) => {
    const opt = document.createElement('option');
    opt.value = o;
    opt.textContent = fixtureOptionLabel(o);
    sel.appendChild(opt);
  };
  const addSep = (label) => {
    const sep = document.createElement('option');
    sep.disabled = true;
    sep.textContent = label;
    sel.appendChild(sep);
  };

  natural.forEach(addOpt);
  if (batchCompound.length) {
    addSep('── compounded batch ──');
    batchCompound.forEach(addOpt);
  }
  if (allTypes.length) {
    addSep('── compounded data types ──');
    allTypes.forEach(addOpt);
  }
  if (allAll.length) {
    addSep('── compounded all ──');
    allAll.forEach(addOpt);
  }

  if ([...sel.options].some((o) => o.value === prev)) {
    sel.value = prev;
  } else if (sel.options.length) {
    const first = [...sel.options].find((o) => !o.disabled && o.value);
    if (first) sel.value = first.value;
  }
}

/**
 * Docs Summary aggregation (reports._scientific_summary_md intent):
 * - Prefer bytes/string mode when present for a serializer (else keep all modes).
 * - Restrict to suite data-type base ids (message, document, …).
 * - One value per field: arithmetic mean across remaining groups;
 *   `runs` is summed; non-numeric: first non-empty (e.g. serializer_version).
 * - `total_median_ns` falls back to `avg_time_total_ns` when missing.
 */

/** Instance count from group (column or @n= suffix). */
function instanceCount(g) {
  let n = g?.data_type_instance_count;
  if (n != null && n !== '') {
    const num = Number(n);
    if (Number.isFinite(num) && num > 0) return num;
  }
  const m = String(g?.test_data ?? '').match(/@n=(\d+)/i);
  return m ? Number(m[1]) : null;
}

/**
 * Data-type selection kinds:
 * - natural: message@n=1
 * - batch_compound: message@n=1+100 (same type, two batch sizes)
 * - all_n: all@1 / all@100 (all suite types at fixed n)
 * - all_all: all@all (all suite types × all n)
 */
function parseFixtureSelection(key) {
  const s = String(key || '').trim();
  if (!s) return { kind: 'natural', key: s };
  if (s === 'all@all') return { kind: 'all_all', key: s };
  let m = s.match(/^all@n=(\d+)$/i) || s.match(/^all@(\d+)$/i);
  if (m) return { kind: 'all_n', key: s, n: Number(m[1]) };
  m = s.match(/^(.+)@n=(\d+)\+(\d+)$/i);
  if (m) {
    return {
      kind: 'batch_compound',
      key: s,
      base: m[1],
      nA: Number(m[2]),
      nB: Number(m[3]),
    };
  }
  return { kind: 'natural', key: s };
}

/** @deprecated use parseFixtureSelection; kept for call sites that only need batch compound */
function parseCompoundFixture(key) {
  const p = parseFixtureSelection(key);
  if (p.kind === 'batch_compound') return { base: p.base, nA: p.nA, nB: p.nB };
  return null;
}

function compoundFixtureKey(base, nA, nB) {
  const a = Math.min(nA, nB);
  const b = Math.max(nA, nB);
  return `${base}@n=${a}+${b}`;
}

function isSyntheticFixture(key) {
  const k = parseFixtureSelection(key).kind;
  return k === 'batch_compound' || k === 'all_n' || k === 'all_all';
}

function isCompoundFixture(key) {
  return isSyntheticFixture(key);
}

/**
 * Average numeric fields across a list of groups (same serializer).
 * runs: sum; total_median_ns falls back to avg_time_total_ns.
 */
function averageGroupsForSerializer(serializer, entries, meta) {
  const row = {
    serializer,
    test_data: meta.test_data,
    mode: meta.mode,
    language: entries[0]?.language || state.currentLanguage,
    compounded: !!meta.compounded,
    compound_parts: meta.compound_parts || null,
  };
  let version = '';
  for (const e of entries) {
    if (e.serializer_version) {
      version = String(e.serializer_version).trim();
      break;
    }
  }
  if (version) row.serializer_version = version;

  const streamModes = [
    ...new Set(
      entries
        .map((e) => e.StreamMode)
        .filter((v) => v != null && String(v).trim() !== '')
        .map((v) => String(v))
    ),
  ];
  if (streamModes.length === 1) row.StreamMode = streamModes[0];

  const numericKeys = new Set();
  for (const e of entries) {
    for (const [k, v] of Object.entries(e)) {
      if (GROUP_META_KEYS.has(k) || k === 'data_type_instance_count') continue;
      if (typeof v === 'number' && Number.isFinite(v)) numericKeys.add(k);
    }
  }
  for (const key of numericKeys) {
    const vals = [];
    for (const e of entries) {
      let v = e[key];
      if ((v === null || v === undefined) && key === 'total_median_ns') {
        v = e.avg_time_total_ns;
      }
      if (typeof v === 'number' && Number.isFinite(v)) vals.push(v);
    }
    if (!vals.length) continue;
    row[key] =
      key === 'runs' ||
      key === 'runs_raw' ||
      key === 'outliers_removed' ||
      key === 'values_clipped' ||
      key === 'warmup_skipped'
        ? vals.reduce((a, b) => a + b, 0)
        : vals.reduce((a, b) => a + b, 0) / vals.length;
  }
  if (row.avg_time_total_ns == null && row.total_median_ns != null) {
    row.avg_time_total_ns = row.total_median_ns;
  }
  if (row.avg_ops_per_sec == null && row.avg_time_total_ns > 0) {
    row.avg_ops_per_sec = 1e9 / row.avg_time_total_ns;
  }
  return row;
}

/**
 * Build compounded rows: for each serializer, mean of n=A and n=B groups
 * for the same base type + mode.
 */
function buildCompoundedFixtureGroups(allGroups, base, nA, nB, mode) {
  const want = new Set([nA, nB]);
  const matched = (allGroups || []).filter((g) => {
    if (baseTypeId(g.test_data) !== base) return false;
    if (normalizeMode(g.mode) !== normalizeMode(mode)) return false;
    const n = instanceCount(g);
    return n != null && want.has(n);
  });

  const bySer = new Map();
  for (const g of matched) {
    if (!bySer.has(g.serializer)) bySer.set(g.serializer, []);
    bySer.get(g.serializer).push(g);
  }

  const test_data = compoundFixtureKey(base, nA, nB);
  const out = [];
  for (const [serializer, entries] of bySer) {
    // Prefer serializers that have both batch sizes
    const ns = new Set(entries.map(instanceCount).filter((x) => x != null));
    if (!ns.has(nA) || !ns.has(nB)) continue;
    // One group per n (if duplicates, average those first)
    const perN = new Map();
    for (const e of entries) {
      const n = instanceCount(e);
      if (!perN.has(n)) perN.set(n, []);
      perN.get(n).push(e);
    }
    const parts = [];
    for (const n of [nA, nB]) {
      const list = perN.get(n) || [];
      if (list.length === 1) parts.push(list[0]);
      else if (list.length > 1) {
        parts.push(
          averageGroupsForSerializer(serializer, list, {
            test_data: `${base}@n=${n}`,
            mode,
            compounded: false,
          })
        );
      }
    }
    if (parts.length < 2) continue;
    out.push(
      averageGroupsForSerializer(serializer, parts, {
        test_data,
        mode,
        compounded: true,
        compound_parts: `${base}@n=${nA} + ${base}@n=${nB}`,
      })
    );
  }
  return out.sort((a, b) => a.serializer.localeCompare(b.serializer));
}

/**
 * all@1 / all@100: mean across all suite data types at a fixed instance count.
 * One contribution per base type (if multiple rows, pre-averaged).
 */
function buildAllTypesAtNGroups(allGroups, n, mode) {
  const matched = (allGroups || []).filter((g) => {
    if (!SUITE_TYPE_IDS.includes(baseTypeId(g.test_data))) return false;
    if (normalizeMode(g.mode) !== normalizeMode(mode)) return false;
    return instanceCount(g) === n;
  });

  const bySer = new Map();
  for (const g of matched) {
    if (!bySer.has(g.serializer)) bySer.set(g.serializer, []);
    bySer.get(g.serializer).push(g);
  }

  const test_data = `all@${n}`;
  const out = [];
  for (const [serializer, entries] of bySer) {
    // One value per base type, then mean across types
    const byBase = new Map();
    for (const e of entries) {
      const base = baseTypeId(e.test_data);
      if (!byBase.has(base)) byBase.set(base, []);
      byBase.get(base).push(e);
    }
    const parts = [];
    const bases = [];
    for (const base of SUITE_TYPE_IDS) {
      const list = byBase.get(base);
      if (!list || !list.length) continue;
      bases.push(`${base}@n=${n}`);
      if (list.length === 1) parts.push(list[0]);
      else {
        parts.push(
          averageGroupsForSerializer(serializer, list, {
            test_data: `${base}@n=${n}`,
            mode,
            compounded: false,
          })
        );
      }
    }
    if (parts.length < 1) continue;
    out.push(
      averageGroupsForSerializer(serializer, parts, {
        test_data,
        mode,
        compounded: true,
        compound_parts: bases.join(' + '),
      })
    );
  }
  return out.sort((a, b) => a.serializer.localeCompare(b.serializer));
}

/**
 * all@all: mean across all suite types and all batch sizes (current mode).
 * Collapse to one row per (base, n) then average those cells.
 */
function buildAllAllGroups(allGroups, mode) {
  const matched = (allGroups || []).filter((g) => {
    if (!SUITE_TYPE_IDS.includes(baseTypeId(g.test_data))) return false;
    return normalizeMode(g.mode) === normalizeMode(mode);
  });

  const bySer = new Map();
  for (const g of matched) {
    if (!bySer.has(g.serializer)) bySer.set(g.serializer, []);
    bySer.get(g.serializer).push(g);
  }

  const out = [];
  for (const [serializer, entries] of bySer) {
    const byCell = new Map(); // base@n -> groups
    for (const e of entries) {
      const n = instanceCount(e);
      const base = baseTypeId(e.test_data);
      if (n == null) continue;
      const cell = `${base}@n=${n}`;
      if (!byCell.has(cell)) byCell.set(cell, []);
      byCell.get(cell).push(e);
    }
    const parts = [];
    const cells = [...byCell.keys()].sort();
    for (const cell of cells) {
      const list = byCell.get(cell);
      if (list.length === 1) parts.push(list[0]);
      else {
        parts.push(
          averageGroupsForSerializer(serializer, list, {
            test_data: cell,
            mode,
            compounded: false,
          })
        );
      }
    }
    if (parts.length < 1) continue;
    out.push(
      averageGroupsForSerializer(serializer, parts, {
        test_data: 'all@all',
        mode,
        compounded: true,
        compound_parts: cells.join(' + '),
      })
    );
  }
  return out.sort((a, b) => a.serializer.localeCompare(b.serializer));
}

/** Natural + synthetic data-type keys for the Test Data dropdown. */
function discoverFixtureOptions(allGroups) {
  const natural = [
    ...new Set(
      (allGroups || [])
        .map((g) => g.test_data)
        .filter((k) => k && SUITE_TYPE_IDS.includes(baseTypeId(k)))
    ),
  ].sort();

  const byBase = new Map();
  const nsGlobal = new Set();
  for (const g of allGroups || []) {
    const base = baseTypeId(g.test_data);
    if (!SUITE_TYPE_IDS.includes(base)) continue;
    const n = instanceCount(g);
    if (n == null) continue;
    if (!byBase.has(base)) byBase.set(base, new Set());
    byBase.get(base).add(n);
    nsGlobal.add(n);
  }

  // Per-type batch compounds: message@n=1+100, …
  const batchCompound = [];
  for (const [base, ns] of byBase) {
    if (ns.has(1) && ns.has(100)) {
      batchCompound.push(compoundFixtureKey(base, 1, 100));
    }
  }
  batchCompound.sort();

  // Cross-type at fixed n
  const allTypes = [];
  if (nsGlobal.has(1)) allTypes.push('all@1');
  if (nsGlobal.has(100)) allTypes.push('all@100');

  // Everything
  const allAll = natural.length ? ['all@all'] : [];

  return {
    natural,
    batchCompound,
    allTypes,
    allAll,
    all: [...natural, ...batchCompound, ...allTypes, ...allAll],
  };
}

function fixtureOptionLabel(key) {
  const p = parseFixtureSelection(key);
  if (p.kind === 'batch_compound') {
    return `${p.base}@n=${p.nA}+${p.nB} (compounded batch)`;
  }
  if (p.kind === 'all_n') {
    return `all@${p.n} (all data types, n=${p.n})`;
  }
  if (p.kind === 'all_all') {
    return 'all@all (all types × all n)';
  }
  return key;
}

function resolveFixtureGroups() {
  const sel = parseFixtureSelection(state.currentTestData);
  const mode = state.currentMode;
  if (sel.kind === 'batch_compound') {
    return buildCompoundedFixtureGroups(
      state.allGroups,
      sel.base,
      sel.nA,
      sel.nB,
      mode
    );
  }
  if (sel.kind === 'all_n') {
    return buildAllTypesAtNGroups(state.allGroups, sel.n, mode);
  }
  if (sel.kind === 'all_all') {
    return buildAllAllGroups(state.allGroups, mode);
  }
  return state.allGroups.filter(
    (g) =>
      g.test_data === state.currentTestData &&
      normalizeMode(g.mode) === normalizeMode(mode)
  );
}

function filterAndRefresh() {
  state.filteredGroups = resolveFixtureGroups();

  state.serializerNames = [
    ...new Set(state.filteredGroups.map((g) => g.serializer)),
  ].sort((a, b) => a.localeCompare(b));

  calculateParetoFrontier();

  // Baseline default
  if (!state.compareBaseline || !state.serializerNames.includes(state.compareBaseline)) {
    state.compareBaseline =
      state.paretoSerializerNames[0] || state.serializerNames[0] || '';
  }

  // Detail serializers default: baseline + a few others (capped)
  state.detailSerializers = state.detailSerializers.filter((s) =>
    state.serializerNames.includes(s)
  );
  if (!state.detailSerializers.length) {
    const seed = state.paretoSerializerNames.length
      ? state.paretoSerializerNames
      : state.serializerNames;
    state.detailSerializers = seed.slice(0, Math.min(6, seed.length));
  }
  if (state.compareBaseline && !state.detailSerializers.includes(state.compareBaseline)) {
    state.detailSerializers = [state.compareBaseline, ...state.detailSerializers].slice(
      0,
      MAX_COMPARE_COLUMNS
    );
  }

  updateKPIs();
  updateFilterPolicyMeta();
  updateStreamHonestyChip();
  populateBaselineSelect();
  populateSameSerAddSelect();
  renderSameSelectionChips();
  renderMetricsChecklist();
  renderTable();
  renderCompareMatrix();
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
  updateSortIndicators();
  updateCompareStatusLine();
  saveSettings();
}

function setViewMetric(metric) {
  state.displayMetric = metric;
  document.getElementById('btn-ops-sec')?.classList.toggle('active', metric === 'ops');
  document.getElementById('btn-time-ns')?.classList.toggle('active', metric === 'time');
  updateRankSortPrimaryLabel();
  saveSettings();
  updateCharts(state.filteredGroups, state.paretoSerializerNames, state.displayMetric);
}

function setRosterMetric(metric) {
  state.rosterMetric = metric === 'time' ? 'time' : 'ops';
  document.getElementById('btn-roster-ops')?.classList.toggle('active', state.rosterMetric === 'ops');
  document.getElementById('btn-roster-latency')?.classList.toggle('active', state.rosterMetric === 'time');
  // Reset sort to primary column of the active view
  const opsKeys = new Set(['ops_median', 'ops_std', 'ops_p95', 'ops_p99']);
  const latKeys = new Set(['total_median_ns', 'total_std_ns', 'total_p95_ns', 'total_p99_ns']);
  if (state.rosterMetric === 'ops' && latKeys.has(state.sortKey)) {
    state.sortKey = 'ops_median';
    state.sortDirection = 'desc';
  } else if (state.rosterMetric === 'time' && opsKeys.has(state.sortKey)) {
    state.sortKey = 'total_median_ns';
    state.sortDirection = 'asc';
  }
  saveSettings();
  renderTable();
}

/**
 * Ops stats derived from trial latencies when direct ops percentiles are absent.
 * (ops ≈ 1e9 / total_ns; percentile of ops inverts latency percentiles.)
 */
function invNsToOps(ns) {
  if (typeof ns !== 'number' || !Number.isFinite(ns) || ns <= 0) return null;
  return 1e9 / ns;
}

/** Attach ops_median / ops_std / ops_p95 / ops_p99 for roster display & sort. */
function withOpsDerivedStats(g) {
  if (!g) return g;
  const medianNs = g.total_median_ns ?? g.total_p50_ns ?? g.avg_time_total_ns;
  const meanNs = g.total_mean_ns ?? g.avg_time_total_ns;
  const stdNs = g.total_std_ns;
  // High throughput percentiles ↔ low latency percentiles
  const p95Ops = invNsToOps(g.total_p5_ns);
  const p99Ops = invNsToOps(g.total_min_ns ?? g.total_p5_ns);
  let opsStd = null;
  if (
    typeof meanNs === 'number' &&
    meanNs > 0 &&
    typeof stdNs === 'number' &&
    Number.isFinite(stdNs)
  ) {
    // Delta method: sd(1e9/T) ≈ 1e9 * sd(T) / E[T]^2
    opsStd = (1e9 * stdNs) / (meanNs * meanNs);
  }
  return {
    ...g,
    ops_median: invNsToOps(medianNs) ?? g.avg_ops_per_sec ?? null,
    ops_std: opsStd,
    ops_p95: p95Ops ?? g.max_ops_per_sec ?? null,
    ops_p99: p99Ops ?? g.max_ops_per_sec ?? null,
  };
}

/** Roster columns for Detailed Analytics (local Ops/s | Latency switch). */
function rosterMetricKeys() {
  if (state.rosterMetric === 'time') {
    return [
      { key: 'total_median_ns', higherIsBetter: false, label: 'Median' },
      { key: 'total_std_ns', higherIsBetter: false, label: 'Std' },
      { key: 'total_p95_ns', higherIsBetter: false, label: 'P95' },
      { key: 'total_p99_ns', higherIsBetter: false, label: 'P99' },
      { key: 'median_size_bytes', higherIsBetter: false, label: 'Median size' },
    ];
  }
  return [
    { key: 'ops_median', higherIsBetter: true, label: 'Median' },
    { key: 'ops_std', higherIsBetter: false, label: 'Std' },
    { key: 'ops_p95', higherIsBetter: true, label: 'P95' },
    { key: 'ops_p99', higherIsBetter: true, label: 'P99' },
    { key: 'median_size_bytes', higherIsBetter: false, label: 'Median size' },
  ];
}

function formatRosterCell(key, value, scales) {
  if (value === null || value === undefined) return '—';
  if (key.startsWith('ops_') || key === 'avg_ops_per_sec') {
    return formatOpsCell(value, scales.ops);
  }
  return formatMetricCell(key, value, scales);
}

/**
 * Detailed Analytics cell policy:
 * - Median (ops/latency) & size → absolute + ×base (vs baseline same column)
 * - Std / P95 / P99 → absolute + ×med (vs that row’s own median)
 */
function formatRosterRelativeCell(row, key, higherIsBetter, scales, baselineGroup, isBaseline) {
  const v = row[key];
  const ownMedian =
    key.startsWith('ops_')
      ? row.ops_median
      : key.startsWith('total_')
        ? row.total_median_ns ?? row.total_p50_ns
        : null;

  // Shape stats: ratio to own median
  const vsOwnMed =
    key === 'ops_std' ||
    key === 'ops_p95' ||
    key === 'ops_p99' ||
    key === 'total_std_ns' ||
    key === 'total_p95_ns' ||
    key === 'total_p99_ns';

  if (vsOwnMed) {
    // ×med is distribution shape (tail/spread vs typical), not better/worse vs baseline.
    // Never green/red these: P95/P99 are almost always > median, so coloring was nonsense.
    if (
      ownMedian == null ||
      typeof ownMedian !== 'number' ||
      !Number.isFinite(ownMedian) ||
      ownMedian === 0
    ) {
      return {
        text: formatRosterCell(key, v, scales),
        className: 'num' + (isBaseline ? ' baseline-col' : ''),
      };
    }
    const rel = formatRelativeCell(v, ownMedian, null, scales, key, 'med');
    return {
      text: rel.text,
      className: 'num rel-neutral' + (isBaseline ? ' baseline-col' : ''),
    };
  }

  // Median & size only: vs baseline (green = better, red = worse)
  if (isBaseline || !baselineGroup) {
    return {
      text: formatRosterCell(key, v, scales),
      className: 'num' + (isBaseline ? ' baseline-col' : ''),
    };
  }
  const baseVal = baselineGroup[key];
  if (baseVal == null || typeof baseVal !== 'number' || !Number.isFinite(baseVal)) {
    return { text: formatRosterCell(key, v, scales), className: 'num' };
  }
  // Equal within ~1%: treat as neutral (avoid noisy green/red on ties)
  const ratio = v / baseVal;
  if (Math.abs(ratio - 1) < 0.01) {
    return {
      text: formatRelativeCell(v, baseVal, null, scales, key, 'base').text,
      className: 'num rel-neutral',
    };
  }
  return formatRelativeCell(v, baseVal, higherIsBetter, scales, key, 'base');
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

/** Canonical StreamMode on a group; empty/unknown → "". */
function normalizeStreamMode(value) {
  let s = String(value || '')
    .trim()
    .toLowerCase()
    .replace(/[-\s]/g, '_');
  if (s === 'text' || s === 'text_writer' || s === 'textonstream') s = 'text_on_stream';
  if (s === 'native' || s === 'text_on_stream' || s === 'adapted') return s;
  return s;
}

function honestyDisplayLabel(streamMode) {
  const sm = normalizeStreamMode(streamMode);
  if (sm === 'native') return 'native';
  if (sm === 'text_on_stream') return 'text';
  if (sm === 'adapted') return 'adapted';
  return '—';
}

/** Count StreamMode on stream I/O rows only (language-level, allGroups). */
function summarizeStreamHonesty(groups) {
  const counts = { native: 0, text_on_stream: 0, adapted: 0, unlabeled: 0 };
  let streamRows = 0;
  for (const g of groups || []) {
    if (normalizeMode(g.mode) !== 'stream') continue;
    streamRows += 1;
    const sm = normalizeStreamMode(g.StreamMode);
    if (sm === 'native') counts.native += 1;
    else if (sm === 'text_on_stream') counts.text_on_stream += 1;
    else if (sm === 'adapted') counts.adapted += 1;
    else counts.unlabeled += 1;
  }
  return { streamRows, counts };
}

function updateStreamHonestyChip() {
  const chip = document.getElementById('stream-honesty-chip');
  if (!chip) return;
  const { streamRows, counts } = summarizeStreamHonesty(state.allGroups);
  if (streamRows <= 0) {
    chip.hidden = true;
    chip.textContent = '';
    chip.removeAttribute('title');
    return;
  }
  const { native, text_on_stream, adapted, unlabeled } = counts;
  const allAdapted = adapted === streamRows && unlabeled === 0;
  const allUnlabeled = unlabeled === streamRows;
  let text;
  if (allUnlabeled) {
    text = 'stream rows unlabeled — treat as adapted';
  } else if (allAdapted) {
    text = 'stream: all adapted — not incremental I/O';
  } else {
    const parts = [];
    if (native) parts.push(`${native} native`);
    if (text_on_stream) parts.push(`${text_on_stream} text`);
    if (adapted) parts.push(`${adapted} adapted`);
    if (unlabeled) parts.push(`${unlabeled} unlabeled`);
    text = `stream: ${parts.join(' · ')}`;
  }
  chip.textContent = text;
  chip.title = text;
  chip.hidden = false;
}

/**
 * Load multi-policy groups for one language (cross-lang compare).
 * @returns {Promise<Record<string, object[]>>} policy → groups
 */
async function fetchStatsGroupsByPolicy(langId) {
  const urls = [
    `data/stats_${langId}_latest.json.gz`,
    `data/stats_${langId}_latest.json`,
    `data/${langId}_latest.json.gz`,
  ];
  for (const url of urls) {
    try {
      const payload = await fetchJsonMaybeGzip(url);
      if (!payload) continue;
      // standalone stats file vs language pack with embedded .stats
      const statsObj =
        payload.groups || payload.groups_by_policy || payload.default_filter_policy
          ? payload
          : payload.stats || payload;
      const { groupsByPolicy, defaultPolicy } = normalizeStatsPayload(statsObj);
      if (!Object.keys(groupsByPolicy).length) continue;
      const stamped = {};
      for (const [pid, list] of Object.entries(groupsByPolicy)) {
        stamped[pid] = list.map((g) => ({
          ...g,
          language: g.language || langId,
          test_data: fixtureKey(g),
        }));
      }
      if (!stamped[defaultPolicy] && Array.isArray(statsObj.groups) && !statsObj.groups[0]?.variants) {
        stamped[defaultPolicy] = (statsObj.groups || []).map((g) => ({
          ...g,
          language: g.language || langId,
          test_data: fixtureKey(g),
        }));
      }
      return stamped;
    } catch (e) {
      console.warn(`Cross-lang load failed for ${langId} via ${url}:`, e);
    }
  }
  return {};
}

function rebuildCrossLangForPolicy() {
  const pid = state.filterPolicy;
  const byLang = {};
  for (const [lang, byPolicy] of Object.entries(state.crossLangGroupsByLangPolicy || {})) {
    byLang[lang] =
      byPolicy[pid] ||
      byPolicy[state.defaultFilterPolicy] ||
      byPolicy[DEFAULT_FILTER_POLICY] ||
      byPolicy[Object.keys(byPolicy)[0]] ||
      [];
  }
  state.crossLangGroupsByLang = byLang;
  if (state.xlSelectionMode === 'pareto') {
    applyCrossLangParetoSelection();
  } else {
    pruneCrossLangSelection();
  }
  updateXlBaselineSelect();
}

async function ensureCrossLangLoaded() {
  if (state.crossLangLoaded) {
    rebuildCrossLangForPolicy();
    initCrossLangControls();
    return;
  }
  showNotification('Loading cross-language stats…', 'info');
  const entries = await Promise.all(
    LANGUAGE_CATALOG.map(async (lang) => [lang.id, await fetchStatsGroupsByPolicy(lang.id)])
  );
  state.crossLangGroupsByLangPolicy = Object.fromEntries(entries);
  state.crossLangLoaded = true;
  rebuildCrossLangForPolicy();
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
  const discovered = discoverFixtureOptions(all);
  const dataTypes = discovered.all;
  const modes = [...new Set(all.map((g) => normalizeMode(g.mode)).filter(Boolean))].sort();

  // Same grouped options as top toolbar Test Data (natural + compounds)
  populateFixtureSelect(dataTypes, {
    selectId: 'xl-data-select',
    previous: state.xlTestData,
  });

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

  if (!dataTypes.includes(state.xlTestData)) {
    state.xlTestData =
      pickPreferredFixture(discovered.natural) || dataTypes[0] || '';
  }
  if (!modes.includes(state.xlMode)) {
    state.xlMode = modes.includes('bytes') ? 'bytes' : modes[0] || '';
  }
  const xd = document.getElementById('xl-data-select');
  const xm = document.getElementById('xl-mode-select');
  if (xd && [...xd.options].some((o) => o.value === state.xlTestData)) {
    xd.value = state.xlTestData;
  } else if (xd && xd.options.length) {
    const first = [...xd.options].find((o) => !o.disabled && o.value);
    if (first) {
      xd.value = first.value;
      state.xlTestData = first.value;
    }
  }
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

/**
 * Resolve groups for one language under XL Test Data + Mode
 * (supports natural, batch compound, all@1/all@100, all@all).
 */
function filterGroupsForCrossLang(groups) {
  const modeNorm = state.xlMode;
  const modeGroups = (groups || []).filter(
    (g) => normalizeMode(g.mode) === modeNorm
  );
  // Normalize mode field so builders can match with exact equality
  const normalized = modeGroups.map((g) => ({ ...g, mode: modeNorm }));

  const sel = parseFixtureSelection(state.xlTestData);
  if (sel.kind === 'batch_compound') {
    return buildCompoundedFixtureGroups(
      normalized,
      sel.base,
      sel.nA,
      sel.nB,
      modeNorm
    );
  }
  if (sel.kind === 'all_n') {
    return buildAllTypesAtNGroups(normalized, sel.n, modeNorm);
  }
  if (sel.kind === 'all_all') {
    return buildAllAllGroups(normalized, modeNorm);
  }
  return normalized.filter((g) => g.test_data === state.xlTestData);
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
  // Prefer diversity but keep table readable
  state.xlSelected = selected.slice(0, MAX_COMPARE_COLUMNS);
  state.xlSelectionMode = 'pareto';
  if (state.xlSelected.length) {
    const keys = new Set(state.xlSelected.map((x) => `${x.lang}|${x.serializer}`));
    if (!keys.has(state.xlBaselineKey)) {
      state.xlBaselineKey = `${state.xlSelected[0].lang}|${state.xlSelected[0].serializer}`;
    }
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
  const selected = new Set(
    state.xlSelected.filter((x) => x.lang === lang).map((x) => x.serializer)
  );
  serSel.innerHTML = '';
  names
    .filter((n) => !selected.has(n))
    .forEach((n) => {
      const g = groups.find((x) => x.serializer === n);
      const opt = document.createElement('option');
      opt.value = n;
      opt.textContent = g ? serializerLabelFromGroup(g) : n;
      serSel.appendChild(opt);
    });
}

/**
 * Build a chip element: neutral pill, optional baseline highlight, truncated label.
 */
function makeChip({ fullLabel, shortLabel, title, isBaseline, onRemove }) {
  const chip = document.createElement('span');
  chip.className = 'xl-chip' + (isBaseline ? ' chip-baseline' : '');
  chip.title = title || fullLabel;

  const label = document.createElement('span');
  label.className = 'xl-chip-label';
  // Prefer compact shortLabel (no version in chip; full string in title)
  if (shortLabel) {
    label.textContent = shortLabel + (isBaseline ? ' · base' : '');
  } else {
    const colon = fullLabel.lastIndexOf(':');
    if (colon > 0 && colon < fullLabel.length - 1 && !fullLabel.includes(' / ')) {
      label.textContent = fullLabel.slice(0, colon) + (isBaseline ? ' · base' : '');
    } else {
      label.textContent = fullLabel + (isBaseline ? ' · base' : '');
    }
  }
  chip.appendChild(label);

  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'xl-chip-remove';
  btn.textContent = '×';
  btn.setAttribute('aria-label', `Remove ${fullLabel}`);
  btn.addEventListener('click', onRemove);
  chip.appendChild(btn);
  return chip;
}

/**
 * Flat chip stream (single dense line with horizontal scroll in compact UI).
 * groups: { langLabel?, chips: HTMLElement[] }[]
 */
function renderChipGroups(host, groups) {
  host.innerHTML = '';
  host.className = 'chip-groups chip-groups-compact';
  if (!groups.length) {
    const empty = document.createElement('span');
    empty.className = 'chip-empty';
    empty.textContent = 'None selected';
    host.appendChild(empty);
    return;
  }
  // Flatten: one continuous flex row of chips (lang prefix already on chip label when needed)
  groups.forEach((g) => {
    g.chips.forEach((c) => host.appendChild(c));
  });
}

function renderCrossLangSelection() {
  const host = document.getElementById('xl-selection-chips');
  if (!host) return;
  if (!state.xlSelected.length) {
    renderChipGroups(host, []);
    updateCompareStatusLine();
    return;
  }

  // Group by language, preserve LANGUAGE_CATALOG order
  const byLang = new Map();
  state.xlSelected.forEach((x) => {
    if (!byLang.has(x.lang)) byLang.set(x.lang, []);
    byLang.get(x.lang).push(x);
  });

  const groups = [];
  const orderedLangs = [
    ...LANGUAGE_CATALOG.map((l) => l.id).filter((id) => byLang.has(id)),
    ...[...byLang.keys()].filter((id) => !LANGUAGE_CATALOG.some((l) => l.id === id)),
  ];

  orderedLangs.forEach((langId) => {
    const items = byLang.get(langId) || [];
    const langShort = languageLabel(langId);
    const chips = items.map((x) => {
      const g = findCrossLangGroup(x.lang, x.serializer);
      const serLabel = g ? serializerLabelFromGroup(g) : x.serializer;
      const key = `${x.lang}|${x.serializer}`;
      // Compact: "C#: BinaryPack" on one chip (no separate language rows)
      return makeChip({
        fullLabel: serLabel,
        shortLabel: `${langShort}: ${serLabel.split(':')[0]}`,
        title: `${langShort} / ${serLabel}`,
        isBaseline: key === state.xlBaselineKey,
        onRemove: () => {
          state.xlSelectionMode = 'custom';
          state.xlSelected = state.xlSelected.filter(
            (y) => !(y.lang === x.lang && y.serializer === x.serializer)
          );
          renderCrossLangSelection();
          updateXlBaselineSelect();
          refreshCrossLangAddSerializerOptions();
          renderCompareMatrix();
          saveSettings();
          updateCompareStatusLine();
        },
      });
    });
    groups.push({ langLabel: langShort, chips });
  });

  renderChipGroups(host, groups);
  updateCompareStatusLine();
}

function populateSameSerAddSelect() {
  const sel = document.getElementById('same-ser-add-select');
  if (!sel) return;
  const q = (document.getElementById('same-ser-search')?.value || '').toLowerCase().trim();
  const selected = new Set(state.detailSerializers);
  const candidates = state.serializerNames.filter((n) => !selected.has(n));
  const filtered = candidates.filter((n) => {
    if (!q) return true;
    const g = groupForSerializer(n);
    const label = (g ? serializerLabelFromGroup(g) : n).toLowerCase();
    return n.toLowerCase().includes(q) || label.includes(q);
  });
  sel.innerHTML = '';
  if (!filtered.length) {
    const opt = document.createElement('option');
    opt.value = '';
    opt.textContent = q ? 'No matches' : 'All selected';
    sel.appendChild(opt);
    return;
  }
  filtered.forEach((n) => {
    const g = groupForSerializer(n);
    const opt = document.createElement('option');
    opt.value = n;
    opt.textContent = g ? serializerLabelFromGroup(g) : n;
    sel.appendChild(opt);
  });
}

function addSameLanguageSerializer(name) {
  if (!name || !state.serializerNames.includes(name)) return;
  if (state.detailSerializers.includes(name)) {
    showNotification('Already selected.', 'info');
    return;
  }
  if (state.detailSerializers.length >= MAX_COMPARE_COLUMNS) {
    showNotification(`At most ${MAX_COMPARE_COLUMNS} serializers in Compare.`, 'info');
    return;
  }
  state.detailSerializers = [...state.detailSerializers, name];
  saveSettings();
  renderSameSelectionChips();
  populateSameSerAddSelect();
  renderCompareMatrix();
  updateCompareStatusLine();
}

function renderSameSelectionChips() {
  const host = document.getElementById('same-selection-chips');
  if (!host) return;
  const names = state.detailSerializers.filter((s) => state.serializerNames.includes(s));
  if (!names.length) {
    renderChipGroups(host, []);
    updateCompareStatusLine();
    return;
  }
  const chips = names.map((name) => {
    const g = groupForSerializer(name);
    const full = g ? serializerLabelFromGroup(g) : name;
    return makeChip({
      fullLabel: full,
      shortLabel: full.split(':')[0],
      title: full,
      isBaseline: name === state.compareBaseline,
      onRemove: () => {
        state.detailSerializers = state.detailSerializers.filter((s) => s !== name);
        if (
          state.compareBaseline === name ||
          !state.detailSerializers.includes(state.compareBaseline)
        ) {
          state.compareBaseline = state.detailSerializers[0] || '';
          populateBaselineSelect();
        }
        saveSettings();
        renderSameSelectionChips();
        populateSameSerAddSelect();
        renderCompareMatrix();
        updateCompareStatusLine();
      },
    });
  });
  renderChipGroups(host, [{ chips }]);
  updateCompareStatusLine();
}

function updateXlBaselineSelect() {
  const sel = document.getElementById('compare-xl-baseline-select');
  if (!sel) return;
  sel.innerHTML = '';
  state.xlSelected.forEach((x) => {
    const opt = document.createElement('option');
    opt.value = `${x.lang}|${x.serializer}`;
    const g = findCrossLangGroup(x.lang, x.serializer);
    const serLabel = g ? serializerLabelFromGroup(g) : x.serializer;
    opt.textContent = `${languageLabel(x.lang)} / ${serLabel}`;
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
  document.getElementById('kpi-fastest-val').textContent = 'Select another data type or mode';
  document.getElementById('kpi-compact').textContent = msg || 'No data for this filter';
  document.getElementById('kpi-compact-val').textContent = 'Select another data type or mode';
  document.getElementById('kpi-pareto').textContent = '—';
}

function setChartEmptyVisible(empty) {
  ['scatter-empty', 'bar-empty'].forEach((id) => {
    const node = document.getElementById(id);
    if (node) node.hidden = !empty;
  });
}

function updateKPIs() {
  const total = state.filteredGroups.length;
  document.getElementById('kpi-total').textContent = formatIntGrouped(total);
  setChartEmptyVisible(total === 0);

  if (total === 0) {
    setKpiEmpty('No data for this filter');
    return;
  }

  const latencyKey = (g) =>
    g.total_median_ns != null && Number.isFinite(g.total_median_ns)
      ? g.total_median_ns
      : g.avg_time_total_ns;

  const fastest = [...state.filteredGroups]
    .filter((g) => latencyKey(g) != null && Number.isFinite(latencyKey(g)))
    .sort((a, b) => latencyKey(a) - latencyKey(b))[0];
  if (fastest) {
    document.getElementById('kpi-fastest').textContent = fastest.serializer;
    const lat = latencyKey(fastest);
    const suffix = fastest.compounded ? ` · ${state.currentTestData}` : '';
    document.getElementById('kpi-fastest-val').textContent =
      `${formatTimeCompact(lat)} · ${formatOpsCompact(fastest.avg_ops_per_sec)}${suffix}`;
  }

  const compact = [...state.filteredGroups]
    .filter((g) => g.median_size_bytes != null)
    .sort((a, b) => a.median_size_bytes - b.median_size_bytes)[0];
  if (compact) {
    document.getElementById('kpi-compact').textContent = compact.serializer;
    const suffix = compact.compounded ? ` · ${state.currentTestData}` : '';
    document.getElementById('kpi-compact-val').textContent =
      `${formatIntGrouped(compact.median_size_bytes)} bytes${suffix}`;
  }

  document.getElementById('kpi-pareto').textContent =
    `${state.paretoSerializerNames.length} / ${total}`;
  const paretoDesc = document.querySelector('#kpi-pareto')?.closest('.kpi-card')?.querySelector('.kpi-desc');
  if (paretoDesc) {
    const pl =
      state.filterPolicies[state.filterPolicy]?.label || state.filterPolicy || 'default';
    paretoDesc.textContent = `Optimal trade-offs · samples: ${pl}`;
  }
}

function groupForSerializer(name) {
  return state.filteredGroups.find((g) => g.serializer === name) || null;
}

function populateBaselineSelect() {
  const sels = [
    document.getElementById('compare-baseline-select'),
    document.getElementById('roster-baseline-select'),
  ].filter(Boolean);
  if (!sels.length) return;

  if (state.compareBaseline && state.serializerNames.includes(state.compareBaseline)) {
    // keep
  } else if (state.serializerNames.length) {
    state.compareBaseline =
      state.paretoSerializerNames[0] || state.serializerNames[0] || '';
  }

  sels.forEach((sel) => {
    sel.innerHTML = '';
    state.serializerNames.forEach((name) => {
      const opt = document.createElement('option');
      opt.value = name;
      const g = groupForSerializer(name);
      const label = g ? serializerLabelFromGroup(g) : name;
      opt.textContent = label + (state.paretoSerializerNames.includes(name) ? ' ★' : '');
      sel.appendChild(opt);
    });
    if (state.compareBaseline && state.serializerNames.includes(state.compareBaseline)) {
      sel.value = state.compareBaseline;
    }
  });
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

function openMetricsPanel(open) {
  const body = document.getElementById('metrics-panel-body');
  const toggle = document.getElementById('metrics-edit-toggle');
  if (body) body.hidden = !open;
  if (toggle) toggle.textContent = open ? 'Custom ▴' : 'Custom ▾';
}

function setMetricsPresetActive(preset) {
  document.querySelectorAll('.preset-btn').forEach((btn) => {
    btn.classList.toggle('active', btn.dataset.preset === preset);
  });
}

function applyMetricPreset(preset) {
  const keys = METRIC_PRESETS[preset] || METRIC_PRESETS.defaults;
  state.selectedMetrics = keys.filter((k) => state.availableMetrics.includes(k));
  if (!state.selectedMetrics.length && preset === 'defaults') {
    state.selectedMetrics = state.availableMetrics.slice(0, 12);
  }
  setMetricsPresetActive(preset);
  // Latency/size presets leave catalog closed; custom opens it
  openMetricsPanel(false);
  saveSettings();
  renderMetricsChecklist();
  renderCompareMatrix();
  updateCompareStatusLine();
}

/** @deprecated checklist replaced by chips; kept as no-op alias */
function renderDetailSerializerChecklist() {
  renderSameSelectionChips();
  populateSameSerAddSelect();
}

function renderMetricsChecklist() {
  const container = document.getElementById('metrics-checklist');
  if (!container) return;
  container.innerHTML = '';
  const groups = groupMetrics(state.availableMetrics);
  groups.forEach((group) => {
    const selectedInGroup = group.keys.filter((k) => state.selectedMetrics.includes(k)).length;
    const wrap = document.createElement('div');
    wrap.className = 'metric-accordion-group';
    if (metricAccordionOpen[group.name]) wrap.classList.add('open');

    const head = document.createElement('button');
    head.type = 'button';
    head.className = 'metric-accordion-head';
    head.innerHTML =
      `<span><span class="acc-chevron">▸</span>${escapeHtml(group.name)}</span>` +
      `<span class="acc-count">${selectedInGroup}/${group.keys.length}</span>`;
    head.addEventListener('click', () => {
      metricAccordionOpen[group.name] = !metricAccordionOpen[group.name];
      wrap.classList.toggle('open', !!metricAccordionOpen[group.name]);
    });
    wrap.appendChild(head);

    const body = document.createElement('div');
    body.className = 'metric-accordion-body';
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
        setMetricsPresetActive('custom');
        saveSettings();
        // refresh counts on heads without full re-render of open state
        renderMetricsChecklist();
        renderCompareMatrix();
        updateCompareStatusLine();
      });
      label.appendChild(cb);
      label.appendChild(document.createTextNode(` ${metricLabel(key)}`));
      label.title = key;
      body.appendChild(label);
    });
    wrap.appendChild(body);
    container.appendChild(wrap);
  });
  updateCompareStatusLine();
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
  const table = document.getElementById('analytics-table');
  const tbody = document.getElementById('table-body');
  if (!tbody) return;
  tbody.innerHTML = '';

  const isOps = state.rosterMetric === 'ops';
  const showHonesty = normalizeMode(state.currentMode) === 'stream';
  if (table) {
    table.classList.toggle('view-ops', isOps);
    table.classList.toggle('view-latency', !isOps);
    table.classList.toggle('view-stream', showHonesty);
  }

  // Enrich with derived ops stats for sort + cells
  let rows = state.filteredGroups
    .filter((g) => (g.serializer || '').toLowerCase().includes(state.searchQuery))
    .map(withOpsDerivedStats);

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

  const metricKeys = rosterMetricKeys();
  // Scales: ops_* use ops scale; total_* use latency scale
  const latVals = [];
  const opsVals = [];
  for (const g of rows) {
    for (const { key } of metricKeys) {
      const v = g[key];
      if (typeof v !== 'number' || !Number.isFinite(v)) continue;
      if (key.startsWith('ops_')) opsVals.push(v);
      else if (key.endsWith('_ns')) latVals.push(v);
    }
  }
  const scales = {
    latency: latVals.length
      ? chooseLatencyUnit(latVals)
      : { unit: 'µs', divisor: 1e3, header: 'µs' },
    ops: opsVals.length
      ? chooseOpsUnit(opsVals)
      : { unit: 'ops', divisor: 1, header: 'Ops/s' },
  };
  const u = scales.latency.header;
  const oHdr = scales.ops.header;

  // Header labels with units
  const setTh = (id, text) => {
    const el = document.getElementById(id);
    if (el) el.textContent = text;
  };
  setTh('th-ops-median', `Median (${oHdr})`);
  setTh('th-ops-std', `Std (${oHdr})`);
  setTh('th-ops-p95', `P95 (${oHdr})`);
  setTh('th-ops-p99', `P99 (${oHdr})`);
  setTh('th-lat-median', `Median (${u})`);
  setTh('th-lat-std', `Std (${u})`);
  setTh('th-lat-p95', `P95 (${u})`);
  setTh('th-lat-p99', `P99 (${u})`);

  const baselineRaw =
    state.filteredGroups.find((g) => g.serializer === state.compareBaseline) || null;
  const baselineGroup = baselineRaw ? withOpsDerivedStats(baselineRaw) : null;

  const help = document.getElementById('detailed-analytics-help');
  if (help) {
    const scope = parseFixtureSelection(state.currentTestData);
    let scopeNote = ' Full roster for the current language, data type, and mode.';
    if (scope.kind === 'batch_compound') {
      scopeNote =
        ` <strong>Compounded batch</strong>: mean of <code>${escapeHtml(scope.base)}@n=${scope.nA}</code> and <code>${escapeHtml(scope.base)}@n=${scope.nB}</code>.`;
    } else if (scope.kind === 'all_n') {
      scopeNote = ` <strong>Compounded data types</strong> at <code>n=${scope.n}</code>.`;
    } else if (scope.kind === 'all_all') {
      scopeNote = ` <strong>Compounded all</strong> (<code>all@all</code>).`;
    }
    const speedNote = isOps
      ? ' View: <strong>Ops/s</strong> — Median, Std, P95, P99 + size.'
      : ' View: <strong>Latency</strong> — Median, Std, P95, P99 + size.';
    const ratioNote =
      ' Median &amp; size: <code>×base</code> vs baseline (green better / red worse).' +
      ' Std/P95/P99: <code>×med</code> vs that row’s median.';
    const paretoNote = ' <span style="color:var(--color-blue)">Blue rows</span> = Pareto-optimal.';
    if (baselineGroup) {
      help.innerHTML =
        scopeNote +
        speedNote +
        ratioNote +
        ` Baseline: <strong>${escapeHtml(serializerLabelFromGroup(baselineGroup))}</strong>.` +
        paretoNote;
    } else {
      help.innerHTML = scopeNote + speedNote + ratioNote + paretoNote;
    }
  }

  const colCount = 1 + (showHonesty ? 1 : 0) + metricKeys.length;
  if (rows.length === 0) {
    const tr = document.createElement('tr');
    tr.innerHTML = `<td colspan="${colCount}" style="text-align:center;color:var(--text-muted);">No serializers match search query</td>`;
    tbody.appendChild(tr);
    updateSortIndicators();
    return;
  }

  rows.forEach((r) => {
    const tr = document.createElement('tr');
    const isBaseline = baselineGroup && r.serializer === baselineGroup.serializer;
    const isOptimal = state.paretoSerializerNames.includes(r.serializer);
    if (isBaseline) tr.classList.add('roster-baseline-row');
    if (isOptimal) tr.classList.add('roster-pareto-row');

    const tdName = document.createElement('td');
    tdName.className = 'str';
    const displayName = serializerLabelFromGroup(r);
    let nameHtml = `<strong>${escapeHtml(displayName)}</strong>`;
    if (isBaseline) {
      nameHtml += ' <span class="badge badge-cyan">Baseline</span>';
    }
    tdName.innerHTML = nameHtml;
    tdName.title = r.serializer_version
      ? `${r.serializer} @ ${r.serializer_version}`
      : r.serializer;
    tr.appendChild(tdName);

    const tdHonesty = document.createElement('td');
    tdHonesty.className = 'str roster-col-honesty';
    const honestyLabel = honestyDisplayLabel(r.StreamMode);
    tdHonesty.textContent = honestyLabel;
    if (honestyLabel === 'adapted') {
      tdHonesty.title =
        'Adapted stream: in-memory encode/decode then dump to a stream. Do not treat as incremental I/O.';
    }
    tr.appendChild(tdHonesty);

    metricKeys.forEach(({ key, higherIsBetter }) => {
      const td = document.createElement('td');
      if (key.startsWith('ops_')) td.classList.add('roster-col-ops');
      if (key.startsWith('total_')) td.classList.add('roster-col-latency');

      const v = r[key];
      if (v === null || v === undefined) {
        td.textContent = '—';
        td.classList.add('num', 'sm-missing');
        tr.appendChild(td);
        return;
      }

      const cell = formatRosterRelativeCell(r, key, higherIsBetter, scales, baselineGroup, isBaseline);
      td.textContent = cell.text;
      td.className = (td.className + ' ' + cell.className).trim();
      tr.appendChild(td);
    });

    tbody.appendChild(tr);
  });
  updateSortIndicators();
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
    columns = ordered.map((name) => {
      const group = state.filteredGroups.find((g) => g.serializer === name) || null;
      return {
        key: name,
        // Docs Summary style: name:version
        label: group ? serializerLabelFromGroup(group) : name,
        group,
        isBaseline: name === state.compareBaseline,
      };
    });
  } else {
    const ordered = [...state.xlSelected];
    // baseline first
    const bi = ordered.findIndex((x) => `${x.lang}|${x.serializer}` === state.xlBaselineKey);
    if (bi > 0) {
      const [b] = ordered.splice(bi, 1);
      ordered.unshift(b);
    }
    columns = ordered.map((x) => {
      const group = findCrossLangGroup(x.lang, x.serializer);
      const serLabel = group
        ? serializerLabelFromGroup(group)
        : x.serializer;
      return {
        key: `${x.lang}|${x.serializer}`,
        label: `${languageLabel(x.lang)} / ${serLabel}`,
        group,
        isBaseline: `${x.lang}|${x.serializer}` === state.xlBaselineKey,
      };
    });
  }

  const headerRow = document.createElement('tr');
  const metricTh = document.createElement('th');
  metricTh.className = 'str cmp-th-metric';
  metricTh.textContent = 'Metric';
  headerRow.appendChild(metricTh);
  columns.forEach((col) => {
    const th = document.createElement('th');
    th.className = 'cmp-th-ser' + (col.isBaseline ? ' baseline-col' : '');
    th.title = col.isBaseline ? `${col.label} (baseline)` : col.label;

    // Split "Lang / name:ver" or "name:ver" into stacked lines (avoids interleaved wraps)
    let main = col.label;
    let sub = '';
    const slash = col.label.indexOf(' / ');
    if (slash >= 0) {
      sub = col.label.slice(0, slash);
      main = col.label.slice(slash + 3);
    }
    const colon = main.lastIndexOf(':');
    let name = main;
    let ver = '';
    if (colon > 0 && colon < main.length - 1) {
      name = main.slice(0, colon);
      ver = main.slice(colon + 1);
    }
    const nameEl = document.createElement('span');
    nameEl.className = 'cmp-th-name';
    nameEl.textContent = name;
    th.appendChild(nameEl);
    if (ver) {
      const verEl = document.createElement('span');
      verEl.className = 'cmp-th-ver';
      verEl.textContent = ver;
      th.appendChild(verEl);
    }
    if (sub) {
      const subEl = document.createElement('span');
      subEl.className = 'cmp-th-lang';
      subEl.textContent = sub;
      th.insertBefore(subEl, nameEl);
    }
    if (col.isBaseline) {
      const baseEl = document.createElement('span');
      baseEl.className = 'cmp-th-base';
      baseEl.textContent = 'baseline';
      th.appendChild(baseEl);
    }
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
  const metricSpecs = rosterMetricKeys();
  const rows = state.filteredGroups
    .map(withOpsDerivedStats)
    .sort((a, b) => a.serializer.localeCompare(b.serializer));
  const latVals = [];
  const opsVals = [];
  for (const g of rows) {
    for (const { key } of metricSpecs) {
      const v = g[key];
      if (typeof v !== 'number' || !Number.isFinite(v)) continue;
      if (key.startsWith('ops_')) opsVals.push(v);
      else if (key.endsWith('_ns')) latVals.push(v);
    }
  }
  const scales = {
    latency: latVals.length ? chooseLatencyUnit(latVals) : { divisor: 1e3, header: 'µs' },
    ops: opsVals.length ? chooseOpsUnit(opsVals) : { divisor: 1, header: 'Ops/s' },
  };
  const baselineRaw =
    state.filteredGroups.find((g) => g.serializer === state.compareBaseline) || null;
  const baselineGroup = baselineRaw ? withOpsDerivedStats(baselineRaw) : null;
  const baseLabel = baselineGroup
    ? serializerLabelFromGroup(baselineGroup)
    : state.compareBaseline || '—';
  const u = scales.latency.header;
  const oHdr = scales.ops.header;
  const showHonesty = normalizeMode(state.currentMode) === 'stream';
  const headers = ['Serializer'];
  if (showHonesty) headers.push('Honesty');
  metricSpecs.forEach(({ key, label }) => {
    if (key.startsWith('ops_')) headers.push(`${label} (${oHdr})`);
    else if (key.endsWith('_ns')) headers.push(`${label} (${u})`);
    else if (key === 'median_size_bytes') headers.push('Size (bytes)');
    else headers.push(label || key);
  });
  headers.push('Pareto');
  const lines = [
    `Baseline: ${baseLabel}`,
    `View: ${state.rosterMetric === 'ops' ? 'Ops/s stats' : 'Latency stats'} + size`,
    `Ratios: median/size use ×base; Std/P95/P99 use ×med (own median)`,
    (() => {
      const s = parseFixtureSelection(state.currentTestData);
      if (s.kind === 'batch_compound') {
        return `Scope: compounded batch ${state.currentTestData} · mode ${state.currentMode}`;
      }
      if (s.kind === 'all_n') {
        return `Scope: all data types @ n=${s.n} · mode ${state.currentMode}`;
      }
      if (s.kind === 'all_all') {
        return `Scope: all@all (all types × all n) · mode ${state.currentMode}`;
      }
      return `Scope: data type ${state.currentTestData} · mode ${state.currentMode}`;
    })(),
    ``,
    `| ${headers.join(' | ')} |`,
    `|${headers.map((h, i) => (i === 0 || h === 'Pareto' || h === 'Honesty' ? '---' : '---:')).join('|')}|`,
  ];
  rows.forEach((r) => {
    const opt = state.paretoSerializerNames.includes(r.serializer) ? 'yes' : '';
    const isBaseline = baselineGroup && r.serializer === baselineGroup.serializer;
    const cells = metricSpecs.map(({ key, higherIsBetter }) => {
      const cell = formatRosterRelativeCell(
        r,
        key,
        higherIsBetter,
        scales,
        baselineGroup,
        isBaseline
      );
      return cell.text;
    });
    const name =
      serializerLabelFromGroup(r) + (isBaseline ? ' (baseline)' : '');
    const honestyCell = showHonesty ? ` ${honestyDisplayLabel(r.StreamMode)} |` : '';
    lines.push(`| ${name} |${honestyCell} ${cells.join(' | ')} | ${opt} |`);
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
