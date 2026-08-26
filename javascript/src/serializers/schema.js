import avro from 'avsc';
import protobuf from 'protobufjs';
import * as flatbuffers from 'flatbuffers';
import { encode as flexEncode, toObject as flexToObject } from 'flatbuffers/mjs/flexbuffers.js';
import { pkgVersion, baseSupports, jsonClone } from './common.js';

/* ---------- Avro schemas for official V2 types (doubles must be explicit) ---------- */

const avroSchemas = {
  message: {
    type: 'record',
    name: 'MessageV2',
    fields: [
      { name: 'f_bool', type: 'boolean' },
      { name: 'f_int32', type: 'int' },
      { name: 'f_int64', type: 'long' },
      { name: 'f_float64', type: 'double' },
      { name: 'f_string', type: 'string' },
      { name: 'f_bool_2', type: 'boolean' },
      { name: 'f_int32_2', type: 'int' },
      { name: 'f_string_2', type: 'string' },
    ],
  },
  document: {
    type: 'record',
    name: 'DocumentV2',
    fields: [
      { name: 'id', type: 'string' },
      { name: 'status', type: 'int' },
      {
        name: 'meta',
        type: {
          type: 'record',
          name: 'DocumentMetaV2',
          fields: [
            { name: 'region', type: 'string' },
            { name: 'version', type: 'int' },
          ],
        },
      },
      {
        name: 'items',
        type: {
          type: 'array',
          items: {
            type: 'record',
            name: 'DocumentItemV2',
            fields: [
              { name: 'sku', type: 'string' },
              { name: 'qty', type: 'int' },
              { name: 'price_minor', type: 'long' },
            ],
          },
        },
      },
    ],
  },
  telemetry: {
    type: 'record',
    name: 'TelemetryV2',
    fields: [
      { name: 'source', type: 'string' },
      { name: 'ts', type: 'long' },
      { name: 'tags', type: { type: 'array', items: 'string' } },
      { name: 'values', type: { type: 'array', items: 'double' } },
    ],
  },
  strings: {
    type: 'record',
    name: 'StringsV2',
    fields: [{ name: 'items', type: { type: 'array', items: 'string' } }],
  },
  event: {
    type: 'record',
    name: 'EventV2',
    fields: [
      { name: 'event_id', type: 'string' },
      { name: 'event_type', type: 'string' },
      { name: 'occurred_at', type: 'long' },
      { name: 'producer', type: 'string' },
      {
        name: 'attrs',
        type: {
          type: 'array',
          items: {
            type: 'record',
            name: 'EventAttrV2',
            fields: [
              { name: 'key', type: 'string' },
              { name: 'value', type: 'string' },
            ],
          },
        },
      },
    ],
  },
};

let avroType = null;
let avroPrepared = null;
let avroDataName = null;

function avroPrepareValue(_dataName, value) {
  return jsonClone(value);
}

export const avscSer = {
  name: 'avsc',
  version: pkgVersion('avsc'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    avroDataName = dataName;
    const schema = avroSchemas[dataName];
    let base;
    if (!schema) {
      base = avro.Type.forValue(jsonClone(Array.isArray(value) ? value[0] : value));
    } else {
      base = avro.Type.forSchema(schema);
    }
    // Batch N>1: array of records
    if (Array.isArray(value)) {
      avroType = avro.Type.forSchema({ type: 'array', items: base });
      avroPrepared = value.map((v) => avroPrepareValue(dataName, v));
    } else {
      avroType = base;
      avroPrepared = avroPrepareValue(dataName, value);
    }
  },
  serialize(_value) {
    return avroType.toBuffer(avroPrepared);
  },
  deserialize(buf) {
    // Normalize Avro types (Long/ints) to plain JSON for suite fidelity compare.
    const raw = avroType.fromBuffer(Buffer.from(buf));
    return JSON.parse(JSON.stringify(raw));
  },
};

/* ---------- protobufjs: real V2 messages matching data_v2 field shapes ---------- */

