/**
 * P0/P1 additions: protobuf-es, json-pack (MessagePack), devalue, bebop, sia.
 * flexbuffers lives in schema.js (already registered).
 */
import { createRequire } from 'node:module';
import { create, toBinary, fromBinary, toJson } from '@bufbuild/protobuf';
import { stringify as devalueStringify, parse as devalueParse } from 'devalue';
import { BebopView } from 'bebop';
import { Sia } from '@timeleap/sia';
import {
  PersonSchema,
  SimpleObjectSchema,
  StringArrayObjectSchema,
  TelemetryDataSchema,
  EDI835Schema,
  IntegerValueSchema,
} from '../generated/js_fixtures_pb.js';
import { pkgVersion, baseSupports, jsonClone } from './common.js';

const require = createRequire(import.meta.url);

/* ---------- protobuf-es (@bufbuild/protobuf) ---------- */

const esSchemaByName = {
  Person: PersonSchema,
  SimpleObject: SimpleObjectSchema,
  StringArray: StringArrayObjectSchema,
  Telemetry: TelemetryDataSchema,
  EDI_835: EDI835Schema,
  Integer: IntegerValueSchema,
};

let esSchema = null;
let esDataName = null;

function toEsInput(dataName, value) {
  if (dataName === 'Integer') return { value: value | 0 };
  const v = jsonClone(value);
  if (dataName === 'Telemetry') {
    v.AssociatedProblemID = BigInt(v.AssociatedProblemID);
    v.AssociatedLogID = BigInt(v.AssociatedLogID);
  }
  return v;
}

function fromEsMessage(dataName, msg) {
  // Prefer field access (toJson drops proto3 defaults like 0 / false).
  if (dataName === 'Integer') return Number(msg.value);
  if (dataName === 'SimpleObject') {
    return {
      Id: Number(msg.Id),
      Name: String(msg.Name ?? ''),
      Timestamp: String(msg.Timestamp ?? ''),
      IsActive: Boolean(msg.IsActive),
    };
  }
  if (dataName === 'StringArray') {
    return { Items: [...(msg.Items ?? [])].map(String) };
  }
  if (dataName === 'Person') {
    return {
      FirstName: String(msg.FirstName ?? ''),
      LastName: String(msg.LastName ?? ''),
      Age: Number(msg.Age),
      Gender: Number(msg.Gender),
      Passport: {
        Number: String(msg.Passport?.Number ?? ''),
        Authority: String(msg.Passport?.Authority ?? ''),
        ExpirationDate: String(msg.Passport?.ExpirationDate ?? ''),
      },
      PoliceRecords: [...(msg.PoliceRecords ?? [])].map((r) => ({
        Id: Number(r.Id),
        CrimeCode: String(r.CrimeCode ?? ''),
      })),
    };
  }
  if (dataName === 'Telemetry') {
    return {
      Id: String(msg.Id ?? ''),
      DataSource: String(msg.DataSource ?? ''),
      TimeStamp: String(msg.TimeStamp ?? ''),
      Param1: Number(msg.Param1),
      Param2: Number(msg.Param2),
      Measurements: [...(msg.Measurements ?? [])].map(Number),
      AssociatedProblemID: Number(msg.AssociatedProblemID),
      AssociatedLogID: Number(msg.AssociatedLogID),
      WasProcessed: Boolean(msg.WasProcessed),
    };
  }
  if (dataName === 'EDI_835') {
    return {
      PayerName: String(msg.PayerName ?? ''),
      PayeeName: String(msg.PayeeName ?? ''),
      PaymentDate: String(msg.PaymentDate ?? ''),
      TotalActualAmount: Number(msg.TotalActualAmount),
      TransactionControlNumber: String(msg.TransactionControlNumber ?? ''),
      Claims: [...(msg.Claims ?? [])].map((c) => ({
        ClaimId: String(c.ClaimId ?? ''),
        PatientName: String(c.PatientName ?? ''),
        TotalCharge: Number(c.TotalCharge),
        PaymentAmount: Number(c.PaymentAmount),
        Lines: [...(c.Lines ?? [])].map((L) => ({
          ServiceCode: String(L.ServiceCode ?? ''),
          ChargeAmount: Number(L.ChargeAmount),
          AdjudicatedAmount: Number(L.AdjudicatedAmount),
        })),
      })),
    };
  }
  return toJson(esSchema, msg, { emitDefaultValues: true });
}

export const protobufEsSer = {
  name: 'protobuf-es',
  version: pkgVersion('@bufbuild/protobuf'),
  category: 'schema',
  supports: baseSupports,
  prepare(dataName) {
    esDataName = dataName;
    esSchema = esSchemaByName[dataName];
    if (!esSchema) throw new Error(`protobuf-es: no schema for ${dataName}`);
  },
  serialize(value) {
    const msg = create(esSchema, toEsInput(esDataName, value));
    return Buffer.from(toBinary(esSchema, msg));
  },
  deserialize(buf) {
    const msg = fromBinary(esSchema, buf instanceof Uint8Array ? buf : new Uint8Array(buf));
    return fromEsMessage(esDataName, msg);
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
    // devalue produces a JS expression string; store as UTF-8 bytes
    return Buffer.from(devalueStringify(value), 'utf8');
  },
  deserialize(buf) {
    return devalueParse(Buffer.from(buf).toString('utf8'));
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
    const view = BebopView.getInstance();
    view.startWriting();
    bebopWriteAny(view, value);
    return Buffer.from(view.toArray());
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
    siaWriter.offset = 0;
    // reset write position: Sia may not have seek for write — recreate or set offset
    siaWriter.seek(0);
    // If seek only for read, assign offset
    siaWriter.offset = 0;
    siaWriteAnyFixed(siaWriter, value);
    return Buffer.from(siaWriter.content.subarray(0, siaWriter.offset));
  },
  deserialize(buf) {
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    // copy into reader content at start
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
    siaReader.seek(0);
    siaReader.offset = 0;
    return siaReadAny(siaReader);
  },
};

export function modernSerializers() {
  return [protobufEsSer, jsonPackMsgpackSer, devalueSer, bebopSer, siaSer];
}
