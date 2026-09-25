# Dagr serializer runtime (plan 28 Phase 4) — a faithful port of the TS `Builder`
# (targets/typescript/src/dagr_writer.ts), itself a port of Swift's DataArenaBuilder.
#
# A BACKWARD-growing builder over a SINGLE contiguous buffer (the Rust `DagrBuilder`
# model — see `spec/32-performance-optimization-notes.md` §1.11): the wire lives in the
# tail slice `_buf[_cap - cursor .. _cap]` and every store PREPENDS its bytes at the
# head (`_buf[_cap - cursor - n ..]`), decrementing the head and growing `cursor` by
# `n`. Writing in place (no per-store `List` allocation) is byte-identical to the old
# chunk-list + `make_data()` reversal: prepending each store at the head reproduces a
# reverse-order concatenation with every store's internal byte order preserved. A
# buffer offset is the cursor value AT store time (bytes-from-the-end); the forward
# distance between two stored things is `cursor_now - offset`, and offset `O` lives at
# absolute index `_cap - O` (grow-invariant, since growth prepends capacity).
#
# Mojo differences from the TS reference: (1) node identity for dedup / cycle late-
# binding is the arena's packed `UInt64` handle (not an object), so `struct_lookup` /
# `in_progress` / `late_bindings` are keyed on UInt64. (2) TS passed per-element
# CALLBACKS; Mojo has no ergonomic closures, so the generated serde emits the
# per-element store loop INLINE and passes the Builder pre-computed offset/value
# lists — the array helpers here take lists, not callbacks. (3) A late-binding
# placeholder records the reserved block's offset-from-end `pos` (patched via
# `_buf[_cap - pos + k] = …`) instead of a chunk index.
#
# Gate: serialize(restore(fixture)) must equal the fixture byte-for-byte.

from std.collections import Dict, Set
from std.io.file import FileHandle
from std.memory import unsafe_memcpy, unsafe_memcmp, unsafe_memset_zero
from std.hashlib import Hasher
from std.bit import bit_width
from std.sys import CompilationTarget
from std.sys.intrinsics import llvm_intrinsic, inlined_assembly


# ── varint / zigzag helpers (free functions; also used by the generated serde) ─────

