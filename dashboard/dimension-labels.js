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

/** Dropdown values. All is first. Other ids are sorted. */
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
