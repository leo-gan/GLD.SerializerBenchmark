// dagr/fixed_writer.hpp — the hand-written Dagr wire runtime for the C++ target, write side,
// packed subset (spec/41-cpp-codegen-plan.md §4.2 core tier, §8.5). Generated direct
// builders (dagr/codegen/cpp/direct.py) call into this header; nothing here is
// schema-specific.
//
// Writer model: ONE buffer filled from its END toward its start — the Swift / Rust / Go
// lineage. A parent is stored after its children, so a block's length is known when its
// prefix is written and nothing is ever patched. "Store X then store Y" therefore puts Y
// BEFORE X in the finished bytes; each function's comment gives the forward layout.
//
// Every store is a template over the BUILDER, which is any type with
//
//   std::uint8_t* claim(std::size_t n) noexcept;   // n writable bytes just below the data
//                                                  // written so far, or nullptr
//   std::size_t   cursor() const noexcept;         // bytes written so far
//   void          fail(Status) noexcept;           // make every later claim fail
//   std::size_t   alignment_offset() const noexcept;   // bytes that will precede the
//                                                  // finished buffer in its envelope (spec 12 §14)
//
// `FixedBuilder` (below, no allocation) and `Builder` (dagr/writer.hpp, growing) are the
// two in the runtime, and the generated stores are the same code over both — so
// `fixed == growing` is a real differential.
//
// FAILURE IS STICKY, NOT THREADED. A claim that cannot be served returns nullptr, the
// store writes nothing, and every later claim fails too; the caller checks `status()` once,
// at the end. No store returns an error and no generated call site tests one.
//
// Core tier: no allocation, no exceptions, no RTTI, no containers.
#pragma once

#include "reader.hpp"

namespace dagr {

// ── Encoding arithmetic ────────────────────────────────────────────────────────

/// LEB128 byte length of `v` (0 → 1).
constexpr std::size_t leb_length(std::uint64_t v) noexcept {
  return v == 0 ? 1 : (static_cast<std::size_t>(64 - __builtin_clzll(v)) + 6) / 7;
}

constexpr std::uint64_t zigzag_encode(std::int64_t v) noexcept {
  return (static_cast<std::uint64_t>(v) << 1) ^ static_cast<std::uint64_t>(v >> 63);
}

/// float → bfloat16 bits: round-to-nearest-even on the top 16 bits.
inline std::uint16_t f32_to_bf16_bits(float v) noexcept {
  const std::uint32_t b = detail::bits<std::uint32_t>(v);
  const std::uint32_t lsb = (b >> 16) & 1u;
  return static_cast<std::uint16_t>((b + 0x7fffu + lsb) >> 16);
}

/// float → IEEE-754 half bits: round-to-nearest-even, subnormals, overflow to infinity.
inline std::uint16_t f32_to_f16_bits(float v) noexcept {
  if (v != v) return 0x7e00u;
  const std::uint32_t b = detail::bits<std::uint32_t>(v);
  const std::uint32_t sign = (b >> 16) & 0x8000u;
  const int exp32 = static_cast<int>((b >> 23) & 0xffu);
  const std::uint32_t mant32 = b & 0x7fffffu;
  if (exp32 == 0xff) return static_cast<std::uint16_t>(sign | 0x7c00u);
  if ((b & 0x7fffffffu) == 0) return static_cast<std::uint16_t>(sign);
  const int exp16 = exp32 - 127 + 15;
  if (exp16 >= 0x1f) return static_cast<std::uint16_t>(sign | 0x7c00u);
  if (exp16 <= 0) {
    if (exp16 < -10) return static_cast<std::uint16_t>(sign);
    const std::uint32_t m = mant32 | 0x800000u;
    const unsigned shift = static_cast<unsigned>(14 - exp16);
    const std::uint32_t low = m & ((std::uint32_t{1} << shift) - 1u);
    const std::uint32_t half = std::uint32_t{1} << (shift - 1);
    std::uint32_t r = m >> shift;
    if (low > half || (low == half && (r & 1u) == 1u)) r++;
    return static_cast<std::uint16_t>(sign | r);
  }
  std::uint32_t half16 = (static_cast<std::uint32_t>(exp16) << 10) | (mant32 >> 13);
  const std::uint32_t round = (mant32 >> 12) & 1u;
  const bool sticky = (mant32 & 0xfffu) != 0;
  if (round == 1u && (sticky || (half16 & 1u) == 1u)) half16++;
  return static_cast<std::uint16_t>(sign | half16);
}

/// The half bits of `v` when `v` is a NORMAL half exactly (what the packed float codec's
/// tag 0x06 stores), and whether it is.
struct ExactHalf {
  std::uint16_t bits;
  bool exact;
};

inline ExactHalf f32_to_f16_bits_exact(float v) noexcept {
  const std::uint32_t b = detail::bits<std::uint32_t>(v);
  const std::uint32_t sign = b >> 31;
  const std::uint32_t exp32 = (b >> 23) & 0xffu;
  const std::uint32_t mant32 = b & 0x7fffffu;
  if (exp32 == 0xffu) return ExactHalf{0, false};
  if (exp32 == 0) return mant32 == 0 ? ExactHalf{static_cast<std::uint16_t>(sign << 15), true} : ExactHalf{0, false};
  const int exp16 = static_cast<int>(exp32) - 112;
  if (exp16 < 1 || exp16 > 30) return ExactHalf{0, false};
  if ((mant32 & 0x1fffu) != 0) return ExactHalf{0, false};
  return ExactHalf{static_cast<std::uint16_t>((sign << 15) | (static_cast<std::uint32_t>(exp16) << 10) | (mant32 >> 13)),
                   true};
}

namespace detail {

/// Writes the LEB128 of `v` forward at `p` (room for leb_length(v) bytes); returns its length.
inline std::size_t put_leb(std::uint8_t* p, std::uint64_t v) noexcept {
  std::size_t n = 0;
  while (v >= 0x80u) {
    p[n++] = static_cast<std::uint8_t>((v & 0x7fu) | 0x80u);
    v >>= 7;
  }
  p[n++] = static_cast<std::uint8_t>(v);
  return n;
}

/// One unaligned little-endian store of an unsigned integer.
template <class U>
inline void put_le(std::uint8_t* p, U v) noexcept {
  v = le(v);
  std::memcpy(p, &v, sizeof(U));
}

/// What the LEB form of a packed integer encodes: the value, or its ZigZag when signed.
template <class T>
constexpr std::uint64_t leb_form(T v) noexcept {
  if constexpr (std::is_signed<T>::value) {
    return zigzag_encode(static_cast<std::int64_t>(v));
  } else {
    return static_cast<std::uint64_t>(v);
  }
}

template <class T>
constexpr std::make_unsigned_t<T> fixed_form(T v) noexcept {
  return static_cast<std::make_unsigned_t<T>>(v);
}

inline void set_bit(std::uint8_t* bits, std::size_t i) noexcept {
  bits[i >> 3] = static_cast<std::uint8_t>(bits[i >> 3] | (1u << (i & 7u)));
}

}  // namespace detail

// ── FixedBuilder ───────────────────────────────────────────────────────────────

/// A writer over caller-provided storage: no allocation, `Status::buffer_full` when the
/// record does not fit. The record ends up at the END of the storage; `bytes()` is it.
class FixedBuilder {
 public:
  constexpr FixedBuilder() noexcept = default;
  constexpr FixedBuilder(std::uint8_t* storage, std::size_t capacity) noexcept : data_(storage), cap_(capacity) {}
  constexpr explicit FixedBuilder(Span<std::uint8_t> storage) noexcept : data_(storage.data()), cap_(storage.size()) {}

