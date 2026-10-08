// dagr/graph_writer.hpp — the write side of the generated ARENAS (spec/41-cpp-codegen-plan.md
// §8.5, milestone 8): what a whole graph needs beyond the packed stores of
// dagr/fixed_writer.hpp — regular (vtable) and frozen (positional) nodes, the regular
// arrays and union slots they point at, the three dedup caches, and late binding for
// cycles. A port of the Python reference writer (dagr/runtime/dagr_writer.py), which is
// byte-identical to the Swift and Rust writers on the whole corpus.
//
// Every store is still a template over the BUILDER (`dagr::FixedBuilder`, `dagr::Builder`),
// which here must also have `ok()` and `written(at)` — the graph writer reads back what it
// stored to compare a string with a cached one, and patches a late-bound reference in place.
// Failure stays sticky (a failed claim leaves the builder no room), and a vtable entry or a
// reference the wire cannot hold fails the builder with `invalid_value`.
//
// Offsets. A stored thing is named by the builder's cursor right after it was stored — the
// number of bytes from its first byte to the end of the record. Offsets survive the growing
// builder's reallocation (the record grows at its front), and a pointer is the difference
// of two of them.
//
// Model tier: std::vector (the caches). No exceptions, no RTTI.
#pragma once

#include <optional>
#include <vector>

#include "fixed_writer.hpp"

namespace dagr {

// ── An open-addressing index ───────────────────────────────────────────────────

/// Maps a 64-bit hash to the entries stored under it — indices into a vector the caller
/// owns — with linear probing. Equal hashes are told apart by the caller's predicate.
/// `clear()` is O(1): a slot is occupied only under the current epoch, so a writer reused
/// across records does not re-zero its tables.
class IndexTable {
 public:
  static constexpr std::uint32_t none = 0xffffffffu;

  /// The entry under `hash` for which `same(entry)` holds, or `none`.
  template <class Same>
  std::uint32_t find(std::uint64_t hash, Same&& same) const noexcept {
    if (slots_.empty()) return none;
    const std::size_t mask = slots_.size() - 1;
    for (std::size_t i = static_cast<std::size_t>(hash) & mask;; i = (i + 1) & mask) {
      const Slot& s = slots_[i];
      if (s.epoch != epoch_) return none;
      if (s.hash == hash && same(s.entry)) return s.entry;
    }
  }

  void insert(std::uint64_t hash, std::uint32_t entry) {
    if ((used_ + 1) * 2 > slots_.size()) grow();
    put(hash, entry);
    used_++;
  }

  void clear() noexcept {
    used_ = 0;
    if (++epoch_ == 0) {                 // wrapped: no stale slot may look current
      for (Slot& s : slots_) s.epoch = 0;
      epoch_ = 1;
    }
  }

 private:
  struct Slot {
    std::uint64_t hash;
    std::uint32_t entry;
    std::uint32_t epoch;
  };

  void put(std::uint64_t hash, std::uint32_t entry) noexcept {
    const std::size_t mask = slots_.size() - 1;
    std::size_t i = static_cast<std::size_t>(hash) & mask;
    while (slots_[i].epoch == epoch_) i = (i + 1) & mask;
    slots_[i] = Slot{hash, entry, epoch_};
  }

  void grow() {
    std::vector<Slot> old;
    old.swap(slots_);
    slots_.assign(old.empty() ? 64 : old.size() * 2, Slot{0, 0, 0});
    const std::uint32_t was = epoch_;
    epoch_ = 1;
    for (const Slot& s : old) {
      if (s.epoch == was) put(s.hash, s.entry);
    }
  }

