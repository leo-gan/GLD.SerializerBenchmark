// dagr/values.hpp — what the generated VALUE form needs from the runtime (spec/41 §8.3,
// §9): the payload cell of a union value, the scratch memory `restore_values` builds
// arrays in, and the restore context. Generated value structs, union values and restore
// functions (dagr/codegen/cpp/direct.py) are written against this header.
//
// A value tree BORROWS: strings and data are views of the caller's memory (or of the
// buffer a restore read), arrays are spans, a union holding a node points at it. Nothing
// here owns or frees anything a value refers to.
//
// Core tier: no allocation (a `Scratch` hands out the caller's memory), no exceptions, no
// RTTI, no containers.
#pragma once

#include <new>

#include "reader.hpp"

namespace dagr {

// ── Cell: the payload of a union value ─────────────────────────────────────────

/// One word and one pointer — what a generated union value holds beside its tag, 24 bytes
/// together. A word-sized variant (integer, float, bool, enum) lives in the word; a view
/// (utf8, data, an array) is pointer + length; a node or a nested union value is a pointer
/// to the caller's object. The generated class knows which of these its tag means, and is
/// the only thing that reads a Cell back — always as what it stored.
class Cell {
 public:
  constexpr Cell() noexcept = default;

  static constexpr Cell of_bits(std::uint64_t bits) noexcept { return Cell(bits, nullptr); }
  static Cell of_f32(float v) noexcept { return Cell(detail::bits<std::uint32_t>(v), nullptr); }
  static Cell of_f64(double v) noexcept { return Cell(detail::bits<std::uint64_t>(v), nullptr); }
  static constexpr Cell of_text(std::string_view s) noexcept { return Cell(s.size(), s.data()); }
  template <class T>
  static constexpr Cell of_span(Span<const T> s) noexcept {
    return Cell(s.size(), s.data());
  }
  /// Points at `v`, which must outlive every use of the value.
  template <class T>
  static constexpr Cell of_ref(const T& v) noexcept {
    return Cell(0, &v);
  }

  constexpr std::uint64_t bits() const noexcept { return num_; }
  float f32() const noexcept { return detail::bits<float>(static_cast<std::uint32_t>(num_)); }
  double f64() const noexcept { return detail::bits<double>(num_); }
  std::string_view text() const noexcept {
    return std::string_view(static_cast<const char*>(ptr_), static_cast<std::size_t>(num_));
  }
  template <class T>
  Span<const T> span() const noexcept {
    return Span<const T>(static_cast<const T*>(ptr_), static_cast<std::size_t>(num_));
  }
  template <class T>
  const T* ref() const noexcept {
    return static_cast<const T*>(ptr_);
  }

 private:
  constexpr Cell(std::uint64_t num, const void* ptr) noexcept : num_(num), ptr_(ptr) {}

  std::uint64_t num_ = 0;
  const void* ptr_ = nullptr;
};

/// What a union value's `visit` hands the visitor when the value holds no variant this
/// schema knows — default-constructed, or restored from a newer writer's bytes.
struct NoVariant {};

// ── Comparisons a writer's default elision makes (spec 14 §4) ──────────────────

/// Bitwise, so that an elided value is synthesized back bit for bit: -0.0 is not the
/// default 0.0, and a NaN default is matched by that NaN.
inline bool same_bits(float a, float b) noexcept {
  return detail::bits<std::uint32_t>(a) == detail::bits<std::uint32_t>(b);
}
inline bool same_bits(double a, double b) noexcept {
  return detail::bits<std::uint64_t>(a) == detail::bits<std::uint64_t>(b);
}

inline bool same_bytes(Bytes a, Bytes b) noexcept {
  return a.size() == b.size() && (a.empty() || std::memcmp(a.data(), b.data(), a.size()) == 0);
}

/// Element `i` of a caller's array (`i < s.size()` is the caller's claim, as for `[]`).
template <class T>
constexpr const T& nth(Span<const T> s, std::size_t i) noexcept {
  return s.data()[i];
}

// ── Scratch ────────────────────────────────────────────────────────────────────

/// Memory for the arrays a restore builds: a bump allocator over storage the caller
/// provides. Nothing is freed individually — `reset()` rewinds all of it, and the values
/// built in it die with that. A request that does not fit yields nothing and is
/// remembered (`exhausted()`); `HeapScratch` (dagr/writer.hpp) is the growing form.
class Scratch {
 public:
  constexpr Scratch() noexcept = default;
  Scratch(void* storage, std::size_t size) noexcept
      : begin_(static_cast<std::uint8_t*>(storage)), cur_(begin_), end_(begin_ + size) {}
  Scratch(const Scratch&) = delete;
  Scratch& operator=(const Scratch&) = delete;

  /// Uninitialized room for `n` objects of T, or nullptr. T must need no destructor:
  /// nothing will ever run one.
  template <class T>
  T* room(std::size_t n) noexcept {
    static_assert(std::is_trivially_destructible<T>::value, "scratch memory is never destroyed");
    if (n > static_cast<std::size_t>(-1) / sizeof(T)) {
      exhausted_ = true;
      return nullptr;
    }
    return static_cast<T*>(allocate(n * sizeof(T), alignof(T)));
  }

  /// A copy of `v` that lives as long as the scratch is not reset, or nullptr.
  template <class T>
  const T* keep(const T& v) noexcept {
    T* p = room<T>(1);
    return p != nullptr ? new (p) T(v) : nullptr;
  }

  bool exhausted() const noexcept { return exhausted_; }
  /// Why a request is refused: `buffer_full` for caller storage, `out_of_memory` for a
  /// growing scratch.
  Status failure() const noexcept { return failure_; }
  std::size_t used() const noexcept { return used_ + static_cast<std::size_t>(cur_ - begin_); }