  /// `n` writable bytes immediately below what is stored so far, or nullptr — and then
  /// every later claim fails as well.
  std::uint8_t* claim(std::size_t n) noexcept {
    if (n > cap_ - cursor_) {
      fail(Status::buffer_full);
      return nullptr;
    }
    cursor_ += n;
    return data_ + (cap_ - cursor_);
  }

  constexpr std::size_t cursor() const noexcept { return cursor_; }
  constexpr std::size_t capacity() const noexcept { return cap_; }
  constexpr Status status() const noexcept { return status_; }
  constexpr bool ok() const noexcept { return status_ == Status::ok; }

  /// The number of bytes that will precede the finished buffer in whatever carries it
  /// (spec 12 §14): finish padding then aligns `offset + length`, so that aligned arrays
  /// land on their boundary in the ENVELOPE's frame. Configuration — `reset()` keeps it.
  void set_alignment_offset(std::size_t offset) noexcept { alignment_offset_ = offset; }
  constexpr std::size_t alignment_offset() const noexcept { return alignment_offset_; }

  /// Records the first failure and leaves no room, so that no later claim succeeds.
  void fail(Status status) noexcept {
    if (status_ == Status::ok) status_ = status;
    cursor_ = cap_;
  }

  /// The bytes stored so far; empty once anything has failed.
  Bytes bytes() const noexcept { return ok() ? Bytes(data_ + (cap_ - cursor_), cursor_) : Bytes(); }

  /// The byte stored when the cursor reached `at` — the first byte of what a claim that
  /// left the cursor at `at` returned — with `cursor() - at` more stored bytes after it, or
  /// nullptr when nothing is stored there. The graph writer reads back its dedup keys and
  /// patches late-bound references through it (dagr/graph_writer.hpp).
  std::uint8_t* written(std::size_t at) noexcept {
    return ok() && at != 0 && at <= cursor_ ? data_ + (cap_ - at) : nullptr;
  }

  /// Rewinds for another record over the same storage.
  void reset() noexcept {
    cursor_ = 0;
    status_ = Status::ok;
  }

  /// Appends `n` bytes AFTER what is stored — the one store that does not grow the record
  /// at its front: a doubly-linked sink's trailing span (spec 11 §11.5), whose value is
  /// the length of what precedes it. What is stored moves down by `n`. Fails like a claim.
  void append_tail(const std::uint8_t* tail, std::size_t n) noexcept {
    if (n == 0 || claim(n) == nullptr) return;
    std::uint8_t* front = data_ + (cap_ - cursor_);
    std::memmove(front, front + n, cursor_ - n);
    std::memcpy(data_ + (cap_ - n), tail, n);
  }