  std::vector<Slot> slots_;
  std::size_t used_ = 0;
  std::uint32_t epoch_ = 1;
};

namespace detail {

constexpr std::uint64_t mix(std::uint64_t x) noexcept {   // splitmix64's finalizer
  x ^= x >> 30;
  x *= 0xbf58476d1ce4e5b9ull;
  x ^= x >> 27;
  x *= 0x94d049bb133111ebull;
  return x ^ (x >> 31);
}

inline std::uint64_t hash_bytes(const std::uint8_t* p, std::size_t n) noexcept {
  std::uint64_t h = 0xcbf29ce484222325ull ^ n;
  for (std::size_t i = 0; i < n; i++) {
    h ^= p[i];
    h *= 0x100000001b3ull;
  }
  return mix(h);
}

/// `v` as the `es`-byte little-endian integer (two's complement for a signed one).
inline void put_le_n(std::uint8_t* p, std::uint64_t v, std::size_t es) noexcept {
  for (std::size_t i = 0; i < es; i++) {
    p[i] = static_cast<std::uint8_t>(v);
    v >>= 8;
  }
}

constexpr unsigned unsigned_width_code(std::uint64_t v) noexcept {
  return v <= 0xffu ? 0u : v <= 0xffffu ? 1u : v <= 0xffffffffu ? 2u : 3u;
}

constexpr unsigned signed_width_code(std::int64_t d) noexcept {
  return (d >= -128 && d <= 127) ? 0u : (d >= -32768 && d <= 32767) ? 1u
         : (d >= -2147483647 - 1 && d <= 2147483647) ? 2u : 3u;
}

}  // namespace detail

// ── References to stored nodes ─────────────────────────────────────────────────

/// A stored node — its offset — or, for a node still being stored (an ancestor on the
/// path a cycle leads back to), a PENDING reference to it: a pointer to it is written as a
/// placeholder and patched when the node is finished (`GraphWriter::finish`).
struct NodeRef {
  static constexpr std::uint32_t resolved = 0xffffffffu;
  static constexpr std::uint32_t none = 0xfffffffeu;
  std::size_t off = 0;
  std::uint32_t pending = resolved;   // the in-flight node's entry, when not resolved
  constexpr bool is_resolved() const noexcept { return pending == resolved; }
  /// No node: a nil element of a node arrayWithOptionals.
  static constexpr NodeRef nil() noexcept { return NodeRef{0, none}; }
  constexpr bool is_nil() const noexcept { return pending == none; }
};

/// What a union field's first pass stored, for its slot (the second pass) to point at or
/// hold — `store_union_slot` writes it (spec 04 §4.9). An inline VALUE is `width` bytes of
/// `bits`; a FORWARD pointer targets offset `off`; a NODE is a bidirectional pointer.
struct UnionApplied {
  enum Kind : std::uint8_t { value, forward, node };
  std::uint64_t id = 0;
  Kind kind = value;
  std::uint8_t width = 1;
  std::uint64_t bits = 0;
  NodeRef ref{};
};

/// One element of a regular / frozen union ARRAY (spec 04 §4.9): its slot is a value's bit
/// pattern (`value`), a distance to content (`forward`), or a distance to a node, doubled
/// (`node`). `present` false is a nil element of an arrayWithOptionals.
struct UnionElem {
  std::uint64_t id = 0;
  UnionApplied::Kind kind = UnionApplied::value;
  bool present = false;
  std::uint64_t val = 0;
};

// ── The caches ──────────────────────────────────────────────────────────────────

/// The state a graph serialization keeps beside the builder: the node dedup cache (a node
/// stored once, pointed at from every reference — the sharing and cycles of the graph),
/// the vtable and string dedup caches, and the late bindings of the references to nodes
/// still in flight. Reusable: `reset()` keeps every allocation, so an encode loop settles
/// on its largest record and allocates nothing more.
///
/// `max_size` is the largest buffer the producer expects; it fixes the width of a cycle's
/// placeholder pointer (2 MiB → 4 bytes, as every other writer's default) and must match
/// across producers for byte identity.
class GraphCaches {
 public:
  explicit GraphCaches(std::size_t max_size = 2 * 1024 * 1024) noexcept : reserve_(reserve_width(max_size)) {}

  void reset() noexcept {
    node_index_.clear();
    nodes_.clear();
    vt_index_.clear();
    vts_.clear();
    vt_pool_.clear();
    str_index_.clear();
    strs_.clear();
    binds_.clear();
  }

  /// The placeholder width of a reference to a node in flight: 2, 4 or 8 bytes.
  std::size_t reserve() const noexcept { return reserve_; }

 private:
  template <class B>
  friend class GraphWriter;

  /// bits = bitlen(max_size) + 3; width = the power of two of bytes that holds them —
  /// exactly the Swift / Rust `with_max_size` rule.
  static std::size_t reserve_width(std::size_t max_size) noexcept {
    std::size_t bitlen = 0;
    for (std::size_t v = max_size; v != 0; v >>= 1) bitlen++;
    const std::size_t bits = bitlen + 3;
    const std::size_t bytes = (bits + 7) / 8;
    std::size_t w = 1;
    while (w < bytes) w <<= 1;
    return w < 2 ? 2 : w;
  }

  struct NodeEntry {
    std::uint64_t type;
    std::uint64_t handle;
    std::size_t off;          // valid once done
    std::uint32_t binds;      // first late binding against it, or none
    bool done;
  };
  struct VtEntry {
    std::size_t at;           // into vt_pool_
    std::size_t len;
    std::size_t off;
  };
  struct Binding {
    std::uint32_t next;
    std::size_t at;           // the placeholder: written(at) is its first byte
    std::size_t base;         // a field pointer's cursor before the placeholder
    std::size_t array_end;    // a node array's slot base, or npos for a field pointer
    std::size_t es;
  };

  IndexTable node_index_;
  std::vector<NodeEntry> nodes_;
  IndexTable vt_index_;
  std::vector<VtEntry> vts_;
  std::vector<std::uint32_t> vt_pool_;
  IndexTable str_index_;
  std::vector<std::size_t> strs_;
  std::vector<Binding> binds_;
  std::vector<std::size_t> scratch_;     // a vtable's entries, normalized
  std::size_t reserve_;
};

// ── The graph writer ────────────────────────────────────────────────────────────

/// A builder and its caches, threaded through the generated node stores. Generated code
/// calls the stores below with it; nothing here knows a schema.
template <class B>
class GraphWriter {
 public:
  GraphWriter(B& b, GraphCaches& caches) noexcept : b_(b), c_(caches) {}

