import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { VISIBLE_TYPE_IDS } from '../fixture-types.js';
import {
  exampleIsSingleRecord,
  exampleSummary,
  exampleTypeIds,
  renderTypeExampleBody,
} from '../type-examples.js';

const here = dirname(fileURLToPath(import.meta.url));

test('a batch still asks for the n=1 example of that data type', () => {
  assert.deepEqual(exampleTypeIds('message@n=1'), ['message']);
  assert.deepEqual(exampleTypeIds('message@n=100'), ['message']);
  assert.deepEqual(exampleTypeIds('telemetry@n=1+100'), ['telemetry']);
  assert.equal(exampleIsSingleRecord('message@n=1'), true);
  assert.equal(exampleIsSingleRecord('document'), true);
  assert.equal(exampleIsSingleRecord('message@n=100'), false);
  assert.equal(exampleIsSingleRecord('message@n=1+100'), false);
});

test('an average asks for one record of each suite data type', () => {
  assert.deepEqual(exampleTypeIds('all@1'), ['message', 'document', 'telemetry', 'strings', 'event']);
  assert.deepEqual(exampleTypeIds('all@100'), ['message', 'document', 'telemetry', 'strings', 'event']);
  assert.deepEqual(exampleTypeIds('all@all'), ['message', 'document', 'telemetry', 'strings', 'event']);
  assert.equal(exampleIsSingleRecord('all@1'), false);
  assert.equal(exampleSummary(5), 'Examples · one record each (n=1)');
  assert.equal(exampleSummary(1), 'Example · one record (n=1)');
});

test('the example body says n=1 and stays free of a batch record', () => {
  const html = renderTypeExampleBody({
    ids: ['message'],
    examples: { types: { message: { record: { f_bool: true } } } },
    menuLabel: 'message@n=100',
    singleRecord: false,
  });
  assert.match(html, /n=1 only/);
  assert.match(html, /message@n=100/);
  assert.match(html, /&quot;f_bool&quot;: true/);
  assert.doesNotMatch(html, /open/);
});

test('published examples cover every data type at one record', () => {
  const path = join(here, '..', 'public', 'data', 'type-examples.json');
  const doc = JSON.parse(readFileSync(path, 'utf8'));
  assert.equal(doc.n, 1);
  assert.equal(doc.seed, 42);
  for (const id of VISIBLE_TYPE_IDS) {
    assert.equal(typeof doc.types[id].record, 'object', id);
  }
  const tensor = doc.types.tensor.record;
  assert.equal(tensor.rows, 1024);
  assert.equal(tensor.cols, 1024);
  assert.equal(tensor.values.at(-1)._more > 32, true);
  assert.equal(tensor.values[0], '-0');
  assert.equal(tensor.values[1], 'NaN');
  const page = readFileSync(join(here, '..', 'index.html'), 'utf8');
  assert.match(page, /<details id="datatype-example"/);
  assert.doesNotMatch(page, /<details id="datatype-example"[^>]*open/);
});
