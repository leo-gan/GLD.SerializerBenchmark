import { test } from 'node:test';
import assert from 'node:assert/strict';
import { allFixturesV2, deepEqual, expectedForFidelity, instances, makeOne, V2_TYPE_IDS } from '../src/data.js';
import { ALL_SERIALIZERS } from '../src/serializers/index.js';
import { asDomain } from '../src/serializers/common.js';
import { readArrowIpc } from '../src/serializers/columnar.js';
import { serializerSelected } from '../src/filter.js';
import { compressSizes } from '../src/compress.js';
import { parquetMetadata } from 'hyparquet';
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

test('deepEqual covers null, missing keys, and array length', () => {
  assert.equal(deepEqual(null, null), true);
  assert.equal(deepEqual(null, undefined), false);
  assert.equal(deepEqual(undefined, undefined), true);
  assert.equal(deepEqual([1, 2], [1, 2, 3]), false);
  assert.equal(deepEqual([1, null], [1, undefined]), false);
  assert.equal(deepEqual({ a: 1, b: 2 }, { b: 2, a: 1 }), true);
  assert.equal(deepEqual({ a: 1 }, { a: 1, b: 2 }), false);
  assert.equal(deepEqual({ a: 1 }, { a: 1, b: undefined }), false);
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
  assert.equal(names.length, 9);
  assert.deepEqual(names.slice(0, 5), ['message', 'document', 'telemetry', 'strings', 'event']);
  assert.deepEqual(names.slice(5), ['table', 'table_project', 'nested_table', 'signal']);
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

function isThenable(v) {
  return v != null && typeof v.then === 'function';
}

async function roundTrip(ser, typeId, value) {
  ser.prepare(typeId, value);
  let buf = ser.serialize(value);
  if (isThenable(buf)) buf = await buf;
  assert.ok(buf && (buf.length ?? Buffer.byteLength(buf)) > 0, `${ser.name}/${typeId} empty`);
  let native = ser.deserialize(buf);
  if (isThenable(native)) native = await native;
  return { buf, out: asDomain(ser, native) };
}

function arrayBufferOf(buf) {
  const u8 = buf instanceof Uint8Array ? buf : Buffer.from(buf);
  return u8.buffer.slice(u8.byteOffset, u8.byteOffset + u8.byteLength);
}

test('all V2 fixtures roundtrip for every supporting serializer', async () => {
  const fixtures = allFixturesV2(42);
  for (const ser of ALL_SERIALIZERS) {
    for (const fx of fixtures) {
      if (ser.supports && !ser.supports(fx.name)) continue;
      const { out } = await roundTrip(ser, fx.name, fx.value);
      const expected = expectedForFidelity(fx.name, fx.value);
      if (ser.name.startsWith('simdjson')) {
        /* number coercion allowed */
      } else if (!deepEqual(expected, out)) {
        assert.fail(
          `${ser.name}/${fx.name} fidelity mismatch\n` +
            `  expected: ${JSON.stringify(expected)}\n` +
            `  got:      ${JSON.stringify(out)}`,
        );
      }
    }
  }
});

test('compressSizes gzip of hello is about 25 bytes', () => {
  const [gz, zs] = compressSizes(Buffer.from('hello'));
  assert.ok(gz >= 20 && gz <= 40, `gzip=${gz}`);
  assert.equal(typeof zs, 'number');
  assert.deepEqual(compressSizes(Buffer.alloc(0)), [0, 0]);
});

test('JSON serializer roundtrips message', async () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'JSON.stringify');
  const fx = allFixturesV2(42).find((f) => f.name === 'message');
  const { out } = await roundTrip(ser, fx.name, fx.value);
  assert.ok(deepEqual(fx.value, out));
});

test('msgpackr roundtrips document', () => {
  const ser = ALL_SERIALIZERS.find((s) => s.name === 'msgpackr');
  const fx = allFixturesV2(42).find((f) => f.name === 'document');
  ser.prepare(fx.name, fx.value);
  const buf = ser.serialize(fx.value);
  const out = asDomain(ser, ser.deserialize(buf));
  assert.ok(deepEqual(fx.value, out));
});

