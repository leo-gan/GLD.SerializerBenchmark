import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { gunzipSync } from 'node:zlib';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawnSync } from 'node:child_process';
import { FOLD_FILE_ONLY, FOLD_OPT_IN, foldIoGroups } from '../fold-io.js';

const here = dirname(fileURLToPath(import.meta.url));
const repo = join(here, '..', '..');

const DIMS = {
  optIn: [
    { language: 'go', serializer: 'sonic', level: 'stream' },
    { language: 'csharp', serializer: 'MemoryPack', level: 'string' },
    { language: 'csharp', serializer: 'ShapeShift.Json', level: 'stream' },
  ],
  base64Ratio: 0.75,
  base64Tolerance: 0.05,
  fileOnly: [],
};

function group(lang, ser, mode, median, size, streamMode = '') {
  const row = {
    language: lang,
    serializer: ser,
    test_data: 'message',
    type_config_hash: 'abc',
    data_type_instance_count: 100,
    mode,
    standard: 'json',
    data_set: 'suite',
    variants: {
      iqr_1_5: {
        total_median_ns: median,
        total_mean_ns: median,
        avg_time_total_ns: median,
        median_size_bytes: size,
        runs: 99,
        filter: { policy: 'iqr_1.5' },
      },
    },
  };
  if (streamMode) row.StreamMode = streamMode;
  return row;
}

function cellKey(row) {
  return [
    row.language,
    row.serializer,
    row.test_data,
    row.data_type_instance_count,
    row.type_config_hash,
  ].join('\0');
}

test('same-size opt-in averages both levels and keeps them as children', () => {
  const folded = foldIoGroups([
    group('go', 'sonic', 'bytes', 100, 40),
    group('go', 'sonic', 'stream', 140, 40, 'native'),
  ], DIMS);
  assert.equal(folded.length, 1);
  const parent = folded[0];
  assert.equal(parent.io_parent, 'average');
  assert.equal(parent.mode, 'published');
  assert.equal(parent.variants.iqr_1_5.total_median_ns, 120);
  assert.equal(parent.variants.iqr_1_5.median_size_bytes, 40);
  assert.deepEqual(parent.optional.map((child) => child.level), ['bytes', 'stream']);
  assert.equal(parent.optional[1].variants.iqr_1_5.total_median_ns, 140);
});

test('C# Base64 opt-in keeps the raw-byte parent and the string child', () => {
  const parent = foldIoGroups([
    group('csharp', 'MemoryPack', 'string', 40, 80),
    group('csharp', 'MemoryPack', 'stream', 26, 60, 'native'),
  ], DIMS)[0];
  assert.equal(parent.io_parent, 'raw_bytes');
  assert.equal(parent.variants.iqr_1_5.total_median_ns, 26);
  assert.equal(parent.variants.iqr_1_5.median_size_bytes, 60);
  assert.equal(parent.optional.length, 1);
  assert.equal(parent.optional[0].level, 'string');
  assert.equal(parent.optional[0].variants.iqr_1_5.median_size_bytes, 80);
});

test('a serializer outside the opt-in list keeps only the in-memory row', () => {
  const parent = foldIoGroups([
    group('python', 'orjson', 'bytes', 10, 20),
    group('python', 'orjson', 'stream', 10.2, 20, 'adapted'),
  ], DIMS)[0];
  assert.equal(parent.io_parent, 'in_memory');
  assert.deepEqual(parent.optional, []);
  assert.equal(parent.variants.iqr_1_5.total_median_ns, 10);
});

test('C# Base64 outside the opt-in list has no child', () => {
  const parent = foldIoGroups([
    group('csharp', 'FsPickler', 'string', 50, 80),
    group('csharp', 'FsPickler', 'stream', 48, 60, 'native'),
  ], DIMS)[0];
  assert.equal(parent.io_parent, 'raw_bytes');
  assert.equal(parent.variants.iqr_1_5.total_median_ns, 48);
  assert.deepEqual(parent.optional, []);
});

