// Dagr lazy-read runtime primitives (TypeScript).
//
// Ported byte-for-byte from the Swift/Rust generated runtime
// (targets/swift/Sources/DagrExample/DagrRuntime.swift). This is the Phase 0 spike surface
// (see "spec/21-typescript-codegen-plan.md" §7): just enough of the wire primitives
// to lazily read a regular (vtable) node of required scalars.
//
// Reader model (plan §8.1): hold BOTH a Uint8Array (varint / byte hot path) and
// a same-region DataView (fixed-width scalars & floats). Access is via
// position-passing free functions, mirroring the Swift/Rust getters 1:1.

export class DagrError extends Error {
  constructor(kind: string) {
    super(`DagrError: ${kind}`);
    this.name = "DagrError";
  }
}

/** Buffer pair: byte view for varints, DataView for fixed-width reads. */
export class Buf {
  readonly u8: Uint8Array;
  readonly dv: DataView;
  constructor(bytes: Uint8Array) {
    this.u8 = bytes;
    // #1 footgun (plan §8.1): view the SAME region, honoring byteOffset /
    // byteLength. A Node Buffer (or any subarray) can carry a nonzero
    // byteOffset; `new DataView(bytes.buffer)` alone would make every offset
    // wrong.
    this.dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  }
}

/**
 * LEB128 unsigned varint. Returns [value, bytesConsumed].
 *
 * Spike scope: `value` is a JS number, exact up to 2^53. Offsets, vtable sizes,
 * and the framing word are all small, so this is safe here. 64-bit field values
 * (u64/i64) will need a BigInt variant in Phase 1.
 *
 * Mirrors restoreLEB(from:at:) in DagrRuntime.swift.
 */
export function readLEB(buf: Buf, at: number): [number, number] {
  if (at < 0) throw new DagrError("outsideOfBuffer");
  const u8 = buf.u8;
  if (at < u8.length && u8[at]! < 0x80) return [u8[at]!, 1];   // one-byte fast path (tags, lengths)
  let pos = at;
  let result = 0;
  let shift = 0;
  for (;;) {
    if (pos >= buf.u8.length) throw new DagrError("outsideOfBuffer");
    const b = buf.u8[pos]!;
    // `* 2**shift` (not `<< shift`): JS bitwise shifts are 32-bit and would
    // corrupt values past bit 31.
    result += (b & 0x7f) * 2 ** shift;
    shift += 7;
    pos += 1;
    if (b >> 7 === 0) break;
  }
  return [result, pos - at];
}

/**
 * ZigZag decode. Spike scope: magnitudes fit in 32 bits (vtable / root
 * offsets), so the 32-bit `^` is safe. Mirrors `.fromZigZag` in the runtime.
 */
export function zigzagDecode(n: number): number {
  return Math.floor(n / 2) ^ -(n & 1);
}

/**
 * BigInt LEB128 unsigned varint — the exact path for u64/i64 field values,
 * where a JS number would lose precision past 2^53. Returns [value, bytes].
 */
export function readLEBBig(buf: Buf, at: number): [bigint, number] {
  if (at < 0) throw new DagrError("outsideOfBuffer");
  // Accumulate in a number while it stays exact (7 groups = 49 bits), so a typical i64
  // (a timestamp, a price) costs one BigInt conversion instead of BigInt ops per byte.
  const u8 = buf.u8;
  let pos = at;
  let small = 0;
  for (let k = 0; k < 7; k++) {
    if (pos >= u8.length) throw new DagrError("outsideOfBuffer");
    const b = u8[pos]!;
    small += (b & 0x7f) * 2 ** (7 * k);
    pos += 1;
    if (b >> 7 === 0) return [BigInt(small), pos - at];
  }
  let result = BigInt(small);
  let shift = 49n;
  for (;;) {
    if (pos >= buf.u8.length) throw new DagrError("outsideOfBuffer");
    const b = buf.u8[pos]!;
    result |= BigInt(b & 0x7f) << shift;
    shift += 7n;
    pos += 1;
    if (b >> 7 === 0) break;
  }
  return [result, pos - at];
}

/** BigInt ZigZag decode (i64). Mirrors `.fromZigZag`. */
export function zigzagDecodeBig(n: bigint): bigint {
  return (n >> 1n) ^ -(n & 1n);
}

/**
 * V62 bidirectional pointer. Low 2 bits select width (0→1B, 1→2B, 2→4B, 3→8B),
 * value = raw >> 2. Returns [value, bytesConsumed].
 *
 * Not exercised by the pure-scalar u32 spike (no node-refs), but it is a core
 * primitive — included so Phase 1 (refs/arrays) can build directly on it.
 * Mirrors readV62(from:at:) in the runtime.
 */