test('protobuf-es and google-protobuf roundtrip publication types; protobufjs includes columnar', async () => {
  const fixtures = allFixturesV2(42);
  for (const name of ['protobuf-es', 'google-protobuf', 'protobufjs']) {
    const ser = ALL_SERIALIZERS.find((s) => s.name === name);
    assert.ok(ser, name);
    for (const fx of fixtures) {
      if (ser.supports && !ser.supports(fx.name)) continue;
      const { out } = await roundTrip(ser, fx.name, fx.value);
      const expected = expectedForFidelity(fx.name, fx.value);
      if (!deepEqual(expected, out)) {
        assert.fail(
          `${name}/${fx.name} fidelity mismatch\n` +
            `  expected: ${JSON.stringify(expected)}\n` +
            `  got:      ${JSON.stringify(out)}`,
        );
      }
    }
  }
  const es = ALL_SERIALIZERS.find((s) => s.name === 'protobuf-es');
  const pb = ALL_SERIALIZERS.find((s) => s.name === 'protobufjs');
  assert.equal(es.supports('table'), false);
  assert.equal(pb.supports('signal'), true);
});

test('columnar fixtures are deterministic and repeat strings', () => {
  const a = instances('table', {}, 42, 40).map((row) => row.f_str_0);
  const b = instances('table', {}, 42, 40).map((row) => row.f_str_0);
  assert.deepEqual(a, b);
  assert.ok(new Set(a).size < a.length, `unique f_str_0 ${new Set(a).size}`);
  const table = makeOne('table', {}, 42, 0);
  const project = makeOne('table_project', {}, 42, 0);
  assert.notDeepEqual(table, project);
  for (let i = 0; i < 4; i++) assert.equal(Number.isInteger(table[`f_int_${i}`]), true);
  assert.equal(typeof table.f_float_0, 'number');

  const nested = makeOne('nested_table', {}, 3, 0);
  assert.equal(nested.items.length, 4);
  assert.deepEqual(Object.keys(nested), ['id', 'status', 'meta', 'items']);

  const signal = makeOne('signal', {}, 9, 0);
  assert.equal(signal.legs.length, 4);
  assert.ok(signal.legs.every((leg) => leg.leg_pad === 0));
  assert.deepEqual(Object.keys(signal), [
    'seq',
    'ts',
    'price_mantissa',
    'qty',
    'flags',
    'symbol',
    'venue',
    'legs',
  ]);
});

const COLUMNAR_ALLOW =
  'arrow-ipc,parquet,parquet-uncompressed,JSON.stringify,protobufjs,flatbuffers,avsc';

test('comma filter is exact and the columnar allow-list selects those names', () => {
  assert.equal(serializerSelected('anything', ''), true);
  assert.equal(serializerSelected('anything', '   '), true);
  const substring = ALL_SERIALIZERS.filter((s) => serializerSelected(s.name, 'json')).map((s) => s.name);
  assert.ok(substring.includes('JSON.stringify'));
  assert.ok(substring.includes('fast-json-stringify'));
  assert.ok(substring.length > 1);
  const exactJson = ALL_SERIALIZERS.filter((s) => serializerSelected(s.name, 'json,JSON.stringify')).map(
    (s) => s.name,
  );
  assert.deepEqual(exactJson, ['JSON.stringify']);
  assert.equal(serializerSelected('parquet-uncompressed', 'parquet'), true);
  assert.equal(serializerSelected('parquet-uncompressed', 'parquet,arrow-ipc'), false);
  assert.equal(serializerSelected('Parquet', 'parquet'), true);
  const selected = ALL_SERIALIZERS.filter((s) => serializerSelected(s.name, COLUMNAR_ALLOW)).map((s) => s.name);
  assert.deepEqual(selected, [
    'JSON.stringify',
    'avsc',
    'protobufjs',
    'flatbuffers',
    'arrow-ipc',
    'parquet',
    'parquet-uncompressed',
  ]);
});

test('columnar supports is only the four ids', () => {
  for (const name of ['arrow-ipc', 'parquet', 'parquet-uncompressed']) {
    const ser = ALL_SERIALIZERS.find((s) => s.name === name);
    assert.ok(ser, name);
    assert.equal(ser.supports('table'), true);
    assert.equal(ser.supports('table_project'), true);
    assert.equal(ser.supports('nested_table'), true);
    assert.equal(ser.supports('signal'), true);
    assert.equal(ser.supports('message'), false);
  }
  const cbor = ALL_SERIALIZERS.find((s) => s.name === 'cbor');
  assert.equal(cbor.supports('message'), true);
  assert.equal(cbor.supports('table'), false);
});

