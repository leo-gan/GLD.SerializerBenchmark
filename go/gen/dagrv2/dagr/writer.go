package dagr

// Dagr serializer runtime — a faithful port of the reference BACKWARD-growing builder
// (Swift DataArenaBuilder / targets/typescript/src/dagr_writer.ts). Every store writes
// toward the FRONT of one buffer: the stored bytes occupy [len(buf)-cursor, len(buf));
// `cursor` is the total stored so far, an offset is the cursor value at store time, and
// the forward distance between two stored things is cursorNow - offset. The buffer
// doubles on demand; MakeData copies the stored region out.
//
// Gate: ToBytes(Restore(fixture)) must equal the fixture byte-for-byte.

import (
	"encoding/binary"
	"math"
	"math/bits"
	"strconv"
	"strings"
	"unsafe"
)

// Opt is an optional value: the stored form of an arrayWithOptionals element and of
// an optional arena field. Ok=false is the nil element.
type Opt[T any] struct {
	V  T
	Ok bool
}

// Some wraps a present value.
func Some[T any](v T) Opt[T] { return Opt[T]{V: v, Ok: true} }

// None is the absent value.
func None[T any]() Opt[T] { return Opt[T]{} }

// LebLength is the LEB128 byte length of v (0 → 1).
func LebLength(v uint64) int {
	if v == 0 {
		return 1
	}
	return (bits.Len64(v) + 6) / 7
}

// ToZigZag maps a signed distance to its unsigned ZigZag form.
func ToZigZag(v int64) uint64 {
	return uint64(v<<1) ^ uint64(v>>63)
}

// toNegativZigZag is the vtable size marker: 0 → 0, else (v-1)<<1|1.
func toNegativZigZag(v uint64) uint64 {
	if v == 0 {
		return 0
	}
	return (v-1)<<1 | 1
}

// F32Bits / F64Bits: IEEE-754 bit patterns (union-array value slots store raw bits).
func F32Bits(v float32) uint64 { return uint64(math.Float32bits(v)) }
func F64Bits(v float64) uint64 { return math.Float64bits(v) }

// F32ToBf16Bits rounds a float32 to bfloat16 (round-to-nearest-even on the top 16 bits).
func F32ToBf16Bits(v float32) uint16 {
	b := math.Float32bits(v)
	lsb := (b >> 16) & 1
	return uint16((b + 0x7fff + lsb) >> 16)
}

// F32ToF16Bits rounds a float32 to IEEE-754 half (round-to-nearest-even, subnormals).
func F32ToF16Bits(v float32) uint16 {
	if v != v {
		return 0x7e00
	}
	b := math.Float32bits(v)
	sign := uint16((b >> 16) & 0x8000)
	exp32 := int((b >> 23) & 0xff)
	mant32 := b & 0x7fffff
	if exp32 == 0xff {
		return sign | 0x7c00
	}
	if b&0x7fffffff == 0 {
		return sign
	}
	exp16 := exp32 - 127 + 15
	if exp16 >= 0x1f {
		return sign | 0x7c00
	}
	if exp16 <= 0 {
		if exp16 < -10 {
			return sign
		}
		m := mant32 | 0x800000
		shift := uint(14 - exp16)
		low := m & (1<<shift - 1)
		half := uint32(1) << (shift - 1)
		r := m >> shift
		if low > half || (low == half && r&1 == 1) {
			r++
		}
		return sign | uint16(r)
	}
	half16 := uint32(exp16)<<10 | mant32>>13
	round := (mant32 >> 12) & 1
	sticky := mant32&0xfff != 0
	if round == 1 && (sticky || half16&1 == 1) {
		half16++
	}
	return sign | uint16(half16)
}

// F32ToF16BitsExact converts only when the value is exactly representable as f16.
func F32ToF16BitsExact(v float32) (uint16, bool) {
	b := math.Float32bits(v)
	sign := b >> 31
	exp32 := (b >> 23) & 0xff
	mant32 := b & 0x7fffff
	if exp32 == 0xff {
		return 0, false
	}
	if exp32 == 0 {
		if mant32 == 0 {
			return uint16(sign << 15), true
		}
		return 0, false
	}
	exp16 := int(exp32) - 112
	if exp16 < 1 || exp16 > 30 {
		return 0, false
	}
	if mant32&0x1fff != 0 {
		return 0, false
	}
	return uint16(sign<<15 | uint32(exp16)<<10 | mant32>>13), true
}

func offsetWidthCode(v uint64) int {
	switch {
	case v <= 0xff:
		return 0
	case v <= 0xffff:
		return 1
	case v <= 0xffffffff:
		return 2
	default:
		return 3
	}
}

func signedWidthCode(d int64) int {
	switch {
	case d >= -128 && d <= 127:
		return 0
	case d >= -32768 && d <= 32767:
		return 1
	case d >= -2147483648 && d <= 2147483647:
		return 2
	default:
		return 3
	}
}

// NodeKey identifies a node for dedup and cycle late-binding: the node type's ordinal
// in its graph plus the packed arena handle (unique within one arena).
type NodeKey struct {
	Type   int
	Handle uint64
}

// NodeStoreRef is a node-store result: Pending=false → the node is fully stored at Off;
// Pending=true → the node is an ancestor still being stored (a cycle), so a pointer to
// it is written as a fixed-width placeholder patched by FinishStoring.
type NodeStoreRef struct {
	Off     int
	Pending bool
	Key     NodeKey
}

// NodeOffset unwraps a resolved ref; panics on a pending one (a cycle reached a context
// without late-binding support, e.g. a union-array node variant).
func NodeOffset(r NodeStoreRef) int {
	if r.Pending {
		panic("dagr: cyclic reference in a context without late-binding support")
	}
	return r.Off
}

// UnionApplied is a regular/frozen union slot descriptor: the content was stored by the
// apply step; Emit writes the inline value or the pointer in the value pass.
type UnionApplied struct {
	ID   int
	Emit func(*Builder)
}

// UnionArrElem is one union-array element's slot descriptor (Kind 'v' value bits /
// 'p' pointer distance / 'b' node bidir distance).
type UnionArrElem struct {
	Kind byte
	Val  uint64
	Tid  int
}

// PackedUnionHdr is a packed union header (typeId + payload code).
type PackedUnionHdr struct {
	ID   int
	Code int
}

type lateBind struct {
	cursorAt int
	base     int
	arrayEnd int
	es       int
}

// Builder is the backward-growing serializer.
type Builder struct {
	buf    []byte
	cursor int

	vtLookup     map[string]int
	stringLookup map[string]int
	// StructLookup caches node → offset (shared/cyclic node dedup, = Rust node_cache).
	StructLookup map[NodeKey]int
	inProgress   map[NodeKey]bool
	lateBindings map[NodeKey][]lateBind

	// ReserveFieldPointerSize is the placeholder width for cycle back-edges, derived
	// from maxSize exactly like Rust/Swift (2 MiB → 4 bytes, 1024 → 2 bytes).
	ReserveFieldPointerSize int
}

// NewBuilder creates a builder; maxSize sets the back-reference placeholder width and
// must match across producers for byte-identity (0 → the 2 MiB default).
func NewBuilder(maxSize int) *Builder {
	if maxSize <= 0 {
		maxSize = 2 * 1024 * 1024
	}
	nbits := bits.Len(uint(maxSize)) + 3
	nbytes := nbits/8 + boolInt(nbits&7 != 0)
	rfps := 1
	for rfps < nbytes {
		rfps <<= 1
	}
	return &Builder{
		buf:                     make([]byte, 64),
		vtLookup:                map[string]int{},
		stringLookup:            map[string]int{},
		StructLookup:            map[NodeKey]int{},
		inProgress:              map[NodeKey]bool{},
		lateBindings:            map[NodeKey][]lateBind{},
		ReserveFieldPointerSize: rfps,
	}
}

func boolInt(b bool) int {
	if b {
		return 1
	}
	return 0
}

// Cursor is the total number of bytes stored so far.
func (b *Builder) Cursor() int { return b.cursor }

func (b *Builder) ensure(n int) {
	if len(b.buf)-b.cursor >= n {
		return
	}
	c := len(b.buf) * 2
	for c-b.cursor < n {
		c *= 2
	}
	nb := make([]byte, c)
	copy(nb[c-b.cursor:], b.buf[len(b.buf)-b.cursor:])
	b.buf = nb
}

// wpos reserves n bytes at the front of the stored region; returns their start.
func (b *Builder) wpos(n int) int {
	b.ensure(n)
	p := len(b.buf) - b.cursor - n
	b.cursor += n
	return p
}

func (b *Builder) StoreU8(v uint8) int {
	p := b.wpos(1)
	b.buf[p] = v
	return b.cursor
}

func (b *Builder) StoreU16(v uint16) int {
	p := b.wpos(2)
	binary.LittleEndian.PutUint16(b.buf[p:], v)
	return b.cursor
}

