/**
 * Data-type ids for the Dashboard Test Data menu.
 *
 * SUITE_TYPE_IDS are the five row types. all@n and all@all average only these,
 * so a columnar publish does not move the published row rankings.
 * COLUMNAR_TYPE_IDS appear as their own data types, and as a per-type 1+100
 * compound when both batch sizes exist. They are not mixed into all@all.
 */
export const SUITE_TYPE_IDS = ['message', 'document', 'telemetry', 'strings', 'event'];
export const COLUMNAR_TYPE_IDS = ['table', 'table_project', 'nested_table', 'signal'];
export const GRAPH_TYPE_IDS = ['graph'];
export const ARRAY_TYPE_IDS = ['grid', 'grid_window'];
export const VISIBLE_TYPE_IDS = [...SUITE_TYPE_IDS, ...COLUMNAR_TYPE_IDS, ...GRAPH_TYPE_IDS, ...ARRAY_TYPE_IDS];
export const DATA_SET_ORDER = ['suite', 'columnar', 'graph', 'array'];
export const DATA_SET_LABELS = { suite: 'Suite', columnar: 'Columnar', graph: 'Graph', array: 'Array' };

export function dataSetLabel(id) {
  return DATA_SET_LABELS[id] || 'Suite';
}

export function baseTypeId(key) {
  if (!key) return '';
  const i = String(key).indexOf('@n=');
  return i >= 0 ? String(key).slice(0, i) : String(key);
}

/** Instance count from group (column or @n= suffix). */
export function instanceCount(g) {
  let n = g?.data_type_instance_count;
  if (n != null && n !== '') {
    const num = Number(n);
    if (Number.isFinite(num) && num > 0) return num;
  }
  const m = String(g?.test_data ?? '').match(/@n=(\d+)/i);
  return m ? Number(m[1]) : null;
}

export function compoundFixtureKey(base, nA, nB) {
  const a = Math.min(nA, nB);
  const b = Math.max(nA, nB);
  return `${base}@n=${a}+${b}`;
}

/** Natural + synthetic data-type keys for the Test Data dropdown. */
export function discoverFixtureOptions(allGroups) {
  const natural = [
    ...new Set(
      (allGroups || [])
        .map((g) => g.test_data)
        .filter((k) => k && VISIBLE_TYPE_IDS.includes(baseTypeId(k))),
    ),
  ].sort();

  const byBase = new Map();
  const nsSuite = new Set();
  for (const g of allGroups || []) {
    const base = baseTypeId(g.test_data);
    if (!VISIBLE_TYPE_IDS.includes(base)) continue;
    const n = instanceCount(g);
    if (n == null) continue;
    if (!byBase.has(base)) byBase.set(base, new Set());
    byBase.get(base).add(n);
    if (SUITE_TYPE_IDS.includes(base)) nsSuite.add(n);
  }

  // Per-type batch compounds: message@n=1+100, table@n=1+100, …
  const batchCompound = [];
  for (const [base, ns] of byBase) {
    if (ns.has(1) && ns.has(100)) {
      batchCompound.push(compoundFixtureKey(base, 1, 100));
    }
  }
  batchCompound.sort();

  // Cross-type at fixed n. Row types only — columnar groups stay out of all@n.
  const allTypes = [];
  if (nsSuite.has(1)) allTypes.push('all@1');
  if (nsSuite.has(100)) allTypes.push('all@100');

  const suiteNatural = natural.filter((k) => SUITE_TYPE_IDS.includes(baseTypeId(k)));
  const allAll = suiteNatural.length ? ['all@all'] : [];

  return {
    natural,
    batchCompound,
    allTypes,
    allAll,
    all: [...natural, ...batchCompound, ...allTypes, ...allAll],
  };
}

/** suite, columnar, graph, or array for a data-type menu key, including all@n compounds. */
export function dataSetForFixture(key) {
  const s = String(key || '');
  if (!s || s === 'all@all' || /^all@/i.test(s)) return 'suite';
  const base = baseTypeId(s);
  if (COLUMNAR_TYPE_IDS.includes(base)) return 'columnar';
  if (GRAPH_TYPE_IDS.includes(base)) return 'graph';
  if (ARRAY_TYPE_IDS.includes(base)) return 'array';
  return 'suite';
}

