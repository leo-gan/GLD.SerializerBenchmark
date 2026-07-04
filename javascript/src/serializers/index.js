/**
 * Serializer registry. Each entry exposes optimal recommended APIs.
 * prepare() runs outside the timed loop.
 */

import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { deepEqual } from '../data.js';
import v8 from 'node:v8';
import { performance } from 'node:perf_hooks';

const require = createRequire(import.meta.url);

/** Installed npm package version for CSV SerializerVersion (full semver). */
function pkgVersion(packageName) {
  try {
    return require(`${packageName}/package.json`).version || '';
  } catch {
    /* package.json may be blocked by "exports"; walk up from resolved entry */
  }
  try {
    let dir = dirname(require.resolve(packageName));
    for (let i = 0; i < 8; i++) {
      try {
        const raw = readFileSync(join(dir, 'package.json'), 'utf8');
        const v = JSON.parse(raw).version;
        if (v) return String(v);
      } catch {
        /* continue */
      }
      const parent = dirname(dir);
      if (parent === dir) break;
      dir = parent;
    }
  } catch {
    /* missing package */
  }
  return '';
}

// Lazy-loaded optionals
let simdjson = null;
try {
  simdjson = await import('simdjson');
} catch {
  /* optional */
}

import fastJson from 'fast-json-stringify';
import { Packr, Unpackr } from 'msgpackr';
import * as msgpackOfficial from '@msgpack/msgpack';
import { Encoder as CborXEncoder, Decoder as CborXDecoder } from 'cbor-x';
import cbor from 'cbor';
import avro from 'avsc';
import protobuf from 'protobufjs';
import { BSON } from 'bson';
import bser from 'bser';

/** @typedef {{ name: string, version: string, supports: (n:string)=>boolean, prepare: (name:string, value:any)=>void, serialize: (value:any)=>Buffer|Uint8Array, deserialize: (buf:Buffer|Uint8Array)=>any }} Ser */

const personSchema = {
  title: 'Person',
  type: 'object',
  properties: {
    FirstName: { type: 'string' },
    LastName: { type: 'string' },
    Age: { type: 'integer' },
    Gender: { type: 'integer' },
    Passport: {
      type: 'object',
      properties: {
        Number: { type: 'string' },
        Authority: { type: 'string' },
        ExpirationDate: { type: 'string' },
      },
    },
    PoliceRecords: {
      type: 'array',
      items: {
        type: 'object',
        properties: { Id: { type: 'integer' }, CrimeCode: { type: 'string' } },
      },
    },
  },
};

function baseSupports(name) {
  return name !== 'ObjectGraph';
}

// 1. JSON.stringify / parse (baseline)
const jsonBuiltin = {
  name: 'JSON.stringify',
  version: `node-${process.versions.node}`,
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(JSON.stringify(value), 'utf8');
  },
  deserialize(buf) {
    return JSON.parse(Buffer.from(buf).toString('utf8'));
  },
};

// 2. fast-json-stringify (schema compiled once in prepare)
let fjsStringify = null;
const fastJsonSer = {
  name: 'fast-json-stringify',
  version: pkgVersion('fast-json-stringify'),
  supports: baseSupports,
  prepare(dataName, value) {
    // Compile a permissive schema from runtime shape for non-Person; Person uses static schema
    if (dataName === 'Person') {
      fjsStringify = fastJson(personSchema);
    } else if (dataName === 'Integer') {
      fjsStringify = fastJson({ type: 'integer' });
    } else {
      fjsStringify = fastJson({
        type: typeof value === 'object' && !Array.isArray(value) ? 'object' : 'integer',
        additionalProperties: true,
      });
    }
  },
  serialize(value) {
    return Buffer.from(fjsStringify(value), 'utf8');
  },
  deserialize(buf) {
    return JSON.parse(Buffer.from(buf).toString('utf8'));
  },
};

// 3. simdjson (optional native addon)
const simdjsonSer = {
  name: 'simdjson',
  version: pkgVersion('simdjson') || 'optional-missing',
  supports: (n) => baseSupports(n) && !!simdjson,
  prepare() {},
  serialize(value) {
    return Buffer.from(JSON.stringify(value), 'utf8');
  },
  deserialize(buf) {
    if (!simdjson) throw new Error('simdjson not installed');
    const mod = simdjson.default || simdjson;
    return mod.parse(Buffer.from(buf).toString('utf8'));
  },
};

// 4. msgpackr
const packr = new Packr({ useRecords: false, structuredClone: false });
const unpackr = new Unpackr({ useRecords: false });
const msgpackrSer = {
  name: 'msgpackr',
  version: pkgVersion('msgpackr'),
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return packr.pack(value);
  },
  deserialize(buf) {
    return unpackr.unpack(buf);
  },
};

