// Dagr serializer runtime (Phase 4). A faithful port of Swift's DataArenaBuilder
// (dagr/codegen/swift/serde.py): a BACKWARD-growing builder. Every store writes toward
// the FRONT of a single Uint8Array (the stored bytes occupy `[buf.length - cursor,
// buf.length)`, the far end); the buffer doubles on demand and makeData() slices out the
// stored region. `cursor` = total bytes stored so far; a BufferOffset is the cursor value
// at store time; the forward distance between two stored things is `cursorNow - offset`.
// (Earlier this used a `number[][]` chunk list concatenated in reverse — same bytes, but a
// per-field micro-allocation; the single-buffer form is byte-identical and ~2.5× faster.)
//
// Gate: toBytes(restore(fixture)) must equal the fixture byte-for-byte.

const _f = new DataView(new ArrayBuffer(8));
const _te = new TextEncoder();

/** LEB byte length of a non-negative value. */
export function lebLength(v: number | bigint): number {
  if (typeof v === "number") {                 // fast path: no BigInt (integers up to 2^53)
    if (v < 0x80) return 1;
    if (v < 0x4000) return 2;
    if (v < 0x200000) return 3;
    if (v < 0x10000000) return 4;
    let n = 0, x = v;
    while (x > 0) { n++; x = Math.floor(x / 128); }
    return n;
  }
  let x = v;
  if (x <= 0n) return 1;
  let n = 0;
  while (x > 0n) { n++; x >>= 7n; }
  return n;
}

/** Zig-zag for signed distances (node-ref bidir pointers): n>=0 ? n<<1 : ~n<<1|1. */
export function toZigZag(v: number | bigint): bigint {
  const x = typeof v === "bigint" ? v : BigInt(v);
  return x >= 0n ? x << 1n : ((~x) << 1n) | 1n;
}

/** Zig-zag that stays a `number` whenever the result fits in 2^53 (|v| < 2^52), so the
 *  scalar/array writers take the non-BigInt `lebLength`/`storeLEB` paths; falls back to
 *  `toZigZag` (BigInt) beyond that. Same value as `toZigZag`, different JS type. */
export function zigzag(v: number | bigint): number | bigint {
  if (typeof v === "number") {
    if (v > -0x10000000000000 && v < 0x10000000000000) return v >= 0 ? v * 2 : -v * 2 - 1;
    return toZigZag(v);
  }
  if (v > -0x10000000000000n && v < 0x10000000000000n) { const n = Number(v); return n >= 0 ? n * 2 : -n * 2 - 1; }
  return toZigZag(v);
}

/** "Negative" zig-zag used for the vtable size marker: v==0 ? 0 : (v-1)<<1|1. */
export function toNegativZigZag(v: number | bigint): bigint {
  const x = typeof v === "bigint" ? v : BigInt(v);
  return x === 0n ? 0n : (((x - 1n) << 1n) | 1n);
}

/** f32 bit pattern of a JS number. */
function _f32Bits(v: number): number { _f.setFloat32(0, v, true); return _f.getUint32(0, true); }

/** IEEE-754 bit patterns (for union-array value slots, which store raw bits). */
export function f32Bits(v: number): number { _f.setFloat32(0, v, true); return _f.getUint32(0, true); }
export function f64Bits(v: number): bigint { _f.setFloat64(0, v, true); return _f.getBigUint64(0, true); }

/** f32 → bf16 bits: round-to-nearest-even on the top 16 bits (mirrors _f32ToBf16Bits). */
export function f32ToBf16Bits(v: number): number {
  const bits = _f32Bits(v);
  const lsb = (bits >>> 16) & 1;
  return ((bits + 0x7fff + lsb) >>> 16) & 0xffff;
}

/** f32 → f16 bits: IEEE-754 round-to-nearest-even with subnormals (mirrors _f32ToF16BitsLossy). */
export function f32ToF16Bits(v: number): number {
  if (Number.isNaN(v)) return 0x7e00;
  const bits = _f32Bits(v);
  const sign = (bits >>> 16) & 0x8000;
  const exp32 = (bits >>> 23) & 0xff;
  const mant32 = bits & 0x7fffff;
  if (exp32 === 0xff) return sign | 0x7c00;              // infinity (NaN handled)
  if ((bits & 0x7fffffff) === 0) return sign;            // +/-0
  const exp16 = exp32 - 127 + 15;
  if (exp16 >= 0x1f) return sign | 0x7c00;
  if (exp16 <= 0) {
    if (exp16 < -10) return sign;
    const m = mant32 | 0x800000;
    const shift = 14 - exp16;
    const low = m & ((1 << shift) - 1);
    const half = 1 << (shift - 1);
    let r = m >>> shift;
    if (low > half || (low === half && (r & 1) === 1)) r += 1;
    return (sign | r) & 0xffff;
  }
  let half16 = (exp16 << 10) | (mant32 >>> 13);
  const round = (mant32 >>> 12) & 1;
  const sticky = (mant32 & 0xfff) !== 0;
  if (round === 1 && (sticky || (half16 & 1) === 1)) half16 += 1;
  return (sign | half16) & 0xffff;
}

/** f32 → f16 bits ONLY if exactly representable (else null); mirrors _f32ToF16Bits. */
export function f32ToF16BitsExact(v: number): number | null {
  const bits = _f32Bits(v);
  const sign = bits >>> 31;
  const exp32 = (bits >>> 23) & 0xff;
  const mant32 = bits & 0x7fffff;
  if (exp32 === 0xff) return null;                                  // nan/inf
  if (exp32 === 0) return mant32 === 0 ? (sign << 15) : null;       // ±0 / subnormal
  const exp16 = exp32 - 112;
  if (exp16 < 1 || exp16 > 30) return null;                         // out of f16 range
  if ((mant32 & 0x1fff) !== 0) return null;                         // precision loss
  return ((sign << 15) | (exp16 << 10) | (mant32 >>> 13)) & 0xffff;
}

/** Min unsigned width code for `v` (value-ref array slots). Mirrors _offsetWidthCode. */
function _offsetWidthCode(v: number): number {
  if (v <= 0xff) return 0;
  if (v <= 0xffff) return 1;
  if (v <= 0xffffffff) return 2;
  return 3;
}
/** Min signed (two's-complement) width code for `d` (node-ref slots). Mirrors _signedWidthCode. */
function _signedWidthCode(d: number): number {
  if (d >= -128 && d <= 127) return 0;
  if (d >= -32768 && d <= 32767) return 1;
  if (d >= -2147483648 && d <= 2147483647) return 2;
  return 3;
}

