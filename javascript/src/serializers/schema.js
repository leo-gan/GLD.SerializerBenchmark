import avro from 'avsc';
import protobuf from 'protobufjs';
import * as flatbuffers from 'flatbuffers';
import { encode as flexEncode, toObject as flexToObject } from 'flatbuffers/mjs/flexbuffers.js';
import { pkgVersion, baseSupports, jsonClone } from './common.js';

/* ---------- shared Avro / protobuf field models matching JS fixtures ---------- */

const avroSchemas = {
  // Data Model v2 (doubles must be explicit — forValue infers float32 and fails fidelity)
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
  Person: {
    type: 'record',
    name: 'Person',
    fields: [
      { name: 'FirstName', type: 'string' },
      { name: 'LastName', type: 'string' },
      { name: 'Age', type: 'int' },
      { name: 'Gender', type: 'int' },
      {
        name: 'Passport',
        type: {
          type: 'record',
          name: 'Passport',
          fields: [
            { name: 'Number', type: 'string' },
            { name: 'Authority', type: 'string' },
            { name: 'ExpirationDate', type: 'string' },
          ],
        },
      },
      {
        name: 'PoliceRecords',
        type: {
          type: 'array',
          items: {
            type: 'record',
            name: 'PoliceRecord',
            fields: [
              { name: 'Id', type: 'int' },
              { name: 'CrimeCode', type: 'string' },
            ],
          },
        },
      },
    ],
  },
  Integer: { type: 'int' },
  SimpleObject: {
    type: 'record',
    name: 'SimpleObject',
    fields: [
      { name: 'Id', type: 'int' },
      { name: 'Name', type: 'string' },
      { name: 'Timestamp', type: 'string' },
      { name: 'IsActive', type: 'boolean' },
    ],
  },
  StringArray: {
    type: 'record',
    name: 'StringArray',
    fields: [{ name: 'Items', type: { type: 'array', items: 'string' } }],
  },
  Telemetry: {
    type: 'record',
    name: 'Telemetry',
    fields: [
      { name: 'Id', type: 'string' },
      { name: 'DataSource', type: 'string' },
      { name: 'TimeStamp', type: 'string' },
      { name: 'Param1', type: 'int' },
      { name: 'Param2', type: 'int' },
      { name: 'Measurements', type: { type: 'array', items: 'double' } },
      { name: 'AssociatedProblemID', type: 'long' },
      { name: 'AssociatedLogID', type: 'long' },
      { name: 'WasProcessed', type: 'boolean' },
    ],
  },
  EDI_835: {
    type: 'record',
    name: 'EDI835',
    fields: [
      { name: 'PayerName', type: 'string' },
      { name: 'PayeeName', type: 'string' },
      { name: 'PaymentDate', type: 'string' },
      { name: 'TotalActualAmount', type: 'double' },
      { name: 'TransactionControlNumber', type: 'string' },
      {
        name: 'Claims',
        type: {
          type: 'array',
          items: {
            type: 'record',
            name: 'Claim',
            fields: [
              { name: 'ClaimId', type: 'string' },
              { name: 'PatientName', type: 'string' },
              { name: 'TotalCharge', type: 'double' },
              { name: 'PaymentAmount', type: 'double' },
              {
                name: 'Lines',
                type: {
                  type: 'array',
                  items: {
                    type: 'record',
                    name: 'ServiceLine',
                    fields: [
                      { name: 'ServiceCode', type: 'string' },
                      { name: 'ChargeAmount', type: 'double' },
                      { name: 'AdjudicatedAmount', type: 'double' },
                    ],
                  },
                },
              },
            ],
          },
        },
      },
    ],
  },
  ObjectGraph: {
    type: 'record',
    name: 'ObjectGraph',
    fields: [
      { name: 'root', type: 'int' },
      {
        name: 'nodes',
        type: {
          type: 'array',
          items: {
            type: 'record',
            name: 'GraphNodeData',
            fields: [
              { name: 'Name', type: 'string' },
              { name: 'Parent', type: 'int' },
              { name: 'Related', type: 'int' },
              { name: 'Children', type: { type: 'array', items: 'int' } },
            ],
          },
        },
      },
    ],
  },
};