 private:
  std::uint8_t* data_ = nullptr;
  std::size_t cap_ = 0;
  std::size_t cursor_ = 0;
  std::size_t alignment_offset_ = 0;
  Status status_ = Status::ok;
};

// ── Fixed-width scalars, bytes, varints ────────────────────────────────────────

template <class B>
inline void store_u8(B& b, std::uint8_t v) noexcept {
  if (std::uint8_t* p = b.claim(1)) *p = v;
}

/// An unsigned integer, little-endian, in its own width.
template <class B, class U>
inline void store_fixed(B& b, U v) noexcept {
  if (std::uint8_t* p = b.claim(sizeof(U))) detail::put_le(p, v);
}

/// Any integer in its own width (two's complement).
template <class B, class T>
inline void store_int(B& b, T v) noexcept {
  store_fixed(b, detail::fixed_form(v));
}

template <class B>
inline void store_bool(B& b, bool v) noexcept {
  store_u8(b, v ? std::uint8_t{1} : std::uint8_t{0});
}
template <class B>
inline void store_f32(B& b, float v) noexcept {
  store_fixed(b, detail::bits<std::uint32_t>(v));
}
template <class B>
inline void store_f64(B& b, double v) noexcept {
  store_fixed(b, detail::bits<std::uint64_t>(v));
}
template <class B>
inline void store_f16(B& b, float v) noexcept {
  store_fixed(b, f32_to_f16_bits(v));
}
template <class B>
inline void store_bf16(B& b, float v) noexcept {
  store_fixed(b, f32_to_bf16_bits(v));
}

/// Raw bytes, in order.
template <class B>
inline void store_bytes(B& b, Bytes bytes) noexcept {
  if (bytes.empty()) return;
  if (std::uint8_t* p = b.claim(bytes.size())) std::memcpy(p, bytes.data(), bytes.size());
}

template <class B>
inline void store_zeros(B& b, std::size_t n) noexcept {
  if (n == 0) return;
  if (std::uint8_t* p = b.claim(n)) std::memset(p, 0, n);
}

/// Unsigned LEB128. The one- and two-byte cases are written directly: nearly every varint
/// a packed record stores is a field tag, an element count or a block length.
template <class B>
inline void store_leb(B& b, std::uint64_t v) noexcept {
  if (v < 0x80u) {
    if (std::uint8_t* p = b.claim(1)) p[0] = static_cast<std::uint8_t>(v);
    return;
  }
  if (v < 0x4000u) {
    if (std::uint8_t* p = b.claim(2)) {
      p[0] = static_cast<std::uint8_t>((v & 0x7fu) | 0x80u);
      p[1] = static_cast<std::uint8_t>(v >> 7);
    }
    return;
  }
  if (std::uint8_t* p = b.claim(leb_length(v))) detail::put_leb(p, v);
}

/// `[LEB length][bytes]` in one claim — utf8 and data payloads.
template <class B>
inline void store_blob(B& b, Bytes bytes) noexcept {
  const std::size_t n = bytes.size();
  const std::size_t ln = leb_length(n);
  if (std::uint8_t* p = b.claim(ln + n)) {
    detail::put_leb(p, n);
    if (n != 0) std::memcpy(p + ln, bytes.data(), n);
  }
}

inline Bytes as_bytes(std::string_view s) noexcept {
  return Bytes(reinterpret_cast<const std::uint8_t*>(s.data()), s.size());
}

template <class B>
inline void store_utf8(B& b, std::string_view s) noexcept {
  store_blob(b, as_bytes(s));
}

// ── Packed scalars (spec 07 §3, §12) ───────────────────────────────────────────
//
// A packed node's field is `[LEB (index << 1) | raw][payload]`. `raw` says the payload is
// in its fixed-width form; otherwise it is the compact one (a varint, or the
// self-describing float codec). The writer picks per value — the compact form only when
// it is strictly smaller — unless the schema marks the field `raw` (spec 39).

/// The payload of a u16..i64 field: a varint when that is shorter than the fixed width,
/// else the fixed width. Returns whether it went raw (the tag bit / encoding-bitset bit).
template <class B, class T>
inline bool store_packed_int(B& b, T v, bool force_raw) noexcept {
  const std::uint64_t lv = detail::leb_form(v);
  if (!force_raw && leb_length(lv) < sizeof(T)) {
    store_leb(b, lv);
    return false;
  }
  store_int(b, v);
  return true;
}

/// `[tag][payload]` of a u16..i64 field in ONE claim: a packed record is mostly these.
template <class B, class T>
inline void store_packed_int_field(B& b, T v, std::uint64_t index, bool force_raw) noexcept {
  const std::uint64_t lv = detail::leb_form(v);
  const std::size_t ll = leb_length(lv);
  if (!force_raw && ll < sizeof(T)) {
    const std::uint64_t tag = index << 1;
    const std::size_t tl = leb_length(tag);
    if (std::uint8_t* p = b.claim(tl + ll)) {
      detail::put_leb(p, tag);
      detail::put_leb(p + tl, lv);
    }
    return;
  }
  const std::uint64_t tag = (index << 1) | 1u;
  const std::size_t tl = leb_length(tag);
  if (std::uint8_t* p = b.claim(tl + sizeof(T))) {
    detail::put_leb(p, tag);
    detail::put_le(p + tl, detail::fixed_form(v));
  }
}

/// `[tag | 1][byte]` — u8, i8, bool and byte-wide enums have one encoding.
template <class B>
inline void store_packed_byte_field(B& b, std::uint8_t v, std::uint64_t index) noexcept {
  const std::uint64_t tag = (index << 1) | 1u;
  const std::size_t tl = leb_length(tag);
  if (std::uint8_t* p = b.claim(tl + 1)) {
    detail::put_leb(p, tag);
    p[tl] = v;
  }
}

/// `[tag | 1][LEB length][bytes]` in one claim — utf8 and data fields.
template <class B>
inline void store_packed_blob_field(B& b, Bytes bytes, std::uint64_t index) noexcept {
  const std::uint64_t tag = (index << 1) | 1u;
  const std::size_t tl = leb_length(tag);
  const std::size_t n = bytes.size();
  const std::size_t ln = leb_length(n);
  if (std::uint8_t* p = b.claim(tl + ln + n)) {
    detail::put_leb(p, tag);
    detail::put_leb(p + tl, n);
    if (n != 0) std::memcpy(p + tl + ln, bytes.data(), n);
  }
}

template <class B>
inline void store_packed_utf8_field(B& b, std::string_view s, std::uint64_t index) noexcept {
  store_packed_blob_field(b, as_bytes(s), index);
}

/// The tag of a field whose payload was just stored.
template <class B>
inline void store_packed_tag(B& b, std::uint64_t index, bool raw) noexcept {
  store_leb(b, (index << 1) | (raw ? 1u : 0u));
}

namespace detail {

/// An encoded packed float: at most `[tag][8 payload bytes]`.
struct PackedFloat {
  std::uint8_t bytes[9];
  std::size_t len;
  bool raw;   // the fixed-width fallback was used
};

inline void put_int_float(PackedFloat& out, std::int64_t iv) noexcept {
  out.bytes[0] = 0x05;
  out.len = 1 + put_leb(out.bytes + 1, zigzag_encode(iv));
}

/// Tag-only encodings of ±0, ±infinity and NaN; false when `v` is none of them.
inline bool put_special_f32(PackedFloat& out, std::uint32_t bits) noexcept {
  std::uint8_t tag;
  if (bits == 0) tag = 0x00;
  else if (bits == 0x80000000u) tag = 0x01;
  else if ((bits & 0x7fffffffu) > 0x7f800000u) tag = 0x04;
  else if (bits == 0x7f800000u) tag = 0x02;
  else if (bits == 0xff800000u) tag = 0x03;
  else return false;
  out.bytes[0] = tag;
  out.len = 1;
  return true;
}

/// spec 07 §12, f32: special → `[tag]`; a small integer → `[05][zigzag LEB ≤ 3]`; an exact
/// half → `[06][2]`; else the 4 raw bytes — behind tag 07 when `elem` (array elements are
/// always self-describing; a field says "raw" in its tag instead).
inline PackedFloat encode_packed_f32(float v, bool elem) noexcept {
  PackedFloat out{};
  const std::uint32_t bits = detail::bits<std::uint32_t>(v);
  if (put_special_f32(out, bits)) return out;
  if (v > -2097152.0f && v < 2097152.0f) {                       // |v| < 2^21: the cast is defined
    const std::int64_t iv = static_cast<std::int64_t>(v);
    if (static_cast<float>(iv) == v && leb_length(zigzag_encode(iv)) <= 3) {
      put_int_float(out, iv);
      return out;
    }
  }
  const ExactHalf h = f32_to_f16_bits_exact(v);
  if (h.exact) {
    out.bytes[0] = 0x06;
    put_le(out.bytes + 1, h.bits);
    out.len = 3;
    return out;
  }
  std::size_t at = 0;
  if (elem) out.bytes[at++] = 0x07;
  put_le(out.bytes + at, bits);
  out.len = at + 4;
  out.raw = true;
  return out;
}

/// spec 07 §12, f64: as f32 with a 7-byte integer, then an exact half (`06`), an exact
/// float (`07`), else the 8 raw bytes (behind tag 08 when `elem`).
inline PackedFloat encode_packed_f64(double v, bool elem) noexcept {
  PackedFloat out{};
  const std::uint64_t bits = detail::bits<std::uint64_t>(v);
  std::uint8_t special = 0xff;
  if (bits == 0) special = 0x00;
  else if (bits == 0x8000000000000000u) special = 0x01;
  else if ((bits & 0x7fffffffffffffffu) > 0x7ff0000000000000u) special = 0x04;
  else if (bits == 0x7ff0000000000000u) special = 0x02;
  else if (bits == 0xfff0000000000000u) special = 0x03;
  if (special != 0xff) {
    out.bytes[0] = special;
    out.len = 1;
    return out;
  }
  if (v > -281474976710656.0 && v < 281474976710656.0) {         // |v| < 2^48
    const std::int64_t iv = static_cast<std::int64_t>(v);
    if (static_cast<double>(iv) == v && leb_length(zigzag_encode(iv)) <= 7) {
      put_int_float(out, iv);
      return out;
    }
  }
  // A double outside float's range does not convert (the conversion is undefined), and is
  // not an exact float either.
  if (v >= -3.4028234663852886e38 && v <= 3.4028234663852886e38) {
    const float f = static_cast<float>(v);
    if (static_cast<double>(f) == v) {
      const ExactHalf h = f32_to_f16_bits_exact(f);
      if (h.exact) {
        out.bytes[0] = 0x06;
        put_le(out.bytes + 1, h.bits);
        out.len = 3;
        return out;
      }
      out.bytes[0] = 0x07;
      put_le(out.bytes + 1, detail::bits<std::uint32_t>(f));
      out.len = 5;
      return out;
    }
  }
  std::size_t at = 0;
  if (elem) out.bytes[at++] = 0x08;
  put_le(out.bytes + at, bits);
  out.len = at + 8;
  out.raw = true;
  return out;
}

/// The tag byte a packed f16 / bf16 stores INSTEAD of its two bytes, or 0xff for none.
inline std::uint8_t half_special(float v) noexcept {
  PackedFloat out{};
  return put_special_f32(out, detail::bits<std::uint32_t>(v)) ? out.bytes[0] : std::uint8_t{0xff};
}

template <class B>
inline bool store_encoded(B& b, const PackedFloat& f) noexcept {
  if (std::uint8_t* p = b.claim(f.len)) std::memcpy(p, f.bytes, f.len);
  return f.raw;
}

}  // namespace detail

/// A packed f32 payload. Returns whether the raw fallback was used.
template <class B>
inline bool store_packed_f32(B& b, float v, bool elem) noexcept {
  return detail::store_encoded(b, detail::encode_packed_f32(v, elem));
}

template <class B>
inline bool store_packed_f64(B& b, double v, bool elem) noexcept {
  return detail::store_encoded(b, detail::encode_packed_f64(v, elem));
}

/// A packed f16 / bf16 SCALAR: a special value as its one tag byte (returns false), else
/// the two raw bytes (returns true).
template <class B>
inline bool store_packed_half(B& b, float v, bool bf16) noexcept {
  const std::uint8_t special = detail::half_special(v);
  if (special != 0xff) {
    store_u8(b, special);
    return false;
  }
  store_fixed(b, bf16 ? f32_to_bf16_bits(v) : f32_to_f16_bits(v));
  return true;
}

// ── Bitsets of a frozen+packed node ────────────────────────────────────────────

/// `N` bytes of presence or encoding bits, bit i in byte i / 8.
template <std::size_t N>
struct BitSet {
  std::uint8_t bytes[N] = {};
  void set(std::size_t i) noexcept { detail::set_bit(bytes, i); }
};

template <class B, std::size_t N>
inline void store_bitset(B& b, const BitSet<N>& bits) noexcept {
  store_bytes(b, Bytes(bits.bytes, N));
}

// ── Packed unions (spec 07 §8) ─────────────────────────────────────────────────
//
// A union value is `[LEB (type id << 3) | code][payload]`. The code says how to SKIP the
// payload: 0 a varint, 1 / 2 / 3 / 4 a fixed 1 / 2 / 4 / 8 bytes, 5 the self-describing
// float codec, 6 a length-prefixed blob. Each store below writes a payload and returns
// its code; its `_code` twin computes the code alone — a union ARRAY writes every payload
// first and the headers afterwards, with nowhere to keep the codes in between.

constexpr std::uint64_t packed_union_header(std::uint64_t type_id, std::uint64_t code) noexcept {
  return (type_id << 3) | code;
}

namespace detail {
constexpr std::uint64_t width_code(std::size_t width) noexcept {
  return width == 1 ? 1u : width == 2 ? 2u : width == 4 ? 3u : 4u;
}
}  // namespace detail

template <class T>
constexpr std::uint64_t packed_union_int_code(T v) noexcept {
  return leb_length(detail::leb_form(v)) < sizeof(T) ? 0u : detail::width_code(sizeof(T));
}

/// A u16..i64 variant: a varint (code 0) when shorter than the fixed width.
template <class B, class T>
inline std::uint64_t store_packed_union_int(B& b, T v) noexcept {
  return store_packed_int(b, v, false) ? detail::width_code(sizeof(T)) : 0u;
}

/// An f32 variant: the float codec (code 5), or its 4 raw bytes (code 3).
inline std::uint64_t packed_union_f32_code(float v) noexcept { return detail::encode_packed_f32(v, false).raw ? 3u : 5u; }
template <class B>
inline std::uint64_t store_packed_union_f32(B& b, float v) noexcept {
  return store_packed_f32(b, v, false) ? 3u : 5u;
}

/// An f64 variant: the float codec (code 5), or its 8 raw bytes (code 4).
inline std::uint64_t packed_union_f64_code(double v) noexcept { return detail::encode_packed_f64(v, false).raw ? 4u : 5u; }
template <class B>
inline std::uint64_t store_packed_union_f64(B& b, double v) noexcept {
  return store_packed_f64(b, v, false) ? 4u : 5u;
}

// An f16 / bf16 variant is ALWAYS its two raw bytes under code 2 (`store_fixed` of the
// half bits), and an enum variant is stored like an enum field — one raw byte under code 1
// for a byte-wide enum, `store_packed_union_int` of its backing integer for a wider one.
// Neither needs a store of its own.

// ── Packed arrays (spec 04 §5, spec 07) ────────────────────────────────────────
//
// Every packed array is `[LEB block length][count word][bitsets][elements]`, the block
// length counting everything after itself. Elements are in index order; an
// arrayWithOptionals stores a nil bitset (bit i set = element i absent) and only the
// PRESENT elements.
//
// Where an array needs a bitset whose contents depend on the elements (nil, encoding),
// the elements are measured first and the whole body is written forward into one exact
// claim: there is no scratch memory to build a bitset in, and an over-claim would make a
// record that fits an exact-size buffer fail.

namespace detail {

template <class B>
inline void finish_block(B& b, std::size_t before, std::uint64_t count_word) noexcept {
  store_leb(b, count_word);
  store_leb(b, b.cursor() - before);
}

/// The nil bitset of `elems`.
template <class B, class T>
inline void store_nil_bits(B& b, Span<const std::optional<T>> elems) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) >> 3;
  if (nb == 0) return;
  if (std::uint8_t* p = b.claim(nb)) {
    std::memset(p, 0, nb);
    for (std::size_t i = 0; i < n; i++) {
      if (!elems[i].has_value()) set_bit(p, i);
    }
  }
}

