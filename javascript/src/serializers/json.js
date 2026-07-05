import fastJson from 'fast-json-stringify';
import { pkgVersion, baseSupports } from './common.js';

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

export const jsonBuiltin = {
  name: 'JSON.stringify',
  version: `node-${process.versions.node}`,
  category: 'json',
  supports: baseSupports,
  prepare() {},
  serialize(value) {
    return Buffer.from(JSON.stringify(value), 'utf8');
  },
  deserialize(buf) {
    return JSON.parse(Buffer.from(buf).toString('utf8'));
  },
};

let fjsStringify = null;
export const fastJsonSer = {
  name: 'fast-json-stringify',
  version: pkgVersion('fast-json-stringify'),
  category: 'json',
  supports: baseSupports,
  prepare(dataName, value) {
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

export const simdjsonSer = {
  name: 'simdjson',
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
    return mod.parse(Buffer.from(buf).toString('utf8'));
  },
};

export function jsonSerializers() {
  const list = [jsonBuiltin, fastJsonSer];
  if (simdjson) list.push(simdjsonSer);
  return list;
}
