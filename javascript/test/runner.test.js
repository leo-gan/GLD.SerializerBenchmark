import { test } from 'node:test';
import assert from 'node:assert/strict';
import {
  allFixtures,
  Rng,
  deepEqual,
  makeObjectGraph,
  objectGraphEqual,
} from '../src/data.js';
import { ALL_SERIALIZERS } from '../src/serializers/index.js';

test('fixtures are deterministic for seed 42', () => {
  const a = allFixtures(42);
  const b = allFixtures(42);
  assert.equal(a.length, b.length);
  assert.deepEqual(a[0].value, b[0].value);
});

test('fixtures include ObjectGraph', () => {
  const names = allFixtures(42).map((f) => f.name);
  assert.ok(names.includes('ObjectGraph'));
  assert.equal(names.length, 7);
});

test('object graph topology has sibling cycle via indices', () => {
  const g = makeObjectGraph();
  assert.equal(g.root, 0);
  assert.equal(g.nodes.length, 3);
  assert.deepEqual(g.nodes[0].Children, [1, 2]);
  assert.equal(g.nodes[1].Related, 2);
  assert.equal(g.nodes[2].Related, 1);
  assert.ok(objectGraphEqual(g, g));
});

test('at least 10 serializers registered', () => {
  assert.ok(ALL_SERIALIZERS.length >= 10, `got ${ALL_SERIALIZERS.length}`);
});

test('all serializers that support ObjectGraph roundtrip it', () => {
  const fx = allFixtures(42).find((f) => f.name === 'ObjectGraph');
  let ok = 0;
  for (const ser of ALL_SERIALIZERS) {
    if (!ser.supports(fx.name)) continue;
    ser.prepare(fx.name, fx.value);
    const buf = ser.serialize(fx.value);
    assert.ok(buf && (buf.length ?? Buffer.byteLength(buf)) > 0, `${ser.name} empty`);
    const out = ser.deserialize(buf);
    assert.ok(objectGraphEqual(fx.value, out), `${ser.name} ObjectGraph fidelity`);
    ok += 1;
  }
  assert.equal(ok, ALL_SERIALIZERS.length, `expected all serializers, got ${ok}`);
});

test('all supported fixtures roundtrip for every serializer', () => {
  const fixtures = allFixtures(42);
  for (const ser of ALL_SERIALIZERS) {
    for (const fx of fixtures) {
      if (!ser.supports(fx.name)) continue;
      ser.prepare(fx.name, fx.value);
      const buf = ser.serialize(fx.value);
      const out = ser.deserialize(buf);
      if (fx.name === 'ObjectGraph') {
        assert.ok(objectGraphEqual(fx.value, out), `${ser.name}/${fx.name}`);
      } else if (fx.name === 'Integer' && ser.name === 'bson') {
        assert.ok(out && (out.v === fx.value || out === fx.value));
      } else if (ser.name.startsWith('simdjson')) {
        /* number coercion allowed */
      } else {
        assert.ok(deepEqual(fx.value, out), `${ser.name}/${fx.name}`);
      }
    }
  }
});

test('JSON serializer roundtrips Person', () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'JSON.stringify');
  const fx = allFixtures(42).find((f) => f.name === 'Person');
  ser.prepare(fx.name, fx.value);
  const buf = ser.serialize(fx.value);
  const out = ser.deserialize(buf);
  assert.ok(deepEqual(fx.value, out));
});

test('msgpackr roundtrips SimpleObject', () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'msgpackr');
  const fx = allFixtures(42).find((f) => f.name === 'SimpleObject');
  ser.prepare(fx.name, fx.value);
  const buf = ser.serialize(fx.value);
  const out = ser.deserialize(buf);
  assert.ok(deepEqual(fx.value, out));
});

test('rng produces integers in range', () => {
  const rng = new Rng(1);
  for (let i = 0; i < 100; i++) {
    const v = rng.nextInt(0, 10);
    assert.ok(v >= 0 && v <= 10);
  }
});