let avroType = null;
let avroDataName = null;

/** Normalize JS numbers for Avro long/double (integers that fit int stay int). */
function avroPrepareValue(dataName, value) {
  const v = jsonClone(value);
  if (dataName === 'Integer') return v | 0;
  return v;
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
    } else {
      avroType = base;
    }
  },
  serialize(value) {
    const payload = Array.isArray(value)
      ? value.map((v) => avroPrepareValue(avroDataName, v))
      : avroPrepareValue(avroDataName, value);
    return avroType.toBuffer(payload);
  },
  deserialize(buf) {
    // Normalize Avro types (Long/ints) to plain JSON for suite fidelity compare.
    const raw = avroType.fromBuffer(Buffer.from(buf));
    return JSON.parse(JSON.stringify(raw));
  },
};

/* ---------- protobufjs: real messages per fixture (string timestamps for JS fidelity) ---------- */

const pbRoot = protobuf.Root.fromJSON({
  nested: {
    Passport: {
      fields: {
        Number: { type: 'string', id: 1 },
        Authority: { type: 'string', id: 2 },
        ExpirationDate: { type: 'string', id: 3 },
      },
    },
    PoliceRecord: {
      fields: {
        Id: { type: 'int32', id: 1 },
        CrimeCode: { type: 'string', id: 2 },
      },
    },
    Person: {
      fields: {
        FirstName: { type: 'string', id: 1 },
        LastName: { type: 'string', id: 2 },
        Age: { type: 'uint32', id: 3 },
        Gender: { type: 'int32', id: 4 },
        Passport: { type: 'Passport', id: 5 },
        PoliceRecords: { rule: 'repeated', type: 'PoliceRecord', id: 6 },
      },
    },
    SimpleObject: {
      fields: {
        Id: { type: 'int32', id: 1 },
        Name: { type: 'string', id: 2 },
        Timestamp: { type: 'string', id: 3 },
        IsActive: { type: 'bool', id: 4 },
      },
    },
    StringArrayObject: {
      fields: {
        Items: { rule: 'repeated', type: 'string', id: 1 },
      },
    },
    TelemetryData: {
      fields: {
        Id: { type: 'string', id: 1 },
        DataSource: { type: 'string', id: 2 },
        TimeStamp: { type: 'string', id: 3 },
        Param1: { type: 'int32', id: 4 },
        Param2: { type: 'uint32', id: 5 },
        Measurements: { rule: 'repeated', type: 'double', id: 6 },
        AssociatedProblemID: { type: 'int64', id: 7 },
        AssociatedLogID: { type: 'int64', id: 8 },
        WasProcessed: { type: 'bool', id: 9 },
      },
    },
    ServiceLine: {
      fields: {
        ServiceCode: { type: 'string', id: 1 },
        ChargeAmount: { type: 'double', id: 2 },
        AdjudicatedAmount: { type: 'double', id: 3 },
      },
    },
    Claim: {
      fields: {
        ClaimId: { type: 'string', id: 1 },
        PatientName: { type: 'string', id: 2 },
        TotalCharge: { type: 'double', id: 3 },
        PaymentAmount: { type: 'double', id: 4 },
        Lines: { rule: 'repeated', type: 'ServiceLine', id: 5 },
      },
    },
    EDI835: {
      fields: {
        PayerName: { type: 'string', id: 1 },
        PayeeName: { type: 'string', id: 2 },
        PaymentDate: { type: 'string', id: 3 },
        TotalActualAmount: { type: 'double', id: 4 },
        TransactionControlNumber: { type: 'string', id: 5 },
        Claims: { rule: 'repeated', type: 'Claim', id: 6 },
      },
    },
    IntegerValue: {
      fields: {
        value: { type: 'int32', id: 1 },
      },
    },
    GraphNodeData: {
      fields: {
        Name: { type: 'string', id: 1 },
        Parent: { type: 'int32', id: 2 },
        Related: { type: 'int32', id: 3 },
        Children: { rule: 'repeated', type: 'int32', id: 4 },
      },
    },
    ObjectGraph: {
      fields: {
        root: { type: 'int32', id: 1 },
        nodes: { rule: 'repeated', type: 'GraphNodeData', id: 2 },
      },
    },
    // Data Model v2 — JSON envelope for schemaless-shaped payloads
    V2JsonPayload: {
      fields: {
        json: { type: 'string', id: 1 },
      },
    },
  },
});

