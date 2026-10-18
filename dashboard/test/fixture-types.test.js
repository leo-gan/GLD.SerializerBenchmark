import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  dataSetForFixture,
  discoverFixtureOptions,
  fixturesForDataSet,
  groupMatchesDataSet,
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

test('data set is array for grid types and all@ stays suite', () => {
  assert.equal(dataSetForFixture('grid@n=1'), 'array');
  assert.equal(dataSetForFixture('grid_window@n=1'), 'array');
  assert.equal(dataSetForFixture('all@all'), 'suite');
  const discovered = discoverFixtureOptions([
    { test_data: 'message@n=1', data_type_instance_count: 1 },
    { test_data: 'grid@n=1', data_type_instance_count: 1 },
    { test_data: 'grid_window@n=1', data_type_instance_count: 1 },
    { test_data: 'event@n=100', data_type_instance_count: 100 },
  ]);
  assert.ok(discovered.all.includes('grid@n=1'));
  assert.ok(discovered.all.includes('all@all'));
  assert.equal(discovered.all.includes('grid@n=1+100'), false);
  assert.equal(discovered.allAll.includes('all@all'), true);
  const onlyArray = discoverFixtureOptions([
    { test_data: 'grid_window@n=1', data_type_instance_count: 1, standard: 'hdf5', data_set: 'array' },
    { test_data: 'grid@n=1', data_type_instance_count: 1, standard: 'hdf5', data_set: 'array' },
  ]);
  assert.equal(onlyArray.all.includes('all@all'), false);
  const resolved = resolveStandardDataSet({
    groups: [
      { standard: 'hdf5', data_set: 'array', test_data: 'grid_window@n=1', data_type_instance_count: 1 },
      { standard: 'hdf5', data_set: 'array', test_data: 'grid@n=1', data_type_instance_count: 1 },
    ],
    standard: 'hdf5',
    testData: 'message@n=1',
    preferPrimary: true,
  });
  assert.equal(resolved.dataSet, 'array');
  assert.equal(resolved.testData, 'grid@n=1');
});

test('data set is tensor for ML payloads and all@ stays suite', () => {
  assert.equal(dataSetForFixture('tensor@n=1'), 'tensor');
  assert.equal(dataSetForFixture('tensor_view@n=1'), 'tensor');
  assert.equal(dataSetForFixture('prompt'), 'tensor');
  assert.equal(dataSetForFixture('shard@n=1'), 'tensor');
  assert.equal(dataSetForFixture('request@n=1'), 'tensor');
  assert.equal(dataSetForFixture('all@all'), 'suite');
  const keys = ['message@n=1', 'tensor@n=1', 'prompt@n=1', 'all@all'];
  assert.deepEqual(fixturesForDataSet(keys, 'tensor'), ['tensor@n=1', 'prompt@n=1']);
  const resolved = resolveStandardDataSet({
    groups: [
      { standard: 'hdf5', data_set: 'tensor', test_data: 'tensor@n=1', data_type_instance_count: 1 },
      { standard: 'hdf5', data_set: 'array', test_data: 'grid@n=1', data_type_instance_count: 1 },
    ],
    standard: 'hdf5',
    testData: 'tensor@n=1',
    dataSet: 'tensor',
  });
  assert.equal(resolved.dataSet, 'tensor');
  assert.equal(resolved.testData, 'tensor@n=1');
  assert.deepEqual(resolved.keys, ['tensor@n=1']);
});

test('data set is graph for the graph type and all@ stays suite', () => {
  assert.equal(dataSetForFixture('graph@n=1'), 'graph');
  assert.equal(dataSetForFixture('graph@n=100'), 'graph');
  assert.equal(dataSetForFixture('all@all'), 'suite');
  const keys = ['message@n=1', 'graph@n=1', 'table@n=1', 'all@all'];
  assert.deepEqual(fixturesForDataSet(keys, 'graph'), ['graph@n=1']);
  assert.deepEqual(fixturesForDataSet(keys, 'suite'), ['message@n=1', 'all@all']);
  const discovered = discoverFixtureOptions([
    { test_data: 'message@n=1', data_type_instance_count: 1 },
    { test_data: 'graph@n=1', data_type_instance_count: 1 },
    { test_data: 'event@n=100', data_type_instance_count: 100 },
  ]);
  assert.ok(discovered.all.includes('graph@n=1'));
  assert.ok(discovered.all.includes('all@all'));
  assert.equal(discovered.allTypes.includes('all@1'), true);
  assert.equal(discovered.all.filter((key) => key.startsWith('graph')).length, 1);
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
  assert.equal(resolved.keys.includes('table@n=1'), false);
  assert.equal(resolved.keys.includes('message@n=1'), true);
  assert.equal(resolved.keys.includes('all@100'), true);
  assert.equal(resolved.keys.every((key) => dataSetForFixture(key) === 'suite'), true);
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

test('a standard measured on both sets keeps a columnar type until the standard changes', () => {
  const groups = [...rows('avro', SUITE), ...rows('avro', COLUMNAR)];
  const kept = resolveStandardDataSet({
    groups,
    standard: 'avro',
    testData: 'table@n=1',
  });
  assert.deepEqual(kept.sets, ['suite', 'columnar']);
  assert.equal(kept.dataSet, 'columnar');
  assert.equal(kept.testData, 'table@n=1');
  assert.equal(kept.keys.includes('message@n=1'), false);
  assert.equal(kept.keys.every((key) => dataSetForFixture(key) === 'columnar'), true);
});

test('changing to Avro, JSON, Protocol Buffers, or FlatBuffers opens Suite', () => {
  for (const standard of ['avro', 'json', 'protobuf', 'flatbuffers']) {
    const resolved = resolveStandardDataSet({
      groups: [...rows(standard, SUITE), ...rows(standard, COLUMNAR)],
      standard,
      testData: 'table@n=100',
      preferPrimary: true,
    });
    assert.equal(resolved.dataSet, 'suite', standard);
    assert.equal(resolved.testData, 'message@n=1', standard);
    assert.equal(resolved.keys.includes('table@n=1'), false, standard);
    assert.equal(resolved.keys.includes('nested_table@n=1'), false, standard);
    assert.equal(resolved.keys.includes('message@n=1'), true, standard);
    assert.equal(resolved.sets.includes('columnar'), true, standard);
  }
});

test('a standard change keeps the current Suite type', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('avro', SUITE), ...rows('avro', COLUMNAR)],
    standard: 'avro',
    testData: 'event@n=100',
    preferPrimary: true,
  });
  assert.equal(resolved.dataSet, 'suite');
  assert.equal(resolved.testData, 'event@n=100');
});

