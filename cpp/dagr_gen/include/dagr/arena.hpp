// dagr/arena.hpp — the runtime of the generated ARENAS (spec/41-cpp-codegen-plan.md §8.6,
// §8.7, §8.9): the mutable in-memory model of a graph, which may be cyclic and share nodes.
//
// A generated `{graph}_arena.hpp` keeps every node of one graph instance in per-type
// `std::vector`s of records (struct-of-arrays); a node is a HANDLE — the arena's address
// and `generation << 40 | index` (spec 09) — so references between nodes are integers, and
// a cycle is just two integers naming each other. This header holds what every generated
// arena shares: the handle packing, the owning `Box`, the array RANGES its getters return
// (the same `IndexedRange` shape as the lazy reader's, so one assertion body reads both),
// and the canonical description behind `equals` / `hash` / `to_string`.
//
// Alloc tier and more: std::vector, std::string, std::map. Still no exceptions (a failed
// allocation terminates, as `new` does under -fno-exceptions) and no RTTI.
#pragma once

#include <cstdint>
#include <cstdio>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <map>
#include <optional>
#include <string>
#include <string_view>
#include <type_traits>
#include <utility>
#include <vector>

#include "arrays.hpp"
#include "reader.hpp"
#include "values.hpp"

namespace dagr {

// ── Handles (spec 09): generation << 40 | index ────────────────────────────────

/// The stored form of a reference that is not set: no node has this handle (its index is
/// past any arena's capacity).
inline constexpr std::uint64_t no_handle = ~std::uint64_t{0};

// `pack_handle` / `handle_index` / `handle_generation` are dagr/reader.hpp's (a stored
// reference is the same 64-bit handle the reader packs).

/// Element `i` of `v`, or nullptr past its end — the one way generated arena code reaches
/// into a store (no subscript in generated code, spec/41 §5).
template <class T>
T* slot(std::vector<T>& v, std::uint64_t i) noexcept {
  return i < v.size() ? &v[static_cast<std::size_t>(i)] : nullptr;
}
template <class T>
const T* slot(const std::vector<T>& v, std::uint64_t i) noexcept {
  return i < v.size() ? &v[static_cast<std::size_t>(i)] : nullptr;
}

/// A programming error the arena cannot continue past — a handle used with an arena it
/// does not belong to. Not a data error: those are statuses. Prints and aborts.
[[noreturn]] inline void arena_misuse(const char* what) noexcept {
  std::fputs("dagr arena misuse: ", stderr);
  std::fputs(what, stderr);
  std::fputc('\n', stderr);
  std::abort();
}

/// The tag of a union value that holds no variant: the tag type's largest value, which no
/// schema names (the lazy reader's empty view reads the same).
template <class Tag>
constexpr Tag no_variant() noexcept {
  return static_cast<Tag>(std::numeric_limits<std::underlying_type_t<Tag>>::max());
}

// ── Box: an owning pointer with value semantics ────────────────────────────────

/// Holds one T on the heap and copies it deeply — how a union value holds a union (a
/// recursive union would otherwise contain itself). Never empty after construction from a
/// value; a default-constructed Box reads as a default T.
template <class T>
class Box {
 public:
  Box() noexcept = default;
  explicit Box(const T& v) : p_(new T(v)) {}
  Box(const Box& other) : p_(other.p_ != nullptr ? new T(*other.p_) : nullptr) {}
  Box(Box&& other) noexcept : p_(other.p_) { other.p_ = nullptr; }
  Box& operator=(const Box& other) {
    if (this != &other) {
      T* copy = other.p_ != nullptr ? new T(*other.p_) : nullptr;
      delete p_;
      p_ = copy;
    }
    return *this;
  }
  Box& operator=(Box&& other) noexcept {
    if (this != &other) {
      delete p_;
      p_ = other.p_;
      other.p_ = nullptr;
    }
    return *this;
  }
  ~Box() { delete p_; }

  const T* get() const noexcept { return p_; }
  /// The held value, to clean in place (an arena sweeping a stale reference out of it).
  T* get_mut() noexcept { return p_; }