template <class T>
inline constexpr bool is_byte = sizeof(T) == 1 && std::is_integral<T>::value && !std::is_same<T, bool>::value;

}  // namespace detail

/// `[u16..i64]`: `[(count << 2) | tag][encoding bitset if tag 2][elements]` — tag 0 every
/// element a varint, 1 every element fixed-width, 2 mixed (bit i set = element i fixed).
/// `raw` (spec 39) skips the probe: tag 1.
template <class B, class T>
inline void store_packed_int_array(B& b, Span<const T> elems, bool raw) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  const std::size_t w = sizeof(T);
  std::size_t total = n * w;
  std::size_t raw_count = n;
  if (!raw) {
    total = 0;
    raw_count = 0;
    for (const T v : elems) {
      const std::size_t ll = leb_length(detail::leb_form(v));
      if (ll < w) {
        total += ll;
      } else {
        total += w;
        raw_count++;
      }
    }
  }
  const std::uint64_t tag = raw ? 1u : (raw_count == n && n > 0) ? 1u : raw_count > 0 ? 2u : 0u;
  const std::size_t eb = tag == 2 ? (n + 7) >> 3 : 0;
  if (eb + total != 0) {
    if (std::uint8_t* p = b.claim(eb + total)) {
      if (eb != 0) std::memset(p, 0, eb);
      std::uint8_t* out = p + eb;
      for (std::size_t i = 0; i < n; i++) {
        const T v = elems[i];
        const std::uint64_t lv = detail::leb_form(v);
        if (tag != 1 && leb_length(lv) < w) {
          out += detail::put_leb(out, lv);
        } else {
          detail::put_le(out, detail::fixed_form(v));
          out += w;
          if (eb != 0) detail::set_bit(p, i);
        }
      }
    }
  }
  detail::finish_block(b, before, (static_cast<std::uint64_t>(n) << 2) | tag);
}

