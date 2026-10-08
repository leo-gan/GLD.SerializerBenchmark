/**
 * Standard and Data Set labels for benchmark rows.
 * The map is dashboard/public/data/dimension-labels.json, built from
 * compliance/serializer-standards.json and schemas/data_catalog_v2.yaml.
 */

export function baseTypeId(key) {
  const raw = String(key || '');
  const at = raw.indexOf('@');
  return at >= 0 ? raw.slice(0, at) : raw;
}

export function dataSetForTypeId(typeId, dataSets) {
  const base = baseTypeId(typeId);
  const value = dataSets && dataSets[base];
  return typeof value === 'string' ? value : '';
}

export function standardForSerializer(language, serializer, standards) {
  const lang = standards && standards[language];
  if (!lang) return '';
  const value = lang[serializer];
  return typeof value === 'string' ? value : '';
}

/** Fill standard and data_set when the stats row does not already carry them. */
export function applyDimensionLabels(group, labels) {
  if (!group || !labels) return group;
  const language = group.language || '';
  if (!group.data_set) {
    const dataSet = dataSetForTypeId(group.test_data, labels.data_sets);
    if (dataSet) group.data_set = dataSet;
  }
  if (!group.standard) {
    const standard = standardForSerializer(language, group.serializer, labels.standards);
    if (standard) group.standard = standard;
  }
  return group;
}

export const NO_SERIALIZERS_SEP = '--no serializers--';
export const NO_SERIALIZERS_SEP_ID = '__no-serializers__';

function compareStandardLabels(a, b, labelOf) {
  return labelOf(a).localeCompare(labelOf(b), undefined, { sensitivity: 'base' });
}

/**
 * Standard dropdown for one language.
 * All, then standards that have a serializer here (sorted), then a disabled
 * separator, then standards that have none here (sorted).
 *
 * @param {object} args
 * @param {object[]} [args.groups] rows for this language (any data type)
 * @param {object} [args.labels] dimension-labels.json
 * @param {string} [args.language]
 * @param {string[]} [args.allStandardIds] every known standard id
 * @param {(id: string) => string} [args.labelOf]
 */
export function benchmarkStandardMenu({
  groups = [],
  labels = null,
  language = '',
  allStandardIds = [],
  labelOf = (id) => id,
} = {}) {
  const present = new Set();
  const langMap = (labels && labels.standards && labels.standards[language]) || {};
  for (const standard of Object.values(langMap)) {
    if (standard) present.add(standard);
  }
  for (const group of groups || []) {
    if (!group || !group.standard) continue;
    if (language && group.language && group.language !== language) continue;
    present.add(group.standard);
  }

  const universe = new Set(allStandardIds.filter(Boolean));
  if (labels && labels.standards) {
    for (const map of Object.values(labels.standards)) {
      for (const standard of Object.values(map || {})) {
        if (standard) universe.add(standard);
      }
    }
  }
  for (const standard of present) universe.add(standard);

  const populated = [];
  const empty = [];
  for (const id of universe) {
    if (id === 'all' || id === NO_SERIALIZERS_SEP_ID) continue;
    (present.has(id) ? populated : empty).push(id);
  }
  populated.sort((a, b) => compareStandardLabels(a, b, labelOf));
  empty.sort((a, b) => compareStandardLabels(a, b, labelOf));

  const items = [{ id: 'all', label: 'All', disabled: false }];
  for (const id of populated) items.push({ id, label: labelOf(id), disabled: false });
  if (empty.length) {
    items.push({ id: NO_SERIALIZERS_SEP_ID, label: NO_SERIALIZERS_SEP, disabled: true });
    for (const id of empty) items.push({ id, label: labelOf(id), disabled: false });
  }
  return items;
}

/** @deprecated flat ids; the menu uses benchmarkStandardMenu. */
export function standardSelectOptions(groups) {
  const ids = new Set();
  for (const group of groups || []) {
    if (group && group.standard) ids.add(group.standard);
  }
  return ['all', ...[...ids].sort((a, b) => a.localeCompare(b))];
}

export function matchesStandard(group, selected) {
  if (!selected || selected === 'all') return true;
  return group?.standard === selected;
}

/**
 * Registered serializers that the current published run did not measure.
 * Charts stay on measured rows. These are table placeholders only.
 * A row is kept when its standard matches the Overview filter.
 */
export function missingRegisteredRows({
  language = '',
  selectedStandard = 'all',
  measuredNames = [],
  registrations = [],
  testData = '',
} = {}) {
  const measured = new Set(measuredNames);
  const out = [];
  for (const row of registrations || []) {
    if (!row || row.language !== language) continue;
    const name = row.serializer || row.name || '';
    if (!name || measured.has(name)) continue;
    const group = {
      language,
      serializer: name,
      standard: row.standard || '',
      test_data: testData,
      unmeasured: true,
    };
    if (!matchesStandard(group, selectedStandard)) continue;
    out.push(group);
  }
  out.sort((a, b) => a.serializer.localeCompare(b.serializer));
  return out;
}
