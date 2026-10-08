// dagr/shared_buffer.hpp — the SharedBuffer runtime (spec/20, spec/40; spec/41 §11): what a
// generated overlay calls to read and write a fixed-layout region in place.
//
// A SharedBuffer is a region of `ByteSize` bytes laid out by the language-neutral manifest
// (dagr/layout.py), so every target reads and writes the same bytes at the same offsets. A
// generated overlay holds the region's base pointer and a node's offset and calls these
// functions; it never touches memory itself (spec/41 §5).
//
//   * scalars: little-endian, unaligned-safe loads and stores (`sb_get` / `sb_put`) — the
//     same accessors run over a live region and over a snapshot copy;
//   * atomics: wrappers over the `__atomic_*` builtins on a 4- or 8-byte word, which must be
//     naturally aligned (the layout places every atomic word so, relative to a
//     RegionAlign-aligned base). Not `std::atomic_ref`: one path at every -std, and the
//     C target's <stdatomic.h> port is mechanical (spec/41 §11);
//   * `racy_copy`: the seqlock's payload copy, word-wise through relaxed atomic loads and
//     stores — the copy races BY DESIGN (the counter decides afterwards whether it was
//     torn), which is a data race unless every access is atomic. Same instructions, defined
//     behaviour, ThreadSanitizer-clean.
//
// Core tier: no allocation, no container. The region is the caller's — mmap'd, static,
// or from `dagr::Region` (dagr/writer.hpp).
#pragma once

#include <cstddef>
#include <cstdint>
#include <cstring>
#include <string_view>

#include "fixed_writer.hpp"
#include "reader.hpp"

