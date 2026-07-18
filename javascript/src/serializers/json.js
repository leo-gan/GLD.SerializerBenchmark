import fastJson from 'fast-json-stringify';
import { pkgVersion, baseSupports, bufToUtf8 } from './common.js';

let simdjson = null;
try {
  simdjson = await import('simdjson');
} catch {
  /* optional native addon */
}

/** JSON Schema shapes for official V2 types (fast-json-stringify). */
const v2JsonSchemas = {
  message: {
    title: 'Message',
    type: 'object',
    properties: {
      f_bool: { type: 'boolean' },
      f_int32: { type: 'integer' },
      f_int64: { type: 'integer' },
      f_float64: { type: 'number' },
      f_string: { type: 'string' },
      f_bool_2: { type: 'boolean' },
      f_int32_2: { type: 'integer' },
      f_string_2: { type: 'string' },
    },
  },
  document: {
    title: 'Document',
    type: 'object',
    properties: {
      id: { type: 'string' },
      status: { type: 'integer' },
      meta: {
        type: 'object',
        properties: {
          region: { type: 'string' },
          version: { type: 'integer' },
        },
      },
      items: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            sku: { type: 'string' },
            qty: { type: 'integer' },
            price_minor: { type: 'integer' },
          },
        },
      },
    },
  },
  telemetry: {
    title: 'Telemetry',
    type: 'object',
    properties: {
      source: { type: 'string' },
      ts: { type: 'integer' },
      tags: { type: 'array', items: { type: 'string' } },
      values: { type: 'array', items: { type: 'number' } },
    },
  },
  strings: {
    title: 'Strings',
    type: 'object',
    properties: {
      items: { type: 'array', items: { type: 'string' } },
    },
  },
  event: {
    title: 'Event',
    type: 'object',
    properties: {
      event_id: { type: 'string' },
      event_type: { type: 'string' },
      occurred_at: { type: 'integer' },
      producer: { type: 'string' },
      attrs: {
        type: 'array',
        items: {
          type: 'object',
          properties: {
            key: { type: 'string' },
            value: { type: 'string' },
          },
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
    if (Array.isArray(value)) {
      const itemSchema = v2JsonSchemas[dataName] || {
        type: 'object',
        additionalProperties: true,
      };
      fjsStringify = fastJson({ type: 'array', items: itemSchema });
    } else if (v2JsonSchemas[dataName]) {
      fjsStringify = fastJson(v2JsonSchemas[dataName]);
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
