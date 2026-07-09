/**
 * Deterministic test fixtures aligned with schemas/test_data_config.json (seed=42).
 */

export class Rng {
  constructor(seed = 42) {
    this.state = BigInt(seed) || 1n;
  }
  nextU64() {
    let x = this.state;
    x ^= x << 13n;
    x ^= x >> 7n;
    x ^= x << 17n;
    this.state = x & 0xffffffffffffffffn;
    return this.state;
  }
  nextInt(lo, hi) {
    const span = BigInt(hi - lo + 1);
    return lo + Number(this.nextU64() % span);
  }
  nextFloat() {
    return Number(this.nextU64()) / Number(0xffffffffffffffffn);
  }
  nextBool() {
    return (this.nextU64() & 1n) === 1n;
  }
  word(minLen = 3, maxLen = 10) {
    const pool = 'abcdefghijklmnopqrstuvwxyz';
    const len = this.nextInt(minLen, maxLen);
    let s = '';
    for (let i = 0; i < len; i++) {
      s += pool[Number(this.nextU64() % BigInt(pool.length))];
    }
    return s;
  }
}

export function makePerson(rng) {
  return {
    FirstName: rng.word(3, 10),
    LastName: rng.word(3, 10),
    Age: rng.nextInt(1, 99),
    Gender: rng.nextBool() ? 0 : 1,
    Passport: {
      Number: rng.word(8, 12),
      Authority: rng.word(3, 10),
      ExpirationDate: '2030-01-01T00:00:00Z',
    },
    PoliceRecords: Array.from({ length: 5 }, (_, i) => ({
      Id: i,
      CrimeCode: rng.word(3, 8),
    })),
  };
}

export function makeSimple(rng) {
  return {
    Id: rng.nextInt(0, 1_000_000),
    Name: rng.word(3, 10),
    Timestamp: '2024-01-01T00:00:00Z',
    IsActive: rng.nextBool(),
  };
}

export function makeStringArray(rng) {
  return { Items: Array.from({ length: 100 }, () => rng.word(3, 10)) };
}

export function makeTelemetry(rng) {
  return {
    Id: rng.word(8, 12),
    DataSource: rng.word(3, 10),
    TimeStamp: '2024-01-01T00:00:00Z',
    Param1: rng.nextInt(0, 1000),
    Param2: rng.nextInt(0, 1000),
    Measurements: Array.from({ length: 100 }, () => rng.nextFloat() * 100),
    AssociatedProblemID: rng.nextInt(0, 10000),
    AssociatedLogID: rng.nextInt(0, 10000),
    WasProcessed: rng.nextBool(),
  };
}

export function makeEdi(rng) {
  const claims = [];
  for (let c = 0; c < 5; c++) {
    claims.push({
      ClaimId: `C${c}`,
      PatientName: rng.word(3, 10),
      TotalCharge: rng.nextFloat() * 5000,
      PaymentAmount: rng.nextFloat() * 5000,
      Lines: Array.from({ length: 3 }, () => ({
        ServiceCode: rng.word(3, 6),
        ChargeAmount: rng.nextFloat() * 1000,
        AdjudicatedAmount: rng.nextFloat() * 1000,
      })),
    });
  }
  return {
    PayerName: rng.word(3, 10),
    PayeeName: rng.word(3, 10),
    PaymentDate: '2024-01-01T00:00:00Z',
    TotalActualAmount: rng.nextFloat() * 10000,
    TransactionControlNumber: rng.word(8, 12),
    Claims: claims,
  };
}

/** Null edge index for ObjectGraph (matches C/Rust GRAPH_NULL). */
export const GRAPH_NULL = -1;

/**
 * Flat ObjectGraph: same topology as C#/Python/C/Rust.
 * Edges are node indices (not live parent pointers) so every codec can encode cycles.
 */
export function makeObjectGraph() {
  return {
    root: 0,
    nodes: [
      { Name: 'Root', Parent: GRAPH_NULL, Related: GRAPH_NULL, Children: [1, 2] },
      { Name: 'Child1', Parent: 0, Related: 2, Children: [] },
      { Name: 'Child2', Parent: 0, Related: 1, Children: [] },
    ],
  };
}

/** Structural fidelity for ObjectGraph (names + index edges + sibling cycle). */
export function objectGraphEqual(a, b) {
  if (!a || !b || a.root !== b.root) return false;
  if (!Array.isArray(a.nodes) || !Array.isArray(b.nodes) || a.nodes.length !== b.nodes.length) {
    return false;
  }
  for (let i = 0; i < a.nodes.length; i++) {
    const na = a.nodes[i];
    const nb = b.nodes[i];
    if (na.Name !== nb.Name || na.Parent !== nb.Parent || na.Related !== nb.Related) return false;
    if (!deepEqual(na.Children || [], nb.Children || [])) return false;
  }
  if (a.nodes.length >= 3 && a.root === 0) {
    const root = a.nodes[0];
    if ((root.Children || []).length >= 2) {
      const i1 = root.Children[0];
      const i2 = root.Children[1];
      if (a.nodes[i1].Parent !== 0 || a.nodes[i2].Parent !== 0) return false;
      if (a.nodes[i1].Related !== i2 || a.nodes[i2].Related !== i1) return false;
    }
  }
  return true;
}

export function allFixtures(seed = 42) {
  const rng = new Rng(seed);
  return [
    { name: 'Person', value: makePerson(rng), circular: false },
    { name: 'Integer', value: 42, circular: false },
    { name: 'Telemetry', value: makeTelemetry(rng), circular: false },
    { name: 'SimpleObject', value: makeSimple(rng), circular: false },
    { name: 'StringArray', value: makeStringArray(rng), circular: false },
    { name: 'EDI_835', value: makeEdi(rng), circular: false },
    { name: 'ObjectGraph', value: makeObjectGraph(), circular: true },
  ];
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
