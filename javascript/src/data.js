/**
 * Shared helpers for the JS suite.
 * Suite fixtures — re-export / helpers for data_v2.js
 * (message, document, telemetry, strings, event,
 * table, table_project, nested_table, signal).
 */

import { makeOne, instances } from './data_v2.js';

export { makeOne, instances };

/** Official Data Model v2 suite type ids. Publication types, then columnar. */
export const V2_TYPE_IDS = [
  'message',
  'document',
  'telemetry',
  'strings',
  'event',
  'table',
  'table_project',
  'nested_table',
  'signal',
];

/**
 * Value the runner compares after deserialize.
 * table_project encodes the full row and returns f_float_0 only, including N=1.
 */
export function expectedForFidelity(typeId, value) {
  if (typeId !== 'table_project') return value;
  const rows = Array.isArray(value) ? value : [value];
  const out = new Array(rows.length);
  for (let i = 0; i < rows.length; i++) out[i] = rows[i].f_float_0;
  return out;
}

/** Build one fixture per V2 type (seeded). */
export function allFixturesV2(seed = 42) {
  return V2_TYPE_IDS.map((name) => ({
    name,
    value: makeOne(name, {}, seed, 0),
    circular: false,
  }));
}

/** Deep equality (key-order insensitive). Prefer this over JSON.stringify for fidelity. */
export function deepEqual(a, b) {
  if (Object.is(a, b)) return true;
  if (typeof a !== typeof b) return false;
  if (a === null || b === null) return a === b;
  if (typeof a !== 'object') return false;
  if (Array.isArray(a)) {
    if (!Array.isArray(b) || a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (!deepEqual(a[i], b[i])) return false;
    return true;
  }
  if (Array.isArray(b)) return false;
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  for (const k of ka) {
    if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
    if (!deepEqual(a[k], b[k])) return false;
  }
  return true;
}

function graphPair(a, b, memoA, memoB) {
  if (a === null || a === undefined || b === null || b === undefined) return a === b;
  if (typeof a !== 'object' || typeof b !== 'object') return Object.is(a, b);
  // Lists are ordered values, not nodes. A cycle lives on objects (the person ring).
  if (Array.isArray(a) || Array.isArray(b)) {
    if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) {
      if (!graphPair(a[i], b[i], memoA, memoB)) return false;
    }
    return true;
  }
  const seenA = memoA.has(a);
  const seenB = memoB.has(b);
  if (seenA || seenB) return seenA && seenB && memoA.get(a) === memoB.get(b);
  const token = memoA.size;
  memoA.set(a, token);
  memoB.set(b, token);
  const ka = Object.keys(a);
  const kb = Object.keys(b);
  if (ka.length !== kb.length) return false;
  for (const k of ka) {
    if (!Object.prototype.hasOwnProperty.call(b, k)) return false;
    if (!graphPair(a[k], b[k], memoA, memoB)) return false;
  }
  return true;
}

/**
 * Identity compare for `graph` (shared nodes and one cycle).
 * A second visit must hit the same object on the other side; a duplicated
 * region fails. JSON.stringify throws on the person ring — do not use it.
 */
export function graphEqual(a, b) {
  return graphPair(a, b, new Map(), new Map());
}