export function readV62(buf: Buf, at: number): [number, number] {
  if (at < 0 || at >= buf.u8.length) throw new DagrError("outsideOfBuffer");
  const code = buf.u8[at]! & 3;
  switch (code) {
    case 0:
      return [buf.u8[at]! >>> 2, 1];
    case 1:
      return [buf.dv.getUint16(at, true) >>> 2, 2];
    case 2:
      // Divide, not `>>> 2`: a full 32-bit value would lose its top bits.
      return [Math.floor(buf.dv.getUint32(at, true) / 4), 4];
    default:
      return [Number(buf.dv.getBigUint64(at, true) >> 2n), 8];
  }
}

/** Signed (ZigZag) V62 pointer. Mirrors readZigZagV62 in the runtime. */
export function readZigZagV62(buf: Buf, at: number): [number, number] {
  const [raw, len] = readV62(buf, at);
  return [zigzagDecode(raw), len];
}

/**
 * Parse a regular-node vtable, returning per-field offsets relative to the node
 * start (null = field absent). Field position = nodeStart + offset.
 *
 * Mirrors restoreRTypeVTable(from:start:) in the runtime:
 *  - LEB at nodeStart is the (ZigZag) pointer to the vtable; even = dedup
 *    forward-ref (+b1 off-by-one), odd = fresh vtable.
 *  - vtable header LEB: `(fieldCount << 1) | wideFlag` (wide → 16-bit entries).
 *  - each entry: 0 = absent, else storedValue - 1 + b1 = field offset.
 */
export function restoreRTypeVTable(buf: Buf, start: number): (number | null)[] {
  const [offsetValue, b1] = readLEB(buf, start);
  const adj = (offsetValue & 1) === 0 ? b1 : 0;
  const vtStart = start + zigzagDecode(offsetValue) + adj;
  const [vtSize, b2] = readLEB(buf, vtStart);
  const count = vtSize >> 1;
  const wide = (vtSize & 1) !== 0;
  let cursor = vtStart + b2;
  const result: (number | null)[] = [];
  for (let i = 0; i < count; i++) {
    const v = wide ? buf.dv.getUint16(cursor, true) : buf.u8[cursor]!;
    result.push(v === 0 ? null : v - 1 + b1);
    cursor += wide ? 2 : 1;
  }
  return result;
}

// ── Fixed-width scalar reads (regular-node `restore` path — NOT LEB) ──────────
// In a regular (vtable) node, scalars are stored native little-endian at a
// fixed width. (Packed nodes use LEB via a separate `restorePacked` path — a
// Phase 1 fork.) These mirror the UIntN/IntN `restore(from:at:)` extensions.

function bounds(buf: Buf, at: number, width: number): void {
  if (at < 0 || at + width > buf.u8.length) throw new DagrError("outsideOfBuffer");
}

export function readU8(buf: Buf, at: number): number { bounds(buf, at, 1); return buf.dv.getUint8(at); }
export function readU16(buf: Buf, at: number): number { bounds(buf, at, 2); return buf.dv.getUint16(at, true); }
export function readU32(buf: Buf, at: number): number { bounds(buf, at, 4); return buf.dv.getUint32(at, true); }
export function readU64(buf: Buf, at: number): bigint { bounds(buf, at, 8); return buf.dv.getBigUint64(at, true); }
export function readI8(buf: Buf, at: number): number { bounds(buf, at, 1); return buf.dv.getInt8(at); }
export function readI16(buf: Buf, at: number): number { bounds(buf, at, 2); return buf.dv.getInt16(at, true); }
export function readI32(buf: Buf, at: number): number { bounds(buf, at, 4); return buf.dv.getInt32(at, true); }
export function readI64(buf: Buf, at: number): bigint { bounds(buf, at, 8); return buf.dv.getBigInt64(at, true); }
export function readF32(buf: Buf, at: number): number { bounds(buf, at, 4); return buf.dv.getFloat32(at, true); }
export function readF64(buf: Buf, at: number): number { bounds(buf, at, 8); return buf.dv.getFloat64(at, true); }

// ── Half-precision helpers (f16 / bf16) ──────────────────────────────────────
// f16/bf16 have no fully-portable native reads, so they are done by hand
// (plan §8.1). Ported from _f16BitsToF32 / _bf16BitsToF32 in the runtime.

const _scratch = new DataView(new ArrayBuffer(8));

/** Reinterpret a u32 bit pattern as f32. */
export function f32FromBits(bits: number): number {
  _scratch.setUint32(0, bits >>> 0, true);
  return _scratch.getFloat32(0, true);
}

export function f16BitsToF32(b: number): number {
  const sign = (b >>> 15) << 31;
  const exp16 = (b >>> 10) & 0x1f;
  const mant16 = b & 0x3ff;
  let bits32: number;
  if (exp16 === 0) {
    if (mant16 === 0) {
      bits32 = sign >>> 0;
    } else {
      // subnormal f16 → normalised f32
      let m = mant16;
      let e = -14 + 127;
      while ((m & 0x400) === 0) { m <<= 1; e -= 1; }
      bits32 = (sign | (e << 23) | ((m & 0x3ff) << 13)) >>> 0;
    }
  } else if (exp16 === 31) {
    bits32 = (sign | 0x7f800000 | (mant16 << 13)) >>> 0;
  } else {
    bits32 = (sign | ((exp16 + 112) << 23) | (mant16 << 13)) >>> 0;
  }
  return f32FromBits(bits32);
}

