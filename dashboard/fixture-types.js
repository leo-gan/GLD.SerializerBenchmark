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
export const VISIBLE_TYPE_IDS = [...SUITE_TYPE_IDS, ...COLUMNAR_TYPE_IDS];

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
