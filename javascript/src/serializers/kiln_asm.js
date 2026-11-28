/**
 * gld-kiln-asm 0.2.0 — pure x86-64 Assembly Kiln Wire Format v2 codec via Node N-API addon.
 *
 * Covers all four Data Sets:
 *   - suite:    message, document, telemetry, strings, event (single + batch)
 *   - columnar: table (TableColumns), table_project (KILN_OPT_EMBEDDED O(1) skip),
 *               nested_table, signal (single + batch; row->column transpose timed)
 *   - array:    grid, grid_window (KLNT v2 float64 [ny, nx] with strided window copy)
 *   - tensor:   tensor, tensor_view (zero-copy subarray borrow of wire Buffer),
 *               prompt, shard, request (KLNT v2)
 */
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

const require = createRequire(import.meta.url);
const __dirname = path.dirname(fileURLToPath(import.meta.url));
const repoRoot = path.resolve(__dirname, '../../..');
const addonPath = path.join(repoRoot, 'build/kiln-asm/kiln_asm_napi.node');

let cachedAddon = null;
export function loadKilnAsmAddon() {
  if (!cachedAddon) {
    cachedAddon = require(addonPath);
  }
  return cachedAddon;
}

const SUPPORTED = new Set([
  'message',
  'document',
  'telemetry',
  'strings',
  'event',
  'table',
  'table_project',
  'nested_table',
  'signal',
  'grid',
  'grid_window',
  'tensor',
  'tensor_view',
  'prompt',
  'shard',
  'request',
]);

const podCache = new WeakMap();

function cacheF64(values) {
  if (values instanceof Float64Array || Buffer.isBuffer(values)) return values;
  let hit = podCache.get(values);
  if (hit && hit.byteLength === values.length * 8) return hit;
  const arr = new Float64Array(values.length);
  for (let i = 0; i < values.length; i++) arr[i] = values[i];
  podCache.set(values, arr);
  return arr;
}

function cacheF32(values) {
  if (Buffer.isBuffer(values)) return values;
  if (values && typeof values === 'object' && values.f32Bytes instanceof Uint8Array) return values.f32Bytes;
  let hit = podCache.get(values);
  if (hit && hit.length === values.length * 4) return hit;
  const buf = Buffer.allocUnsafe(values.length * 4);
  for (let i = 0; i < values.length; i++) {
    const v = values[i];
    if (v && typeof v === 'object' && v.kind === 'f32') {
      buf.writeUInt32LE(Number(BigInt(v.bits) & 0xffffffffn), i * 4);
    } else {
      buf.writeFloatLE(v, i * 4);
    }
  }
  podCache.set(values, buf);
  return buf;
}

function cacheI64(values) {
  if (values instanceof BigInt64Array || Buffer.isBuffer(values)) return values;
  let hit = podCache.get(values);
  if (hit && hit.byteLength === values.length * 8) return hit;
  const arr = new BigInt64Array(values.length);
  for (let i = 0; i < values.length; i++) arr[i] = BigInt(values[i]);
  podCache.set(values, arr);
  return arr;
}

function f64ToArray(ta) {
  const n = ta.length;
  const out = new Array(n);
  for (let i = 0; i < n; i++) out[i] = ta[i];
  return out;
}

function finishPrompt(p) {
  p.input_ids = f64ToArray(p.input_ids);
  p.attention_mask = f64ToArray(p.attention_mask);
  p.position_ids = f64ToArray(p.position_ids);
  return p;
}

let activeType = 'message';
let activeBatch = false;
let activeWindow = [0, 0, 0, 0];

