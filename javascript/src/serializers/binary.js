import { Packr, Unpackr } from 'msgpackr';
import * as msgpackOfficial from '@msgpack/msgpack';
import { Encoder as CborXEncoder, Decoder as CborXDecoder } from 'cbor-x';
import cbor from 'cbor';
import { BSON } from 'bson';
import bser from 'bser';
import { pkgVersion, baseSupports, asBuffer } from './common.js';

// Reuse encoder instances (msgpackr docs: Packr/Unpackr are stateful and reusable).
const packr = new Packr({ useRecords: false, structuredClone: false });
const unpackr = new Unpackr({ useRecords: false });

export const msgpackrSer = {
  name: 'msgpackr',
  version: pkgVersion('msgpackr'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return packr.pack(value);
  },
  deserialize(buf) {
    return unpackr.unpack(asBuffer(buf));
  },
};

export const msgpackOffSer = {
  name: '@msgpack/msgpack',
  version: pkgVersion('@msgpack/msgpack'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // encode returns Uint8Array; avoid Buffer.from copy (runner accepts length).
    return msgpackOfficial.encode(value);
  },
  deserialize(buf) {
    // decode accepts Uint8Array / ArrayBuffer views without requiring Buffer.
    const u8 = buf instanceof Uint8Array ? buf : new Uint8Array(buf);
    return msgpackOfficial.decode(u8);
  },
};

const cborxEnc = new CborXEncoder();
const cborxDec = new CborXDecoder();
export const cborxSer = {
  name: 'cbor-x',
  version: pkgVersion('cbor-x'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return cborxEnc.encode(value);
  },
  deserialize(buf) {
    return cborxDec.decode(buf instanceof Uint8Array ? buf : new Uint8Array(buf));
  },
};

export const cborSer = {
  name: 'cbor',
  version: pkgVersion('cbor'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // encodeOne: single-value encode (avoids accidental multi-value framing).
    // https://github.com/hildjj/node-cbor
    return typeof cbor.encodeOne === 'function' ? cbor.encodeOne(value) : cbor.encode(value);
  },
  deserialize(buf) {
    const b = asBuffer(buf);
    // decodeFirstSync is the recommended sync path for a complete buffer.
    return cbor.decodeFirstSync(b);
  },
};

export const bsonSer = {
  name: 'bson',
  version: pkgVersion('bson'),
  category: 'binary',
  // BSON top-level must be a document (V2 types are always plain objects / arrays of objects).
  supports: baseSupports,
  _wrapped: false,
  prepare(_dataName, value) {
    this._wrapped = Array.isArray(value) || typeof value !== 'object' || value === null;
  },
  serialize(value) {
    const doc =
      typeof value === 'object' && value !== null && !Array.isArray(value) ? value : { v: value };
    return BSON.serialize(doc);
  },
  deserialize(buf) {
    // BSON.serialize returns Buffer; deserialize accepts Buffer/Uint8Array.
    const doc = BSON.deserialize(asBuffer(buf));
    if (this._wrapped && doc && Object.prototype.hasOwnProperty.call(doc, 'v')) {
      return doc.v;
    }
    return doc;
  },
};

export const bserSer = {
  name: 'bser',
  version: pkgVersion('bser'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return bser.dumpToBuffer(value);
  },
  deserialize(buf) {
    return bser.loadFromBuffer(asBuffer(buf));
  },
};

export function binarySerializers() {
  return [msgpackrSer, msgpackOffSer, cborxSer, cborSer, bsonSer, bserSer];
}