const pbRoot = protobuf.Root.fromJSON({
  nested: {
    Message: {
      fields: {
        f_bool: { type: 'bool', id: 1 },
        f_int32: { type: 'int32', id: 2 },
        f_int64: { type: 'int64', id: 3 },
        f_float64: { type: 'double', id: 4 },
        f_string: { type: 'string', id: 5 },
        f_bool_2: { type: 'bool', id: 6 },
        f_int32_2: { type: 'int32', id: 7 },
        f_string_2: { type: 'string', id: 8 },
      },
    },
    BatchMessage: {
      fields: {
        items: { rule: 'repeated', type: 'Message', id: 1 },
      },
    },
    DocumentMeta: {
      fields: {
        region: { type: 'string', id: 1 },
        version: { type: 'int32', id: 2 },
      },
    },
    DocumentItem: {
      fields: {
        sku: { type: 'string', id: 1 },
        qty: { type: 'int32', id: 2 },
        price_minor: { type: 'int64', id: 3 },
      },
    },
    Document: {
      fields: {
        id: { type: 'string', id: 1 },
        status: { type: 'int32', id: 2 },
        meta: { type: 'DocumentMeta', id: 3 },
        items: { rule: 'repeated', type: 'DocumentItem', id: 4 },
      },
    },
    BatchDocument: {
      fields: {
        items: { rule: 'repeated', type: 'Document', id: 1 },
      },
    },
    Telemetry: {
      fields: {
        source: { type: 'string', id: 1 },
        ts: { type: 'int64', id: 2 },
        tags: { rule: 'repeated', type: 'string', id: 3 },
        values: { rule: 'repeated', type: 'double', id: 4 },
      },
    },
    BatchTelemetry: {
      fields: {
        items: { rule: 'repeated', type: 'Telemetry', id: 1 },
      },
    },
    Strings: {
      fields: {
        items: { rule: 'repeated', type: 'string', id: 1 },
      },
    },
    BatchStrings: {
      fields: {
        items: { rule: 'repeated', type: 'Strings', id: 1 },
      },
    },
    EventAttr: {
      fields: {
        key: { type: 'string', id: 1 },
        value: { type: 'string', id: 2 },
      },
    },
    Event: {
      fields: {
        event_id: { type: 'string', id: 1 },
        event_type: { type: 'string', id: 2 },
        occurred_at: { type: 'int64', id: 3 },
        producer: { type: 'string', id: 4 },
        attrs: { rule: 'repeated', type: 'EventAttr', id: 5 },
      },
    },
    BatchEvent: {
      fields: {
        items: { rule: 'repeated', type: 'Event', id: 1 },
      },
    },
  },
});

const pbSingleType = {
  message: 'Message',
  document: 'Document',
  telemetry: 'Telemetry',
  strings: 'Strings',
  event: 'Event',
};

const pbBatchType = {
  message: 'BatchMessage',
  document: 'BatchDocument',
  telemetry: 'BatchTelemetry',
  strings: 'BatchStrings',
  event: 'BatchEvent',
};

let pbType = null;
let pbDataName = null;
let pbIsBatch = false;
/** Message built in prepare (untimed); serialize only encodes. */
let pbMsg = null;

function toPbItem(dataName, value) {
  const v = jsonClone(value);
  if (dataName === 'message') {
    return {
      f_bool: Boolean(v.f_bool),
      f_int32: v.f_int32 | 0,
      f_int64: Number(v.f_int64),
      f_float64: Number(v.f_float64),
      f_string: String(v.f_string ?? ''),
      f_bool_2: Boolean(v.f_bool_2),
      f_int32_2: v.f_int32_2 | 0,
      f_string_2: String(v.f_string_2 ?? ''),
    };
  }
  if (dataName === 'document') {
    return {
      id: String(v.id ?? ''),
      status: v.status | 0,
      meta: {
        region: String(v.meta?.region ?? ''),
        version: (v.meta?.version ?? 0) | 0,
      },
      items: (v.items || []).map((it) => ({
        sku: String(it.sku ?? ''),
        qty: it.qty | 0,
        price_minor: Number(it.price_minor),
      })),
    };
  }
  if (dataName === 'telemetry') {
    return {
      source: String(v.source ?? ''),
      ts: Number(v.ts),
      tags: (v.tags || []).map(String),
      values: (v.values || []).map(Number),
    };
  }
  if (dataName === 'strings') {
    return { items: (v.items || []).map(String) };
  }
  if (dataName === 'event') {
    return {
      event_id: String(v.event_id ?? ''),
      event_type: String(v.event_type ?? ''),
      occurred_at: Number(v.occurred_at),
      producer: String(v.producer ?? ''),
      attrs: (v.attrs || []).map((a) => ({
        key: String(a.key ?? ''),
        value: String(a.value ?? ''),
      })),
    };
  }
  throw new Error(`protobufjs: no mapping for ${dataName}`);
}