export const kilnAsmSer = {
  name: 'gld-kiln-asm',
  version: '0.2.0',
  category: 'binary',

  supports(name) {
    return SUPPORTED.has(name);
  },

  prepare(dataName, value) {
    loadKilnAsmAddon();
    activeType = dataName;
    activeBatch = Array.isArray(value);
    if (dataName === 'grid' || dataName === 'grid_window') {
      activeWindow = [value.x0 | 0, value.y0 | 0, value.wx | 0, value.wy | 0];
      cacheF64(value.values);
    } else if (dataName === 'tensor' || dataName === 'tensor_view') {
      cacheF32(value.values);
    } else if (dataName === 'prompt') {
      cacheI64(value.input_ids);
      cacheI64(value.attention_mask);
      cacheI64(value.position_ids);
    } else if (dataName === 'shard') {
      cacheF32(value.tok_emb);
      cacheF32(value.attn);
      cacheF32(value.ffn_weight);
      cacheF32(value.norm);
    } else if (dataName === 'request') {
      cacheI64(value.inputs.input_ids);
      cacheI64(value.inputs.attention_mask);
      cacheI64(value.inputs.position_ids);
    }
  },

  serialize(value) {
    const addon = loadKilnAsmAddon();
    switch (activeType) {
      case 'message':
        return addon.encodeMessage(value, activeBatch);
      case 'document':
        return addon.encodeDocument(value, activeBatch);
      case 'telemetry':
        return addon.encodeTelemetry(value, activeBatch);
      case 'strings':
        return addon.encodeStrings(value, activeBatch);
      case 'event':
        return addon.encodeEvent(value, activeBatch);
      case 'table':
      case 'table_project':
        return addon.encodeTable(value, activeBatch);
      case 'nested_table':
        return addon.encodeNestedTable(value, activeBatch);
      case 'signal':
        return addon.encodeSignal(value, activeBatch);
      case 'grid':
      case 'grid_window':
        return addon.encodeGrid(value.nx, value.ny, cacheF64(value.values));
      case 'tensor':
      case 'tensor_view':
        return addon.encodeTensor(value.rows, value.cols, cacheF32(value.values));
      case 'prompt':
        return addon.encodePrompt(
          value.batch,
          value.seq,
          cacheI64(value.input_ids),
          cacheI64(value.attention_mask),
          cacheI64(value.position_ids),
        );
      case 'shard':
        return addon.encodeShard(
          value.vocab,
          value.hidden,
          value.ffn,
          cacheF32(value.tok_emb),
          cacheF32(value.attn),
          cacheF32(value.ffn_weight),
          cacheF32(value.norm),
        );
      case 'request':
        return addon.encodeRequest(
          value.request_id,
          value.model,
          value.temperature,
          value.inputs.batch,
          value.inputs.seq,
          cacheI64(value.inputs.input_ids),
          cacheI64(value.inputs.attention_mask),
          cacheI64(value.inputs.position_ids),
        );
      default:
        throw new Error(`gld-kiln-asm: unsupported type ${activeType}`);
    }
  },

  deserialize(buf) {
    const addon = loadKilnAsmAddon();
    const u8 = buf instanceof Uint8Array ? buf : Buffer.from(buf);
    switch (activeType) {
      case 'message':
        return addon.decodeMessage(u8, activeBatch);
      case 'document':
        return addon.decodeDocument(u8, activeBatch);
      case 'telemetry':
        return addon.decodeTelemetry(u8, activeBatch);
      case 'strings':
        return addon.decodeStrings(u8, activeBatch);
      case 'event':
        return addon.decodeEvent(u8, activeBatch);
      case 'table':
        return addon.decodeTable(u8, activeBatch);
      case 'table_project':
        return f64ToArray(addon.decodeTableProject(u8));
      case 'nested_table':
        return addon.decodeNestedTable(u8, activeBatch);
      case 'signal':
        return addon.decodeSignal(u8, activeBatch);
      case 'grid':
        return f64ToArray(addon.decodeGrid(u8));
      case 'grid_window':
        return f64ToArray(
          addon.decodeGridWindow(
            u8,
            activeWindow[0],
            activeWindow[1],
            activeWindow[2],
            activeWindow[3],
          ),
        );
      case 'tensor':
        return addon.decodeTensor(u8);
      case 'tensor_view': {
        const [rows, cols, off, len] = addon.decodeTensorViewMeta(u8);
        const payload = u8.subarray(off, off + len);
        if (payload.buffer !== u8.buffer || payload.byteOffset !== u8.byteOffset + off) {
          throw new Error('gld-kiln-asm tensor_view copied');
        }
        return {
          rows,
          cols,
          values: { f32Bytes: payload, length: len >>> 2 },
        };
      }
      case 'prompt':
        return finishPrompt(addon.decodePrompt(u8));
      case 'shard':
        return addon.decodeShard(u8);
      case 'request': {
        const r = addon.decodeRequest(u8);
        finishPrompt(r.inputs);
        return r;
      }
      default:
        throw new Error(`gld-kiln-asm: unsupported type ${activeType}`);
    }
  },
};

export function kilnAsmSerializers() {
  return [kilnAsmSer];
}