export function bf16BitsToF32(b: number): number {
  return f32FromBits((b << 16) >>> 0);
}

export function readF16(buf: Buf, at: number): number { bounds(buf, at, 2); return f16BitsToF32(buf.dv.getUint16(at, true)); }
export function readBf16(buf: Buf, at: number): number { bounds(buf, at, 2); return bf16BitsToF32(buf.dv.getUint16(at, true)); }

/** ZigZag decode without the 32-bit `^` (safe for the leb-int float path). */
export function zigzagDecodeNum(n: number): number {
  return n % 2 === 0 ? n / 2 : -(n + 1) / 2;
}

/** Read an `nbytes` little-endian bitset into a number (bit i = field/optional i). */
export function readBitset(buf: Buf, at: number, nbytes: number): number {
  let b = 0;
  for (let k = 0; k < nbytes; k++) b += buf.u8[at + k]! * 2 ** (8 * k);
  return b;
}

// ── Packed-float decode (self-describing sub-tag scheme) ─────────────────────
// Ported from _decodePackedFloat32 / _decodePackedFloat64. Sub-tags:
//   00 +0, 01 -0, 02 +inf, 03 -inf, 04 NaN, 05 zigzag-LEB int,
//   06 f16 bits (2B), 07 f32 (4B), 08 f64 (8B, f64 only).
// Returns [value, bytesConsumed].

export function decodePackedFloat32(buf: Buf, at: number): [number, number] {
  if (at < 0 || at >= buf.u8.length) throw new DagrError("outsideOfBuffer");
  const tag = buf.u8[at];
  switch (tag) {
    case 0x00: return [0.0, 1];
    case 0x01: return [-0.0, 1];
    case 0x02: return [Infinity, 1];
    case 0x03: return [-Infinity, 1];
    case 0x04: return [NaN, 1];
    case 0x05: { const [zz, b] = readLEB(buf, at + 1); return [zigzagDecodeNum(zz), 1 + b]; }
    case 0x06: return [f16BitsToF32(buf.dv.getUint16(at + 1, true)), 3];
    case 0x07: return [buf.dv.getFloat32(at + 1, true), 5];
    default: return [0.0, 1];
  }
}

export function decodePackedFloat64(buf: Buf, at: number): [number, number] {
  if (at < 0 || at >= buf.u8.length) throw new DagrError("outsideOfBuffer");
  const tag = buf.u8[at];
  switch (tag) {
    case 0x00: return [0.0, 1];
    case 0x01: return [-0.0, 1];
    case 0x02: return [Infinity, 1];
    case 0x03: return [-Infinity, 1];
    case 0x04: return [NaN, 1];
    case 0x05: { const [zz, b] = readLEB(buf, at + 1); return [zigzagDecodeNum(zz), 1 + b]; }
    case 0x06: return [f16BitsToF32(buf.dv.getUint16(at + 1, true)), 3];
    case 0x07: return [buf.dv.getFloat32(at + 1, true), 5];  // f32 widened to f64
    case 0x08: return [buf.dv.getFloat64(at + 1, true), 9];
    default: return [0.0, 1];
  }
}

/** Packed f16/bf16 encoded path: special values only (1 byte). */
export function decodePackedF16(buf: Buf, at: number): [number, number] {
  if (at < 0 || at >= buf.u8.length) throw new DagrError("outsideOfBuffer");
  switch (buf.u8[at]) {
    case 0x00: return [0.0, 1];
    case 0x01: return [-0.0, 1];
    case 0x02: return [Infinity, 1];
    case 0x03: return [-Infinity, 1];
    case 0x04: return [NaN, 1];
    default: return [0.0, 1];
  }
}

// ── Inline fixed-width numeric arrays ([LEB count][elem0..elemN-1] raw LE) ────
// The regular/frozen array layout: reached via a V62 forward pointer, then a LEB
// count followed by `count` fixed-width little-endian elements. Mirrors the
// numeric branch of Array.restore. Returns [array, bytesConsumed].

export function readFixedArrayAt<T>(
  buf: Buf,
  at: number,
  read: (b: Buf, p: number) => T,
  width: number,
): [T[], number] {
  const [count, cB] = readLEB(buf, at);
  const base = at + cB;
  const out: T[] = [];
  for (let i = 0; i < count; i++) out.push(read(buf, base + i * width));
  return [out, cB + count * width];
}