/**
 * A node-store result (mirrors Rust's `NodeStoreRef`). `{ off }` = the node is
 * fully stored at that cursor. `{ pending }` = the node is an ANCESTOR still being
 * stored (a cycle): its final offset is unknown, so a pointer to it is written as a
 * fixed-width placeholder and patched by `finishStoring` (`08`/`05`: cycle late
 * binding). `pending` is the shared `_values` record identifying the in-flight node.
 */
export type NodeStoreRef = { off: number } | { pending: object };

/**
 * Structural value-equality for write-side default elision ("spec/14-defaults-and-prefabs.md"
 * §4): true when a field's runtime value equals its schema default so the serializer can
 * omit it. Handles scalars/bigint/strings (`Object.is` — bit-faithful for -0 / NaN,
 * matching Rust's `.to_bits()`), `Uint8Array` (byte-wise), plain arrays (element-wise),
 * and value-union `{ type, value }` literals (recursively). Node-ref-bearing values never
 * reach here — they are never elided.
 */
export function _dagrEq(a: unknown, b: unknown): boolean {
  if (a instanceof Uint8Array && b instanceof Uint8Array) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
  }
  if (Array.isArray(a) && Array.isArray(b)) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (!_dagrEq(a[i], b[i])) return false;
    return true;
  }
  if (a && b && typeof a === "object" && typeof b === "object" && "type" in a && "type" in b) {
    const ta = a as { type: unknown; value: unknown };
    const tb = b as { type: unknown; value: unknown };
    return ta.type === tb.type && _dagrEq(ta.value, tb.value);
  }
  return Object.is(a, b);
}

/** Unwrap a resolved offset; throws if the ref is still pending (a cycle reached a
 *  context that has no late-binding support, e.g. a union-array node variant). */
export function nodeOffset(r: NodeStoreRef): number {
  if (!("off" in r)) throw new Error("cyclic reference in a context without late-binding support");
  return r.off;
}

export class Builder {
  // Single BACKWARD-growing buffer: stores write from the top down, so the bytes stored
  // so far occupy `[buf.length - cursor, buf.length)` (the far end). Grows by doubling.
  // Replaces the old per-store `number[][]` chunk list — no micro-allocations per field,
  // no `makeData` concat pass. Late bindings record a CURSOR value (stable across grows),
  // patched at `buf.length - cursorAt`.
  private buf: Uint8Array;
  private dv: DataView;   // over `buf`, re-made on every grow (float stores)
  cursor = 0;

  // reserveFieldPointerSize is derived from maxSize EXACTLY like Rust/Swift (with_max_size):
  // bits = bitLength(maxSize)+3; width = nextPow2(ceil(bits/8)). 2 MiB -> 4 B, 1024 -> 2 B.
  constructor(maxSize: number = 2 * 1024 * 1024, initialCapacity: number = 64) {
    this.buf = new Uint8Array(Math.max(16, initialCapacity));
    this.dv = new DataView(this.buf.buffer);
    const bits = (32 - Math.clz32(maxSize)) + 3;
    const nbytes = (bits >> 3) + ((bits & 7) ? 1 : 0);
    this.reserveFieldPointerSize = 1 << (32 - Math.clz32(nbytes - 1));
  }
  private vtLookup = new Map<string, number>();  // norm-vector key → header offset (vtable dedup)
  private stringLookup = new Map<string, number>();  // string → content offset (utf8 dedup)
  structLookup = new Map<object, number>();  // node → offset (shared/cyclic node dedup, = Rust node_cache)

  // ── Cycle late-binding (mirrors Rust DagrBuilder in_progress/late_bindings) ───
  // A node is "in progress" between beginStoring and finishStoring; a pointer to it
  // during that window is written as a fixed-width placeholder hole whose CURSOR position
  // is recorded here (stable across buffer grows), then patched in finishStoring at
  // `buf.length - cursorAt`.
  // rfps = reserved bidir-pointer width, derived from maxSize in the constructor (2MiB → 4 bytes).
  readonly reserveFieldPointerSize: number;
  private inProgress = new Set<object>();
  private lateBindings = new Map<object, { cursorAt: number; base: number; arrayEnd: number; es: number }[]>();

  private _ensure(n: number): void {
    if (this.buf.length - this.cursor >= n) return;
    let cap = this.buf.length * 2;
    while (cap - this.cursor < n) cap *= 2;
    const nb = new Uint8Array(cap);
    nb.set(this.buf.subarray(this.buf.length - this.cursor), cap - this.cursor);  // move tail to the new far end
    this.buf = nb;
    this.dv = new DataView(nb.buffer);
  }
  /** Reserve `n` bytes at the front of the stored region; returns their start position. */
  private _wpos(n: number): number { this._ensure(n); const p = this.buf.length - this.cursor - n; this.cursor += n; return p; }

  private push(bytes: number[]): number { const p = this._wpos(bytes.length); this.buf.set(bytes, p); return this.cursor; }

  storeU8(v: number): number { const p = this._wpos(1); this.buf[p] = v & 0xff; return this.cursor; }
  storeU16(v: number): number { const p = this._wpos(2); this.buf[p] = v & 0xff; this.buf[p + 1] = (v >>> 8) & 0xff; return this.cursor; }
  storeU32(v: number): number {
    const p = this._wpos(4);
    this.buf[p] = v & 0xff; this.buf[p + 1] = (v >>> 8) & 0xff; this.buf[p + 2] = (v >>> 16) & 0xff; this.buf[p + 3] = (v >>> 24) & 0xff;
    return this.cursor;
  }
  storeU64(v: bigint): number {
    const p = this._wpos(8);
    let x = v & 0xffffffffffffffffn;
    for (let i = 0; i < 8; i++) { this.buf[p + i] = Number(x & 0xffn); x >>= 8n; }
    return this.cursor;
  }
  // Signed integers share the little-endian two's-complement layout of the unsigned store.
  storeI8(v: number): number { return this.storeU8(v & 0xff); }
  storeI16(v: number): number { return this.storeU16(v & 0xffff); }
  storeI32(v: number): number { return this.storeU32(v >>> 0); }
  storeI64(v: bigint): number { return this.storeU64(v & 0xffffffffffffffffn); }

