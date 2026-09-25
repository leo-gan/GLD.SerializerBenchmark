// Package dagr is the hand-written Dagr wire runtime for the Go target
// (spec/37-go-codegen-plan.md §8). Reader model: a borrowed []byte plus
// position-passing free functions returning (value, bytesConsumed), mirroring the
// Swift/Rust/Odin runtimes one to one. Generated accessors (dagr/codegen/go/) call
// into this package; nothing here is schema-specific.
//
// Fixed-width scalars go through encoding/binary (bounds-checked; the compiler folds
// the byte assembly into a single load on amd64/arm64), so the reader needs no
// `unsafe`. Varints reuse encoding/binary's Uvarint, which is the same low-7-first
// LEB128 Dagr uses (verified in reader_test.go against the hand-rolled reference).
package dagr

import (
	"encoding/binary"
	"errors"
	"math"
	"unsafe"
)

// ErrCustomHeader is returned by HeaderFrame when the framing word does not carry the
// custom-header flag (spec 15); such buffers are opened through the header-aware
// entry point instead.
var ErrCustomHeader = errors.New("dagr: buffer carries a custom header")

// ErrBadFraming is returned by RootOffset when the framing varint is malformed.
var ErrBadFraming = errors.New("dagr: malformed framing word")

// ErrMalformed is returned by a graph's validating Open when walking the reachable
// graph hit out-of-range or inconsistent bytes.
var ErrMalformed = errors.New("dagr: malformed buffer")

// ── Varints ────────────────────────────────────────────────────────────────────

// ReadLEB decodes an unsigned LEB128 varint at `at`, returning (value, bytesConsumed).
func ReadLEB(buf []byte, at int) (uint64, int) {
	v, n := binary.Uvarint(buf[at:])
	if n <= 0 {
		panic("dagr: malformed LEB128 varint")
	}
	return v, n
}

// ZigZagDecode maps an unsigned ZigZag value back to a signed integer.
func ZigZagDecode(n uint64) int64 {
	return int64(n>>1) ^ -int64(n&1)
}

// ReadZigZagLEB decodes a ZigZag-LEB128 signed varint (packed signed ints).
func ReadZigZagLEB(buf []byte, at int) (int64, int) {
	v, n := ReadLEB(buf, at)
	return ZigZagDecode(v), n
}

// LebEnd returns the position just past the varint at `at` (skip a self-delimiting
// encoded int / enum payload).
func LebEnd(buf []byte, at int) int {
	_, n := ReadLEB(buf, at)
	return at + n
}

// SkipBlob returns the end of a size-prefixed blob `[LEB N][N bytes]` at `at`.
func SkipBlob(buf []byte, at int) int {
	n, b := ReadLEB(buf, at)
	return at + b + int(n)
}

// ── V62 pointers ───────────────────────────────────────────────────────────────

// ReadV62 decodes a V62 pointer: the low 2 bits of the first byte select the width
// (0→1, 1→2, 2→4, 3→8 bytes); the value is raw>>2. Unsigned (forward pointers);
// wrap in ReadZigZagV62 for bidirectional node-ref pointers.
func ReadV62(buf []byte, at int) (uint64, int) {
	switch buf[at] & 3 {
	case 0:
		return uint64(buf[at]) >> 2, 1
	case 1:
		return uint64(ReadU16(buf, at)) >> 2, 2
	case 2:
		return uint64(ReadU32(buf, at)) >> 2, 4
	default:
		return ReadU64(buf, at) >> 2, 8
	}
}

// ReadZigZagV62 decodes a bidirectional (ZigZag) V62 pointer.
func ReadZigZagV62(buf []byte, at int) (int64, int) {
	v, n := ReadV62(buf, at)
	return ZigZagDecode(v), n
}

// V62Bytes is the byte width of the V62 pointer at `at` (advances a frozen walk).
func V62Bytes(buf []byte, at int) int {
	return 1 << (buf[at] & 3)
}

// FwdTarget resolves the V62 forward pointer at `slot` to the position it targets.
func FwdTarget(buf []byte, slot int) int {
	fwd, fwdB := ReadV62(buf, slot)
	return slot + fwdB + int(fwd)
}

// ── Fixed-width native-LE scalars (unaligned; encoding/binary) ─────────────────