  B& builder() noexcept { return b_; }
  GraphCaches& caches() noexcept { return c_; }
  std::size_t cursor() const noexcept { return b_.cursor(); }
  bool ok() const noexcept { return b_.ok(); }
  void fail(Status s) noexcept { b_.fail(s); }

  // ── Node dedup and late binding (regular and frozen nodes) ──

  /// What `begin` found: a stored node (`done`, `ref` resolved), an ancestor still being
  /// stored (`done`, `ref` pending — a cycle), or a node to store now (`entry` names it
  /// for `finish`).
  struct Begun {
    bool done;
    NodeRef ref;
    std::uint32_t entry;
  };

  Begun begin(std::uint64_t type, std::uint64_t handle) {
    const std::uint64_t h = node_hash(type, handle);
    const std::uint32_t e = find_node(h, type, handle);
    if (e != IndexTable::none) {
      const GraphCaches::NodeEntry& n = c_.nodes_[e];
      return n.done ? Begun{true, NodeRef{n.off, NodeRef::resolved}, e} : Begun{true, NodeRef{0, e}, e};
    }
    const std::uint32_t entry = static_cast<std::uint32_t>(c_.nodes_.size());
    c_.nodes_.push_back(GraphCaches::NodeEntry{type, handle, 0, IndexTable::none, false});
    c_.node_index_.insert(h, entry);
    return Begun{false, NodeRef{}, entry};
  }

  /// The node `entry` is stored at `off`: every placeholder written against it is patched,
  /// and later references find it.
  NodeRef finish(std::uint32_t entry, std::size_t off) noexcept {
    GraphCaches::NodeEntry& n = c_.nodes_[entry];
    n.off = off;
    n.done = true;
    for (std::uint32_t i = n.binds; i != IndexTable::none; i = c_.binds_[i].next) {
      const GraphCaches::Binding& bd = c_.binds_[i];
      std::uint8_t* p = b_.written(bd.at);
      if (p == nullptr) continue;            // the builder failed: nothing left to patch
      if (bd.array_end != npos) {
        // a node array's slot: the raw two's-complement distance, + 1
        detail::put_le_n(p, static_cast<std::uint64_t>(bd.array_end) - off + 1u, bd.es);
      } else {
        // a field pointer: a ZigZag V62 at the reserved width
        const std::int64_t d = static_cast<std::int64_t>(bd.base) - static_cast<std::int64_t>(off);
        const unsigned wc = bd.es == 2 ? 1u : bd.es == 4 ? 2u : 3u;
        detail::put_le_n(p, (zigzag_encode(d) << 2) | wc, bd.es);
      }
    }
    n.binds = IndexTable::none;
    return NodeRef{off, NodeRef::resolved};
  }

  /// A packed node already stored (a packed node is a tree: its cache holds no node in
  /// flight), or nothing.
  std::optional<std::size_t> cached(std::uint64_t type, std::uint64_t handle) const noexcept {
    const std::uint32_t e = find_node(node_hash(type, handle), type, handle);
    if (e == IndexTable::none || !c_.nodes_[e].done) return std::nullopt;
    return c_.nodes_[e].off;
  }

  /// Registers a packed node stored at `off` (only a node DECLARED packed: a regular or
  /// frozen node inlined by a packed parent is a private copy, spec 07 §5.1).
  /// A node inlined again (a packed parent holds no pointer) replaces the earlier copy: a
  /// later pointer reaches the most recent one, as in every other writer.
  void cache(std::uint64_t type, std::uint64_t handle, std::size_t off) {
    const std::uint64_t h = node_hash(type, handle);
    const std::uint32_t e = find_node(h, type, handle);
    if (e != IndexTable::none) {
      c_.nodes_[e].off = off;
      return;
    }
    const std::uint32_t entry = static_cast<std::uint32_t>(c_.nodes_.size());
    c_.nodes_.push_back(GraphCaches::NodeEntry{type, handle, off, IndexTable::none, true});
    c_.node_index_.insert(h, entry);
  }

  // ── Pointers ──

  /// A V62 of `value`, at least `min_code` wide (0 → 1 byte … 3 → 8 bytes).
  void store_v62(std::uint64_t value, unsigned min_code = 0) noexcept {
    if (value < (std::uint64_t{1} << 6) && min_code == 0) {
      store_u8(b_, static_cast<std::uint8_t>(value << 2));
    } else if (value < (std::uint64_t{1} << 14) && min_code <= 1) {
      store_fixed(b_, static_cast<std::uint16_t>((value << 2) | (min_code > 1 ? min_code : 1u)));
    } else if (value < (std::uint64_t{1} << 30) && min_code <= 2) {
      store_fixed(b_, static_cast<std::uint32_t>((value << 2) | (min_code > 2 ? min_code : 2u)));
    } else if (value < (std::uint64_t{1} << 62)) {
      store_fixed(b_, (value << 2) | 3u);
    } else {
      b_.fail(Status::invalid_value);
    }
  }