function toPbValue(dataName, value) {
  if (Array.isArray(value)) {
    return { items: value.map((v) => toPbItem(dataName, v)) };
  }
  return toPbItem(dataName, value);
}

function num(v, d = 0) {
  const n = Number(v);
  return Number.isFinite(n) ? n : d;
}

function fromPbItem(dataName, o) {
  if (dataName === 'message') {
    return {
      f_bool: Boolean(o.f_bool),
      f_int32: num(o.f_int32),
      f_int64: num(o.f_int64),
      f_float64: num(o.f_float64),
      f_string: String(o.f_string ?? ''),
      f_bool_2: Boolean(o.f_bool_2),
      f_int32_2: num(o.f_int32_2),
      f_string_2: String(o.f_string_2 ?? ''),
    };
  }
  if (dataName === 'document') {
    return {
      id: String(o.id ?? ''),
      status: num(o.status),
      meta: {
        region: String(o.meta?.region ?? ''),
        version: num(o.meta?.version),
      },
      items: (o.items || []).map((it) => ({
        sku: String(it.sku ?? ''),
        qty: num(it.qty),
        price_minor: num(it.price_minor),
      })),
    };
  }
  if (dataName === 'telemetry') {
    return {
      source: String(o.source ?? ''),
      ts: num(o.ts),
      tags: (o.tags || []).map(String),
      values: (o.values || []).map(Number),
    };
  }
  if (dataName === 'strings') {
    return { items: (o.items || []).map(String) };
  }
  if (dataName === 'event') {
    return {
      event_id: String(o.event_id ?? ''),
      event_type: String(o.event_type ?? ''),
      occurred_at: num(o.occurred_at),
      producer: String(o.producer ?? ''),
      attrs: (o.attrs || []).map((a) => ({
        key: String(a.key ?? ''),
        value: String(a.value ?? ''),
      })),
    };
  }
  return o;
}

function fromPbValue(dataName, decoded, isBatch) {
  const o = decoded.toJSON ? decoded.toJSON() : { ...decoded };
  if (isBatch) {
    return (o.items || []).map((it) => fromPbItem(dataName, it));
  }
  return fromPbItem(dataName, o);
}

export const pbSer = {
  name: 'protobufjs',
  version: pkgVersion('protobufjs'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    // Optimal: verify + create once outside the timed loop (docs: encode only on hot path).
    pbDataName = dataName;
    pbIsBatch = Array.isArray(value);
    const typeName = pbIsBatch ? pbBatchType[dataName] : pbSingleType[dataName];
    if (!typeName) throw new Error(`protobufjs: no type for ${dataName}`);
    pbType = pbRoot.lookupType(typeName);
    const payload = toPbValue(dataName, value);
    const err = pbType.verify(payload);
    if (err) throw new Error(`protobufjs verify: ${err}`);
    pbMsg = pbType.create(payload);
  },
  serialize(_value) {
    return pbType.encode(pbMsg).finish();
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    const decoded = pbType.decode(u8);
    return fromPbValue(pbDataName, decoded, pbIsBatch);
  },
};

/* ---------- FlatBuffers: real tables for V2 types (not JSON-in-FB) ---------- */

let fbDataName = null;
let fbIsBatch = false;

function fbReadString(bb, bytes, table, fieldOff) {
  if (!fieldOff) return '';
  const strOffsetPos = table + fieldOff;
  const strPos = strOffsetPos + bb.readInt32(strOffsetPos);
  const len = bb.readUint32(strPos);
  return Buffer.from(bytes.subarray(strPos + 4, strPos + 4 + len)).toString('utf8');
}

