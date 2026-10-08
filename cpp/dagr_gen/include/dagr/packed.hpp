// dagr/packed.hpp — reading the packed layouts (spec 07): the scalar decoders and scan
// steps generated packed accessors call, and the array views they return.
//
// A packed array is a run of SELF-SIZING elements: a varint, a packed float, a length-
// prefixed blob. There is no offset table, so element i can only be reached by walking
// the i elements before it. The ranges here are therefore FORWARD ranges — begin() /
// end(), size(), no operator[] — and a sweep over one is O(n). A caller that wants
// element i writes the loop and sees what it costs (spec/41 §8.2; an `at(i)` that hides an
// O(i) walk made every sweep quadratic in the Go target, spec/38 §10.2).
//
// The packed shapes that DO have a fixed stride — `[u8]`, `[i8]`, `[bool]` and sub-byte
// enum arrays — are laid out exactly like their regular-node twins and use the indexed
// ranges of dagr/arrays.hpp.
//
// Totality (spec/41 §5): `open` clamps the element count against the buffer (every
// element occupies at least one bit), every read is a checked primitive, and a cursor
// that fails to advance parks at `npos`, where every read yields zero. Iteration always
// ends after `size()` steps.
//
// Core tier: no allocation, no exceptions, no RTTI, no containers.
#pragma once

#include <cstddef>
#include <cstdint>
#include <optional>

#include "dagr/arrays.hpp"
#include "dagr/reader.hpp"

namespace dagr {

// ── Packed scalars: a field's payload is a varint or the raw fixed-width form ──
//
// `raw` comes from the field's tag bit (packed nodes), its encoding bit (frozen+packed)
// or a union header's code.

inline std::uint16_t read_packed_u16(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_u16(b, at) : static_cast<std::uint16_t>(read_leb(b, at).value);
}
inline std::uint32_t read_packed_u32(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_u32(b, at) : static_cast<std::uint32_t>(read_leb(b, at).value);
}
inline std::uint64_t read_packed_u64(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_u64(b, at) : read_leb(b, at).value;
}
inline std::int16_t read_packed_i16(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_i16(b, at) : static_cast<std::int16_t>(read_zigzag_leb(b, at).value);
}
inline std::int32_t read_packed_i32(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_i32(b, at) : static_cast<std::int32_t>(read_zigzag_leb(b, at).value);
}
inline std::int64_t read_packed_i64(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_i64(b, at) : read_zigzag_leb(b, at).value;
}
inline float read_packed_f32(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_f32(b, at) : decode_packed_f32(b, at).value;
}
inline double read_packed_f64(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_f64(b, at) : decode_packed_f64(b, at).value;
}
inline float read_packed_f16(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_f16(b, at) : decode_packed_f16(b, at).value;
}
inline float read_packed_bf16(Bytes b, std::size_t at, bool raw) noexcept {
  return raw ? read_bf16(b, at) : decode_packed_bf16(b, at).value;
}

// A packed UNION variant (spec 07 §8) says how its payload is encoded in the header's
// `code`, not in a tag bit: 0 a varint, 1 / 2 / 3 / 4 a fixed 1 / 2 / 4 / 8 bytes. Two kinds
// of variant are decoded by that code alone, whatever their declared width:

/// An unsigned integer variant of any width — a wide enum, which a writer may store in one
/// byte when the value fits one.
inline std::uint64_t read_packed_union_uint(Bytes b, std::size_t at, std::uint32_t code) noexcept {
  switch (code) {
    case 0: return read_leb(b, at).value;
    case 1: return read_u8(b, at);
    case 2: return read_u16(b, at);
    case 3: return read_u32(b, at);
    default: return read_u64(b, at);
  }
}

/// An f16 / bf16 variant: its 16 bits AS AN UNSIGNED INTEGER — a varint when they are below
/// 128 (+0.0 is one zero byte), two raw bytes otherwise. Not the field codec above.
inline float read_packed_union_f16(Bytes b, std::size_t at, std::uint32_t code) noexcept {
  return f16_bits_to_f32(static_cast<std::uint16_t>(read_packed_union_uint(b, at, code == 0 ? 0u : 2u)));
}
inline float read_packed_union_bf16(Bytes b, std::size_t at, std::uint32_t code) noexcept {
  return bf16_bits_to_f32(static_cast<std::uint16_t>(read_packed_union_uint(b, at, code == 0 ? 0u : 2u)));
}

// ── Scan steps: the position just past one field's payload ─────────────────────
//
// A generated constructor walks a packed block once with these. Each returns a position
// strictly greater than `at`, or `npos` when the payload cannot be sized — and `npos` is
// past every block end, so an unsizable payload ends the scan (rule 3).

/// An integer or wide enum: `width` raw bytes, or a varint.
inline std::size_t skip_packed_varint(Bytes b, std::size_t at, bool raw, std::size_t width) noexcept {
  return raw ? at + width : leb_end(b, at);
}
inline std::size_t skip_packed_f32(Bytes b, std::size_t at, bool raw) noexcept {
  if (raw) return at + 4;
  const std::size_t len = decode_packed_f32(b, at).len;
  return len != 0 ? at + len : npos;
}
inline std::size_t skip_packed_f64(Bytes b, std::size_t at, bool raw) noexcept {
  if (raw) return at + 8;
  const std::size_t len = decode_packed_f64(b, at).len;
  return len != 0 ? at + len : npos;
}
/// An f16 / bf16: two raw bytes, or a one-byte special value.
constexpr std::size_t skip_packed_f16(std::size_t at, bool raw) noexcept { return at + (raw ? 2u : 1u); }
/// A union: `[LEB (typeId << 3) | code][payload]`.
inline std::size_t skip_packed_union(Bytes b, std::size_t at) noexcept {
  const PackedUnionHeader h = packed_union_header(b, at);
  const std::size_t len = packed_union_payload_bytes(b, h.payload, h.code);
  // Every code occupies at least one byte, so zero means "could not be sized" — which is
  // also what an unreadable header comes to: its payload position is npos, and nothing
  // can be sized there.
  return len != 0 ? h.payload + len : npos;
}

// ── Forward iteration ──────────────────────────────────────────────────────────

/// CRTP base of the packed ranges. `Derived` provides
///     std::size_t size() const
///     State start() const                       — the cursor at element 0
///     Value read(const State&, std::size_t i)   — element i, the cursor being AT it
///     void advance(State&, std::size_t i)       — move the cursor past element i
/// and gets begin() / end() / empty(). The iterator holds the range by value.
template <class Derived, class Value, class State>
class ForwardRange {
 public:
  using value_type = Value;
  struct sentinel {};