namespace dagr {

// ── Plain loads and stores ─────────────────────────────────────────────────────

/// The `T` stored little-endian at `p + at`.
template <class T>
inline T sb_get(const std::uint8_t* p, std::size_t at) noexcept {
  T v;
  std::memcpy(&v, p + at, sizeof(T));
  if constexpr (sizeof(T) > 1) {
    using U = std::conditional_t<sizeof(T) == 2, std::uint16_t, std::conditional_t<sizeof(T) == 4, std::uint32_t, std::uint64_t>>;
    U u;
    std::memcpy(&u, &v, sizeof(T));
    u = detail::le(u);
    std::memcpy(&v, &u, sizeof(T));
  }
  return v;
}

/// Stores `v` little-endian at `p + at`.
template <class T>
inline void sb_put(std::uint8_t* p, std::size_t at, T v) noexcept {
  if constexpr (sizeof(T) > 1) {
    using U = std::conditional_t<sizeof(T) == 2, std::uint16_t, std::conditional_t<sizeof(T) == 4, std::uint32_t, std::uint64_t>>;
    U u;
    std::memcpy(&u, &v, sizeof(T));
    u = detail::le(u);
    std::memcpy(p + at, &u, sizeof(T));
  } else {
    std::memcpy(p + at, &v, 1);
  }
}

inline float sb_get_f16(const std::uint8_t* p, std::size_t at) noexcept { return f16_from_bits(sb_get<std::uint16_t>(p, at)); }
inline float sb_get_bf16(const std::uint8_t* p, std::size_t at) noexcept { return bf16_from_bits(sb_get<std::uint16_t>(p, at)); }
inline void sb_put_f16(std::uint8_t* p, std::size_t at, float v) noexcept { sb_put(p, at, f32_to_f16_bits(v)); }
inline void sb_put_bf16(std::uint8_t* p, std::size_t at, float v) noexcept { sb_put(p, at, f32_to_bf16_bits(v)); }
inline bool sb_get_bool(const std::uint8_t* p, std::size_t at) noexcept { return p[at] != 0; }
inline void sb_put_bool(std::uint8_t* p, std::size_t at, bool v) noexcept { p[at] = v ? 1 : 0; }

/// An unsigned value of `width` bytes (1, 2, 4 or 8) — a length or a union tag.
inline std::uint64_t sb_get_uint(const std::uint8_t* p, std::size_t at, std::size_t width) noexcept {
  switch (width) {
    case 1: return p[at];
    case 2: return sb_get<std::uint16_t>(p, at);
    case 4: return sb_get<std::uint32_t>(p, at);
    default: return sb_get<std::uint64_t>(p, at);
  }
}

inline void sb_put_uint(std::uint8_t* p, std::size_t at, std::size_t width, std::uint64_t v) noexcept {
  switch (width) {
    case 1: p[at] = static_cast<std::uint8_t>(v); break;
    case 2: sb_put(p, at, static_cast<std::uint16_t>(v)); break;
    case 4: sb_put(p, at, static_cast<std::uint32_t>(v)); break;
    default: sb_put(p, at, v); break;
  }
}

/// A length stored in `width` bytes at `p + at`, clamped to `cap`: the region may be
/// shared with another process and is not trusted to hold a length within its capacity.
inline std::size_t sb_len(const std::uint8_t* p, std::size_t at, std::size_t width, std::size_t cap) noexcept {
  const std::uint64_t n = sb_get_uint(p, at, width);
  return n > cap ? cap : static_cast<std::size_t>(n);
}

// ── Bits ───────────────────────────────────────────────────────────────────────

inline bool sb_bit(const std::uint8_t* p, std::size_t byte, unsigned bit) noexcept { return ((p[byte] >> bit) & 1u) != 0; }
inline void sb_set_bit(std::uint8_t* p, std::size_t byte, unsigned bit) noexcept {
  p[byte] = static_cast<std::uint8_t>(p[byte] | (1u << bit));
}
inline void sb_clear_bit(std::uint8_t* p, std::size_t byte, unsigned bit) noexcept {
  p[byte] = static_cast<std::uint8_t>(p[byte] & ~(1u << bit));
}
inline void sb_put_bit(std::uint8_t* p, std::size_t byte, unsigned bit, bool v) noexcept {
  if (v) {
    sb_set_bit(p, byte, bit);
  } else {
    sb_clear_bit(p, byte, bit);
  }
}

/// `bits` bits at bit `bit` of byte `byte` (a sub-byte enum or tag; never crosses a byte).
inline unsigned sb_bits(const std::uint8_t* p, std::size_t byte, unsigned bit, unsigned bits) noexcept {
  return (p[byte] >> bit) & ((1u << bits) - 1u);
}
inline void sb_put_bits(std::uint8_t* p, std::size_t byte, unsigned bit, unsigned bits, unsigned v) noexcept {
  const unsigned mask = (1u << bits) - 1u;
  p[byte] = static_cast<std::uint8_t>((p[byte] & ~(mask << bit)) | ((v & mask) << bit));
}

/// The `i`-th of an array of `bits`-wide elements starting at byte `base` (they may span
/// a byte boundary only when `bits` does not divide 8, which the layout never produces).
inline unsigned sb_elem_bits(const std::uint8_t* p, std::size_t base, std::size_t i, unsigned bits) noexcept {
  const std::size_t bit = i * bits;
  return sb_bits(p, base + (bit >> 3), static_cast<unsigned>(bit & 7u), bits);
}
inline void sb_put_elem_bits(std::uint8_t* p, std::size_t base, std::size_t i, unsigned bits, unsigned v) noexcept {
  const std::size_t bit = i * bits;
  sb_put_bits(p, base + (bit >> 3), static_cast<unsigned>(bit & 7u), bits, v);
}

// ── Byte ranges ────────────────────────────────────────────────────────────────

inline void sb_zero(std::uint8_t* p, std::size_t at, std::size_t n) noexcept { std::memset(p + at, 0, n); }

/// `n` bytes at `p + at`, as a view of the region (valid as long as the region is).
inline Bytes sb_view(const std::uint8_t* p, std::size_t at, std::size_t n) noexcept { return Bytes(p + at, n); }
inline std::string_view sb_text(const std::uint8_t* p, std::size_t at, std::size_t n) noexcept {
  return std::string_view(reinterpret_cast<const char*>(p + at), n);
}
inline void sb_put_bytes(std::uint8_t* p, std::size_t at, const void* src, std::size_t n) noexcept {
  if (n != 0) std::memcpy(p + at, src, n);
}
inline void sb_put_bytes(std::uint8_t* p, std::size_t at, Bytes src) noexcept { sb_put_bytes(p, at, src.data(), src.size()); }
inline void sb_put_text(std::uint8_t* p, std::size_t at, std::string_view src) noexcept {
  sb_put_bytes(p, at, src.data(), src.size());
}

// ── Atomics ────────────────────────────────────────────────────────────────────
//
// On a naturally aligned 4- or 8-byte word at `p + at`. Sequentially consistent unless the
// name says otherwise: every SharedBuffer protocol here is a handful of operations per
// record, and the cost of a weaker order is a correctness argument per call site.

namespace detail {
template <class W>
inline W* word(std::uint8_t* p, std::size_t at) noexcept {
  return reinterpret_cast<W*>(p + at);
}
template <class W>
inline const W* word(const std::uint8_t* p, std::size_t at) noexcept {
  return reinterpret_cast<const W*>(p + at);
}
}  // namespace detail

template <class W>
inline W atomic_load(const std::uint8_t* p, std::size_t at) noexcept {
  return __atomic_load_n(detail::word<W>(p, at), __ATOMIC_SEQ_CST);
}
template <class W>
inline W atomic_load_acquire(const std::uint8_t* p, std::size_t at) noexcept {
  return __atomic_load_n(detail::word<W>(p, at), __ATOMIC_ACQUIRE);
}
template <class W>
inline void atomic_store(std::uint8_t* p, std::size_t at, W v) noexcept {
  __atomic_store_n(detail::word<W>(p, at), v, __ATOMIC_SEQ_CST);
}
template <class W>
inline void atomic_store_release(std::uint8_t* p, std::size_t at, W v) noexcept {
  __atomic_store_n(detail::word<W>(p, at), v, __ATOMIC_RELEASE);
}
/// Adds `d` and returns the NEW value.
template <class W>
inline W atomic_add(std::uint8_t* p, std::size_t at, W d) noexcept {
  return __atomic_add_fetch(detail::word<W>(p, at), d, __ATOMIC_SEQ_CST);
}
/// Stores `v` and returns the old value.
template <class W>
inline W atomic_swap(std::uint8_t* p, std::size_t at, W v) noexcept {
  return __atomic_exchange_n(detail::word<W>(p, at), v, __ATOMIC_SEQ_CST);
}
/// Stores `desired` if the word holds `expected`; whether it did.
template <class W>
inline bool atomic_cas(std::uint8_t* p, std::size_t at, W expected, W desired) noexcept {
  return __atomic_compare_exchange_n(detail::word<W>(p, at), &expected, desired, false, __ATOMIC_SEQ_CST,
                                     __ATOMIC_SEQ_CST);
}

/// A float as the word an `atomic` region stores it in, and back.
inline std::uint32_t sb_word(float v) noexcept { return detail::bits<std::uint32_t>(v); }
inline std::uint64_t sb_word(double v) noexcept { return detail::bits<std::uint64_t>(v); }
inline float sb_f32(std::uint32_t w) noexcept { return detail::bits<float>(w); }
inline double sb_f64(std::uint64_t w) noexcept { return detail::bits<double>(w); }

/// Whether `p` is a multiple of `align` — what a region's base must be for its atomics.
inline bool sb_aligned(const void* p, std::size_t align) noexcept {
  return align <= 1 || (reinterpret_cast<std::uintptr_t>(p) & (align - 1)) == 0;
}

/// The seqlock's payload copy (spec/41 §11): `n` bytes from `src` to `dst`, every access a
/// relaxed atomic — word-wise where both sides are 8-byte aligned, byte-wise for the rest.
/// The copy may race with a writer; whoever calls it decides afterwards from the counter
/// whether to keep it.
inline void racy_copy(std::uint8_t* dst, const std::uint8_t* src, std::size_t n) noexcept {
  std::size_t i = 0;
  if (sb_aligned(dst, 8) && sb_aligned(src, 8)) {
    for (; i + 8 <= n; i += 8) {
      const std::uint64_t w = __atomic_load_n(reinterpret_cast<const std::uint64_t*>(src + i), __ATOMIC_RELAXED);
      __atomic_store_n(reinterpret_cast<std::uint64_t*>(dst + i), w, __ATOMIC_RELAXED);
    }
  }
  for (; i < n; i++) {
    __atomic_store_n(dst + i, __atomic_load_n(src + i, __ATOMIC_RELAXED), __ATOMIC_RELAXED);
  }
}

/// `N` bytes aligned to `Align`, zeroed — a seqlock's staging copy of the payload, held
/// inside the generated `Seqlock` (no allocation).
template <std::size_t N, std::size_t Align>
struct alignas(Align) RegionBuffer {
  std::uint8_t bytes[N] = {};
  std::uint8_t* region() noexcept { return bytes; }
};

/// A full fence: what orders the seqlock writer's payload stores against its counter.
inline void atomic_fence() noexcept { __atomic_thread_fence(__ATOMIC_SEQ_CST); }

}  // namespace dagr