function fbCreateOffsetVector(builder, offsets) {
  builder.startVector(4, offsets.length, 4);
  for (let i = offsets.length - 1; i >= 0; i--) {
    builder.addOffset(offsets[i]);
  }
  return builder.endVector();
}

function fbOpenRoot(bytes) {
  const u8 = bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes);
  const bb = new flatbuffers.ByteBuffer(u8);
  bb.setPosition(0);
  const root = bb.readInt32(0);
  const table = root;
  const vtable = table - bb.readInt32(table);
  const vsize = bb.readInt16(vtable);
  const field = (id) => (4 + id * 2 + 2 <= vsize ? bb.readInt16(vtable + 4 + id * 2) : 0);
  return { bb, bytes: u8, table, field };
}

function fbReadStringVector(bb, bytes, table, fieldOff) {
  if (!fieldOff) return [];
  const vec = table + fieldOff;
  const start = vec + bb.readInt32(vec);
  const len = bb.readInt32(start);
  const out = [];
  for (let i = 0; i < len; i++) {
    const offPos = start + 4 + i * 4;
    const strPos = offPos + bb.readInt32(offPos);
    const slen = bb.readUint32(strPos);
    out.push(Buffer.from(bytes.subarray(strPos + 4, strPos + 4 + slen)).toString('utf8'));
  }
  return out;
}

function fbReadFloat64Vector(bb, table, fieldOff) {
  if (!fieldOff) return [];
  const vec = table + fieldOff;
  const start = vec + bb.readInt32(vec);
  const len = bb.readInt32(start);
  const out = [];
  for (let i = 0; i < len; i++) {
    out.push(bb.readFloat64(start + 4 + i * 8));
  }
  return out;
}

function fbSerializeMessage(builder, v) {
  const s1 = builder.createString(String(v.f_string ?? ''));
  const s2 = builder.createString(String(v.f_string_2 ?? ''));
  builder.startObject(8);
  builder.addFieldOffset(7, s2, 0);
  builder.addFieldInt32(6, v.f_int32_2 | 0, 0);
  builder.addFieldInt8(5, v.f_bool_2 ? 1 : 0, 0);
  builder.addFieldOffset(4, s1, 0);
  builder.addFieldFloat64(3, Number(v.f_float64) || 0, 0);
  builder.addFieldInt64(2, BigInt(Number(v.f_int64) || 0), 0n);
  builder.addFieldInt32(1, v.f_int32 | 0, 0);
  builder.addFieldInt8(0, v.f_bool ? 1 : 0, 0);
  return builder.endObject();
}

function fbDeserializeMessage(bytes) {
  const { bb, bytes: u8, table, field } = fbOpenRoot(bytes);
  const f = field;
  return {
    f_bool: f(0) ? bb.readInt8(table + f(0)) !== 0 : false,
    f_int32: f(1) ? bb.readInt32(table + f(1)) : 0,
    f_int64: f(2) ? Number(bb.readInt64(table + f(2))) : 0,
    f_float64: f(3) ? bb.readFloat64(table + f(3)) : 0,
    f_string: fbReadString(bb, u8, table, f(4)),
    f_bool_2: f(5) ? bb.readInt8(table + f(5)) !== 0 : false,
    f_int32_2: f(6) ? bb.readInt32(table + f(6)) : 0,
    f_string_2: fbReadString(bb, u8, table, f(7)),
  };
}

function fbSerializeDocument(builder, v) {
  const idOff = builder.createString(String(v.id ?? ''));
  const regionOff = builder.createString(String(v.meta?.region ?? ''));
  // meta table: region, version
  builder.startObject(2);
  builder.addFieldOffset(0, regionOff, 0);
  builder.addFieldInt32(1, (v.meta?.version ?? 0) | 0, 0);
  const metaOff = builder.endObject();

  const itemOffs = (v.items || []).map((it) => {
    const skuOff = builder.createString(String(it.sku ?? ''));
    builder.startObject(3);
    builder.addFieldOffset(0, skuOff, 0);
    builder.addFieldInt32(1, it.qty | 0, 0);
    builder.addFieldInt64(2, BigInt(Number(it.price_minor) || 0), 0n);
    return builder.endObject();
  });
  const itemsVec = fbCreateOffsetVector(builder, itemOffs);

  builder.startObject(4);
  builder.addFieldOffset(0, idOff, 0);
  builder.addFieldInt32(1, v.status | 0, 0);
  builder.addFieldOffset(2, metaOff, 0);
  builder.addFieldOffset(3, itemsVec, 0);
  return builder.endObject();
}