  /// A forward pointer to the content stored at `off`.
  void store_forward_pointer(std::size_t off) noexcept { store_v62(b_.cursor() - off); }

  /// A bidirectional pointer to a node: ZigZag V62 of the distance, or — to a node still
  /// in flight — a placeholder of the reserved width, patched by `finish`.
  void store_bidirectional_pointer(const NodeRef& ref) {
    const std::size_t base = b_.cursor();
    if (ref.is_resolved()) {
      store_v62(zigzag_encode(static_cast<std::int64_t>(base) - static_cast<std::int64_t>(ref.off)));
      return;
    }
    store_zeros(b_, c_.reserve_);
    bind(ref.pending, b_.cursor(), base, npos, c_.reserve_);
  }

  // ── utf8 / data content ──

  /// `[LEB count][bytes]`, the same string stored once (spec 07 §5): its offset.
  std::size_t utf8(std::string_view s) {
    const Bytes bytes = as_bytes(s);
    const std::uint64_t h = detail::hash_bytes(bytes.data(), bytes.size());
    const std::uint32_t e = c_.str_index_.find(h, [&](std::uint32_t i) noexcept { return stored_blob_is(c_.strs_[i], bytes); });
    if (e != IndexTable::none) return c_.strs_[e];
    store_blob(b_, bytes);
    const std::size_t off = b_.cursor();
    if (b_.ok()) {
      c_.str_index_.insert(h, static_cast<std::uint32_t>(c_.strs_.size()));
      c_.strs_.push_back(off);
    }
    return off;
  }

  /// `[LEB count][bytes]` — data is never deduplicated.
  std::size_t data(Bytes bytes) noexcept {
    store_blob(b_, bytes);
    return b_.cursor();
  }

  // ── The vtable (regular nodes, spec 05) ──

  /// Stores the vtable of a node whose field slots were stored at `offsets` (forward index
  /// order; 0 = absent), deduplicated, and returns the node's offset. A slot more than
  /// 65535 bytes before the header cannot be written: `invalid_value`.
  std::size_t store_vtable(Span<const std::size_t> offsets) {
    std::vector<std::size_t>& norm = c_.scratch_;
    norm.clear();
    const std::size_t cur = b_.cursor();
    bool wide = false;
    for (const std::size_t off : offsets) {
      const std::size_t v = off == 0 ? 0 : cur - off + 1;
      if (v > 0xffffu) {
        b_.fail(Status::invalid_value);
        return b_.cursor();
      }
      wide = wide || v > 0xffu;
      norm.push_back(v);
    }
    std::uint64_t h = wide ? 0x77u : 0x6eu;
    for (const std::size_t v : norm) h = detail::mix(h ^ v);
    const std::uint32_t hit = c_.vt_index_.find(h, [&](std::uint32_t i) noexcept {
      const GraphCaches::VtEntry& vt = c_.vts_[i];
      if (vt.len != norm.size()) return false;
      for (std::size_t k = 0; k < vt.len; k++) {
        if (c_.vt_pool_[vt.at + k] != norm[k]) return false;
      }
      return true;
    });
    if (hit != IndexTable::none) {
      // a vtable already stored: an EVEN marker, the distance to it doubled
      store_leb(b_, static_cast<std::uint64_t>(b_.cursor() - c_.vts_[hit].off) << 1);
      return b_.cursor();
    }
    const std::size_t n = norm.size();
    const std::uint64_t cnt = wide ? (static_cast<std::uint64_t>(n) << 1) | 1u : static_cast<std::uint64_t>(n) << 1;
    const std::size_t size = (!wide && cnt == 0) ? 0 : leb_length(cnt) + n * (wide ? 2 : 1);
    store_leb(b_, size == 0 ? 0 : ((static_cast<std::uint64_t>(size) - 1) << 1) | 1u);
    const std::size_t result = b_.cursor();
    const std::size_t es = wide ? 2 : 1;
    if (n != 0) {
      if (std::uint8_t* p = b_.claim(n * es)) {
        for (std::size_t k = 0; k < n; k++) detail::put_le_n(p + k * es, norm[k], es);
      }
    }
    store_leb(b_, cnt);
    if (b_.ok()) {
      c_.vt_index_.insert(h, static_cast<std::uint32_t>(c_.vts_.size()));
      c_.vts_.push_back(GraphCaches::VtEntry{c_.vt_pool_.size(), n, b_.cursor()});
      for (const std::size_t v : norm) c_.vt_pool_.push_back(static_cast<std::uint32_t>(v));
    }
    return result;
  }

  // ── Arrays of node references (spec 04 §4.7) ──