test('a single level stays one row', () => {
  const parent = foldIoGroups([
    group('javascript', 'JSON.stringify', 'bytes', 5, 12),
  ], DIMS)[0];
  assert.equal(parent.io_parent, 'single');
  assert.deepEqual(parent.optional, []);
  assert.equal(parent.variants.iqr_1_5.total_median_ns, 5);
});

test('a file-only stream row is the parent', () => {
  const parent = foldIoGroups([
    group('fortran', 'adios2', 'stream', 30, 128, 'native'),
  ], { ...DIMS, fileOnly: [{ language: 'fortran', serializer: 'adios2' }] })[0];
  assert.equal(parent.io_parent, 'file');
  assert.equal(parent.mode, 'published');
  assert.deepEqual(parent.optional, []);
  assert.equal(parent.variants.iqr_1_5.median_size_bytes, 128);
  assert.equal(parent.StreamMode, 'native');
});

test('an unlisted stream-only row is dropped', () => {
  const folded = foldIoGroups([
    group('python', 'orjson', 'bytes', 10, 20),
    group('fortran', 'custom-binary', 'stream', 4, 40, 'native'),
  ], DIMS);
  assert.equal(folded.length, 1);
  assert.equal(folded[0].serializer, 'orjson');
  assert.equal(folded[0].io_parent, 'single');
});

test('an already published parent keeps its children', () => {
  const published = {
    language: 'csharp',
    serializer: 'FlatSharp',
    test_data: 'table',
    type_config_hash: 'abc',
    data_type_instance_count: 1,
    mode: 'published',
    io_parent: 'raw_bytes',
    optional: [{ level: 'string', mode: 'string', variants: { iqr_1_5: { total_median_ns: 9 } } }],
    variants: { iqr_1_5: { total_median_ns: 4, median_size_bytes: 20 } },
  };
  const folded = foldIoGroups([published], DIMS);
  assert.equal(folded.length, 1);
  assert.equal(folded[0], published);
  assert.equal(folded[0].optional[0].level, 'string');
  assert.equal(folded[0].variants.iqr_1_5.total_median_ns, 4);
});

test('opt-in and file-only lists match the dimension contract', () => {
  const yaml = readFileSync(join(repo, 'config', 'dimensions.yaml'), 'utf8');
  const entries = [];
  let inOpt = false;
  for (const line of yaml.split('\n')) {
    if (/^  opt_in:/.test(line)) {
      inOpt = true;
      continue;
    }
    if (!inOpt) continue;
    if (/^  [a-z_]+:/.test(line)) break;
    const match = line.match(/language:\s*([^,\s]+),\s*serializer:\s*(?:"([^"]+)"|([^,}]+)),\s*level:\s*([a-z_]+)/);
    if (!match) continue;
    entries.push({
      language: match[1],
      serializer: (match[2] || match[3]).trim(),
      level: match[4],
    });
  }
  const key = (row) => `${row.language}\0${row.serializer}\0${row.level}`;
  assert.deepEqual(FOLD_OPT_IN.map(key).sort(), entries.map(key).sort());

  const fileOnly = [];
  for (const raw of readFileSync(join(repo, 'config', 'file-only.txt'), 'utf8').split('\n')) {
    const line = raw.split('#')[0].trim();
    if (!line) continue;
    const [language, ...rest] = line.split(/\s+/);
    fileOnly.push(`${language}\0${rest.join(' ')}`);
  }
  assert.deepEqual(
    FOLD_FILE_ONLY.map((row) => `${row.language}\0${row.serializer}`).sort(),
    fileOnly.sort(),
  );
});