// ── Sub-byte enum arrays: [LEB count][packed bits] ───────────────────────────
// For enums whose backing raw fits in 1/2/4 bits (see _enum_bits_per_elem), the
// element values are packed contiguously: element i lives at bit
// (i % perByte) * bits of byte base + floor(i / perByte). Total payload =
// ceil(count * bits / 8) bytes. Plain LEB count (NOT the count<<2 count-tag —
// enum arrays never use the packed-int mixed encoding). Byte-aligned enums
// (bits === null) reuse readFixedArrayAt with the backing-int reader instead.
// Mirrors the sub-byte branch of Vtable/Packed{Enum}ArrayAccessor. Returns
// [rawValues, bytesConsumed].
export function readEnumBitArrayAt(buf: Buf, at: number, bits: number): [number[], number] {
  const [count, cB] = readLEB(buf, at);
  const base = at + cB;
  const perByte = 8 / bits;
  const mask = (1 << bits) - 1;
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    const byte = buf.u8[base + Math.floor(i / perByte)]!;
    out.push((byte >> ((i % perByte) * bits)) & mask);
  }
  return [out, cB + Math.ceil((count * bits) / 8)];
}

// Raw embedded-graph leaf ("spec/18-raw-embedded-graphs.md" §4). A `raw` node-ref
// field in a packed stream is a variable-size entry `[LEB payloadLen][payload]`;
// the payload is `[padByte][standalone .dagr blob][trailing pad]` when the target
// is alignment-bearing (`global_max_N > 1`), else just `[blob]`. `pos` = start of
// the payloadLen LEB. Returns the absolute root-node position inside the blob,
// opened with the target's OWN-format accessor. Mirrors the Swift raw-ref getter.
export function rawEmbeddedRoot(buf: Buf, pos: number, hasPad: boolean): number {
  const [, plB] = readLEB(buf, pos);              // payloadLen (only used to skip in the scan)
  const bs = pos + plB + (hasPad ? 1 : 0);         // blob byte 0 (framing word), already N-aligned
  const [fr, frB] = readLEB(buf, bs);              // blob framing: root_abs = hdrBytes + (fr >> 2)
  return bs + frB + (fr >> 2);
}

// Byte size of a packed-union payload following its [LEB (typeId<<3)|code]
// header, from the 3-bit `code` (size class). Lets a packed node's scan advance
// past a union field without knowing the concrete variant. Mirrors the skip
// switch in _emit_packed_accessor. `ep` = payload start.
export function packedUnionPayloadBytes(buf: Buf, ep: number, code: number): number {
  switch (code) {
    case 0: return readLEB(buf, ep)[1];                 // LEB-encoded scalar/enum
    case 1: return 1;
    case 2: return 2;
    case 3: return 4;
    case 4: return 8;
    case 5: return decodePackedFloat64(buf, ep)[1];     // self-describing packed float
    case 6: { const [sz, szB] = readLEB(buf, ep); return szB + sz; }  // len-prefixed / inline block
    default: return 0;
  }
}

// Packed node-ref array: [LEB count][opt nil bitset][ (LEB blockLen + child
// packed data) per present element ]. Each child is read at the blockLen
// position (its packed accessor consumes the blockLen itself); the array
// advances by blockLenBytes + blockLen. Mirrors _emit_packed_node_array_accessor
// / _emit_packed_node_opt_array_accessor. `makeChild(buf, pos)` builds an element.
export function readPackedNodeArrayAt<T>(
  buf: Buf, countPos: number, makeChild: (b: Buf, p: number) => T, opt: boolean,
): (T | null)[] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  const bsNil = opt ? ((count + 7) >> 3) : 0;
  let p = nilStart + bsNil;
  const out: (T | null)[] = [];
  for (let i = 0; i < count; i++) {
    if (opt && ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1)) { out.push(null); continue; }
    const [nb, nbB] = readLEB(buf, p);
    out.push(makeChild(buf, p));
    p += nbB + nb;
  }
  return out;
}

// Unsigned `es`-byte little-endian read — the slot value in a union array
// (`readRelOffset`). Used only for reference variants (node/utf8/data/nested-
// union), whose slot holds an offset from the payload base; value variants read
// their typed value straight from the slot position instead. Offsets stay well
// under 2^53, so a plain number is safe even at es=8.
export function readRelOffsetU(buf: Buf, at: number, es: number): number {
  let v = 0;
  for (let k = 0; k < es; k++) v += buf.u8[at + k]! * 2 ** (8 * k);
  return v;
}

/** BigInt es-byte little-endian read — for 64-bit union-array value variants
 * (u64/i64/f64), whose slot value may exceed 2^53. */
export function readRelOffsetUBig(buf: Buf, at: number, es: number): bigint {
  let v = 0n;
  for (let k = 0; k < es; k++) v += BigInt(buf.u8[at + k]!) << BigInt(8 * k);
  return v;
}

// Reinterpret raw integer bits as IEEE-754 (union-array float value variants,
// whose slot holds the bit pattern in `es` bytes → widened to the full type).
const _bitScratch = new DataView(new ArrayBuffer(8));
export function u32BitsToF32(bits: number): number {
  _bitScratch.setUint32(0, bits >>> 0, true);
  return _bitScratch.getFloat32(0, true);
}
export function u64BitsToF64(bits: bigint): number {
  _bitScratch.setBigUint64(0, bits & 0xffffffffffffffffn, true);
  return _bitScratch.getFloat64(0, true);
}

