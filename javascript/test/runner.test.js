import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allFixtures, Rng, deepEqual } from '../src/data.js';
import { ALL_SERIALIZERS } from '../src/serializers/index.js';

test('fixtures are deterministic for seed 42', () => {
  const a = allFixtures(42);
  const b = allFixtures(42);
  assert.equal(a.length, b.length);
  assert.deepEqual(a[0].value, b[0].value);
});

test('at least 10 serializers registered', () => {
  assert.ok(ALL_SERIALIZERS.length >= 10, `got ${ALL_SERIALIZERS.length}`);
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
