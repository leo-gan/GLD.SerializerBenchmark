/**
 * P0/P1 additions: protobuf-es, google-protobuf, json-pack (MessagePack), devalue, bebop, sia.
 * flexbuffers lives in schema.js (already registered).
 * Official suite types: message, document, telemetry, strings, event (Data Model v2).
 */
import { createRequire } from 'node:module';
import { create, toBinary, fromBinary } from '@bufbuild/protobuf';
import { stringify as devalueStringify, parse as devalueParse } from 'devalue';
import { BebopView } from 'bebop';
import { Sia } from '@timeleap/sia';
import {
  MessageSchema,
  BatchMessageSchema,
  DocumentSchema,
  BatchDocumentSchema,
  TelemetrySchema,
  BatchTelemetrySchema,
  StringsSchema,
  BatchStringsSchema,
  EventSchema,
  BatchEventSchema,
} from '../generated/js_fixtures_pb.js';
import { pkgVersion, baseSupports, bufToUtf8 } from './common.js';

const require = createRequire(import.meta.url);

/* ---------- google-protobuf (jspb BinaryWriter/Reader — real V2 field numbers) ---------- */
// Wire layout matches schemas/js_fixtures.proto / schemas/v2/protobuf/benchmark_v2.proto.
// Uses google-protobuf runtime BinaryWriter/BinaryReader (same primitives as protoc --js_out stubs).
const { BinaryWriter, BinaryReader } = require('google-protobuf');

let jspbDataName = null;
let jspbIsBatch = false;

function jspbWriteMessage(w, v) {
  w.writeBool(1, Boolean(v.f_bool));
  w.writeInt32(2, v.f_int32 | 0);
  w.writeInt64(3, Number(v.f_int64));
  w.writeDouble(4, Number(v.f_float64));
  w.writeString(5, String(v.f_string ?? ''));
  w.writeBool(6, Boolean(v.f_bool_2));
  w.writeInt32(7, v.f_int32_2 | 0);
  w.writeString(8, String(v.f_string_2 ?? ''));
}

function jspbReadMessage(r) {
  const o = {
    f_bool: false,
    f_int32: 0,
    f_int64: 0,
    f_float64: 0,
    f_string: '',
    f_bool_2: false,
    f_int32_2: 0,
    f_string_2: '',
  };
  while (r.nextField()) {
    if (r.isEndGroup()) break;
    switch (r.getFieldNumber()) {
      case 1: o.f_bool = r.readBool(); break;
      case 2: o.f_int32 = r.readInt32(); break;
      case 3: o.f_int64 = Number(r.readInt64()); break;
      case 4: o.f_float64 = r.readDouble(); break;
      case 5: o.f_string = r.readString(); break;
      case 6: o.f_bool_2 = r.readBool(); break;
      case 7: o.f_int32_2 = r.readInt32(); break;
      case 8: o.f_string_2 = r.readString(); break;
      default: r.skipField();
    }
  }
  return o;
}

/** Length-delimited submessage (wire type 2) via google-protobuf BinaryWriter. */
function jspbWriteNested(w, fieldNo, writeFn) {
  // writeMessage(field, value, writerFn) skips when value is null/undefined.
  w.writeMessage(fieldNo, /* value marker */ 1, (_msg, iw) => {
    writeFn(iw);
  });
}

function jspbWriteDocumentFixed(w, v) {
  w.writeString(1, String(v.id ?? ''));
  w.writeInt32(2, v.status | 0);
  jspbWriteNested(w, 3, (iw) => {
    iw.writeString(1, String(v.meta?.region ?? ''));
    iw.writeInt32(2, (v.meta?.version ?? 0) | 0);
  });
  for (const it of v.items || []) {
    jspbWriteNested(w, 4, (iw) => {
      iw.writeString(1, String(it.sku ?? ''));
      iw.writeInt32(2, it.qty | 0);
      iw.writeInt64(3, Number(it.price_minor));
    });
  }
}

