/**
 * gld-kiln 0.2.0 — positional little-endian encode/decode.
 * Schemas are built once in prepare(). Writer.encode reuses one buffer.
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

const { Writer, decode, FloatBits } = await loadKiln();

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

const writer = new Writer();
let schema = null;
let borrow = false;

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
    // Compile the plan and grow the writer outside the timer.
    writer.encode(schema, value);
  },
  serialize(value) {
    if (schema == null) throw new Error('gld-kiln prepare was not called');
    return writer.encode(schema, value);
  },
  deserialize(buf) {
    if (schema == null) throw new Error('gld-kiln prepare was not called');
    if (borrow) return borrowMatrix(buf);
    return decode(schema, asUint8(buf));
  },
};

export function kilnSerializers() {
  return [kilnSer];
}