/// `[u16?..i64?]`: `[(count << 2) | tag][nil bitset][encoding bitset if tag 2][present
/// elements]`. The encoding bitset is indexed by ELEMENT, like the nil bitset.
template <class B, class T>
inline void store_packed_int_opt_array(B& b, Span<const std::optional<T>> elems, bool raw) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  const std::size_t w = sizeof(T);
  std::size_t total = 0;
  std::size_t raw_count = 0;
  std::size_t present = 0;
  for (const std::optional<T>& e : elems) {
    if (!e.has_value()) continue;
    present++;
    const std::size_t ll = leb_length(detail::leb_form(*e));
    if (!raw && ll < w) {
      total += ll;
    } else {
      total += w;
      raw_count++;
    }
  }
  const std::uint64_t tag = raw ? 1u : (raw_count == present && present > 0) ? 1u : raw_count > 0 ? 2u : 0u;
  const std::size_t nb = (n + 7) >> 3;
  const std::size_t eb = tag == 2 ? nb : 0;
  if (nb + eb + total != 0) {
    if (std::uint8_t* p = b.claim(nb + eb + total)) {
      std::memset(p, 0, nb + eb);
      std::uint8_t* enc = p + nb;
      std::uint8_t* out = enc + eb;
      for (std::size_t i = 0; i < n; i++) {
        if (!elems[i].has_value()) {
          detail::set_bit(p, i);
          continue;
        }
        const T v = *elems[i];
        const std::uint64_t lv = detail::leb_form(v);
        if (tag != 1 && leb_length(lv) < w) {
          out += detail::put_leb(out, lv);
        } else {
          detail::put_le(out, detail::fixed_form(v));
          out += w;
          if (eb != 0) detail::set_bit(enc, i);
        }
      }
    }
  }
  detail::finish_block(b, before, (static_cast<std::uint64_t>(n) << 2) | tag);
}