  storeF32(v: number): number { const p = this._wpos(4); this.dv.setFloat32(p, v, true); return this.cursor; }
  storeF64(v: number): number { const p = this._wpos(8); this.dv.setFloat64(p, v, true); return this.cursor; }

  /** Raw 2-byte f16/bf16 bits (frozen/vtable nodes). */
  storeF16(v: number): number { return this.storeU16(f32ToF16Bits(v)); }
  storeBf16(v: number): number { return this.storeU16(f32ToBf16Bits(v)); }

  // ── Packed self-describing floats (sub-tag scheme) ───────────────────────────
  // Returns true if the RAW fallback was used (for the packed-scalar field/enc
  // bit). `elem` = true for array elements: the raw fallback gets a 0x07/0x08 tag
  // so every element is self-describing (arrays are always mode 0). Mirrors
  // Float.storePacked / Double.storePacked.
  storePackedFloat32(v: number, elem: boolean): boolean {
    if (Object.is(v, 0)) { this.storeU8(0x00); return false; }
    if (Object.is(v, -0)) { this.storeU8(0x01); return false; }
    if (Number.isNaN(v)) { this.storeU8(0x04); return false; }
    if (!Number.isFinite(v)) { this.storeU8(v < 0 ? 0x03 : 0x02); return false; }
    if (Number.isInteger(v) && Math.abs(v) < (1 << 21)) {
      const zz = zigzag(v);
      if (lebLength(zz) <= 3) { this.storeLEB(zz); this.storeU8(0x05); return false; }
    }
    const f16 = f32ToF16BitsExact(v);
    if (f16 !== null) { this.storeU16(f16); this.storeU8(0x06); return false; }
    this.storeF32(v);
    if (elem) this.storeU8(0x07);
    return true;
  }
  storePackedFloat64(v: number, elem: boolean): boolean {
    if (Object.is(v, 0)) { this.storeU8(0x00); return false; }
    if (Object.is(v, -0)) { this.storeU8(0x01); return false; }
    if (Number.isNaN(v)) { this.storeU8(0x04); return false; }
    if (!Number.isFinite(v)) { this.storeU8(v < 0 ? 0x03 : 0x02); return false; }
    if (Number.isInteger(v) && Math.abs(v) < 2 ** 48) {
      const zz = zigzag(v);
      if (lebLength(zz) <= 7) { this.storeLEB(zz); this.storeU8(0x05); return false; }
    }
    const f32 = Math.fround(v);
    if (f32 === v) {
      const f16 = f32ToF16BitsExact(f32);
      if (f16 !== null) { this.storeU16(f16); this.storeU8(0x06); return false; }
      this.storeF32(f32); this.storeU8(0x07); return false;
    }
    this.storeF64(v);
    if (elem) this.storeU8(0x08);
    return true;
  }

  /** Packed sub-byte enum array: [blockLen][count][bitset]. */
  storePackedEnumBitArray(elems: (number | bigint)[], bits: number): number {
    const before = this.cursor;
    const perByte = 8 / bits;
    const mask = (1 << bits) - 1;
    const bs = new Array(Math.ceil((elems.length * bits) / 8)).fill(0);
    for (let i = 0; i < elems.length; i++) {
      bs[Math.floor(i / perByte)] |= (Number(elems[i]) & mask) << ((i % perByte) * bits);
    }
    this.storeBytes(bs);
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed byte-aligned enum array: [blockLen][count][LEB(rawValue) per element]. */
  storePackedEnumRawArray(elems: (number | bigint)[]): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) this.storeLEB(elems[i]!);
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed f16/bf16 scalar: special value → self-describing 1-byte tag (returns
   * false), else raw 2-byte bits (returns true = raw). Mirrors _storePackedF16. */
  storePackedF16Scalar(v: number, isBf16: boolean): boolean {
    if (Object.is(v, 0)) { this.storeU8(0x00); return false; }
    if (Object.is(v, -0)) { this.storeU8(0x01); return false; }
    if (Number.isNaN(v)) { this.storeU8(0x04); return false; }
    if (!Number.isFinite(v)) { this.storeU8(v < 0 ? 0x03 : 0x02); return false; }
    this.storeU16(isBf16 ? f32ToBf16Bits(v) : f32ToF16Bits(v));
    return true;
  }