function jspbReadDocument(r) {
  const o = { id: '', status: 0, meta: { region: '', version: 0 }, items: [] };
  while (r.nextField()) {
    if (r.isEndGroup()) break;
    switch (r.getFieldNumber()) {
      case 1: o.id = r.readString(); break;
      case 2: o.status = r.readInt32(); break;
      case 3: {
        const bytes = r.readBytes();
        const ir = new BinaryReader(bytes);
        while (ir.nextField()) {
          if (ir.isEndGroup()) break;
          switch (ir.getFieldNumber()) {
            case 1: o.meta.region = ir.readString(); break;
            case 2: o.meta.version = ir.readInt32(); break;
            default: ir.skipField();
          }
        }
        break;
      }
      case 4: {
        const bytes = r.readBytes();
        const ir = new BinaryReader(bytes);
        const it = { sku: '', qty: 0, price_minor: 0 };
        while (ir.nextField()) {
          if (ir.isEndGroup()) break;
          switch (ir.getFieldNumber()) {
            case 1: it.sku = ir.readString(); break;
            case 2: it.qty = ir.readInt32(); break;
            case 3: it.price_minor = Number(ir.readInt64()); break;
            default: ir.skipField();
          }
        }
        o.items.push(it);
        break;
      }
      default: r.skipField();
    }
  }
  return o;
}

function jspbWriteTelemetry(w, v) {
  w.writeString(1, String(v.source ?? ''));
  w.writeInt64(2, Number(v.ts));
  for (const t of v.tags || []) w.writeString(3, String(t));
  if ((v.values || []).length) w.writePackedDouble(4, (v.values || []).map(Number));
}

function jspbReadTelemetry(r) {
  const o = { source: '', ts: 0, tags: [], values: [] };
  while (r.nextField()) {
    if (r.isEndGroup()) break;
    switch (r.getFieldNumber()) {
      case 1: o.source = r.readString(); break;
      case 2: o.ts = Number(r.readInt64()); break;
      case 3: o.tags.push(r.readString()); break;
      case 4:
        if (r.isDelimited()) o.values.push(...r.readPackedDouble().map(Number));
        else o.values.push(r.readDouble());
        break;
      default: r.skipField();
    }
  }
  return o;
}

function jspbWriteStrings(w, v) {
  for (const s of v.items || []) w.writeString(1, String(s));
}

function jspbReadStrings(r) {
  const o = { items: [] };
  while (r.nextField()) {
    if (r.isEndGroup()) break;
    if (r.getFieldNumber() === 1) o.items.push(r.readString());
    else r.skipField();
  }
  return o;
}

function jspbWriteEvent(w, v) {
  w.writeString(1, String(v.event_id ?? ''));
  w.writeString(2, String(v.event_type ?? ''));
  w.writeInt64(3, Number(v.occurred_at));
  w.writeString(4, String(v.producer ?? ''));
  for (const a of v.attrs || []) {
    jspbWriteNested(w, 5, (iw) => {
      iw.writeString(1, String(a.key ?? ''));
      iw.writeString(2, String(a.value ?? ''));
    });
  }
}

function jspbReadEvent(r) {
  const o = {
    event_id: '',
    event_type: '',
    occurred_at: 0,
    producer: '',
    attrs: [],
  };
  while (r.nextField()) {
    if (r.isEndGroup()) break;
    switch (r.getFieldNumber()) {
      case 1: o.event_id = r.readString(); break;
      case 2: o.event_type = r.readString(); break;
      case 3: o.occurred_at = Number(r.readInt64()); break;
      case 4: o.producer = r.readString(); break;
      case 5: {
        const bytes = r.readBytes();
        const ir = new BinaryReader(bytes);
        const a = { key: '', value: '' };
        while (ir.nextField()) {
          if (ir.isEndGroup()) break;
          switch (ir.getFieldNumber()) {
            case 1: a.key = ir.readString(); break;
            case 2: a.value = ir.readString(); break;
            default: ir.skipField();
          }
        }
        o.attrs.push(a);
        break;
      }
      default: r.skipField();
    }
  }
  return o;
}

function jspbWriteItem(dataName, w, v) {
  switch (dataName) {
    case 'message': return jspbWriteMessage(w, v);
    case 'document': return jspbWriteDocumentFixed(w, v);
    case 'telemetry': return jspbWriteTelemetry(w, v);
    case 'strings': return jspbWriteStrings(w, v);
    case 'event': return jspbWriteEvent(w, v);
    default: throw new Error(`google-protobuf: no mapping for ${dataName}`);
  }
}

