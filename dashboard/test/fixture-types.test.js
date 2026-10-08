import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  dataSetForFixture,
  fixturesForDataSet,
  pickPreferredFixture,
  resolveStandardDataSet,
} from '../fixture-types.js';

test('data set is suite for row types and all@ compounds', () => {
  assert.equal(dataSetForFixture('message@n=1'), 'suite');
  assert.equal(dataSetForFixture('event@n=100'), 'suite');
  assert.equal(dataSetForFixture('message@n=1+100'), 'suite');
  assert.equal(dataSetForFixture('all@100'), 'suite');
  assert.equal(dataSetForFixture('all@all'), 'suite');
});

test('data set is columnar for table types', () => {
  assert.equal(dataSetForFixture('table@n=1'), 'columnar');
  assert.equal(dataSetForFixture('signal@n=100'), 'columnar');
  assert.equal(dataSetForFixture('table@n=1+100'), 'columnar');
});

test('data type menu keeps only the selected data set', () => {
  const keys = ['message@n=1', 'event@n=100', 'table@n=1', 'all@100', 'table@n=1+100'];
  assert.deepEqual(fixturesForDataSet(keys, 'suite'), ['message@n=1', 'event@n=100', 'all@100']);
  assert.deepEqual(fixturesForDataSet(keys, 'columnar'), ['table@n=1', 'table@n=1+100']);
});

function row(standard, base, n) {
  const columnar = ['table', 'table_project', 'nested_table', 'signal'].includes(base);
  return {
    standard,
    data_set: columnar ? 'columnar' : 'suite',
    test_data: `${base}@n=${n}`,
    data_type_instance_count: n,
  };
}

function rows(standard, bases, ns = [1, 100]) {
  const out = [];
  for (const base of bases) {
    for (const n of ns) out.push(row(standard, base, n));
  }
  return out;
}

const SUITE = ['message', 'document', 'telemetry', 'strings', 'event'];
const COLUMNAR = ['table', 'table_project', 'nested_table', 'signal'];
const SBE = ['table', 'table_project', 'signal'];

test('columnar-only menu prefers table@n=1 over a sorted nested_table key', () => {
  assert.equal(
    pickPreferredFixture(['nested_table@n=1', 'signal@n=1', 'table@n=100']),
    'table@n=100',
  );
  assert.equal(pickPreferredFixture(['signal@n=1', 'nested_table@n=1']), 'signal@n=1');
  assert.equal(
    pickPreferredFixture(['table@n=1', 'message@n=1+100']),
    'message@n=1+100',
  );
});

test('Arrow selects Columnar and replaces a suite data type', () => {
  const resolved = resolveStandardDataSet({
    groups: rows('arrow', COLUMNAR),
    standard: 'arrow',
    testData: 'message@n=1',
  });
  assert.equal(resolved.keepType, false);
  assert.deepEqual(resolved.sets, ['columnar']);
  assert.equal(resolved.dataSet, 'columnar');
  assert.equal(resolved.testData, 'table@n=1');
  assert.equal(resolved.keys.includes('message@n=1'), false);
  assert.equal(resolved.keys.includes('nested_table@n=1'), true);
});

test('SBE omits nested_table', () => {
  const resolved = resolveStandardDataSet({
    groups: rows('sbe', SBE),
    standard: 'sbe',
    testData: 'nested_table@n=1',
  });
  assert.equal(resolved.testData, 'table@n=1');
  assert.equal(resolved.keys.some((key) => key.startsWith('nested_table')), false);
  assert.equal(resolved.keys.includes('signal@n=1'), true);
});

test('JSON keeps both sets and the current suite type', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('json', SUITE), ...rows('json', COLUMNAR)],
    standard: 'json',
    testData: 'message@n=1',
  });
  assert.deepEqual(resolved.sets, ['suite', 'columnar']);
  assert.equal(resolved.dataSet, 'suite');
  assert.equal(resolved.testData, 'message@n=1');
  assert.equal(resolved.keys.includes('table@n=1'), true);
  assert.equal(resolved.keys.includes('all@100'), true);
});

test('MessagePack forces Suite', () => {
  const resolved = resolveStandardDataSet({
    groups: rows('msgpack', SUITE),
    standard: 'msgpack',
    testData: 'table@n=1',
  });
  assert.deepEqual(resolved.sets, ['suite']);
  assert.equal(resolved.dataSet, 'suite');
  assert.equal(resolved.testData, 'message@n=1');
  assert.equal(resolved.keys.includes('table@n=1'), false);
});

test('All keeps the current data type and its data set', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('json', SUITE), ...rows('arrow', COLUMNAR)],
    standard: 'all',
    testData: 'nested_table@n=100',
  });
  assert.equal(resolved.keepType, false);
  assert.deepEqual(resolved.sets, ['suite', 'columnar']);
  assert.equal(resolved.testData, 'nested_table@n=100');
  assert.equal(resolved.dataSet, 'columnar');
});

test('a standard with no rows does not change the data type', () => {
  const resolved = resolveStandardDataSet({
    groups: rows('arrow', COLUMNAR),
    standard: 'thrift',
    testData: 'message@n=1',
  });
  assert.equal(resolved.keepType, true);
  assert.equal(resolved.testData, 'message@n=1');
  assert.equal(resolved.dataSet, 'suite');
  assert.deepEqual(resolved.keys, []);
});