  class iterator {
   public:
    using value_type = Value;
    using difference_type = std::ptrdiff_t;
    using reference = Value;
    using pointer = void;
    using iterator_category = std::input_iterator_tag;

    iterator(const Derived& range, State state) noexcept : range_(range), state_(state) {}
    Value operator*() const noexcept { return range_.read(state_, i_); }
    iterator& operator++() noexcept {
      range_.advance(state_, i_);
      ++i_;
      return *this;
    }
    bool operator!=(sentinel) const noexcept { return i_ < range_.size(); }
    bool operator==(sentinel) const noexcept { return i_ >= range_.size(); }

   private:
    Derived range_;
    State state_;
    std::size_t i_ = 0;
  };

  iterator begin() const noexcept { return iterator(self(), self().start()); }
  sentinel end() const noexcept { return sentinel{}; }
  bool empty() const noexcept { return self().size() == 0; }

 private:
  const Derived& self() const noexcept { return static_cast<const Derived&>(*this); }
};

namespace detail {

/// A count read from a packed array header, clamped: each element occupies at least
/// `min_bits` bits of what follows `base` (1 where an element may be a nil bit and nothing
/// else, 8 where it is at least a byte). A count that cannot fit is an empty array.
inline std::size_t packed_count(Bytes b, std::size_t base, std::uint64_t count, unsigned min_bits) noexcept {
  const std::size_t rem = remaining(b, base);
  if (min_bits >= 8) return count <= rem ? static_cast<std::size_t>(count) : 0;
  return count / 8 <= rem && (count + 7) / 8 <= rem ? static_cast<std::size_t>(count) : 0;
}

/// A cursor position advanced by `n` bytes; `npos` stays `npos`.
constexpr std::size_t step(std::size_t p, std::size_t n) noexcept { return p == npos ? npos : p + n; }

/// The header of an arrayWithOptionals codec: `[LEB count or (count << 2) | mode][nil bitset]`.
struct OptHeader {
  std::size_t count = 0;
  unsigned mode = 0;
  std::size_t nil_base = npos;
  std::size_t after_nil = npos;   // first byte past the nil bitset
};

inline OptHeader opt_header(Bytes b, std::size_t c, bool tagged) noexcept {
  OptHeader out;
  const Varint h = read_leb(b, c);
  if (h.len == 0) return out;
  const std::size_t nil_base = c + h.len;
  const std::size_t count = packed_count(b, nil_base, tagged ? h.value >> 2 : h.value, 1);
  if (count == 0) return out;
  out.count = count;
  out.mode = tagged ? static_cast<unsigned>(h.value & 3u) : 0;
  out.nil_base = nil_base;
  out.after_nil = nil_base + (count + 7) / 8;
  return out;
}

struct Pos {
  std::size_t p = npos;
};
struct PosIndex {
  std::size_t ci = 0;   // index among the PRESENT elements
};

}  // namespace detail

// ── Plain packed arrays ────────────────────────────────────────────────────────

/// `[u16]` … `[i64]`: `[LEB (count << 2) | tag]`, then by tag — 0: every element a varint;
/// 1: every element raw; 2: an encoding bitset, then each element raw or a varint.
template <class C>
class PackedIntArray : public ForwardRange<PackedIntArray<C>, typename C::value_type, detail::Pos> {
 public:
  constexpr PackedIntArray() noexcept = default;
  static PackedIntArray open(Bytes buf, std::size_t c) noexcept {
    PackedIntArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.tag_ = static_cast<unsigned>(h.value & 3u);
    out.enc_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.enc_, h.value >> 2, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedIntArray<C>, typename C::value_type, detail::Pos>;
  bool raw(std::size_t i) const noexcept { return tag_ == 1 || (tag_ == 2 && bit_at(buf_, enc_, i)); }
  detail::Pos start() const noexcept { return detail::Pos{enc_ + (tag_ == 2 ? (count_ + 7) / 8 : 0)}; }
  typename C::value_type read(const detail::Pos& s, std::size_t i) const noexcept {
    return raw(i) ? C::read(buf_, s.p) : C::from_leb(read_leb(buf_, s.p).value);
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    s.p = raw(i) ? detail::step(s.p, C::width) : leb_end(buf_, s.p);
  }

  Bytes buf_;
  std::size_t enc_ = npos;
  std::size_t count_ = 0;
  unsigned tag_ = 0;
};

/// `[f32]` / `[f64]`: `[LEB (count << 2) | mode]`, then mode 1: every element raw (a `raw`
/// float array, spec 04 §5.2); otherwise each element a self-describing packed float.
template <class C>
class PackedFloatArray : public ForwardRange<PackedFloatArray<C>, typename C::value_type, detail::Pos> {
 public:
  constexpr PackedFloatArray() noexcept = default;
  static PackedFloatArray open(Bytes buf, std::size_t c) noexcept {
    PackedFloatArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.raw_ = (h.value & 3u) == 1;
    out.base_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.base_, h.value >> 2, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedFloatArray<C>, typename C::value_type, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{base_}; }
  typename C::value_type read(const detail::Pos& s, std::size_t) const noexcept {
    return raw_ ? C::read(buf_, s.p) : C::packed(buf_, s.p).value;
  }
  void advance(detail::Pos& s, std::size_t) const noexcept {
    if (raw_) {
      s.p = detail::step(s.p, C::width);
    } else {
      const std::size_t len = C::packed(buf_, s.p).len;
      s.p = len != 0 ? detail::step(s.p, len) : npos;
    }
  }

  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
  bool raw_ = false;
};

/// `[f16]` / `[bf16]`: `[LEB count][encoding bitset]`, then each element two raw bytes
/// (bit set) or a one-byte special value.
template <class C>
class PackedHalfArray : public ForwardRange<PackedHalfArray<C>, float, detail::Pos> {
 public:
  constexpr PackedHalfArray() noexcept = default;
  static PackedHalfArray open(Bytes buf, std::size_t c) noexcept {
    PackedHalfArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.enc_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.enc_, h.value, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedHalfArray<C>, float, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{enc_ + (count_ + 7) / 8}; }
  float read(const detail::Pos& s, std::size_t i) const noexcept {
    return bit_at(buf_, enc_, i) ? C::read(buf_, s.p) : C::packed(buf_, s.p).value;
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    s.p = detail::step(s.p, bit_at(buf_, enc_, i) ? 2 : 1);
  }