 private:
  T* p_ = nullptr;
};

// ── Stored arrays, read as ranges ──────────────────────────────────────────────

/// An array field of an arena record, read as an indexed range — `size()`, `operator[]`,
/// `begin()` / `end()`, `value_type` — like every array of the lazy reader. `Map` turns a
/// stored element into the public one (a `std::string` into a `std::string_view`, a stored
/// handle into a node handle); it is a small value the range carries.
///
/// The range borrows the record's storage: it is valid until the field is set again or a
/// node of the same type is created (the store may move), like an iterator into a vector.
template <class S, class Map>
class StoredArray : public IndexedRange<StoredArray<S, Map>, typename Map::value_type> {
 public:
  using value_type = typename Map::value_type;

  constexpr StoredArray() noexcept = default;
  StoredArray(const std::vector<S>& v, Map map) noexcept : data_(v.data()), size_(v.size()), map_(map) {}

  constexpr std::size_t size() const noexcept { return size_; }
  /// Element i; past the end, an empty element (the lazy ranges' rule).
  value_type operator[](std::size_t i) const noexcept { return i < size_ ? map_(data_[i]) : value_type(); }

 private:
  const S* data_ = nullptr;
  std::size_t size_ = 0;
  Map map_{};
};

namespace map {

/// The element as stored.
template <class T>
struct Same {
  using value_type = T;
  T operator()(const T& v) const noexcept { return v; }
};

/// A bool array element, stored as one byte (std::vector<bool> has no storage to view).
struct Flag {
  using value_type = bool;
  bool operator()(std::uint8_t v) const noexcept { return v != 0; }
};

struct Text {
  using value_type = std::string_view;
  std::string_view operator()(const std::string& v) const noexcept { return std::string_view(v); }
};

struct Blob {
  using value_type = Bytes;
  Bytes operator()(const std::vector<std::uint8_t>& v) const noexcept { return Bytes(v.data(), v.size()); }
};

/// An arrayWithOptionals element: absent stays absent, present goes through `M`.
template <class M>
struct Opt {
  using value_type = std::optional<typename M::value_type>;
  M inner{};
  template <class S>
  value_type operator()(const std::optional<S>& v) const noexcept {
    return v ? value_type(inner(*v)) : value_type();
  }
};

/// A stored node handle → the node handle class `H`, which is built from its arena.
template <class H, class A>
struct Node {
  using value_type = H;
  A* arena = nullptr;
  H operator()(std::uint64_t h) const noexcept { return H(arena, h); }
};

/// A stored union value → its view `V`.
template <class V, class A>
struct View {
  using value_type = V;
  A* arena = nullptr;
  template <class S>
  V operator()(const S& v) const noexcept { return V(arena, &v); }
};

/// A union held through a Box (inside a union value) → its view; an empty Box reads as
/// the empty view.
template <class V, class A>
struct BoxView {
  using value_type = V;
  A* arena = nullptr;
  template <class B>
  V operator()(const B& b) const noexcept { return V(arena, b.get()); }
};

/// The same in an arrayWithOptionals: an empty Box is a nil element.
template <class V, class A>
struct BoxOpt {
  using value_type = std::optional<V>;
  A* arena = nullptr;
  template <class B>
  value_type operator()(const B& b) const noexcept {
    return b.get() != nullptr ? value_type(V(arena, b.get())) : value_type();
  }
};

}  // namespace map

/// `v` as stored bytes.
inline std::vector<std::uint8_t> to_blob(Bytes v) { return std::vector<std::uint8_t>(v.begin(), v.end()); }

// ── The canonical description: equals / hash / to_string (spec/41 §8.9) ───────

/// One depth-first walk that writes a node and everything reachable from it as text. A
/// node seen before is written as `Type#<ordinal>` — its position in the walk, not its
/// handle — so the text is the same for isomorphic graphs in different arenas, a cycle
/// terminates, and sharing shows. `equals` compares two descriptions, `hash` is FNV-1a of
/// one, `to_string` returns it. A walk deeper than `max_depth` writes `…` and goes no
/// further (spec/41 §5): two graphs that differ only below that depth compare equal.
class Describer {
 public:
  explicit Describer(std::size_t max_depth = default_max_depth) : max_depth_(max_depth) {}

  std::string& out() noexcept { return out_; }