func (b *Builder) StoreU32(v uint32) int {
	p := b.wpos(4)
	binary.LittleEndian.PutUint32(b.buf[p:], v)
	return b.cursor
}

func (b *Builder) StoreU64(v uint64) int {
	p := b.wpos(8)
	binary.LittleEndian.PutUint64(b.buf[p:], v)
	return b.cursor
}

func (b *Builder) StoreI8(v int8) int     { return b.StoreU8(uint8(v)) }
func (b *Builder) StoreI16(v int16) int   { return b.StoreU16(uint16(v)) }
func (b *Builder) StoreI32(v int32) int   { return b.StoreU32(uint32(v)) }
func (b *Builder) StoreI64(v int64) int   { return b.StoreU64(uint64(v)) }
func (b *Builder) StoreF32(v float32) int { return b.StoreU32(math.Float32bits(v)) }
func (b *Builder) StoreF64(v float64) int { return b.StoreU64(math.Float64bits(v)) }
func (b *Builder) StoreF16(v float32) int { return b.StoreU16(F32ToF16Bits(v)) }
func (b *Builder) StoreBf16(v float32) int {
	return b.StoreU16(F32ToBf16Bits(v))
}
func (b *Builder) StoreBool(v bool) int { return b.StoreU8(uint8(boolInt(v))) }

// StoreBytes stores raw bytes in forward order.
func (b *Builder) StoreBytes(bs []byte) int {
	p := b.wpos(len(bs))
	copy(b.buf[p:], bs)
	return b.cursor
}

func (b *Builder) storeZeros(n int) {
	if n <= 0 {
		return
	}
	p := b.wpos(n)
	clear(b.buf[p : p+n])
}

// StoreLEB stores an unsigned LEB128 varint (low 7 bits first; 0 → one 0x00).
func (b *Builder) StoreLEB(v uint64) int {
	// Almost every LEB a packed encode writes is a field tag, an element count or a
	// block size, so one and two byte values dominate. Writing those directly skips
	// LebLength's bits.Len64 + divide, the subslice, and PutUvarint's loop — StoreLEB
	// profiled as 39% of the Go serializer before this (spec/32 §1.49).
	switch {
	case v < 0x80:
		b.ensure(1)
		b.cursor++
		b.buf[len(b.buf)-b.cursor] = byte(v)
	case v < 0x4000:
		b.ensure(2)
		b.cursor += 2
		p := len(b.buf) - b.cursor
		b.buf[p] = byte(v) | 0x80
		b.buf[p+1] = byte(v >> 7)
	default:
		n := LebLength(v)
		p := b.wpos(n)
		binary.PutUvarint(b.buf[p:p+n], v)
	}
	return b.cursor
}

// StoreV62 stores a fixed-width pointer value<<2 | widthCode, width by magnitude.
func (b *Builder) StoreV62(v uint64, minCode int) int {
	switch {
	case v < 1<<6 && minCode == 0:
		return b.StoreU8(uint8(v << 2))
	case v < 1<<14 && minCode <= 1:
		return b.StoreU16(uint16(v<<2 | uint64(max(1, minCode))))
	case v < 1<<30 && minCode <= 2:
		return b.StoreU32(uint32(v<<2 | uint64(max(2, minCode))))
	case v < 1<<62:
		return b.StoreU64(v<<2 | uint64(max(3, minCode)))
	}
	panic("dagr: cannot store value as V62: " + strconv.FormatUint(v, 10))
}

// StoreForwardPointer stores V62(cursor - offset) to a previously stored offset.
func (b *Builder) StoreForwardPointer(offset int) int {
	return b.StoreV62(uint64(b.cursor-offset), 0)
}

// StoreBidirectionalPointer stores a signed pointer to a node: resolved →
// V62(zigzag(cursor - off)); pending (a cycle back-edge) → a fixed-width placeholder
// (width code from ReserveFieldPointerSize) patched by FinishStoring.
func (b *Builder) StoreBidirectionalPointer(ref NodeStoreRef) int {
	if !ref.Pending {
		return b.StoreV62(ToZigZag(int64(b.cursor-ref.Off)), 0)
	}
	base := b.cursor
	es := b.ReserveFieldPointerSize
	b.storeZeros(es)
	b.addLateBinding(ref.Key, lateBind{cursorAt: b.cursor, base: base, arrayEnd: -1, es: es})
	return b.cursor
}

func (b *Builder) addLateBinding(k NodeKey, lb lateBind) {
	b.lateBindings[k] = append(b.lateBindings[k], lb)
}

// BeginStoring registers a node as in-progress. It returns (ref, true) when the node is
// already stored (cache hit) or is an in-flight ancestor (pending = a cycle), else
// (zero, false) to proceed storing fresh. Mirrors Rust DagrBuilder::begin_storing.
func (b *Builder) BeginStoring(k NodeKey) (NodeStoreRef, bool) {
	if off, ok := b.StructLookup[k]; ok {
		return NodeStoreRef{Off: off}, true
	}
	if b.inProgress[k] {
		return NodeStoreRef{Pending: true, Key: k}, true
	}
	b.inProgress[k] = true
	return NodeStoreRef{}, false
}

// FinishStoring patches every placeholder recorded against the node, then caches its
// offset. Bidir placeholders get a V62 of the reserved width; node-ref array slots get
// a raw fixed-width two's-complement distance.
func (b *Builder) FinishStoring(k NodeKey, offset int) {
	delete(b.inProgress, k)
	if binds, ok := b.lateBindings[k]; ok {
		for _, bd := range binds {
			pos := len(b.buf) - bd.cursorAt
			var x uint64
			if bd.arrayEnd >= 0 {
				x = uint64(int64(bd.arrayEnd-offset+1)) & (1<<(bd.es*8) - 1)
			} else {
				x = ToZigZag(int64(bd.base-offset))<<2 | uint64(bits.Len(uint(bd.es))-1)
			}
			for i := 0; i < bd.es; i++ {
				b.buf[pos+i] = byte(x)
				x >>= 8
			}
		}
		delete(b.lateBindings, k)
	}
	b.StructLookup[k] = offset
}

// StoreVTable stores a regular node's vtable. entries are field value offsets in
// forward index order (-1 = absent). Returns the node offset (the vtable-pointer LEB).
// Dedups identical entry vectors.
func (b *Builder) StoreVTable(entries []int) int {
	norm := make([]int, len(entries))
	is16 := false
	var key strings.Builder
	for i, off := range entries {
		if off >= 0 {
			norm[i] = b.cursor - off + 1
		}
		if norm[i] > 0xffff {
			panic("dagr: vtable entry overflow: field slot " + strconv.Itoa(norm[i]) +
				" bytes before the node header exceeds the UInt16 wire limit (65535)")
		}
		if norm[i] > 0xff {
			is16 = true
		}
	}
	if is16 {
		key.WriteString("w:")
	}
	for i, n := range norm {
		if i > 0 {
			key.WriteByte(',')
		}
		key.WriteString(strconv.Itoa(n))
	}
	ks := key.String()
	if hit, ok := b.vtLookup[ks]; ok {
		return b.StoreLEB(uint64(b.cursor-hit) << 1)
	}
	var result int
	if is16 {
		cnt := uint64(len(entries))<<1 | 1
		sz := uint64(LebLength(cnt) + len(entries)*2)
		result = b.StoreLEB(toNegativZigZag(sz))
		for i := len(norm) - 1; i >= 0; i-- {
			b.StoreU16(uint16(norm[i]))
		}
		b.vtLookup[ks] = b.StoreLEB(cnt)
	} else {
		cnt := uint64(len(entries)) << 1
		var sz uint64
		if cnt != 0 {
			sz = uint64(LebLength(cnt) + len(entries))
		}
		result = b.StoreLEB(toNegativZigZag(sz))
		for i := len(norm) - 1; i >= 0; i-- {
			b.StoreU8(uint8(norm[i]))
		}
		b.vtLookup[ks] = b.StoreLEB(cnt)
	}
	return result
}

// StoreUtf8 stores `[LEB byteCount][utf8 bytes]`; dedup mirrors the reference
// stringLookup (regular/frozen out-of-line; packed inline stores with dedup=false).
// Take / Put hand the write position to a caller that wants to run a hot subtree with
// the buffer and cursor as LOCALS, the way a hand-written marshaller keeps them in
// registers, and hand it back. `i` is the index the next byte is written BELOW, so it
// counts down from len(buf) while the builder's cursor counts up (spec/32 §1.53).
func (b *Builder) Take() ([]byte, int) { return b.buf, len(b.buf) - b.cursor }

func (b *Builder) Put(buf []byte, i int) {
	b.buf = buf
	b.cursor = len(buf) - i
}