func ReadU8(buf []byte, at int) uint8   { return buf[at] }
func ReadU16(buf []byte, at int) uint16 { return binary.LittleEndian.Uint16(buf[at:]) }
func ReadU32(buf []byte, at int) uint32 { return binary.LittleEndian.Uint32(buf[at:]) }
func ReadU64(buf []byte, at int) uint64 { return binary.LittleEndian.Uint64(buf[at:]) }
func ReadI8(buf []byte, at int) int8    { return int8(buf[at]) }
func ReadI16(buf []byte, at int) int16  { return int16(binary.LittleEndian.Uint16(buf[at:])) }
func ReadI32(buf []byte, at int) int32  { return int32(binary.LittleEndian.Uint32(buf[at:])) }
func ReadI64(buf []byte, at int) int64  { return int64(binary.LittleEndian.Uint64(buf[at:])) }
func ReadF32(buf []byte, at int) float32 {
	return math.Float32frombits(binary.LittleEndian.Uint32(buf[at:]))
}
func ReadF64(buf []byte, at int) float64 {
	return math.Float64frombits(binary.LittleEndian.Uint64(buf[at:]))
}
func ReadBool(buf []byte, at int) bool { return buf[at] != 0 }

// ReadF16 reads an IEEE-754 half at `at` and widens it to float32 (the API type;
// Go has no native f16).
func ReadF16(buf []byte, at int) float32 {
	return F16BitsToF32(binary.LittleEndian.Uint16(buf[at:]))
}

// ReadBf16 reads a bfloat16 at `at` and widens it to float32.
func ReadBf16(buf []byte, at int) float32 {
	return Bf16BitsToF32(binary.LittleEndian.Uint16(buf[at:]))
}

// F16BitsToF32 converts IEEE-754 half bits to a float32 (exact; subnormals normalised).
func F16BitsToF32(h uint16) float32 {
	sign := uint32(h>>15) << 31
	exp := uint32(h>>10) & 0x1f
	mant := uint32(h) & 0x3ff
	var bits uint32
	switch {
	case exp == 0:
		if mant == 0 {
			bits = sign
		} else {
			m, e := mant, uint32(127-14)
			for m&0x400 == 0 {
				m <<= 1
				e--
			}
			bits = sign | e<<23 | (m&0x3ff)<<13
		}
	case exp == 31:
		bits = sign | 0x7f800000 | mant<<13
	default:
		bits = sign | (exp+112)<<23 | mant<<13
	}
	return math.Float32frombits(bits)
}

// Bf16BitsToF32 converts bfloat16 bits to a float32 (the high 16 bits of the f32).
func Bf16BitsToF32(b uint16) float32 {
	return math.Float32frombits(uint32(b) << 16)
}

// ReadUintLE reads an unsigned `es`-byte little-endian integer (pointer-table slots).
func ReadUintLE(buf []byte, at int, es int) int {
	var v uint64
	for k := 0; k < es; k++ {
		v |= uint64(buf[at+k]) << (8 * k)
	}
	return int(v)
}

// ReadIntLE reads a signed (two's-complement) `es`-byte little-endian integer —
// node-ref array slots may point backward to a shared/cyclic node.
func ReadIntLE(buf []byte, at int, es int) int {
	v := ReadUintLE(buf, at, es)
	bits := 8 * es
	if bits < 64 && v&(1<<(bits-1)) != 0 {
		v -= 1 << bits
	}
	return v
}

// ReadBitset reads an `n`-byte little-endian presence/encoding bitset (n ≤ 8).
func ReadBitset(buf []byte, at int, n int) uint64 {
	var v uint64
	for k := 0; k < n; k++ {
		v |= uint64(buf[at+k]) << (8 * k)
	}
	return v
}

// ── Length-prefixed utf8 / data ────────────────────────────────────────────────

// ReadBytes returns the payload of a `[LEB count][bytes]` blob at `at` as a
// zero-copy sub-slice, plus the total bytes consumed (inline callers advance by it).
func ReadBytes(buf []byte, at int) ([]byte, int) {
	n, b := ReadLEB(buf, at)
	start := at + b
	return buf[start : start+int(n)], b + int(n)
}

// ReadUtf8 returns the utf8 payload at `at` as an (owned, copied) string.
func ReadUtf8(buf []byte, at int) (string, int) {
	bs, n := ReadBytes(buf, at)
	return string(bs), n
}

// ── Arrays (spec 04) ───────────────────────────────────────────────────────────

