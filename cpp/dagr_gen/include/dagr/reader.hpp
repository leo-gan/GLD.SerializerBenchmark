// dagr/reader.hpp — the hand-written Dagr wire runtime for the C++ target, read side
// (spec/41-cpp-codegen-plan.md §4.2 core tier, §5, §8). Generated accessors
// (dagr/codegen/cpp/) call into this header; nothing here is schema-specific.
//
// Reader model: a borrowed byte range plus position-passing free functions, mirroring the
// Swift / Rust / Go runtimes one to one.
//
// THE CONTRACT (spec/41 §5): every function here is TOTAL. For any byte string and any
// position it returns without reading outside [data, data + size). What it returns for
// malformed input is unspecified but safe — a zero, an empty range, `npos`, a zero length.
// Three rules make that hold, and generated code relies on all three:
//
//   1. A dereference takes an ABSOLUTE position and is checked against the buffer at that
//      position. Position arithmetic is unsigned and may wrap: a wrapped position fails
//      the check like any other out-of-range one.
//   2. A length or count read from the buffer is clamped against the bytes that remain
//      WHERE IT IS RECORDED, so a caller iterating `count` elements is bounded by the
//      buffer, not by a hostile varint.
//   3. A varint read that fails reports length 0. A loop over the data must stop on it.
//
// Core tier: no allocation, no exceptions, no RTTI, no containers.
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <optional>
#include <string_view>
#include <type_traits>

#if __cplusplus >= 202002L && __has_include(<span>)
#include <span>
#endif

namespace dagr {

// ── Span ───────────────────────────────────────────────────────────────────────

/// A pointer + length view — the one range vocabulary type of the generated API, so a
/// signature does not change type with `-std` (spec/41 §4.1). Converts to and from
/// `std::span` where that exists.
template <class T>
class Span {
 public:
  using element_type = T;
  using value_type = std::remove_cv_t<T>;
  using iterator = T*;

  constexpr Span() noexcept = default;
  constexpr Span(T* data, std::size_t size) noexcept : data_(data), size_(size) {}
  template <std::size_t N>
  constexpr Span(T (&arr)[N]) noexcept : data_(arr), size_(N) {}  // NOLINT(google-explicit-constructor)

  /// From any contiguous container exposing data()/size() (std::vector, std::array,
  /// std::string, another Span of a compatible element type).
  template <class C, class = std::enable_if_t<
                         !std::is_array<std::remove_reference_t<C>>::value &&
                         std::is_convertible<decltype(std::declval<C&>().data()), T*>::value &&
                         std::is_convertible<decltype(std::declval<C&>().size()), std::size_t>::value>>
  constexpr Span(C& c) noexcept  // NOLINT(google-explicit-constructor)
      : data_(c.data()), size_(static_cast<std::size_t>(c.size())) {}

#if __cplusplus >= 202002L && __has_include(<span>)
  constexpr operator std::span<T>() const noexcept { return std::span<T>(data_, size_); }  // NOLINT
#endif

  constexpr T* data() const noexcept { return data_; }
  constexpr std::size_t size() const noexcept { return size_; }
  constexpr bool empty() const noexcept { return size_ == 0; }
  constexpr T* begin() const noexcept { return data_; }
  constexpr T* end() const noexcept { return data_ + size_; }
  /// Unchecked, like every standard view: the index is the caller's claim.
  constexpr T& operator[](std::size_t i) const noexcept { return data_[i]; }

 private:
  T* data_ = nullptr;
  std::size_t size_ = 0;
};

/// The borrowed buffer every reader function takes.
using Bytes = Span<const std::uint8_t>;

/// "No position": fails every bounds check, so reading through it yields zeros.
inline constexpr std::size_t npos = static_cast<std::size_t>(-1);

/// True when [at, at + len) lies inside the buffer. Written so that neither a wrapped
/// `at` nor a huge `len` can pass.
constexpr bool in_bounds(Bytes b, std::size_t at, std::size_t len) noexcept {
  return at <= b.size() && len <= b.size() - at;
}

/// Bytes left from `at` to the end of the buffer (0 when `at` is out of range).
constexpr std::size_t remaining(Bytes b, std::size_t at) noexcept {
  return at <= b.size() ? b.size() - at : 0;
}

// ── Status / Result ────────────────────────────────────────────────────────────

enum class Status : std::uint8_t {
  ok = 0,
  bad_framing,     // the framing word is malformed or points outside the buffer
  no_header,       // a header was asked for and the framing word carries none (spec 15)
  malformed,       // a validating walk found out-of-range or inconsistent bytes
  buffer_full,     // a fixed-capacity writer or scratch ran out of room
  depth_exceeded,  // a recursive walk over the data hit its depth limit (spec/41 §5)
  invalid_value,   // a value tree holds what the wire cannot express (a union with no variant)
  out_of_memory,   // a growing writer or scratch could not allocate
  rejected,        // an open-time gate refused the stream (spec 34 §4.3)
  wrong_type,      // a DataSink record was asked for as a type it is not
};

/// A value or the reason there is none (`std::expected` is C++23). T is default
/// constructed on failure, so `value()` is always safe to read.
template <class T>
class Result {
 public:
  constexpr Result(T value) noexcept : value_(value), status_(Status::ok) {}  // NOLINT
  constexpr Result(Status status) noexcept : value_(), status_(status) {}     // NOLINT
  constexpr bool ok() const noexcept { return status_ == Status::ok; }
  constexpr explicit operator bool() const noexcept { return ok(); }
  constexpr Status status() const noexcept { return status_; }
  constexpr const T& value() const noexcept { return value_; }
  constexpr const T& operator*() const noexcept { return value_; }
  constexpr const T* operator->() const noexcept { return &value_; }