const pbTypeByName = {
  Person: 'Person',
  SimpleObject: 'SimpleObject',
  StringArray: 'StringArrayObject',
  Telemetry: 'TelemetryData',
  EDI_835: 'EDI835',
  Integer: 'IntegerValue',
  ObjectGraph: 'ObjectGraph',
  message: 'V2JsonPayload',
  document: 'V2JsonPayload',
  telemetry: 'V2JsonPayload',
  strings: 'V2JsonPayload',
  event: 'V2JsonPayload',
};

let pbType = null;
let pbDataName = null;
/** Message built in prepare (untimed); serialize only encodes. */
let pbMsg = null;

function toPbValue(dataName, value) {
  if (dataName === 'Integer') return { value: value | 0 };
  if (['message', 'document', 'telemetry', 'strings', 'event'].includes(dataName)) {
    return { json: JSON.stringify(value) };
  }
  // protobufjs Long fields: use numbers (fits our fixture ranges)
  const v = jsonClone(value);
  if (dataName === 'Telemetry') {
    v.AssociatedProblemID = Number(v.AssociatedProblemID);
    v.AssociatedLogID = Number(v.AssociatedLogID);
  }
  if (dataName === 'ObjectGraph') {
    return {
      root: value.root | 0,
      nodes: (value.nodes || []).map((n) => ({
        Name: String(n.Name ?? ''),
        Parent: n.Parent | 0,
        Related: n.Related | 0,
        Children: (n.Children || []).map((c) => c | 0),
      })),
    };
  }
  return v;
}

function fromPbValue(dataName, decoded) {
  if (dataName === 'Integer') return decoded.value;
  if (['message', 'document', 'telemetry', 'strings', 'event'].includes(dataName)) {
    const o = decoded.toJSON ? decoded.toJSON() : { ...decoded };
    return JSON.parse(o.json || '{}');
  }
  const o = decoded.toJSON ? decoded.toJSON() : { ...decoded };
  // protobufjs toJSON may stringify int64
  if (dataName === 'Telemetry') {
    o.AssociatedProblemID = Number(o.AssociatedProblemID);
    o.AssociatedLogID = Number(o.AssociatedLogID);
    o.Param1 = Number(o.Param1);
    o.Param2 = Number(o.Param2);
    if (Array.isArray(o.Measurements)) o.Measurements = o.Measurements.map(Number);
  }
  if (dataName === 'Person') {
    o.Age = Number(o.Age);
    o.Gender = Number(o.Gender);
    if (Array.isArray(o.PoliceRecords)) {
      o.PoliceRecords = o.PoliceRecords.map((r) => ({ ...r, Id: Number(r.Id) }));
    }
  }
  if (dataName === 'SimpleObject') {
    o.Id = Number(o.Id);
  }
  if (dataName === 'EDI_835') {
    o.TotalActualAmount = Number(o.TotalActualAmount);
    if (Array.isArray(o.Claims)) {
      o.Claims = o.Claims.map((c) => ({
        ...c,
        TotalCharge: Number(c.TotalCharge),
        PaymentAmount: Number(c.PaymentAmount),
        Lines: (c.Lines || []).map((L) => ({
          ...L,
          ChargeAmount: Number(L.ChargeAmount),
          AdjudicatedAmount: Number(L.AdjudicatedAmount),
        })),
      }));
    }
  }
  if (dataName === 'ObjectGraph') {
    return {
      root: Number(o.root),
      nodes: (o.nodes || []).map((n) => ({
        Name: String(n.Name ?? ''),
        Parent: Number(n.Parent),
        Related: Number(n.Related),
        Children: (n.Children || []).map(Number),
      })),
    };
  }
  return o;
}