// 5. @msgpack/msgpack
const msgpackOffSer = {
  name: '@msgpack/msgpack',
  version: pkgVersion('@msgpack/msgpack'),
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(msgpackOfficial.encode(value));
  },
  deserialize(buf) {
    return msgpackOfficial.decode(buf);
  },
};

// 6. cbor-x
const cborxEnc = new CborXEncoder();
const cborxDec = new CborXDecoder();
const cborxSer = {
  name: 'cbor-x',
  version: pkgVersion('cbor-x'),
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return cborxEnc.encode(value);
  },
  deserialize(buf) {
    return cborxDec.decode(buf);
  },
};

// 7. cbor (node-cbor)
const cborSer = {
  name: 'cbor',
  version: pkgVersion('cbor'),
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return cbor.encode(value);
  },
  deserialize(buf) {
    return cbor.decodeFirstSync(buf);
  },
};

// 8. avsc — build type from value sample in prepare; normalize floats for Avro double fidelity
let avroType = null;
function avroNormalize(value) {
  return JSON.parse(JSON.stringify(value));
}
const avscSer = {
  name: 'avsc',
  version: pkgVersion('avsc'),
  // Avro double/float inference is brittle on randomly generated f64 telemetry/EDI payloads
  supports: (n) => baseSupports(n) && !['Integer', 'Telemetry', 'EDI_835'].includes(n),
  prepare(_name, value) {
    avroType = avro.Type.forValue(avroNormalize(value));
  },
  serialize(value) {
    return avroType.toBuffer(avroNormalize(value));
  },
  deserialize(buf) {
    return avroType.fromBuffer(Buffer.from(buf));
  },
};

// 9. protobufjs — dynamic type from JSON schema-ish message
let pbType = null;
const pbRoot = protobuf.Root.fromJSON({
  nested: {
    Person: {
      fields: {
        FirstName: { type: 'string', id: 1 },
        LastName: { type: 'string', id: 2 },
        Age: { type: 'int32', id: 3 },
        Gender: { type: 'int32', id: 4 },
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
    Wrapper: {
      fields: {
        json: { type: 'string', id: 1 },
      },
    },
  },
});
const pbSer = {
  name: 'protobufjs',
  version: pkgVersion('protobufjs'),
  supports: baseSupports,
  prepare(dataName) {
    // Always use JSON-wrapper for full fidelity across all fixtures; Person/Simple
    // schemas are incomplete (missing nested Passport/PoliceRecords). Optimal path
    // for real schemas is preloaded Type.encode/decode — see docs.
    pbType = pbRoot.lookupType('Wrapper');
  },
  serialize(value) {
    const msg = pbType.create({ json: JSON.stringify(value) });
    return pbType.encode(msg).finish();
  },
  deserialize(buf) {
    const decoded = pbType.decode(buf);
    return JSON.parse(decoded.json);
  },
};

// 10. bson
const bsonSer = {
  name: 'bson',
  version: pkgVersion('bson'),
  supports: (n) => baseSupports(n) && n !== 'Integer',
  prepare() {},
  serialize(value) {
    // BSON requires document (object)
    const doc = typeof value === 'object' ? value : { v: value };
    return BSON.serialize(doc);
  },
  deserialize(buf) {
    return BSON.deserialize(Buffer.from(buf));
  },
};

// 11. v8 serialize
const v8Ser = {
  name: 'v8-serializer',
  version: `v8-${process.versions.v8}`,
  supports: () => true,
  prepare() {},
  serialize(value) {
    return v8.serialize(value);
  },
  deserialize(buf) {
    return v8.deserialize(Buffer.from(buf));
  },
};

// 12. bser
const bserSer = {
  name: 'bser',
  version: pkgVersion('bser'),
  supports: (n) => baseSupports(n) && n !== 'Integer',
  prepare() {},
  serialize(value) {
    return bser.dumpToBuffer(value);
  },
  deserialize(buf) {
    return bser.loadFromBuffer(Buffer.from(buf));
  },
};

export const ALL_SERIALIZERS = [
  jsonBuiltin,
  fastJsonSer,
  simdjsonSer,
  msgpackrSer,
  msgpackOffSer,
  cborxSer,
  cborSer,
  avscSer,
  pbSer,
  bsonSer,
  v8Ser,
  bserSer,
].filter((s) => {
  // drop simdjson if unavailable at runtime
  if (s.name === 'simdjson' && !simdjson) return false;
  return true;
});

export { deepEqual, performance };
