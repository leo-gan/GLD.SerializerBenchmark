import { test } from 'node:test';
import assert from 'node:assert/strict';
import { aggregateCSVRecords, parseCSV } from '../csv-upload.js';

test('parseCSV keeps quoted commas and escaped quotes', () => {
  const rows = parseCSV('Name,Note\n"orjson","a, ""b"""\n\njson,plain\n');
  assert.deepEqual(rows, [
    { Name: 'orjson', Note: 'a, "b"' },
    { Name: 'json', Note: 'plain' },
  ]);
});

test('aggregateCSVRecords averages repeats and derives ops from time', () => {
  const groups = aggregateCSVRecords([
    { Serializer: 'orjson', TestData: 'message', Mode: 'bytes', TotalTimeNs: '1000', SizeBytes: '10', FidelityScore: '1' },
    { Serializer: 'orjson', TestData: 'message', Mode: 'bytes', TotalTimeNs: '3000', SizeBytes: '30', FidelityScore: '1' },
    { serializer: 'json', test_data: 'message', ops_per_sec: '100' },
    { Note: 'ignored' },
  ]);
  assert.equal(groups.length, 2);
  const orjson = groups.find((g) => g.serializer === 'orjson');
  assert.equal(orjson.avg_time_total_ns, 2000);
  assert.equal(orjson.median_size_bytes, 20);
  assert.equal(orjson.avg_ops_per_sec, 1e9 / 2000);
  assert.equal(orjson.runs, 2);
  assert.equal(orjson.mean_fidelity, 1);
  const json = groups.find((g) => g.serializer === 'json');
  assert.equal(json.mode, 'bytes');
  assert.equal(json.avg_ops_per_sec, 100);
  assert.equal(json.runs, 1);
});