// GrowBack is the growth step for a local-cursor writer: it doubles until `need` bytes
// fit below `i`, moving the already-written tail to the end of the new buffer.
func GrowBack(buf []byte, i, need int) ([]byte, int) {
	written := len(buf) - i
	c := len(buf) * 2
	if c == 0 {
		c = 64
	}
	for c-written < need {
		c *= 2
	}
	nb := make([]byte, c)
	copy(nb[c-written:], buf[i:])
	return nb, c - written
}

// PutLEBAt is the local-cursor LEB store: writes v below i and returns the new buffer
// (it may have grown) and cursor.
func PutLEBAt(buf []byte, i int, v uint64) ([]byte, int) {
	if i >= 1 && v < 0x80 {
		i--
		buf[i] = byte(v)
		return buf, i
	}
	return putLEBAtSlow(buf, i, v)
}

func putLEBAtSlow(buf []byte, i int, v uint64) ([]byte, int) {
	n := LebLength(v)
	if i < n {
		buf, i = GrowBack(buf, i, n)
	}
	i -= n
	putLEB(buf[i:], v)
	return buf, i
}

// PutPackedNodeArrayPlainAt is the local-cursor twin of StorePackedNodeArrayPlain: the
// cursor threads through the child stores instead of each one re-acquiring it from the
// builder, which is the whole point of the local-cursor path (spec/32 §1.53).
func PutPackedNodeArrayPlainAt[T any](buf []byte, i int, elems []T,
	put func([]byte, int, T) ([]byte, int)) ([]byte, int) {
	before := len(buf) - i
	for k := len(elems) - 1; k >= 0; k-- {
		buf, i = put(buf, i, elems[k])
	}
	buf, i = PutLEBAt(buf, i, uint64(len(elems)))
	return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
}

// PutPackedUnionArrayAt mirrors StorePackedUnionArray for a plain (non-optional) array:
// each element's payload (reversed), then the headers, the count and the block size.
func PutPackedUnionArrayAt[T any](buf []byte, i int, elems []Opt[T],
	apply func([]byte, int, T) ([]byte, int, PackedUnionHdr)) ([]byte, int) {
	before := len(buf) - i
	hdrs := make([]PackedUnionHdr, len(elems))
	for k := len(elems) - 1; k >= 0; k-- {
		buf, i, hdrs[k] = apply(buf, i, elems[k].V)
	}
	for k := len(elems) - 1; k >= 0; k-- {
		buf, i = PutLEBAt(buf, i, uint64(hdrs[k].ID<<3|hdrs[k].Code))
	}
	buf, i = PutLEBAt(buf, i, uint64(len(elems)))
	return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
}

// PutFixedAt writes a fixed-width little-endian value of w bytes (1, 2, 4 or 8) below i.
// It is the local-cursor twin of StoreU8 / StoreU16 / StoreU32 / StoreU64 and their
// signed and float counterparts, which all funnel into the same little-endian store.
func PutFixedAt(buf []byte, i int, v uint64, w int) ([]byte, int) {
	if i < w {
		buf, i = GrowBack(buf, i, w)
	}
	i -= w
	switch w {
	case 1:
		buf[i] = byte(v)
	case 2:
		binary.LittleEndian.PutUint16(buf[i:], uint16(v))
	case 4:
		binary.LittleEndian.PutUint32(buf[i:], uint32(v))
	default:
		binary.LittleEndian.PutUint64(buf[i:], v)
	}
	return buf, i
}

// Checked local-cursor twins of the tagged / fixed-width stores.
func PutBytesTaggedAt(buf []byte, i int, d []byte, tag uint64) ([]byte, int) {
	n := len(d)
	ln := LebLength(uint64(n))
	tl := LebLength(tag)
	need := tl + ln + n
	if i < need {
		buf, i = GrowBack(buf, i, need)
	}
	i -= need
	putLEB(buf[i:], tag)
	putLEB(buf[i+tl:], uint64(n))
	copy(buf[i+tl+ln:], d)
	return buf, i
}

func PutLEBTaggedAt(buf []byte, i int, v, tag uint64) ([]byte, int) {
	vl := LebLength(v)
	tl := LebLength(tag)
	if i < tl+vl {
		buf, i = GrowBack(buf, i, tl+vl)
	}
	i -= tl + vl
	putLEB(buf[i:], tag)
	putLEB(buf[i+tl:], v)
	return buf, i
}

func PutU64At(buf []byte, i int, v uint64) ([]byte, int) {
	if i < 8 {
		buf, i = GrowBack(buf, i, 8)
	}
	i -= 8
	binary.LittleEndian.PutUint64(buf[i:], v)
	return buf, i
}

// PutUtf8At / PutBytesAt / PutU8At are the remaining local-cursor primitives: a
// length-prefixed string or blob, and a single byte.
func PutUtf8At(buf []byte, i int, s string) ([]byte, int) {
	n := len(s)
	ln := LebLength(uint64(n))
	if i < n+ln {
		buf, i = GrowBack(buf, i, n+ln)
	}
	i -= n + ln
	putLEB(buf[i:], uint64(n))
	copy(buf[i+ln:], s)
	return buf, i
}

func PutBytesAt(buf []byte, i int, d []byte) ([]byte, int) {
	n := len(d)
	ln := LebLength(uint64(n))
	if i < n+ln {
		buf, i = GrowBack(buf, i, n+ln)
	}
	i -= n + ln
	putLEB(buf[i:], uint64(n))
	copy(buf[i+ln:], d)
	return buf, i
}

func PutU8At(buf []byte, i int, v uint8) ([]byte, int) {
	if i < 1 {
		buf, i = GrowBack(buf, i, 1)
	}
	i--
	buf[i] = v
	return buf, i
}

// PutUtf8TaggedAt is the local-cursor form of StoreUtf8Tagged.
func PutUtf8TaggedAt(buf []byte, i int, s string, tag uint64) ([]byte, int) {
	n := len(s)
	ln := LebLength(uint64(n))
	tl := LebLength(tag)
	need := tl + ln + n
	if i < need {
		buf, i = GrowBack(buf, i, need)
	}
	i -= need
	putLEB(buf[i:], tag)
	putLEB(buf[i+tl:], uint64(n))
	copy(buf[i+tl+ln:], s)
	return buf, i
}

// putLEB writes v at dst[0:] and returns its byte length. It exists so several values
// can share ONE reservation — see StoreUtf8 and the *Tagged stores below.
func putLEB(dst []byte, v uint64) int {
	if v < 0x80 {
		dst[0] = byte(v)
		return 1
	}
	return binary.PutUvarint(dst, v)
}

// StoreUtf8Tagged writes `[LEB tag][LEB len][bytes]` in a single reservation.
//
// A packed field used to take two or three separate stores — the payload, its length,
// then the field tag — and every one of them reloaded the builder's slice header and
// cursor through a pointer and re-checked capacity. That state round-trip, not the
// encoding, is what separated this serializer from a hand-written one: 47,170 stores per
// OTLP batch at ~0.9ns of overhead each (spec/32 §1.52).
func (b *Builder) StoreUtf8Tagged(s string, tag uint64) int {
	n := len(s)
	ln := LebLength(uint64(n))
	tl := LebLength(tag)
	p := b.wpos(tl + ln + n)
	putLEB(b.buf[p:], tag)
	putLEB(b.buf[p+tl:], uint64(n))
	copy(b.buf[p+tl+ln:], s)
	return b.cursor
}

// StoreDataTagged is StoreUtf8Tagged for a byte slice.
func (b *Builder) StoreDataTagged(d []byte, tag uint64) int {
	n := len(d)
	ln := LebLength(uint64(n))
	tl := LebLength(tag)
	p := b.wpos(tl + ln + n)
	putLEB(b.buf[p:], tag)
	putLEB(b.buf[p+tl:], uint64(n))
	copy(b.buf[p+tl+ln:], d)
	return b.cursor
}

// StoreLEBTagged writes `[LEB tag][LEB v]` in a single reservation.
func (b *Builder) StoreLEBTagged(v, tag uint64) int {
	vl := LebLength(v)
	tl := LebLength(tag)
	p := b.wpos(tl + vl)
	putLEB(b.buf[p:], tag)
	putLEB(b.buf[p+tl:], v)
	return b.cursor
}

func (b *Builder) StoreUtf8(s string, dedup bool) int {
	if dedup {
		if hit, ok := b.stringLookup[s]; ok {
			return hit
		}
	}
	n := len(s) // one reservation for [LEB len][bytes], not two
	ln := LebLength(uint64(n))
	p := b.wpos(n + ln)
	putLEB(b.buf[p:], uint64(n))
	copy(b.buf[p+ln:], s)
	off := b.cursor
	if dedup {
		b.stringLookup[s] = off
	}
	return off
}