// A union field slot is [LEB (typeId<<2)|wc][payload], the payload exactly
// 1<<wc bytes (a fixed value, a V62/bidir pointer, or a nested union's whole
// encoding). Returns the total slot size, for the frozen forward-walk to skip a
// union field. Mirrors _unionByteCountToWC (inverted).
export function unionSlotBytes(buf: Buf, at: number): number {
  const [raw, tidB] = readLEB(buf, at);
  return tidB + (1 << (raw & 3));
}

// ── Optional (arrayWithOptionals) leaf readers ───────────────────────────────

// bool arrayWithOptionals, regular/frozen (UNCOMPACTED): [LEB count][nil bitset]
// [value bitset], the value bitset indexed by i (not compacted). Mirrors
// _restoreBoolArrayOpt. Returns [(boolean|null)[], bytesConsumed].
export function readBoolOptArrayAt(buf: Buf, at: number): [(boolean | null)[], number] {
  const [count, cB] = readLEB(buf, at);
  const nilStart = at + cB;
  const bs = (count + 7) >> 3;
  const valStart = nilStart + bs;
  const out: (boolean | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    out.push(((buf.u8[valStart + (i >> 3)]! >> (i & 7)) & 1) !== 0);
  }
  return [out, cB + bs + bs];
}

// bool arrayWithOptionals, packed/fp (COMPACTED): [LEB count][nil bitset]
// [compacted value bitset] — value bit ci counts only present elements. Mirrors
// _restorePackedBoolOptArray.
export function readPackedBoolOptArrayAt(buf: Buf, countPos: number): [(boolean | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  const bs = (count + 7) >> 3;
  const valStart = nilStart + bs;
  const out: (boolean | null)[] = [];
  let ci = 0;
  let present = 0;
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    out.push(((buf.u8[valStart + (ci >> 3)]! >> (ci & 7)) & 1) !== 0); ci++; present++;
  }
  return [out, cB + bs + ((present + 7) >> 3)];
}

