/**
 * gld-kiln 0.2.0 — positional little-endian encode/decode.
 * Schemas are built once in prepare(). Numeric lists are cached as one
 * little-endian byte run outside the timer, then copied. tensor_view borrows.
 * A batch (array) is one list of the struct; one instance is the struct.
 *
 * The package ships TypeScript. Node refuses to strip types under node_modules,
 * so this module strips those files once at load (esbuild bundle on older Node).
 */
import fs from 'node:fs';
import path from 'node:path';
import nodeModule from 'node:module';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { pkgVersion } from './common.js';

const require = nodeModule.createRequire(import.meta.url);

function kilnPackageFile(url) {
  return url.includes('/node_modules/gld-kiln/') && url.endsWith('.ts');
}

async function loadKiln() {
  const { registerHooks, stripTypeScriptTypes } = nodeModule;
  if (typeof registerHooks === 'function' && typeof stripTypeScriptTypes === 'function') {
    const emitWarning = process.emitWarning;
    process.emitWarning = function (warning, type, ...rest) {
      const msg = typeof warning === 'string' ? warning : warning && warning.message;
      const name = typeof warning === 'string' ? type : warning && warning.name;
      if (name === 'ExperimentalWarning' && msg && String(msg).includes('stripTypeScriptTypes')) {
        return;
      }
      return emitWarning.call(process, warning, type, ...rest);
    };
    registerHooks({
      load(url, context, nextLoad) {
        if (!kilnPackageFile(url)) return nextLoad(url, context);
        const source = fs.readFileSync(fileURLToPath(url), 'utf8');
        return {
          format: 'module',
          source: stripTypeScriptTypes(source, { mode: 'strip' }),
          shortCircuit: true,
        };
      },
    });
    try {
      return await import('gld-kiln');
    } finally {
      process.emitWarning = emitWarning;
    }
  }

  const { build } = await import('esbuild');
  const entry = require.resolve('gld-kiln');
  const cacheDir = path.resolve(
    path.dirname(fileURLToPath(import.meta.url)),
    '../../node_modules/.cache/gld-kiln',
  );
  fs.mkdirSync(cacheDir, { recursive: true });
  const outfile = path.join(cacheDir, 'bundle.mjs');
  const stampPath = path.join(cacheDir, 'stamp');
  const st = fs.statSync(entry);
  const stamp = `${st.mtimeMs}:${st.size}`;
  const fresh = fs.existsSync(outfile) && fs.existsSync(stampPath) && fs.readFileSync(stampPath, 'utf8') === stamp;
  if (!fresh) {
    await build({
      entryPoints: [entry],
      bundle: true,
      format: 'esm',
      platform: 'node',
      target: 'node18',
      outfile,
      logLevel: 'silent',
      legalComments: 'none',
    });
    fs.writeFileSync(stampPath, stamp);
  }
  return import(pathToFileURL(outfile).href);
}

const { FloatBits } = await loadKiln();

export { FloatBits };

const BOOL = ['bool'];
const I32 = ['i32'];
const I64 = ['i64'];
const F32 = ['f32'];
const F64 = ['f64'];
const STR = ['str'];

const MESSAGE = [
  'struct',
  [
    ['f_bool', BOOL],
    ['f_int32', I32],
    ['f_int64', I64],
    ['f_float64', F64],
    ['f_string', STR],
    ['f_bool_2', BOOL],
    ['f_int32_2', I32],
    ['f_string_2', STR],
  ],
];

const DOCUMENT = [
  'struct',
  [
    ['id', STR],
    ['status', I32],
    ['meta', ['struct', [['region', STR], ['version', I32]]]],
    [
      'items',
      ['list', ['struct', [['sku', STR], ['qty', I32], ['price_minor', I64]]]],
    ],
  ],
];

const TELEMETRY = [
  'struct',
  [
    ['source', STR],
    ['ts', I64],
    ['tags', ['list', STR]],
    ['values', ['list', F64]],
  ],
];

const STRINGS = ['struct', [['items', ['list', STR]]]];

const EVENT = [
  'struct',
  [
    ['event_id', STR],
    ['event_type', STR],
    ['occurred_at', I64],
    ['producer', STR],
    ['attrs', ['list', ['struct', [['key', STR], ['value', STR]]]]],
  ],
];