test('changing to a columnar-only standard still opens Columnar', () => {
  for (const standard of ['arrow', 'parquet', 'orc']) {
    const resolved = resolveStandardDataSet({
      groups: rows(standard, COLUMNAR),
      standard,
      testData: 'message@n=1',
      preferPrimary: true,
    });
    assert.equal(resolved.dataSet, 'columnar', standard);
    assert.equal(resolved.testData, 'table@n=1', standard);
  }
  const sbe = resolveStandardDataSet({
    groups: rows('sbe', SBE),
    standard: 'sbe',
    testData: 'nested_table@n=1',
    preferPrimary: true,
  });
  assert.equal(sbe.dataSet, 'columnar');
  assert.equal(sbe.testData, 'table@n=1');
});

test('All keeps the current columnar type when the standard changes to All', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('json', SUITE), ...rows('avro', SUITE), ...rows('avro', COLUMNAR), ...rows('arrow', COLUMNAR)],
    standard: 'all',
    testData: 'signal@n=100',
    preferPrimary: true,
  });
  assert.equal(resolved.dataSet, 'columnar');
  assert.equal(resolved.testData, 'signal@n=100');
});

test('an explicit data set keeps keys and the data type inside that set', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('json', SUITE), ...rows('json', COLUMNAR)],
    standard: 'json',
    testData: 'message@n=1',
    dataSet: 'columnar',
  });
  assert.equal(resolved.dataSet, 'columnar');
  assert.equal(resolved.testData, 'table@n=1');
  assert.equal(resolved.keys.includes('message@n=1'), false);
  assert.equal(resolved.keys.every((key) => dataSetForFixture(key) === 'columnar'), true);
});

test('a standard change opens Suite even when Columnar was the selected set', () => {
  const resolved = resolveStandardDataSet({
    groups: [...rows('avro', SUITE), ...rows('avro', COLUMNAR)],
    standard: 'avro',
    testData: 'table@n=1',
    dataSet: 'columnar',
    preferPrimary: true,
  });
  assert.equal(resolved.dataSet, 'suite');
  assert.equal(resolved.testData, 'message@n=1');
  assert.equal(resolved.keys.includes('table@n=1'), false);
});

test('HDF5, NetCDF, and ADIOS2 open Array and leave suite-typed rows out of Suite', () => {
  const arrayRow = (standard, serializer) => ({
    standard,
    serializer,
    data_set: 'array',
    test_data: 'grid@n=1',
    data_type_instance_count: 1,
  });
  const suiteRow = (standard, serializer) => ({
    standard,
    serializer,
    language: 'mojo',
    data_set: 'suite',
    test_data: 'message@n=1',
    data_type_instance_count: 1,
  });
  for (const [standard, arrayName, suiteName] of [
    ['hdf5', 'h5py', 'gld-hdf5'],
    ['netcdf', 'netCDF4', 'gld-netcdf'],
    ['adios2', 'adios2', 'gld-adios2'],
  ]) {
    const groups = [
      arrayRow(standard, arrayName),
      { ...arrayRow(standard, arrayName), test_data: 'grid_window@n=1' },
      suiteRow(standard, suiteName),
      { standard: 'json', serializer: 'mojo-json', data_set: 'suite', test_data: 'message@n=1', data_type_instance_count: 1 },
    ];
    const resolved = resolveStandardDataSet({
      groups,
      standard,
      testData: 'message@n=1',
      dataSet: 'suite',
      preferPrimary: true,
    });
    assert.deepEqual(resolved.sets, ['array'], standard);
    assert.equal(resolved.dataSet, 'array', standard);
    assert.equal(resolved.testData, 'grid@n=1', standard);
    assert.equal(resolved.keys.includes('message@n=1'), false, standard);
    assert.equal(groupMatchesDataSet(suiteRow(standard, suiteName), 'suite'), false, standard);
    assert.equal(groupMatchesDataSet(suiteRow(standard, suiteName), 'array'), false, standard);
    assert.equal(groupMatchesDataSet(arrayRow(standard, arrayName), 'array'), true, standard);
  }

  const mojoOnly = resolveStandardDataSet({
    groups: [{
      standard: 'hdf5',
      serializer: 'gld-hdf5',
      data_set: 'suite',
      test_data: 'message@n=1',
      data_type_instance_count: 1,
    }],
    standard: 'hdf5',
    testData: 'message@n=1',
    preferPrimary: true,
  });
  assert.deepEqual(mojoOnly.sets, ['array']);
  assert.equal(mojoOnly.dataSet, 'array');
  assert.deepEqual(mojoOnly.keys, []);
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
