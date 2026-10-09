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

function slen(cfg, defMin, defMax) {
  const sl = cfg.string_len;
  if (!sl) return [defMin, defMax];
  return [sl.min ?? defMin, sl.max ?? defMax];
}

function irange(cfg) {
  const ir = cfg.int_range;
  if (!ir) return [0, 1_000_000];
  return [ir.min ?? 0, ir.max ?? 1_000_000];
}

/** Vocab of 32 from mixSeed(seed, typeId+"#vocab", 0). Not the row RNG. */
function sharedVocab(seed, typeId, smin, smax, size = 32) {
  const vocabRng = new Rng(mixSeed(seed, `${typeId}#vocab`, 0));
  const vocab = [];
  for (let i = 0; i < size; i++) vocab.push(vocabRng.word(smin, smax));
  return vocab;
}

function pickWord(rng, vocab, duplication, smin, smax) {
  if (vocab.length && rng.nextF64() < duplication) {
    return vocab[rng.nextInt(0, vocab.length - 1)];
  }
  return rng.word(smin, smax);
}

function makeTable(rng, cfg, vocab) {
  const [lo, hi] = irange(cfg);
  const [smin, smax] = slen(cfg, 3, 16);
  const dup = cfg.duplication ?? 0.5;
  const row = {};
  for (let i = 0; i < 16; i++) row[`f_float_${i}`] = rng.nextF64() * 1000;
  for (let i = 0; i < 4; i++) row[`f_int_${i}`] = rng.nextInt(lo, hi);
  row.f_str_0 = pickWord(rng, vocab, dup, smin, smax);
  row.f_str_1 = pickWord(rng, vocab, dup, smin, smax);
  return row;
}

// Items are drawn before id/status/meta so the RNG matches generator.py.
// The object key order stays id, status, meta, items.
function makeNestedTable(rng, cfg) {
  const children = cfg.children ?? 4;
  const [smin, smax] = slen(cfg, 3, 12);
  const items = [];
  for (let i = 0; i < children; i++) {
    items.push({
      sku: rng.word(smin, smax),
      qty: rng.nextInt(1, 100),
      price_minor: rng.nextInt(0, 100000),
    });
  }
  return {
    id: rng.word(8, 12),
    status: rng.nextInt(0, 5),
    meta: { region: rng.word(2, 4), version: rng.nextInt(1, 10) },
    items,
  };
}

// Legs are drawn before the fixed block so the RNG matches generator.py.
// leg_pad is the constant 0 and consumes no random bits.
// Object key order is the domain order: numbers, strings, then legs.
function makeSignal(rng, cfg) {
  const groupCount = cfg.group_count ?? 4;
  const [smin, smax] = slen(cfg, 3, 12);
  const legs = [];
  for (let i = 0; i < groupCount; i++) {
    legs.push({
      leg_id: rng.nextInt(0, 1_000_000),
      leg_qty: rng.nextInt(0, 10_000),
      leg_pad: 0,
    });
  }
  return {
    seq: rng.nextInt(0, 1_000_000_000),
    ts: Number(BASE_TS_MS) + rng.nextInt(0, 86_400_000),
    price_mantissa: rng.nextInt(0, 1_000_000_000),
    qty: rng.nextInt(0, 10_000),
    flags: rng.nextInt(0, 65_535),
    symbol: rng.word(smin, smax),
    venue: rng.word(smin, smax),
    legs,
  };
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
    case 'table':
    case 'table_project': {
      const [smin, smax] = slen(typeConfig, 3, 16);
      const vocab = sharedVocab(seed, typeId, smin, smax);
      return makeTable(r, typeConfig, vocab);
    }
    case 'nested_table':
      return makeNestedTable(r, typeConfig);
    case 'signal':
      return makeSignal(r, typeConfig);
    case 'graph': {
      // Call order is the cross-language contract: regions, orders, names, then the ring.
      const [smin, smax] = slen(typeConfig, 8, 16);
      const nOrders = typeConfig.order_count ?? 32;
      const nRegions = typeConfig.region_count ?? 4;
      const ring = typeConfig.ring_size ?? 8;
      if (nRegions < 1) throw new Error('region_count must be >= 1');
      if (ring < 1) throw new Error('ring_size must be >= 1');
      const regions = [];
      for (let i = 0; i < nRegions; i++) {
        regions.push({
          code: r.word(smin, smax),
          note: r.word(64, 64),
          version: r.nextInt(1, 10),
        });
      }
      const orders = [];
      for (let i = 0; i < nOrders; i++) {
        orders.push({
          sku: r.word(smin, smax),
          qty: r.nextInt(1, 100),
          region: regions[i % nRegions],
        });
      }
      const people = [];
      for (let i = 0; i < ring; i++) people.push({ name: r.word(smin, smax), next: null });
      for (let i = 0; i < ring; i++) people[i].next = people[(i + 1) % ring];
      return { orders, people };
    }
    default:
      throw new Error(`unknown type_id: ${typeId}`);
  }
}

export function instances(typeId, typeConfig, seed, n) {
  return Array.from({ length: n }, (_, i) => makeOne(typeId, typeConfig, seed, i));
}