  /// Starts node (`type`, `handle`): false — and its back-reference written — when the
  /// walk has seen it or is too deep; true, with `Type#n{` written, when it is new.
  bool enter(unsigned type, const char* name, std::uint64_t handle) {
    const auto key = std::make_pair(type, handle);
    const auto seen = seen_.find(key);
    if (seen != seen_.end()) {
      out_ += name;
      out_ += '#';
      out_ += std::to_string(seen->second);
      return false;
    }
    if (depth_ >= max_depth_) {
      out_ += "…";
      return false;
    }
    const std::size_t ordinal = seen_.size();
    seen_.emplace(key, ordinal);
    out_ += name;
    out_ += '#';
    out_ += std::to_string(ordinal);
    out_ += '{';
    depth_++;
    return true;
  }
  void leave() {
    depth_--;
    out_ += '}';
  }
  /// A reference that names no node (absent, or deleted).
  void none() { out_ += "nil"; }

  /// `name: ` — after a ", " unless it is the node's first field.
  void field(const char* name, bool first) {
    if (!first) out_ += ", ";
    out_ += name;
    out_ += ": ";
  }
  void sep(std::size_t i) {
    if (i > 0) out_ += ", ";
  }

  void value(bool v) { out_ += v ? "true" : "false"; }
  void value(std::int64_t v) { out_ += std::to_string(v); }
  void value(std::uint64_t v) { out_ += std::to_string(v); }
  void value(std::int32_t v) { value(static_cast<std::int64_t>(v)); }
  void value(std::uint32_t v) { value(static_cast<std::uint64_t>(v)); }
  void value(std::int16_t v) { value(static_cast<std::int64_t>(v)); }
  void value(std::uint16_t v) { value(static_cast<std::uint64_t>(v)); }
  void value(std::int8_t v) { value(static_cast<std::int64_t>(v)); }
  void value(std::uint8_t v) { value(static_cast<std::uint64_t>(v)); }
  /// Floats by their bits: equal descriptions mean bit-identical values (-0.0 ≠ 0.0, a NaN
  /// equals itself), which is what "the same graph" means for a serialization format.
  void value(float v) { bits("f", float_bits(v)); }
  void value(double v) { bits("d", double_bits(v)); }
  void value(std::string_view v) {
    out_ += '"';
    for (const char c : v) {
      if (c == '"' || c == '\\') out_ += '\\';
      out_ += c;
    }
    out_ += '"';
  }
  void value(Bytes v) {
    static const char hex[] = "0123456789abcdef";
    out_ += "0x";
    for (const std::uint8_t b : v) {
      out_ += hex[b >> 4];
      out_ += hex[b & 15];
    }
  }
  void raw(const char* text) { out_ += text; }

 private:
  static std::uint64_t float_bits(float v) noexcept {
    std::uint32_t b = 0;
    std::memcpy(&b, &v, sizeof b);
    return b;
  }
  static std::uint64_t double_bits(double v) noexcept {
    std::uint64_t b = 0;
    std::memcpy(&b, &v, sizeof b);
    return b;
  }
  void bits(const char* prefix, std::uint64_t b) {
    char text[24];
    std::snprintf(text, sizeof text, "%s%llx", prefix, static_cast<unsigned long long>(b));
    out_ += text;
  }

  std::string out_;
  std::map<std::pair<unsigned, std::uint64_t>, std::size_t> seen_;
  std::size_t depth_ = 0;
  std::size_t max_depth_;
};

namespace detail {
template <class R, class T, class = void>
struct has_copy_to : std::false_type {};
template <class R, class T>
struct has_copy_to<R, T, std::void_t<decltype(std::declval<const R&>().copy_to(std::declval<T*>(), std::size_t{}))>>
    : std::true_type {};
}  // namespace detail

/// `out` becomes the elements of a numeric array range (spec/43): one block copy where the
/// range has `copy_to` and its wire form allows it, iteration otherwise.
template <class T, class R>
inline void assign_elements(std::vector<T>& out, const R& range) {
  if constexpr (detail::has_copy_to<R, T>::value) {
    out.resize(range.size());
    out.resize(range.copy_to(out.data(), out.size()));
  } else {
    out.clear();
    out.reserve(range.size());
    for (const auto& e : range) out.push_back(e);
  }
}

/// FNV-1a, 64-bit.
inline std::uint64_t fnv1a(std::string_view text) noexcept {
  std::uint64_t h = 0xcbf29ce484222325ull;
  for (const char c : text) {
    h ^= static_cast<std::uint8_t>(c);
    h *= 0x100000001b3ull;
  }
  return h;
}

}  // namespace dagr
