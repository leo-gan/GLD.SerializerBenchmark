import { Packr, Unpackr } from 'msgpackr';
import * as msgpackOfficial from '@msgpack/msgpack';
import { Encoder as CborXEncoder, Decoder as CborXDecoder } from 'cbor-x';
import cbor from 'cbor';
import { BSON } from 'bson';
import bser from 'bser';
import { pkgVersion, baseSupports } from './common.js';

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
    return unpackr.unpack(buf);
  },
};

export const msgpackOffSer = {
  name: '@msgpack/msgpack',
  version: pkgVersion('@msgpack/msgpack'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(msgpackOfficial.encode(value));
  },
  deserialize(buf) {
    return msgpackOfficial.decode(buf);
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
    return cborxDec.decode(buf);
  },
};

export const cborSer = {
  name: 'cbor',
  version: pkgVersion('cbor'),
  category: 'binary',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return cbor.encode(value);
  },
  deserialize(buf) {
    return cbor.decodeFirstSync(buf);
  },
};

export const bsonSer = {
  name: 'bson',
  version: pkgVersion('bson'),
  category: 'binary',
  // BSON top-level must be a document
  supports: (n) => baseSupports(n) && n !== 'Integer',
  prepare() {},
  serialize(value) {
    const doc = typeof value === 'object' && value !== null && !Array.isArray(value) ? value : { v: value };
    return BSON.serialize(doc);
  },
  deserialize(buf) {
    return BSON.deserialize(Buffer.from(buf));
  },
};

export const bserSer = {
  name: 'bser',
  version: pkgVersion('bser'),
  category: 'binary',
  supports: (n) => baseSupports(n) && n !== 'Integer',
  prepare() {},
  serialize(value) {
    return bser.dumpToBuffer(value);
  },
  deserialize(buf) {
    return bser.loadFromBuffer(buf);
  },
};

export function binarySerializers() {
  return [msgpackrSer, msgpackOffSer, cborxSer, cborSer, bsonSer, bserSer];
}