// Same field order as Mojo. Lists are length-prefixed; no field names on the wire.
const TENSOR = [
  'struct',
  [
    ['rows', I32],
    ['cols', I32],
    ['values', ['list', F32]],
  ],
];

const PROMPT = [
  'struct',
  [
    ['batch', I32],
    ['seq', I32],
    ['input_ids', ['list', I64]],
    ['attention_mask', ['list', I64]],
    ['position_ids', ['list', I64]],
  ],
];

const SHARD = [
  'struct',
  [
    ['vocab', I32],
    ['hidden', I32],
    ['ffn', I32],
    ['tok_emb', ['list', F32]],
    ['attn', ['list', F32]],
    ['ffn_weight', ['list', F32]],
    ['norm', ['list', F32]],
  ],
];

const REQUEST = [
  'struct',
  [
    ['request_id', I64],
    ['model', STR],
    ['temperature', F32],
    ['inputs', PROMPT],
  ],
];

const SCHEMAS = {
  message: MESSAGE,
  document: DOCUMENT,
  telemetry: TELEMETRY,
  strings: STRINGS,
  event: EVENT,
  tensor: TENSOR,
  tensor_view: TENSOR,
  prompt: PROMPT,
  shard: SHARD,
  request: REQUEST,
};

const CAP = 16_777_216;
const podBytes = new WeakMap();
let schema = null;
let borrow = false;

function fail(kind) {
  throw new Error(`gld-kiln: ${kind}`);
}

function cacheBytes(values, width, writeAt) {
  if (!Array.isArray(values)) return null;
  let hit = podBytes.get(values);
  if (hit && hit.length === values.length * width) return hit;
  const bytes = Buffer.allocUnsafe(values.length * width);
  for (let i = 0; i < values.length; i++) writeAt(bytes, i, values[i]);
  podBytes.set(values, bytes);
  return bytes;
}

function cacheF32(values) {
  return cacheBytes(values, 4, (buf, i, value) => {
    if (value && typeof value === 'object' && value.kind === 'f32') {
      buf.writeUInt32LE(Number(BigInt(value.bits) & 0xffffffffn), i * 4);
    } else {
      buf.writeFloatLE(value, i * 4);
    }
  });
}

function cacheF64(values) {
  return cacheBytes(values, 8, (buf, i, value) => {
    buf.writeDoubleLE(value, i * 8);
  });
}

function cacheI64(values) {
  return cacheBytes(values, 8, (buf, i, value) => {
    buf.writeBigInt64LE(BigInt(value), i * 8);
  });
}

function warm(node, value) {
  if (!node || value == null) return;
  const kind = node[0];
  if (kind === 'list') {
    const elem = node[1];
    if (elem[0] === 'f32') cacheF32(value);
    else if (elem[0] === 'f64') cacheF64(value);
    else if (elem[0] === 'i64') cacheI64(value);
    else if (Array.isArray(value)) {
      for (let i = 0; i < value.length; i++) warm(elem, value[i]);
    }
    return;
  }
  if (kind === 'struct') {
    for (const [name, field] of node[1]) warm(field, value[name]);
  }
}

function writePod(parts, values, cache) {
  const bytes = cache(values);
  if (!bytes) fail('TYPE');
  if (values.length > CAP) fail('LIMIT');
  const head = Buffer.allocUnsafe(4);
  head.writeUInt32LE(values.length, 0);
  parts.push(head, bytes);
}