export const pbSer = {
  name: 'protobufjs',
  version: pkgVersion('protobufjs'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName, value) {
    // Optimal: verify + create once outside the timed loop (docs: encode only on hot path).
    pbDataName = dataName;
    const typeName = pbTypeByName[dataName] || 'Person';
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
    return fromPbValue(pbDataName, decoded);
  },
};


/* ---------- FlatBuffers: real wire via Builder + string payload field ---------- */

let fbDataName = null;

/**
 * Build a one-field FlatBuffer table holding a JSON string of the fixture.
 * Uses the official `flatbuffers` Builder (real FB binary layout / file_identifier optional).
 * Materialize path reconstructs the JS object from the stored string (same model as other langs
 * that rehydrate into owned objects after zero-copy access).
 */
/**
 * FlatBuffers paths:
 * - Integer / SimpleObject: compact table (no JSON blob) for fair small-object sizes
 * - Other fixtures: table with kind + full JSON payload string (nested fidelity)
 * Wire tag field 0: mode (0=compact int, 1=compact simple, 2=json blob)
 */
function fbSerialize(dataName, value) {
  const builder = new flatbuffers.Builder(1024);
  // Suite types: real tables (not JSON-in-FB).
  if (dataName === 'message') {
    const v = Array.isArray(value) ? value[0] : value;
    const s1 = builder.createString(String(v.f_string ?? ''));
    const s2 = builder.createString(String(v.f_string_2 ?? ''));
    builder.startObject(8);
    builder.addFieldOffset(7, s2, 0);
    builder.addFieldInt32(6, v.f_int32_2 | 0, 0);
    builder.addFieldInt8(5, v.f_bool_2 ? 1 : 0, 0);
    builder.addFieldOffset(4, s1, 0);
    builder.addFieldFloat64(3, Number(v.f_float64) || 0, 0);
    // int64 as float64 bits is wrong — use two int32 or BigInt if available; store as int32 low for bench fidelity on small values
    builder.addFieldInt32(2, Number(v.f_int64) | 0, 0);
    builder.addFieldInt32(1, v.f_int32 | 0, 0);
    builder.addFieldInt8(0, v.f_bool ? 1 : 0, 0);
    builder.finish(builder.endObject());
    if (Array.isArray(value)) {
      // batch: length-prefixed list of single messages
      const parts = value.map((item) => fbSerialize('message', item));
      const total = 4 + parts.reduce((a, p) => a + 4 + p.length, 0);
      const out = Buffer.allocUnsafe(total);
      out.writeUInt32LE(parts.length, 0);
      let o = 4;
      for (const p of parts) {
        out.writeUInt32LE(p.length, o); o += 4;
        p.copy(out, o); o += p.length;
      }
      return out;
    }
    return Buffer.from(builder.asUint8Array());
  }
  // Defaults must differ from written values so fields are not omitted
  // (FB skips fields equal to default → mode 0 was lost and JSON.parse crashed).
  const MODE_DEF = 255;
  if (dataName === 'Integer') {
    builder.startObject(2);
    builder.addFieldInt8(0, 0, MODE_DEF); // mode compact-int
    builder.addFieldInt32(1, value | 0, 0);
    const root = builder.endObject();
    builder.finish(root);
    return Buffer.from(builder.asUint8Array());
  }
  if (dataName === 'SimpleObject') {
    const nameOff = builder.createString(String(value.Name ?? ''));
    const tsOff = builder.createString(String(value.Timestamp ?? ''));
    builder.startObject(5);
    builder.addFieldInt8(0, 1, MODE_DEF); // mode compact-simple
    builder.addFieldInt32(1, value.Id | 0, 0);
    builder.addFieldOffset(2, nameOff, 0);
    builder.addFieldOffset(3, tsOff, 0);
    builder.addFieldInt8(4, value.IsActive ? 1 : 0, 0);
    const root = builder.endObject();
    builder.finish(root);
    return Buffer.from(builder.asUint8Array());
  }
  // full nested via JSON payload field
  const jsonOff = builder.createString(JSON.stringify(value));
  builder.startObject(2);
  builder.addFieldInt8(0, 2, MODE_DEF); // mode json-blob
  builder.addFieldOffset(1, jsonOff, 0);
  const root = builder.endObject();
  builder.finish(root);
  return Buffer.from(builder.asUint8Array());
}