function fbReadNestedTable(bb, bytes, table, fieldOff) {
  if (!fieldOff) return null;
  const nested = table + fieldOff + bb.readInt32(table + fieldOff);
  const vtable = nested - bb.readInt32(nested);
  const vsize = bb.readInt16(vtable);
  const field = (id) => (4 + id * 2 + 2 <= vsize ? bb.readInt16(vtable + 4 + id * 2) : 0);
  return { table: nested, field };
}

function fbDeserializeDocument(bytes) {
  const { bb, bytes: u8, table, field } = fbOpenRoot(bytes);
  const meta = fbReadNestedTable(bb, u8, table, field(2));
  let items = [];
  if (field(3)) {
    const vec = table + field(3);
    const start = vec + bb.readInt32(vec);
    const len = bb.readInt32(start);
    for (let i = 0; i < len; i++) {
      const offPos = start + 4 + i * 4;
      const itemTable = offPos + bb.readInt32(offPos);
      const vt = itemTable - bb.readInt32(itemTable);
      const vs = bb.readInt16(vt);
      const f = (id) => (4 + id * 2 + 2 <= vs ? bb.readInt16(vt + 4 + id * 2) : 0);
      items.push({
        sku: fbReadString(bb, u8, itemTable, f(0)),
        qty: f(1) ? bb.readInt32(itemTable + f(1)) : 0,
        price_minor: f(2) ? Number(bb.readInt64(itemTable + f(2))) : 0,
      });
    }
  }
  return {
    id: fbReadString(bb, u8, table, field(0)),
    status: field(1) ? bb.readInt32(table + field(1)) : 0,
    meta: {
      region: meta ? fbReadString(bb, u8, meta.table, meta.field(0)) : '',
      version: meta && meta.field(1) ? bb.readInt32(meta.table + meta.field(1)) : 0,
    },
    items,
  };
}

function fbSerializeTelemetry(builder, v) {
  const srcOff = builder.createString(String(v.source ?? ''));
  const tagOffs = (v.tags || []).map((t) => builder.createString(String(t)));
  const tagsVec = fbCreateOffsetVector(builder, tagOffs);
  // float64 vector
  const vals = v.values || [];
  builder.startVector(8, vals.length, 8);
  for (let i = vals.length - 1; i >= 0; i--) {
    builder.addFloat64(Number(vals[i]) || 0);
  }
  const valuesVec = builder.endVector();

  builder.startObject(4);
  builder.addFieldOffset(0, srcOff, 0);
  builder.addFieldInt64(1, BigInt(Number(v.ts) || 0), 0n);
  builder.addFieldOffset(2, tagsVec, 0);
  builder.addFieldOffset(3, valuesVec, 0);
  return builder.endObject();
}

function fbDeserializeTelemetry(bytes) {
  const { bb, bytes: u8, table, field } = fbOpenRoot(bytes);
  return {
    source: fbReadString(bb, u8, table, field(0)),
    ts: field(1) ? Number(bb.readInt64(table + field(1))) : 0,
    tags: fbReadStringVector(bb, u8, table, field(2)),
    values: fbReadFloat64Vector(bb, table, field(3)),
  };
}

function fbSerializeStrings(builder, v) {
  const offs = (v.items || []).map((s) => builder.createString(String(s)));
  const vec = fbCreateOffsetVector(builder, offs);
  builder.startObject(1);
  builder.addFieldOffset(0, vec, 0);
  return builder.endObject();
}

function fbDeserializeStrings(bytes) {
  const { bb, bytes: u8, table, field } = fbOpenRoot(bytes);
  return { items: fbReadStringVector(bb, u8, table, field(0)) };
}

