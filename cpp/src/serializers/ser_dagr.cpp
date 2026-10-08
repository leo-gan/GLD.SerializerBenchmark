// Dagr ("Data Graph") via generated C++ (Dagr spec/41): schemas/v2/dagr/schema.py →
// `dagr build` → cpp/dagr_gen (header-only: the lazy reader, the arena and its serializer,
// and — for the packed layouts — the direct builder).
//
// Four rows, one per node layout (Dagr spec/16), as in every other language:
//
//   row                  graphs                         native model (built in prepare)
//   dagr-packed          MessageGraph, …                direct-builder value structs
//   dagr-regular         MessageRegularGraph, …         the generated arena (vtable nodes)
//   dagr-frozen          MessageFrozenGraph, …          the generated arena (frozen nodes)
//   dagr-frozen-packed   MessageFrozenPackedGraph, …    direct-builder value structs
//
// Serialize (timed): like libprotobuf's prepared messages, the native model is built from
// the suite values in prepare (untimed). The timed call encodes it — the packed layouts
// with the DIRECT BUILDER (value structs → bytes: `direct::build` into one reused
// dagr::Builder), the regular and frozen layouts with the ARENA SERIALIZER
// (`Arena::serialize` into the reused builder and dedup caches; the arena holds the cell's
// N roots). Dagr writes back to front, so each record is copied into the output buffer once,
// and the bytes are returned by value, as the libprotobuf row returns its buffer.
//
// Deserialize (timed): the generated LAZY READER (`open_<graph>`, O(1)), then the owned
// suite value materialized field by field — decode AND domain build on the clock, as the
// Rust and Go Dagr rows time them. (The libprotobuf row times ParseFromArray only and builds
// the domain value in to_domain, untimed: this row is the stricter of the two.)
//
// N>1 cells: the schema has no Batch_* wrapper (the harness frames N instances); the frame is
// the suite's cross-language one (rust/src/run_v2.rs, go/serializers/dagr.go):
// u32 LE count + (u32 LE len + record) × N. N=1 is the bare record.

#include "bench/serializer.hpp"

#include "benchmark_v2/document_frozen_graph_arena.hpp"
#include "benchmark_v2/document_frozen_packed_graph_direct.hpp"
#include "benchmark_v2/document_graph_direct.hpp"
#include "benchmark_v2/document_regular_graph_arena.hpp"
#include "benchmark_v2/event_frozen_graph_arena.hpp"
#include "benchmark_v2/event_frozen_packed_graph_direct.hpp"
#include "benchmark_v2/event_graph_direct.hpp"
#include "benchmark_v2/event_regular_graph_arena.hpp"
#include "benchmark_v2/message_frozen_graph_arena.hpp"
#include "benchmark_v2/message_frozen_packed_graph_direct.hpp"
#include "benchmark_v2/message_graph_direct.hpp"
#include "benchmark_v2/message_regular_graph_arena.hpp"
#include "benchmark_v2/strings_frozen_graph_arena.hpp"
#include "benchmark_v2/strings_frozen_packed_graph_direct.hpp"
#include "benchmark_v2/strings_graph_direct.hpp"
#include "benchmark_v2/strings_regular_graph_arena.hpp"
#include "benchmark_v2/telemetry_frozen_graph_arena.hpp"
#include "benchmark_v2/telemetry_frozen_packed_graph_direct.hpp"
#include "benchmark_v2/telemetry_graph_direct.hpp"
#include "benchmark_v2/telemetry_regular_graph_arena.hpp"
#include "dagr/graph_writer.hpp"
#include "dagr/writer.hpp"

#include <deque>
#include <functional>
#include <memory>
#include <stdexcept>
#include <string>
#include <string_view>
#include <type_traits>
#include <vector>

#ifndef DAGR_TOOL_VERSION
#define DAGR_TOOL_VERSION "unknown"
#endif