function jspbReadItem(dataName, r) {
  switch (dataName) {
    case 'message': return jspbReadMessage(r);
    case 'document': return jspbReadDocument(r);
    case 'telemetry': return jspbReadTelemetry(r);
    case 'strings': return jspbReadStrings(r);
    case 'event': return jspbReadEvent(r);
    default: throw new Error(`google-protobuf: no mapping for ${dataName}`);
  }
}

function jspbEncode(dataName, value) {
  const w = new BinaryWriter();
  if (Array.isArray(value)) {
    for (const item of value) {
      jspbWriteNested(w, 1, (iw) => jspbWriteItem(dataName, iw, item));
    }
  } else {
    jspbWriteItem(dataName, w, value);
  }
  return w.getResultBuffer();
}

function jspbDecode(dataName, bytes, isBatch) {
  const r = new BinaryReader(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes));
  if (isBatch) {
    const items = [];
    while (r.nextField()) {
      if (r.isEndGroup()) break;
      if (r.getFieldNumber() === 1) {
        const nested = r.readBytes();
        items.push(jspbReadItem(dataName, new BinaryReader(nested)));
      } else {
        r.skipField();
      }
    }
    return items;
  }
  return jspbReadItem(dataName, r);
}

export const googleProtobufSer = {
  name: 'google-protobuf',
  version: pkgVersion('google-protobuf'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    jspbDataName = dataName;
    jspbIsBatch = Array.isArray(value);
  },
  serialize(value) {
    // Encode on every timed call. Caching the output bytes in prepare would
    // measure a Buffer copy, not Protocol Buffers encode.
    const u8 = jspbEncode(jspbDataName, value);
    return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    return jspbDecode(jspbDataName, u8, jspbIsBatch);
  },
};

/* ---------- protobuf-es (@bufbuild/protobuf) ---------- */

const esSingleSchema = {
  message: MessageSchema,
  document: DocumentSchema,
  telemetry: TelemetrySchema,
  strings: StringsSchema,
  event: EventSchema,
};

const esBatchSchema = {
  message: BatchMessageSchema,
  document: BatchDocumentSchema,
  telemetry: BatchTelemetrySchema,
  strings: BatchStringsSchema,
  event: BatchEventSchema,
};

let esSchema = null;
let esDataName = null;
let esIsBatch = false;
/** Message built in prepare (untimed); serialize only runs toBinary. */
let esMsg = null;

function toEsItem(dataName, value) {
  if (dataName === 'message') {
    return {
      fBool: Boolean(value.f_bool),
      fInt32: value.f_int32 | 0,
      fInt64: BigInt(Number(value.f_int64)),
      fFloat64: Number(value.f_float64),
      fString: String(value.f_string ?? ''),
      fBool2: Boolean(value.f_bool_2),
      fInt322: value.f_int32_2 | 0,
      fString2: String(value.f_string_2 ?? ''),
    };
  }
  if (dataName === 'document') {
    return {
      id: String(value.id ?? ''),
      status: value.status | 0,
      meta: {
        region: String(value.meta?.region ?? ''),
        version: (value.meta?.version ?? 0) | 0,
      },
      items: (value.items || []).map((it) => ({
        sku: String(it.sku ?? ''),
        qty: it.qty | 0,
        priceMinor: BigInt(Number(it.price_minor)),
      })),
    };
  }
  if (dataName === 'telemetry') {
    return {
      source: String(value.source ?? ''),
      ts: BigInt(Number(value.ts)),
      tags: (value.tags || []).map(String),
      values: (value.values || []).map(Number),
    };
  }
  if (dataName === 'strings') {
    return { items: (value.items || []).map(String) };
  }
  if (dataName === 'event') {
    return {
      eventId: String(value.event_id ?? ''),
      eventType: String(value.event_type ?? ''),
      occurredAt: BigInt(Number(value.occurred_at)),
      producer: String(value.producer ?? ''),
      attrs: (value.attrs || []).map((a) => ({
        key: String(a.key ?? ''),
        value: String(a.value ?? ''),
      })),
    };
  }
  throw new Error(`protobuf-es: no mapping for ${dataName}`);
}