function fbSerializeEvent(builder, v) {
  const idOff = builder.createString(String(v.event_id ?? ''));
  const typeOff = builder.createString(String(v.event_type ?? ''));
  const prodOff = builder.createString(String(v.producer ?? ''));
  const attrOffs = (v.attrs || []).map((a) => {
    const k = builder.createString(String(a.key ?? ''));
    const val = builder.createString(String(a.value ?? ''));
    builder.startObject(2);
    builder.addFieldOffset(0, k, 0);
    builder.addFieldOffset(1, val, 0);
    return builder.endObject();
  });
  const attrsVec = fbCreateOffsetVector(builder, attrOffs);
  builder.startObject(5);
  builder.addFieldOffset(0, idOff, 0);
  builder.addFieldOffset(1, typeOff, 0);
  builder.addFieldInt64(2, BigInt(Number(v.occurred_at) || 0), 0n);
  builder.addFieldOffset(3, prodOff, 0);
  builder.addFieldOffset(4, attrsVec, 0);
  return builder.endObject();
}

function fbDeserializeEvent(bytes) {
  const { bb, bytes: u8, table, field } = fbOpenRoot(bytes);
  let attrs = [];
  if (field(4)) {
    const vec = table + field(4);
    const start = vec + bb.readInt32(vec);
    const len = bb.readInt32(start);
    for (let i = 0; i < len; i++) {
      const offPos = start + 4 + i * 4;
      const at = offPos + bb.readInt32(offPos);
      const vt = at - bb.readInt32(at);
      const vs = bb.readInt16(vt);
      const f = (id) => (4 + id * 2 + 2 <= vs ? bb.readInt16(vt + 4 + id * 2) : 0);
      attrs.push({
        key: fbReadString(bb, u8, at, f(0)),
        value: fbReadString(bb, u8, at, f(1)),
      });
    }
  }
  return {
    event_id: fbReadString(bb, u8, table, field(0)),
    event_type: fbReadString(bb, u8, table, field(1)),
    occurred_at: field(2) ? Number(bb.readInt64(table + field(2))) : 0,
    producer: fbReadString(bb, u8, table, field(3)),
    attrs,
  };
}

function fbSerializeOne(dataName, value) {
  const builder = new flatbuffers.Builder(1024);
  let root;
  switch (dataName) {
    case 'message':
      root = fbSerializeMessage(builder, value);
      break;
    case 'document':
      root = fbSerializeDocument(builder, value);
      break;
    case 'telemetry':
      root = fbSerializeTelemetry(builder, value);
      break;
    case 'strings':
      root = fbSerializeStrings(builder, value);
      break;
    case 'event':
      root = fbSerializeEvent(builder, value);
      break;
    default:
      throw new Error(`flatbuffers: no mapping for ${dataName}`);
  }
  builder.finish(root);
  return Buffer.from(builder.asUint8Array());
}

function fbDeserializeOne(dataName, bytes) {
  switch (dataName) {
    case 'message':
      return fbDeserializeMessage(bytes);
    case 'document':
      return fbDeserializeDocument(bytes);
    case 'telemetry':
      return fbDeserializeTelemetry(bytes);
    case 'strings':
      return fbDeserializeStrings(bytes);
    case 'event':
      return fbDeserializeEvent(bytes);
    default:
      throw new Error(`flatbuffers: no mapping for ${dataName}`);
  }
}

function fbSerialize(dataName, value) {
  if (Array.isArray(value)) {
    const parts = value.map((item) => fbSerializeOne(dataName, item));
    const total = 4 + parts.reduce((a, p) => a + 4 + p.length, 0);
    const out = Buffer.allocUnsafe(total);
    out.writeUInt32LE(parts.length, 0);
    let o = 4;
    for (const p of parts) {
      out.writeUInt32LE(p.length, o);
      o += 4;
      p.copy(out, o);
      o += p.length;
    }
    return out;
  }
  return fbSerializeOne(dataName, value);
}

function fbDeserialize(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  if (fbIsBatch) {
    const n = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
    let o = 4;
    const items = [];
    for (let i = 0; i < n; i++) {
      const ln = bytes[o] | (bytes[o + 1] << 8) | (bytes[o + 2] << 16) | (bytes[o + 3] << 24);
      o += 4;
      items.push(fbDeserializeOne(fbDataName, bytes.subarray(o, o + ln)));
      o += ln;
    }
    return items;
  }
  return fbDeserializeOne(fbDataName, bytes);
}