/// `[u8]` / `[i8]`: `[count][bytes]`.
template <class B, class T>
inline void store_packed_byte_array(B& b, Span<const T> elems) noexcept {
  static_assert(detail::is_byte<T>, "a byte array holds u8 or i8");
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  if (n != 0) {
    if (std::uint8_t* p = b.claim(n)) std::memcpy(p, elems.data(), n);
  }
  detail::finish_block(b, before, n);
}

/// `[u8?]` / `[i8?]`: `[count][nil bitset][present bytes]`.
template <class B, class T>
inline void store_packed_byte_opt_array(B& b, Span<const std::optional<T>> elems) noexcept {
  static_assert(detail::is_byte<T>, "a byte array holds u8 or i8");
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  std::size_t present = 0;
  for (const std::optional<T>& e : elems) present += e.has_value() ? 1u : 0u;
  if (present != 0) {
    if (std::uint8_t* p = b.claim(present)) {
      for (const std::optional<T>& e : elems) {
        if (e.has_value()) *p++ = static_cast<std::uint8_t>(*e);
      }
    }
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, n);
}

/// `[bool]`: `[count][bitset]`. `E` is `bool`, or a byte holding 0 / 1 (an arena's store).
template <class B, class E>
inline void store_packed_bool_array(B& b, Span<const E> elems) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) >> 3;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(nb)) {
      std::memset(p, 0, nb);
      for (std::size_t i = 0; i < n; i++) {
        if (elems[i]) detail::set_bit(p, i);
      }
    }
  }
  detail::finish_block(b, before, n);
}

/// `[bool?]`: `[count][nil bitset][value bits of the present elements, compacted]`.
template <class B, class E>
inline void store_packed_bool_opt_array(B& b, Span<const std::optional<E>> elems) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  std::size_t present = 0;
  for (const std::optional<E>& e : elems) present += e.has_value() ? 1u : 0u;
  const std::size_t vb = (present + 7) >> 3;
  if (vb != 0) {
    if (std::uint8_t* p = b.claim(vb)) {
      std::memset(p, 0, vb);
      std::size_t at = 0;
      for (const std::optional<E>& e : elems) {
        if (!e.has_value()) continue;
        if (*e) detail::set_bit(p, at);
        at++;
      }
    }
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, n);
}

/// `[f16]` / `[bf16]`: `[count][encoding bitset][elements]` — a special value is its one
/// tag byte, anything else its two raw bytes with the encoding bit set.
template <class B>
inline void store_packed_half_array(B& b, Span<const float> elems, bool bf16) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  const std::size_t eb = (n + 7) >> 3;
  std::size_t total = 0;
  for (const float v : elems) total += detail::half_special(v) != 0xff ? 1u : 2u;
  if (eb + total != 0) {
    if (std::uint8_t* p = b.claim(eb + total)) {
      std::memset(p, 0, eb);
      std::uint8_t* out = p + eb;
      for (std::size_t i = 0; i < n; i++) {
        const float v = elems[i];
        const std::uint8_t special = detail::half_special(v);
        if (special != 0xff) {
          *out++ = special;
        } else {
          detail::put_le(out, bf16 ? f32_to_bf16_bits(v) : f32_to_f16_bits(v));
          out += 2;
          detail::set_bit(p, i);
        }
      }
    }
  }
  detail::finish_block(b, before, n);
}