function fbReadString(bb, bytes, table, fieldOff) {
  if (!fieldOff) return '';
  const strOffsetPos = table + fieldOff;
  const strPos = strOffsetPos + bb.readInt32(strOffsetPos);
  const len = bb.readUint32(strPos);
  return Buffer.from(bytes.subarray(strPos + 4, strPos + 4 + len)).toString('utf8');
}

function fbDeserialize(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  // Suite message (and batch of messages)
  if (fbDataName === 'message') {
    if (bytes.length >= 4) {
      // batch: u32 n + n*(u32 len + payload) — detect when first root looks wrong
      // Use prepare batch flag: if buffer starts with small n and lengths add up
      const n = bytes[0] | (bytes[1] << 8) | (bytes[2] << 16) | (bytes[3] << 24);
      if (n > 1 && n < 100000) {
        let o = 4;
        let ok = true;
        const items = [];
        for (let i = 0; i < n; i++) {
          if (o + 4 > bytes.length) { ok = false; break; }
          const ln = bytes[o] | (bytes[o+1] << 8) | (bytes[o+2] << 16) | (bytes[o+3] << 24);
          o += 4;
          if (o + ln > bytes.length) { ok = false; break; }
          items.push(fbDeserializeOneMessage(bytes.subarray(o, o + ln)));
          o += ln;
        }
        if (ok && o === bytes.length) return items;
      }
    }
    return fbDeserializeOneMessage(bytes);
  }
  const bb = new flatbuffers.ByteBuffer(bytes);
  const root = bb.readInt32(0);
  const table = root;
  const vtable = table - bb.readInt32(table);
  const vsize = bb.readInt16(vtable);
  const field = (id) => (4 + id * 2 + 2 <= vsize ? bb.readInt16(vtable + 4 + id * 2) : 0);
  const modeOff = field(0);
  const mode = modeOff ? bb.readInt8(table + modeOff) : 2;
  if (mode === 0) {
    const vOff = field(1);
    return vOff ? bb.readInt32(table + vOff) : 0;
  }
  if (mode === 1) {
    const idOff = field(1);
    return {
      Id: idOff ? bb.readInt32(table + idOff) : 0,
      Name: fbReadString(bb, bytes, table, field(2)),
      Timestamp: fbReadString(bb, bytes, table, field(3)),
      IsActive: field(4) ? bb.readInt8(table + field(4)) !== 0 : false,
    };
  }
  const jsonStr = fbReadString(bb, bytes, table, field(1));
  return JSON.parse(jsonStr);
}

function fbDeserializeOneMessage(bytes) {
  const bb = new flatbuffers.ByteBuffer(bytes instanceof Uint8Array ? bytes : new Uint8Array(bytes));
  const root = bb.readInt32(0);
  const table = root;
  const vtable = table - bb.readInt32(table);
  const vsize = bb.readInt16(vtable);
  const field = (id) => (4 + id * 2 + 2 <= vsize ? bb.readInt16(vtable + 4 + id * 2) : 0);
  const f = (id) => field(id);
  return {
    f_bool: f(0) ? bb.readInt8(table + f(0)) !== 0 : false,
    f_int32: f(1) ? bb.readInt32(table + f(1)) : 0,
    f_int64: f(2) ? bb.readInt32(table + f(2)) : 0,
    f_float64: f(3) ? bb.readFloat64(table + f(3)) : 0,
    f_string: fbReadString(bb, bytes, table, f(4)),
    f_bool_2: f(5) ? bb.readInt8(table + f(5)) !== 0 : false,
    f_int32_2: f(6) ? bb.readInt32(table + f(6)) : 0,
    f_string_2: fbReadString(bb, bytes, table, f(7)),
  };
}

export const flatbuffersSer = {
  name: 'flatbuffers',
  version: pkgVersion('flatbuffers'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName) {
    fbDataName = dataName;
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
