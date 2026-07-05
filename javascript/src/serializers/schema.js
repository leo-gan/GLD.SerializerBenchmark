import avro from 'avsc';
import protobuf from 'protobufjs';
import * as flatbuffers from 'flatbuffers';
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
function fbSerialize(_dataName, value) {
  const builder = new flatbuffers.Builder(1024);
  const jsonOff = builder.createString(JSON.stringify(value));
  builder.startObject(1);
  builder.addFieldOffset(0, jsonOff, 0);
  const root = builder.endObject();
  builder.finish(root);
  return Buffer.from(builder.asUint8Array());
}

function fbDeserialize(buf) {
  const bytes = buf instanceof Uint8Array ? buf : new Uint8Array(buf.buffer, buf.byteOffset, buf.byteLength);
  const bb = new flatbuffers.ByteBuffer(bytes);
  // Root table offset is little-endian int32 at start of buffer (no size prefix).
  const root = bb.readInt32(0);
  const table = root;
  // vtable offset (negative relative from table start in FB encoding)
  const vtable = table - bb.readInt32(table);
  const vsize = bb.readInt16(vtable);
  // field 0 offset in vtable (after vtable size + object size = 4 bytes)
  let fieldOff = 0;
  if (vsize >= 6) fieldOff = bb.readInt16(vtable + 4);
  if (!fieldOff) throw new Error('flatbuffers: empty table');
  const strOffsetPos = table + fieldOff;
  const strPos = strOffsetPos + bb.readInt32(strOffsetPos);
  const len = bb.readUint32(strPos);
  // strings are UTF-8 in flatbuffers
  const slice = bytes.subarray(strPos + 4, strPos + 4 + len);
  const jsonStr = Buffer.from(slice).toString('utf8');
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

export function schemaSerializers() {
  return [avscSer, pbSer, flatbuffersSer];
}
