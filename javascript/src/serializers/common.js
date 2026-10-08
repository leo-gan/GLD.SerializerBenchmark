import { createRequire } from 'node:module';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';

const require = createRequire(import.meta.url);

/** Installed npm package version for CSV SerializerVersion (full semver). */
export function pkgVersion(packageName) {
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

const PUBLICATION_TYPES = new Set(['message', 'document', 'telemetry', 'strings', 'event']);
const COLUMNAR_TYPES = new Set(['table', 'table_project', 'nested_table', 'signal']);

/** Original five publication types. Schema codecs without columnar mappings stay here. */
export function baseSupports(name) {
  return PUBLICATION_TYPES.has(name);
}

/** Publication types plus the four columnar ids (allow-list peers). */
export function peerSupports(name) {
  return PUBLICATION_TYPES.has(name) || COLUMNAR_TYPES.has(name);
}

/** Columnar codecs encode only table, table_project, nested_table, and signal. */
export function columnarSupports(name) {
  return COLUMNAR_TYPES.has(name);
}

/** Full rows in, f_float_0 column out. N=1 is a one-element array, not the row. */
export function projectFFloat0(value) {
  const rows = Array.isArray(value) ? value : [value];
  const out = new Array(rows.length);
  for (let i = 0; i < rows.length; i++) out[i] = rows[i].f_float_0;
  return out;
}

/** JSON-clone to strip non-JSON types before schemaless binary codecs if needed. */
export function jsonClone(value) {
  return JSON.parse(JSON.stringify(value));
}

/** Prefer zero-copy string view when buf is already a Buffer. */
/** Apply untimed toDomain when the adapter provides it. */
export function asDomain(ser, native) {
  return typeof ser.toDomain === 'function' ? ser.toDomain(native) : native;
}

export function bufToUtf8(buf) {
  if (Buffer.isBuffer(buf)) return buf.toString('utf8');
  if (buf instanceof Uint8Array) {
    return Buffer.from(buf.buffer, buf.byteOffset, buf.byteLength).toString('utf8');
  }
  return Buffer.from(buf).toString('utf8');
}

/** Ensure Buffer without unnecessary copy when already Buffer. */
export function asBuffer(buf) {
  if (Buffer.isBuffer(buf)) return buf;
  if (buf instanceof Uint8Array) {
    return Buffer.from(buf.buffer, buf.byteOffset, buf.byteLength);
  }
  return Buffer.from(buf);
}