// StoreData stores `[LEB count][bytes]` (no dedup).
func (b *Builder) StoreData(bs []byte) int {
	n := len(bs)
	ln := LebLength(uint64(n))
	p := b.wpos(n + ln)
	putLEB(b.buf[p:], uint64(n))
	copy(b.buf[p+ln:], bs)
	return b.cursor
}

// StoreUnionSlot stores a regular/frozen union field slot: the payload via Emit, then
// the tag LEB (typeId<<2)|widthCode (1→0, 2→1, 4→2, else 3). Returns the slot offset.
func (b *Builder) StoreUnionSlot(a UnionApplied) int {
	before := b.cursor
	a.Emit(b)
	n := b.cursor - before
	wc := 3
	switch n {
	case 1:
		wc = 0
	case 2:
		wc = 1
	case 4:
		wc = 2
	}
	return b.StoreLEB(uint64(a.ID<<2 | wc))
}

// StoreNestedUnionSlot is StoreUnionSlot with the width code fixed at 0 (a union that
// is itself another union's variant, or a union-array element).
func (b *Builder) StoreNestedUnionSlot(a UnionApplied) int {
	a.Emit(b)
	return b.StoreLEB(uint64(a.ID << 2))
}

func (b *Builder) storeUintWc(v uint64, wc int) {
	switch wc {
	case 0:
		b.StoreU8(uint8(v))
	case 1:
		b.StoreU16(uint16(v))
	case 2:
		b.StoreU32(uint32(v))
	default:
		b.StoreU64(v)
	}
}

func (b *Builder) storeIntWc(v int64, wc int) {
	switch wc {
	case 0:
		b.StoreI8(int8(v))
	case 1:
		b.StoreI16(int16(v))
	case 2:
		b.StoreI32(int32(v))
	default:
		b.StoreI64(v)
	}
}

// StoreUnionArray stores a regular/frozen union array (§4.9): content already stored;
// applied is in REVERSED element order with Ok=false for a nil element. Writes
// [slot table][nil bitset (opt)][typeId section][header (count<<2)|es].
func (b *Builder) StoreUnionArray(count int, applied []Opt[UnionArrElem], bp int, opt bool) int {
	contentEnd := b.cursor
	wc := 0
	slots := make([]uint64, len(applied))
	for i, a := range applied {
		if !a.Ok {
			continue
		}
		var v uint64
		switch a.V.Kind {
		case 'v':
			v = a.V.Val
		case 'p':
			v = uint64(contentEnd - int(a.V.Val))
		default:
			v = uint64(contentEnd-int(a.V.Val)) << 1
		}
		wc = max(wc, offsetWidthCode(v))
		slots[i] = v
	}
	for _, v := range slots {
		b.storeUintWc(v, wc)
	}
	if opt {
		nb := make([]byte, (count+7)>>3)
		for j := 0; j < count; j++ {
			idx := count - 1 - j
			if !applied[j].Ok {
				nb[idx>>3] |= 1 << (idx & 7)
			}
		}
		b.StoreBytes(nb)
	}
	if bp < 8 {
		perByte, mask := 8/bp, (1<<bp)-1
		bs := make([]byte, (count*bp+7)/8)
		for j := 0; j < count; j++ {
			idx := count - 1 - j
			tid := 0
			if applied[j].Ok {
				tid = applied[j].V.Tid
			}
			bs[idx/perByte] |= byte((tid & mask) << ((idx % perByte) * bp))
		}
		b.StoreBytes(bs)
	} else {
		for _, a := range applied {
			tid := 0
			if a.Ok {
				tid = a.V.Tid
			}
			b.StoreU8(uint8(tid))
		}
	}
	return b.StoreLEB(uint64(count)<<2 | uint64(wc))
}

// StorePtrTableArray stores a pointer-table array of utf8/data elements: content
// (reversed) via storeElem, a [count×es] slot table (slot = cur-off+1, 0 = nil), then
// the header (count<<2)|widthCode. Returns the header offset.
func StorePtrTableArray[T any](b *Builder, elems []Opt[T], storeElem func(*Builder, T) int) int {
	offs := make([]int, 0, len(elems))
	for i := len(elems) - 1; i >= 0; i-- {
		if elems[i].Ok {
			offs = append(offs, storeElem(b, elems[i].V))
		} else {
			offs = append(offs, -1)
		}
	}
	cur := b.cursor
	wc := 0
	for _, off := range offs {
		if off >= 0 {
			wc = max(wc, offsetWidthCode(uint64(cur-off+1)))
		}
	}
	for _, off := range offs {
		d := 0
		if off >= 0 {
			d = cur - off + 1
		}
		b.storeUintWc(uint64(d), wc)
	}
	return b.StoreLEB(uint64(len(elems))<<2 | uint64(wc))
}

// StoreNodeRefArray stores a regular/frozen node-ref array (signed two's-complement
// slots): each element's node (reversed), then the slot table; a pending (cyclic)
// element gets a zero placeholder patched by FinishStoring.
func StoreNodeRefArray[T any](b *Builder, elems []Opt[T], storeRef func(*Builder, T) NodeStoreRef) int {
	refs := make([]Opt[NodeStoreRef], 0, len(elems))
	for i := len(elems) - 1; i >= 0; i-- {
		if elems[i].Ok {
			refs = append(refs, Some(storeRef(b, elems[i].V)))
		} else {
			refs = append(refs, None[NodeStoreRef]())
		}
	}
	cur := b.cursor
	wc, hasPending := 0, false
	for _, r := range refs {
		if !r.Ok {
			continue
		}
		if r.V.Pending {
			hasPending = true
		} else {
			wc = max(wc, signedWidthCode(int64(cur-r.V.Off+1)))
		}
	}
	reserveWc := bits.Len(uint(b.ReserveFieldPointerSize)) - 1
	if hasPending && wc < reserveWc {
		wc = reserveWc
	}
	es := 1 << wc
	for _, r := range refs {
		switch {
		case !r.Ok:
			b.storeIntWc(0, wc)
		case !r.V.Pending:
			b.storeIntWc(int64(cur-r.V.Off+1), wc)
		default:
			b.storeZeros(es)
			b.addLateBinding(r.V.Key, lateBind{cursorAt: b.cursor, base: 0, arrayEnd: cur, es: es})
		}
	}
	return b.StoreLEB(uint64(len(elems))<<2 | uint64(wc))
}

// StoreFixedArray stores `[LEB count][elems]` with each element via `each` (reversed).
func StoreFixedArray[T any](b *Builder, elems []T, each func(*Builder, T)) int {
	for i := len(elems) - 1; i >= 0; i-- {
		each(b, elems[i])
	}
	return b.StoreLEB(uint64(len(elems)))
}

// StoreOptFixedArray stores an uncompacted numeric arrayWithOptionals:
// `[LEB count][nil bitset][N fixed slots]` (zero bytes for a nil element).
func StoreOptFixedArray[T any](b *Builder, elems []Opt[T], width int, each func(*Builder, T)) int {
	for i := len(elems) - 1; i >= 0; i-- {
		if elems[i].Ok {
			each(b, elems[i].V)
		} else {
			b.storeZeros(width)
		}
	}
	b.StoreBytes(nilBits(elems))
	return b.StoreLEB(uint64(len(elems)))
}

func nilBits[T any](elems []Opt[T]) []byte {
	nb := make([]byte, (len(elems)+7)>>3)
	for i, e := range elems {
		if !e.Ok {
			nb[i>>3] |= 1 << (i & 7)
		}
	}
	return nb
}

func boolBits(elems []bool) []byte {
	bs := make([]byte, (len(elems)+7)>>3)
	for i, e := range elems {
		if e {
			bs[i>>3] |= 1 << (i & 7)
		}
	}
	return bs
}

// StoreBoolArray stores `[LEB count][bitset]`.
func (b *Builder) StoreBoolArray(elems []bool) int {
	b.StoreBytes(boolBits(elems))
	return b.StoreLEB(uint64(len(elems)))
}

// StoreOptBoolArray stores `[LEB count][nil bitset][value bitset]` (uncompacted).
func (b *Builder) StoreOptBoolArray(elems []Opt[bool]) int {
	nb := len(elems)
	val := make([]byte, (nb+7)>>3)
	for i, e := range elems {
		if e.Ok && e.V {
			val[i>>3] |= 1 << (i & 7)
		}
	}
	b.StoreBytes(val)
	b.StoreBytes(nilBits(elems))
	return b.StoreLEB(uint64(nb))
}

func enumBits(vals []uint64, bits int) []byte {
	perByte, mask := 8/bits, uint64(1<<bits-1)
	bs := make([]byte, (len(vals)*bits+7)/8)
	for i, v := range vals {
		bs[i/perByte] |= byte((v & mask) << ((i % perByte) * bits))
	}
	return bs
}

