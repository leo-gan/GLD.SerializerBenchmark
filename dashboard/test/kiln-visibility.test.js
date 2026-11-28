import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { gunzipSync } from 'node:zlib';

const dataDir = join(dirname(fileURLToPath(import.meta.url)), '..', 'public', 'data');
const LANGS = [
  'python', 'rust', 'c', 'cpp', 'javascript', 'go', 'java', 'swift', 'zig', 'csharp',
];
const SUITE = ['message', 'document', 'telemetry', 'strings', 'event'];
const TENSOR = ['tensor', 'tensor_view', 'prompt', 'shard', 'request'];
const WIRE = {
  tensor: 4194316,
  tensor_view: 4194316,
  prompt: 24596,
  shard: 1836060,
  request: 24623,
};
// Timed gld-kiln release on the published snapshot. Rust and the Mojo row
// stay on 0.2.0. Compliance for these ports is still scored with 0.2.0.
const KILN_VERSION = {
  python: '0.2.2',
  rust: '0.2.0',
  c: '0.2.1',
  cpp: '0.2.1',
  javascript: '0.2.1',
  go: '0.2.1',
  java: '0.2.1',
  swift: '0.2.1',
  zig: '0.2.1',
  csharp: '0.2.1',
};


function loadJsonGz(name) {
  const buf = readFileSync(join(dataDir, name));
  const raw = buf[0] === 0x1f && buf[1] === 0x8b ? gunzipSync(buf) : buf;
  return JSON.parse(raw.toString('utf8'));
}

function baseType(testData) {
  const raw = String(testData || '');
  const cut = raw.indexOf('@n=');
  return cut >= 0 ? raw.slice(0, cut) : raw;
}

test('published snapshots include gld-kiln on suite and tensor', () => {
  for (const lang of LANGS) {
    const stats = loadJsonGz(`stats_${lang}_latest.json.gz`);
    const fromStats = stats.groups.filter((g) => g.serializer === 'gld-kiln');
    assert.equal(fromStats.length, 15, lang);
    if (stats.kiln_splice) {
      assert.equal(stats.kiln_splice.serializer, 'gld-kiln', lang);
      assert.match(stats.kiln_splice.note, /were not recomputed/);
    }
    const cells = new Set(
      fromStats.map((g) => `${g.data_set}:${baseType(g.test_data)}@${g.data_type_instance_count}`),
    );
    for (const typeId of SUITE) {
      assert.ok(cells.has(`suite:${typeId}@1`), `${lang} ${typeId} n=1`);
      assert.ok(cells.has(`suite:${typeId}@100`), `${lang} ${typeId} n=100`);
    }
    const sizes = WIRE;
    for (const typeId of TENSOR) {
      assert.ok(cells.has(`tensor:${typeId}@1`), `${lang} ${typeId}`);
      const group = fromStats.find(
        (g) => baseType(g.test_data) === typeId && g.data_type_instance_count === 1,
      );
      assert.equal(group.standard, 'kiln', lang);
      assert.equal(group.serializer_version, KILN_VERSION[lang], lang);
      const metrics = group.variants.iqr_1_5 || group.variants['iqr_1.5'];
      assert.equal(metrics.mean_fidelity, 1, `${lang} ${typeId}`);
      assert.equal(metrics.median_size_bytes, sizes[typeId], `${lang} ${typeId} size`);
    }
  }
});

// gld-kiln-asm 0.2.0 membership from config/benchmark_config.yaml serializer_data_sets.
const ASM_SETS = {
  c: ['suite', 'columnar', 'array', 'tensor'],
  cpp: ['suite', 'columnar', 'array', 'tensor'],
  csharp: ['suite', 'columnar', 'array', 'tensor'],
  fortran: ['suite', 'array'],
  go: ['suite', 'columnar', 'tensor'],
  java: ['suite', 'columnar', 'tensor'],
  javascript: ['suite', 'columnar', 'array', 'tensor'],
  kotlin: ['suite', 'columnar'],
  mojo: ['suite', 'columnar', 'array', 'tensor'],
  python: ['suite', 'columnar', 'array', 'tensor'],
  rust: ['suite', 'columnar', 'array', 'tensor'],
  swift: ['suite', 'tensor'],
  zig: ['suite', 'tensor'],
};
const ASM_CELLS = {
  suite: SUITE.flatMap((typeId) => [1, 100].map((n) => `${typeId}@${n}`)),
  columnar: ['table', 'table_project'].flatMap((typeId) => [1, 100, 10000].map((n) => `${typeId}@${n}`))
    .concat(['nested_table', 'signal'].flatMap((typeId) => [1, 100].map((n) => `${typeId}@${n}`))),
  array: ['grid@1', 'grid_window@1'],
  tensor: TENSOR.map((typeId) => `${typeId}@1`),
};

test('published snapshots include gld-kiln-asm 0.2.0 on its data sets', () => {
  for (const [lang, sets] of Object.entries(ASM_SETS)) {
    const stats = loadJsonGz(`stats_${lang}_latest.json.gz`);
    const groups = stats.groups.filter((g) => g.serializer === 'gld-kiln-asm');
    const cells = new Set(groups.map((g) => `${g.data_set}:${baseType(g.test_data)}@${g.data_type_instance_count}`));
    const want = new Set(sets.flatMap((set) => ASM_CELLS[set].map((cell) => `${set}:${cell}`)));
    assert.deepEqual(cells, want, lang);
    for (const group of groups) {
      assert.equal(group.standard, 'kiln', lang);
      assert.equal(group.serializer_version, '0.2.0', lang);
      for (const metrics of Object.values(group.variants)) {
        assert.equal(metrics.mean_fidelity, 1, `${lang} ${group.test_data}`);
        assert.equal(metrics.runs_raw, 100, `${lang} ${group.test_data}`);
      }
    }
    if (sets.includes('tensor')) {
      for (const typeId of ['tensor', 'tensor_view']) {
        const group = groups.find((g) => baseType(g.test_data) === typeId);
        const metrics = group.variants.iqr_1_5 || group.variants['iqr_1.5'];
        assert.equal(metrics.median_size_bytes, 4194496, `${lang} ${typeId}`);
      }
    }
  }
});
