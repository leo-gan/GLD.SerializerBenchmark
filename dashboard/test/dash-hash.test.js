import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  formatComplianceHash,
  formatExperimentsHash,
  parseComplianceHash,
  parseExperimentsHash,
} from '../dash-hash.js';

test('compliance hash: bare tab', () => {
  assert.deepEqual(parseComplianceHash('#compliance'), {
    active: true,
    lang: '',
    serializer: '',
    format: undefined,
  });
  assert.equal(parseComplianceHash('#dashboard').active, false);
  assert.equal(formatComplianceHash({}), '#compliance');
});

test('compliance hash: language only', () => {
  assert.deepEqual(parseComplianceHash('#compliance/python'), {
    active: true,
    lang: 'python',
    serializer: '',
    format: undefined,
  });
  assert.equal(formatComplianceHash({ lang: 'python' }), '#compliance/python');
});

test('compliance hash: language + serializer is All standards', () => {
  const loc = parseComplianceHash('#compliance/python/orjson');
  assert.equal(loc.active, true);
  assert.equal(loc.lang, 'python');
  assert.equal(loc.serializer, 'orjson');
  assert.equal(loc.format, undefined);
  assert.equal(
    formatComplianceHash({ lang: 'python', serializer: 'orjson' }),
    '#compliance/python/orjson',
  );
});

test('compliance hash: explicit standard family', () => {
  assert.equal(parseComplianceHash('#compliance/python/orjson/json').format, 'json');
  assert.equal(parseComplianceHash('#compliance/python/orjson/all').format, '');
  assert.equal(
    formatComplianceHash({ lang: 'python', serializer: 'orjson', format: 'yaml' }),
    '#compliance/python/orjson/yaml',
  );
});

test('compliance hash: encodes slashes and spaces in serializer names', () => {
  const name = 'shamaton/msgpack (array)';
  const href = formatComplianceHash({ lang: 'go', serializer: name });
  assert.equal(href, '#compliance/go/shamaton%2Fmsgpack%20(array)');
  assert.equal(parseComplianceHash(href).serializer, name);
});

test('experiments hash: list, detail, and language', () => {
  assert.deepEqual(parseExperimentsHash('#experiments'), {
    view: 'list',
    id: null,
    lang: '',
  });
  assert.deepEqual(parseExperimentsHash('#experiments/01-json-library-bakeoff'), {
    view: 'detail',
    id: '01-json-library-bakeoff',
    lang: '',
  });
  assert.deepEqual(parseExperimentsHash('#experiments/01-json-library-bakeoff/python'), {
    view: 'detail',
    id: '01-json-library-bakeoff',
    lang: 'python',
  });
  assert.equal(
    formatExperimentsHash({ id: '01-json-library-bakeoff', lang: 'python' }),
    '#experiments/01-json-library-bakeoff/python',
  );
  assert.equal(parseExperimentsHash('#dashboard').view, 'suite');
});