/** Menu keys that belong to one data set. */
export function fixturesForDataSet(keys, dataSet) {
  return (keys || []).filter((key) => dataSetForFixture(key) === dataSet);
}

/**
 * Preferred data type when the current one is not in the menu.
 * Suite keys win, in catalog order (`message@n=1` first).
 * A columnar-only menu prefers `table@n=1`, then `table`, then `table@n=100`.
 */
export function pickPreferredFixture(options) {
  if (!options || !options.length) return '';
  const preferred = [];
  for (const id of SUITE_TYPE_IDS) {
    preferred.push(`${id}@n=1`, id, `${id}@n=100`);
  }
  for (const key of preferred) {
    if (options.includes(key)) return key;
  }
  const suiteKey = options.find((key) => SUITE_TYPE_IDS.includes(baseTypeId(key)));
  if (suiteKey) return suiteKey;
  for (const key of ['table@n=1', 'table', 'table@n=100']) {
    if (options.includes(key)) return key;
  }
  for (const key of ['graph@n=1', 'graph', 'graph@n=100']) {
    if (options.includes(key)) return key;
  }
  for (const key of ['grid@n=1', 'grid', 'grid@n=100']) {
    if (options.includes(key)) return key;
  }
  return options[0] || '';
}

function groupDataSet(group) {
  if (!group) return '';
  if (group.data_set === 'suite' || group.data_set === 'columnar' || group.data_set === 'graph' || group.data_set === 'array') {
    return group.data_set;
  }
  if (!group.test_data) return '';
  return dataSetForFixture(group.test_data);
}

function isNaturalFixtureKey(key) {
  const s = String(key || '');
  if (!s || s === 'all@all' || /^all@/i.test(s)) return false;
  return !/@n=\d+\+\d+$/i.test(s);
}

/**
 * Data set and data-type menu for one standard.
 * No rows: keep the current type (`keepType`) and leave the menu alone.
 * One data set: use it, and replace the type when it is outside that set.
 * Both: keep the current type when it is still present. The label follows the type.
 * preferPrimary is a Standard change. A standard that has Suite rows opens on
 * Suite, even when that library was also measured on Columnar types. Columnar-only
 * standards (no Suite rows) stay Columnar. All keeps the current type.
 * The returned keys still list every type, so Columnar stays in the data-type menu.
 *
 * @param {{ groups?: object[], standard?: string, testData?: string, preferPrimary?: boolean }} args
 */
export function resolveStandardDataSet({
  groups = [],
  standard = 'all',
  testData = '',
  preferPrimary = false,
} = {}) {
  const selected = standard || 'all';
  const matching = selected === 'all'
    ? (groups || [])
    : (groups || []).filter((group) => group && group.standard === selected);
  const present = new Set();
  for (const group of matching) {
    const dataSet = groupDataSet(group);
    if (dataSet) present.add(dataSet);
  }
  const sets = DATA_SET_ORDER.filter((id) => present.has(id));
  if (!sets.length) {
    return {
      keepType: true,
      dataSet: dataSetForFixture(testData) || 'suite',
      testData: testData || '',
      keys: [],
      sets: [],
    };
  }
  const keys = discoverFixtureOptions(matching).all;
  const primary = sets.includes('suite') ? 'suite' : sets[0];
  const snapToPrimary = !!preferPrimary && selected !== 'all' && sets.length > 1;
  let next = testData || '';
  if (snapToPrimary && dataSetForFixture(next) !== primary) next = '';
  if (!keys.includes(next)) {
    const pool = snapToPrimary ? keys.filter((key) => dataSetForFixture(key) === primary) : keys;
    const natural = pool.filter(isNaturalFixtureKey);
    next = pickPreferredFixture(natural) || pool[0] || keys[0] || '';
  }
  const dataSet = sets.length === 1 ? sets[0] : (dataSetForFixture(next) || primary);
  return { keepType: false, dataSet, testData: next, keys, sets };
}
