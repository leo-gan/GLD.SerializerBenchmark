import { test } from 'node:test';
import assert from 'node:assert/strict';
import { heatmapFromMatrix, parseRowIdentity, rowIdentity } from '../compliance-matrix.js';
import {
  NO_SPEC,
  PUBLISHED_STANDARD_COLUMNS,
  complianceHeatmap,
} from '../compliance-groups.js';

function cell(language, serializer, standard, total, passed = total) {
  return {
    language,
    serializer,
    format: 'protobuf',
    standard,
    version: 'proto3-json',
    passed,
    failed: total - passed,
    total,
  };
}

const JSON_MAP = 'Protocol Buffers JSON mapping';

test('All-languages heatmap keeps one row per language × serializer', () => {
  const matrix = [
    cell('c', 'protobuf-wire', JSON_MAP, 12),
    cell('cpp', 'protobuf-wire', JSON_MAP, 12),
    cell('swift', 'protobuf-wire', JSON_MAP, 12),
    cell('zig', 'protobuf-wire', JSON_MAP, 12),
    cell('go', 'protobuf', JSON_MAP, 12),
    cell('java', 'protobuf', JSON_MAP, 12),
    cell('kotlin', 'protobuf', JSON_MAP, 12),
    cell('php', 'protobuf', JSON_MAP, 12),
    cell('python', 'protobuf', JSON_MAP, 12),
    cell('csharp', 'Google.Protobuf', JSON_MAP, 12),
    cell('javascript', 'protobufjs', JSON_MAP, 12),
    cell('mojo', 'mojo-protobuf', JSON_MAP, 12, 8),
    cell('rust', 'prost', JSON_MAP, 12),
  ];
  const { rows } = heatmapFromMatrix(matrix, { format: 'protobuf' });
  assert.equal(rows.length, 13);
  const labels = rows.map((r) => `${r.language}:${r.serializer}`);
  assert.ok(labels.includes('cpp:protobuf-wire'));
  assert.ok(labels.includes('java:protobuf'));
  assert.ok(labels.includes('python:protobuf'));
  assert.ok(labels.includes('swift:protobuf-wire'));
  for (const row of rows) {
    const acc = row.byStandard.get(JSON_MAP);
    assert.equal(acc.total, 12, `${row.language} ${row.serializer}`);
  }
  const go = rows.find((r) => r.language === 'go');
  assert.equal(go.byStandard.get(JSON_MAP).total, 12);
  const mojo = rows.find((r) => r.language === 'mojo');
  assert.equal(mojo.byStandard.get(JSON_MAP).passed, 8);
});

test('All-standards padding keeps language × serializer rows', () => {
  const matrix = [
    cell('csharp', 'System.Text.Json', 'RFC 8259', 4),
    cell('csharp', 'Json.Net', 'RFC 8259', 4),
  ];
  const { rows } = heatmapFromMatrix(matrix, { format: '' });
  assert.equal(rows.length, 2);
});

test('Arrow, Parquet, ORC, and SBE show spec columns when the matrix is empty', () => {
  const extras = [
    { language: 'java', serializer: 'arrow-ipc' },
    { language: 'java', serializer: 'orc' },
    { language: 'java', serializer: 'orc-uncompressed' },
    { language: 'java', serializer: 'sbe' },
    { language: 'java', serializer: 'parquet' },
    { language: 'java', serializer: 'parquet-uncompressed' },
  ];
  const expected = {
    arrow: ['Arrow IPC stream'],
    parquet: ['Parquet file format'],
    orc: ['ORC v0', 'ORC v1'],
    sbe: ['SBE 1.0'],
  };
  for (const [format, titles] of Object.entries(expected)) {
    const heat = complianceHeatmap([], { format, language: 'java', extras });
    assert.deepEqual(heat.columns.map((column) => column.standard), titles, format);
    assert.ok(heat.columns.every((column) => column.unscored === true), format);
    assert.ok(heat.columns.every((column) => String(column.standard_url).startsWith('https://')), format);
    assert.equal(heat.columns.some((column) => /v2|2\.0/i.test(column.standard)), false, format);
    assert.ok(heat.rows.length > 0, format);
    assert.ok(heat.rows.every((row) => row.byStandard.size === 0), format);
  }
  assert.deepEqual(
    Object.keys(PUBLISHED_STANDARD_COLUMNS).sort(),
    ['arrow', 'orc', 'parquet', 'sbe'],
  );

  const onlyOrc = complianceHeatmap([], {
    format: 'orc',
    language: 'java',
    serializerKey: rowIdentity({ language: 'java', serializer: 'orc' }),
    extras,
  });
  assert.deepEqual(onlyOrc.rows.map((row) => row.serializer), ['orc']);
  assert.deepEqual(onlyOrc.columns.map((column) => column.standard), ['ORC v0', 'ORC v1']);
});

test('a scored ORC v1 cell replaces the empty ORC v0 placeholder', () => {
  const matrix = [cell('java', 'orc', 'ORC v1', 3)];
  matrix[0].format = 'orc';
  matrix[0].version = 'v1';
  const heat = complianceHeatmap(matrix, {
    format: 'orc',
    language: 'java',
    extras: [
      { language: 'java', serializer: 'orc' },
      { language: 'java', serializer: 'orc-uncompressed' },
    ],
  });
  assert.deepEqual(heat.columns.map((column) => column.standard), ['ORC v1']);
  assert.equal(heat.columns[0].unscored, undefined);
  assert.equal(heat.rows.find((row) => row.serializer === 'orc').byStandard.get('ORC v1').passed, 3);
});

test('a scored standard keeps its matrix columns', () => {
  const matrix = [cell('python', 'json', 'RFC 8259', 4)];
  matrix[0].format = 'json';
  const heat = complianceHeatmap(matrix, {
    format: 'json',
    language: 'python',
    extras: [{ language: 'python', serializer: 'json' }, { language: 'python', serializer: 'orjson' }],
  });
  assert.deepEqual(heat.columns.map((column) => column.standard), ['RFC 8259']);
  assert.equal(heat.columns[0].unscored, undefined);
  assert.equal(heat.rows.find((row) => row.serializer === 'orjson').byStandard.size, 0);

  const all = complianceHeatmap([], {
    format: '',
    extras: [{ language: 'python', serializer: 'arrow-ipc' }],
  });
  assert.deepEqual(all.columns, []);
  const noSpec = complianceHeatmap([], {
    format: NO_SPEC,
    extras: [{ language: 'python', serializer: 'pickle' }],
  });
  assert.deepEqual(noSpec.columns, []);
});

test('row identity never drops the language', () => {
  assert.equal(rowIdentity({ language: 'c', serializer: 'protobuf-wire' }).startsWith('c'), true);
  assert.notEqual(
    rowIdentity({ language: 'c', serializer: 'protobuf-wire' }),
    rowIdentity({ language: 'cpp', serializer: 'protobuf-wire' }),
  );
  const parsed = parseRowIdentity(rowIdentity({ language: 'go', serializer: 'protobuf' }));
  assert.deepEqual(parsed, { language: 'go', serializer: 'protobuf' });
});