  /// `[LEB (count << 2) | wc][count × es signed slots]` over the element nodes `refs`,
  /// already stored (a pending one is patched by `finish`; a nil one is slot 0). Returns
  /// the array's offset.
  std::size_t store_node_ref_array(Span<const NodeRef> refs) {
    const std::size_t n = refs.size();
    const std::size_t cur = b_.cursor();
    unsigned wc = 0;
    bool pending = false;
    for (std::size_t i = 0; i < n; i++) {
      const NodeRef& r = refs[i];
      if (r.is_nil()) continue;
      if (r.is_resolved()) {
        const unsigned c = detail::signed_width_code(static_cast<std::int64_t>(cur - r.off + 1));
        if (c > wc) wc = c;
      } else {
        pending = true;
      }
    }
    const unsigned reserve_wc = c_.reserve_ == 2 ? 1u : c_.reserve_ == 4 ? 2u : 3u;
    if (pending && wc < reserve_wc) wc = reserve_wc;
    const std::size_t es = std::size_t{1} << wc;
    if (n != 0) {
      if (std::uint8_t* p = b_.claim(n * es)) {
        const std::size_t first = b_.cursor();
        for (std::size_t i = 0; i < n; i++) {
          const NodeRef& r = refs[i];
          std::uint64_t v = 0;
          if (r.is_resolved()) v = static_cast<std::uint64_t>(cur - r.off + 1);
          detail::put_le_n(p + i * es, v, es);
          if (!r.is_resolved() && !r.is_nil()) bind(r.pending, first - i * es, 0, cur, es);
        }
      }
    }
    store_leb(b_, (static_cast<std::uint64_t>(n) << 2) | wc);
    return b_.cursor();
  }

  /// A pointer table `[LEB (count << 2) | wc][count × es unsigned slots]` over utf8 / data
  /// elements stored at `offsets` (0 = nil). Returns the table's offset.
  std::size_t store_ptr_table(Span<const std::size_t> offsets) noexcept {
    const std::size_t n = offsets.size();
    const std::size_t cur = b_.cursor();
    unsigned wc = 0;
    for (const std::size_t off : offsets) {
      if (off == 0) continue;
      const unsigned c = detail::unsigned_width_code(cur - off + 1);
      if (c > wc) wc = c;
    }
    const std::size_t es = std::size_t{1} << wc;
    if (n != 0) {
      if (std::uint8_t* p = b_.claim(n * es)) {
        for (std::size_t i = 0; i < n; i++) {
          detail::put_le_n(p + i * es, offsets[i] == 0 ? 0 : cur - offsets[i] + 1, es);
        }
      }
    }
    store_leb(b_, (static_cast<std::uint64_t>(n) << 2) | wc);
    return b_.cursor();
  }

  // ── Unions in regular / frozen nodes (spec 04 §4.9) ──

  /// The slot of a union FIELD: the value or pointer, then `LEB (id << 2) | wc` — wc the
  /// slot's width code. Returns the field's offset.
  std::size_t store_union_slot(const UnionApplied& a) {
    const std::size_t before = b_.cursor();
    emit(a);
    const std::size_t n = b_.cursor() - before;
    const unsigned wc = n == 1 ? 0u : n == 2 ? 1u : n == 4 ? 2u : 3u;
    store_leb(b_, (a.id << 2) | wc);
    return b_.cursor();
  }

  /// A NESTED union value (a union variant of a union): `LEB id << 2` — no width code.
  std::size_t store_nested_union_slot(const UnionApplied& a) {
    emit(a);
    store_leb(b_, a.id << 2);
    return b_.cursor();
  }

  /// A union ARRAY: `[LEB (count << 2) | wc][count slots][nil bitset?][type ids][…]`,
  /// the elements' content already stored. `bits_per` is the type id's width (1, 2, 4 or
  /// 8+: a byte each). Returns its offset.
  std::size_t store_union_array(Span<const UnionElem> elems, unsigned bits_per, bool opt) noexcept {
    const std::size_t n = elems.size();
    const std::size_t content_end = b_.cursor();
    unsigned wc = 0;
    for (const UnionElem& e : elems) {
      if (!e.present) continue;
      const unsigned c = detail::unsigned_width_code(slot_of(e, content_end));
      if (c > wc) wc = c;
    }
    const std::size_t es = std::size_t{1} << wc;
    const std::size_t nb = opt ? (n + 7) / 8 : 0;
    const std::size_t tb = bits_per < 8 ? (n * bits_per + 7) / 8 : n;
    const std::size_t total = n * es + nb + tb;
    if (total != 0) {
      if (std::uint8_t* p = b_.claim(total)) {
        std::memset(p, 0, total);
        std::uint8_t* types = p;
        std::uint8_t* nils = p + tb;
        std::uint8_t* slots = nils + nb;
        const std::size_t per = bits_per < 8 ? 8 / bits_per : 1;
        const std::uint64_t mask = bits_per < 8 ? (std::uint64_t{1} << bits_per) - 1u : 0xffu;
        for (std::size_t i = 0; i < n; i++) {
          const UnionElem& e = elems[i];
          if (!e.present) {
            if (opt) detail::set_bit(nils, i);
            continue;
          }
          detail::put_le_n(slots + i * es, slot_of(e, content_end), es);
          if (bits_per < 8) {
            types[i / per] = static_cast<std::uint8_t>(types[i / per] | ((e.id & mask) << ((i % per) * bits_per)));
          } else {
            types[i] = static_cast<std::uint8_t>(e.id);
          }
        }
      }
    }
    store_leb(b_, (static_cast<std::uint64_t>(n) << 2) | wc);
    return b_.cursor();
  }