 private:
  T value_;
  Status status_;
};

// ── Fixed-width native-LE scalars (unaligned) ──────────────────────────────────

namespace detail {

#if defined(__BYTE_ORDER__) && __BYTE_ORDER__ == __ORDER_BIG_ENDIAN__
inline constexpr bool host_little_endian = false;
inline std::uint16_t le(std::uint16_t v) noexcept { return __builtin_bswap16(v); }
inline std::uint32_t le(std::uint32_t v) noexcept { return __builtin_bswap32(v); }
inline std::uint64_t le(std::uint64_t v) noexcept { return __builtin_bswap64(v); }
#else
inline constexpr bool host_little_endian = true;
constexpr std::uint16_t le(std::uint16_t v) noexcept { return v; }
constexpr std::uint32_t le(std::uint32_t v) noexcept { return v; }
constexpr std::uint64_t le(std::uint64_t v) noexcept { return v; }
#endif
constexpr std::uint8_t le(std::uint8_t v) noexcept { return v; }

/// One checked unaligned load. `memcpy` into a local folds to a single instruction and
/// has no alignment or aliasing precondition.
template <class U>
inline U load(Bytes b, std::size_t at) noexcept {
  U v = 0;
  if (in_bounds(b, at, sizeof(U))) {
    std::memcpy(&v, b.data() + at, sizeof(U));
    v = le(v);
  }
  return v;
}

template <class To, class From>
inline To bits(From from) noexcept {
  static_assert(sizeof(To) == sizeof(From), "bit cast between different sizes");
  To to;
  std::memcpy(&to, &from, sizeof(To));
  return to;
}

}  // namespace detail

inline std::uint8_t read_u8(Bytes b, std::size_t at) noexcept { return detail::load<std::uint8_t>(b, at); }
inline std::uint16_t read_u16(Bytes b, std::size_t at) noexcept { return detail::load<std::uint16_t>(b, at); }
inline std::uint32_t read_u32(Bytes b, std::size_t at) noexcept { return detail::load<std::uint32_t>(b, at); }
inline std::uint64_t read_u64(Bytes b, std::size_t at) noexcept { return detail::load<std::uint64_t>(b, at); }
inline std::int8_t read_i8(Bytes b, std::size_t at) noexcept { return static_cast<std::int8_t>(read_u8(b, at)); }
inline std::int16_t read_i16(Bytes b, std::size_t at) noexcept { return static_cast<std::int16_t>(read_u16(b, at)); }
inline std::int32_t read_i32(Bytes b, std::size_t at) noexcept { return static_cast<std::int32_t>(read_u32(b, at)); }
inline std::int64_t read_i64(Bytes b, std::size_t at) noexcept { return static_cast<std::int64_t>(read_u64(b, at)); }
inline float read_f32(Bytes b, std::size_t at) noexcept { return detail::bits<float>(read_u32(b, at)); }
inline double read_f64(Bytes b, std::size_t at) noexcept { return detail::bits<double>(read_u64(b, at)); }
/// Decoded as `byte != 0` — never by reinterpreting a byte as `bool`.
inline bool read_bool(Bytes b, std::size_t at) noexcept { return read_u8(b, at) != 0; }

/// IEEE-754 half bits → float (exact; subnormals normalised). The API type for f16 is
/// `float`: `_Float16` is not portable (spec/41 §8.1).
inline float f16_bits_to_f32(std::uint16_t h) noexcept {
  const std::uint32_t sign = static_cast<std::uint32_t>(h >> 15) << 31;
  const std::uint32_t exp = static_cast<std::uint32_t>(h >> 10) & 0x1fu;
  const std::uint32_t mant = static_cast<std::uint32_t>(h) & 0x3ffu;
  std::uint32_t out;
  if (exp == 0) {
    if (mant == 0) {
      out = sign;
    } else {
      std::uint32_t m = mant;
      std::uint32_t e = 127 - 14;
      while ((m & 0x400u) == 0) {
        m <<= 1;
        e--;
      }
      out = sign | (e << 23) | ((m & 0x3ffu) << 13);
    }
  } else if (exp == 31) {
    out = sign | 0x7f800000u | (mant << 13);
  } else {
    out = sign | ((exp + 112) << 23) | (mant << 13);
  }
  return detail::bits<float>(out);
}

/// bfloat16 bits → float (the high 16 bits of the f32).
inline float bf16_bits_to_f32(std::uint16_t v) noexcept {
  return detail::bits<float>(static_cast<std::uint32_t>(v) << 16);
}

/// A float from its bit pattern held in the low bytes of a wider word — what a union
/// array's slot is (spec 05): the slot is as narrow as the array's largest element allows.
inline float f32_from_bits(std::uint64_t bits) noexcept { return detail::bits<float>(static_cast<std::uint32_t>(bits)); }
inline double f64_from_bits(std::uint64_t bits) noexcept { return detail::bits<double>(bits); }
inline float f16_from_bits(std::uint64_t bits) noexcept { return f16_bits_to_f32(static_cast<std::uint16_t>(bits)); }
inline float bf16_from_bits(std::uint64_t bits) noexcept { return bf16_bits_to_f32(static_cast<std::uint16_t>(bits)); }

inline float read_f16(Bytes b, std::size_t at) noexcept { return f16_bits_to_f32(read_u16(b, at)); }
inline float read_bf16(Bytes b, std::size_t at) noexcept { return bf16_bits_to_f32(read_u16(b, at)); }

/// An unsigned `es`-byte little-endian integer, es ≤ 8 (pointer-table slots).
inline std::uint64_t read_uint_le(Bytes b, std::size_t at, std::size_t es) noexcept {
  std::uint64_t v = 0;
  if (es <= 8 && in_bounds(b, at, es)) {
    for (std::size_t k = 0; k < es; k++) v |= static_cast<std::uint64_t>(b.data()[at + k]) << (8 * k);
  }
  return v;
}

/// A signed (two's-complement) `es`-byte little-endian integer — node-ref array slots may
/// point backward to a shared or cyclic node.
inline std::int64_t read_int_le(Bytes b, std::size_t at, std::size_t es) noexcept {
  std::uint64_t v = read_uint_le(b, at, es);
  const std::size_t nbits = 8 * es;
  if (nbits > 0 && nbits < 64 && (v & (std::uint64_t{1} << (nbits - 1))) != 0) v |= ~std::uint64_t{0} << nbits;
  return static_cast<std::int64_t>(v);
}

/// An `n`-byte little-endian presence / encoding bitset (n ≤ 8).
inline std::uint64_t read_bitset(Bytes b, std::size_t at, std::size_t n) noexcept { return read_uint_le(b, at, n); }

// ── Varints ────────────────────────────────────────────────────────────────────

/// A decoded varint and the bytes it occupied. `len == 0` means the read failed
/// (truncated, out of range, or longer than a u64 allows); `value` is then 0.
struct Varint {
  std::uint64_t value;
  std::size_t len;
};

struct SignedVarint {
  std::int64_t value;
  std::size_t len;
};

namespace detail {
#if defined(__GNUC__) || defined(__clang__)
[[gnu::noinline]]
#endif
inline Varint read_leb_multi(Bytes b, std::size_t at) noexcept {
  std::uint64_t result = 0;
  unsigned shift = 0;
  std::size_t pos = at;
  for (;;) {
    // A u64 needs at most 10 LEB bytes (shift 63); anything longer is malformed input.
    if (pos >= b.size() || shift > 63) return Varint{0, 0};
    const std::uint8_t byte = b.data()[pos];
    result |= static_cast<std::uint64_t>(byte & 0x7fu) << shift;
    pos++;
    shift += 7;
    if ((byte & 0x80u) == 0) break;
  }
  return Varint{result, pos - at};
}
}  // namespace detail

/// Unsigned LEB128 at `at`. The one- and two-byte cases are inline: nearly every varint a
/// packed layout stores is a field tag, an element count or a block size.
inline Varint read_leb(Bytes b, std::size_t at) noexcept {
  if (at < b.size()) {
    const std::uint8_t b0 = b.data()[at];
    if (b0 < 0x80u) return Varint{b0, 1};
    if (b.size() - at >= 2) {
      const std::uint8_t b1 = b.data()[at + 1];
      if (b1 < 0x80u) return Varint{(b0 & 0x7fu) | (static_cast<std::uint64_t>(b1) << 7), 2};
    }
    return detail::read_leb_multi(b, at);
  }
  return Varint{0, 0};
}

constexpr std::int64_t zigzag_decode(std::uint64_t n) noexcept {
  return static_cast<std::int64_t>(n >> 1) ^ -static_cast<std::int64_t>(n & 1);
}

/// ZigZag-LEB128 signed varint (packed signed ints).
inline SignedVarint read_zigzag_leb(Bytes b, std::size_t at) noexcept {
  const Varint v = read_leb(b, at);
  return SignedVarint{zigzag_decode(v.value), v.len};
}

/// Position just past the varint at `at`, or `npos` when it cannot be read.
inline std::size_t leb_end(Bytes b, std::size_t at) noexcept {
  const Varint v = read_leb(b, at);
  return v.len != 0 ? at + v.len : npos;
}

/// End of a size-prefixed blob `[LEB N][N bytes]` at `at`, or `npos` when the blob does
/// not fit in the buffer.
inline std::size_t skip_blob(Bytes b, std::size_t at) noexcept {
  const Varint n = read_leb(b, at);
  if (n.len == 0) return npos;
  const std::size_t start = at + n.len;
  if (n.value > remaining(b, start)) return npos;
  return start + static_cast<std::size_t>(n.value);
}

// ── V62 pointers ───────────────────────────────────────────────────────────────

/// A V62 pointer: the low 2 bits of the first byte select the width (0→1, 1→2, 2→4,
/// 3→8 bytes); the value is raw >> 2. Unsigned (forward pointers).
inline Varint read_v62(Bytes b, std::size_t at) noexcept {
  if (at >= b.size()) return Varint{0, 0};
  const std::uint8_t first = b.data()[at];
  switch (first & 3u) {
    case 0:
      return Varint{static_cast<std::uint64_t>(first) >> 2, 1};
    case 1:
      return in_bounds(b, at, 2) ? Varint{static_cast<std::uint64_t>(read_u16(b, at)) >> 2, 2} : Varint{0, 0};
    case 2:
      return in_bounds(b, at, 4) ? Varint{static_cast<std::uint64_t>(read_u32(b, at)) >> 2, 4} : Varint{0, 0};
    default:
      return in_bounds(b, at, 8) ? Varint{read_u64(b, at) >> 2, 8} : Varint{0, 0};
  }
}

/// A bidirectional (ZigZag) V62 pointer — node refs, which may point backward.
inline SignedVarint read_zigzag_v62(Bytes b, std::size_t at) noexcept {
  const Varint v = read_v62(b, at);
  return SignedVarint{zigzag_decode(v.value), v.len};
}

/// Byte width of the V62 pointer at `at` (advances a frozen walk); 0 when out of range.
inline std::size_t v62_bytes(Bytes b, std::size_t at) noexcept {
  return at < b.size() ? std::size_t{1} << (b.data()[at] & 3u) : 0;
}

/// The position the V62 forward pointer at `slot` targets, or `npos` when the pointer is
/// unreadable or leaves the buffer.
inline std::size_t fwd_target(Bytes b, std::size_t slot) noexcept {
  const Varint v = read_v62(b, slot);
  if (v.len == 0) return npos;
  const std::size_t from = slot + v.len;
  if (v.value > remaining(b, from)) return npos;
  return from + static_cast<std::size_t>(v.value);
}

/// The position the bidirectional (ZigZag V62) node reference at `slot` targets, or `npos`
/// when the reference is unreadable. A backward reference — a shared or cyclic node — is a
/// negative offset; the sum is modular, so a hostile offset lands on some position that
/// the target accessor's own checked reads then deal with.
inline std::size_t ref_target(Bytes b, std::size_t slot) noexcept {
  const SignedVarint v = read_zigzag_v62(b, slot);
  if (v.len == 0) return npos;
  return slot + v.len + static_cast<std::size_t>(v.value);
}

// ── Length-prefixed utf8 / data ────────────────────────────────────────────────

/// A `[LEB count][bytes]` payload as a zero-copy view plus the total bytes consumed
/// (inline callers advance by it). An unreadable or overlong payload is empty, consumed 0.
struct BytesRead {
  Bytes bytes;
  std::size_t consumed;
};

inline BytesRead read_bytes(Bytes b, std::size_t at) noexcept {
  const Varint n = read_leb(b, at);
  if (n.len == 0) return BytesRead{Bytes(), 0};
  const std::size_t start = at + n.len;
  if (n.value > remaining(b, start)) return BytesRead{Bytes(), 0};
  const std::size_t count = static_cast<std::size_t>(n.value);
  return BytesRead{Bytes(b.data() + start, count), n.len + count};
}

/// utf8 as a view of the buffer's bytes. Not validated as UTF-8 (spec/41 §8.1).
inline std::string_view as_string_view(Bytes bytes) noexcept {
  return std::string_view(reinterpret_cast<const char*>(bytes.data()), bytes.size());
}

// ── Arrays (spec 04) ───────────────────────────────────────────────────────────
//
// Every parser below clamps the element count against the buffer (rule 2): `min_width`
// is the fewest bytes one element can occupy (the element width for fixed-width arrays,
// 1 for self-sizing elements). A count that cannot fit yields an empty array.

struct ArrayRef {
  std::size_t base;   // first element
  std::size_t count;  // elements the buffer can actually hold
};

/// `[LEB count][elements]` at `ps`.
inline ArrayRef array_payload_at(Bytes b, std::size_t ps, std::size_t min_width) noexcept {
  const Varint c = read_leb(b, ps);
  if (c.len == 0) return ArrayRef{npos, 0};
  const std::size_t base = ps + c.len;
  const std::size_t w = min_width == 0 ? 1 : min_width;
  if (c.value > remaining(b, base) / w) return ArrayRef{npos, 0};
  return ArrayRef{base, static_cast<std::size_t>(c.value)};
}

/// A regular-node array slot (a V62 forward pointer) resolved to its payload.
inline ArrayRef array_payload(Bytes b, std::size_t slot, std::size_t min_width) noexcept {
  return array_payload_at(b, fwd_target(b, slot), min_width);
}

/// A bit-packed array `[LEB count][ceil(count/8) bytes]` at `ps` (bool arrays, sub-byte
/// enums pass their own bits per element).
inline ArrayRef bit_array_payload_at(Bytes b, std::size_t ps, std::size_t bits_per_elem) noexcept {
  const Varint c = read_leb(b, ps);
  if (c.len == 0) return ArrayRef{npos, 0};
  const std::size_t base = ps + c.len;
  const std::size_t bpe = bits_per_elem == 0 ? 1 : bits_per_elem;
  const std::size_t rem = remaining(b, base);
  // count * bpe bits must fit in rem bytes; compare without multiplying the hostile count.
  if (c.value / 8 > rem / bpe) return ArrayRef{npos, 0};
  const std::size_t count = static_cast<std::size_t>(c.value);
  if ((count * bpe + 7) / 8 > rem) return ArrayRef{npos, 0};
  return ArrayRef{base, count};
}

/// A pointer-table payload `[LEB (count<<2)|wc][count×es slots][data]`. Element i lives
/// at data_base + slot[i] - 1 (slot 0 = nil).
struct PtrTable {
  std::size_t table_base;
  std::size_t data_base;
  std::size_t count;
  std::size_t es;  // slot width in bytes: 1, 2, 4 or 8
};

inline PtrTable ptr_table_at(Bytes b, std::size_t ps) noexcept {
  const Varint hdr = read_leb(b, ps);
  if (hdr.len == 0) return PtrTable{npos, npos, 0, 1};
  const std::size_t es = std::size_t{1} << (hdr.value & 3u);
  const std::size_t table_base = ps + hdr.len;
  const std::uint64_t count = hdr.value >> 2;
  if (count > remaining(b, table_base) / es) return PtrTable{npos, npos, 0, es};
  const std::size_t n = static_cast<std::size_t>(count);
  return PtrTable{table_base, table_base + n * es, n, es};
}

inline PtrTable ptr_table(Bytes b, std::size_t slot) noexcept { return ptr_table_at(b, fwd_target(b, slot)); }

/// An inline arrayWithOptionals payload `[LEB count][nil bitset][values]`. Uncompacted:
/// value i is indexed by i regardless of nil elements.
struct AwoRef {
  std::size_t nil_base;
  std::size_t value_base;
  std::size_t count;
};

inline AwoRef awo_payload_at(Bytes b, std::size_t ps, std::size_t min_width) noexcept {
  const Varint c = read_leb(b, ps);
  if (c.len == 0) return AwoRef{npos, npos, 0};
  const std::size_t nil_base = ps + c.len;
  const std::size_t rem = remaining(b, nil_base);
  // The nil bitset alone needs ceil(count/8) bytes, so count ≤ 8·rem before any multiply.
  if (c.value / 8 > rem) return AwoRef{npos, npos, 0};
  const std::size_t count = static_cast<std::size_t>(c.value);
  const std::size_t nil_bytes = (count + 7) / 8;
  if (nil_bytes > rem) return AwoRef{npos, npos, 0};
  if (min_width != 0 && count > (rem - nil_bytes) / min_width) return AwoRef{npos, npos, 0};
  return AwoRef{nil_base, nil_base + nil_bytes, count};
}

inline AwoRef awo_payload(Bytes b, std::size_t slot, std::size_t min_width) noexcept {
  return awo_payload_at(b, fwd_target(b, slot), min_width);
}

/// Bit i of a bitset starting at `base` (nil bitsets, bool arrays).
inline bool bit_at(Bytes b, std::size_t base, std::size_t i) noexcept {
  return ((read_u8(b, base + (i >> 3)) >> (i & 7u)) & 1u) != 0;
}

/// `count` native little-endian elements at `base` as a zero-copy span — engaged only on a
/// little-endian host, when the range is in bounds and the address keeps T's alignment
/// (an aligned(N) array is aligned relative to the buffer start, so the buffer itself
/// must be N-aligned). Callers fall back to the per-element loads otherwise.
template <class T>
inline std::optional<Span<const T>> aligned_view(Bytes b, std::size_t base, std::size_t count) noexcept {
  static_assert(std::is_arithmetic<T>::value, "aligned_view is for numeric element types");
  if (count == 0) return Span<const T>();
  if (!detail::host_little_endian) return std::nullopt;
  if (count > remaining(b, base) / sizeof(T)) return std::nullopt;
  const std::uint8_t* p = b.data() + base;
  if (reinterpret_cast<std::uintptr_t>(p) % alignof(T) != 0) return std::nullopt;
  return Span<const T>(reinterpret_cast<const T*>(p), count);
}

/// Copies `count` native little-endian elements at `base` into `out` with one `memcpy`
/// (spec/43). False, copying nothing, on a big-endian host or when the block does not
/// fit the buffer: the caller then reads element by element, which is what iteration
/// yields for the same bytes.
template <class T>
inline bool copy_le(Bytes b, std::size_t base, std::size_t count, T* out) noexcept {
  static_assert(std::is_arithmetic<T>::value, "copy_le is for numeric element types");
  if (count == 0) return true;
  if (!detail::host_little_endian) return false;
  if (count > remaining(b, base) / sizeof(T)) return false;
  std::memcpy(out, b.data() + base, count * sizeof(T));
  return true;
}

// ── Packed nodes (spec 07) ─────────────────────────────────────────────────────

/// The entries of the packed block whose length LEB is at `start`. A block that does not
/// fit in the buffer is empty — every field of it reads as absent.
struct Block {
  std::size_t begin;
  std::size_t end;
};

inline Block packed_bounds(Bytes b, std::size_t start) noexcept {
  const Varint s = read_leb(b, start);
  if (s.len == 0) return Block{npos, npos};
  const std::size_t begin = start + s.len;
  if (s.value > remaining(b, begin)) return Block{begin, begin};
  return Block{begin, begin + static_cast<std::size_t>(s.value)};
}

struct F32Read {
  float value;
  std::size_t len;
};
struct F64Read {
  double value;
  std::size_t len;
};

/// A self-describing packed float (sub-tag byte): 00 +0 · 01 -0 · 02 +inf · 03 -inf ·
/// 04 NaN · 05 zigzag-LEB int · 06 f16 bits · 07 f32 raw. len 0 when out of range.
inline F32Read decode_packed_f32(Bytes b, std::size_t at) noexcept {
  if (at >= b.size()) return F32Read{0.0f, 0};
  switch (b.data()[at]) {
    case 0: return F32Read{0.0f, 1};
    case 1: return F32Read{detail::bits<float>(std::uint32_t{0x80000000u}), 1};
    case 2: return F32Read{detail::bits<float>(std::uint32_t{0x7F800000u}), 1};
    case 3: return F32Read{detail::bits<float>(std::uint32_t{0xFF800000u}), 1};
    case 4: return F32Read{detail::bits<float>(std::uint32_t{0x7FC00000u}), 1};
    case 5: {
      const SignedVarint v = read_zigzag_leb(b, at + 1);
      return v.len != 0 ? F32Read{static_cast<float>(v.value), 1 + v.len} : F32Read{0.0f, 0};
    }
    case 6: return in_bounds(b, at + 1, 2) ? F32Read{read_f16(b, at + 1), 3} : F32Read{0.0f, 0};
    default: return in_bounds(b, at + 1, 4) ? F32Read{read_f32(b, at + 1), 5} : F32Read{0.0f, 0};
  }
}

/// The f64 form of decode_packed_f32 (adds 08 f64 raw).
inline F64Read decode_packed_f64(Bytes b, std::size_t at) noexcept {
  if (at >= b.size()) return F64Read{0.0, 0};
  switch (b.data()[at]) {
    case 0: return F64Read{0.0, 1};
    case 1: return F64Read{detail::bits<double>(std::uint64_t{0x8000000000000000u}), 1};
    case 2: return F64Read{detail::bits<double>(std::uint64_t{0x7FF0000000000000u}), 1};
    case 3: return F64Read{detail::bits<double>(std::uint64_t{0xFFF0000000000000u}), 1};
    case 4: return F64Read{detail::bits<double>(std::uint64_t{0x7FF8000000000000u}), 1};
    case 5: {
      const SignedVarint v = read_zigzag_leb(b, at + 1);
      return v.len != 0 ? F64Read{static_cast<double>(v.value), 1 + v.len} : F64Read{0.0, 0};
    }
    case 6: return in_bounds(b, at + 1, 2) ? F64Read{static_cast<double>(read_f16(b, at + 1)), 3} : F64Read{0.0, 0};
    case 7: return in_bounds(b, at + 1, 4) ? F64Read{static_cast<double>(read_f32(b, at + 1)), 5} : F64Read{0.0, 0};
    default: return in_bounds(b, at + 1, 8) ? F64Read{read_f64(b, at + 1), 9} : F64Read{0.0, 0};
  }
}

/// The encoded (special-value, 1-byte) form of a packed f16 / bf16; a non-special value is
/// stored raw and handled by the caller.
inline F32Read decode_packed_f16(Bytes b, std::size_t at) noexcept {
  if (at >= b.size()) return F32Read{0.0f, 0};
  switch (b.data()[at]) {
    case 1: return F32Read{detail::bits<float>(std::uint32_t{0x80000000u}), 1};
    case 2: return F32Read{detail::bits<float>(std::uint32_t{0x7F800000u}), 1};
    case 3: return F32Read{detail::bits<float>(std::uint32_t{0xFF800000u}), 1};
    case 4: return F32Read{detail::bits<float>(std::uint32_t{0x7FC00000u}), 1};
    default: return F32Read{0.0f, 1};
  }
}

inline F32Read decode_packed_bf16(Bytes b, std::size_t at) noexcept { return decode_packed_f16(b, at); }

/// `[LEB (typeId<<3)|code]` at `at`. code: 0 LEB · 1/2/3/4 = 1/2/4/8 raw bytes ·
/// 5 packed float · 6 len-prefixed block. `payload == npos` when unreadable.
struct PackedUnionHeader {
  std::size_t payload;
  std::uint8_t tag;
  std::uint8_t code;
};

inline PackedUnionHeader packed_union_header(Bytes b, std::size_t at) noexcept {
  const Varint r = read_leb(b, at);
  if (r.len == 0) return PackedUnionHeader{npos, 0, 0};
  return PackedUnionHeader{at + r.len, static_cast<std::uint8_t>((r.value >> 3) & 0xffu),
                           static_cast<std::uint8_t>(r.value & 7u)};
}

/// Byte size of a packed-union payload after its header; 0 when it cannot be sized
/// (a scan must stop on 0 — rule 3).
inline std::size_t packed_union_payload_bytes(Bytes b, std::size_t ep, unsigned code) noexcept {
  switch (code) {
    case 0: return read_leb(b, ep).len;
    case 1: return 1;
    case 2: return 2;
    case 3: return 4;
    case 4: return 8;
    case 5: return decode_packed_f64(b, ep).len;
    default: {
      const std::size_t end = skip_blob(b, ep);
      return end != npos ? end - ep : 0;
    }
  }
}

// ── Unions (spec 05) ───────────────────────────────────────────────────────────

/// A union field slot header `[LEB (tag<<2)|wc]` at `pos`. `payload == npos` when
/// unreadable.
struct UnionHeader {
  std::size_t payload;
  std::uint8_t tag;
};

inline UnionHeader union_header(Bytes b, std::size_t pos) noexcept {
  const Varint r = read_leb(b, pos);
  if (r.len == 0) return UnionHeader{npos, 0};
  return UnionHeader{pos + r.len, static_cast<std::uint8_t>(r.value >> 2)};
}

/// Total size of a union field slot `[LEB (tag<<2)|wc][1<<wc]` (advances a frozen walk);
/// 0 when unreadable.
inline std::size_t union_slot_bytes(Bytes b, std::size_t at) noexcept {
  const Varint r = read_leb(b, at);
  return r.len != 0 ? r.len + (std::size_t{1} << (r.value & 3u)) : 0;
}

/// The layout of a union array of a regular or frozen node (spec 05):
/// `[LEB (count << 2) | wc][type ids][nil bitset?][count slots of 1 << wc bytes][payloads]`.
/// Type ids are `tag_bits` wide each (1, 2 or 4 bits packed low-first, or whole bytes).
/// The nil bitset exists only for the arrayWithOptionals form.
struct UnionArrayRef {
  std::size_t tid_start = npos;
  std::size_t nil_start = npos;   // npos: every element present
  std::size_t slot_start = npos;
  std::size_t base = npos;        // payload offsets in the slots are relative to this
  std::size_t count = 0;
  std::size_t es = 1;             // slot width in bytes
};

/// Parses the union array whose header is at `arr`. The count is clamped: type ids, the
/// nil bitset and the slots must all fit in the buffer, or the array is empty.
inline UnionArrayRef union_array_at(Bytes b, std::size_t arr, unsigned tag_bits, bool optionals) noexcept {
  UnionArrayRef out;
  const Varint h = read_leb(b, arr);
  if (h.len == 0) return out;
  const std::size_t es = std::size_t{1} << (h.value & 3u);
  const std::size_t tid_start = arr + h.len;
  const std::size_t rem = remaining(b, tid_start);
  const std::uint64_t count64 = h.value >> 2;
  if (count64 > rem) return out;                  // bounds the count before anything multiplies it
  const std::size_t count = static_cast<std::size_t>(count64);
  const std::size_t tid_bytes = tag_bits < 8 ? (count * tag_bits + 7) / 8 : count * (tag_bits / 8);
  const std::size_t nil_bytes = optionals ? (count + 7) / 8 : 0;
  if (tid_bytes > rem || nil_bytes > rem - tid_bytes || count * es > rem - tid_bytes - nil_bytes) return out;
  out.tid_start = tid_start;
  out.nil_start = optionals ? tid_start + tid_bytes : npos;
  out.slot_start = tid_start + tid_bytes + nil_bytes;
  out.base = out.slot_start + count * es;
  out.count = count;
  out.es = es;
  return out;
}

/// The type id of element i of a union array.
inline std::uint32_t union_array_tag(Bytes b, const UnionArrayRef& a, std::size_t i, unsigned tag_bits) noexcept {
  if (tag_bits < 8) {
    const std::size_t bit = i * tag_bits;
    return (static_cast<std::uint32_t>(read_u8(b, a.tid_start + (bit >> 3))) >> (bit & 7u)) & ((1u << tag_bits) - 1u);
  }
  return static_cast<std::uint32_t>(read_uint_le(b, a.tid_start + i * (tag_bits / 8), tag_bits / 8));
}

// ── Raw embedded graphs (spec 18) ──────────────────────────────────────────────

/// Absolute root position inside a raw-embedded graph entry
/// `[LEB payloadLen][pad?][standalone blob]` at `pos`; `npos` when unreadable.
inline std::size_t raw_embedded_root(Bytes b, std::size_t pos, bool has_pad) noexcept {
  const Varint pl = read_leb(b, pos);
  if (pl.len == 0) return npos;
  const std::size_t bs = pos + pl.len + (has_pad ? 1u : 0u);
  const Varint fr = read_leb(b, bs);
  if (fr.len == 0) return npos;
  const std::size_t from = bs + fr.len;
  const std::uint64_t off = fr.value >> 2;
  if (off >= remaining(b, from)) return npos;
  return from + static_cast<std::size_t>(off);
}

// ── Framing + vtables (spec 06) ────────────────────────────────────────────────

/// The absolute root-node position from the framing word. With a header (bit 0) the
/// stored offset already spans it (spec 15 §4), so the expression is the same either way.
inline Result<std::size_t> root_offset(Bytes b) noexcept {
  const Varint framing = read_leb(b, 0);
  if (framing.len == 0 || (framing.value & 2u) != 0) return Status::bad_framing;
  const std::uint64_t off = framing.value >> 2;
  if (off >= remaining(b, framing.len)) return Status::bad_framing;
  return framing.len + static_cast<std::size_t>(off);
}

/// The framing of a DataGraph buffer that carries a spec-15 header: where the header
/// starts (right after the framing word), its total span (size LEB + content), and the
/// header-free root offset the producer signed over (stored − span).
struct HeaderFrame {
  std::size_t start = 0;
  std::size_t span = 0;
  std::size_t root_offset = 0;
};

inline Result<HeaderFrame> header_frame(Bytes b) noexcept {
  const Varint framing = read_leb(b, 0);
  if (framing.len == 0 || (framing.value & 2u) != 0) return Status::bad_framing;
  if ((framing.value & 1u) == 0) return Status::no_header;
  const Varint hcs = read_leb(b, framing.len);
  if (hcs.len == 0 || hcs.value > remaining(b, framing.len + hcs.len)) return Status::bad_framing;
  const std::size_t span = hcs.len + static_cast<std::size_t>(hcs.value);
  const std::uint64_t stored = framing.value >> 2;
  if (stored < span) return Status::bad_framing;
  return HeaderFrame{framing.len, span, static_cast<std::size_t>(stored) - span};
}

/// Whether a DataGraph buffer's framing word carries a header.
inline bool has_header(Bytes b) noexcept {
  const Varint framing = read_leb(b, 0);
  return framing.len != 0 && (framing.value & 1u) == 1;
}

/// Absolute position of vtable field `idx` of the regular node at `start`, or `npos` when
/// the field is absent or the vtable unreadable — without materialising the table.
/// The node-start LEB is ZigZag: even = dedup forward reference (+its own width,
/// off-by-one), odd = fresh vtable. Header LEB = (fieldCount << 1) | wide.
///
/// Forced inline: this is the body of every regular-node getter, and Clang otherwise
/// leaves it a call (measured 1.71 → 1.22 ns per getter, spec/41 §17). Inlined, the
/// compiler also shares the vtable header parse between getters of the same node.
#if defined(__GNUC__) || defined(__clang__)
[[gnu::always_inline]]
#endif
inline std::size_t field_pos(Bytes b, std::size_t start, std::size_t idx) noexcept {
  const Varint ov = read_leb(b, start);
  if (ov.len == 0) return npos;
  const std::size_t adj = (ov.value & 1u) == 0 ? ov.len : 0;
  // A hostile offset wraps; the vtable read below is checked at whatever it lands on.
  const std::size_t vt = start + static_cast<std::size_t>(zigzag_decode(ov.value)) + adj;
  const Varint vs = read_leb(b, vt);
  if (vs.len == 0 || idx >= (vs.value >> 1)) return npos;
  const std::size_t v = (vs.value & 1u) != 0 ? std::size_t{read_u16(b, vt + vs.len + idx * 2)}
                                             : std::size_t{read_u8(b, vt + vs.len + idx)};
  if (v == 0) return npos;
  return start + v - 1 + ov.len;
}

// ── Arena handle packing (spec 09) ─────────────────────────────────────────────

/// Selects the 40-bit index of a packed handle.
inline constexpr std::uint64_t idx_mask = 0xFFFFFFFFFFull;

/// A generational handle `generation << 40 | index`.
constexpr std::uint64_t pack_handle(std::uint32_t gen, std::uint64_t idx) noexcept {
  return (static_cast<std::uint64_t>(gen) << 40) | (idx & idx_mask);
}
constexpr std::uint64_t handle_index(std::uint64_t h) noexcept { return h & idx_mask; }
constexpr std::uint32_t handle_generation(std::uint64_t h) noexcept { return static_cast<std::uint32_t>(h >> 40); }

/// FNV-1a (structural hashing, spec/41 §8.9).
inline std::uint64_t fnv1a(Bytes data) noexcept {
  std::uint64_t h = 0xcbf29ce484222325ull;
  for (const std::uint8_t byte : data) h = (h ^ byte) * 0x100000001b3ull;
  return h;
}

}  // namespace dagr