// StoreEnumBitArray stores a sub-byte enum array `[LEB count][packed bits]`.
func (b *Builder) StoreEnumBitArray(vals []uint64, bits int) int {
	b.StoreBytes(enumBits(vals, bits))
	return b.StoreLEB(uint64(len(vals)))
}

// StoreOptEnumBitArray stores `[LEB count][nil bitset][value bits]` (uncompacted).
func (b *Builder) StoreOptEnumBitArray(elems []Opt[uint64], bits int) int {
	vals := make([]uint64, len(elems))
	for i, e := range elems {
		if e.Ok {
			vals[i] = e.V
		}
	}
	b.StoreBytes(enumBits(vals, bits))
	b.StoreBytes(nilBits(elems))
	return b.StoreLEB(uint64(len(elems)))
}

// ── Aligned fields (spec 12) ───────────────────────────────────────────────────

// StoreAlignedArray stores a fixed-width array whose element base is N-aligned:
// pre-element pad, reversed elements, LEB count.
func StoreAlignedArray[T any](b *Builder, elems []T, width, n int, each func(*Builder, T)) int {
	pad := (-(b.cursor + len(elems)*width)) & (n - 1)
	b.storeZeros(pad)
	for i := len(elems) - 1; i >= 0; i-- {
		each(b, elems[i])
	}
	return b.StoreLEB(uint64(len(elems)))
}

// StoreAlignedBytes stores an N-aligned byte blob (utf8/data, no dedup).
func (b *Builder) StoreAlignedBytes(bs []byte, n int) int {
	pad := (-(b.cursor + len(bs))) & (n - 1)
	b.storeZeros(pad)
	b.StoreBytes(bs)
	return b.StoreLEB(uint64(len(bs)))
}

// StoreFinishAlignmentPadding inserts zero bytes before the framing LEB so the total
// length is ≡ 0 mod maxN. Call after the root is stored, before the framing word.
func (b *Builder) StoreFinishAlignmentPadding(rootOffset, maxN int) {
	if maxN <= 1 {
		return
	}
	for p := 0; p < maxN; p++ {
		afterPad := b.cursor + p
		framingLen := LebLength(uint64(afterPad-rootOffset) << 2)
		if (afterPad+framingLen)%maxN == 0 {
			b.storeZeros(p)
			return
		}
	}
}

// ── Packed self-describing floats (spec 07 §12) ────────────────────────────────

// StorePackedFloat32 stores a packed f32; returns true when the RAW fallback was used
// (the packed-scalar field / enc bit). elem=true tags the raw fallback (array elements
// are always self-describing).
func (b *Builder) StorePackedFloat32(v float32, elem bool) bool {
	bitsv := math.Float32bits(v)
	switch {
	case bitsv == 0:
		b.StoreU8(0x00)
		return false
	case bitsv == 0x80000000:
		b.StoreU8(0x01)
		return false
	case v != v:
		b.StoreU8(0x04)
		return false
	case math.IsInf(float64(v), 1):
		b.StoreU8(0x02)
		return false
	case math.IsInf(float64(v), -1):
		b.StoreU8(0x03)
		return false
	}
	if v == float32(math.Trunc(float64(v))) && math.Abs(float64(v)) < 1<<21 {
		zz := ToZigZag(int64(v))
		if LebLength(zz) <= 3 {
			b.StoreLEB(zz)
			b.StoreU8(0x05)
			return false
		}
	}
	if h, ok := F32ToF16BitsExact(v); ok {
		b.StoreU16(h)
		b.StoreU8(0x06)
		return false
	}
	b.StoreF32(v)
	if elem {
		b.StoreU8(0x07)
	}
	return true
}

// StorePackedFloat64 is the f64 form of StorePackedFloat32.
func (b *Builder) StorePackedFloat64(v float64, elem bool) bool {
	bitsv := math.Float64bits(v)
	switch {
	case bitsv == 0:
		b.StoreU8(0x00)
		return false
	case bitsv == 0x8000000000000000:
		b.StoreU8(0x01)
		return false
	case v != v:
		b.StoreU8(0x04)
		return false
	case math.IsInf(v, 1):
		b.StoreU8(0x02)
		return false
	case math.IsInf(v, -1):
		b.StoreU8(0x03)
		return false
	}
	if v == math.Trunc(v) && math.Abs(v) < 1<<48 {
		zz := ToZigZag(int64(v))
		if LebLength(zz) <= 7 {
			b.StoreLEB(zz)
			b.StoreU8(0x05)
			return false
		}
	}
	if f32 := float32(v); float64(f32) == v {
		if h, ok := F32ToF16BitsExact(f32); ok {
			b.StoreU16(h)
			b.StoreU8(0x06)
			return false
		}
		b.StoreF32(f32)
		b.StoreU8(0x07)
		return false
	}
	b.StoreF64(v)
	if elem {
		b.StoreU8(0x08)
	}
	return true
}

// StorePackedF16Scalar stores a packed f16/bf16: a special value as a 1-byte tag
// (returns false), else raw 2-byte bits (returns true = raw).
func (b *Builder) StorePackedF16Scalar(v float32, isBf16 bool) bool {
	bitsv := math.Float32bits(v)
	switch {
	case bitsv == 0:
		b.StoreU8(0x00)
		return false
	case bitsv == 0x80000000:
		b.StoreU8(0x01)
		return false
	case v != v:
		b.StoreU8(0x04)
		return false
	case math.IsInf(float64(v), 1):
		b.StoreU8(0x02)
		return false
	case math.IsInf(float64(v), -1):
		b.StoreU8(0x03)
		return false
	}
	if isBf16 {
		b.StoreU16(F32ToBf16Bits(v))
	} else {
		b.StoreU16(F32ToF16Bits(v))
	}
	return true
}

// ── Packed array bodies `[blockLen][count-tag][elems]` (each returns the blockLen offset) ──

// StorePackedIntArray stores a packed int array (width ≥ 2): (count<<2)|tag, tag 0
// all-LEB / 1 all-raw / 2 mixed (enc bitset); per element LEB when strictly smaller
// than the raw width. raw (a `>> raw` field, spec/39) skips the probe: every element
// is width bytes, tag 1, no enc bitset — the same bytes a data-dependent all-raw
// array produces, so readers are unaffected.
// PackedInt is every element type a packed integer array stores through its width probe
// (u8/i8 arrays are plain bytes: StorePackedByteArray).
type PackedInt interface {
	~uint16 | ~uint32 | ~uint64 | ~int16 | ~int32 | ~int64
}

// PutPackedIntArrayAt is StorePackedIntArray on a local cursor — the same bytes, block
// size included. It is generic over the element TYPE rather than taking toLEB / storeRaw
// function values, so each element type gets its own compiled loop with the LEB-or-fixed
// decision inline: no indirect call per element, and room for the whole array is reserved
// once (an element is never wider than its fixed width) instead of checked per byte. The
// encoding bitset is only needed when LEB and fixed elements mix, which is rare, so it is
// filled by a second pass over the elements rather than tracked in the first.
func PutPackedIntArrayAt[T PackedInt](buf []byte, i int, elems []T, raw bool) ([]byte, int) {
	var zero T
	w := int(unsafe.Sizeof(zero))
	signed := ^zero < 0
	before := len(buf) - i
	n := len(elems)
	if need := n*w + (n+7)>>3; i < need {
		buf, i = GrowBack(buf, i, need)
	}
	if raw {
		for k := n - 1; k >= 0; k-- {
			i -= w
			putFixedLE(buf[i:], uint64(elems[k]), w)
		}
		buf, i = PutLEBAt(buf, i, uint64(n)<<2|1)
		return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
	}
	rawCount := 0
	for k := n - 1; k >= 0; k-- {
		v := elems[k]
		lv := uint64(v)
		if signed {
			lv = ToZigZag(int64(v))
		}
		if lv < 0x80 {
			i--
			buf[i] = byte(lv)
			continue
		}
		if l := LebLength(lv); l < w {
			i -= l
			binary.PutUvarint(buf[i:], lv)
		} else {
			i -= w
			putFixedLE(buf[i:], uint64(v), w)
			rawCount++
		}
	}
	tag := uint64(0)
	if rawCount == n && n > 0 {
		tag = 1
	} else if rawCount > 0 {
		tag = 2
		nb := (n + 7) >> 3
		i -= nb
		enc := buf[i : i+nb]
		clear(enc)
		for k, v := range elems {
			lv := uint64(v)
			if signed {
				lv = ToZigZag(int64(v))
			}
			if LebLength(lv) >= w {
				enc[k>>3] |= 1 << (k & 7)
			}
		}
	}
	buf, i = PutLEBAt(buf, i, uint64(n)<<2|tag)
	return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
}

// StorePackedIntArrayOf is PutPackedIntArrayAt for a caller holding the Builder (the arena
// serializer): the same bytes as StorePackedIntArray, without its per-element calls.
func StorePackedIntArrayOf[T PackedInt](b *Builder, elems []T, raw bool) int {
	buf, i := b.Take()
	buf, i = PutPackedIntArrayAt(buf, i, elems, raw)
	b.Put(buf, i)
	return b.cursor
}

