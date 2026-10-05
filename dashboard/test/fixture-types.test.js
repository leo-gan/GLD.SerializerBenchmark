import { test } from 'node:test';
import assert from 'node:assert/strict';
import { dataSetForFixture, fixturesForDataSet } from '../fixture-types.js';

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