namespace bench {
namespace {

namespace bv = benchmark_v2;

// ── The suite frame ────────────────────────────────────────────────────────────

void put_u32(std::vector<uint8_t>& out, uint32_t v) {
  const uint8_t b[4] = {static_cast<uint8_t>(v), static_cast<uint8_t>(v >> 8), static_cast<uint8_t>(v >> 16),
                        static_cast<uint8_t>(v >> 24)};
  out.insert(out.end(), b, b + 4);
}

uint32_t get_u32(const std::vector<uint8_t>& in, size_t at) {
  if (at + 4 > in.size()) throw std::runtime_error("dagr: truncated frame");
  return static_cast<uint32_t>(in[at]) | static_cast<uint32_t>(in[at + 1]) << 8 |
         static_cast<uint32_t>(in[at + 2]) << 16 | static_cast<uint32_t>(in[at + 3]) << 24;
}

/// Appends one record: bare when the cell holds one instance, else `u32 len + record`.
void append_record(std::vector<uint8_t>& out, dagr::Bytes rec, size_t n) {
  if (rec.empty()) throw std::runtime_error("dagr: encode failed");
  if (n > 1) put_u32(out, static_cast<uint32_t>(rec.size()));
  out.insert(out.end(), rec.begin(), rec.end());
}

/// `each(record)` for every record of a framed (N>1) or bare (N=1) buffer.
template <class Each>
void for_each_record(const std::vector<uint8_t>& data, int n, Each&& each) {
  if (n <= 1) {
    each(dagr::Bytes(data.data(), data.size()));
    return;
  }
  const uint32_t count = get_u32(data, 0);
  size_t at = 4;
  for (uint32_t i = 0; i < count; i++) {
    const uint32_t len = get_u32(data, at);
    at += 4;
    if (len > data.size() - at) throw std::runtime_error("dagr: truncated record");
    each(dagr::Bytes(data.data() + at, len));
    at += len;
  }
}

/// The instances of a cell, whatever N.
template <class T>
std::vector<const T*> instances(const Fixture& fx) {
  std::vector<const T*> out;
  if (fx.instance_count > 1) {
    for (const T& v : std::get<std::vector<T>>(fx.value)) out.push_back(&v);
  } else {
    out.push_back(&std::get<T>(fx.value));
  }
  return out;
}

std::string str(std::optional<std::string_view> v) { return v ? std::string(*v) : std::string(); }

// ── Decode: the lazy reader → the suite value ──────────────────────────────────
//
// Every layout's accessors have the same getters (all suite fields are optional), so one
// template per type reads all four layouts.

template <class A>
Message read_message(const A& a) {
  Message m;
  m.f_bool = a.f_bool().value_or(false);
  m.f_int32 = a.f_int32().value_or(0);
  m.f_int64 = a.f_int64().value_or(0);
  m.f_float64 = a.f_float64().value_or(0.0);
  m.f_string = str(a.f_string());
  m.f_bool_2 = a.f_bool_2().value_or(false);
  m.f_int32_2 = a.f_int32_2().value_or(0);
  m.f_string_2 = str(a.f_string_2());
  return m;
}

template <class A>
Document read_document(const A& a) {
  Document d;
  d.id = str(a.id());
  d.status = a.status().value_or(0);
  if (const auto meta = a.meta()) {
    d.meta.region = str(meta->region());
    d.meta.version = meta->version().value_or(0);
  }
  if (const auto items = a.items()) {
    d.items.reserve(items->size());
    for (const auto& it : *items) {
      d.items.push_back(DocumentItem{str(it.sku()), it.qty().value_or(0), it.price_minor().value_or(0)});
    }
  }
  return d;
}

template <class A>
Telemetry read_telemetry(const A& a) {
  Telemetry t;
  t.source = str(a.source());
  t.ts = a.ts().value_or(0);
  if (const auto tags = a.tags()) {
    t.tags.reserve(tags->size());
    for (const std::string_view s : *tags) t.tags.emplace_back(s);
  }
  if (const auto values = a.values()) {
    // one block copy: `values` is `raw`, so its elements are one native-LE block (Dagr spec/43)
    t.values.resize(values->size());
    t.values.resize(values->copy_to(t.values.data(), t.values.size()));
  }
  return t;
}

template <class A>
Strings read_strings(const A& a) {
  Strings s;
  if (const auto items = a.items()) {
    s.items.reserve(items->size());
    for (const std::string_view x : *items) s.items.emplace_back(x);
  }
  return s;
}

template <class A>
Event read_event(const A& a) {
  Event e;
  e.event_id = str(a.event_id());
  e.event_type = str(a.event_type());
  e.occurred_at = a.occurred_at().value_or(0);
  e.producer = str(a.producer());
  if (const auto attrs = a.attrs()) {
    e.attrs.reserve(attrs->size());
    for (const auto& at : *attrs) e.attrs.push_back(EventAttr{str(at.key()), str(at.value())});
  }
  return e;
}

template <class T, class A>
T read_value(const A& a) {
  if constexpr (std::is_same_v<T, Message>) return read_message(a);
  else if constexpr (std::is_same_v<T, Document>) return read_document(a);
  else if constexpr (std::is_same_v<T, Telemetry>) return read_telemetry(a);
  else if constexpr (std::is_same_v<T, Strings>) return read_strings(a);
  else return read_event(a);
}

/// Opens each record with `open`, reads it with `read`: one value, or a vector of N.
template <class T, class Open, class Read>
Value decode_all(const std::vector<uint8_t>& data, int n, Open open, Read read) {
  std::vector<T> out;
  if (n > 1) out.reserve(static_cast<size_t>(n));
  for_each_record(data, n, [&](dagr::Bytes rec) {
    const auto acc = open(rec);
    if (!acc.ok()) throw std::runtime_error("dagr: not a buffer of this graph");
    out.push_back(read(acc.value()));
  });
  if (n > 1) return out;
  if (out.empty()) throw std::runtime_error("dagr: no record");
  return std::move(out.front());
}

// ── Encode, packed layouts: the direct builder's value structs ─────────────────
//
// The value structs BORROW — strings are views of the fixture, arrays spans of side tables —
// so the row keeps its own copy of the fixture and the side tables (deques: a table that
// grows never moves what an earlier value points at).

template <class NS>
struct DirectTables {
  std::deque<std::vector<typename NS::DocumentItem>> items;
  std::deque<std::vector<typename NS::EventAttr>> attrs;
  std::deque<std::vector<std::string_view>> strs;