function fromEsItem(dataName, msg) {
  // Prefer field access (toJson drops proto3 defaults like 0 / false).
  if (dataName === 'message') {
    return {
      f_bool: Boolean(msg.fBool),
      f_int32: Number(msg.fInt32),
      f_int64: Number(msg.fInt64),
      f_float64: Number(msg.fFloat64),
      f_string: String(msg.fString ?? ''),
      f_bool_2: Boolean(msg.fBool2),
      f_int32_2: Number(msg.fInt322),
      f_string_2: String(msg.fString2 ?? ''),
    };
  }
  if (dataName === 'document') {
    return {
      id: String(msg.id ?? ''),
      status: Number(msg.status),
      meta: {
        region: String(msg.meta?.region ?? ''),
        version: Number(msg.meta?.version ?? 0),
      },
      items: [...(msg.items ?? [])].map((it) => ({
        sku: String(it.sku ?? ''),
        qty: Number(it.qty),
        price_minor: Number(it.priceMinor),
      })),
    };
  }
  if (dataName === 'telemetry') {
    return {
      source: String(msg.source ?? ''),
      ts: Number(msg.ts),
      tags: [...(msg.tags ?? [])].map(String),
      values: [...(msg.values ?? [])].map(Number),
    };
  }
  if (dataName === 'strings') {
    return { items: [...(msg.items ?? [])].map(String) };
  }
  if (dataName === 'event') {
    return {
      event_id: String(msg.eventId ?? ''),
      event_type: String(msg.eventType ?? ''),
      occurred_at: Number(msg.occurredAt),
      producer: String(msg.producer ?? ''),
      attrs: [...(msg.attrs ?? [])].map((a) => ({
        key: String(a.key ?? ''),
        value: String(a.value ?? ''),
      })),
    };
  }
  return msg;
}

export const protobufEsSer = {
  name: 'protobuf-es',
  version: pkgVersion('@bufbuild/protobuf'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    // Optimal: create() once outside timed path; serialize only toBinary.
    esDataName = dataName;
    esIsBatch = Array.isArray(value);
    esSchema = esIsBatch ? esBatchSchema[dataName] : esSingleSchema[dataName];
    if (!esSchema) throw new Error(`protobuf-es: no schema for ${dataName}`);
    const input = esIsBatch
      ? { items: value.map((v) => toEsItem(dataName, v)) }
      : toEsItem(dataName, value);
    esMsg = create(esSchema, input);
  },
  serialize(_value) {
    const u8 = toBinary(esSchema, esMsg);
    return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    return fromBinary(esSchema, u8);
  },
  toDomain(msg) {
    if (esIsBatch) {
      return [...(msg.items ?? [])].map((it) => fromEsItem(esDataName, it));
    }
    return fromEsItem(esDataName, msg);
  },
};

/* ---------- @jsonjoy.com/json-pack MessagePack (one backend) ---------- */

const { MsgPackEncoder } = require('@jsonjoy.com/json-pack/lib/msgpack/MsgPackEncoder.js');
const { MsgPackDecoder } = require('@jsonjoy.com/json-pack/lib/msgpack/MsgPackDecoder.js');
const jpEnc = new MsgPackEncoder();
const jpDec = new MsgPackDecoder();

export const jsonPackMsgpackSer = {
  name: 'json-pack-msgpack',
  version: pkgVersion('@jsonjoy.com/json-pack'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // Encoder instance reused; return Buffer view of encode output.
    const u8 = jpEnc.encode(value);
    return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    return jpDec.decode(u8);
  },
};

/* ---------- devalue (SvelteKit-style value codec) ---------- */

export const devalueSer = {
  name: 'devalue',
  version: pkgVersion('devalue'),
  category: 'native',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(devalueStringify(value), 'utf8');
  },
  deserialize(buf) {
    return devalueParse(bufToUtf8(buf));
  },
};

/* ---------- bebop: JSON-model over BebopView primitives (no .bop codegen available) ---------- */