// ArrayPayloadAt parses `[LEB count][elements]` at `ps`, returning (base, count).
func ArrayPayloadAt(buf []byte, ps int) (int, int) {
	c, cB := ReadLEB(buf, ps)
	return ps + cB, int(c)
}

// ArrayPayload resolves a regular-node array slot (a V62 forward pointer) to
// (elementBase, count).
func ArrayPayload(buf []byte, slot int) (int, int) {
	return ArrayPayloadAt(buf, FwdTarget(buf, slot))
}

// PtrTableAt parses a pointer-table payload `[LEB (count<<2)|wc][count×es slots][data]`
// at `ps`, returning (tableBase, dataBase, count, es). Element i lives at
// dataBase + slot[i] - 1 (slot 0 = nil).
func PtrTableAt(buf []byte, ps int) (int, int, int, int) {
	hdr, hB := ReadLEB(buf, ps)
	count := int(hdr >> 2)
	es := 1 << (hdr & 3)
	tableBase := ps + hB
	return tableBase, tableBase + count*es, count, es
}

// PtrTable resolves a pointer-table array slot (V62 forward pointer) to its layout.
func PtrTable(buf []byte, slot int) (int, int, int, int) {
	return PtrTableAt(buf, FwdTarget(buf, slot))
}

// AwoPayloadAt parses an inline arrayWithOptionals payload `[LEB count][nil bitset]
// [values]` at `ps`, returning (nilBase, valueBase, count). Uncompacted: value i is
// indexed by i regardless of nil elements.
func AwoPayloadAt(buf []byte, ps int) (int, int, int) {
	c, cB := ReadLEB(buf, ps)
	nilBase := ps + cB
	count := int(c)
	return nilBase, nilBase + (count+7)/8, count
}

// AwoPayload resolves an arrayWithOptionals slot (V62 forward pointer) to its layout.
func AwoPayload(buf []byte, slot int) (int, int, int) {
	return AwoPayloadAt(buf, FwdTarget(buf, slot))
}

// NilBit reports whether bit i of the nil bitset at nilBase is set (element i absent).
func NilBit(buf []byte, nilBase int, i int) bool {
	return (buf[nilBase+(i>>3)]>>(i&7))&1 != 0
}

// Bit reports bit i of a bitset starting at `base` (element-i bool arrays).
func Bit(buf []byte, base int, i int) bool {
	return (buf[base+(i>>3)]>>(i&7))&1 != 0
}

// DecodeArray decodes `count` fixed-width elements of `width` bytes at `base` into a
// new slice via `rd`. Allocates; the zero-copy alternative is the per-element `At`
// getter (or the aligned view, spec 12).
func DecodeArray[T any](buf []byte, base, count, width int, rd func([]byte, int) T) []T {
	out := make([]T, count)
	for i := range out {
		out[i] = rd(buf, base+i*width)
	}
	return out
}

// ── Packed nodes (spec 07) ─────────────────────────────────────────────────────

// PackedBounds reads the block-length LEB at `start`, returning (entriesStart, entriesEnd).
func PackedBounds(buf []byte, start int) (int, int) {
	s, b := ReadLEB(buf, start)
	es := start + b
	return es, es + int(s)
}

// DecodePackedF32 decodes a self-describing packed float (§12 sub-tag byte):
// 00 +0 · 01 -0 · 02 +inf · 03 -inf · 04 NaN · 05 zigzag-LEB int · 06 f16 bits ·
// 07 f32 raw. Returns (value, bytesConsumed).
func DecodePackedF32(buf []byte, at int) (float32, int) {
	switch buf[at] {
	case 0:
		return 0, 1
	case 1:
		return math.Float32frombits(0x80000000), 1
	case 2:
		return math.Float32frombits(0x7F800000), 1
	case 3:
		return math.Float32frombits(0xFF800000), 1
	case 4:
		return math.Float32frombits(0x7FC00000), 1
	case 5:
		v, n := ReadZigZagLEB(buf, at+1)
		return float32(v), 1 + n
	case 6:
		return ReadF16(buf, at+1), 3
	default:
		return ReadF32(buf, at+1), 5
	}
}

