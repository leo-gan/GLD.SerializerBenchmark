/**
 * Data Model v2 make_one generators (within-language deterministic).
 * Cross-language payload identity is not required.
 *
 * RNG: xorshift64*. Zero-seed / avalanche uses floor(2^64/φ)=0x9e3779b97f4a7c15
 * (golden ratio; nothing-up-my-sleeve). Suite seed: BENCHMARK_SEED.
 * Wire via BENCHMARK_DATA_MODEL=v2 when the runner supports it.
 */

const BASE_TS_MS = 1704067200000n;

class Rng {
  constructor(seed) {
    // floor(2^64/φ) when seed is 0
    this.state = seed === 0n ? 0x9e3779b97f4a7c15n : BigInt(seed);
  }
  nextU64() {
    let x = this.state;
    x ^= (x << 13n) & 0xffffffffffffffffn;
    x ^= x >> 7n;
    x ^= (x << 17n) & 0xffffffffffffffffn;
    this.state = x & 0xffffffffffffffffn;
    return this.state;
  }
  nextInt(lo, hi) {
    if (hi <= lo) return lo;
    return lo + Number(this.nextU64() % BigInt(hi - lo + 1));
  }
  nextBool() {
    return (this.nextU64() & 1n) === 1n;
  }
  nextF64() {
    return Number(this.nextU64() >> 11n) / Number(1n << 53n);
  }
  word(minL, maxL) {
    const n = this.nextInt(minL, maxL);
    const alpha = 'abcdefghijklmnopqrstuvwxyz';
    let s = '';
    for (let i = 0; i < n; i++) s += alpha[Number(this.nextU64() % 26n)];
    return s;
  }
}

function mixSeed(seed, typeId, idx) {
  let h = BigInt(seed);
  for (const ch of typeId) {
    h = (h ^ BigInt(ch.charCodeAt(0))) * 0x100000001b3n;
    h &= 0xffffffffffffffffn;
  }
  h ^= BigInt(idx) * 0x9e3779b97f4a7c15n;
  h &= 0xffffffffffffffffn;
  return h === 0n ? 1n : h;
}

export function makeOne(typeId, typeConfig = {}, seed = 42, instanceIndex = 0) {
  const r = new Rng(mixSeed(seed, typeId, instanceIndex));
  const children = typeConfig.children ?? 8;
  const points = typeConfig.points ?? 32;
  const count = typeConfig.count ?? 32;
  const attrCount = typeConfig.attr_count ?? 4;
  switch (typeId) {
    case 'message':
      return {
        f_bool: r.nextBool(),
        f_int32: r.nextInt(0, 1_000_000),
        f_int64: r.nextInt(0, 1_000_000),
        f_float64: r.nextF64() * 1000,
        f_string: r.word(3, 16),
        f_bool_2: r.nextBool(),
        f_int32_2: r.nextInt(0, 1_000_000),
        f_string_2: r.word(3, 16),
      };
    case 'document': {
      const items = [];
      for (let i = 0; i < children; i++) {
        items.push({ sku: r.word(3, 12), qty: r.nextInt(1, 100), price_minor: r.nextInt(0, 100000) });
      }
      return {
        id: r.word(8, 12),
        status: r.nextInt(0, 5),
        meta: { region: r.word(2, 4), version: r.nextInt(1, 10) },
        items,
      };
    }
    case 'telemetry': {
      const tags = [];
      for (let i = 0; i < (typeConfig.tag_count ?? 2); i++) tags.push(r.word(3, 10));
      const values = [];
      for (let i = 0; i < points; i++) values.push(r.nextF64() * 100);
      return {
        source: r.word(3, 10),
        ts: Number(BASE_TS_MS) + r.nextInt(0, 86400000),
        tags,
        values,
      };
    }
    case 'strings': {
      const items = [];
      for (let i = 0; i < count; i++) items.push(r.word(3, 16));
      return { items };
    }
    case 'event': {
      const attrs = [];
      for (let i = 0; i < attrCount; i++) attrs.push({ key: r.word(3, 12), value: r.word(3, 12) });
      return {
        event_id: r.word(8, 12),
        event_type: r.word(3, 12),
        occurred_at: Number(BASE_TS_MS) + r.nextInt(0, 86400000),
        producer: r.word(3, 12),
        attrs,
      };
    }
    default:
      throw new Error(`unknown type_id: ${typeId}`);
  }
}

export function instances(typeId, typeConfig, seed, n) {
  return Array.from({ length: n }, (_, i) => makeOne(typeId, typeConfig, seed, i));
}