// Packed u8/i8 arrayWithOptionals: [LEB count][nil bitset][present raw bytes]
// (plain count, one compacted byte per present element). Mirrors
// PackedU8OptArrayAccessor / PackedI8OptArrayAccessor. `signed` → i8.
export function readPackedByteOptArrayAt(buf: Buf, countPos: number, signed: boolean): [(number | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (number | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    let v = buf.u8[p]!; if (signed && v >= 128) v -= 256; out.push(v); p++;
  }
  return [out, p - countPos];
}

// Packed f16/bf16 array: [LEB count][enc bitset][elements]. bit i = 1 → raw
// 2-byte native-LE (conv = f16BitsToF32/bf16BitsToF32); bit i = 0 →
// self-describing special-value tag (decodePackedF16, 1 byte). Mirrors
// _restorePackedF16Array. `conv` maps raw u16 bits → number.
export function readPackedF16ArrayAt(buf: Buf, countPos: number, conv: (b: number) => number): [number[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const encStart = countPos + cB;
  let p = encStart + ((count + 7) >> 3);
  const out: number[] = [];
  for (let i = 0; i < count; i++) {
    const isRaw = ((buf.u8[encStart + (i >> 3)]! >> (i & 7)) & 1) !== 0;
    if (isRaw) { out.push(conv(buf.dv.getUint16(p, true))); p += 2; }
    else { const [v, b] = decodePackedF16(buf, p); out.push(v); p += b; }
  }
  return [out, p - countPos];
}

// Packed f16/bf16 arrayWithOptionals: [LEB count][nil bitset][M raw 2-byte
// present elements] (no enc bitset — present elems always raw). Mirrors
// _restorePackedF16OptArray.
export function readPackedF16OptArrayAt(buf: Buf, countPos: number, conv: (b: number) => number): [(number | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (number | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    out.push(conv(buf.dv.getUint16(p, true))); p += 2;
  }
  return [out, p - countPos];
}

// Packed complex array (utf8/data): [LEB count][ (LEB len + bytes) per element ].
// Each element is exactly the length-prefixed form readUtf8At/readDataAt decode.
// Mirrors _restorePackedComplexArray.
export function readPackedComplexArrayAt<T>(
  buf: Buf, countPos: number, readElem: (b: Buf, p: number) => [T, number],
): [T[], number] {
  const [count, cB] = readLEB(buf, countPos);
  let p = countPos + cB;
  const out: T[] = [];
  for (let i = 0; i < count; i++) { const [v, b] = readElem(buf, p); out.push(v); p += b; }
  return [out, p - countPos];
}

// Packed complex arrayWithOptionals: [LEB count][nil bitset][present elems]
// (nil elements omitted from the payload). Mirrors _restorePackedComplexOptArray.
export function readPackedComplexOptArrayAt<T>(
  buf: Buf, countPos: number, readElem: (b: Buf, p: number) => [T, number],
): [(T | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (T | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    const [v, b] = readElem(buf, p); out.push(v); p += b;
  }
  return [out, p - countPos];
}

// Enum arrayWithOptionals, sub-byte. regular/frozen = UNCOMPACTED value bitset
// (indexed by i); packed/fp = COMPACTED (indexed by ci, present only). Layout:
// [LEB count][nil bitset][value bitset]. Mirrors _restoreEnumBitsetArrayOpt /
// _restoreEnumBitsetArrayOptCompacted.
export function readEnumBitOptArrayAt(buf: Buf, at: number, bits: number, compacted: boolean): [(number | null)[], number] {
  const [count, cB] = readLEB(buf, at);
  const nilStart = at + cB;
  const bsNil = (count + 7) >> 3;
  const valStart = nilStart + bsNil;
  const perByte = 8 / bits;
  const mask = (1 << bits) - 1;
  const out: (number | null)[] = [];
  let ci = 0, present = 0;
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    const j = compacted ? ci : i;
    out.push((buf.u8[valStart + Math.floor(j / perByte)]! >> ((j % perByte) * bits)) & mask);
    ci++; present++;
  }
  const valBytes = compacted ? Math.ceil((present * bits) / 8) : Math.ceil((count * bits) / 8);
  return [out, cB + bsNil + valBytes];
}

// Packed byte-aligned enum arrayWithOptionals: [LEB count][nil bitset][M LEB
// present rawValues]. Mirrors _restorePackedEnumRawOptArray. `big` selects the
// BigInt LEB reader (u64-backed enums).
export function readPackedEnumRawOptArrayAt(buf: Buf, countPos: number): [(number | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (number | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    const [v, b] = readLEB(buf, p); out.push(v); p += b;
  }
  return [out, p - countPos];
}

export function readPackedEnumRawOptArrayAtBig(buf: Buf, countPos: number): [(bigint | null)[], number] {
  const [count, cB] = readLEB(buf, countPos);
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (bigint | null)[] = [];
  for (let i = 0; i < count; i++) {
    if ((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) { out.push(null); continue; }
    const [v, b] = readLEBBig(buf, p); out.push(v); p += b;
  }
  return [out, p - countPos];
}

// Packed byte-aligned enum array: [LEB count][LEB(rawValue) per element]. Unlike
// the regular/frozen byte-aligned layout (fixed-width LE via readFixedArrayAt),
// packed nodes store each raw value as an (unsigned) LEB. Mirrors
// _restorePackedEnumRawArray. Returns [rawValues, bytesConsumed]. Sub-byte enums
// use readEnumBitArrayAt in packed nodes too (identical [count][bitset]).
export function readPackedEnumRawArrayAt(buf: Buf, countPos: number): [number[], number] {
  const [count, cB] = readLEB(buf, countPos);
  let p = countPos + cB;
  const out: number[] = [];
  for (let i = 0; i < count; i++) { const [v, b] = readLEB(buf, p); out.push(v); p += b; }
  return [out, p - countPos];
}

/** BigInt variant of readPackedEnumRawArrayAt (u64-backed enums, e.g. BitCap64). */
export function readPackedEnumRawArrayAtBig(buf: Buf, countPos: number): [bigint[], number] {
  const [count, cB] = readLEB(buf, countPos);
  let p = countPos + cB;
  const out: bigint[] = [];
  for (let i = 0; i < count; i++) { const [v, b] = readLEBBig(buf, p); out.push(v); p += b; }
  return [out, p - countPos];
}

/** ZigZag-decoded LEB (signed packed int elements, ≤32-bit). Returns [value, bytes]. */
export function readZigZagLEB(buf: Buf, at: number): [number, number] {
  const [v, n] = readLEB(buf, at);
  return [zigzagDecode(v), n];
}

/** ZigZag-decoded BigInt LEB (signed i64 packed int elements). */
export function readZigZagLEBBig(buf: Buf, at: number): [bigint, number] {
  const [v, n] = readLEBBig(buf, at);
  return [zigzagDecodeBig(v), n];
}

// ── Packed integer arrays (width ≥ 2): [LEB (count<<2)|tag][elems] ────────────
// tag 0 = all-LEB, 1 = all-raw (fixed width), 2 = mixed (leading enc-bitset,
// bit i set = element i is raw). Mirrors _restorePackedIntArray. `rawFn` reads a
// fixed-width element; `lebFn` reads+decodes a LEB element (returns [value,bytes]).
// (u8/i8 arrays use the plain count + raw layout — readFixedArrayAt.)

export function readPackedIntArrayAt<T>(
  buf: Buf,
  countPos: number,
  width: number,
  rawFn: (b: Buf, p: number) => T,
  lebFn: (b: Buf, p: number) => [T, number],
): [T[], number] {
  const [c, cB] = readLEB(buf, countPos);
  const count = Math.floor(c / 4);   // c >> 2
  const tag = c % 4;                  // c & 3
  const encStart = countPos + cB;
  let p = encStart + (tag === 2 ? ((count + 7) >> 3) : 0);
  const out: T[] = [];
  for (let i = 0; i < count; i++) {
    let isRaw = tag === 1;
    if (tag === 2) isRaw = ((buf.u8[encStart + (i >> 3)]! >> (i & 7)) & 1) !== 0;
    if (isRaw) { out.push(rawFn(buf, p)); p += width; }
    else { const [v, vB] = lebFn(buf, p); out.push(v); p += vB; }
  }
  return [out, p - countPos];
}

// ── Packed float arrays: [LEB (count<<2)|mode][self-describing float elems] ───
// Default (non-`raw`) schema mode: each element is a self-describing packed float
// (decodePackedFloat32/64). Mirrors _restorePackedFloatArray. `dec` returns
// [value, bytes].
export function readPackedFloatArrayAt(
  buf: Buf,
  countPos: number,
  dec: (b: Buf, p: number) => [number, number],
  rawWidth: number,
): [number[], number] {
  const [c, cB] = readLEB(buf, countPos);
  const count = Math.floor(c / 4);  // header = (count << 2) | mode
  const mode = c % 4;               // 0 = packed self-describing, 1 = raw native-LE
  let p = countPos + cB;
  const out: number[] = [];
  if (mode === 1) {
    const rd = rawWidth === 8 ? readF64 : readF32;
    for (let i = 0; i < count; i++) { out.push(rd(buf, p)); p += rawWidth; }
  } else {
    for (let i = 0; i < count; i++) { const [v, b] = dec(buf, p); out.push(v); p += b; }
  }
  return [out, p - countPos];
}

// ── Pointer-table arrays ([LEB (count<<2)|wc][slot table][elem data]) ─────────
// wc selects slot width es = [1,2,4,8][wc]; element i sits at base + slot[i] - 1
// (slot 0 = nil, required arrays never 0). Element decode is caller-supplied.
// Used for utf8/data (value slots, unsigned) element arrays. Mirrors the
// pointer-table branch of Array.restore.

function _relOffsetU(buf: Buf, at: number, es: number): number {
  if (es === 1) return buf.u8[at]!;
  if (es === 2) return buf.dv.getUint16(at, true);
  if (es === 4) return buf.dv.getUint32(at, true);
  return Number(buf.dv.getBigUint64(at, true));
}

// Node-ref slots are signed (two's-complement) so a slot can point backward to a
// shared/cyclic node; value (utf8/data) slots are unsigned. 0 = nil either way.
function _relOffsetS(buf: Buf, at: number, es: number): number {
  if (es === 1) return buf.dv.getInt8(at);
  if (es === 2) return buf.dv.getInt16(at, true);
  if (es === 4) return buf.dv.getInt32(at, true);
  return Number(buf.dv.getBigInt64(at, true));
}

// Returns `(T | null)[]`: slot 0 encodes a nil element (arrayWithOptionals). Plain
// (required) array callers never hit slot 0, so they cast the result to `T[]`.
export function readPtrTableArrayAt<T>(
  buf: Buf,
  at: number,
  readElem: (b: Buf, p: number) => T,
  signed = false,
): (T | null)[] {
  const [hdr, hB] = readLEB(buf, at);
  const count = Math.floor(hdr / 4);   // hdr >> 2
  const es = [1, 2, 4, 8][hdr % 4]!;    // wc = hdr & 3
  const tableBase = at + hB;
  const base = tableBase + count * es;
  const rel = signed ? _relOffsetS : _relOffsetU;
  const out: (T | null)[] = [];
  for (let i = 0; i < count; i++) {
    const ro = rel(buf, tableBase + i * es, es);
    out.push(ro === 0 ? null : readElem(buf, base + ro - 1));  // slot 0 = nil (element-optional)
  }
  return out;
}

// ── Packed element-optional int/float arrays: [count-tag][nil bitset][present] ─
// Compacted: only non-nil elements are stored. nil-bitset bit i set → element i
// is null. Mirror _restorePackedIntOptArray / _restorePackedFloatOptArray.
export function readPackedIntOptArrayAt<T>(
  buf: Buf, countPos: number, width: number,
  rawFn: (b: Buf, p: number) => T,
  lebFn: (b: Buf, p: number) => [T, number],
): [(T | null)[], number] {
  const [c, cB] = readLEB(buf, countPos);
  const count = Math.floor(c / 4);
  const tag = c % 4;
  const nilStart = countPos + cB;
  const bsCnt = (count + 7) >> 3;
  const encStart = nilStart + bsCnt;
  let p = encStart + (tag === 2 ? bsCnt : 0);
  const out: (T | null)[] = [];
  for (let i = 0; i < count; i++) {
    if (((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) !== 0) { out.push(null); continue; }
    let isRaw = tag === 1;
    if (tag === 2) isRaw = ((buf.u8[encStart + (i >> 3)]! >> (i & 7)) & 1) !== 0;
    if (isRaw) { out.push(rawFn(buf, p)); p += width; }
    else { const [v, vB] = lebFn(buf, p); out.push(v); p += vB; }
  }
  return [out, p - countPos];
}

export function readPackedFloatOptArrayAt(
  buf: Buf, countPos: number,
  dec: (b: Buf, p: number) => [number, number],
  rawWidth: number,
): [(number | null)[], number] {
  const [c, cB] = readLEB(buf, countPos);
  const count = Math.floor(c / 4);  // header = (count << 2) | mode
  const mode = c % 4;               // 0 = packed self-describing, 1 = raw native-LE
  const nilStart = countPos + cB;
  let p = nilStart + ((count + 7) >> 3);
  const out: (number | null)[] = [];
  const rd = rawWidth === 8 ? readF64 : readF32;
  for (let i = 0; i < count; i++) {
    if (((buf.u8[nilStart + (i >> 3)]! >> (i & 7)) & 1) !== 0) { out.push(null); continue; }
    if (mode === 1) { out.push(rd(buf, p)); p += rawWidth; }
    else { const [v, b] = dec(buf, p); out.push(v); p += b; }
  }
  return [out, p - countPos];
}

// ── Bool arrays: [LEB count][bitset ceil(count/8)] (bit i = element i) ────────
export function readBoolArrayAt(buf: Buf, at: number): [boolean[], number] {
  const [count, cB] = readLEB(buf, at);
  const bsStart = at + cB;
  const out: boolean[] = [];
  for (let i = 0; i < count; i++) out.push(((buf.u8[bsStart + (i >> 3)]! >> (i & 7)) & 1) !== 0);
  return [out, cB + ((count + 7) >> 3)];
}

// ── Element-optional fixed-width arrays: [LEB count][nil bitset][count slots] ─
// Uncompacted: all `count` fixed-width slots present (nil elements zero-filled);
// element i is null when nil-bitset bit i is set. Mirrors the optional numeric
// branch of Array.restore.
export function readOptFixedArrayAt<T>(
  buf: Buf,
  at: number,
  read: (b: Buf, p: number) => T,
  width: number,
): [(T | null)[], number] {
  const [count, cB] = readLEB(buf, at);
  const bsStart = at + cB;
  const bsLen = (count + 7) >> 3;
  const base = bsStart + bsLen;
  const out: (T | null)[] = [];
  for (let i = 0; i < count; i++) {
    const isNil = ((buf.u8[bsStart + (i >> 3)]! >> (i & 7)) & 1) !== 0;
    out.push(isNil ? null : read(buf, base + i * width));
  }
  return [out, cB + bsLen + count * width];
}

// ── Length-prefixed utf8 / data (LEB count + bytes) ──────────────────────────
// Mirrors String.restore / Data.restore. Returns [value, totalBytesConsumed] so
// inline (packed / frozen-packed) callers can advance a cursor; forward-pointer
// (frozen / regular) callers ignore the count.

const _utf8Decoder = new TextDecoder();

export function readUtf8At(buf: Buf, at: number): [string, number] {
  const [len, lenB] = readLEB(buf, at);
  const start = at + lenB;
  const u8 = buf.u8;
  if (start + len > u8.length) throw new DagrError("outsideOfBuffer");
  // Short ASCII strings: build directly — TextDecoder's per-call overhead dominates a
  // small string. Anything else (or on the first non-ASCII byte) goes to TextDecoder.
  if (len <= 32) {
    let s = "";
    let i = start;
    const end = start + len;
    for (; i < end; i++) {
      const c = u8[i]!;
      if (c >= 0x80) break;
      s += String.fromCharCode(c);
    }
    if (i === end) return [s, lenB + len];
  }
  return [_utf8Decoder.decode(u8.subarray(start, start + len)), lenB + len];
}

export function readDataAt(buf: Buf, at: number): [Uint8Array, number] {
  const [len, lenB] = readLEB(buf, at);
  const start = at + lenB;
  if (start + len > buf.u8.length) throw new DagrError("outsideOfBuffer");
  // Wrap in a fresh plain Uint8Array: buf.u8 may be a Node Buffer, whose slice
  // is also a Buffer — callers (and deepStrictEqual) expect a plain Uint8Array.
  return [new Uint8Array(buf.u8.subarray(start, start + len)), lenB + len];
}

/**
 * Derive the root node's absolute offset from the framing word.
 * Mirrors `lazyRoot` in AddressBookLazy.swift:
 *   framing LEB; bit 0 = custom-header flag (must be 0 for the spike),
 *   root = hdrBytes + (framing >> 2).
 */
export function rootOffset(buf: Buf): number {
  const [framing, hdrBytes] = readLEB(buf, 0);
  if ((framing & 1) !== 0) throw new DagrError("missingHeader"); // custom header: Phase 1+
  return hdrBytes + (framing >> 2);
}
