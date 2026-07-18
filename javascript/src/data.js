/**
 * Shared helpers for the JS suite.
 * V1 fixture factories removed — official types live in data_v2.js
 * (message, document, telemetry, strings, event).
 */

import { makeOne, instances } from './data_v2.js';

export { makeOne, instances };

/** Official Data Model v2 suite type ids. */
export const V2_TYPE_IDS = ['message', 'document', 'telemetry', 'strings', 'event'];

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