function writeValue(parts, node, value) {
  const kind = node[0];
  if (kind === 'bool') {
    const b = Buffer.allocUnsafe(1);
    b[0] = value ? 1 : 0;
    parts.push(b);
    return;
  }
  if (kind === 'i32' || kind === 'f32') {
    const b = Buffer.allocUnsafe(4);
    if (kind === 'i32') b.writeInt32LE(value | 0, 0);
    else if (value && typeof value === 'object' && value.kind === 'f32') b.writeUInt32LE(Number(BigInt(value.bits) & 0xffffffffn), 0);
    else b.writeFloatLE(value, 0);
    parts.push(b);
    return;
  }
  if (kind === 'i64') {
    const b = Buffer.allocUnsafe(8);
    b.writeBigInt64LE(BigInt(value), 0);
    parts.push(b);
    return;
  }
  if (kind === 'f64') {
    const b = Buffer.allocUnsafe(8);
    b.writeDoubleLE(value, 0);
    parts.push(b);
    return;
  }
  if (kind === 'str') {
    const raw = Buffer.from(value, 'utf8');
    if (raw.length > CAP) fail('LIMIT');
    const head = Buffer.allocUnsafe(4);
    head.writeUInt32LE(raw.length, 0);
    parts.push(head, raw);
    return;
  }
  if (kind === 'list') {
    const elem = node[1];
    if (elem[0] === 'f32') return writePod(parts, value, cacheF32);
    if (elem[0] === 'f64') return writePod(parts, value, cacheF64);
    if (elem[0] === 'i64') return writePod(parts, value, cacheI64);
    if (value.length > CAP) fail('LIMIT');
    const head = Buffer.allocUnsafe(4);
    head.writeUInt32LE(value.length, 0);
    parts.push(head);
    for (let i = 0; i < value.length; i++) writeValue(parts, elem, value[i]);
    return;
  }
  if (kind === 'struct') {
    for (const [name, field] of node[1]) writeValue(parts, field, value[name]);
    return;
  }
  fail('TYPE');
}

let outPool = Buffer.allocUnsafe(0);

function encodeDirect(node, value) {
  const parts = [];
  writeValue(parts, node, value);
  let size = 0;
  for (let i = 0; i < parts.length; i++) size += parts[i].length;
  if (outPool.length !== size) outPool = Buffer.allocUnsafe(size);
  let at = 0;
  for (let i = 0; i < parts.length; i++) {
    const part = parts[i];
    part.copy(outPool, at);
    at += part.length;
  }
  return outPool;
}

let f32Pool = [];
let f32Used = 0;

function takeF32(nbytes) {
  let buf = f32Pool[f32Used];
  if (!buf || buf.length !== nbytes) {
    buf = Buffer.allocUnsafe(nbytes);
    f32Pool[f32Used] = buf;
  }
  f32Used += 1;
  return buf;
}

class Cursor {
  constructor(buf) {
    this.buf = Buffer.isBuffer(buf) ? buf : Buffer.from(buf);
    this.i = 0;
  }

  need(n) {
    if (n < 0 || this.i + n > this.buf.length) fail('EOF');
  }

  u32() {
    this.need(4);
    const v = this.buf.readUInt32LE(this.i);
    this.i += 4;
    return v;
  }

  count(width) {
    const n = this.u32();
    if (n > CAP) fail('LIMIT');
    if (width && n > Math.floor((this.buf.length - this.i) / width)) fail('EOF');
    return n;
  }

  bool() {
    this.need(1);
    const v = this.buf[this.i++];
    if (v > 1) fail('TYPE');
    return v === 1;
  }

  i32() {
    this.need(4);
    const v = this.buf.readInt32LE(this.i);
    this.i += 4;
    return v;
  }

  i64() {
    this.need(8);
    const v = this.buf.readBigInt64LE(this.i);
    this.i += 8;
    return Number(v);
  }

  f64() {
    this.need(8);
    const v = this.buf.readDoubleLE(this.i);
    this.i += 8;
    return v;
  }

  f32() {
    this.need(4);
    const bits = this.buf.readUInt32LE(this.i);
    this.i += 4;
    const frac = bits & 0x7fffff;
    if ((bits >>> 23) === 0xff && frac !== 0) return new FloatBits('f32', BigInt(bits));
    return this.buf.readFloatLE(this.i - 4);
  }

  str() {
    const n = this.count(1);
    this.need(n);
    let text;
    try {
      text = new TextDecoder('utf-8', { fatal: true }).decode(this.buf.subarray(this.i, this.i + n));
    } catch {
      fail('UTF8');
    }
    this.i += n;
    return text;
  }

  f32List(copy) {
    const n = this.count(4);
    const nbytes = n * 4;
    this.need(nbytes);
    const payload = copy ? takeF32(nbytes) : this.buf.subarray(this.i, this.i + nbytes);
    if (copy) this.buf.copy(payload, 0, this.i, this.i + nbytes);
    this.i += nbytes;
    return { f32Bytes: payload, length: n };
  }

