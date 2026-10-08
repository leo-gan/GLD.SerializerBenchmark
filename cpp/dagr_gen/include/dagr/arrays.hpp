// dagr/arrays.hpp — the array views generated accessors return (spec/41 §8.2).
//
// An array getter returns a RANGE: a small value holding the buffer and where the array
// lives in it. Nothing is decoded until an element is asked for, and nothing allocates.
//
//   for (std::uint32_t v : node.values()) …          // every range
//   node.values()[2], node.values().size()            // these ranges: O(1) indexing
//
// The ranges in this header are the ones that index in O(1) — a fixed element stride, or a
// pointer table — which is every array of a regular or frozen node. Packed arrays are
// sequences of self-sizing elements; their ranges are forward-only and have no
// `operator[]` (spec/38 §10.2: an O(i) `at(i)` makes every sweep quadratic).
//
// Totality (spec/41 §5): `open` clamps the element count against the buffer, element reads
// go through the checked primitives, and an index at or past `size()` yields a zero / empty
// / absent element rather than a read.
//
// Core tier: no allocation, no exceptions, no RTTI, no containers.
#pragma once

#include <cstddef>
#include <cstdint>
#include <iterator>
#include <optional>
#include <string_view>

#include "dagr/reader.hpp"

namespace dagr {

// ── Element codecs: how one fixed-width element is read ────────────────────────

namespace codec {

struct U8 {
  using value_type = std::uint8_t;
  static constexpr std::size_t width = 1;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_u8(b, at); }
};
struct U16 {
  using value_type = std::uint16_t;
  static constexpr std::size_t width = 2;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_u16(b, at); }
  /// The value a packed layout stored as a varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(v); }
};
struct U32 {
  using value_type = std::uint32_t;
  static constexpr std::size_t width = 4;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_u32(b, at); }
  /// The value a packed layout stored as a varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(v); }
};
struct U64 {
  using value_type = std::uint64_t;
  static constexpr std::size_t width = 8;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_u64(b, at); }
  /// The value a packed layout stored as a varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(v); }
};
struct I8 {
  using value_type = std::int8_t;
  static constexpr std::size_t width = 1;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_i8(b, at); }
};
struct I16 {
  using value_type = std::int16_t;
  static constexpr std::size_t width = 2;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_i16(b, at); }
  /// The value a packed layout stored as a ZigZag varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(zigzag_decode(v)); }
};
struct I32 {
  using value_type = std::int32_t;
  static constexpr std::size_t width = 4;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_i32(b, at); }
  /// The value a packed layout stored as a ZigZag varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(zigzag_decode(v)); }
};
struct I64 {
  using value_type = std::int64_t;
  static constexpr std::size_t width = 8;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_i64(b, at); }
  /// The value a packed layout stored as a ZigZag varint.
  static value_type from_leb(std::uint64_t v) noexcept { return static_cast<value_type>(zigzag_decode(v)); }
};
struct F32 {
  using value_type = float;
  static constexpr std::size_t width = 4;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_f32(b, at); }
  /// The self-describing packed form (spec 07 §12): value and bytes consumed.
  static F32Read packed(Bytes b, std::size_t at) noexcept { return decode_packed_f32(b, at); }
};
struct F64 {
  using value_type = double;
  static constexpr std::size_t width = 8;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_f64(b, at); }
  static F64Read packed(Bytes b, std::size_t at) noexcept { return decode_packed_f64(b, at); }
};
/// IEEE half on the wire, `float` in the API.
struct F16 {
  using value_type = float;
  static constexpr std::size_t width = 2;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_f16(b, at); }
  static F32Read packed(Bytes b, std::size_t at) noexcept { return decode_packed_f16(b, at); }
};
/// bfloat16 on the wire, `float` in the API.
struct Bf16 {
  using value_type = float;
  static constexpr std::size_t width = 2;
  static value_type read(Bytes b, std::size_t at) noexcept { return read_bf16(b, at); }
  static F32Read packed(Bytes b, std::size_t at) noexcept { return decode_packed_bf16(b, at); }
};
/// An enum stored at its backing width `Raw` (a byte-aligned enum array).
template <class E, class Raw>
struct Enum {
  using value_type = E;
  static constexpr std::size_t width = Raw::width;
  static value_type read(Bytes b, std::size_t at) noexcept { return static_cast<E>(Raw::read(b, at)); }
};

}  // namespace codec

// ── The iteration every O(1)-indexable range shares ────────────────────────────

/// CRTP base: a range that has `size()` and `operator[]` gets `begin()` / `end()` /
/// `empty()`. The iterator holds the range BY VALUE (ranges are a few words), so
/// `auto it = node.values().begin();` does not dangle off a temporary.
template <class Derived, class Value>
class IndexedRange {
 public:
  using value_type = Value;

