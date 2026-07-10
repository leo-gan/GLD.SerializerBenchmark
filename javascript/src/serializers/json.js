import fastJson from 'fast-json-stringify';
import { pkgVersion, baseSupports, bufToUtf8 } from './common.js';

let simdjson = null;
try {
  simdjson = await import('simdjson');
} catch {
  /* optional native addon */
}

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

const objectGraphSchema = {
  title: 'ObjectGraph',
  type: 'object',
  properties: {
    root: { type: 'integer' },
    nodes: {
      type: 'array',
      items: {
        type: 'object',
        properties: {
          Name: { type: 'string' },
          Parent: { type: 'integer' },
          Related: { type: 'integer' },
          Children: { type: 'array', items: { type: 'integer' } },
        },
      },
    },
  },
};

export const jsonBuiltin = {
  name: 'JSON.stringify',
  version: `node-${process.versions.node}`,
  category: 'json',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    // Optimal: single stringify; Buffer.from(string) is the Node wire representation.
    return Buffer.from(JSON.stringify(value), 'utf8');
  },
  deserialize(buf) {
    // Optimal: avoid double Buffer wrap when already a Buffer.
    return JSON.parse(bufToUtf8(buf));
  },
};

let fjsStringify = null;
export const fastJsonSer = {
  name: 'fast-json-stringify',
  version: pkgVersion('fast-json-stringify'),
  category: 'json',
  supports: baseSupports,
  prepare(dataName, value) {
    // Compile once per fixture outside the timed path (package contract).
    if (dataName === 'Person') {
      fjsStringify = fastJson(personSchema);
    } else if (dataName === 'ObjectGraph') {
      fjsStringify = fastJson(objectGraphSchema);
    } else if (dataName === 'Integer') {
      fjsStringify = fastJson({ type: 'integer' });
    } else if (Array.isArray(value)) {
      // Batch N>1: array of objects (Data Model v2)
      fjsStringify = fastJson({
        type: 'array',
        items: { type: 'object', additionalProperties: true },
      });
    } else {
      fjsStringify = fastJson({
        type: typeof value === 'object' && value !== null ? 'object' : 'integer',
        additionalProperties: true,
      });
    }
  },
  serialize(value) {
    return Buffer.from(fjsStringify(value), 'utf8');
  },
  deserialize(buf) {
    return JSON.parse(bufToUtf8(buf));
  },
};

/** Honest name: serialize is std JSON.stringify; only deserialize uses SIMD. */
export const simdjsonSer = {
  name: 'simdjson-parse+JSON.stringify',
  version: pkgVersion('simdjson') || 'optional-missing',
  category: 'json',
  supports: (n) => baseSupports(n) && !!simdjson,
  prepare() {},
  serialize(value) {
    return Buffer.from(JSON.stringify(value), 'utf8');
  },
  deserialize(buf) {
    if (!simdjson) throw new Error('simdjson not installed');
    const mod = simdjson.default || simdjson;
    // simdjson parse expects a string
    return mod.parse(bufToUtf8(buf));
  },
};

export function jsonSerializers() {
  const list = [jsonBuiltin, fastJsonSer];
  if (simdjson) list.push(simdjsonSer);
  return list;
}