  Bytes buf_;
  std::size_t enc_ = npos;
  std::size_t count_ = 0;
};

/// `[utf8]`, `[data]` or `[Node]` in a packed parent: `[LEB count]`, then the elements
/// inline, each a length-prefixed blob. `Elem` is one of `dagr::elem` (a node's accessor
/// sits AT its blob).
template <class Elem>
class PackedBlobArray : public ForwardRange<PackedBlobArray<Elem>, typename Elem::value_type, detail::Pos> {
 public:
  constexpr PackedBlobArray() noexcept = default;
  static PackedBlobArray open(Bytes buf, std::size_t c) noexcept {
    PackedBlobArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.base_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.base_, h.value, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedBlobArray<Elem>, typename Elem::value_type, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{base_}; }
  typename Elem::value_type read(const detail::Pos& s, std::size_t) const noexcept { return Elem::at(buf_, s.p); }
  void advance(detail::Pos& s, std::size_t) const noexcept { s.p = skip_blob(buf_, s.p); }

  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
};

/// An enum array too wide for sub-byte packing: `[LEB count]`, then one varint each.
template <class E>
class PackedLebEnumArray : public ForwardRange<PackedLebEnumArray<E>, E, detail::Pos> {
 public:
  constexpr PackedLebEnumArray() noexcept = default;
  static PackedLebEnumArray open(Bytes buf, std::size_t c) noexcept {
    PackedLebEnumArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.base_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.base_, h.value, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedLebEnumArray<E>, E, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{base_}; }
  E read(const detail::Pos& s, std::size_t) const noexcept { return static_cast<E>(read_leb(buf_, s.p).value); }
  void advance(detail::Pos& s, std::size_t) const noexcept { s.p = leb_end(buf_, s.p); }

  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
};

// ── arrayWithOptionals in a packed parent ──────────────────────────────────────
//
// `[header][nil bitset]`, then the PRESENT elements only, compacted. A nil element is a
// set bit and nothing else: the cursor does not move past it.

/// `[u16?]` … `[i64?]`: header `(count << 2) | mode`; mode 1: every present element raw;
/// mode 2: an encoding bitset (indexed by ELEMENT, not by present element) follows the nil
/// bitset; otherwise every present element a varint.
template <class C>
class PackedIntOptArray
    : public ForwardRange<PackedIntOptArray<C>, std::optional<typename C::value_type>, detail::Pos> {
 public:
  constexpr PackedIntOptArray() noexcept = default;
  static PackedIntOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedIntOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, true);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedIntOptArray<C>, std::optional<typename C::value_type>, detail::Pos>;
  bool raw(std::size_t i) const noexcept { return h_.mode == 1 || (h_.mode == 2 && bit_at(buf_, h_.after_nil, i)); }
  detail::Pos start() const noexcept {
    return detail::Pos{detail::step(h_.after_nil, h_.mode == 2 ? (h_.count + 7) / 8 : 0)};
  }
  std::optional<typename C::value_type> read(const detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return raw(i) ? C::read(buf_, s.p) : C::from_leb(read_leb(buf_, s.p).value);
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return;
    s.p = raw(i) ? detail::step(s.p, C::width) : leb_end(buf_, s.p);
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// `[f32?]` / `[f64?]`: header `(count << 2) | mode`; mode 1: present elements raw;
/// otherwise each a self-describing packed float.
template <class C>
class PackedFloatOptArray
    : public ForwardRange<PackedFloatOptArray<C>, std::optional<typename C::value_type>, detail::Pos> {
 public:
  constexpr PackedFloatOptArray() noexcept = default;
  static PackedFloatOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedFloatOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, true);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedFloatOptArray<C>, std::optional<typename C::value_type>, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{h_.after_nil}; }
  std::optional<typename C::value_type> read(const detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return h_.mode == 1 ? C::read(buf_, s.p) : C::packed(buf_, s.p).value;
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return;
    if (h_.mode == 1) {
      s.p = detail::step(s.p, C::width);
    } else {
      const std::size_t len = C::packed(buf_, s.p).len;
      s.p = len != 0 ? detail::step(s.p, len) : npos;
    }
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// `[u8?]`, `[i8?]`, `[f16?]`, `[bf16?]`: `[LEB count][nil bitset]`, then the present
/// elements at their fixed width.
template <class C>
class PackedFixedOptArray
    : public ForwardRange<PackedFixedOptArray<C>, std::optional<typename C::value_type>, detail::Pos> {
 public:
  constexpr PackedFixedOptArray() noexcept = default;
  static PackedFixedOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedFixedOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedFixedOptArray<C>, std::optional<typename C::value_type>, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{h_.after_nil}; }
  std::optional<typename C::value_type> read(const detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return C::read(buf_, s.p);
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) s.p = detail::step(s.p, C::width);
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// `[bool?]`: `[LEB count][nil bitset]`, then one bit per PRESENT element.
class PackedBoolOptArray : public ForwardRange<PackedBoolOptArray, std::optional<bool>, detail::PosIndex> {
 public:
  constexpr PackedBoolOptArray() noexcept = default;
  static PackedBoolOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedBoolOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedBoolOptArray, std::optional<bool>, detail::PosIndex>;
  detail::PosIndex start() const noexcept { return detail::PosIndex{}; }
  std::optional<bool> read(const detail::PosIndex& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return bit_at(buf_, h_.after_nil, s.ci);
  }
  void advance(detail::PosIndex& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) s.ci++;
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// A sub-byte enum array with optionals: `Bits` bits per PRESENT element.
template <class E, unsigned Bits>
class PackedBitEnumOptArray
    : public ForwardRange<PackedBitEnumOptArray<E, Bits>, std::optional<E>, detail::PosIndex> {
 public:
  constexpr PackedBitEnumOptArray() noexcept = default;
  static PackedBitEnumOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedBitEnumOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedBitEnumOptArray<E, Bits>, std::optional<E>, detail::PosIndex>;
  detail::PosIndex start() const noexcept { return detail::PosIndex{}; }
  std::optional<E> read(const detail::PosIndex& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return static_cast<E>(detail::packed_bits<Bits>(buf_, h_.after_nil, s.ci));
  }
  void advance(detail::PosIndex& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) s.ci++;
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// `[utf8?]`, `[data?]` or `[Node?]` in a packed parent: the present elements' blobs.
template <class Elem>
class PackedBlobOptArray
    : public ForwardRange<PackedBlobOptArray<Elem>, std::optional<typename Elem::value_type>, detail::Pos> {
 public:
  constexpr PackedBlobOptArray() noexcept = default;
  static PackedBlobOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedBlobOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedBlobOptArray<Elem>, std::optional<typename Elem::value_type>, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{h_.after_nil}; }
  std::optional<typename Elem::value_type> read(const detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return Elem::at(buf_, s.p);
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) s.p = skip_blob(buf_, s.p);
  }

  Bytes buf_;
  detail::OptHeader h_;
};

/// A wide enum array with optionals: one varint per present element.
template <class E>
class PackedLebEnumOptArray : public ForwardRange<PackedLebEnumOptArray<E>, std::optional<E>, detail::Pos> {
 public:
  constexpr PackedLebEnumOptArray() noexcept = default;
  static PackedLebEnumOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedLebEnumOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedLebEnumOptArray<E>, std::optional<E>, detail::Pos>;
  detail::Pos start() const noexcept { return detail::Pos{h_.after_nil}; }
  std::optional<E> read(const detail::Pos& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return static_cast<E>(read_leb(buf_, s.p).value);
  }
  void advance(detail::Pos& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) s.p = leb_end(buf_, s.p);
  }

  Bytes buf_;
  detail::OptHeader h_;
};

// ── Union arrays in a packed parent ────────────────────────────────────────────
//
// Two sections: every present element's header `[LEB (typeId << 3) | code]`, then every
// present element's payload. `View` is the generated packed view of the union —
// constructible from `(buffer, payload position, type id, code)`.

namespace detail {
struct UnionCursor {
  std::size_t header = npos;    // the next header
  std::size_t payload = npos;   // the next payload
};

/// Where the payload section starts: past `present` header varints from `headers`.
inline std::size_t union_payload_start(Bytes b, std::size_t headers, std::size_t present) noexcept {
  std::size_t p = headers;
  for (std::size_t k = 0; k < present; k++) {
    p = leb_end(b, p);
    if (p == npos) return npos;
  }
  return p;
}

template <class View>
inline View union_view_at(Bytes b, const UnionCursor& s) noexcept {
  const Varint h = read_leb(b, s.header);
  if (h.len == 0) return View();
  return View(b, s.payload, static_cast<std::uint32_t>((h.value >> 3) & 0xffu), static_cast<std::uint32_t>(h.value & 7u));
}

inline void union_advance(Bytes b, UnionCursor& s) noexcept {
  const Varint h = read_leb(b, s.header);
  if (h.len == 0) {
    s.header = npos;
    s.payload = npos;
    return;
  }
  s.header += h.len;
  const std::size_t len = packed_union_payload_bytes(b, s.payload, static_cast<unsigned>(h.value & 7u));
  s.payload = len != 0 ? step(s.payload, len) : npos;
}
}  // namespace detail

/// `[Union]` in a packed parent: `[LEB count][headers][payloads]`.
template <class View>
class PackedUnionArray : public ForwardRange<PackedUnionArray<View>, View, detail::UnionCursor> {
 public:
  constexpr PackedUnionArray() noexcept = default;
  static PackedUnionArray open(Bytes buf, std::size_t c) noexcept {
    PackedUnionArray out;
    const Varint h = read_leb(buf, c);
    if (h.len == 0) return out;
    out.buf_ = buf;
    out.headers_ = c + h.len;
    out.count_ = detail::packed_count(buf, out.headers_, h.value, 8);
    return out;
  }
  constexpr std::size_t size() const noexcept { return count_; }