func putFixedLE(dst []byte, v uint64, w int) {
	switch w {
	case 2:
		binary.LittleEndian.PutUint16(dst, uint16(v))
	case 4:
		binary.LittleEndian.PutUint32(dst, uint32(v))
	default:
		binary.LittleEndian.PutUint64(dst, v)
	}
}

// putPackedFloat64At writes one packed f64 — StorePackedFloat64's bytes — below i, which
// must have 9 bytes of room, and reports whether it went raw.
func putPackedFloat64At(buf []byte, i int, v float64, elem bool) (int, bool) {
	bitsv := math.Float64bits(v)
	var special byte = 0xff
	switch {
	case bitsv == 0:
		special = 0x00
	case bitsv == 0x8000000000000000:
		special = 0x01
	case v != v:
		special = 0x04
	case math.IsInf(v, 1):
		special = 0x02
	case math.IsInf(v, -1):
		special = 0x03
	}
	if special != 0xff {
		i--
		buf[i] = special
		return i, false
	}
	if v == math.Trunc(v) && math.Abs(v) < 1<<48 {
		if zz := ToZigZag(int64(v)); LebLength(zz) <= 7 {
			i -= LebLength(zz)
			binary.PutUvarint(buf[i:], zz)
			i--
			buf[i] = 0x05
			return i, false
		}
	}
	if f32 := float32(v); float64(f32) == v {
		if h, ok := F32ToF16BitsExact(f32); ok {
			i -= 2
			binary.LittleEndian.PutUint16(buf[i:], h)
			i--
			buf[i] = 0x06
			return i, false
		}
		i -= 4
		binary.LittleEndian.PutUint32(buf[i:], math.Float32bits(f32))
		i--
		buf[i] = 0x07
		return i, false
	}
	i -= 8
	binary.LittleEndian.PutUint64(buf[i:], bitsv)
	if elem {
		i--
		buf[i] = 0x08
	}
	return i, true
}

// putPackedFloat32At is putPackedFloat64At for f32 (StorePackedFloat32's bytes; 5 bytes of room).
func putPackedFloat32At(buf []byte, i int, v float32, elem bool) (int, bool) {
	bitsv := math.Float32bits(v)
	var special byte = 0xff
	switch {
	case bitsv == 0:
		special = 0x00
	case bitsv == 0x80000000:
		special = 0x01
	case v != v:
		special = 0x04
	case math.IsInf(float64(v), 1):
		special = 0x02
	case math.IsInf(float64(v), -1):
		special = 0x03
	}
	if special != 0xff {
		i--
		buf[i] = special
		return i, false
	}
	if v == float32(math.Trunc(float64(v))) && math.Abs(float64(v)) < 1<<21 {
		if zz := ToZigZag(int64(v)); LebLength(zz) <= 3 {
			i -= LebLength(zz)
			binary.PutUvarint(buf[i:], zz)
			i--
			buf[i] = 0x05
			return i, false
		}
	}
	if h, ok := F32ToF16BitsExact(v); ok {
		i -= 2
		binary.LittleEndian.PutUint16(buf[i:], h)
		i--
		buf[i] = 0x06
		return i, false
	}
	i -= 4
	binary.LittleEndian.PutUint32(buf[i:], bitsv)
	if elem {
		i--
		buf[i] = 0x07
	}
	return i, true
}

// PutPackedFloat64At / PutPackedFloat32At are the local-cursor forms of the packed float
// scalar stores: the same bytes, and the same "went raw" result that picks the field tag.
func PutPackedFloat64At(buf []byte, i int, v float64) ([]byte, int, bool) {
	if i < 9 {
		buf, i = GrowBack(buf, i, 9)
	}
	i, raw := putPackedFloat64At(buf, i, v, false)
	return buf, i, raw
}

func PutPackedFloat32At(buf []byte, i int, v float32) ([]byte, int, bool) {
	if i < 5 {
		buf, i = GrowBack(buf, i, 5)
	}
	i, raw := putPackedFloat32At(buf, i, v, false)
	return buf, i, raw
}

// PutPackedF64ArrayAt / PutPackedF32ArrayAt are StorePackedFloatArray on a local cursor —
// the same bytes — with room for the whole array reserved once.
func PutPackedF64ArrayAt(buf []byte, i int, elems []float64, raw bool) ([]byte, int) {
	before := len(buf) - i
	n := len(elems)
	if i < n*9 {
		buf, i = GrowBack(buf, i, n*9)
	}
	for k := n - 1; k >= 0; k-- {
		if raw {
			i -= 8
			binary.LittleEndian.PutUint64(buf[i:], math.Float64bits(elems[k]))
		} else {
			i, _ = putPackedFloat64At(buf, i, elems[k], true)
		}
	}
	buf, i = PutLEBAt(buf, i, uint64(n)<<2|uint64(boolInt(raw)))
	return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
}

func PutPackedF32ArrayAt(buf []byte, i int, elems []float32, raw bool) ([]byte, int) {
	before := len(buf) - i
	n := len(elems)
	if i < n*5 {
		buf, i = GrowBack(buf, i, n*5)
	}
	for k := n - 1; k >= 0; k-- {
		if raw {
			i -= 4
			binary.LittleEndian.PutUint32(buf[i:], math.Float32bits(elems[k]))
		} else {
			i, _ = putPackedFloat32At(buf, i, elems[k], true)
		}
	}
	buf, i = PutLEBAt(buf, i, uint64(n)<<2|uint64(boolInt(raw)))
	return PutLEBAt(buf, i, uint64((len(buf)-i)-before))
}

