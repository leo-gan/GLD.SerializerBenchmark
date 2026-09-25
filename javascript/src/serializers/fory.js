import { createRequire } from 'node:module';
import { pkgVersion } from './common.js';

const require = createRequire(import.meta.url);
const { default: Fory, Type } = require('@apache-fory/core');
const struct = (name, fields) => Type.struct({ typeName: `benchmark.${name}` }, fields);
const meta = struct('DocumentMeta', { region: Type.string(), version: Type.int32() });
const item = struct('DocumentItem', {
  sku: Type.string(), qty: Type.int32(), price_minor: Type.int64(),
});
const attr = struct('EventAttr', { key: Type.string(), value: Type.string() });
const schemas = {
  message: struct('Message', {
    f_bool: Type.bool(), f_int32: Type.int32(), f_int64: Type.int64(),
    f_float64: Type.float64(), f_string: Type.string(), f_bool_2: Type.bool(),
    f_int32_2: Type.int32(), f_string_2: Type.string(),
  }),
  document: struct('Document', {
    id: Type.string(), status: Type.int32(), meta, items: Type.list(item),
  }),
  telemetry: struct('Telemetry', {
    source: Type.string(), ts: Type.int64(), tags: Type.list(Type.string()),
    values: Type.list(Type.float64()),
  }),
  strings: struct('Strings', { items: Type.list(Type.string()) }),
  event: struct('Event', {
    event_id: Type.string(), event_type: Type.string(), occurred_at: Type.int64(),
    producer: Type.string(), attrs: Type.list(attr),
  }),
};

const fory = new Fory({ refTracking: false, compatible: false });
const codecs = Object.fromEntries(Object.entries(schemas).map(([name, schema]) => [name, {
  single: fory.register(schema),
  batch: fory.register(Type.list(schema)),
}]));

export const forySer = {
  name: 'fory',
  version: pkgVersion('@apache-fory/core'),
  category: 'binary',
  supports: (name) => name in schemas,
  prepare(name, value) {
    // All roots share one registry, fully registered before the first operation.
    this.codec = codecs[name][Array.isArray(value) ? 'batch' : 'single'];
    this.codec.deserialize(this.codec.serialize(value));
  },
  serialize(value) { return this.codec.serialize(value); },
  deserialize(bytes) { return this.codec.deserialize(bytes); },
  toDomain(value) {
    // int64 decodes as bigint; the suite uses safe-integer numbers. Untimed.
    const convert = (v) => {
      if (typeof v === 'bigint') return Number(v);
      if (Array.isArray(v)) return v.map(convert);
      if (v && typeof v === 'object') {
        return Object.fromEntries(Object.entries(v).map(([k, x]) => [k, convert(x)]));
      }
      return v;
    };
    return convert(value);
  },
};