 private:
  static std::uint64_t node_hash(std::uint64_t type, std::uint64_t handle) noexcept {
    return detail::mix(handle ^ detail::mix(type + 0x9e3779b97f4a7c15ull));
  }

  std::uint32_t find_node(std::uint64_t h, std::uint64_t type, std::uint64_t handle) const noexcept {
    return c_.node_index_.find(h, [&](std::uint32_t i) noexcept {
      return c_.nodes_[i].type == type && c_.nodes_[i].handle == handle;
    });
  }

  void bind(std::uint32_t entry, std::size_t at, std::size_t base, std::size_t array_end, std::size_t es) {
    if (!b_.ok()) return;
    GraphCaches::NodeEntry& n = c_.nodes_[entry];
    c_.binds_.push_back(GraphCaches::Binding{n.binds, at, base, array_end, es});
    n.binds = static_cast<std::uint32_t>(c_.binds_.size() - 1);
  }

  /// Whether the `[LEB count][bytes]` stored at `off` holds exactly `bytes`.
  bool stored_blob_is(std::size_t off, Bytes bytes) noexcept {
    const std::uint8_t* p = b_.written(off);
    if (p == nullptr) return false;
    // The length prefixes are compared first: a stored blob of another length differs
    // there, so the bytes compared after it are the stored blob's own.
    const std::size_t ln = leb_length(bytes.size());
    std::uint8_t expect[10];
    detail::put_leb(expect, bytes.size());
    return std::memcmp(p, expect, ln) == 0 && (bytes.empty() || std::memcmp(p + ln, bytes.data(), bytes.size()) == 0);
  }

  void emit(const UnionApplied& a) {
    switch (a.kind) {
      case UnionApplied::value:
        if (std::uint8_t* p = b_.claim(a.width)) detail::put_le_n(p, a.bits, a.width);
        break;
      case UnionApplied::forward:
        store_forward_pointer(a.ref.off);
        break;
      case UnionApplied::node:
        store_bidirectional_pointer(a.ref);
        break;
    }
  }

  static std::uint64_t slot_of(const UnionElem& e, std::size_t content_end) noexcept {
    switch (e.kind) {
      case UnionApplied::value:
        return e.val;
      case UnionApplied::forward:
        return content_end - e.val;
      case UnionApplied::node:
        return static_cast<std::uint64_t>(content_end - e.val) << 1;
    }
    return 0;
  }

  B& b_;
  GraphCaches& c_;
};

// ── Arrays whose elements are stored first ──────────────────────────────────────
//
// The elements are stored last first (the record grows toward its front), each by
// `each(element)`, and the array's table after them. Their offsets are kept in a vector:
// the graph writer is model tier.

/// A pointer table over utf8 / data elements; `each(e)` stores one and returns its offset,
/// or 0 for a nil element.
template <class B, class T, class Each>
inline std::size_t store_ptr_table_array(GraphWriter<B>& w, Span<const T> elems, Each&& each) {
  std::vector<std::size_t> offsets(elems.size(), 0);
  for (std::size_t i = elems.size(); i-- > 0;) offsets[i] = each(elems[i]);
  return w.store_ptr_table(Span<const std::size_t>(offsets));
}

/// A node array; `each(e)` stores one node and returns its reference (`NodeRef::nil()` for
/// a nil element).
template <class B, class T, class Each>
inline std::size_t store_node_array(GraphWriter<B>& w, Span<const T> elems, Each&& each) {
  std::vector<NodeRef> refs(elems.size());
  for (std::size_t i = elems.size(); i-- > 0;) refs[i] = each(elems[i]);
  return w.store_node_ref_array(Span<const NodeRef>(refs));
}

/// A regular / frozen union array; `each(e)` stores one element's content and returns its
/// slot (`present` false: a nil element).
template <class B, class T, class Each>
inline std::size_t store_union_array_of(GraphWriter<B>& w, Span<const T> elems, unsigned bits_per, bool opt,
                                        Each&& each) {
  std::vector<UnionElem> applied(elems.size());
  for (std::size_t i = elems.size(); i-- > 0;) applied[i] = each(elems[i]);
  return w.store_union_array(Span<const UnionElem>(applied), bits_per, opt);
}

/// A packed union array `[block length][count][nil bitset][LEB header size][headers]
/// [payloads]` (the bitset and header size when `opt`); `payload(e)` stores one payload
/// and returns its header, or nullopt for a nil element.
template <class B, class T, class Payload>
inline void store_packed_union_array_of(B& b, Span<const T> elems, bool opt, Payload&& payload) {
  const std::size_t before = b.cursor();
  const std::size_t n = elems.size();
  std::vector<std::optional<std::uint64_t>> headers(n);
  for (std::size_t i = n; i-- > 0;) headers[i] = payload(elems[i]);
  const std::size_t at = b.cursor();
  for (std::size_t i = n; i-- > 0;) {
    if (headers[i].has_value()) store_leb(b, *headers[i]);
  }
  if (opt) {
    store_leb(b, b.cursor() - at);
    const std::size_t nb = (n + 7) / 8;
    if (nb != 0) {
      if (std::uint8_t* p = b.claim(nb)) {
        std::memset(p, 0, nb);
        for (std::size_t i = 0; i < n; i++) {
          if (!headers[i].has_value()) detail::set_bit(p, i);
        }
      }
    }
  }
  store_leb(b, n);
  store_leb(b, b.cursor() - before);
}

// ── Restore: the nodes read so far ──────────────────────────────────────────────

/// What an arena restore threads: each node read so far, by type and buffer position, so
/// that a node met again — shared, or a cycle back to an ancestor — is the same node; and
/// how deep the walk may still descend (it recurses over the DATA, spec/41 §5).
class RestoreSeen {
 public:
  static constexpr std::uint64_t none = ~std::uint64_t{0};