func StorePackedIntArray[T any](b *Builder, elems []T, width int, toLEB func(T) uint64, storeRaw func(*Builder, T), raw bool) int {
	before := b.cursor
	if raw {
		for i := len(elems) - 1; i >= 0; i-- {
			storeRaw(b, elems[i])
		}
		b.StoreLEB(uint64(len(elems))<<2 | 1)
		return b.StoreLEB(uint64(b.cursor - before))
	}
	enc := make([]byte, (len(elems)+7)>>3)
	rawCount := 0
	for i := len(elems) - 1; i >= 0; i-- {
		lv := toLEB(elems[i])
		if LebLength(lv) < width {
			b.StoreLEB(lv)
		} else {
			storeRaw(b, elems[i])
			enc[i>>3] |= 1 << (i & 7)
			rawCount++
		}
	}
	tag := 0
	if rawCount == len(elems) && len(elems) > 0 {
		tag = 1
	} else if rawCount > 0 {
		tag = 2
		b.StoreBytes(enc)
	}
	b.StoreLEB(uint64(len(elems))<<2 | uint64(tag))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedByteArray stores a packed u8/i8 array: plain [count][raw bytes].
func StorePackedByteArray[T any](b *Builder, elems []T, storeRaw func(*Builder, T)) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		storeRaw(b, elems[i])
	}
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedIntOptArray stores a compacted packed int arrayWithOptionals:
// [(count<<2)|tag][nil bs][enc bs if tag 2][present elems]. raw (spec/39): no probe,
// every present element is width bytes, tag 1.
func StorePackedIntOptArray[T any](b *Builder, elems []Opt[T], width int, toLEB func(T) uint64, storeRaw func(*Builder, T), raw bool) int {
	before := b.cursor
	count := len(elems)
	if raw {
		for i := count - 1; i >= 0; i-- {
			if elems[i].Ok {
				storeRaw(b, elems[i].V)
			}
		}
		b.StoreBytes(nilBits(elems))
		b.StoreLEB(uint64(count)<<2 | 1)
		return b.StoreLEB(uint64(b.cursor - before))
	}
	enc := make([]byte, (count+7)>>3)
	rawCount, present := 0, 0
	for i := count - 1; i >= 0; i-- {
		if !elems[i].Ok {
			continue
		}
		present++
		lv := toLEB(elems[i].V)
		if LebLength(lv) < width {
			b.StoreLEB(lv)
		} else {
			storeRaw(b, elems[i].V)
			enc[i>>3] |= 1 << (i & 7)
			rawCount++
		}
	}
	tag := 0
	if rawCount == present && present > 0 {
		tag = 1
	} else if rawCount > 0 {
		tag = 2
		b.StoreBytes(enc)
	}
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(count)<<2 | uint64(tag))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedByteOptArray stores [count][nil bs][present raw bytes].
func StorePackedByteOptArray[T any](b *Builder, elems []Opt[T], storeRaw func(*Builder, T)) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		if elems[i].Ok {
			storeRaw(b, elems[i].V)
		}
	}
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedBoolArray stores [blockLen][count][bitset].
func (b *Builder) StorePackedBoolArray(elems []bool) int {
	before := b.cursor
	b.StoreBytes(boolBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedBoolOptArray stores [count][nil bs][present value bitset] (compacted).
func (b *Builder) StorePackedBoolOptArray(elems []Opt[bool]) int {
	before := b.cursor
	present := 0
	for _, e := range elems {
		if e.Ok {
			present++
		}
	}
	val := make([]byte, (present+7)>>3)
	ci := 0
	for _, e := range elems {
		if !e.Ok {
			continue
		}
		if e.V {
			val[ci>>3] |= 1 << (ci & 7)
		}
		ci++
	}
	b.StoreBytes(val)
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedF16Array stores [count][enc bitset][elems]; enc bit 1 = raw 2-byte.
func (b *Builder) StorePackedF16Array(elems []float32, isBf16 bool) int {
	before := b.cursor
	enc := make([]byte, (len(elems)+7)>>3)
	for i := len(elems) - 1; i >= 0; i-- {
		if b.StorePackedF16Scalar(elems[i], isBf16) {
			enc[i>>3] |= 1 << (i & 7)
		}
	}
	b.StoreBytes(enc)
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedF16OptArray stores [count][nil bs][present raw 2-byte].
func (b *Builder) StorePackedF16OptArray(elems []Opt[float32], isBf16 bool) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		if !elems[i].Ok {
			continue
		}
		if isBf16 {
			b.StoreU16(F32ToBf16Bits(elems[i].V))
		} else {
			b.StoreU16(F32ToF16Bits(elems[i].V))
		}
	}
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedFloatArray stores [(count<<2)|mode][elems]: mode 0 self-describing,
// mode 1 (`raw` fields) native-LE.
func (b *Builder) StorePackedFloatArray(elems32 []float32, elems64 []float64, raw bool) int {
	buf, i := b.Take()
	if elems64 != nil {
		buf, i = PutPackedF64ArrayAt(buf, i, elems64, raw)
	} else {
		buf, i = PutPackedF32ArrayAt(buf, i, elems32, raw)
	}
	b.Put(buf, i)
	return b.cursor
}

// StorePackedFloatOptArray is the compacted arrayWithOptionals form of StorePackedFloatArray.
func (b *Builder) StorePackedFloatOptArray(elems32 []Opt[float32], elems64 []Opt[float64], raw bool) int {
	before := b.cursor
	var count int
	if elems64 != nil {
		count = len(elems64)
		for i := count - 1; i >= 0; i-- {
			if !elems64[i].Ok {
				continue
			}
			if raw {
				b.StoreF64(elems64[i].V)
			} else {
				b.StorePackedFloat64(elems64[i].V, true)
			}
		}
		b.StoreBytes(nilBits(elems64))
	} else {
		count = len(elems32)
		for i := count - 1; i >= 0; i-- {
			if !elems32[i].Ok {
				continue
			}
			if raw {
				b.StoreF32(elems32[i].V)
			} else {
				b.StorePackedFloat32(elems32[i].V, true)
			}
		}
		b.StoreBytes(nilBits(elems32))
	}
	b.StoreLEB(uint64(count)<<2 | uint64(boolInt(raw)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedEnumBitArray stores [blockLen][count][bitset] (sub-byte enums).
func (b *Builder) StorePackedEnumBitArray(vals []uint64, bits int) int {
	before := b.cursor
	b.StoreBytes(enumBits(vals, bits))
	b.StoreLEB(uint64(len(vals)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedEnumRawArray stores [blockLen][count][LEB per element].
func (b *Builder) StorePackedEnumRawArray(vals []uint64) int {
	before := b.cursor
	for i := len(vals) - 1; i >= 0; i-- {
		b.StoreLEB(vals[i])
	}
	b.StoreLEB(uint64(len(vals)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedEnumBitOptArray stores [count][nil bs][present value bits] (compacted).
func (b *Builder) StorePackedEnumBitOptArray(elems []Opt[uint64], bits int) int {
	before := b.cursor
	present := make([]uint64, 0, len(elems))
	for _, e := range elems {
		if e.Ok {
			present = append(present, e.V)
		}
	}
	b.StoreBytes(enumBits(present, bits))
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedEnumRawOptArray stores [count][nil bs][present LEB values].
func (b *Builder) StorePackedEnumRawOptArray(elems []Opt[uint64]) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		if elems[i].Ok {
			b.StoreLEB(elems[i].V)
		}
	}
	b.StoreBytes(nilBits(elems))
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedNodeArray stores [count][opt nil bs][(blockLen+child block) per present].
func StorePackedNodeArray[T any](b *Builder, elems []Opt[T], storeChild func(*Builder, T), opt bool) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		if opt && !elems[i].Ok {
			continue
		}
		storeChild(b, elems[i].V)
	}
	if opt {
		b.StoreBytes(nilBits(elems))
	}
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedComplexArray stores utf8/data element arrays: [count][opt nil bs][inline elems].
func StorePackedComplexArray[T any](b *Builder, elems []Opt[T], storeElem func(*Builder, T), opt bool) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		if opt && !elems[i].Ok {
			continue
		}
		storeElem(b, elems[i].V)
	}
	if opt {
		b.StoreBytes(nilBits(elems))
	}
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

// StorePackedUnionArray stores a packed array-of-union: [blockLen][count][nil bs (opt)]
// [LEB hss (opt)][headers][payloads]; apply stores each present element's payload
// (reversed) and returns its header.
func StorePackedUnionArray[T any](b *Builder, elems []Opt[T], apply func(*Builder, T) PackedUnionHdr, opt bool) int {
	before := b.cursor
	count := len(elems)
	hdrs := make([]Opt[PackedUnionHdr], 0, count)
	for i := count - 1; i >= 0; i-- {
		if opt && !elems[i].Ok {
			hdrs = append(hdrs, None[PackedUnionHdr]())
			continue
		}
		hdrs = append(hdrs, Some(apply(b, elems[i].V)))
	}
	hdrStart := b.cursor
	for _, h := range hdrs {
		if h.Ok {
			b.StoreLEB(uint64(h.V.ID<<3 | h.V.Code))
		}
	}
	if opt {
		hss := b.cursor - hdrStart
		b.StoreLEB(uint64(hss))
		nb := make([]byte, (count+7)>>3)
		for j := 0; j < count; j++ {
			idx := count - 1 - j
			if !hdrs[j].Ok {
				nb[idx>>3] |= 1 << (idx & 7)
			}
		}
		b.StoreBytes(nb)
	}
	b.StoreLEB(uint64(count))
	return b.StoreLEB(uint64(b.cursor - before))
}

// ToOpts wraps a plain slice as an all-present Opt slice (shared array helpers).
// ── Plain array stores ───────────────────────────────────────────────────────
//
// A plain `[T]` array has no nil slots, so wrapping it in `[]Opt[T]` just to hand it to
// the arrayWithOptionals store allocates a whole parallel slice per array and throws it
// away. On an OTLP batch that was 78% of the direct builder's allocations. These are the
// same loops with the presence check and the wrapper removed; the emitted bytes are
// identical (the `opt` branches they drop are exactly the ones a plain array never took).

func StorePackedNodeArrayPlain[T any](b *Builder, elems []T, storeChild func(*Builder, T)) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		storeChild(b, elems[i])
	}
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

func StorePackedComplexArrayPlain[T any](b *Builder, elems []T, storeElem func(*Builder, T)) int {
	before := b.cursor
	for i := len(elems) - 1; i >= 0; i-- {
		storeElem(b, elems[i])
	}
	b.StoreLEB(uint64(len(elems)))
	return b.StoreLEB(uint64(b.cursor - before))
}

func StorePtrTableArrayPlain[T any](b *Builder, elems []T, storeElem func(*Builder, T) int) int {
	offs := make([]int, 0, len(elems))
	for i := len(elems) - 1; i >= 0; i-- {
		offs = append(offs, storeElem(b, elems[i]))
	}
	cur := b.cursor
	wc := 0
	for _, off := range offs {
		wc = max(wc, offsetWidthCode(uint64(cur-off+1)))
	}
	for _, off := range offs {
		b.storeUintWc(uint64(cur-off+1), wc)
	}
	return b.StoreLEB(uint64(len(elems))<<2 | uint64(wc))
}

func StoreNodeRefArrayPlain[T any](b *Builder, elems []T, storeRef func(*Builder, T) NodeStoreRef) int {
	refs := make([]NodeStoreRef, 0, len(elems))
	for i := len(elems) - 1; i >= 0; i-- {
		refs = append(refs, storeRef(b, elems[i]))
	}
	cur := b.cursor
	wc, hasPending := 0, false
	for _, r := range refs {
		if r.Pending {
			hasPending = true
		} else {
			wc = max(wc, signedWidthCode(int64(cur-r.Off+1)))
		}
	}
	reserveWc := bits.Len(uint(b.ReserveFieldPointerSize)) - 1
	if hasPending && wc < reserveWc {
		wc = reserveWc
	}
	es := 1 << wc
	for _, r := range refs {
		if !r.Pending {
			b.storeIntWc(int64(cur-r.Off+1), wc)
			continue
		}
		b.storeZeros(es)
		b.addLateBinding(r.Key, lateBind{cursorAt: b.cursor, base: 0, arrayEnd: cur, es: es})
	}
	return b.StoreLEB(uint64(len(elems))<<2 | uint64(wc))
}

// BoolU64 packs a bool into a generated union value's word-sized payload slot.
func BoolU64(b bool) uint64 {
	if b {
		return 1
	}
	return 0
}

func ToOpts[T any](elems []T) []Opt[T] {
	out := make([]Opt[T], len(elems))
	for i, e := range elems {
		out[i] = Some(e)
	}
	return out
}

// Reset rewinds the builder for another independent record (DataSink streaming).
func (b *Builder) Reset() {
	b.cursor = 0
	clear(b.vtLookup)
	clear(b.stringLookup)
	clear(b.StructLookup)
	clear(b.inProgress)
	clear(b.lateBindings)
}

// MakeData copies out the stored region.
func (b *Builder) MakeData() []byte {
	out := make([]byte, b.cursor)
	copy(out, b.buf[len(b.buf)-b.cursor:])
	return out
}

// Bytes returns the finished record WITHOUT copying it. The slice aliases the builder's
// buffer and is only valid until the next Reset / store on this builder, so a caller that
// keeps the bytes must copy them (MakeData) or append them somewhere (AppendTo).
func (b *Builder) Bytes() []byte {
	return b.buf[len(b.buf)-b.cursor:]
}

// AppendTo appends the finished record to dst and returns the extended slice. A caller
// that keeps dst between records reuses its capacity, so steady-state encoding allocates
// nothing at all — where MakeData allocates the whole record every time.
func (b *Builder) AppendTo(dst []byte) []byte {
	return append(dst, b.buf[len(b.buf)-b.cursor:]...)
}

// Grow makes room for a record of n bytes so the write does not have to double its way
// up from the initial 64. A builder reused across records keeps its buffer, so this only
// matters for the first record (or a one-shot builder).
func (b *Builder) Grow(n int) {
	b.ensure(n)
}

// ── Tiny element stores / converters referenced by generated serializers ─────────

func StU8(b *Builder, v uint8)     { b.StoreU8(v) }
func StU16(b *Builder, v uint16)   { b.StoreU16(v) }
func StU32(b *Builder, v uint32)   { b.StoreU32(v) }
func StU64(b *Builder, v uint64)   { b.StoreU64(v) }
func StI8(b *Builder, v int8)      { b.StoreI8(v) }
func StI16(b *Builder, v int16)    { b.StoreI16(v) }
func StI32(b *Builder, v int32)    { b.StoreI32(v) }
func StI64(b *Builder, v int64)    { b.StoreI64(v) }
func StF32(b *Builder, v float32)  { b.StoreF32(v) }
func StF64(b *Builder, v float64)  { b.StoreF64(v) }
func StF16(b *Builder, v float32)  { b.StoreF16(v) }
func StBf16(b *Builder, v float32) { b.StoreBf16(v) }
func StBool(b *Builder, v bool)    { b.StoreBool(v) }

// StEnum stores an enum's backing integer at its raw width (1/2/4/8 bytes).
func StEnum[E ~uint8 | ~uint16 | ~uint32 | ~uint64](width int) func(*Builder, E) {
	return func(b *Builder, v E) {
		switch width {
		case 1:
			b.StoreU8(uint8(v))
		case 2:
			b.StoreU16(uint16(v))
		case 4:
			b.StoreU32(uint32(v))
		default:
			b.StoreU64(uint64(v))
		}
	}
}

// BoolBit is 1 for true, 0 for false (union-array value slots).
func BoolBit(v bool) uint64 { return uint64(boolInt(v)) }

// LebOf / ZigZagOf yield the LEB value of an unsigned / signed element.
func LebOf[T ~uint16 | ~uint32 | ~uint64](v T) uint64 { return uint64(v) }
func ZigZagOf[T ~int16 | ~int32 | ~int64](v T) uint64 { return ToZigZag(int64(v)) }

// EnumRaw / EnumRawOpt widen enum slices to their raw values.
func EnumRaw[E ~uint8 | ~uint16 | ~uint32 | ~uint64](s []E) []uint64 {
	out := make([]uint64, len(s))
	for i, e := range s {
		out[i] = uint64(e)
	}
	return out
}

func EnumRawOpt[E ~uint8 | ~uint16 | ~uint32 | ~uint64](s []Opt[E]) []Opt[uint64] {
	out := make([]Opt[uint64], len(s))
	for i, e := range s {
		if e.Ok {
			out[i] = Some(uint64(e.V))
		}
	}
	return out
}

// ── In-place fixed-width stores over a byte slice (SharedBuffer overlays, spec 20) ──

func PutU8(buf []byte, at int, v uint8)   { buf[at] = v }
func PutU16(buf []byte, at int, v uint16) { binary.LittleEndian.PutUint16(buf[at:], v) }
func PutU32(buf []byte, at int, v uint32) { binary.LittleEndian.PutUint32(buf[at:], v) }
func PutU64(buf []byte, at int, v uint64) { binary.LittleEndian.PutUint64(buf[at:], v) }
func PutI8(buf []byte, at int, v int8)    { buf[at] = uint8(v) }
func PutI16(buf []byte, at int, v int16)  { binary.LittleEndian.PutUint16(buf[at:], uint16(v)) }
func PutI32(buf []byte, at int, v int32)  { binary.LittleEndian.PutUint32(buf[at:], uint32(v)) }
func PutI64(buf []byte, at int, v int64)  { binary.LittleEndian.PutUint64(buf[at:], uint64(v)) }
func PutF32(buf []byte, at int, v float32) {
	binary.LittleEndian.PutUint32(buf[at:], math.Float32bits(v))
}
func PutF64(buf []byte, at int, v float64) {
	binary.LittleEndian.PutUint64(buf[at:], math.Float64bits(v))
}
func PutF16(buf []byte, at int, v float32) { binary.LittleEndian.PutUint16(buf[at:], F32ToF16Bits(v)) }
func PutBf16(buf []byte, at int, v float32) {
	binary.LittleEndian.PutUint16(buf[at:], F32ToBf16Bits(v))
}
func PutBool(buf []byte, at int, v bool) { buf[at] = uint8(boolInt(v)) }

// AlignedRegion returns a zeroed byte region of `size` bytes whose first byte sits at
// an `align`-byte boundary (align must be a power of two): the layout of a
// SharedBuffer places atomics and aligned(N) arrays relative to the region base, so
// the base itself must honour the region alignment (Go's allocator only guarantees the
// size-class alignment).
func AlignedRegion(size, align int) []byte {
	if align <= 1 {
		return make([]byte, size)
	}
	buf := make([]byte, size+align)
	off := int(-uintptr(unsafe.Pointer(&buf[0])) & uintptr(align-1))
	return buf[off : off+size : off+size]
}

// ── Spec-15 graph header framing ─────────────────────────────────────────────────

// FrameWithHeader assembles `[LEB((rootOffset+len(header))<<2 | 0b01)][header][body]`:
// the stored offset spans the header so a reader recovers rootOffset as stored − span.
func FrameWithHeader(rootOffset int, header, body []byte) []byte {
	stored := uint64(rootOffset+len(header))<<2 | 1
	fl := LebLength(stored)
	out := make([]byte, 0, fl+len(header)+len(body))
	var tmp [10]byte
	n := binary.PutUvarint(tmp[:], stored)
	out = append(out, tmp[:n]...)
	out = append(out, header...)
	out = append(out, body...)
	return out
}

// InflateHeader pads a packed header's content with trailing zeros until the whole
// buffer (framing + header + body) is a multiple of maxN, so aligned(N) arrays in the
// body keep their alignment (spec 15 §6 / spec 12); a packed reader ignores the tail.
func InflateHeader(header []byte, rootOffset, bodyLen, maxN int) []byte {
	if maxN <= 1 {
		return header
	}
	hcs, hcsb := binary.Uvarint(header)
	fields := header[hcsb:]
	for q := 0; ; q++ {
		content := int(hcs) + q
		span := LebLength(uint64(content)) + content
		stored := uint64(rootOffset+span)<<2 | 1
		if (LebLength(stored)+span+bodyLen)%maxN == 0 {
			var tmp [10]byte
			n := binary.PutUvarint(tmp[:], uint64(content))
			out := make([]byte, 0, span)
			out = append(out, tmp[:n]...)
			out = append(out, fields...)
			out = append(out, make([]byte, q)...)
			return out
		}
	}
}