// DecodePackedF64 is the f64 form of DecodePackedF32 (adds 08 f64 raw).
func DecodePackedF64(buf []byte, at int) (float64, int) {
	switch buf[at] {
	case 0:
		return 0, 1
	case 1:
		return math.Float64frombits(0x8000000000000000), 1
	case 2:
		return math.Float64frombits(0x7FF0000000000000), 1
	case 3:
		return math.Float64frombits(0xFFF0000000000000), 1
	case 4:
		return math.Float64frombits(0x7FF8000000000000), 1
	case 5:
		v, n := ReadZigZagLEB(buf, at+1)
		return float64(v), 1 + n
	case 6:
		return float64(ReadF16(buf, at+1)), 3
	case 7:
		return float64(ReadF32(buf, at+1)), 5
	default:
		return ReadF64(buf, at+1), 9
	}
}

// DecodePackedF16 decodes the encoded (special-value, 1-byte) form of a packed f16;
// a non-special value is stored raw and handled by the caller.
func DecodePackedF16(buf []byte, at int) (float32, int) {
	switch buf[at] {
	case 1:
		return math.Float32frombits(0x80000000), 1
	case 2:
		return math.Float32frombits(0x7F800000), 1
	case 3:
		return math.Float32frombits(0xFF800000), 1
	case 4:
		return math.Float32frombits(0x7FC00000), 1
	default:
		return 0, 1
	}
}

// DecodePackedBf16 is the bf16 twin of DecodePackedF16.
func DecodePackedBf16(buf []byte, at int) (float32, int) {
	return DecodePackedF16(buf, at)
}

// PackedUnionHeader parses `[LEB (typeId<<3)|code]` at `at`, returning
// (payloadPos, tag, code). code: 0 LEB · 1/2/3/4 = 1/2/4/8 raw bytes · 5 packed
// float · 6 len-prefixed block.
func PackedUnionHeader(buf []byte, at int) (int, uint8, uint8) {
	r, b := ReadLEB(buf, at)
	return at + b, uint8((r >> 3) & 0xFF), uint8(r & 7)
}

// PackedUnionPayloadBytes is the byte size of a packed-union payload after its header.
func PackedUnionPayloadBytes(buf []byte, ep int, code int) int {
	switch code {
	case 0:
		_, b := ReadLEB(buf, ep)
		return b
	case 1:
		return 1
	case 2:
		return 2
	case 3:
		return 4
	case 4:
		return 8
	case 5:
		_, n := DecodePackedF64(buf, ep)
		return n
	default:
		r, b := ReadLEB(buf, ep)
		return b + int(r)
	}
}

// ── Unions (spec 05) ───────────────────────────────────────────────────────────

// UnionHeader parses a union field slot header `[LEB (tag<<2)|wc]` at `pos`,
// returning (payloadPos, tag).
func UnionHeader(buf []byte, pos int) (int, uint8) {
	r, b := ReadLEB(buf, pos)
	return pos + b, uint8(r >> 2)
}

// UnionSlotBytes is the total size of a union field slot `[LEB (tag<<2)|wc][1<<wc]`
// (advances a frozen walk).
func UnionSlotBytes(buf []byte, at int) int {
	r, b := ReadLEB(buf, at)
	return b + (1 << (r & 3))
}

// ── Raw embedded graphs (spec 18) ──────────────────────────────────────────────

// RawEmbeddedRoot returns the absolute root position inside a raw-embedded graph
// entry `[LEB payloadLen][pad?][standalone blob]` at `pos`.
func RawEmbeddedRoot(buf []byte, pos int, hasPad bool) int {
	_, plb := ReadLEB(buf, pos)
	bs := pos + plb
	if hasPad {
		bs++
	}
	fr, frb := ReadLEB(buf, bs)
	return bs + frb + int(fr>>2)
}

// ── Framing + vtables (spec 06) ────────────────────────────────────────────────

// RootOffset returns the absolute root-node position from the framing word.
func RootOffset(buf []byte) (int, error) {
	framing, hb := binary.Uvarint(buf)
	if hb <= 0 || framing&2 != 0 {
		return 0, ErrBadFraming
	}
	// With a header (bit 0) the stored offset already spans it (spec 15 §4), so the
	// root position is the same expression either way.
	return hb + int(framing>>2), nil
}