test('published C# suite rows collapse to one parent and match analysis', () => {
  const stats = JSON.parse(gunzipSync(readFileSync(
    join(here, '..', 'public', 'data', 'stats_csharp_latest.json.gz'),
  )));
  const folded = foldIoGroups(stats.groups);
  const seen = new Set();
  for (const row of folded) {
    const key = cellKey(row);
    assert.equal(seen.has(key), false, key);
    seen.add(key);
  }

  const message = folded.filter((row) => row.test_data === 'message' && row.data_type_instance_count === 1);
  const names = message.map((row) => row.serializer);
  assert.equal(new Set(names).size, names.length);
  assert.ok(names.length > 10);

  const avro = message.find((row) => row.serializer === 'Apache.Avro');
  const avroStream = stats.groups.find((row) => (
    row.serializer === 'Apache.Avro'
    && row.test_data === 'message'
    && row.data_type_instance_count === 1
    && String(row.mode).toLowerCase() === 'stream'
  ));
  assert.equal(avro.io_parent, 'raw_bytes');
  assert.deepEqual(avro.optional, []);
  assert.equal(avro.variants['iqr_1.5'].median_size_bytes, avroStream.variants['iqr_1.5'].median_size_bytes);
  assert.equal(avro.variants['iqr_1.5'].total_median_ns, avroStream.variants['iqr_1.5'].total_median_ns);

  const pack = message.find((row) => row.serializer === 'BinaryPack');
  assert.equal(pack.io_parent, 'raw_bytes');
  assert.deepEqual(pack.optional.map((child) => child.level), ['string']);

  const kept = stats.groups.find((row) => (
    row.serializer === 'FlatSharp'
    && row.test_data === 'nested_table'
    && row.data_type_instance_count === 1
  ));
  const keptFolded = folded.find((row) => (
    row.serializer === 'FlatSharp'
    && row.test_data === 'nested_table'
    && row.data_type_instance_count === 1
  ));
  assert.equal(keptFolded, kept);
  assert.equal(keptFolded.optional[0].level, 'string');

  const counts = new Map();
  for (const row of stats.groups) {
    const key = cellKey(row);
    counts.set(key, (counts.get(key) || 0) + 1);
  }
  const peers = stats.groups.filter((row) => counts.get(cellKey(row)) > 1);
  const py = spawnSync('python3', ['-c', `
import json, sys
sys.path.insert(0, "analysis/src")
from benchmark_analysis.fold_io import fold_io_groups
groups = json.load(sys.stdin)
out = []
for group in fold_io_groups(groups):
    metrics = (group.get("variants") or {}).get("iqr_1.5") or {}
    out.append({
        "serializer": group.get("serializer"),
        "test_data": group.get("test_data"),
        "n": group.get("data_type_instance_count"),
        "hash": group.get("type_config_hash"),
        "io_parent": group.get("io_parent"),
        "levels": [child.get("level") for child in group.get("optional") or []],
        "median": metrics.get("total_median_ns"),
        "size": metrics.get("median_size_bytes"),
    })
json.dump(out, sys.stdout)
`], {
    cwd: repo,
    input: JSON.stringify(peers),
    encoding: 'utf8',
  });
  assert.equal(py.status, 0, py.stderr);
  const expected = JSON.parse(py.stdout);
  const actualByKey = new Map();
  for (const row of foldIoGroups(peers)) {
    const metrics = (row.variants || {})['iqr_1.5'] || {};
    actualByKey.set([row.serializer, row.test_data, row.data_type_instance_count, row.type_config_hash].join('\0'), {
      serializer: row.serializer,
      test_data: row.test_data,
      n: row.data_type_instance_count,
      hash: row.type_config_hash,
      io_parent: row.io_parent,
      levels: (row.optional || []).map((child) => child.level),
      median: metrics.total_median_ns,
      size: metrics.median_size_bytes,
    });
  }
  assert.equal(actualByKey.size, expected.length);
  for (const row of expected) {
    const key = [row.serializer, row.test_data, row.n, row.hash].join('\0');
    const actual = actualByKey.get([row.serializer, row.test_data, row.n, row.hash].join('\0'));
    assert.ok(actual, key);
    assert.equal(actual.io_parent, row.io_parent, key);
    assert.deepEqual(actual.levels, row.levels, key);
    assert.equal(actual.median, row.median, key);
    assert.equal(actual.size, row.size, key);
  }
});
