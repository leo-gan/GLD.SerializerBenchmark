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
// C# bytes mode stores the Base64 text length of that wire payload.
const CSHARP = {
  tensor: 5592424,
  tensor_view: 5592424,
  prompt: 32796,
  shard: 2448080,
  request: 32832,
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
    const payload = loadJsonGz(`${lang}_latest.json.gz`);
    const fromStats = stats.groups.filter((g) => g.serializer === 'gld-kiln');
    const fromPayload = payload.stats.groups.filter((g) => g.serializer === 'gld-kiln');
    assert.equal(fromStats.length, 15, lang);
    assert.equal(fromPayload.length, fromStats.length, lang);
    assert.equal(stats.kiln_splice.serializer, 'gld-kiln', lang);
    assert.match(stats.kiln_splice.note, /were not recomputed/);
    const cells = new Set(
      fromStats.map((g) => `${g.data_set}:${baseType(g.test_data)}@${g.data_type_instance_count}`),
    );
    for (const typeId of SUITE) {
      assert.ok(cells.has(`suite:${typeId}@1`), `${lang} ${typeId} n=1`);
      assert.ok(cells.has(`suite:${typeId}@100`), `${lang} ${typeId} n=100`);
    }
    const sizes = lang === 'csharp' ? CSHARP : WIRE;
    for (const typeId of TENSOR) {
      assert.ok(cells.has(`tensor:${typeId}@1`), `${lang} ${typeId}`);
      const group = fromStats.find(
        (g) => baseType(g.test_data) === typeId && g.data_type_instance_count === 1,
      );
      assert.equal(group.standard, 'kiln', lang);
      assert.equal(group.serializer_version, '0.2.0', lang);
      const metrics = group.variants.iqr_1_5 || group.variants['iqr_1.5'];
      assert.equal(metrics.mean_fidelity, 1, `${lang} ${typeId}`);
      assert.equal(metrics.median_size_bytes, sizes[typeId], `${lang} ${typeId} size`);
    }
  }
});