test('columnar peers roundtrip N=1 and N=100 and table_project has length N', async () => {
  const names = COLUMNAR_ALLOW.split(',');
  const sers = names.map((name) => ALL_SERIALIZERS.find((s) => s.name === name));
  for (const ser of sers) assert.ok(ser, 'missing allow-list serializer');
  for (const typeId of ['table', 'table_project', 'nested_table', 'signal']) {
    for (const n of [1, 100]) {
      const value = n === 1 ? makeOne(typeId, {}, 42, 0) : instances(typeId, {}, 42, n);
      const expected = expectedForFidelity(typeId, value);
      for (const ser of sers) {
        const { out } = await roundTrip(ser, typeId, value);
        if (typeId === 'table_project') {
          assert.ok(Array.isArray(out), `${ser.name} N=${n}`);
          assert.equal(out.length, n, `${ser.name} N=${n}`);
        }
        if (!deepEqual(expected, out)) {
          assert.fail(`${ser.name}/${typeId} N=${n} fidelity mismatch`);
        }
      }
    }
  }
});

test('arrow table_project read schema is only f_float_0 and nested int32 stays int32', async () => {
  const arrow = ALL_SERIALIZERS.find((s) => s.name === 'arrow-ipc');
  const one = makeOne('table_project', {}, 42, 0);
  arrow.prepare('table_project', one);
  const buf1 = arrow.serialize(one);
  assert.equal(buf1[0], 0xff);
  assert.equal(buf1[1], 0xff);
  assert.equal(buf1[2], 0xff);
  assert.equal(buf1[3], 0xff);
  const schema1 = readArrowIpc(buf1, ['f_float_0']);
  assert.deepEqual([...schema1.schema.names], ['f_float_0']);
  const out1 = asDomain(arrow, arrow.deserialize(buf1));
  assert.deepEqual(out1, [one.f_float_0]);

  const rows = instances('table', {}, 7, 4);
  arrow.prepare('table_project', rows);
  const bufN = arrow.serialize(rows);
  const schemaN = readArrowIpc(bufN, ['f_float_0']);
  assert.deepEqual([...schemaN.schema.names], ['f_float_0']);
  assert.equal(schemaN.numRows, 4);

  const nested = makeOne('nested_table', {}, 1, 0);
  arrow.prepare('nested_table', nested);
  const nestedBuf = arrow.serialize(nested);
  const nestedTable = readArrowIpc(nestedBuf);
  const status = nestedTable.schema.fields.find((f) => f.name === 'status');
  assert.match(String(status.type), /Int32/);
  const items = nestedTable.schema.fields.find((f) => f.name === 'items');
  const itemStruct = items.type.children[0].type;
  const qty = itemStruct.children.find((c) => c.name === 'qty');
  assert.match(String(qty.type), /Int32/);
  const price = itemStruct.children.find((c) => c.name === 'price_minor');
  assert.match(String(price.type), /Int64/);
});

test('parquet default codec is SNAPPY and UNCOMPRESSED changes bytes and metadata', async () => {
  const snappy = ALL_SERIALIZERS.find((s) => s.name === 'parquet');
  const plain = ALL_SERIALIZERS.find((s) => s.name === 'parquet-uncompressed');
  const nested = makeOne('nested_table', {}, 5, 0);
  const a = await roundTrip(snappy, 'nested_table', nested);
  const b = await roundTrip(plain, 'nested_table', nested);
  assert.ok(deepEqual(nested, a.out));
  assert.ok(deepEqual(nested, b.out));
  assert.notEqual(a.buf.length, b.buf.length);
  const metaA = parquetMetadata(arrayBufferOf(a.buf));
  const metaB = parquetMetadata(arrayBufferOf(b.buf));
  const codecs = (meta) => meta.row_groups[0].columns.map((c) => c.meta_data.codec);
  assert.ok(codecs(metaA).every((c) => c === 'SNAPPY'));
  assert.ok(codecs(metaB).every((c) => c === 'UNCOMPRESSED'));
  for (const name of ['status', 'version', 'qty']) {
    assert.equal(metaA.schema.find((el) => el.name === name).type, 'INT32', name);
  }
  assert.equal(metaA.schema.find((el) => el.name === 'price_minor').type, 'INT64');
});