  class iterator {
   public:
    using value_type = Value;
    using difference_type = std::ptrdiff_t;
    using reference = Value;
    using pointer = void;
    using iterator_category = std::input_iterator_tag;

    constexpr iterator() noexcept = default;
    constexpr iterator(const Derived& range, std::size_t i) noexcept : range_(range), i_(i) {}
    Value operator*() const noexcept { return range_[i_]; }
    iterator& operator++() noexcept {
      ++i_;
      return *this;
    }
    iterator operator++(int) noexcept {
      iterator before = *this;
      ++i_;
      return before;
    }
    constexpr bool operator==(const iterator& other) const noexcept { return i_ == other.i_; }
    constexpr bool operator!=(const iterator& other) const noexcept { return i_ != other.i_; }

   private:
    Derived range_{};
    std::size_t i_ = 0;
  };

  iterator begin() const noexcept { return iterator(self(), 0); }
  iterator end() const noexcept { return iterator(self(), self().size()); }
  bool empty() const noexcept { return self().size() == 0; }

 private:
  const Derived& self() const noexcept { return static_cast<const Derived&>(*this); }
};

// ── Fixed-width elements: `[LEB count][elements]` ──────────────────────────────

/// A numeric array (or an enum array at a byte-aligned backing width): `count` elements
/// of `C::width` bytes each, little-endian, unaligned. `operator[]` is one checked load.
template <class C>
class FixedArray : public IndexedRange<FixedArray<C>, typename C::value_type> {
 public:
  constexpr FixedArray() noexcept = default;
  /// `count` elements starting at `base` — the caller has bounded `count` (a default
  /// array over its own literal bytes, or a parser below).
  constexpr FixedArray(Bytes buf, std::size_t base, std::size_t count) noexcept
      : buf_(buf), base_(base), count_(count) {}
  /// The array whose `[LEB count]` header is at `payload`; empty when it does not fit.
  static FixedArray open(Bytes buf, std::size_t payload) noexcept {
    const ArrayRef a = array_payload_at(buf, payload, C::width);
    return FixedArray(buf, a.base, a.count);
  }

  constexpr std::size_t size() const noexcept { return count_; }
  typename C::value_type operator[](std::size_t i) const noexcept {
    return i < count_ ? C::read(buf_, base_ + i * C::width) : typename C::value_type{};
  }

 private:
  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
};

/// The `arrayWithOptionals` form: `[LEB count][nil bitset][elements]`, uncompacted —
/// element i sits at index i whether or not its neighbours are nil.
template <class C>
class FixedOptArray : public IndexedRange<FixedOptArray<C>, std::optional<typename C::value_type>> {
 public:
  constexpr FixedOptArray() noexcept = default;
  static FixedOptArray open(Bytes buf, std::size_t payload) noexcept {
    const AwoRef a = awo_payload_at(buf, payload, C::width);
    FixedOptArray out;
    out.buf_ = buf;
    out.nil_base_ = a.nil_base;
    out.value_base_ = a.value_base;
    out.count_ = a.count;
    return out;
  }

  constexpr std::size_t size() const noexcept { return count_; }
  std::optional<typename C::value_type> operator[](std::size_t i) const noexcept {
    if (i >= count_ || bit_at(buf_, nil_base_, i)) return std::nullopt;
    return C::read(buf_, value_base_ + i * C::width);
  }

 private:
  Bytes buf_;
  std::size_t nil_base_ = npos;
  std::size_t value_base_ = npos;
  std::size_t count_ = 0;
};

// ── Bit-packed elements ────────────────────────────────────────────────────────

/// A bool array: one bit per element.
class BoolArray : public IndexedRange<BoolArray, bool> {
 public:
  constexpr BoolArray() noexcept = default;
  static BoolArray open(Bytes buf, std::size_t payload) noexcept {
    const ArrayRef a = bit_array_payload_at(buf, payload, 1);
    BoolArray out;
    out.buf_ = buf;
    out.base_ = a.base;
    out.count_ = a.count;
    return out;
  }

  constexpr std::size_t size() const noexcept { return count_; }
  bool operator[](std::size_t i) const noexcept { return i < count_ && bit_at(buf_, base_, i); }

 private:
  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
};

/// `[bool?]`: a nil bitset, then the value bits.
class BoolOptArray : public IndexedRange<BoolOptArray, std::optional<bool>> {
 public:
  constexpr BoolOptArray() noexcept = default;
  static BoolOptArray open(Bytes buf, std::size_t payload) noexcept {
    const AwoRef a = awo_payload_at(buf, payload, 0);
    BoolOptArray out;
    out.buf_ = buf;
    out.nil_base_ = a.nil_base;
    out.value_base_ = a.value_base;
    out.count_ = a.count;
    return out;
  }