  explicit RestoreSeen(std::size_t max_depth) noexcept : depth_left_(max_depth) {}

  /// The handle the node of `type` at (`buf`, `pos`) was restored as, or `none`.
  std::uint64_t find(std::uint64_t type, Bytes buf, std::size_t pos) const noexcept {
    const std::uint32_t e = index_.find(hash(type, buf, pos), [&](std::uint32_t i) noexcept {
      const Entry& x = entries_[i];
      return x.type == type && x.buf == buf.data() && x.pos == pos;
    });
    return e == IndexTable::none ? none : entries_[e].handle;
  }

  void add(std::uint64_t type, Bytes buf, std::size_t pos, std::uint64_t handle) {
    index_.insert(hash(type, buf, pos), static_cast<std::uint32_t>(entries_.size()));
    entries_.push_back(Entry{type, buf.data(), pos, handle});
  }

  Status status() const noexcept { return status_; }
  void fail(Status s) noexcept {
    if (status_ == Status::ok) status_ = s;
  }

  /// One level of the walk: false — and `depth_exceeded` recorded — at the depth limit.
  class Level {
   public:
    explicit Level(RestoreSeen& s) noexcept : s_(s), entered_(s.depth_left_ > 0) {
      if (entered_) s_.depth_left_--;
      else s_.fail(Status::depth_exceeded);
    }
    ~Level() {
      if (entered_) s_.depth_left_++;
    }
    Level(const Level&) = delete;
    Level& operator=(const Level&) = delete;
    explicit operator bool() const noexcept { return entered_; }

   private:
    RestoreSeen& s_;
    bool entered_;
  };

 private:
  struct Entry {
    std::uint64_t type;
    const std::uint8_t* buf;
    std::size_t pos;
    std::uint64_t handle;
  };

  static std::uint64_t hash(std::uint64_t type, Bytes buf, std::size_t pos) noexcept {
    return detail::mix(pos ^ detail::mix(type ^ (static_cast<std::uint64_t>(buf.size()) << 20)));
  }

  IndexTable index_;
  std::vector<Entry> entries_;
  std::size_t depth_left_;
  Status status_ = Status::ok;
};

// ── Regular / frozen arrays of values (spec 04) ────────────────────────────────

namespace wire {

/// How one fixed-width element of a regular array is written: `Bits` of `T`, as stored.
template <class T>
struct Int {
  static constexpr std::size_t width = sizeof(T);
  static std::uint64_t bits(T v) noexcept { return static_cast<std::make_unsigned_t<T>>(v); }
};
struct F32 {
  static constexpr std::size_t width = 4;
  static std::uint64_t bits(float v) noexcept { return detail::bits<std::uint32_t>(v); }
};
struct F64 {
  static constexpr std::size_t width = 8;
  static std::uint64_t bits(double v) noexcept { return detail::bits<std::uint64_t>(v); }
};
struct F16 {
  static constexpr std::size_t width = 2;
  static std::uint64_t bits(float v) noexcept { return f32_to_f16_bits(v); }
};
struct BF16 {
  static constexpr std::size_t width = 2;
  static std::uint64_t bits(float v) noexcept { return f32_to_bf16_bits(v); }
};
template <class E, class U>
struct Enum {
  static constexpr std::size_t width = sizeof(U);
  static std::uint64_t bits(E v) noexcept { return static_cast<U>(v); }
};

}  // namespace wire

/// `[LEB count][elements]`, each `W::width` bytes little-endian. Returns its offset.
template <class W, class B, class T>
inline std::size_t store_fixed_array(B& b, Span<const T> elems) noexcept {
  const std::size_t n = elems.size();
  if (n != 0) {
    if (std::uint8_t* p = b.claim(n * W::width)) {
      for (std::size_t i = 0; i < n; i++) detail::put_le_n(p + i * W::width, W::bits(elems[i]), W::width);
    }
  }
  store_leb(b, n);
  return b.cursor();
}

/// `[LEB count][nil bitset][count slots]` — an absent element is `W::width` zero bytes
/// (the regular arrayWithOptionals is not compacted).
template <class W, class B, class T>
inline std::size_t store_fixed_opt_array(B& b, Span<const std::optional<T>> elems) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) / 8;
  if (n != 0) {
    if (std::uint8_t* p = b.claim(nb + n * W::width)) {
      std::memset(p, 0, nb + n * W::width);
      for (std::size_t i = 0; i < n; i++) {
        if (elems[i].has_value()) detail::put_le_n(p + nb + i * W::width, W::bits(*elems[i]), W::width);
        else detail::set_bit(p, i);
      }
    }
  }
  store_leb(b, n);
  return b.cursor();
}