  dagr::Span<const std::string_view> views(const std::vector<std::string>& v) {
    strs.emplace_back(v.begin(), v.end());
    return dagr::Span<const std::string_view>(strs.back());
  }
};

template <class NS>
typename NS::Message direct_message(DirectTables<NS>&, const Message& m) {
  typename NS::Message d;
  d.f_bool = m.f_bool;
  d.f_int32 = m.f_int32;
  d.f_int64 = m.f_int64;
  d.f_float64 = m.f_float64;
  d.f_string = std::string_view(m.f_string);
  d.f_bool_2 = m.f_bool_2;
  d.f_int32_2 = m.f_int32_2;
  d.f_string_2 = std::string_view(m.f_string_2);
  return d;
}

template <class NS>
typename NS::Document direct_document(DirectTables<NS>& t, const Document& doc) {
  typename NS::Document d;
  d.id = std::string_view(doc.id);
  d.status = doc.status;
  typename NS::DocumentMeta meta;
  meta.region = std::string_view(doc.meta.region);
  meta.version = doc.meta.version;
  d.meta = meta;
  auto& items = t.items.emplace_back();
  items.reserve(doc.items.size());
  for (const DocumentItem& it : doc.items) {
    typename NS::DocumentItem x;
    x.sku = std::string_view(it.sku);
    x.qty = it.qty;
    x.price_minor = it.price_minor;
    items.push_back(x);
  }
  d.items = dagr::Span<const typename NS::DocumentItem>(items);
  return d;
}

template <class NS>
typename NS::Telemetry direct_telemetry(DirectTables<NS>& t, const Telemetry& tel) {
  typename NS::Telemetry d;
  d.source = std::string_view(tel.source);
  d.ts = tel.ts;
  d.tags = t.views(tel.tags);
  d.values = dagr::Span<const double>(tel.values);
  return d;
}

template <class NS>
typename NS::Strings direct_strings(DirectTables<NS>& t, const Strings& s) {
  typename NS::Strings d;
  d.items = t.views(s.items);
  return d;
}

template <class NS>
typename NS::Event direct_event(DirectTables<NS>& t, const Event& e) {
  typename NS::Event d;
  d.event_id = std::string_view(e.event_id);
  d.event_type = std::string_view(e.event_type);
  d.occurred_at = e.occurred_at;
  d.producer = std::string_view(e.producer);
  auto& attrs = t.attrs.emplace_back();
  attrs.reserve(e.attrs.size());
  for (const EventAttr& a : e.attrs) {
    typename NS::EventAttr x;
    x.key = std::string_view(a.key);
    x.value = std::string_view(a.value);
    attrs.push_back(x);
  }
  d.attrs = dagr::Span<const typename NS::EventAttr>(attrs);
  return d;
}

// ── Encode, regular / frozen layouts: the arena ────────────────────────────────

template <class A>
auto arena_message(A& a, const Message& m) {
  const auto n = a.new_message();
  n.set_f_bool(m.f_bool);
  n.set_f_int32(m.f_int32);
  n.set_f_int64(m.f_int64);
  n.set_f_float64(m.f_float64);
  n.set_f_string(m.f_string);
  n.set_f_bool_2(m.f_bool_2);
  n.set_f_int32_2(m.f_int32_2);
  n.set_f_string_2(m.f_string_2);
  return n;
}

template <class A>
auto arena_document(A& a, const Document& d) {
  const auto n = a.new_document();
  n.set_id(d.id);
  n.set_status(d.status);
  const auto meta = a.new_document_meta();
  meta.set_region(d.meta.region);
  meta.set_version(d.meta.version);
  n.set_meta(meta);
  std::vector<decltype(a.new_document_item())> items;
  items.reserve(d.items.size());
  for (const DocumentItem& it : d.items) {
    const auto x = a.new_document_item();
    x.set_sku(it.sku);
    x.set_qty(it.qty);
    x.set_price_minor(it.price_minor);
    items.push_back(x);
  }
  n.set_items(dagr::Span<const typename decltype(items)::value_type>(items));
  return n;
}

template <class A>
auto arena_telemetry(A& a, const Telemetry& t) {
  const auto n = a.new_telemetry();
  n.set_source(t.source);
  n.set_ts(t.ts);
  const std::vector<std::string_view> tags(t.tags.begin(), t.tags.end());
  n.set_tags(dagr::Span<const std::string_view>(tags));
  n.set_values(dagr::Span<const double>(t.values));
  return n;
}

template <class A>
auto arena_strings(A& a, const Strings& s) {
  const auto n = a.new_strings();
  const std::vector<std::string_view> items(s.items.begin(), s.items.end());
  n.set_items(dagr::Span<const std::string_view>(items));
  return n;
}

template <class A>
auto arena_event(A& a, const Event& e) {
  const auto n = a.new_event();
  n.set_event_id(e.event_id);
  n.set_event_type(e.event_type);
  n.set_occurred_at(e.occurred_at);
  n.set_producer(e.producer);
  std::vector<decltype(a.new_event_attr())> attrs;
  attrs.reserve(e.attrs.size());
  for (const EventAttr& x : e.attrs) {
    const auto at = a.new_event_attr();
    at.set_key(x.key);
    at.set_value(x.value);
    attrs.push_back(at);
  }
  n.set_attrs(dagr::Span<const typename decltype(attrs)::value_type>(attrs));
  return n;
}

// ── The rows ───────────────────────────────────────────────────────────────────

/// What prepare binds for one cell: the timed encode (appends the cell's bytes after the
/// frame's count) and the timed decode.
struct Codec {
  std::function<void(std::vector<uint8_t>&)> encode;
  std::function<Value(const std::vector<uint8_t>&)> decode;
};

class DagrSer : public ISerializer {
 public:
  explicit DagrSer(const char* name) : name_(name) {}
  const char* name() const override { return name_; }
  const char* version() const override { return DAGR_TOOL_VERSION; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    if (!codec_.encode) throw std::runtime_error("dagr: prepare required");
    out_.clear();
    if (n_ > 1) put_u32(out_, static_cast<uint32_t>(n_));
    codec_.encode(out_);
    return out_;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (!codec_.decode) throw std::runtime_error("dagr: prepare required");
    return codec_.decode(data);
  }