export const flatbuffersSer = {
  name: 'flatbuffers',
  version: pkgVersion('flatbuffers'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    fbDataName = dataName;
    fbIsBatch = Array.isArray(value);
  },
  serialize(value) {
    return fbSerialize(fbDataName, value);
  },
  deserialize(buf) {
    return fbDeserialize(buf);
  },
};

/* ---------- FlexBuffers (schemaless FlatBuffers family; parity with Rust flexbuffers) ---------- */
/*
 * flatbuffers 24.x JS flexbuffers has known bugs:
 *  - large typed vectors (float/string arrays) → DataView bounds / BigInt mix errors in toObject
 * Workaround for full-fixture support: encode arrays as maps ({__a,n,i0..}) and non-integer
 * floats as {__f:"..."}. Still real flexbuffers map/string wire; restores exact JS values.
 */

function toArrayBuffer(buf) {
  if (buf instanceof ArrayBuffer) return buf;
  if (buf instanceof Uint8Array) {
    return buf.buffer.slice(buf.byteOffset, buf.byteOffset + buf.byteLength);
  }
  const u8 = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
  return u8.buffer.slice(u8.byteOffset, u8.byteOffset + u8.byteLength);
}

/** Sanitize for flexbuffers 24.x encode/toObject quirks (arrays + non-int floats). */
function flexSanitize(value) {
  if (value === null || value === undefined) return null;
  if (typeof value === 'number') {
    if (!Number.isFinite(value)) return 0;
    // Box all numbers — flexbuffers 24.x mixes BigInt with float vectors otherwise.
    return { __f: String(value) };
  }
  if (typeof value === 'string' || typeof value === 'boolean') return value;
  if (Array.isArray(value)) {
    const o = { __a: true, n: value.length };
    for (let i = 0; i < value.length; i++) o[`i${i}`] = flexSanitize(value[i]);
    return o;
  }
  if (typeof value === 'object') {
    const o = {};
    for (const [k, v] of Object.entries(value)) o[k] = flexSanitize(v);
    return o;
  }
  return String(value);
}

function flexRestoreSanitized(value) {
  if (value === null || value === undefined) return value;
  if (typeof value === 'object' && !Array.isArray(value)) {
    if (value.__a === true) {
      const a = [];
      const n = Number(value.n) || 0;
      for (let i = 0; i < n; i++) a.push(flexRestoreSanitized(value[`i${i}`]));
      return a;
    }
    if (Object.prototype.hasOwnProperty.call(value, '__f') && Object.keys(value).length === 1) {
      return Number(value.__f);
    }
    const o = {};
    for (const [k, v] of Object.entries(value)) o[k] = flexRestoreSanitized(v);
    return o;
  }
  return value;
}

/** Pre-sanitized fixture value (prepare); serialize only encodes. */
let flexPrepared = null;
let flexNeedsRestore = false;
// flexPrepared = null;

export const flexbuffersSer = {
  name: 'flexbuffers',
  version: pkgVersion('flatbuffers'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    // Always run flexSanitize: ints stay native; floats/arrays get workarounds for 24.x bugs.
    flexPrepared = flexSanitize(jsonClone(value));
    flexNeedsRestore = true;
  },
  serialize(_value) {
    // Optimal: encode only; return Buffer view of encode output without double-set.
    const u8 = flexEncode(flexPrepared, 1024 * 1024);
    return Buffer.from(u8.buffer, u8.byteOffset, u8.byteLength);
  },
  deserialize(buf) {
    const raw = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
    // flexbuffers toObject needs a standalone ArrayBuffer in some builds
    const ab = raw.buffer.slice(raw.byteOffset, raw.byteOffset + raw.byteLength);
    const obj = flexToObject(ab);
    return flexNeedsRestore ? flexRestoreSanitized(obj) : obj;
  },
};

export function schemaSerializers() {
  return [avscSer, pbSer, flatbuffersSer, flexbuffersSer];
}