// HeaderFrame parses the framing word of a DataGraph buffer that carries a spec-15
// header: the header's start (right after the framing word), its total span (size LEB
// + content), and the header-free root offset the producer signed over (stored − span).
// ErrCustomHeader when the buffer carries no header.
func HeaderFrame(buf []byte) (start, span, rootOffset int, err error) {
	framing, hb := binary.Uvarint(buf)
	if hb <= 0 || framing&2 != 0 {
		return 0, 0, 0, ErrBadFraming
	}
	if framing&1 == 0 {
		return 0, 0, 0, ErrCustomHeader
	}
	hcs, hcsb := binary.Uvarint(buf[hb:])
	if hcsb <= 0 || hb+hcsb+int(hcs) > len(buf) {
		return 0, 0, 0, ErrBadFraming
	}
	span = hcsb + int(hcs)
	stored := int(framing >> 2)
	if stored < span {
		return 0, 0, 0, ErrBadFraming
	}
	return hb, span, stored - span, nil
}

// HasHeader reports whether a DataGraph buffer's framing word carries a header.
func HasHeader(buf []byte) bool {
	framing, hb := binary.Uvarint(buf)
	return hb > 0 && framing&1 == 1
}

// FieldOffset returns the node-relative offset of vtable field `idx` of the regular
// node at `start`, or -1 when absent, without materialising the table. The
// node-start LEB is ZigZag: even = dedup forward ref (+b1 off-by-one), odd = fresh
// vtable. Header LEB = (fieldCount<<1)|wide.
func FieldOffset(buf []byte, start int, idx int) int {
	offsetValue, b1 := ReadLEB(buf, start)
	adj := 0
	if offsetValue&1 == 0 {
		adj = b1
	}
	vtStart := start + int(ZigZagDecode(offsetValue)) + adj
	vtSize, b2 := ReadLEB(buf, vtStart)
	count := int(vtSize >> 1)
	if idx >= count {
		return -1
	}
	wide := vtSize&1 != 0
	var v int
	if wide {
		v = int(ReadU16(buf, vtStart+b2+idx*2))
	} else {
		v = int(buf[vtStart+b2+idx])
	}
	if v == 0 {
		return -1
	}
	return v - 1 + b1
}

// ── Arena handle packing (spec 09) ─────────────────────────────────────────────

// IdxMask selects the 40-bit index of a packed handle.
const IdxMask uint64 = 0xFF_FFFF_FFFF

// Pack builds a generational handle `generation<<40 | index`.
func Pack(gen uint32, idx int) uint64 { return uint64(gen)<<40 | uint64(idx)&IdxMask }

// UnpackIdx extracts the index of a packed handle.
func UnpackIdx(h uint64) int { return int(h & IdxMask) }

// UnpackGen extracts the generation of a packed handle.
func UnpackGen(h uint64) uint32 { return uint32(h >> 40) }

// Fnv1a hashes bytes with FNV-1a (structural hashing, spec 37 §8.8).
func Fnv1a(data []byte) uint64 {
	h := uint64(0xcbf29ce484222325)
	for _, b := range data {
		h = (h ^ uint64(b)) * 0x100000001b3
	}
	return h
}

// ── Aligned zero-copy views (spec 12, plan 37 §8.2) ──────────────────────────────

var hostLittleEndian = binary.NativeEndian.Uint16([]byte{1, 0}) == 1

// AlignedView reinterprets `count` native little-endian elements of `width` bytes at
// buf[base:] as a []T without copying. ok is false when the element base is not on a
// `width` boundary in memory (an aligned(N) array is aligned relative to the buffer
// start, so the buffer itself must be N-aligned — see AlignedRegion) or when the host is
// big-endian; callers then fall back to the decoding getter.
func AlignedView[T any](buf []byte, base, count, width int) ([]T, bool) {
	if count == 0 {
		return []T{}, true
	}
	if !hostLittleEndian || base < 0 || base+count*width > len(buf) {
		return nil, false
	}
	p := unsafe.Pointer(&buf[base])
	if uintptr(p)%uintptr(width) != 0 {
		return nil, false
	}
	return unsafe.Slice((*T)(p), count), true
}

// SeenKey identifies a node position across buffers: the arena restore keys its
// dedup map by it, so a node materialized from a prototype blob (spec 14 §4 default
// synthesis) never aliases a node at the same offset of the main buffer.
type SeenKey struct {
	buf uintptr
	pos int
}

// SeenAt returns the SeenKey of position pos in buf.
func SeenAt(buf []byte, pos int) SeenKey {
	if len(buf) == 0 {
		return SeenKey{0, pos}
	}
	return SeenKey{uintptr(unsafe.Pointer(&buf[0])), pos}
}