  constexpr std::size_t size() const noexcept { return count_; }
  std::optional<bool> operator[](std::size_t i) const noexcept {
    if (i >= count_ || bit_at(buf_, nil_base_, i)) return std::nullopt;
    return bit_at(buf_, value_base_, i);
  }

 private:
  Bytes buf_;
  std::size_t nil_base_ = npos;
  std::size_t value_base_ = npos;
  std::size_t count_ = 0;
};

namespace detail {
/// Element i of a sub-byte packed array: `Bits` ∈ {1, 2, 4} bits per element, low bits first.
template <unsigned Bits>
inline std::uint8_t packed_bits(Bytes b, std::size_t base, std::size_t i) noexcept {
  const std::size_t bit = i * Bits;
  return static_cast<std::uint8_t>((read_u8(b, base + (bit >> 3)) >> (bit & 7u)) & ((1u << Bits) - 1u));
}
}  // namespace detail

/// An enum array whose capacity fits in `Bits` ∈ {1, 2, 4} bits per element.
template <class E, unsigned Bits>
class BitEnumArray : public IndexedRange<BitEnumArray<E, Bits>, E> {
 public:
  constexpr BitEnumArray() noexcept = default;
  static BitEnumArray open(Bytes buf, std::size_t payload) noexcept {
    const ArrayRef a = bit_array_payload_at(buf, payload, Bits);
    BitEnumArray out;
    out.buf_ = buf;
    out.base_ = a.base;
    out.count_ = a.count;
    return out;
  }

  constexpr std::size_t size() const noexcept { return count_; }
  E operator[](std::size_t i) const noexcept {
    return i < count_ ? static_cast<E>(detail::packed_bits<Bits>(buf_, base_, i)) : E{};
  }

 private:
  Bytes buf_;
  std::size_t base_ = npos;
  std::size_t count_ = 0;
};

/// The `arrayWithOptionals` form of BitEnumArray.
template <class E, unsigned Bits>
class BitEnumOptArray : public IndexedRange<BitEnumOptArray<E, Bits>, std::optional<E>> {
 public:
  constexpr BitEnumOptArray() noexcept = default;
  static BitEnumOptArray open(Bytes buf, std::size_t payload) noexcept {
    const AwoRef a = awo_payload_at(buf, payload, 0);
    BitEnumOptArray out;
    out.buf_ = buf;
    out.nil_base_ = a.nil_base;
    out.value_base_ = a.value_base;
    out.count_ = a.count;
    return out;
  }

  constexpr std::size_t size() const noexcept { return count_; }
  std::optional<E> operator[](std::size_t i) const noexcept {
    if (i >= count_ || bit_at(buf_, nil_base_, i)) return std::nullopt;
    return static_cast<E>(detail::packed_bits<Bits>(buf_, value_base_, i));
  }

 private:
  Bytes buf_;
  std::size_t nil_base_ = npos;
  std::size_t value_base_ = npos;
  std::size_t count_ = 0;
};

// ── Pointer-table elements: utf8, data, nodes ──────────────────────────────────
//
// `[LEB (count << 2) | wc][count slots of 1 << wc bytes][element data]`. Slot i holds the
// element's offset from the data base plus one; 0 is a nil element. A node slot is signed:
// a shared or cyclic node may sit BEFORE the array.

namespace elem {

struct Utf8 {
  using value_type = std::string_view;
  static constexpr bool signed_slots = false;
  static value_type at(Bytes b, std::size_t pos) noexcept { return as_string_view(read_bytes(b, pos).bytes); }
};
struct Data {
  using value_type = Bytes;
  static constexpr bool signed_slots = false;
  static value_type at(Bytes b, std::size_t pos) noexcept { return read_bytes(b, pos).bytes; }
};
/// A node reached through a pointer-table slot, as its lazy accessor.
template <class Accessor>
struct Node {
  using value_type = Accessor;
  static constexpr bool signed_slots = true;
  static value_type at(Bytes b, std::size_t pos) noexcept { return Accessor(b, pos); }
};

}  // namespace elem