/// `[f16?]` / `[bf16?]`: `[count][nil bitset][two raw bytes per present element]`.
template <class B>
inline void store_packed_half_opt_array(B& b, Span<const std::optional<float>> elems, bool bf16) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) store_fixed(b, bf16 ? f32_to_bf16_bits(*elems[i]) : f32_to_f16_bits(*elems[i]));
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, elems.size());
}

namespace detail {
template <class B>
inline void store_float_elem(B& b, float v, bool raw) noexcept {
  if (raw) store_f32(b, v);
  else store_packed_f32(b, v, true);
}
template <class B>
inline void store_float_elem(B& b, double v, bool raw) noexcept {
  if (raw) store_f64(b, v);
  else store_packed_f64(b, v, true);
}
}  // namespace detail

/// `[f32]` / `[f64]`: `[(count << 2) | mode][elements]` — mode 0 each element in the
/// self-describing float codec, mode 1 (`raw`) native little-endian.
template <class B, class T>
inline void store_packed_float_array(B& b, Span<const T> elems, bool raw) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) detail::store_float_elem(b, elems[i], raw);
  detail::finish_block(b, before, (static_cast<std::uint64_t>(elems.size()) << 2) | (raw ? 1u : 0u));
}

/// `[f32?]` / `[f64?]`: `[(count << 2) | mode][nil bitset][present elements]`.
template <class B, class T>
inline void store_packed_float_opt_array(B& b, Span<const std::optional<T>> elems, bool raw) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) detail::store_float_elem(b, *elems[i], raw);
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, (static_cast<std::uint64_t>(elems.size()) << 2) | (raw ? 1u : 0u));
}

namespace detail {
template <class E>
constexpr std::uint64_t enum_raw(E e) noexcept {
  return static_cast<std::uint64_t>(static_cast<std::underlying_type_t<E>>(e));
}

/// `count` values of `bits_per` bits each, packed low bits first, into `p` (zeroed here).
template <class Next>
inline void put_enum_bits(std::uint8_t* p, std::size_t count, std::size_t bits_per, Next&& next) noexcept {
  const std::size_t per_byte = 8 / bits_per;
  const std::uint64_t mask = (std::uint64_t{1} << bits_per) - 1u;
  std::memset(p, 0, (count * bits_per + 7) / 8);
  for (std::size_t i = 0; i < count; i++) {
    const std::uint64_t v = next() & mask;
    p[i / per_byte] = static_cast<std::uint8_t>(p[i / per_byte] | (v << ((i % per_byte) * bits_per)));
  }
}
}  // namespace detail

/// A sub-byte enum array (1, 2 or 4 bits per element): `[count][packed bits]`.
template <class B, class E>
inline void store_packed_bit_enum_array(B& b, Span<const E> elems, std::size_t bits_per) noexcept {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  const std::size_t nb = (n * bits_per + 7) / 8;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(nb)) {
      std::size_t i = 0;
      detail::put_enum_bits(p, n, bits_per, [&]() noexcept { return detail::enum_raw(elems[i++]); });
    }
  }
  detail::finish_block(b, before, n);
}

/// `[count][nil bitset][packed bits of the present elements]`.
template <class B, class E>
inline void store_packed_bit_enum_opt_array(B& b, Span<const std::optional<E>> elems, std::size_t bits_per) noexcept {
  const std::size_t before = b.cursor();
  std::size_t present = 0;
  for (const std::optional<E>& e : elems) present += e.has_value() ? 1u : 0u;
  const std::size_t nb = (present * bits_per + 7) / 8;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(nb)) {
      std::size_t i = 0;
      detail::put_enum_bits(p, present, bits_per, [&]() noexcept {
        while (!elems[i].has_value()) i++;
        return detail::enum_raw(*elems[i++]);
      });
    }
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, elems.size());
}

/// An enum array of a byte or more per element: `[count][LEB per element]`.
template <class B, class E>
inline void store_packed_leb_enum_array(B& b, Span<const E> elems) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) store_leb(b, detail::enum_raw(elems[i]));
  detail::finish_block(b, before, elems.size());
}

/// `[count][nil bitset][LEB per present element]`.
template <class B, class E>
inline void store_packed_leb_enum_opt_array(B& b, Span<const std::optional<E>> elems) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) store_leb(b, detail::enum_raw(*elems[i]));
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, elems.size());
}

/// An array whose elements size themselves — child nodes, utf8, data: `[count][elements]`.
/// `each(b, element)` stores one element.
template <class B, class T, class Each>
inline void store_packed_array(B& b, Span<const T> elems, Each&& each) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) each(b, elems[i]);
  detail::finish_block(b, before, elems.size());
}

/// `[count][nil bitset][present elements]`.
template <class B, class T, class Each>
inline void store_packed_opt_array(B& b, Span<const std::optional<T>> elems, Each&& each) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) each(b, *elems[i]);
  }
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, elems.size());
}

template <class B>
inline void store_packed_utf8_array(B& b, Span<const std::string_view> elems) noexcept {
  store_packed_array(b, elems, [](B& bb, std::string_view s) noexcept { store_utf8(bb, s); });
}
template <class B>
inline void store_packed_utf8_opt_array(B& b, Span<const std::optional<std::string_view>> elems) noexcept {
  store_packed_opt_array(b, elems, [](B& bb, std::string_view s) noexcept { store_utf8(bb, s); });
}
template <class B>
inline void store_packed_data_array(B& b, Span<const Bytes> elems) noexcept {
  store_packed_array(b, elems, [](B& bb, Bytes d) noexcept { store_blob(bb, d); });
}
template <class B>
inline void store_packed_data_opt_array(B& b, Span<const std::optional<Bytes>> elems) noexcept {
  store_packed_opt_array(b, elems, [](B& bb, Bytes d) noexcept { store_blob(bb, d); });
}

