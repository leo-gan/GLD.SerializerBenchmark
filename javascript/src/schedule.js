/**
 * B-1 deterministic block_shuffle schedule (must match analysis golden vector).
 *
 * Golden: A,B,C @ seed 42 / message / 1 / abc / bytes / 0 → C,B,A
 * (seed 15992650003647724414n).
 */
import crypto from 'node:crypto';

export function normalizeMode(mode) {
  const m = String(mode ?? '')
    .trim()
    .toLowerCase();
  if (m === 'string' || m === 'buffer') return 'bytes';
  if (m === 'stream') return 'stream';
  return m;
}

/**
 * Derive 64-bit schedule seed as BigInt (unsigned).
 */
export function deriveScheduleSeed(
  baseSeed,
  typeId,
  instanceCount,
  typeConfigHash,
  mode,
  rep,
) {
  const key = `${Number(baseSeed)}|${typeId}|${Number(instanceCount)}|${typeConfigHash ?? ''}|${normalizeMode(mode)}|${Number(rep)}`;
  const digest = crypto.createHash('sha256').update(key, 'utf8').digest();
  // first 8 bytes little-endian → BigInt
  let u = 0n;
  for (let i = 7; i >= 0; i--) {
    u = (u << 8n) | BigInt(digest[i]);
  }
  return u;
}

/** SplitMix64 PRNG — returns next u64 as BigInt. */
export class SplitMix64 {
  constructor(seed) {
    this.state = BigInt(seed) & 0xffffffffffffffffn;
  }

  nextU64() {
    this.state = (this.state + 0x9e3779b97f4a7c15n) & 0xffffffffffffffffn;
    let z = this.state;
    z = ((z ^ (z >> 30n)) * 0xbf58476d1ce4e5b9n) & 0xffffffffffffffffn;
    z = ((z ^ (z >> 27n)) * 0x94d049bb133111ebn) & 0xffffffffffffffffn;
    return (z ^ (z >> 31n)) & 0xffffffffffffffffn;
  }
}

/** Fisher–Yates shuffle; returns a new array. */
export function fisherYates(items, seed) {
  const arr = items.slice();
  const rng = new SplitMix64(seed);
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Number(rng.nextU64() % BigInt(i + 1));
    const tmp = arr[i];
    arr[i] = arr[j];
    arr[j] = tmp;
  }
  return arr;
}

export function shuffleSerializerNames(
  names,
  { baseSeed, typeId, instanceCount, typeConfigHash, mode, rep },
) {
  const seed = deriveScheduleSeed(
    baseSeed,
    typeId,
    instanceCount,
    typeConfigHash,
    mode,
    rep,
  );
  return fisherYates(names, seed);
}

/** Golden vector order for A,B,C. */
export function goldenPermutation() {
  return shuffleSerializerNames(['A', 'B', 'C'], {
    baseSeed: 42,
    typeId: 'message',
    instanceCount: 1,
    typeConfigHash: 'abc',
    mode: 'bytes',
    rep: 0,
  });
}

export function resolveScheduleStrategy() {
  const env = String(process.env.BENCHMARK_SCHEDULE ?? '')
    .trim()
    .toLowerCase();
  if (env === 'none' || env === 'block_shuffle') return env;
  return 'block_shuffle';
}

export function resolveRecordRunOrder() {
  const env = String(process.env.BENCHMARK_RECORD_RUN_ORDER ?? '')
    .trim()
    .toLowerCase();
  if (env === '0' || env === 'false' || env === 'no') return false;
  return true;
}