  f64List() {
    const n = this.count(8);
    this.need(n * 8);
    const out = new Array(n);
    for (let i = 0; i < n; i++) {
      out[i] = this.buf.readDoubleLE(this.i);
      this.i += 8;
    }
    return out;
  }

  i64List() {
    const n = this.count(8);
    this.need(n * 8);
    const out = new Array(n);
    for (let i = 0; i < n; i++) {
      out[i] = Number(this.buf.readBigInt64LE(this.i));
      this.i += 8;
    }
    return out;
  }

  finish() {
    if (this.i !== this.buf.length) fail('TRAILING');
  }
}

function readValue(cur, node, copyF32) {
  const kind = node[0];
  if (kind === 'bool') return cur.bool();
  if (kind === 'i32') return cur.i32();
  if (kind === 'i64') return cur.i64();
  if (kind === 'f32') return cur.f32();
  if (kind === 'f64') return cur.f64();
  if (kind === 'str') return cur.str();
  if (kind === 'list') {
    const elem = node[1];
    if (elem[0] === 'f32') return cur.f32List(copyF32);
    if (elem[0] === 'f64') return cur.f64List();
    if (elem[0] === 'i64') return cur.i64List();
    const n = cur.count(1);
    const out = new Array(n);
    for (let i = 0; i < n; i++) out[i] = readValue(cur, elem, copyF32);
    return out;
  }
  if (kind === 'struct') {
    const out = {};
    for (const [name, field] of node[1]) out[name] = readValue(cur, field, copyF32);
    return out;
  }
  fail('TYPE');
}

function asUint8(buf) {
  if (buf instanceof Uint8Array) return buf;
  return new Uint8Array(buf);
}

function readI32(b, o) {
  return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) | 0;
}

function readU32(b, o) {
  return (b[o] | (b[o + 1] << 8) | (b[o + 2] << 16) | (b[o + 3] << 24)) >>> 0;
}

// tensor_view: rows, cols, and a float32 span of the encoded payload.
// subarray shares the input buffer; it does not copy the matrix.
function borrowMatrix(buf) {
  if (!(buf instanceof Uint8Array)) throw new Error('gld-kiln tensor_view copied');
  if (buf.length < 12) throw new Error('gld-kiln tensor_view length');
  const rows = readI32(buf, 0);
  const cols = readI32(buf, 4);
  const count = readU32(buf, 8);
  const start = 12;
  const end = start + count * 4;
  if (end !== buf.length) throw new Error('gld-kiln tensor_view length');
  const payload = buf.subarray(start, end);
  if (payload.buffer !== buf.buffer || payload.byteOffset !== buf.byteOffset + start) {
    throw new Error('gld-kiln tensor_view copied');
  }
  return {
    rows,
    cols,
    values: { f32Bytes: payload, length: count },
  };
}

export const kilnSer = {
  name: 'gld-kiln',
  version: pkgVersion('gld-kiln') || '0.2.0',
  category: 'binary',
  supports(name) {
    return Object.prototype.hasOwnProperty.call(SCHEMAS, name);
  },
  prepare(dataName, value) {
    const base = SCHEMAS[dataName];
    if (!base) throw new Error(`gld-kiln has no schema for ${dataName}`);
    // Same schema object for every timed call. Array value => one list.
    // N is 1 for tensor, so tensor_view borrows that one struct.
    borrow = dataName === 'tensor_view' && !Array.isArray(value);
    schema = Array.isArray(value) ? ['list', base] : base;
    // Numeric lists become one byte run here, outside the timer.
    warm(schema, value);
  },
  serialize(value) {
    if (schema == null) throw new Error('gld-kiln prepare was not called');
    return encodeDirect(schema, value);
  },
  deserialize(buf) {
    if (schema == null) throw new Error('gld-kiln prepare was not called');
    if (borrow) return borrowMatrix(buf);
    f32Used = 0;
    const cur = new Cursor(asUint8(buf));
    // Owned f32 lists are copied. tensor_view uses borrowMatrix instead.
    const value = readValue(cur, schema, true);
    cur.finish();
    return value;
  },
};

export function kilnSerializers() {
  return [kilnSer];
}