const BV_NULL = 0;
const BV_BOOL = 1;
const BV_INT = 2;
const BV_FLOAT = 3;
const BV_STR = 4;
const BV_ARR = 5;
const BV_OBJ = 6;

function bebopWriteAny(view, value) {
  if (value === null || value === undefined) {
    view.writeByte(BV_NULL);
    return;
  }
  switch (typeof value) {
    case 'boolean':
      view.writeByte(BV_BOOL);
      view.writeByte(value ? 1 : 0);
      return;
    case 'number':
      if (Number.isInteger(value) && value >= -2147483648 && value <= 2147483647) {
        view.writeByte(BV_INT);
        view.writeInt32(value);
      } else {
        view.writeByte(BV_FLOAT);
        view.writeFloat64(value);
      }
      return;
    case 'string':
      view.writeByte(BV_STR);
      view.writeString(value);
      return;
    case 'object':
      if (Array.isArray(value)) {
        view.writeByte(BV_ARR);
        view.writeUint32(value.length);
        for (const it of value) bebopWriteAny(view, it);
      } else {
        const keys = Object.keys(value);
        view.writeByte(BV_OBJ);
        view.writeUint32(keys.length);
        for (const k of keys) {
          view.writeString(k);
          bebopWriteAny(view, value[k]);
        }
      }
      return;
    default:
      view.writeByte(BV_STR);
      view.writeString(String(value));
  }
}

function bebopReadAny(view) {
  const t = view.readByte();
  switch (t) {
    case BV_NULL:
      return null;
    case BV_BOOL:
      return view.readByte() !== 0;
    case BV_INT:
      return view.readInt32();
    case BV_FLOAT:
      return view.readFloat64();
    case BV_STR:
      return view.readString();
    case BV_ARR: {
      const n = view.readUint32();
      const a = new Array(n);
      for (let i = 0; i < n; i++) a[i] = bebopReadAny(view);
      return a;
    }
    case BV_OBJ: {
      const n = view.readUint32();
      const o = {};
      for (let i = 0; i < n; i++) {
        const k = view.readString();
        o[k] = bebopReadAny(view);
      }
      return o;
    }
    default:
      throw new Error(`bebop: unknown type tag ${t}`);
  }
}

export const bebopSer = {
  name: 'bebop',
  version: pkgVersion('bebop'),
  category: 'schema',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // BebopView.getInstance() is the documented reuse path (singleton writer).
    const view = BebopView.getInstance();
    view.startWriting();
    bebopWriteAny(view, value);
    const arr = view.toArray();
    return Buffer.from(arr.buffer, arr.byteOffset, arr.byteLength);
  },
  deserialize(buf) {
    const view = BebopView.getInstance();
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    view.startReading(u8);
    return bebopReadAny(view);
  },
};

/* ---------- sia (@timeleap/sia): JSON-model over Sia primitives ---------- */

const SIA_NULL = 0;
const SIA_BOOL = 1;
const SIA_INT = 2;
const SIA_FLOAT = 3;
const SIA_STR = 4;
const SIA_ARR = 5;
const SIA_OBJ = 6;

const _f64 = new Float64Array(1);
const _u32 = new Uint32Array(_f64.buffer);

function siaWriteAny(sia, value) {
  if (value === null || value === undefined) {
    sia.addUInt8(SIA_NULL);
    return;
  }
  switch (typeof value) {
    case 'boolean':
      sia.addUInt8(SIA_BOOL).addBool(value);
      return;
    case 'number':
      if (Number.isInteger(value) && value >= -2147483648 && value <= 2147483647) {
        sia.addUInt8(SIA_INT).addInt32(value);
      } else {
        _f64[0] = value;
        sia.addUInt8(SIA_FLOAT).addUInt32(_u32[0]).addUInt32(_u32[1]);
      }
      return;
    case 'string': {
      // length-prefix width by size
      const len = Buffer.byteLength(value, 'utf8');
      sia.addUInt8(SIA_STR);
      if (len < 256) sia.addString8(value);
      else if (len < 65536) sia.addString16(value);
      else sia.addString32(value);
      return;
    }
    case 'object':
      if (Array.isArray(value)) {
        sia.addUInt8(SIA_ARR).addUInt32(value.length);
        for (const it of value) siaWriteAny(sia, it);
      } else {
        const keys = Object.keys(value);
        sia.addUInt8(SIA_OBJ).addUInt32(keys.length);
        for (const k of keys) {
          const kl = Buffer.byteLength(k, 'utf8');
          if (kl < 256) sia.addString8(k);
          else sia.addString16(k);
          siaWriteAny(sia, value[k]);
        }
      }
      return;
    default:
      sia.addUInt8(SIA_STR).addString8(String(value));
  }
}