/// `[Union]`: `[count][headers][payloads]`. `payload(b, element)` stores one payload;
/// `header(element)` is its `(type id << 3) | code`, computed without storing.
template <class B, class T, class Payload, class Header>
inline void store_packed_union_array(B& b, Span<const T> elems, Payload&& payload, Header&& header) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) payload(b, elems[i]);
  for (std::size_t i = elems.size(); i-- > 0;) store_leb(b, header(elems[i]));
  detail::finish_block(b, before, elems.size());
}

/// `[Union?]`: `[count][nil bitset][LEB size of the headers][headers][payloads]`, headers
/// and payloads of the present elements only.
template <class B, class T, class Payload, class Header>
inline void store_packed_union_opt_array(B& b, Span<const std::optional<T>> elems, Payload&& payload,
                                         Header&& header) noexcept {
  const std::size_t before = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) payload(b, *elems[i]);
  }
  const std::size_t headers = b.cursor();
  for (std::size_t i = elems.size(); i-- > 0;) {
    if (elems[i].has_value()) store_leb(b, header(*elems[i]));
  }
  store_leb(b, b.cursor() - headers);
  detail::store_nil_bits(b, elems);
  detail::finish_block(b, before, elems.size());
}

// ── Framing ────────────────────────────────────────────────────────────────────

/// The zero bytes that make `alignment offset + finished length` a multiple of `max_n` —
/// the graph's largest `aligned(N)` (spec 12 §4, §14) — given the framing word that
/// follows them. `root` is the cursor right after the root was stored.
///
/// The framing word's own length depends on the pad (it encodes a distance that includes
/// it), hence the search. It runs over `[0, 2 * max_n)`: that range crosses at most one
/// step of the framing length, so one side of the step holds `max_n` consecutive
/// candidates and a pad always exists. (Over `[0, max_n)`, as every writer once searched,
/// the range can straddle the step and hold none — spec 42 §1.) The smallest pad is taken.
template <class B>
inline void store_finish_alignment_padding(B& b, std::size_t root, std::size_t max_n) noexcept {
  for (std::size_t pad = 0; pad < 2 * max_n; pad++) {
    const std::size_t after = b.cursor() + pad;
    const std::size_t framing = leb_length(static_cast<std::uint64_t>(after - root) << 2);
    if ((b.alignment_offset() + after + framing) % max_n == 0) {
      store_zeros(b, pad);
      return;
    }
  }
}

/// Ends a graph buffer whose root was just stored: alignment padding when the graph
/// declares aligned arrays (`max_align` > 1), then the framing word, `LEB(distance to the
/// root << 2)`.
template <class B>
inline void store_graph_framing(B& b, std::size_t max_align) noexcept {
  const std::size_t root = b.cursor();
  if (max_align > 1) store_finish_alignment_padding(b, root, max_align);
  store_leb(b, static_cast<std::uint64_t>(b.cursor() - root) << 2);
}

/// Puts a spec-15 header in front of a BODY already stored (a root and what it reaches,
/// no finish padding, no framing): `header` is the header node's packed block
/// `[LEB content length][fields]` (as `put_{header}` writes it), `root_offset` the
/// header-free distance from the body's start to the root. Then the framing word, which
/// spans the header (`((root_offset + header span) << 2) | 1`, spec 15 §4). When the graph
/// has aligned(N) arrays (`max_n` > 1) the header's content is INFLATED with trailing zeros
/// until the whole buffer is a multiple of `max_n` (spec 15 §6) — a packed reader ignores
/// the tail. A header that is not a readable block fails the builder: `invalid_value`.
template <class B>
inline void store_header_frame(B& b, Bytes header, std::size_t root_offset, std::size_t max_n) noexcept {
  const Varint content = read_leb(header, 0);
  if (content.len == 0 || content.value != header.size() - content.len) {
    b.fail(Status::invalid_value);
    return;
  }
  const Bytes fields(header.data() + content.len, header.size() - content.len);
  const std::size_t body = b.cursor();
  std::size_t q = 0;
  if (max_n > 1) {
    // a solution exists within one step of each LEB's length: 2 · max_n tries suffice twice over
    for (;; q++) {
      const std::size_t c = fields.size() + q;
      const std::size_t span = leb_length(c) + c;
      const std::uint64_t stored = (static_cast<std::uint64_t>(root_offset + span) << 2) | 1u;
      if ((leb_length(stored) + span + body) % max_n == 0 || q > 4 * max_n) break;
    }
  }
  store_zeros(b, q);
  store_bytes(b, fields);
  const std::size_t c = fields.size() + q;
  store_leb(b, c);
  store_leb(b, (static_cast<std::uint64_t>(root_offset + leb_length(c) + c) << 2) | 1u);
}

/// `store_graph_framing` for a root stored at offset `root` (the cursor right after its
/// first byte was stored): a regular root's offset is its vtable marker, which is not the
/// last thing its store wrote.
template <class B>
inline void store_graph_framing_at(B& b, std::size_t root, std::size_t max_align) noexcept {
  if (max_align > 1) store_finish_alignment_padding(b, root, max_align);
  store_leb(b, static_cast<std::uint64_t>(b.cursor() - root) << 2);
}

}  // namespace dagr
