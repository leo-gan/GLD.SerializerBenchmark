import { test } from 'node:test';
import assert from 'node:assert/strict';
import { heatmapFromMatrix, parseRowIdentity, rowIdentity } from '../compliance-matrix.js';

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

test('row identity never drops the language', () => {
  assert.equal(rowIdentity({ language: 'c', serializer: 'protobuf-wire' }).startsWith('c'), true);
  assert.notEqual(
    rowIdentity({ language: 'c', serializer: 'protobuf-wire' }),
    rowIdentity({ language: 'cpp', serializer: 'protobuf-wire' }),
  );
  const parsed = parseRowIdentity(rowIdentity({ language: 'go', serializer: 'protobuf' }));
  assert.deepEqual(parsed, { language: 'go', serializer: 'protobuf' });
});