/// `[LEB count][bitset]`. `E` is bool or a byte holding 0 / 1.
template <class B, class E>
inline std::size_t store_bool_array(B& b, Span<const E> elems) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) / 8;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(nb)) {
      std::memset(p, 0, nb);
      for (std::size_t i = 0; i < n; i++) {
        if (elems[i]) detail::set_bit(p, i);
      }
    }
  }
  store_leb(b, n);
  return b.cursor();
}

/// `[LEB count][nil bitset][value bitset]`, both indexed by element.
template <class B, class E>
inline std::size_t store_bool_opt_array(B& b, Span<const std::optional<E>> elems) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) / 8;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(2 * nb)) {
      std::memset(p, 0, 2 * nb);
      for (std::size_t i = 0; i < n; i++) {
        if (!elems[i].has_value()) detail::set_bit(p, i);
        else if (*elems[i]) detail::set_bit(p + nb, i);
      }
    }
  }
  store_leb(b, n);
  return b.cursor();
}

/// A sub-byte enum array: `[LEB count][packed bits]`.
template <class B, class E>
inline std::size_t store_bit_enum_array(B& b, Span<const E> elems, std::size_t bits_per) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n * bits_per + 7) / 8;
  if (nb != 0) {
    if (std::uint8_t* p = b.claim(nb)) {
      std::size_t i = 0;
      detail::put_enum_bits(p, n, bits_per, [&]() noexcept { return detail::enum_raw(elems[i++]); });
    }
  }
  store_leb(b, n);
  return b.cursor();
}

/// `[LEB count][nil bitset][packed bits]`, an absent element's bits zero (not compacted).
template <class B, class E>
inline std::size_t store_bit_enum_opt_array(B& b, Span<const std::optional<E>> elems, std::size_t bits_per) noexcept {
  const std::size_t n = elems.size();
  const std::size_t nb = (n + 7) / 8;
  const std::size_t vb = (n * bits_per + 7) / 8;
  if (nb + vb != 0) {
    if (std::uint8_t* p = b.claim(nb + vb)) {
      std::memset(p, 0, nb);
      std::size_t i = 0;
      detail::put_enum_bits(p + nb, n, bits_per, [&]() noexcept {
        const std::optional<E>& e = elems[i++];
        return e.has_value() ? detail::enum_raw(*e) : std::uint64_t{0};
      });
      for (std::size_t k = 0; k < n; k++) {
        if (!elems[k].has_value()) detail::set_bit(p, k);
      }
    }
  }
  store_leb(b, n);
  return b.cursor();
}

// ── aligned(N) arrays and blobs (spec 12 §11) ──────────────────────────────────

/// Zero bytes before (in store order: after) a payload of `payload` bytes, so that the
/// payload's first byte lands on a multiple of `n` counted from the record's end.
template <class B>
inline void store_aligned_pad(B& b, std::size_t payload, std::size_t n) noexcept {
  store_zeros(b, (0 - (b.cursor() + payload)) & (n - 1));
}

/// An aligned fixed-width array: the pad, the elements, `LEB count`. Returns its offset.
template <class W, class B, class T>
inline std::size_t store_aligned_array(B& b, Span<const T> elems, std::size_t n) noexcept {
  store_aligned_pad(b, elems.size() * W::width, n);
  return store_fixed_array<W>(b, elems);
}

/// An aligned utf8 / data payload — never deduplicated, its position matters.
template <class B>
inline std::size_t store_aligned_bytes(B& b, Bytes bytes, std::size_t n) noexcept {
  store_aligned_pad(b, bytes.size(), n);
  store_bytes(b, bytes);
  store_leb(b, bytes.size());
  return b.cursor();
}

}  // namespace dagr