 protected:
  const char* name_;
  int n_ = 1;
  Codec codec_;
  std::vector<uint8_t> out_;
};

/// A packed layout: `NS` names the five graphs' namespaces (see the layouts below).
template <class NS>
class DirectSer final : public DagrSer {
 public:
  using DagrSer::DagrSer;

  void prepare(const Fixture& fx) override {
    n_ = fx.instance_count;
    fixture_ = std::make_shared<const Fixture>(fx);      // what the value structs borrow
    tables_ = std::make_shared<DirectTables<NS>>();
    builder_ = std::make_shared<dagr::Builder>();
    const std::string& t = fx.type_id;
    if (t == "message") bind<Message>(&direct_message<NS>, &NS::open_message);
    else if (t == "document") bind<Document>(&direct_document<NS>, &NS::open_document);
    else if (t == "telemetry") bind<Telemetry>(&direct_telemetry<NS>, &NS::open_telemetry);
    else if (t == "strings") bind<Strings>(&direct_strings<NS>, &NS::open_strings);
    else if (t == "event") bind<Event>(&direct_event<NS>, &NS::open_event);
    else throw std::runtime_error("dagr: unsupported type " + t);
  }

 private:
  template <class T, class ToDirect, class Open>
  void bind(ToDirect to_direct, Open open) {
    using D = decltype(to_direct(*tables_, std::declval<const T&>()));
    auto values = std::make_shared<std::vector<D>>();
    for (const T* v : instances<T>(*fixture_)) values->push_back(to_direct(*tables_, *v));
    auto builder = builder_;
    auto keep = std::make_pair(fixture_, tables_);
    codec_.encode = [values, builder, keep](std::vector<uint8_t>& out) {
      for (const D& v : *values) append_record(out, NS::build(*builder, v), values->size());
    };
    const int n = n_;
    codec_.decode = [n, open](const std::vector<uint8_t>& data) {
      return decode_all<T>(data, n, open, [](const auto& acc) { return read_value<T>(acc); });
    };
  }