  /** Packed f16/bf16 array: [blockLen][count][enc bitset][elems]; enc bit 1 = raw
   * 2-byte, 0 = special-value tag. Plain count (not the count-tag). */
  storePackedF16Array(elems: number[], isBf16: boolean): number {
    const before = this.cursor;
    const enc = new Array((elems.length + 7) >> 3).fill(0);
    for (let i = elems.length - 1; i >= 0; i--) {
      if (this.storePackedF16Scalar(elems[i]!, isBf16)) enc[i >> 3] |= 1 << (i & 7);
    }
    this.storeBytes(enc);
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed float array: [blockLen][(count<<2)|mode][elems] — mode 0 =
   * self-describing packed elems, mode 1 (`>> raw` fields) = raw native-LE. */
  storePackedFloatArray(elems: number[], isF64: boolean, raw = false): number {
    const before = this.cursor;
    if (raw) {
      const w = isF64 ? 8 : 4, n = elems.length, p = this._wpos(n * w), dv = this.dv;
      if (isF64) for (let i = 0; i < n; i++) dv.setFloat64(p + i * 8, elems[i]!, true);
      else for (let i = 0; i < n; i++) dv.setFloat32(p + i * 4, elems[i]!, true);
    } else {
      for (let i = elems.length - 1; i >= 0; i--) {
        if (isF64) this.storePackedFloat64(elems[i]!, true);
        else this.storePackedFloat32(elems[i]!, true);
      }
    }
    this.storeLEB(elems.length * 4 + (raw ? 1 : 0));
    return this.storeLEB(this.cursor - before);
  }

  /** Inline raw bytes, forward order (matches store(inline:) contiguous path). */
  storeBytes(bytes: Uint8Array | number[]): number { const p = this._wpos(bytes.length); this.buf.set(bytes, p); return this.cursor; }

  private _storeUIntWc(v: number, wc: number): number {
    return wc === 0 ? this.storeU8(v) : wc === 1 ? this.storeU16(v)
      : wc === 2 ? this.storeU32(v) : this.storeU64(BigInt(v));
  }
  private _storeIntWc(v: number, wc: number): number {
    return wc === 0 ? this.storeI8(v) : wc === 1 ? this.storeI16(v)
      : wc === 2 ? this.storeI32(v) : this.storeI64(BigInt(v));
  }
  private _storeUIntWcBig(v: bigint, wc: number): number {
    return wc === 0 ? this.storeU8(Number(v & 0xffn)) : wc === 1 ? this.storeU16(Number(v & 0xffffn))
      : wc === 2 ? this.storeU32(Number(v & 0xffffffffn)) : this.storeU64(v);
  }

  /**
   * Regular/frozen union array (§4.9): content already stored (phase 1). `applied`
   * is in REVERSED element order; each is `{ kind:'v'|'p'|'b', val, tid }` or null
   * (nil element). Stores [slot table][nil bitset (opt)][typeId section][header].
   * Slot = value bit-pattern (v) / distance base→content (p) / distance<<1 (b node).
   * `bp` = typeId bits per element (sub-byte packed, or a byte each when bp===8).
   */
  storeUnionArray(count: number, applied: ({ kind: string; val: number | bigint; tid: number } | null)[],
                  bp: number, opt: boolean): number {
    const contentEnd = this.cursor;
    let wc = 0;
    const slots: bigint[] = applied.map((a) => {
      if (a === null) return 0n;
      let v: bigint;
      if (a.kind === "v") v = BigInt(a.val);
      else if (a.kind === "p") v = BigInt(contentEnd - Number(a.val));
      else v = BigInt(contentEnd - Number(a.val)) << 1n;
      wc = Math.max(wc, v <= 0xffn ? 0 : v <= 0xffffn ? 1 : v <= 0xffffffffn ? 2 : 3);
      return v;
    });
    for (const v of slots) this._storeUIntWcBig(v, wc);       // slot table
    if (opt) {
      const nil = new Array((count + 7) >> 3).fill(0);
      for (let j = 0; j < count; j++) { const idx = count - 1 - j; if (applied[j] === null) nil[idx >> 3] |= 1 << (idx & 7); }
      this.storeBytes(nil);
    }
    if (bp < 8) {                                             // sub-byte typeId bitset
      const perByte = 8 / bp, mask = (1 << bp) - 1;
      const bs = new Array(Math.ceil((count * bp) / 8)).fill(0);
      for (let j = 0; j < count; j++) {
        const idx = count - 1 - j, tid = applied[j] ? applied[j]!.tid : 0;
        bs[Math.floor(idx / perByte)] |= (tid & mask) << ((idx % perByte) * bp);
      }
      this.storeBytes(bs);
    } else {                                                  // one byte per typeId
      for (const a of applied) this.storeU8(a ? a.tid : 0);
    }
    return this.storeLEB(count * 4 + wc);
  }

  /**
   * Pointer-table array (utf8/data/node-ref elements): store each element's content
   * (reversed) via `storeElem`, then a `[count×es]` slot table (slot = distance
   * `cur - off + 1`, 0 = nil), then the header `(count<<2)|widthCode`. `signed` →
   * two's-complement slots (node refs); else unsigned (value refs). Returns the
   * header offset. Mirrors Array.store's reference-element path (§4.5).
   */
  storePtrTableArray<T>(elems: (T | null)[], storeElem: (b: Builder, v: T) => number, signed: boolean): number {
    const offs: (number | null)[] = [];
    for (let i = elems.length - 1; i >= 0; i--) {
      offs.push(elems[i] === null ? null : storeElem(this, elems[i] as T));
    }
    const cur = this.cursor;
    let wc = 0;
    for (const off of offs) {
      if (off !== null) {
        const d = cur - off + 1;
        wc = Math.max(wc, signed ? _signedWidthCode(d) : _offsetWidthCode(d));
      }
    }
    for (const off of offs) {
      const d = off === null ? 0 : cur - off + 1;
      if (signed) this._storeIntWc(d, wc);
      else this._storeUIntWc(d, wc);
    }
    return this.storeLEB(elems.length * 4 + wc);
  }

  /**
   * Length-prefixed utf8 string content: [LEB byteCount][utf8 bytes] in the final
   * buffer. `dedup` mirrors String.store(with:)'s stringLookup (regular/frozen
   * out-of-line); packed inline (storePacked) does not dedup. Returns the content
   * offset (the count LEB position).
   */
  storeUtf8(s: string, dedup: boolean): number {
    if (dedup) { const hit = this.stringLookup.get(s); if (hit !== undefined) return hit; }
    const off = this.storeLEB(this._storeUtf8Bytes(s));
    if (dedup) this.stringLookup.set(s, off);
    return off;
  }

  /** Store the UTF-8 bytes of `s` (no length prefix); returns the byte count. Short
   *  ASCII strings are copied char by char; anything else is `encodeInto` a reserved
   *  worst-case (3 B per UTF-16 unit) region, then moved flush against the stored bytes. */
  private _storeUtf8Bytes(s: string): number {
    const n = s.length;
    if (n <= 64) {
      let ascii = true;
      for (let i = 0; i < n; i++) if (s.charCodeAt(i) > 0x7f) { ascii = false; break; }
      if (ascii) {
        const p = this._wpos(n), buf = this.buf;
        for (let i = 0; i < n; i++) buf[p + i] = s.charCodeAt(i);
        return n;
      }
    }
    const max = n * 3;
    this._ensure(max);
    const end = this.buf.length - this.cursor, start = end - max;
    const w = _te.encodeInto(s, this.buf.subarray(start, end)).written;
    if (w < max) this.buf.copyWithin(end - w, start, start + w);
    this.cursor += w;
    return w;
  }

  /** Length-prefixed data: [LEB count][bytes]. No dedup (Data has none). */
  storeData(bytes: Uint8Array): number {
    this.storeBytes(bytes);
    return this.storeLEB(bytes.length);
  }

  // ── Aligned array/blob fields (§11) ──────────────────────────────────────────
  // Pre-element padding forces the element base (cursor after the reversed elements)
  // onto an N boundary; the arena finish padding makes the whole buffer ≡ 0 mod
  // global_max_N so the base is buffer-relative N-aligned. Layout (makeData/forward):
  // [LEB count][N-aligned elements][pre-element pad] — identical to a plain numeric
  // array plus padding. Returns the count-LEB offset (the V62 forward-pointer target).

  /** Aligned fixed-width numeric array: pre-pad, reversed W-byte elements, LEB count. */
  storeAlignedArray<T>(elems: T[], width: number, N: number, each: (b: Builder, v: T) => void): number {
    const pad = (-(this.cursor + elems.length * width)) & (N - 1);
    if (pad) this.storeBytes(new Array(pad).fill(0));
    for (let i = elems.length - 1; i >= 0; i--) each(this, elems[i]!);
    return this.storeLEB(elems.length);
  }

  /** Aligned byte blob (utf8/data, W=1): pre-pad, reversed bytes, LEB byte-count. */
  storeAlignedBytes(bytes: Uint8Array | number[], N: number): number {
    const b = bytes instanceof Uint8Array ? bytes : Uint8Array.from(bytes);
    const pad = (-(this.cursor + b.length)) & (N - 1);
    if (pad) this.storeBytes(new Array(pad).fill(0));
    for (let i = b.length - 1; i >= 0; i--) this.storeU8(b[i]!);
    return this.storeLEB(b.length);
  }

  /** Aligned utf8: the UTF-8 bytes, N-aligned (no dedup — position-dependent). */
  storeAlignedUtf8(s: string, N: number): number { return this.storeAlignedBytes(_te.encode(s), N); }

  /**
   * Arena finish padding (§11 §4): insert zero bytes before the framing LEB so the
   * total length (afterPad + framingLen) is ≡ 0 mod maxN, making every aligned
   * element base buffer-relative aligned. Brute-forces the smallest pad because the
   * framing LEB width depends on the (padded) distance. Mirrors
   * storeFinishAlignmentPadding. Must be called after the root node is stored,
   * before the framing word.
   */
  storeFinishAlignmentPadding(rootOffset: number, maxN: number): void {
    if (maxN <= 1) return;
    for (let p = 0; p < maxN; p++) {
      const afterPad = this.cursor + p;
      const framingLen = lebLength(BigInt(afterPad - rootOffset) << 2n);
      if ((afterPad + framingLen) % maxN === 0) {
        if (p) this.storeBytes(new Array(p).fill(0));
        return;
      }
    }
  }

  /** Fixed-width numeric array: [LEB count][elem0..elemN-1] LE. Elements stored in
   * reverse (backward builder) via `each`; returns the count-LEB offset. */
  storeFixedArray<T>(elems: T[], each: (b: Builder, v: T) => void): number {
    for (let i = elems.length - 1; i >= 0; i--) each(this, elems[i]!);
    return this.storeLEB(elems.length);
  }

  // ── Packed-node array bodies: [blockLen][count-tag][elems] (self-sizing) ─────
  // Each returns the blockLen offset; the caller then stores the field's raw tag.

  /** Packed int array (width ≥ 2): count-tag = (count<<2)|tag, tag 0 all-LEB / 1
   * all-raw / 2 mixed (enc bitset). Per element: LEB if smaller than the raw width,
   * else raw fixed-width. `toLEB` yields the LEB value (zig-zag for signed).
   * `raw` (a `>> raw` field, spec/39): no probe, every element W bytes, tag 1. */
  storePackedIntArray<T>(elems: T[], width: number, toLEB: (v: T) => number | bigint,
                         storeRaw: (b: Builder, v: T) => void, raw = false): number {
    const before = this.cursor;
    if (raw) {
      for (let i = elems.length - 1; i >= 0; i--) storeRaw(this, elems[i]!);
      this.storeLEB(elems.length * 4 + 1);
      return this.storeLEB(this.cursor - before);
    }
    const enc = new Array((elems.length + 7) >> 3).fill(0);
    let rawCount = 0;
    for (let i = elems.length - 1; i >= 0; i--) {
      const lv = toLEB(elems[i]!);
      if (lebLength(lv) < width) this.storeLEB(lv);
      else { storeRaw(this, elems[i]!); enc[i >> 3] |= 1 << (i & 7); rawCount++; }
    }
    let tag = 0;
    if (rawCount === elems.length && elems.length > 0) tag = 1;
    else if (rawCount > 0) { tag = 2; this.storeBytes(enc); }
    this.storeLEB(elems.length * 4 + tag);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed u8/i8 array: plain [count][raw bytes] (single-path, no count-tag). */
  storePackedByteArray<T>(elems: T[], storeRaw: (b: Builder, v: T) => void): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) storeRaw(this, elems[i]!);
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  // ── Packed arrayWithOptionals bodies: [blockLen][count/tag][nil bs][present…] ──
  // Compacted: only present elements occupy the payload; a leading nil bitset
  // (indexed by element i) marks absent slots. Each returns the blockLen offset.

  /** Packed int awo (width ≥ 2): [(count<<2)|tag][nil bs][enc bs if tag2][present].
   * tag 0 all-LEB / 1 all-raw / 2 mixed; enc bit indexed by i.
   * `raw` (spec/39): no probe, present elements W bytes each, tag 1. */
  storePackedIntOptArray<T>(elems: (T | null)[], width: number, toLEB: (v: T) => number | bigint,
                            storeRaw: (b: Builder, v: T) => void, raw = false): number {
    const before = this.cursor, count = elems.length;
    if (raw) {
      for (let i = count - 1; i >= 0; i--) if (elems[i] !== null) storeRaw(this, elems[i] as T);
      this.storeBytes(this._nilBits(elems));
      this.storeLEB(count * 4 + 1);
      return this.storeLEB(this.cursor - before);
    }
    const enc = new Array((count + 7) >> 3).fill(0);
    let rawCount = 0, present = 0;
    for (let i = count - 1; i >= 0; i--) {
      if (elems[i] === null) continue;
      present++;
      const lv = toLEB(elems[i] as T);
      if (lebLength(lv) < width) this.storeLEB(lv);
      else { storeRaw(this, elems[i] as T); enc[i >> 3] |= 1 << (i & 7); rawCount++; }
    }
    let tag = 0;
    if (rawCount === present && present > 0) tag = 1;
    else if (rawCount > 0) { tag = 2; this.storeBytes(enc); }
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(count * 4 + tag);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed u8/i8 awo: [count][nil bs][present raw bytes]. */
  storePackedByteOptArray<T>(elems: (T | null)[], storeRaw: (b: Builder, v: T) => void): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) if (elems[i] !== null) storeRaw(this, elems[i] as T);
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed bool awo: [count][nil bs][present value bitset] (compacted, ci-indexed). */
  storePackedBoolOptArray(elems: (boolean | null)[]): number {
    const before = this.cursor;
    let present = 0; for (const e of elems) if (e !== null) present++;
    const val = new Array((present + 7) >> 3).fill(0);
    let ci = 0;
    for (let i = 0; i < elems.length; i++) { if (elems[i] === null) continue; if (elems[i]) val[ci >> 3] |= 1 << (ci & 7); ci++; }
    this.storeBytes(val);
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed f16/bf16 awo: [count][nil bs][present raw 2-byte]. */
  storePackedF16OptArray(elems: (number | null)[], isBf16: boolean): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) if (elems[i] !== null) this.storeU16(isBf16 ? f32ToBf16Bits(elems[i] as number) : f32ToF16Bits(elems[i] as number));
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed f32/f64 awo: [(count<<2)|mode][nil bs][present elems] — mode as in
   * storePackedFloatArray (1 = raw native-LE for `>> raw` fields). */
  storePackedFloatOptArray(elems: (number | null)[], isF64: boolean, raw = false): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) {
      if (elems[i] === null) continue;
      if (raw) { if (isF64) this.storeF64(elems[i] as number); else this.storeF32(elems[i] as number); }
      else if (isF64) this.storePackedFloat64(elems[i] as number, true); else this.storePackedFloat32(elems[i] as number, true);
    }
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length * 4 + (raw ? 1 : 0));
    return this.storeLEB(this.cursor - before);
  }

  /** Packed sub-byte enum awo: [count][nil bs][present value bitset] (compacted). */
  storePackedEnumBitOptArray(elems: (number | bigint | null)[], bits: number): number {
    const before = this.cursor;
    let present = 0; for (const e of elems) if (e !== null) present++;
    const perByte = 8 / bits, mask = (1 << bits) - 1;
    const val = new Array(Math.ceil((present * bits) / 8)).fill(0);
    let ci = 0;
    for (let i = 0; i < elems.length; i++) { if (elems[i] === null) continue; val[Math.floor(ci / perByte)] |= (Number(elems[i]) & mask) << ((ci % perByte) * bits); ci++; }
    this.storeBytes(val);
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed byte-aligned enum awo: [count][nil bs][present LEB rawValues]. */
  storePackedEnumRawOptArray(elems: (number | bigint | null)[]): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) if (elems[i] !== null) this.storeLEB(BigInt(elems[i] as number | bigint));
    this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed node-ref element array: [count][opt nil bs][(blockLen+child block) per
   * present]. Each child is stored via `storeChild` (its own inline packed block).
   * Mirrors readPackedNodeArrayAt. */
  storePackedNodeArray<T>(elems: (T | null)[], storeChild: (b: Builder, v: T) => void, opt: boolean): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) {
      if (opt && elems[i] === null) continue;
      storeChild(this, elems[i] as T);
    }
    if (opt) this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Packed utf8/data element array: plain [count][(LEB len+bytes) per element];
   * awo [count][nil bs][present elems]. `storeElem` writes one inline element. */
  storePackedComplexArray<T>(elems: (T | null)[], storeElem: (b: Builder, v: T) => void, opt: boolean): number {
    const before = this.cursor;
    for (let i = elems.length - 1; i >= 0; i--) {
      if (opt && elems[i] === null) continue;
      storeElem(this, elems[i] as T);
    }
    if (opt) this.storeBytes(this._nilBits(elems));
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Nil bitset indexed by element i (bit set = absent). */
  private _nilBits(elems: unknown[]): number[] {
    const nil: number[] = new Array<number>((elems.length + 7) >> 3).fill(0);
    for (let i = 0; i < elems.length; i++) if (elems[i] === null) nil[i >> 3]! |= 1 << (i & 7);
    return nil;
  }

  /** Packed bool array: [count][bitset], wrapped in blockLen. */
  storePackedBoolArray(elems: boolean[]): number {
    const before = this.cursor;
    const bs = new Array((elems.length + 7) >> 3).fill(0);
    for (let i = 0; i < elems.length; i++) if (elems[i]) bs[i >> 3] |= 1 << (i & 7);
    this.storeBytes(bs);
    this.storeLEB(elems.length);
    return this.storeLEB(this.cursor - before);
  }

  /** Numeric arrayWithOptionals (regular/frozen, uncompacted):
   * [LEB count][nil bitset][N fixed slots] — absent elements store `width` zero
   * bytes, nil bit set. Mirrors _storeOptionalGraphStorable. */
  storeOptFixedArray<T>(elems: (T | null)[], width: number, each: (b: Builder, v: T) => void): number {
    for (let i = elems.length - 1; i >= 0; i--) {
      if (elems[i] === null) this.storeBytes(new Array(width).fill(0));
      else each(this, elems[i] as T);
    }
    const bs = new Array((elems.length + 7) >> 3).fill(0);
    for (let i = 0; i < elems.length; i++) if (elems[i] === null) bs[i >> 3] |= 1 << (i & 7);
    this.storeBytes(bs);
    return this.storeLEB(elems.length);
  }

  /** Bool arrayWithOptionals (regular/frozen, uncompacted):
   * [LEB count][nil bitset][value bitset], both indexed by i. */
  storeOptBoolArray(elems: (boolean | null)[]): number {
    const nb = (elems.length + 7) >> 3;
    const val = new Array(nb).fill(0);
    const nil = new Array(nb).fill(0);
    for (let i = 0; i < elems.length; i++) {
      if (elems[i] === null) nil[i >> 3] |= 1 << (i & 7);
      else if (elems[i]) val[i >> 3] |= 1 << (i & 7);
    }
    this.storeBytes(val);
    this.storeBytes(nil);
    return this.storeLEB(elems.length);
  }

  /** Sub-byte enum array: [LEB count][packed bits], `bits` (1/2/4) per element,
   * element i at bit (i%perByte)*bits of byte ⌊i/perByte⌋. Values may be bigint. */
  storeEnumBitArray(elems: (number | bigint)[], bits: number): number {
    const perByte = 8 / bits;
    const mask = (1 << bits) - 1;
    const bs = new Array(Math.ceil((elems.length * bits) / 8)).fill(0);
    for (let i = 0; i < elems.length; i++) {
      bs[Math.floor(i / perByte)] |= (Number(elems[i]) & mask) << ((i % perByte) * bits);
    }
    this.storeBytes(bs);
    return this.storeLEB(elems.length);
  }

  /** Sub-byte enum arrayWithOptionals (regular/frozen, uncompacted):
   * [LEB count][nil bitset][value bitset], both indexed by i. */
  storeOptEnumBitArray(elems: (number | bigint | null)[], bits: number): number {
    const perByte = 8 / bits;
    const mask = (1 << bits) - 1;
    const nil = new Array((elems.length + 7) >> 3).fill(0);
    const val = new Array(Math.ceil((elems.length * bits) / 8)).fill(0);
    for (let i = 0; i < elems.length; i++) {
      if (elems[i] === null) nil[i >> 3] |= 1 << (i & 7);
      else val[Math.floor(i / perByte)] |= (Number(elems[i]) & mask) << ((i % perByte) * bits);
    }
    this.storeBytes(val);
    this.storeBytes(nil);
    return this.storeLEB(elems.length);
  }

  /** Bool array: [LEB count][bitset ⌈count/8⌉], bit i = elem i. */
  storeBoolArray(elems: boolean[]): number {
    const bs = new Array((elems.length + 7) >> 3).fill(0);
    for (let i = 0; i < elems.length; i++) if (elems[i]) bs[i >> 3] |= 1 << (i & 7);
    this.storeBytes(bs);
    return this.storeLEB(elems.length);
  }

  /** LEB128, low 7 bits first (mirrors _storeAsLEB; value 0 → single 0x00). */
  storeLEB(value: number | bigint): number {
    if (typeof value === "number") {           // fast path: no BigInt, no temp array (use % / Math.floor — & is 32-bit)
      if (value < 0x80) { const p0 = this._wpos(1); this.buf[p0] = value > 0 ? value : 0; return this.cursor; }
      const n = lebLength(value);
      if (value < 0x80000000) {
        const p = this._wpos(n), buf = this.buf;
        let x = value;
        for (let i = 0; i < n - 1; i++) { buf[p + i] = (x & 0x7f) | 0x80; x >>>= 7; }
        buf[p + n - 1] = x;
        return this.cursor;
      }
      const p = this._wpos(n);
      let x = value;
      for (let i = 0; i < n; i++) { const b = x % 128; x = Math.floor(x / 128); this.buf[p + i] = x > 0 ? b | 0x80 : b; }
      return this.cursor;
    }
    if (value <= 0n) { const p0 = this._wpos(1); this.buf[p0] = 0; return this.cursor; }
    const n = lebLength(value);
    const p = this._wpos(n);
    let x = value;
    for (let i = 0; i < n; i++) { const b = Number(x & 0x7fn); x >>= 7n; this.buf[p + i] = x > 0n ? b | 0x80 : b; }
    return this.cursor;
  }

  /** V62 fixed-width pointer: value<<2 | widthCode, width by magnitude (mirrors _storeV62). */
  storeV62(value: number | bigint, minCode = 0): number {
    const x = typeof value === "bigint" ? value : BigInt(value);
    if (x < (1n << 6n) && minCode === 0) return this.storeU8(Number((x << 2n) | 0n));
    if (x < (1n << 14n) && minCode <= 1) return this.storeU16(Number((x << 2n) | BigInt(Math.max(1, minCode))));
    if (x < (1n << 30n) && minCode <= 2) return this.storeU32(Number((x << 2n) | BigInt(Math.max(2, minCode))));
    if (x < (1n << 62n)) return this.storeU64((x << 2n) | BigInt(Math.max(3, minCode)));
    throw new Error(`cantStoreValueAsV62(${x})`);
  }

  /**
   * Regular/frozen union field slot: run `a.emit` (store the inline value or the
   * forward/bidir pointer — content was already stored by the union's apply step),
   * then the tag LEB `(typeId<<2)|widthCode`, where widthCode reflects the emitted
   * payload's byte count (1→0, 2→1, 4→2, else 3). Mirrors _storeUnionSlot /
   * ArenaUnion.store(with:). Returns the tag offset (the slot start for the vtable).
   */
  storeUnionSlot(a: { id: number; emit: (b: Builder) => void }): number {
    const before = this.cursor;
    a.emit(this);
    const n = this.cursor - before;
    const wc = n === 1 ? 0 : n === 2 ? 1 : n === 4 ? 2 : 3;
    return this.storeLEB((a.id << 2) | wc);
  }

  /**
   * Nested-union value slot: like storeUnionSlot but the tag LEB is just `id<<2`
   * (width code fixed at 0). A nested union — one appearing as another union's
   * variant, or as a union-array element — needs no width code: the reader recovers
   * each variant's width from the schema (scalars) or self-describing pointers
   * (utf8/data/node/array). Keeping the low 2 bits zero makes the byte identical to
   * Rust/Swift. See spec "spec/05-union-types.md" (nested-union value form).
   */
  storeNestedUnionSlot(a: { id: number; emit: (b: Builder) => void }): number {
    a.emit(this);
    return this.storeLEB(a.id << 2);
  }

  /** Forward pointer to a previously stored offset: V62(cursor - offset). */
  storeForwardPointer(offset: number): number { return this.storeV62(this.cursor - offset); }

  /**
   * Bidirectional (signed) pointer to a node ref. Resolved (`{ off }`) →
   * V62(zigzag(cursor - off)). Pending (`{ pending }`, a cycle back-edge) → reserve a
   * fixed 4-byte V62 placeholder (width code 2, matching Rust's min_code from
   * reserveFieldPointerSize) and record it so finishStoring can patch the distance.
   */
  storeBidirectionalPointer(ref: NodeStoreRef): number {
    if ("off" in ref) return this.storeV62(toZigZag(this.cursor - ref.off));
    const base = this.cursor;                     // cursor BEFORE the placeholder (= Rust pos - rfps)
    const es = this.reserveFieldPointerSize;
    const p = this._wpos(es);                      // reserve a fixed-width hole; patched in finishStoring
    for (let i = 0; i < es; i++) this.buf[p + i] = 0;
    this._addLateBinding(ref.pending, { cursorAt: this.cursor, base, arrayEnd: -1, es });
    return this.cursor;
  }

  /**
   * Node-ref array (regular/frozen, signed two's-complement slots, §4.5): store each
   * element's node (reversed), then a `[count×es]` slot table (slot = distance
   * `cur - off + 1`, 0 = nil/absent). A pending (cyclic) element gets a zero placeholder
   * patched by finishStoring; any pending forces width code ≥ 2 so the patch fits 4
   * bytes. Byte-identical to storePtrTableArray(signed) when nothing is pending.
   */
  storeNodeRefArray<T>(elems: (T | null)[], storeRef: (b: Builder, v: T) => NodeStoreRef): number {
    const refs: (NodeStoreRef | null)[] = [];
    for (let i = elems.length - 1; i >= 0; i--) refs.push(elems[i] === null ? null : storeRef(this, elems[i]!));
    const cur = this.cursor;
    let wc = 0, hasPending = false;
    for (const r of refs) {
      if (r === null) continue;
      if ("off" in r) wc = Math.max(wc, _signedWidthCode(cur - r.off + 1));
      else hasPending = true;
    }
    const reserveWc = 31 - Math.clz32(this.reserveFieldPointerSize);   // 4B → code 2, 2B → code 1
    if (hasPending && wc < reserveWc) wc = reserveWc;
    const es = [1, 2, 4, 8][wc]!;
    for (const r of refs) {
      if (r === null) { this._storeIntWc(0, wc); }
      else if ("off" in r) { this._storeIntWc(cur - r.off + 1, wc); }
      else {
        const p = this._wpos(es);
        for (let i = 0; i < es; i++) this.buf[p + i] = 0;
        this._addLateBinding(r.pending, { cursorAt: this.cursor, base: 0, arrayEnd: cur, es });
      }
    }
    return this.storeLEB(elems.length * 4 + wc);
  }

  private _addLateBinding(id: object, bind: { cursorAt: number; base: number; arrayEnd: number; es: number }): void {
    let arr = this.lateBindings.get(id);
    if (!arr) { arr = []; this.lateBindings.set(id, arr); }
    arr.push(bind);
  }

  /**
   * Begin storing a node keyed on its shared `_values` record. Returns an
   * already-resolved ref (cached offset from a prior store, or a `{ pending }` marker
   * when the node is an in-flight ancestor — a cycle), or null to proceed storing
   * fresh. Mirrors Rust DagrBuilder::begin_storing.
   */
  beginStoring(id: object): NodeStoreRef | null {
    const off = this.structLookup.get(id);
    if (off !== undefined) return { off };
    if (this.inProgress.has(id)) return { pending: id };
    this.inProgress.add(id);
    return null;
  }

  /**
   * Finish storing a node: patch every placeholder recorded against it, then cache the
   * offset (for dedup + any later refs). Bidir placeholders get a 4-byte V62 (width
   * code 2); node-ref array slots get a raw fixed-width two's-complement distance (NOT
   * V62). Mirrors Rust DagrBuilder::finish_storing.
   */
  finishStoring(id: object, offset: number): void {
    this.inProgress.delete(id);
    const binds = this.lateBindings.get(id);
    if (binds) {
      for (const bd of binds) {
        const pos = this.buf.length - bd.cursorAt;    // placeholder's absolute position in the current buffer
        if (bd.arrayEnd >= 0) {
          let x = BigInt(bd.arrayEnd - offset + 1) & ((1n << BigInt(bd.es * 8)) - 1n);   // signed distance, raw fixed-width
          for (let i = 0; i < bd.es; i++) { this.buf[pos + i] = Number(x & 0xffn); x >>= 8n; }
        } else {
          const encoded = toZigZag(bd.base - offset);   // may be negative (forward back-edge)
          const wc = BigInt(31 - Math.clz32(bd.es));     // es bytes → V62 width code (4→2, 2→1)
          let v = (encoded << 2n) | wc;
          for (let i = 0; i < bd.es; i++) { this.buf[pos + i] = Number(v & 0xffn); v >>= 8n; }
        }
      }
      this.lateBindings.delete(id);
    }
    this.structLookup.set(id, offset);
  }

  /**
   * Store a vtable for a regular node. `entries` are field value offsets in FORWARD
   * index order (null = absent field). Returns the node offset (the vtable-pointer
   * LEB). Dedups identical entry vectors. Mirrors DataArenaBuilder.store(vTable:).
   */
  storeVTable(entries: (number | null)[]): number {
    const norm = entries.map((off) => (off === null ? 0 : this.cursor - off + 1));
    // The wire format caps vtable entries at UInt16 ("05" §5.3 Entry range).
    // Every field slot — including union slots — is written in Phase 2 near the
    // node, so entries are naturally tiny; if one still drifts past the cap,
    // fail loudly rather than silently truncate and corrupt the buffer.
    const over = norm.find((n) => n > 0xffff);
    if (over !== undefined) throw new Error(
      `vtable entry overflow: field slot ${over} bytes before the node header exceeds the ` +
      `UInt16 wire limit (65535).`);
    const is16 = norm.some((n) => n > 0xff);
    const key = (is16 ? "w:" : "") + norm.join(",");
    const hit = this.vtLookup.get(key);
    if (hit !== undefined) {
      // Dedup: a fresh vtable stores an ODD marker; a forward-ref stores EVEN ((dist)<<1).
      return this.storeLEB((this.cursor - hit) << 1);
    }
    let result: number;
    if (is16) {
      const cnt = (entries.length << 1) | 1;
      const sz = lebLength(cnt) + entries.length * 2;
      result = this.storeLEB(toNegativZigZag(sz));
      for (let i = norm.length - 1; i >= 0; i--) this.storeU16(norm[i]!);
      this.vtLookup.set(key, this.storeLEB(cnt));
    } else {
      const cnt = entries.length << 1;
      const sz = cnt === 0 ? 0 : lebLength(cnt) + entries.length;
      result = this.storeLEB(sz === 0 ? 0n : toNegativZigZag(sz));
      for (let i = norm.length - 1; i >= 0; i--) this.storeU8(norm[i]!);
      this.vtLookup.set(key, this.storeLEB(cnt));
    }
    return result;
  }

  /** Rewind for reuse on another independent record (a DataSink streaming
   *  writer): reset the cursor (reusing the buffer) and clear the dedup / cycle caches, so each record
   *  dedups only within itself — byte-identical to a fresh Builder. Avoids
   *  allocating a new Builder (object + 5 Map/Set) per record. */
  reset(): void {
    this.cursor = 0;   // reuse this.buf; the stored region is [buf.length - cursor, buf.length)
    this.vtLookup.clear();
    this.stringLookup.clear();
    this.structLookup.clear();
    this.inProgress.clear();
    this.lateBindings.clear();
  }

  /** The stored region as a VIEW (no copy) — valid until the next store / reset. */
  recordBytes(): Uint8Array {
    return this.buf.subarray(this.buf.length - this.cursor);
  }

  /** The finished buffer: the stored region [buf.length - cursor, buf.length), copied out. */
  makeData(): Uint8Array {
    return this.buf.slice(this.buf.length - this.cursor);
  }
}