 private:
  friend class ForwardRange<PackedUnionArray<View>, View, detail::UnionCursor>;
  detail::UnionCursor start() const noexcept {
    return detail::UnionCursor{headers_, detail::union_payload_start(buf_, headers_, count_)};
  }
  View read(const detail::UnionCursor& s, std::size_t) const noexcept { return detail::union_view_at<View>(buf_, s); }
  void advance(detail::UnionCursor& s, std::size_t) const noexcept { detail::union_advance(buf_, s); }

  Bytes buf_;
  std::size_t headers_ = npos;
  std::size_t count_ = 0;
};

/// `[Union?]` in a packed parent: `[LEB count][nil bitset][LEB header section size]
/// [headers of the present elements][their payloads]`.
template <class View>
class PackedUnionOptArray
    : public ForwardRange<PackedUnionOptArray<View>, std::optional<View>, detail::UnionCursor> {
 public:
  constexpr PackedUnionOptArray() noexcept = default;
  static PackedUnionOptArray open(Bytes buf, std::size_t c) noexcept {
    PackedUnionOptArray out;
    out.buf_ = buf;
    out.h_ = detail::opt_header(buf, c, false);
    out.headers_ = leb_end(buf, out.h_.after_nil);
    return out;
  }
  constexpr std::size_t size() const noexcept { return h_.count; }

 private:
  friend class ForwardRange<PackedUnionOptArray<View>, std::optional<View>, detail::UnionCursor>;
  detail::UnionCursor start() const noexcept {
    std::size_t present = 0;
    for (std::size_t i = 0; i < h_.count; i++) present += bit_at(buf_, h_.nil_base, i) ? 0u : 1u;
    return detail::UnionCursor{headers_, detail::union_payload_start(buf_, headers_, present)};
  }
  std::optional<View> read(const detail::UnionCursor& s, std::size_t i) const noexcept {
    if (bit_at(buf_, h_.nil_base, i)) return std::nullopt;
    return detail::union_view_at<View>(buf_, s);
  }
  void advance(detail::UnionCursor& s, std::size_t i) const noexcept {
    if (!bit_at(buf_, h_.nil_base, i)) detail::union_advance(buf_, s);
  }

  Bytes buf_;
  detail::OptHeader h_;
  std::size_t headers_ = npos;
};

}  // namespace dagr
