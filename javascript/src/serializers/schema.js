import avro from 'avsc';
import protobuf from 'protobufjs';
import * as flatbuffers from 'flatbuffers';
import { encode as flexEncode, toObject as flexToObject } from 'flatbuffers/mjs/flexbuffers.js';
import { pkgVersion, baseSupports, jsonClone } from './common.js';

/* ---------- shared Avro / protobuf field models matching JS fixtures ---------- */

const avroSchemas = {
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
    if (!schema) {
      avroType = avro.Type.forValue(jsonClone(value));
    } else {
      avroType = avro.Type.forSchema(schema);
    }
  },
  serialize(value) {
    return avroType.toBuffer(avroPrepareValue(avroDataName, value));
  },
  deserialize(buf) {
    return avroType.fromBuffer(Buffer.from(buf));
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
  },
});

const pbTypeByName = {
  Person: 'Person',
  SimpleObject: 'SimpleObject',
  StringArray: 'StringArrayObject',
  Telemetry: 'TelemetryData',
  EDI_835: 'EDI835',
  Integer: 'IntegerValue',
};

let pbType = null;
let pbDataName = null;

function toPbValue(dataName, value) {
  if (dataName === 'Integer') return { value: value | 0 };
  // protobufjs Long fields: use numbers (fits our fixture ranges)
  const v = jsonClone(value);
  if (dataName === 'Telemetry') {
    v.AssociatedProblemID = Number(v.AssociatedProblemID);
    v.AssociatedLogID = Number(v.AssociatedLogID);
  }
  return v;
}

function fromPbValue(dataName, decoded) {
  if (dataName === 'Integer') return decoded.value;
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
  return o;
}

export const pbSer = {
  name: 'protobufjs',
  version: pkgVersion('protobufjs'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName) {
    pbDataName = dataName;
    const typeName = pbTypeByName[dataName] || 'Person';
    pbType = pbRoot.lookupType(typeName);
  },
  serialize(value) {
    const payload = toPbValue(pbDataName, value);
    const err = pbType.verify(payload);
    if (err) throw new Error(`protobufjs verify: ${err}`);
    const msg = pbType.create(payload);
    return pbType.encode(msg).finish();
  },
  deserialize(buf) {
    const decoded = pbType.decode(Buffer.from(buf));
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
    if (!Number.isInteger(value)) return { __f: String(value) };
    return value;
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

export const flexbuffersSer = {
  name: 'flexbuffers',
  version: pkgVersion('flatbuffers'),
  category: 'schema',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    const plain = flexSanitize(jsonClone(value));
    const u8 = flexEncode(plain, 1024 * 1024);
    const copy = new Uint8Array(u8.byteLength);
    copy.set(u8);
    return Buffer.from(copy.buffer);
  },
  deserialize(buf) {
    const raw = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
    const ab = new ArrayBuffer(raw.byteLength);
    new Uint8Array(ab).set(raw);
    return flexRestoreSanitized(flexToObject(ab));
  },
};

export function schemaSerializers() {
  return [avscSer, pbSer, flatbuffersSer, flexbuffersSer];
}
