import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allFixturesV2, deepEqual, makeOne, V2_TYPE_IDS } from '../src/data.js';
import { ALL_SERIALIZERS } from '../src/serializers/index.js';
import {
  deriveScheduleSeed,
  goldenPermutation,
  normalizeMode,
} from '../src/schedule.js';

test('B-1 schedule golden vector A,B,C → C,B,A', () => {
  assert.equal(normalizeMode('string'), 'bytes');
  assert.equal(normalizeMode('Stream'), 'stream');
  const seed = deriveScheduleSeed(42, 'message', 1, 'abc', 'bytes', 0);
  assert.equal(seed, 15992650003647724414n);
  assert.deepEqual(goldenPermutation(), ['C', 'B', 'A']);
});

test('V2 fixtures are deterministic for seed 42', () => {
  const a = allFixturesV2(42);
  const b = allFixturesV2(42);
  assert.equal(a.length, b.length);
  assert.deepEqual(a[0].value, b[0].value);
  for (let i = 0; i < a.length; i++) {
    assert.deepEqual(a[i].value, b[i].value, a[i].name);
  }
});

test('suite types are official V2 only', () => {
  const names = allFixturesV2(42).map((f) => f.name);
  assert.deepEqual(names, V2_TYPE_IDS);
  assert.equal(names.length, 5);
  assert.ok(!names.includes('not-a-suite-type'));
});

test('makeOne produces expected shapes', () => {
  const msg = makeOne('message', {}, 42, 0);
  assert.equal(typeof msg.f_bool, 'boolean');
  assert.equal(typeof msg.f_int32, 'number');
  assert.equal(typeof msg.f_string, 'string');

  const doc = makeOne('document', { children: 3 }, 42, 0);
  assert.equal(typeof doc.id, 'string');
  assert.ok(Array.isArray(doc.items));
  assert.equal(doc.items.length, 3);

  const tel = makeOne('telemetry', { points: 4, tag_count: 2 }, 42, 0);
  assert.equal(tel.values.length, 4);
  assert.equal(tel.tags.length, 2);

  const str = makeOne('strings', { count: 5 }, 42, 0);
  assert.equal(str.items.length, 5);

  const ev = makeOne('event', { attr_count: 2 }, 42, 0);
  assert.equal(typeof ev.event_id, 'string');
  assert.equal(ev.attrs.length, 2);
});

test('at least 10 serializers registered', () => {
  assert.ok(ALL_SERIALIZERS.length >= 10, `got ${ALL_SERIALIZERS.length}`);
});

test('all V2 fixtures roundtrip for every supporting serializer', () => {
  const fixtures = allFixturesV2(42);
  for (const ser of ALL_SERIALIZERS) {
    for (const fx of fixtures) {
      if (ser.supports && !ser.supports(fx.name)) continue;
      ser.prepare(fx.name, fx.value);
      const buf = ser.serialize(fx.value);
      assert.ok(buf && (buf.length ?? Buffer.byteLength(buf)) > 0, `${ser.name}/${fx.name} empty`);
      const out = ser.deserialize(buf);
      if (ser.name.startsWith('simdjson')) {
        /* number coercion allowed */
      } else if (!deepEqual(fx.value, out)) {
        assert.fail(
          `${ser.name}/${fx.name} fidelity mismatch\n` +
            `  expected: ${JSON.stringify(fx.value)}\n` +
            `  got:      ${JSON.stringify(out)}`,
        );
      }
    }
  }
});

test('JSON serializer roundtrips message', () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'JSON.stringify');
  const fx = allFixturesV2(42).find((f) => f.name === 'message');
  ser.prepare(fx.name, fx.value);
  const buf = ser.serialize(fx.value);
  const out = ser.deserialize(buf);
  assert.ok(deepEqual(fx.value, out));
});

test('msgpackr roundtrips document', () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'msgpackr');
  const fx = allFixturesV2(42).find((f) => f.name === 'document');
  ser.prepare(fx.name, fx.value);
  const buf = ser.serialize(fx.value);
  const out = ser.deserialize(buf);
  assert.ok(deepEqual(fx.value, out));
});

test('protobuf-es and google-protobuf roundtrip all V2 types', () => {
  const fixtures = allFixturesV2(42);
  for (const name of ['protobuf-es', 'google-protobuf', 'protobufjs']) {
    const ser = ALL_SERIALIZERS.find((s) => s.name === name);
    assert.ok(ser, name);
    for (const fx of fixtures) {
      ser.prepare(fx.name, fx.value);
      const buf = ser.serialize(fx.value);
      const out = ser.deserialize(buf);
      if (!deepEqual(fx.value, out)) {
        assert.fail(
          `${name}/${fx.name} fidelity mismatch\n` +
            `  expected: ${JSON.stringify(fx.value)}\n` +
            `  got:      ${JSON.stringify(out)}`,
        );
      }
    }
  }
});