function siaReadString(sia) {
  // Peek is unavailable; we encoded with width chosen by length. Reader must use same rule
  // but we don't know length — store with fixed string32 for objects keys/values for simplicity.
  // Actually for STR tag we need fixed width. Re-encode strings always as string32 for roundtrip.
  return sia.readString32();
}

// Simpler: always use string32 for strings to make read unambiguous
function siaWriteAnyFixed(sia, value) {
  if (value === null || value === undefined) {
    sia.addUInt8(SIA_NULL);
    return;
  }
  switch (typeof value) {
    case 'boolean':
      sia.addUInt8(SIA_BOOL).addBool(value);
      return;
    case 'number':
      if (Number.isInteger(value) && value >= -2147483648 && value <= 2147483647) {
        sia.addUInt8(SIA_INT).addInt32(value);
      } else {
        _f64[0] = value;
        sia.addUInt8(SIA_FLOAT).addUInt32(_u32[0]).addUInt32(_u32[1]);
      }
      return;
    case 'string':
      sia.addUInt8(SIA_STR).addString32(value);
      return;
    case 'object':
      if (Array.isArray(value)) {
        sia.addUInt8(SIA_ARR).addUInt32(value.length);
        for (const it of value) siaWriteAnyFixed(sia, it);
      } else {
        const keys = Object.keys(value);
        sia.addUInt8(SIA_OBJ).addUInt32(keys.length);
        for (const k of keys) {
          sia.addString32(k);
          siaWriteAnyFixed(sia, value[k]);
        }
      }
      return;
    default:
      sia.addUInt8(SIA_STR).addString32(String(value));
  }
}

function siaReadAny(sia) {
  const t = sia.readUInt8();
  switch (t) {
    case SIA_NULL:
      return null;
    case SIA_BOOL:
      return sia.readBool();
    case SIA_INT:
      return sia.readInt32();
    case SIA_FLOAT: {
      _u32[0] = sia.readUInt32();
      _u32[1] = sia.readUInt32();
      return _f64[0];
    }
    case SIA_STR:
      return sia.readString32();
    case SIA_ARR: {
      const n = sia.readUInt32();
      const a = new Array(n);
      for (let i = 0; i < n; i++) a[i] = siaReadAny(sia);
      return a;
    }
    case SIA_OBJ: {
      const n = sia.readUInt32();
      const o = {};
      for (let i = 0; i < n; i++) {
        const k = sia.readString32();
        o[k] = siaReadAny(sia);
      }
      return o;
    }
    default:
      throw new Error(`sia: unknown type tag ${t}`);
  }
}

// Reuse one writer buffer; Sia preallocates large content — slice to offset
const siaWriter = new Sia();
const siaReader = new Sia();

export const siaSer = {
  name: 'sia',
  version: pkgVersion('@timeleap/sia'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // Reuse writer buffer; only reset offset once.
    siaWriter.offset = 0;
    siaWriteAnyFixed(siaWriter, value);
    return Buffer.from(siaWriter.content.subarray(0, siaWriter.offset));
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    if (siaReader.content.length < u8.length) {
      siaReader.content = new Uint8Array(Math.max(u8.length, 65536));
      siaReader.dataView = new DataView(
        siaReader.content.buffer,
        siaReader.content.byteOffset,
        siaReader.content.byteLength,
      );
    }
    siaReader.content.set(u8, 0);
    siaReader.offset = 0;
    return siaReadAny(siaReader);
  },
};

export function modernSerializers() {
  return [protobufEsSer, googleProtobufSer, jsonPackMsgpackSer, devalueSer, bebopSer, siaSer];
}