def leb_length(v: UInt64) -> Int:
    # LEB128 byte count = ceil(significant_bits / 7), computed branch- and
    # loop-free.  `v | 1` forces at least one significant bit so v == 0 → 1 byte.
    return Int((bit_width(v | 1) + 6) // 7)


def to_zigzag(v: Int) -> UInt64:
    # n>=0 ? n<<1 : (~n<<1)|1
    if v >= 0:
        return UInt64(v) << 1
    return (UInt64(~v) << 1) | 1


def to_negativ_zigzag(v: UInt64) -> UInt64:
    # vtable size marker: v==0 ? 0 : ((v-1)<<1)|1
    if v == 0:
        return 0
    return ((v - 1) << 1) | 1


# min unsigned width code for `v` (value-ref array slots)
def offset_width_code(v: UInt64) -> Int:
    if v <= 0xff:
        return 0
    if v <= 0xffff:
        return 1
    if v <= 0xffffffff:
        return 2
    return 3


# min signed (two's-complement) width code for distance `d` (node-ref slots)
def signed_width_code(d: Int) -> Int:
    if d >= -128 and d <= 127:
        return 0
    if d >= -32768 and d <= 32767:
        return 1
    if d >= -2147483648 and d <= 2147483647:
        return 2
    return 3


# ── NodeStoreRef (mirrors Rust NodeStoreRef / TS discriminated union) ──────────────
# resolved  -> the node is fully stored at `off`.
# pending   -> the node is an in-flight ANCESTOR (a cycle); a pointer to it is written
#              as a placeholder and patched by finish_storing, keyed on `pid`.

@fieldwise_init
struct NodeStoreRef(Copyable, Movable, ImplicitlyCopyable):
    var is_pending: Bool
    var off: Int
    var pid: UInt64
    var is_nil: Bool


def resolved_ref(off: Int) -> NodeStoreRef:
    return NodeStoreRef(False, off, 0, False)


def pending_ref(pid: UInt64) -> NodeStoreRef:
    return NodeStoreRef(True, 0, pid, False)


def nil_ref() -> NodeStoreRef:
    return NodeStoreRef(False, 0, 0, True)


# A union-slot descriptor produced by pass-1 apply and consumed by pass-2 emit
# (Mojo has no closures, so the TS `{id, emit}` becomes tag + content offset / node
# ref, re-dispatched by the generated emit fn). `off` = out-of-line content offset
# (utf8/data/nested/array pointer variants); `nref` = the stored node (node variant).
@fieldwise_init
struct USlot(Copyable, Movable, ImplicitlyCopyable):
    var tag: UInt8
    var off: Int
    var nref: NodeStoreRef


# Union field-slot tag: [LEB (typeId<<2)|widthCode] where wc reflects the payload byte
# count (1→0, 2→1, 4→2, else 3). `payload_bytes` = cursor delta the emit produced.
def union_slot_wc(payload_bytes: Int) -> Int:
    if payload_bytes == 1:
        return 0
    if payload_bytes == 2:
        return 1
    if payload_bytes == 4:
        return 2
    return 3


# One applied element of a regular/frozen union array (§4.9). `kind`: 0 = value
# (val = raw bit-pattern), 1 = pointer (val = content offset → slot `contentEnd-val`),
# 2 = bidir node (slot `(contentEnd-val)<<1`). `is_nil` = an AWO absent element.
@fieldwise_init
struct UArrElem(Copyable, Movable, ImplicitlyCopyable):
    var kind: UInt8
    var val: UInt64
    var tid: UInt8
    var is_nil: Bool


def node_offset(r: NodeStoreRef) raises -> Int:
    if r.is_pending:
        raise Error("cyclic reference in a context without late-binding support")
    return r.off


# A late-binding placeholder to patch once the target node's offset is known.
# array_end < 0 → a bidir V62 field pointer (4-byte, width code 2); else a node-ref
# array slot (raw fixed-width two's-complement distance `array_end - offset + 1`).
# `pos` = the reserved block's offset-from-end (cursor right after reserving it), so
# byte `k` of the placeholder lives at absolute index `_cap - pos + k`.
@fieldwise_init
struct _LateBind(Copyable, Movable, ImplicitlyCopyable):
    var pos: Int
    var base: Int
    var array_end: Int
    var es: Int


# VTable dedup key (§5). The dedup must stay byte-identical to Rust (whose cache keys
# on the exact normalized-offset `Vec`), but the old String key was built by decimal-
# formatting + concatenating every slot per node — pure waste (perf notes §1.19). The
# slot values are small (≤ 0xffff, enforced below) and the field count is known, so key
# on the raw values in a fixed-size STACK array: no per-node `String`, no heap. Exact —
# the `Dict` compares via `__eq__`, so a hash collision can never mis-dedup (unlike a
# lossy hash key). The array width is the compile-time `VT_MAX` parameter, which the
# codegen sets to the widest regular node in the schema (perf notes §1.19), so every
# vtable fits — one code path, no runtime fallback.
@fieldwise_init
struct _VtKey[VT_MAX: Int](Copyable, Movable, Hashable, Equatable):
    var vals: Array[UInt16, Self.VT_MAX]  # normalized slot values [0..n); tail unused
    var n: Int                                # field count
    var is16: Bool
    var h: UInt64                             # precomputed content hash (folded once)

    def __eq__(self, other: Self) -> Bool:
        if self.h != other.h or self.n != other.n or self.is16 != other.is16:
            return False
        if self.n == 0:
            return True
        return unsafe_memcmp(self.vals.unsafe_ptr(), other.vals.unsafe_ptr(), self.n) == 0

    def __ne__(self, other: Self) -> Bool:
        return not (self == other)

    def __hash__[H: Hasher](self, mut hasher: H):
        hasher.update(self.h.as_bytes())


struct Builder[VT_MAX: Int = 32](Movable):
    var _buf: List[UInt8]                     # backing store; wire = _buf[_cap - cursor .. _cap]
    var cursor: Int                           # bytes stored so far (the wire length)
    var _vt_lookup: Dict[_VtKey[Self.VT_MAX], Int] # vtable norm-key -> header offset (dedup)
    var _string_lookup: Dict[String, Int]    # string -> content offset (utf8 dedup)
    var struct_lookup: Dict[UInt64, Int]     # node packed handle -> offset (dedup)
    var reserve_field_pointer_size: Int      # bidir pointer reserve = 4 (maxSize 2MiB)
    var _in_progress: Set[UInt64]
    var _late: Dict[UInt64, List[_LateBind]]
    var elide_defaults: Bool                 # §13: omit required fields equal to their default
    var _ref_pool: List[List[NodeStoreRef]]  # recycled node-ref-array scratch (§1.21)
    var _int_pool: List[List[Int]]           # recycled ptr-table offset scratch
    var _byte_pool: List[List[UInt8]]        # recycled frozen-packed bitset scratch (§1.32)

    # `hint` = expected node count (a whole-graph build passes it; a per-record sink
    # writer leaves it 0). Pre-sizing the dedup/cycle maps to the node count avoids the
    # SwissTable resize-from-empty every encode (perf notes §1.20). ×2 headroom so the
    # string cache (more unique strings than nodes) also usually fits without a resize.
    def __init__(out self, hint: Int = 0, max_size: Int = 2 * 1024 * 1024):
        # Backing store is write-once (stores overwrite it; only `_buf[_cap-cursor.._cap]`
        # is ever read), so allocate it UNINITIALIZED — the `List.resize(_, 0)` zero-fill
        # is dead work (perf notes §1.11, Rust `alloc_uninit`). Pre-size from the node-count
        # hint (~64 B/node) so a whole-graph build usually never grows; `_grow` covers the
        # tail if the estimate is short. A sink writer (hint=0) starts at 1 KiB and doubles.
        var _cap = 1024 if hint <= 0 else (hint * 64 if hint * 64 > 1024 else 1024)
        self._buf = List[UInt8](unsafe_uninit_length=_cap)
        self.cursor = 0
        self._vt_lookup = Dict[_VtKey[Self.VT_MAX], Int]()  # distinct vtable shapes are few
        if hint > 0:
            self._string_lookup = Dict[String, Int](capacity=hint * 2)
            self.struct_lookup = Dict[UInt64, Int](capacity=hint * 2)
            self._in_progress = Set[UInt64]()
        else:
            self._string_lookup = Dict[String, Int]()
            self.struct_lookup = Dict[UInt64, Int]()
            self._in_progress = Set[UInt64]()
        # reserve width derived from max_size like Rust/Swift: bits = bitlen(max_size)+3;
        # width = nextPow2(ceil(bits/8)). maxSize 2 MiB -> 4 B (code 2); 1024 -> 2 B (code 1).
        var _bits = 3
        var _m = max_size
        while _m > 0:
            _bits += 1
            _m >>= 1
        var _nbytes = (_bits >> 3) + (1 if (_bits & 7) != 0 else 0)
        var _w = 1
        while _w < _nbytes:
            _w <<= 1
        self.reserve_field_pointer_size = _w
        self._late = Dict[UInt64, List[_LateBind]]()
        self.elide_defaults = True
        self._ref_pool = List[List[NodeStoreRef]]()
        self._int_pool = List[List[Int]]()
        self._byte_pool = List[List[UInt8]]()

    # ── scratch pools (§1.21): recycle the per-array `List`s the store walk builds and
    # discards, so a whole-graph encode allocates them ~once (grows to max array-nesting
    # depth), not once per array. The pool persists across `reset()` (stays warm for a
    # streaming sink writer). `take_*` hands out a cleared buffer; `return_*` recycles it.
    def take_refs(mut self) -> List[NodeStoreRef]:
        if len(self._ref_pool) > 0:
            return self._ref_pool.pop()
        return List[NodeStoreRef]()

    def return_refs(mut self, var l: List[NodeStoreRef]):
        l.clear()
        self._ref_pool.append(l^)

    def take_ints(mut self) -> List[Int]:
        if len(self._int_pool) > 0:
            return self._int_pool.pop()
        return List[Int]()

    def return_ints(mut self, var l: List[Int]):
        l.clear()
        self._int_pool.append(l^)

    def take_bytes(mut self) -> List[UInt8]:
        if len(self._byte_pool) > 0:
            return self._byte_pool.pop()
        return List[UInt8]()

    def return_bytes(mut self, var l: List[UInt8]):
        l.clear()
        self._byte_pool.append(l^)

    # ── contiguous backward buffer ─────────────────────────────────────────────────
    # Ensure room for `n` more bytes at the head; grow (prepend capacity) if needed.
    @always_inline
    def _reserve(mut self, n: Int):
        if self.cursor + n > len(self._buf):
            self._grow(self.cursor + n)

    @no_inline
    def _grow(mut self, need: Int):
        var oldcap = len(self._buf)
        var newcap = oldcap * 2
        if newcap < need:
            newcap = need
        var nb = List[UInt8](unsafe_uninit_length=newcap)   # uninit: head is never read
        # Copy the existing wire (the tail slice) to the tail of the new buffer so the
        # far end stays anchored — offsets-from-end (and late-bind `pos`) are unchanged.
        if self.cursor > 0:
            unsafe_memcpy(dest=nb.unsafe_ptr().unsafe_offset((newcap - self.cursor)),
                   src=self._buf.unsafe_ptr().unsafe_offset((oldcap - self.cursor)), count=self.cursor)
        self._buf = nb^

    # Write index of the FIRST (lowest-address) byte of the next `n`-byte store.
    @always_inline
    def _head(self, n: Int) -> Int:
        return len(self._buf) - self.cursor - n

    # Rewind for reuse on another independent record (a DataSink streaming writer):
    # keep the buffer allocation, clear the dedup / cycle caches so each record dedups
    # only within itself — byte-identical to a fresh Builder, but no per-record alloc.
    # Only non-empty tables are cleared: `clear()` re-initializes a table even when it is
    # empty, ~88 ns for all five — more than encoding a small record (a direct-builder /
    # packed record never touches most of them).
    def reset(mut self):
        self.cursor = 0
        if len(self._vt_lookup) > 0:
            self._vt_lookup.clear()
        if len(self._string_lookup) > 0:
            self._string_lookup.clear()
        if len(self.struct_lookup) > 0:
            self.struct_lookup.clear()
        if len(self._in_progress) > 0:
            self._in_progress.clear()
        if len(self._late) > 0:
            self._late.clear()

    # ── core stores (write in place at the head; return the new cursor) ─────────────
    def store_bytes(mut self, bytes: List[UInt8]) -> Int:
        var n = len(bytes)
        self._reserve(n)
        unsafe_memcpy(dest=self._buf.unsafe_ptr().unsafe_offset(self._head(n)), src=bytes.unsafe_ptr(), count=n)
        self.cursor += n
        return self.cursor

    # `check`: when False the caller has already `_reserve`d enough room for this store
    # (e.g. a loop that reserved its whole upper bound up front), so the per-store bounds
    # test is compiled out. Default True keeps every call site safe/unchanged.
    def store_u8[check: Bool = True](mut self, v: UInt8) -> Int:
        comptime if check:
            self._reserve(1)
        self._buf.unsafe_ptr()[unsafe_offset=self._head(1)] = v
        self.cursor += 1
        return self.cursor

    def store_u16[check: Bool = True](mut self, v: UInt16) -> Int:
        comptime if check:
            self._reserve(2)
        (self._buf.unsafe_ptr().unsafe_offset(self._head(2))).unsafe_bitcast[UInt16]().unsafe_store[alignment=1](v)
        self.cursor += 2
        return self.cursor

    def store_u32[check: Bool = True](mut self, v: UInt32) -> Int:
        comptime if check:
            self._reserve(4)
        (self._buf.unsafe_ptr().unsafe_offset(self._head(4))).unsafe_bitcast[UInt32]().unsafe_store[alignment=1](v)
        self.cursor += 4
        return self.cursor

    def store_u64[check: Bool = True](mut self, v: UInt64) -> Int:
        comptime if check:
            self._reserve(8)
        (self._buf.unsafe_ptr().unsafe_offset(self._head(8))).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](v)
        self.cursor += 8
        return self.cursor

    # signed integers share the LE two's-complement layout of the unsigned store
    def store_i8[check: Bool = True](mut self, v: Int8) -> Int:
        return self.store_u8[check](v.cast[DType.uint8]())
    def store_i16[check: Bool = True](mut self, v: Int16) -> Int:
        return self.store_u16[check](v.cast[DType.uint16]())
    def store_i32[check: Bool = True](mut self, v: Int32) -> Int:
        return self.store_u32[check](v.cast[DType.uint32]())
    def store_i64[check: Bool = True](mut self, v: Int64) -> Int:
        return self.store_u64[check](v.cast[DType.uint64]())

    def store_f32[check: Bool = True](mut self, v: Float32) -> Int:
        return self.store_u32[check](UInt32(v.to_bits()))
    def store_f64[check: Bool = True](mut self, v: Float64) -> Int:
        return self.store_u64[check](UInt64(v.to_bits()))
    def store_f16(mut self, v: Float16) -> Int:
        return self.store_u16(UInt16(v.to_bits()))
    def store_bf16(mut self, v: BFloat16) -> Int:
        return self.store_u16(UInt16(v.to_bits()))

    # ── packed self-describing floats (sub-tag scheme; returns True if RAW fallback) ─
    # `elem` = array element: the raw fallback gets a 0x07/0x08 tag so every element is
    # self-describing (arrays are mode 0). Mirrors TS storePackedFloat32/64.
    def store_packed_float32[check: Bool = True](mut self, v: Float32, elem: Bool) -> Bool:
        # Classify special values from the bit pattern (a few integer ops) instead of an
        # FP-predicate cascade — same tags, faster on incompressible packed floats (§1.3).
        var bits = UInt32(v.to_bits())
        if (bits << 1) == 0:                                   # ±0.0 collapsed: both zeros
            _ = self.store_u8[check](UInt8(bits >> 31)); return False   # clear except sign; sign IS the tag
        var exp = (bits >> 23) & 0xff
        if exp == 0xff:
            if (bits & 0x7fffff) != 0:
                _ = self.store_u8[check](0x04); return False          # NaN
            _ = self.store_u8[check](UInt8(0x03) if (bits >> 31) != 0 else UInt8(0x02)); return False   # ±inf
        var av = -v if v < 0 else v
        if av < Float32(1 << 21) and v == Float32(Int(v)):     # small integer
            var zz = to_zigzag(Int(v))
            if leb_length(zz) <= 3:
                _ = self.store_leb[check](zz); _ = self.store_u8[check](0x05); return False
        # f16 pre-filter: f16→f32 always zeroes the low 13 mantissa bits, so a nonzero low
        # 13 can't be f16-exact — skip the round-trip for the common case (byte-identical).
        if (bits & 0x1fff) == 0:
            var h = v.cast[DType.float16]()
            if h.cast[DType.float32]() == v:
                _ = self.store_u16[check](UInt16(h.to_bits())); _ = self.store_u8[check](0x06); return False
        _ = self.store_f32[check](v)
        if elem:
            _ = self.store_u8[check](0x07)
        return True

    def store_packed_float64[check: Bool = True](mut self, v: Float64, elem: Bool) -> Bool:
        # Classify special values from the bit pattern (a few integer ops) instead of an
        # FP-predicate cascade — same tags, faster on incompressible packed floats (§1.3).
        var bits = UInt64(v.to_bits())
        if (bits << 1) == 0:                                   # ±0.0 collapsed: both zeros
            _ = self.store_u8[check](UInt8(bits >> 63)); return False   # clear except sign; sign IS the tag
        var exp = (bits >> 52) & 0x7ff
        if exp == 0x7ff:
            if (bits & 0xfffffffffffff) != 0:
                _ = self.store_u8[check](0x04); return False
            _ = self.store_u8[check](UInt8(0x03) if (bits >> 63) != 0 else UInt8(0x02)); return False
        var av = -v if v < 0 else v
        if av < Float64(1 << 48) and v == Float64(Int(v)):
            var zz = to_zigzag(Int(v))
            if leb_length(zz) <= 7:
                _ = self.store_leb[check](zz); _ = self.store_u8[check](0x05); return False
        var f32 = v.cast[DType.float32]()                      # f32-exact → f16/f32
        if f32.cast[DType.float64]() == v:
            # f16 pre-filter (low 13 mantissa bits of the f32 must be zero) — skips the
            # f32→f16→f32 round-trip for the common non-f16 case; byte-identical.
            if (UInt32(f32.to_bits()) & 0x1fff) == 0:
                var h = f32.cast[DType.float16]()
                if h.cast[DType.float32]() == f32:
                    _ = self.store_u16[check](UInt16(h.to_bits())); _ = self.store_u8[check](0x06); return False
            _ = self.store_f32[check](f32); _ = self.store_u8[check](0x07); return False
        _ = self.store_f64[check](v)
        if elem:
            _ = self.store_u8[check](0x08)
        return True

    # Packed f16/bf16 scalar: special value → 1-byte tag (False), else raw 2 bytes (True).
    def store_packed_f16_scalar[check: Bool = True](mut self, v: Float16) -> Bool:
        var bits = UInt16(v.to_bits())
        if bits == 0:
            _ = self.store_u8[check](0x00); return False
        if bits == 0x8000:
            _ = self.store_u8[check](0x01); return False
        if ((bits >> 10) & 0x1f) == 0x1f:
            if (bits & 0x3ff) != 0:
                _ = self.store_u8[check](0x04); return False
            _ = self.store_u8[check](UInt8(0x03) if (bits >> 15) != 0 else UInt8(0x02)); return False
        _ = self.store_u16[check](bits); return True

    def store_packed_bf16_scalar[check: Bool = True](mut self, v: BFloat16) -> Bool:
        var bits = UInt16(v.to_bits())
        if bits == 0:
            _ = self.store_u8[check](0x00); return False
        if bits == 0x8000:
            _ = self.store_u8[check](0x01); return False
        if ((bits >> 7) & 0xff) == 0xff:
            if (bits & 0x7f) != 0:
                _ = self.store_u8[check](0x04); return False
            _ = self.store_u8[check](UInt8(0x03) if (bits >> 15) != 0 else UInt8(0x02)); return False
        _ = self.store_u16[check](bits); return True

    # store `es` little-endian bytes of unsigned `v` by width code (0/1/2/3 = 1/2/4/8B)
    def _store_uint_wc[check: Bool = True](mut self, v: UInt64, wc: Int) -> Int:
        if wc == 0:
            return self.store_u8[check](UInt8(v & 0xff))
        if wc == 1:
            return self.store_u16[check](UInt16(v & 0xffff))
        if wc == 2:
            return self.store_u32[check](UInt32(v & 0xffffffff))
        return self.store_u64[check](v)

    def _store_int_wc[check: Bool = True](mut self, v: Int, wc: Int) -> Int:
        # two's-complement in the low `es` bytes (same LE layout as unsigned)
        return self._store_uint_wc[check](UInt64(v) & ((UInt64(1) << UInt64((1 << wc) * 8)) - 1
                                                if wc < 3 else ~UInt64(0)), wc)

    # ── LEB128 (low 7 bits first; value 0 → single 0x00) ──────────────────────────
    def store_leb[check: Bool = True](mut self, value: UInt64) -> Int:
        # 1-byte fast path (value < 128): the dominant case — tags, small counts
        # and indices — and it subsumes value == 0.
        if value < 0x80:
            return self.store_u8[check](UInt8(value))
        # ── x86-BMI2 branch-free path (comptime-gated) ─────────────────────────
        # PDEP scatters the 7-bit groups into byte lanes in one instruction; OR in
        # the continuation bits and store a single 8-byte word backward (§1.36
        # positioning), advancing the cursor by n. Handles value < 2^56 (≤ 8 LEB
        # bytes); larger values fall through to the portable loop below. This is
        # ONLY compiled on x86-with-BMI2 (note: PEXT/PDEP are microcoded/slow on AMD
        # pre-Zen3 — measure and keep-or-revert on such parts). ARM/others take the loop.
        # PDEP is emitted as inline asm rather than `llvm.x86.bmi.pdep.64`: current LLVM no
        # longer exposes that intrinsic by name, and the mnemonic is stable across toolchains.
        comptime if CompilationTarget.is_x86() and CompilationTarget._has_feature["bmi2"]():
            if value < (UInt64(1) << 56):
                var n = leb_length(value)
                var spread = inlined_assembly[
                    "pdepq $2, $1, $0", UInt64, constraints="=r,r,r",
                    has_side_effect=False](value, UInt64(0x7f7f7f7f7f7f7f7f))
                var cont = UInt64(0x8080808080808080) & (
                    (UInt64(1) << UInt64(8 * (n - 1))) - 1)
                comptime if check:
                    self._reserve(8)
                var head8 = len(self._buf) - self.cursor - 8
                (self._buf.unsafe_ptr().unsafe_offset(head8)).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](
                    (spread | cont) << UInt64((8 - n) * 8))
                self.cursor += n
                return self.cursor
        # ── portable loop (ARM/others; and the x86 ≥ 2^56 fallback) — §1.34 ─────
        var n = leb_length(value)
        comptime if check:
            self._reserve(n)
        var p = self._buf.unsafe_ptr().unsafe_offset(self._head(n))
        var x = value
        # Every byte but the last carries the continuation bit — write those
        # unconditionally, then the terminating byte, so the loop has no per-byte
        # data-dependent branch.
        for i in range(n - 1):
            p[unsafe_offset=i] = UInt8(x & 0x7f) | 0x80
            x >>= 7
        p[unsafe_offset=n - 1] = UInt8(x & 0x7f)
        self.cursor += n
        return self.cursor

    # ── V62 fixed-width pointer: value<<2 | widthCode (width by magnitude) ─────────
    def store_v62(mut self, value: UInt64, min_code: Int = 0) raises -> Int:
        # Branch-free width store. The width code comes from one `bit_width`
        # (≤6 payload bits→0, ≤14→1, ≤30→2, ≤62→3), floored at `min_code`.
        # Because the builder grows BACKWARD, an n-byte store occupies the head
        # window `[cap-cursor-n, cap-cursor)`. Rather than dispatch on width, we
        # always do ONE unaligned 8-byte store at `cap-cursor-8`, left-shifting
        # the payload by `(8-n)` bytes so its n little-endian bytes land at the
        # TOP of that window (= the committed region), and advance the cursor by
        # only n. The low `8-n` scratch bytes fall below the new head and are
        # overwritten by the next store; the previous committed bytes are never
        # touched (each store writes strictly below the prior head). This drops
        # the 4-way width branch — which mispredicts badly when back-reference
        # distances vary — for ~2.5× on unpredictable-width pointer streams.
        var bits = Int(bit_width(value))
        if bits > 62:
            raise Error("cantStoreValueAsV62")
        var code = max(Int(bits > 6) + Int(bits > 14) + Int(bits > 30), min_code)
        var n = 1 << code
        var payload = (value << 2) | UInt64(code)
        self._reserve(8)                      # always room for a full u64 store
        var head8 = len(self._buf) - self.cursor - 8
        (self._buf.unsafe_ptr().unsafe_offset(head8)).unsafe_bitcast[UInt64]().unsafe_store[alignment=1](
            payload << UInt64((8 - n) * 8))
        self.cursor += n
        return self.cursor

    def store_forward_pointer(mut self, offset: Int) raises -> Int:
        return self.store_v62(UInt64(self.cursor - offset))

    # ── cycle-aware node storing (mirrors Rust begin/finish_storing) ───────────────
    def begin_storing(mut self, id: UInt64) raises -> NodeStoreRef:
        # returns a resolved ref (cached / in-flight) with is_pending flag, or a
        # sentinel `off == -1` to mean "proceed storing fresh".
        var _sr = self.struct_lookup.get(id)
        if _sr:
            return resolved_ref(_sr.value())
        if id in self._in_progress:
            return pending_ref(id)
        self._in_progress.add(id)
        return NodeStoreRef(False, -1, 0, False)      # sentinel: proceed

    # Perf §1.6: a statically-acyclic node type (see `_node_can_cycle`) can never be a
    # re-entrant ancestor, so it needs neither the `_in_progress` set nor `_late`
    # back-patching — only the dedup cache. This is the lightweight begin/finish pair
    # the generator emits for such types (byte-identical: an acyclic store never
    # produces a pending ref, so `finish_storing` reduces exactly to the cache insert).
    def begin_storing_acyclic(mut self, id: UInt64) raises -> NodeStoreRef:
        var _sr = self.struct_lookup.get(id)
        if _sr:
            return resolved_ref(_sr.value())
        return NodeStoreRef(False, -1, 0, False)      # sentinel: proceed (no cycle set)

    def finish_storing_acyclic(mut self, id: UInt64, offset: Int):
        self.struct_lookup[id] = offset

    def _add_late(mut self, id: UInt64, bind: _LateBind) raises:
        if id in self._late:
            self._late[id].append(bind)
        else:
            var l = List[_LateBind]()
            l.append(bind)
            self._late[id] = l^

    def store_bidirectional_pointer(mut self, r: NodeStoreRef) raises -> Int:
        if not r.is_pending:
            return self.store_v62(to_zigzag(self.cursor - r.off))
        var base = self.cursor                 # cursor BEFORE the placeholder
        _ = self.store_zeros(self.reserve_field_pointer_size)
        self._add_late(r.pid, _LateBind(self.cursor, base, -1,
                                        self.reserve_field_pointer_size))
        return self.cursor

    def finish_storing(mut self, id: UInt64, offset: Int) raises:
        self._in_progress.remove(id)
        if id in self._late:
            var binds = self._late[id].copy()
            var cap = len(self._buf)
            var p = self._buf.unsafe_ptr()
            for bi in range(len(binds)):
                var bd = binds[bi]
                var at = cap - bd.pos                          # first byte of the block
                if bd.array_end >= 0:
                    var rel = bd.array_end - offset + 1        # signed, raw fixed-width
                    var x = UInt64(rel) & ((UInt64(1) << UInt64(bd.es * 8)) - 1
                                           if bd.es < 8 else ~UInt64(0))
                    for k in range(bd.es):
                        p[unsafe_offset=at + k] = UInt8((x >> UInt64(k * 8)) & 0xff)
                else:
                    var encoded = to_zigzag(bd.base - offset)  # may be negative
                    # es bytes → V62 width code (4→2, 2→1, 1→0)
                    var wc = 0 if bd.es == 1 else (1 if bd.es == 2 else (2 if bd.es == 4 else 3))
                    var v = ((encoded << 2) | UInt64(wc))
                    for k in range(bd.es):
                        p[unsafe_offset=at + k] = UInt8((UInt64(v) >> UInt64(k * 8)) & 0xff)
            _ = self._late.pop(id)
        self.struct_lookup[id] = offset

    # ── utf8 / data content (length-prefixed) ─────────────────────────────────────
    def store_utf8(mut self, s: String, dedup: Bool) raises -> Int:
        if dedup:
            var _sh = self._string_lookup.get(s)     # one lookup
            if _sh:
                return _sh.value()
        var b = s.as_bytes()                          # Span[UInt8], no copy
        var n = len(b)
        self._reserve(n)                              # write the bytes straight in place —
        if n > 0:                                     # no intermediate List, no second copy
            unsafe_memcpy(dest=self._buf.unsafe_ptr().unsafe_offset(self._head(n)), src=b.unsafe_ptr(), count=n)
        self.cursor += n
        var off = self.store_leb(UInt64(n))
        if dedup:
            self._string_lookup[s] = off
        return off

    def store_data(mut self, bytes: List[UInt8]) -> Int:
        var n = len(bytes)
        _ = self.store_bytes(bytes)
        return self.store_leb(UInt64(n))

    # §1.8: a native little-endian fixed-width numeric array is byte-identical to the
    # `List[T]`'s memory, so store the whole element block with one `memcpy` instead of a
    # reversed per-element loop. The reversed loop lands element `i` at wire offset `i*W`
    # (element 0 at the front); a forward `memcpy` of the row lands it identically — same
    # bytes on a little-endian target. `w` is the wire/in-memory element width (they match
    # for int/float, so the generator excludes f16/bf16 and enum wrappers). Returns cursor.
    def store_raw_block[T: Copyable](mut self, data: List[T], w: Int) -> Int:
        var nbytes = len(data) * w
        self._reserve(nbytes)
        if nbytes > 0:
            unsafe_memcpy(dest=self._buf.unsafe_ptr().unsafe_offset(self._head(nbytes)),
                   src=data.unsafe_ptr().unsafe_bitcast[UInt8](), count=nbytes)
        self.cursor += nbytes
        return self.cursor

    # `n` zero bytes (absent AWO element slots; also late-bind placeholders).
    def store_zeros[check: Bool = True](mut self, n: Int) -> Int:
        comptime if check:
            self._reserve(n)
        var p = self._buf.unsafe_ptr().unsafe_offset(self._head(n))
        for i in range(n):
            p[unsafe_offset=i] = 0
        self.cursor += n
        return self.cursor

    # A nil bitset (⌈count/8⌉ bytes) with bit i set when `absent[i]`. Indexed by i.
    def store_nil_bits(mut self, absent: List[Bool]) -> Int:
        var nb = (len(absent) + 7) >> 3
        var bs = self._zeros(nb)
        for i in range(len(absent)):
            if absent[i]:
                bs[i >> 3] |= UInt8(1) << UInt8(i & 7)
        return self.store_bytes(bs)

    def _zeros(self, n: Int) -> List[UInt8]:
        var bs = List[UInt8](unsafe_uninit_length=n)   # one alloc, no per-byte append
        unsafe_memset_zero(bs.unsafe_ptr(), n)                # single vectorized zero-fill
        return bs^

    # ── regular/frozen array framing (elements pre-stored inline by the generator) ─
    # Bool array: [LEB count][value bitset], bit i = elem i.
    def store_bool_array(mut self, elems: List[Bool]) -> Int:
        var bs = self._zeros((len(elems) + 7) >> 3)
        for i in range(len(elems)):
            if elems[i]:
                bs[i >> 3] |= UInt8(1) << UInt8(i & 7)
        _ = self.store_bytes(bs)
        return self.store_leb(UInt64(len(elems)))

    # Bool arrayWithOptionals (uncompacted): [count][nil bitset][value bitset], by i.
    def store_opt_bool_array(mut self, elems: List[Optional[Bool]]) -> Int:
        var nb = (len(elems) + 7) >> 3
        var val = self._zeros(nb)
        var nil = self._zeros(nb)
        for i in range(len(elems)):
            if not elems[i]:
                nil[i >> 3] |= UInt8(1) << UInt8(i & 7)
            elif elems[i].value():
                val[i >> 3] |= UInt8(1) << UInt8(i & 7)
        _ = self.store_bytes(val)
        _ = self.store_bytes(nil)
        return self.store_leb(UInt64(len(elems)))

    # Sub-byte enum array: [LEB count][packed bits] (bits ∈ {1,2,4}).
    def store_enum_bit_array(mut self, elems: List[UInt8], bits: Int) -> Int:
        var per = 8 // bits
        var mask = UInt8((1 << bits) - 1)
        var bs = self._zeros((len(elems) * bits + 7) // 8)
        for i in range(len(elems)):
            bs[i // per] |= (elems[i] & mask) << UInt8((i % per) * bits)
        _ = self.store_bytes(bs)
        return self.store_leb(UInt64(len(elems)))

    # Sub-byte enum awo (uncompacted): [count][nil bitset][value bitset], by i.
    def store_opt_enum_bit_array(mut self, elems: List[Optional[UInt8]], bits: Int) -> Int:
        var per = 8 // bits
        var mask = UInt8((1 << bits) - 1)
        var nil = self._zeros((len(elems) + 7) >> 3)
        var val = self._zeros((len(elems) * bits + 7) // 8)
        for i in range(len(elems)):
            if not elems[i]:
                nil[i >> 3] |= UInt8(1) << UInt8(i & 7)
            else:
                val[i // per] |= (elems[i].value() & mask) << UInt8((i % per) * bits)
        _ = self.store_bytes(val)
        _ = self.store_bytes(nil)
        return self.store_leb(UInt64(len(elems)))

    # Pointer-table array (utf8/data elements): each element's content already stored
    # (offsets in `offs`, -1 = nil); write the `[count×es]` slot table (slot =
    # `cur - off + 1`, 0 = nil) then the header `(count<<2)|widthCode`. Unsigned slots.
    def store_ptr_table(mut self, offs: List[Int]) -> Int:
        var cur = self.cursor
        var wc = 0
        for o in offs:
            if o >= 0:
                var c = offset_width_code(UInt64(cur - o + 1))
                if c > wc:
                    wc = c
        self._reserve(len(offs) * (1 << wc))          # whole slot table up front
        for o in offs:
            var d = UInt64(0) if o < 0 else UInt64(cur - o + 1)
            _ = self._store_uint_wc[False](d, wc)
        return self.store_leb((UInt64(len(offs)) << 2) | UInt64(wc))

    # Node-ref array (signed two's-complement slots, §4.5): refs already point to
    # stored content; slot = distance `cur - off + 1` (0 = nil). A pending (cyclic)
    # element gets a raw fixed-width placeholder patched by finish_storing; any pending
    # forces wc ≥ 2 so the 4-byte patch fits.
    def store_node_ref_array(mut self, refs: List[NodeStoreRef]) raises -> Int:
        var cur = self.cursor
        var wc = 0
        var has_pending = False
        for r in refs:
            if r.is_nil:
                continue
            if not r.is_pending:
                var c = signed_width_code(cur - r.off + 1)
                if c > wc:
                    wc = c
            else:
                has_pending = True
        var reserve_wc = 0 if self.reserve_field_pointer_size == 1 else (1 if self.reserve_field_pointer_size == 2 else (2 if self.reserve_field_pointer_size == 4 else 3))
        if has_pending and wc < reserve_wc:
            wc = reserve_wc
        var es = (1 << wc)
        self._reserve(len(refs) * es)                  # whole slot table up front
        for r in refs:
            if r.is_nil:
                _ = self._store_int_wc[False](0, wc)
            elif not r.is_pending:
                _ = self._store_int_wc[False](cur - r.off + 1, wc)
            else:
                _ = self.store_zeros[False](es)
                self._add_late(r.pid, _LateBind(self.cursor, 0, cur, es))
        return self.store_leb((UInt64(len(refs)) << 2) | UInt64(wc))

    # Regular/frozen union array (§4.9): element content already stored (pass 1);
    # `applied` in REVERSED element order (applied[j] = element count-1-j), nil-marked
    # for AWO absent. Stores [slot table][nil bitset (opt)][typeId section][header].
    # Slot = raw value (kind 0) / distance content_end→content (1) / distance<<1 (2).
    def store_union_array(mut self, count: Int, applied: List[UArrElem], bp: Int,
                          opt: Bool) raises -> Int:
        var content_end = self.cursor
        var slots = List[UInt64]()
        var wc = 0
        for a in applied:
            var v = UInt64(0)
            if not a.is_nil:
                if a.kind == 0:
                    v = a.val
                elif a.kind == 1:
                    v = UInt64(content_end - Int(a.val))
                else:
                    v = UInt64(content_end - Int(a.val)) << 1
                var c = offset_width_code(v)
                if c > wc:
                    wc = c
            slots.append(v)
        self._reserve(len(slots) * (1 << wc))          # whole slot table up front
        for v in slots:
            _ = self._store_uint_wc[False](v, wc)
        if opt:
            var nil = self._zeros((count + 7) >> 3)
            for j in range(count):
                var idx = count - 1 - j
                if applied[j].is_nil:
                    nil[idx >> 3] |= UInt8(1) << UInt8(idx & 7)
            _ = self.store_bytes(nil)
        if bp < 8:                                   # sub-byte typeId bitset
            var per = 8 // bp
            var mask = UInt8((1 << bp) - 1)
            var bs = self._zeros((count * bp + 7) // 8)
            for j in range(count):
                var idx = count - 1 - j
                var tid = UInt8(0) if applied[j].is_nil else applied[j].tid
                bs[idx // per] |= (tid & mask) << UInt8((idx % per) * bp)
            _ = self.store_bytes(bs)
        else:                                        # one byte per typeId (cap ≤ 255)
            self._reserve(len(applied))
            for a in applied:
                _ = self.store_u8[False](UInt8(0) if a.is_nil else a.tid)
        return self.store_leb((UInt64(count) << 2) | UInt64(wc))

    # ── packed-node array bodies: [blockLen][count-tag][elems] (self-sizing) ───────
    # Generated serde precomputes the value lists (forward order); these store the
    # reversed elements + framing and return the blockLen offset.

    def _wcw(self, width: Int) -> Int:
        return 0 if width == 1 else (1 if width == 2 else (2 if width == 4 else 3))

    # Packed int array (width ≥ 2): count-tag=(count<<2)|tag, tag 0 all-LEB / 1 all-raw
    # / 2 mixed (enc bitset). `vals` = UInt64(Int(v)) (sign-extended for signed).
    # `raw` (a `>> raw` field, spec/39): no probe, every element `width` bytes, tag 1.
    def store_packed_int_array(mut self, vals: List[UInt64], width: Int, signed: Bool, raw: Bool) raises -> Int:
        var before = self.cursor
        var n = len(vals)
        if raw:
            self._reserve(n * width)
            var wc = self._wcw(width)
            for i in range(n - 1, -1, -1):
                _ = self._store_uint_wc[False](vals[i], wc)
            _ = self.store_leb((UInt64(n) << 2) | UInt64(1))
            return self.store_leb(UInt64(self.cursor - before))
        var enc = self._zeros((n + 7) >> 3)
        var raw_count = 0
        self._reserve(n * 8)                          # ≤ 8 bytes per element (leb or raw)
        for i in range(n - 1, -1, -1):
            var lebv = to_zigzag(Int(vals[i])) if signed else vals[i]
            if leb_length(lebv) < width:
                _ = self.store_leb[False](lebv)
            else:
                _ = self._store_uint_wc[False](vals[i], self._wcw(width))
                enc[i >> 3] |= UInt8(1) << UInt8(i & 7)
                raw_count += 1
        var tag = 0
        if raw_count == n and n > 0:
            tag = 1
        elif raw_count > 0:
            tag = 2
            _ = self.store_bytes(enc)
        _ = self.store_leb((UInt64(n) << 2) | UInt64(tag))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed u8/i8 array: plain [count][raw bytes] (single-path, no count-tag).
    def store_packed_byte_array(mut self, vals: List[UInt64]) -> Int:
        var before = self.cursor
        self._reserve(len(vals))
        for i in range(len(vals) - 1, -1, -1):
            _ = self.store_u8[False](UInt8(vals[i] & 0xff))
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed bool array: [count][bitset], wrapped in blockLen.
    def store_packed_bool_array(mut self, elems: List[Bool]) -> Int:
        var before = self.cursor
        var bs = self._zeros((len(elems) + 7) >> 3)
        for i in range(len(elems)):
            if elems[i]:
                bs[i >> 3] |= UInt8(1) << UInt8(i & 7)
        _ = self.store_bytes(bs)
        _ = self.store_leb(UInt64(len(elems)))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed sub-byte enum array: [blockLen][count][bitset].
    def store_packed_enum_bit_array(mut self, elems: List[UInt8], bits: Int) -> Int:
        var before = self.cursor
        var per = 8 // bits
        var mask = UInt8((1 << bits) - 1)
        var bs = self._zeros((len(elems) * bits + 7) // 8)
        for i in range(len(elems)):
            bs[i // per] |= (elems[i] & mask) << UInt8((i % per) * bits)
        _ = self.store_bytes(bs)
        _ = self.store_leb(UInt64(len(elems)))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed byte-aligned enum array: [blockLen][count][LEB(rawValue) per element].
    def store_packed_enum_raw_array(mut self, vals: List[UInt64]) -> Int:
        var before = self.cursor
        self._reserve(len(vals) * 10)                 # ≤ 10 LEB bytes per value
        for i in range(len(vals) - 1, -1, -1):
            _ = self.store_leb[False](vals[i])
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed f32/f64 array: [blockLen][(count<<2)|mode][elems] — mode 0 self-describing
    # packed, mode 1 (`>> raw` fields) raw native-LE.
    def store_packed_float32_array(mut self, vals: List[Float32], raw: Bool) -> Int:
        var before = self.cursor
        self._reserve(len(vals) * 5)                  # ≤ 5 bytes per element (f32 + tag)
        for i in range(len(vals) - 1, -1, -1):
            if raw:
                _ = self.store_f32[False](vals[i])
            else:
                _ = self.store_packed_float32[False](vals[i], True)
        _ = self.store_leb((UInt64(len(vals)) << 2) | (UInt64(1) if raw else UInt64(0)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_float64_array(mut self, vals: List[Float64], raw: Bool) -> Int:
        var before = self.cursor
        self._reserve(len(vals) * 9)                  # ≤ 9 bytes per element (f64 + tag)
        for i in range(len(vals) - 1, -1, -1):
            if raw:
                _ = self.store_f64[False](vals[i])
            else:
                _ = self.store_packed_float64[False](vals[i], True)
        _ = self.store_leb((UInt64(len(vals)) << 2) | (UInt64(1) if raw else UInt64(0)))
        return self.store_leb(UInt64(self.cursor - before))

    # Packed f16/bf16 array: [blockLen][count][enc bitset][elems]; enc bit 1 = raw.
    def store_packed_f16_array(mut self, vals: List[Float16]) -> Int:
        var before = self.cursor
        var enc = self._zeros((len(vals) + 7) >> 3)
        self._reserve(len(vals) * 2)                  # ≤ 2 bytes per element
        for i in range(len(vals) - 1, -1, -1):
            if self.store_packed_f16_scalar[False](vals[i]):
                enc[i >> 3] |= UInt8(1) << UInt8(i & 7)
        _ = self.store_bytes(enc)
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_bf16_array(mut self, vals: List[BFloat16]) -> Int:
        var before = self.cursor
        var enc = self._zeros((len(vals) + 7) >> 3)
        self._reserve(len(vals) * 2)                  # ≤ 2 bytes per element
        for i in range(len(vals) - 1, -1, -1):
            if self.store_packed_bf16_scalar[False](vals[i]):
                enc[i >> 3] |= UInt8(1) << UInt8(i & 7)
        _ = self.store_bytes(enc)
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    def _nil_from_present(self, present: List[Bool]) -> List[UInt8]:
        var bs = self._zeros((len(present) + 7) >> 3)
        for i in range(len(present)):
            if not present[i]:
                bs[i >> 3] |= UInt8(1) << UInt8(i & 7)
        return bs^

    # Packed arrayWithOptionals: compacted (only present elems), leading nil bitset.
    # `raw` (spec/39): no probe, every present element `width` bytes, tag 1, no enc bitset.
    def store_packed_int_opt_array(mut self, vals: List[UInt64], present: List[Bool],
                                   width: Int, signed: Bool, raw: Bool) raises -> Int:
        var before = self.cursor
        var n = len(vals)
        if raw:
            var wc = self._wcw(width)
            for i in range(n - 1, -1, -1):
                if present[i]:
                    _ = self._store_uint_wc(vals[i], wc)
            _ = self.store_bytes(self._nil_from_present(present))
            _ = self.store_leb((UInt64(n) << 2) | UInt64(1))
            return self.store_leb(UInt64(self.cursor - before))
        var enc = self._zeros((n + 7) >> 3)
        var raw_count = 0
        var pres_count = 0
        for i in range(n - 1, -1, -1):
            if not present[i]:
                continue
            pres_count += 1
            var lebv = to_zigzag(Int(vals[i])) if signed else vals[i]
            if leb_length(lebv) < width:
                _ = self.store_leb(lebv)
            else:
                _ = self._store_uint_wc(vals[i], self._wcw(width))
                enc[i >> 3] |= UInt8(1) << UInt8(i & 7)
                raw_count += 1
        var tag = 0
        if raw_count == pres_count and pres_count > 0:
            tag = 1
        elif raw_count > 0:
            tag = 2
            _ = self.store_bytes(enc)
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb((UInt64(n) << 2) | UInt64(tag))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_byte_opt_array(mut self, vals: List[UInt64], present: List[Bool]) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if present[i]:
                _ = self.store_u8(UInt8(vals[i] & 0xff))
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_bool_opt_array(mut self, elems: List[Bool], present: List[Bool]) -> Int:
        var before = self.cursor
        var pc = 0
        for p in present:
            if p:
                pc += 1
        var val = self._zeros((pc + 7) >> 3)
        var ci = 0
        for i in range(len(elems)):
            if not present[i]:
                continue
            if elems[i]:
                val[ci >> 3] |= UInt8(1) << UInt8(ci & 7)
            ci += 1
        _ = self.store_bytes(val)
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(elems)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_enum_bit_opt_array(mut self, elems: List[UInt8], present: List[Bool],
                                        bits: Int) -> Int:
        var before = self.cursor
        var pc = 0
        for p in present:
            if p:
                pc += 1
        var per = 8 // bits
        var mask = UInt8((1 << bits) - 1)
        var val = self._zeros((pc * bits + 7) // 8)
        var ci = 0
        for i in range(len(elems)):
            if not present[i]:
                continue
            val[ci // per] |= (elems[i] & mask) << UInt8((ci % per) * bits)
            ci += 1
        _ = self.store_bytes(val)
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(elems)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_enum_raw_opt_array(mut self, vals: List[UInt64], present: List[Bool]) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if present[i]:
                _ = self.store_leb(vals[i])
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_float32_opt_array(mut self, vals: List[Float32], present: List[Bool],
                                       raw: Bool) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if not present[i]:
                continue
            if raw:
                _ = self.store_f32(vals[i])
            else:
                _ = self.store_packed_float32(vals[i], True)
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb((UInt64(len(vals)) << 2) | (UInt64(1) if raw else UInt64(0)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_float64_opt_array(mut self, vals: List[Float64], present: List[Bool],
                                       raw: Bool) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if not present[i]:
                continue
            if raw:
                _ = self.store_f64(vals[i])
            else:
                _ = self.store_packed_float64(vals[i], True)
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb((UInt64(len(vals)) << 2) | (UInt64(1) if raw else UInt64(0)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_f16_opt_array(mut self, vals: List[Float16], present: List[Bool]) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if present[i]:
                _ = self.store_u16(UInt16(vals[i].to_bits()))
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    def store_packed_bf16_opt_array(mut self, vals: List[BFloat16], present: List[Bool]) -> Int:
        var before = self.cursor
        for i in range(len(vals) - 1, -1, -1):
            if present[i]:
                _ = self.store_u16(UInt16(vals[i].to_bits()))
        _ = self.store_bytes(self._nil_from_present(present))
        _ = self.store_leb(UInt64(len(vals)))
        return self.store_leb(UInt64(self.cursor - before))

    # ── aligned fields (§11): pre-element padding + arena finish padding ──────────
    # Pre-pad so the element base (cursor after the reversed elements) is N-aligned;
    # the generator then stores the reversed elements + count LEB. Returns cursor.
    def store_aligned_pre_pad(mut self, elem_bytes: Int, N: Int) -> Int:
        var pad = (-(self.cursor + elem_bytes)) & (N - 1)
        if pad != 0:
            _ = self.store_zeros(pad)
        return self.cursor

    # Aligned byte blob (utf8/data, W=1): pre-pad, reversed bytes, LEB byte-count.
    def store_aligned_bytes(mut self, bytes: List[UInt8], N: Int) -> Int:
        var pad = (-(self.cursor + len(bytes))) & (N - 1)
        if pad != 0:
            _ = self.store_zeros(pad)
        for i in range(len(bytes) - 1, -1, -1):
            _ = self.store_u8(bytes[i])
        return self.store_leb(UInt64(len(bytes)))

    def store_aligned_utf8(mut self, s: String, N: Int) -> Int:
        var b = s.as_bytes()
        var bytes = List[UInt8]()
        for i in range(len(b)):
            bytes.append(b[i])
        return self.store_aligned_bytes(bytes, N)

    # Arena finish padding (§11 §4): zero bytes before the framing LEB so the total
    # length (afterPad + framingLen) ≡ 0 mod maxN, making every aligned element base
    # buffer-relative aligned. Brute-forces the smallest pad (framing LEB width depends
    # on the padded distance). Call after the root node is stored, before framing.
    def store_finish_alignment_padding(mut self, root_offset: Int, max_n: Int):
        if max_n <= 1:
            return
        for p in range(max_n):
            var after_pad = self.cursor + p
            var framing_len = leb_length(UInt64((after_pad - root_offset) << 2))
            if (after_pad + framing_len) % max_n == 0:
                if p != 0:
                    _ = self.store_zeros(p)
                return

    # Packed union array frame (§4.9): payloads already stored (pass 1); `hdrs` in
    # REVERSED element order (present headers only used), `present` parallel. Stores
    # [headers][LEB hss + nil bitset (opt)][count][blockLen].
    def store_packed_union_array_frame(mut self, hdrs: List[UInt64], present: List[Bool],
                                       count: Int, opt: Bool, before: Int) raises -> Int:
        var hdr_start = self.cursor
        for i in range(len(hdrs)):
            if present[i]:
                _ = self.store_leb(hdrs[i])
        if opt:
            var hss = self.cursor - hdr_start
            _ = self.store_leb(UInt64(hss))
            var nil = self._zeros((count + 7) >> 3)
            for j in range(count):
                var idx = count - 1 - j
                if not present[j]:
                    nil[idx >> 3] |= UInt8(1) << UInt8(idx & 7)
            _ = self.store_bytes(nil)
        _ = self.store_leb(UInt64(count))
        return self.store_leb(UInt64(self.cursor - before))

    # ── vtable (regular node); dedup identical entry vectors (§5) ──────────────────
    # `entries` are field value offsets in FORWARD index order (-1 = absent field).
    # Variadic so the generated call passes the offsets directly — no per-node
    # `List[Int]` scratch (perf notes §1.21).
    def store_vtable(mut self, *entries: Int) raises -> Int:
        var nf = len(entries)
        if nf > Self.VT_MAX:
            # Never taken when the codegen sizes VT_MAX from the schema's widest regular
            # node (§1.19); a predictable, always-false branch that guards against an
            # out-of-bounds `key.vals` write for a hand-built Builder with too small a bound.
            raise Error("vtable field count exceeds Builder VT_MAX parameter")
        # Build the normalized slot values straight into a fixed-size stack key, folding
        # the content hash in the same pass (uninitialized tail is never read — __eq__ /
        # __hash__ only touch [0..n)).
        var key = _VtKey[Self.VT_MAX](Array[UInt16, Self.VT_MAX](uninitialized=True), nf, False, 0)
        var is16 = False
        var h = UInt64(1469598103934665603)
        for i in range(nf):
            var e = entries[i]
            var n = UInt64(0) if e < 0 else UInt64(self.cursor - e + 1)
            if n > 0xffff:
                raise Error("vtable entry overflow: field slot exceeds UInt16 wire limit")
            if n > 0xff:
                is16 = True
            key.vals[i] = UInt16(n)
            h = (h ^ n) * UInt64(1099511628211)
        key.is16 = is16
        key.h = h ^ (UInt64(1) if is16 else UInt64(0))
        var _hit = self._vt_lookup.get(key)          # one lookup (not contains + getitem)
        if _hit:
            return self.store_leb(UInt64((self.cursor - _hit.value()) << 1))   # fwd-ref (even)
        var result: Int
        var cnt: Int
        if is16:
            cnt = (nf << 1) | 1
            var sz = leb_length(UInt64(cnt)) + nf * 2
            result = self.store_leb(to_negativ_zigzag(UInt64(sz)))
            for i in range(nf - 1, -1, -1):
                _ = self.store_u16(key.vals[i])
        else:
            cnt = nf << 1
            var sz = 0 if cnt == 0 else leb_length(UInt64(cnt)) + nf
            result = self.store_leb(UInt64(0) if sz == 0 else to_negativ_zigzag(UInt64(sz)))
            for i in range(nf - 1, -1, -1):
                _ = self.store_u8(UInt8(Int(key.vals[i])))
        self._vt_lookup[key.copy()] = self.store_leb(UInt64(cnt))
        return result

    # ── finished buffer: the wire is the tail slice `_buf[_cap - cursor .. _cap]` ───
    def make_data(self) -> List[UInt8]:
        var out = List[UInt8](unsafe_uninit_length=self.cursor)   # fully overwritten below
        if self.cursor > 0:
            unsafe_memcpy(dest=out.unsafe_ptr(),
                   src=self._buf.unsafe_ptr().unsafe_offset((len(self._buf)) - self.cursor),
                   count=self.cursor)
        return out^

    # Append this Builder's bytes (forward wire order) directly onto an existing
    # buffer, skipping the intermediate `make_data()` allocation. Byte-identical to
    # `out.extend(make_data())`; used by the DataSink streaming writers.
    def emit_reversed_into(self, mut out: List[UInt8]):
        if self.cursor == 0:
            return
        var oldn = len(out)
        out.resize(unsafe_uninit_length=oldn + self.cursor)   # new tail overwritten below
        unsafe_memcpy(dest=out.unsafe_ptr().unsafe_offset(oldn),
               src=self._buf.unsafe_ptr().unsafe_offset((len(self._buf)) - self.cursor), count=self.cursor)


# ── DataSink write destinations ("spec/11-data-sink.md" §5) ─────────────────────────────
# The seam a generated `{Sink}StreamWriter[D]` writes through: each record is built in
# the writer's scratch buffer and handed to `write` in ONE call (all-or-nothing from the
# writer's view), so a destination never sees a partial record. The Mojo mirror of the
# Swift `SinkDestination` protocol and the Rust `SinkOut` trait. `Movable & Deinitable`
# lets a generic writer own the destination as a field.
trait SinkDestination(Movable, Deinitable):
    def write(mut self, bytes: Span[UInt8, _]) raises:
        """Append `bytes` (one whole record, or the framing prefix) to the destination."""
        ...

    def flush(mut self) raises:
        """Push any buffered bytes toward the underlying sink (no-op when unbuffered)."""
        ...


struct BufferDestination(Defaultable, SinkDestination):
    """Accumulates the stream in memory — tests and in-process transfer."""
    var buffer: List[UInt8]

    def __init__(out self):
        self.buffer = List[UInt8]()

    def write(mut self, bytes: Span[UInt8, _]) raises:
        self.buffer.extend(bytes)

    def flush(mut self) raises:
        pass


struct FileDestination(SinkDestination):
    """Appends each write straight to an open file — no in-memory accumulation.

    `write` issues one `write_bytes` per record, so completed records are in the file
    even if the process dies before `close()`. `flush` is a no-op: the Mojo `FileHandle`
    does no user-space buffering and exposes no fsync."""
    var file: FileHandle

    def __init__(out self, var file: FileHandle):
        self.file = file^

    def write(mut self, bytes: Span[UInt8, _]) raises:
        self.file.write_bytes(bytes)

    def flush(mut self) raises:
        pass

    def close(mut self) raises:
        self.file.close()


struct BufferedFileDestination(SinkDestination):
    """Batches writes to an open file: bytes accumulate in memory and go to the file in
    one `write_bytes` when the next write would exceed `capacity`, so a stream of small
    records costs one system call per ~`capacity` bytes instead of one per record.

    A record is never split across system calls: a write that does not fit drains the
    buffer first, and a write of at least `capacity` bytes goes straight to the file.
    `capacity <= 1` therefore behaves like `FileDestination`.

    Durability trade-off: up to `capacity` bytes of already-appended records live only in
    memory until `flush()` or `close()`, and are lost if the process dies first. The
    buffer is NOT drained on destruction (a destructor cannot raise), so call `close()`."""
    var file: FileHandle
    var buffer: List[UInt8]
    var capacity: Int

    def __init__(out self, var file: FileHandle, capacity: Int = 65536):
        self.file = file^
        self.capacity = capacity
        self.buffer = List[UInt8](capacity=max(capacity, 0))

    def _drain(mut self) raises:
        if len(self.buffer) > 0:
            self.file.write_bytes(Span(self.buffer))
            self.buffer.clear()

    def write(mut self, bytes: Span[UInt8, _]) raises:
        if len(self.buffer) + len(bytes) > self.capacity:
            self._drain()
            if len(bytes) >= self.capacity:
                self.file.write_bytes(bytes)
                return
        self.buffer.extend(bytes)

    def flush(mut self) raises:
        """Write the buffered bytes to the file (still no fsync)."""
        self._drain()

    def close(mut self) raises:
        self._drain()
        self.file.close()