  std::shared_ptr<const Fixture> fixture_;
  std::shared_ptr<DirectTables<NS>> tables_;
  std::shared_ptr<dagr::Builder> builder_;
};

/// A regular / frozen layout: one arena per cell holding its N roots.
template <class NS>
class ArenaSer final : public DagrSer {
 public:
  using DagrSer::DagrSer;

  void prepare(const Fixture& fx) override {
    n_ = fx.instance_count;
    const std::string& t = fx.type_id;
    if (t == "message") bind<Message, typename NS::MessageArena>(fx, [](auto& a, const Message& v) { return arena_message(a, v); }, &NS::open_message);
    else if (t == "document") bind<Document, typename NS::DocumentArena>(fx, [](auto& a, const Document& v) { return arena_document(a, v); }, &NS::open_document);
    else if (t == "telemetry") bind<Telemetry, typename NS::TelemetryArena>(fx, [](auto& a, const Telemetry& v) { return arena_telemetry(a, v); }, &NS::open_telemetry);
    else if (t == "strings") bind<Strings, typename NS::StringsArena>(fx, [](auto& a, const Strings& v) { return arena_strings(a, v); }, &NS::open_strings);
    else if (t == "event") bind<Event, typename NS::EventArena>(fx, [](auto& a, const Event& v) { return arena_event(a, v); }, &NS::open_event);
    else throw std::runtime_error("dagr: unsupported type " + t);
  }

