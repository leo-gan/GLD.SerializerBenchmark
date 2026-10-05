import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  applyDimensionLabels,
  dataSetForTypeId,
  matchesStandard,
  standardForSerializer,
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
