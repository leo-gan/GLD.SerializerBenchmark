import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  applyDimensionLabels,
  dataSetForTypeId,
  matchesStandard,
  standardForSerializer,
  benchmarkStandardMenu,
  NO_SERIALIZERS_SEP,
  NO_SERIALIZERS_SEP_ID,
  standardSelectOptions,
} from '../dimension-labels.js';

const labels = {
  data_sets: { message: 'suite', table: 'columnar', signal: 'columnar' },
  standards: {
    c: { yyjson: 'json', 'custom-binary': 'custom' },
    csharp: { 'MS Bond Json': 'json' },
    python: { parquet: 'parquet' },
  },
};

test('data set is the parent of the type id', () => {
  assert.equal(dataSetForTypeId('message@n=1', labels.data_sets), 'suite');
  assert.equal(dataSetForTypeId('table', labels.data_sets), 'columnar');
  assert.equal(dataSetForTypeId('signal', labels.data_sets), 'columnar');
});

test('standard comes from the compliance map, including custom', () => {
  assert.equal(standardForSerializer('c', 'yyjson', labels.standards), 'json');
  assert.equal(standardForSerializer('c', 'custom-binary', labels.standards), 'custom');
  assert.equal(standardForSerializer('csharp', 'MS Bond Json', labels.standards), 'json');
});

test('apply fills missing labels and keeps labels already on the row', () => {
  const row = applyDimensionLabels(
    { language: 'c', serializer: 'yyjson', test_data: 'message' },
    labels,
  );
  assert.equal(row.standard, 'json');
  assert.equal(row.data_set, 'suite');
  const kept = applyDimensionLabels(
    { language: 'c', serializer: 'yyjson', test_data: 'message', standard: 'json', data_set: 'suite' },
    labels,
  );
  assert.equal(kept.standard, 'json');
});

test('All is the default standard option and a filter keeps one standard', () => {
  const groups = [
    { serializer: 'yyjson', standard: 'json' },
    { serializer: 'parquet', standard: 'parquet' },
  ];
  assert.deepEqual(standardSelectOptions(groups), ['all', 'json', 'parquet']);
  assert.equal(matchesStandard(groups[0], 'all'), true);
  assert.equal(matchesStandard(groups[1], 'json'), false);
  assert.equal(matchesStandard(groups[0], 'json'), true);
});


test('Standard menu is All, populated standards, then standards with no serializers', () => {
  const items = benchmarkStandardMenu({
    language: 'csharp',
    labels,
    allStandardIds: ['json', 'arrow', 'toml', 'parquet', 'avro'],
    labelOf: (id) => ({ json: 'JSON', arrow: 'Arrow IPC', toml: 'TOML', parquet: 'Parquet', avro: 'Avro', custom: 'Custom' }[id] || id),
  });
  const ids = items.map((item) => item.id);
  assert.equal(ids[0], 'all');
  const sep = ids.indexOf(NO_SERIALIZERS_SEP_ID);
  assert.ok(sep > 1);
  assert.equal(items[sep].disabled, true);
  assert.equal(items[sep].label, NO_SERIALIZERS_SEP);
  const populated = ids.slice(1, sep);
  const empty = ids.slice(sep + 1);
  assert.deepEqual(populated, ['json']);
  assert.ok(empty.includes('arrow'));
  assert.ok(empty.includes('toml'));
  assert.ok(empty.includes('parquet'));
  assert.ok(empty.includes('avro'));
  assert.ok(empty.includes('custom'));
  const emptyLabels = items.slice(sep + 1).map((item) => item.label);
  assert.deepEqual(emptyLabels, [...emptyLabels].sort((a, b) => a.localeCompare(b, undefined, { sensitivity: 'base' })));
});