 private:
  template <class T, class A, class Build, class Open>
  void bind(const Fixture& fx, Build build, Open open) {
    auto arena = std::make_shared<A>();                 // handles hold its address: never moved
    using H = decltype(build(*arena, std::declval<const T&>()));
    auto roots = std::make_shared<std::vector<H>>();
    for (const T* v : instances<T>(fx)) roots->push_back(build(*arena, *v));
    auto builder = std::make_shared<dagr::Builder>();
    auto caches = std::make_shared<dagr::GraphCaches>();
    codec_.encode = [arena, roots, builder, caches](std::vector<uint8_t>& out) {
      for (const H& r : *roots) {
        arena->set_root(r);
        append_record(out, arena->serialize(*builder, *caches), roots->size());
      }
    };
    const int n = n_;
    codec_.decode = [n, open](const std::vector<uint8_t>& data) {
      return decode_all<T>(data, n, open, [](const auto& acc) { return read_value<T>(acc); });
    };
  }
};

// ── The four layouts' namespaces ───────────────────────────────────────────────

#define DAGR_OPENERS(L)                                                                                          \
  static auto open_message(dagr::Bytes x) { return bv::message##L##_graph::open_message##L##_graph(x); }       \
  static auto open_document(dagr::Bytes x) { return bv::document##L##_graph::open_document##L##_graph(x); }    \
  static auto open_telemetry(dagr::Bytes x) { return bv::telemetry##L##_graph::open_telemetry##L##_graph(x); } \
  static auto open_strings(dagr::Bytes x) { return bv::strings##L##_graph::open_strings##L##_graph(x); }       \
  static auto open_event(dagr::Bytes x) { return bv::event##L##_graph::open_event##L##_graph(x); }

#define DAGR_DIRECT_LAYOUT(NAME, L)                                                                              \
  struct NAME {                                                                                                  \
    using Message = bv::message##L##_graph::direct::Message;                                                     \
    using Document = bv::document##L##_graph::direct::Document;                                                  \
    using DocumentMeta = bv::document##L##_graph::direct::DocumentMeta;                                          \
    using DocumentItem = bv::document##L##_graph::direct::DocumentItem;                                          \
    using Telemetry = bv::telemetry##L##_graph::direct::Telemetry;                                               \
    using Strings = bv::strings##L##_graph::direct::Strings;                                                     \
    using Event = bv::event##L##_graph::direct::Event;                                                           \
    using EventAttr = bv::event##L##_graph::direct::EventAttr;                                                   \
    static dagr::Bytes build(dagr::Builder& b, const Message& v) { return bv::message##L##_graph::direct::build(b, v); }     \
    static dagr::Bytes build(dagr::Builder& b, const Document& v) { return bv::document##L##_graph::direct::build(b, v); }   \
    static dagr::Bytes build(dagr::Builder& b, const Telemetry& v) { return bv::telemetry##L##_graph::direct::build(b, v); } \
    static dagr::Bytes build(dagr::Builder& b, const Strings& v) { return bv::strings##L##_graph::direct::build(b, v); }     \
    static dagr::Bytes build(dagr::Builder& b, const Event& v) { return bv::event##L##_graph::direct::build(b, v); }         \
    DAGR_OPENERS(L)                                                                                              \
  };

#define DAGR_ARENA_LAYOUT(NAME, L)                                     \
  struct NAME {                                                        \
    using MessageArena = bv::message##L##_graph::arena::Arena;         \
    using DocumentArena = bv::document##L##_graph::arena::Arena;       \
    using TelemetryArena = bv::telemetry##L##_graph::arena::Arena;     \
    using StringsArena = bv::strings##L##_graph::arena::Arena;         \
    using EventArena = bv::event##L##_graph::arena::Arena;             \
    DAGR_OPENERS(L)                                                    \
  };

DAGR_DIRECT_LAYOUT(PackedLayout, )
DAGR_DIRECT_LAYOUT(FrozenPackedLayout, _frozen_packed)
DAGR_ARENA_LAYOUT(RegularLayout, _regular)
DAGR_ARENA_LAYOUT(FrozenLayout, _frozen)

}  // namespace

SerializerPtr make_dagr_packed() { return std::make_unique<DirectSer<PackedLayout>>("dagr-packed"); }
SerializerPtr make_dagr_regular() { return std::make_unique<ArenaSer<RegularLayout>>("dagr-regular"); }
SerializerPtr make_dagr_frozen() { return std::make_unique<ArenaSer<FrozenLayout>>("dagr-frozen"); }
SerializerPtr make_dagr_frozen_packed() { return std::make_unique<DirectSer<FrozenPackedLayout>>("dagr-frozen-packed"); }

}  // namespace bench