  /// Invalidates everything handed out so far.
  void reset() noexcept {
    if (rewind_ != nullptr) rewind_(*this);
    cur_ = begin_;
    used_ = 0;
    exhausted_ = false;
  }

 protected:
  /// How a growing scratch gets another block of at least `bytes`: it re-points
  /// begin_ / cur_ / end_ and returns true, or returns false.
  using Refill = bool (*)(Scratch& self, std::size_t bytes);
  using Rewind = void (*)(Scratch& self);

  std::uint8_t* begin_ = nullptr;
  std::uint8_t* cur_ = nullptr;
  std::uint8_t* end_ = nullptr;
  std::size_t used_ = 0;         // bytes in blocks before the current one
  Refill refill_ = nullptr;
  Rewind rewind_ = nullptr;
  Status failure_ = Status::buffer_full;

 private:
  void* allocate(std::size_t bytes, std::size_t align) noexcept {
    for (int attempt = 0; attempt < 2; attempt++) {
      const std::size_t room_left = static_cast<std::size_t>(end_ - cur_);
      const std::size_t pad = (align - (reinterpret_cast<std::uintptr_t>(cur_) & (align - 1))) & (align - 1);
      if (pad <= room_left && bytes <= room_left - pad) {
        std::uint8_t* p = cur_ + pad;
        cur_ = p + bytes;
        return p;
      }
      // One refill, sized so that the request fits whatever the new block's alignment. (A
      // sum that wraps asks for a small block, which the second attempt then finds too small.)
      if (attempt == 1 || refill_ == nullptr) break;
      const std::size_t before = static_cast<std::size_t>(cur_ - begin_);
      if (!refill_(*this, bytes + align)) break;
      used_ += before;
    }
    exhausted_ = true;
    return nullptr;
  }

  bool exhausted_ = false;
};

// ── Restore ────────────────────────────────────────────────────────────────────

/// How deep a restore follows nested nodes and unions before it gives up. The walk is
/// recursive over the DATA, and a megabyte of bytes can nest half a million levels
/// (spec/41 §5 rule 7).
inline constexpr std::size_t default_max_depth = 128;

/// What the generated restore functions thread: where arrays go, how deep the walk may
/// still descend, and the first thing that went wrong.
class RestoreContext {
 public:
  RestoreContext(Scratch& scratch, std::size_t max_depth) noexcept : scratch_(scratch), depth_left_(max_depth) {}

  Scratch& scratch() noexcept { return scratch_; }
  Status status() const noexcept { return status_; }
  void fail(Status status) noexcept {
    if (status_ == Status::ok) status_ = status;
  }

 private:
  friend class Descent;
  Scratch& scratch_;
  std::size_t depth_left_;
  Status status_ = Status::ok;
};

/// One level of a restore's recursion: false when the depth limit is reached (recorded in
/// the context), and the restore then returns an empty value instead of descending.
class Descent {
 public:
  explicit Descent(RestoreContext& ctx) noexcept : ctx_(ctx), entered_(ctx.depth_left_ > 0) {
    if (entered_) ctx_.depth_left_--;
    else ctx_.fail(Status::depth_exceeded);
  }
  ~Descent() {
    if (entered_) ctx_.depth_left_++;
  }
  Descent(const Descent&) = delete;
  Descent& operator=(const Descent&) = delete;
  explicit operator bool() const noexcept { return entered_; }

 private:
  RestoreContext& ctx_;
  bool entered_;
};

/// The elements of a lazy `range`, each mapped by `make(element)` to a T, in scratch
/// memory. The count is the range's own — clamped against the buffer where the reader
/// recorded it — so a hostile count cannot ask for more than the buffer could hold. A
/// range that ends early (a cursor parked on malformed bytes) leaves the rest empty, and
/// nothing is written past the count whatever the range yields.
template <class T, class Range, class Make>
inline Span<const T> restore_array(RestoreContext& ctx, const Range& range, Make&& make) noexcept {
  const std::size_t n = range.size();
  if (n == 0) return Span<const T>();
  T* out = ctx.scratch().room<T>(n);
  if (out == nullptr) {
    ctx.fail(ctx.scratch().failure());
    return Span<const T>();
  }
  std::size_t i = 0;
  for (auto it = range.begin(); i < n && it != range.end(); ++it) {
    new (out + i) T(make(*it));
    i++;
  }
  for (; i < n; i++) new (out + i) T();
  return Span<const T>(out, n);
}

/// The elements of a lazy `range` copied as they are — scalars, enums, strings and data,
/// whose lazy type is already their value type.
template <class T, class Range>
inline Span<const T> restore_array(RestoreContext& ctx, const Range& range) noexcept {
  return restore_array<T>(ctx, range, [](const T& e) noexcept { return e; });
}

/// An arrayWithOptionals of nodes or unions: `make` maps each PRESENT element.
template <class T, class Range, class Make>
inline Span<const std::optional<T>> restore_opt_array(RestoreContext& ctx, const Range& range, Make&& make) noexcept {
  return restore_array<std::optional<T>>(ctx, range, [&make](const auto& e) noexcept {
    return e.has_value() ? std::optional<T>(make(*e)) : std::optional<T>();
  });
}

/// A copy of `v` in scratch memory — where a value points at another (a recursive node
/// field, a node or nested union inside a union value).
template <class T>
inline const T* restore_ref(RestoreContext& ctx, const T& v) noexcept {
  const T* p = ctx.scratch().keep(v);
  if (p == nullptr) ctx.fail(ctx.scratch().failure());
  return p;
}

}  // namespace dagr