namespace detail {
/// The slot value of element i, as the offset to add to the data base (already minus one);
/// `nil` is set for a zero slot.
template <class Elem>
inline std::size_t ptr_slot(Bytes b, const PtrTable& t, std::size_t i, bool& nil) noexcept {
  const std::size_t at = t.table_base + i * t.es;
  if (Elem::signed_slots) {
    const std::int64_t ro = read_int_le(b, at, t.es);
    nil = ro == 0;
    return static_cast<std::size_t>(ro) - 1;   // modular: a negative offset wraps, then adds back
  }
  const std::uint64_t ro = read_uint_le(b, at, t.es);
  nil = ro == 0;
  return static_cast<std::size_t>(ro) - 1;
}
}  // namespace detail

/// `[utf8]`, `[data]` or `[Node]`: every element present.
template <class Elem>
class PtrArray : public IndexedRange<PtrArray<Elem>, typename Elem::value_type> {
 public:
  constexpr PtrArray() noexcept = default;
  static PtrArray open(Bytes buf, std::size_t payload) noexcept {
    PtrArray out;
    out.buf_ = buf;
    out.table_ = ptr_table_at(buf, payload);
    return out;
  }

  constexpr std::size_t size() const noexcept { return table_.count; }
  typename Elem::value_type operator[](std::size_t i) const noexcept {
    if (i >= table_.count) return typename Elem::value_type{};
    bool nil = false;
    const std::size_t off = detail::ptr_slot<Elem>(buf_, table_, i, nil);
    // A nil slot in an array that declares none is malformed: the empty element.
    return nil ? typename Elem::value_type{} : Elem::at(buf_, table_.data_base + off);
  }

 private:
  Bytes buf_;
  PtrTable table_{npos, npos, 0, 1};
};

/// `[utf8?]`, `[data?]` or `[Node?]`: a zero slot is an absent element.
template <class Elem>
class PtrOptArray : public IndexedRange<PtrOptArray<Elem>, std::optional<typename Elem::value_type>> {
 public:
  constexpr PtrOptArray() noexcept = default;
  static PtrOptArray open(Bytes buf, std::size_t payload) noexcept {
    PtrOptArray out;
    out.buf_ = buf;
    out.table_ = ptr_table_at(buf, payload);
    return out;
  }

  constexpr std::size_t size() const noexcept { return table_.count; }
  std::optional<typename Elem::value_type> operator[](std::size_t i) const noexcept {
    if (i >= table_.count) return std::nullopt;
    bool nil = false;
    const std::size_t off = detail::ptr_slot<Elem>(buf_, table_, i, nil);
    if (nil) return std::nullopt;
    return Elem::at(buf_, table_.data_base + off);
  }

 private:
  Bytes buf_;
  PtrTable table_{npos, npos, 0, 1};
};

// ── Union arrays of a regular or frozen node ───────────────────────────────────
//
// `Elem` is the generated element view of the union — constructible from
// `(buffer, payload base, slot position, slot width, type id)` — and `TagBits` the width
// of a type id, which the union's capacity fixes.

/// `[Union]`: every element present.
template <class Elem, unsigned TagBits>
class UnionArray : public IndexedRange<UnionArray<Elem, TagBits>, Elem> {
 public:
  constexpr UnionArray() noexcept = default;
  /// The union array whose header is at `payload`; empty when it does not fit.
  static UnionArray open(Bytes buf, std::size_t payload) noexcept {
    UnionArray out;
    out.buf_ = buf;
    out.ref_ = union_array_at(buf, payload, TagBits, false);
    return out;
  }

  constexpr std::size_t size() const noexcept { return ref_.count; }
  Elem operator[](std::size_t i) const noexcept {
    if (i >= ref_.count) return Elem();
    return Elem(buf_, ref_.base, ref_.slot_start + i * ref_.es, ref_.es, union_array_tag(buf_, ref_, i, TagBits));
  }

 private:
  Bytes buf_;
  UnionArrayRef ref_;
};

/// `[Union?]`: a set bit in the nil bitset is an absent element.
template <class Elem, unsigned TagBits>
class UnionOptArray : public IndexedRange<UnionOptArray<Elem, TagBits>, std::optional<Elem>> {
 public:
  constexpr UnionOptArray() noexcept = default;
  static UnionOptArray open(Bytes buf, std::size_t payload) noexcept {
    UnionOptArray out;
    out.buf_ = buf;
    out.ref_ = union_array_at(buf, payload, TagBits, true);
    return out;
  }

  constexpr std::size_t size() const noexcept { return ref_.count; }
  std::optional<Elem> operator[](std::size_t i) const noexcept {
    if (i >= ref_.count || bit_at(buf_, ref_.nil_start, i)) return std::nullopt;
    return Elem(buf_, ref_.base, ref_.slot_start + i * ref_.es, ref_.es, union_array_tag(buf_, ref_, i, TagBits));
  }

 private:
  Bytes buf_;
  UnionArrayRef ref_;
};

}  // namespace dagr
