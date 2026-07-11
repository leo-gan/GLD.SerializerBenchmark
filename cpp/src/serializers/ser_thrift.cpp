#include "bench/serializer.hpp"

#include <cstdint>
#include <cstring>
#include <stdexcept>

// Apache Thrift TBinaryProtocol (struct fields) for suite fixtures.
// Optimal: TBinaryProtocol write/read of structs without RPC frame
// (field type + id + value; STOP). Medium-value schema-family codec used
// widely in polyglot services; full thriftc codegen is optional later.

namespace bench {
namespace {

// TType
enum : uint8_t {
  T_STOP = 0,
  T_BOOL = 2,
  T_DOUBLE = 4,
  T_I16 = 6,
  T_I32 = 8,
  T_I64 = 10,
  T_STRING = 11,
  T_STRUCT = 12,
  T_LIST = 15,
};

struct Tw {
  std::vector<uint8_t> b;
  void u8(uint8_t v) { b.push_back(v); }
  void i16be(int16_t v) {
    auto u = static_cast<uint16_t>(v);
    u8(static_cast<uint8_t>((u >> 8) & 0xff));
    u8(static_cast<uint8_t>(u & 0xff));
  }
  void i32be(int32_t v) {
    auto u = static_cast<uint32_t>(v);
    u8(static_cast<uint8_t>((u >> 24) & 0xff));
    u8(static_cast<uint8_t>((u >> 16) & 0xff));
    u8(static_cast<uint8_t>((u >> 8) & 0xff));
    u8(static_cast<uint8_t>(u & 0xff));
  }
  void i64be(int64_t v) {
    auto u = static_cast<uint64_t>(v);
    for (int i = 7; i >= 0; --i) u8(static_cast<uint8_t>((u >> (8 * i)) & 0xff));
  }
  void f64(double d) {
    uint64_t u;
    std::memcpy(&u, &d, 8);
    i64be(static_cast<int64_t>(u));  // thrift uses big-endian IEEE bits
  }
  void str(const std::string& s) {
    i32be(static_cast<int32_t>(s.size()));
    b.insert(b.end(), s.begin(), s.end());
  }
  void field_begin(uint8_t type, int16_t id) {
    u8(type);
    i16be(id);
  }
  void field_stop() { u8(T_STOP); }
};

struct Tr {
  const uint8_t* p;
  const uint8_t* e;
  explicit Tr(const std::vector<uint8_t>& d) : p(d.data()), e(d.data() + d.size()) {}
  void need(size_t n) {
    if (static_cast<size_t>(e - p) < n) throw std::runtime_error("thrift trunc");
  }
  uint8_t u8() {
    need(1);
    return *p++;
  }
  int16_t i16be() {
    need(2);
    uint16_t v = (static_cast<uint16_t>(p[0]) << 8) | static_cast<uint16_t>(p[1]);
    p += 2;
    return static_cast<int16_t>(v);
  }
  int32_t i32be() {
    need(4);
    uint32_t v = (static_cast<uint32_t>(p[0]) << 24) | (static_cast<uint32_t>(p[1]) << 16) |
                 (static_cast<uint32_t>(p[2]) << 8) | static_cast<uint32_t>(p[3]);
    p += 4;
    return static_cast<int32_t>(v);
  }
  int64_t i64be() {
    need(8);
    uint64_t u = 0;
    for (int i = 0; i < 8; ++i) u = (u << 8) | p[i];
    p += 8;
    return static_cast<int64_t>(u);
  }
  double f64() {
    uint64_t u = static_cast<uint64_t>(i64be());
    double d;
    std::memcpy(&d, &u, 8);
    return d;
  }
  std::string str() {
    int32_t n = i32be();
    if (n < 0) throw std::runtime_error("thrift bad str");
    need(static_cast<size_t>(n));
    std::string s(reinterpret_cast<const char*>(p), static_cast<size_t>(n));
    p += n;
    return s;
  }
  void skip(uint8_t type);
  void skip_struct() {
    while (true) {
      uint8_t t = u8();
      if (t == T_STOP) break;
      (void)i16be();
      skip(t);
    }
  }
  void skip_list() {
    uint8_t et = u8();
    int32_t n = i32be();
    for (int32_t i = 0; i < n; ++i) skip(et);
  }
};

void Tr::skip(uint8_t type) {
  switch (type) {
    case T_BOOL: (void)u8(); break;
    case T_I16: (void)i16be(); break;
    case T_I32: (void)i32be(); break;
    case T_I64:
    case T_DOUBLE: (void)i64be(); break;
    case T_STRING: (void)str(); break;
    case T_STRUCT: skip_struct(); break;
    case T_LIST: skip_list(); break;
    default: throw std::runtime_error("thrift skip type");
  }
}

static void write_message(Tw& w, const Message& m) {
  w.field_begin(T_BOOL, 1); w.u8(m.f_bool ? 1 : 0);
  w.field_begin(T_I32, 2); w.i32be(m.f_int32);
  w.field_begin(T_I64, 3); w.i64be(m.f_int64);
  w.field_begin(T_DOUBLE, 4); w.f64(m.f_float64);
  w.field_begin(T_STRING, 5); w.str(m.f_string);
  w.field_begin(T_BOOL, 6); w.u8(m.f_bool_2 ? 1 : 0);
  w.field_begin(T_I32, 7); w.i32be(m.f_int32_2);
  w.field_begin(T_STRING, 8); w.str(m.f_string_2);
  w.field_stop();
}
static Message read_message(Tr& r) {
  Message m;
  while (true) {
    uint8_t t = r.u8();
    if (t == T_STOP) break;
    int16_t id = r.i16be();
    switch (id) {
      case 1: m.f_bool = r.u8() != 0; break;
      case 2: m.f_int32 = r.i32be(); break;
      case 3: m.f_int64 = r.i64be(); break;
      case 4: m.f_float64 = r.f64(); break;
      case 5: m.f_string = r.str(); break;
      case 6: m.f_bool_2 = r.u8() != 0; break;
      case 7: m.f_int32_2 = r.i32be(); break;
      case 8: m.f_string_2 = r.str(); break;
      default: r.skip(t); break;
    }
  }
  return m;
}

static void write_document(Tw& w, const Document& d) {
  w.field_begin(T_STRING, 1); w.str(d.id);
  w.field_begin(T_I32, 2); w.i32be(d.status);
  w.field_begin(T_STRUCT, 3);
  {
    w.field_begin(T_STRING, 1); w.str(d.meta.region);
    w.field_begin(T_I32, 2); w.i32be(d.meta.version);
    w.field_stop();
  }
  w.field_begin(T_LIST, 4);
  w.u8(T_STRUCT);
  w.i32be(static_cast<int32_t>(d.items.size()));
  for (const auto& it : d.items) {
    w.field_begin(T_STRING, 1); w.str(it.sku);
    w.field_begin(T_I32, 2); w.i32be(it.qty);
    w.field_begin(T_I64, 3); w.i64be(it.price_minor);
    w.field_stop();
  }
  w.field_stop();
}
static Document read_document(Tr& r) {
  Document d;
  while (true) {
    uint8_t t = r.u8();
    if (t == T_STOP) break;
    int16_t id = r.i16be();
    if (id == 1) d.id = r.str();
    else if (id == 2) d.status = r.i32be();
    else if (id == 3) {
      while (true) {
        uint8_t t2 = r.u8();
        if (t2 == T_STOP) break;
        int16_t id2 = r.i16be();
        if (id2 == 1) d.meta.region = r.str();
        else if (id2 == 2) d.meta.version = r.i32be();
        else r.skip(t2);
      }
    } else if (id == 4) {
      (void)r.u8();
      int32_t n = r.i32be();
      d.items.resize(static_cast<size_t>(n));
      for (int32_t i = 0; i < n; ++i) {
        DocumentItem it;
        while (true) {
          uint8_t t2 = r.u8();
          if (t2 == T_STOP) break;
          int16_t id2 = r.i16be();
          if (id2 == 1) it.sku = r.str();
          else if (id2 == 2) it.qty = r.i32be();
          else if (id2 == 3) it.price_minor = r.i64be();
          else r.skip(t2);
        }
        d.items[static_cast<size_t>(i)] = std::move(it);
      }
    } else r.skip(t);
  }
  return d;
}

static void write_telemetry(Tw& w, const Telemetry& t) {
  w.field_begin(T_STRING, 1); w.str(t.source);
  w.field_begin(T_I64, 2); w.i64be(t.ts);
  w.field_begin(T_LIST, 3); w.u8(T_STRING); w.i32be(static_cast<int32_t>(t.tags.size()));
  for (const auto& tg : t.tags) w.str(tg);
  w.field_begin(T_LIST, 4); w.u8(T_DOUBLE); w.i32be(static_cast<int32_t>(t.values.size()));
  for (double v : t.values) w.f64(v);
  w.field_stop();
}
static Telemetry read_telemetry(Tr& r) {
  Telemetry t;
  while (true) {
    uint8_t ty = r.u8();
    if (ty == T_STOP) break;
    int16_t id = r.i16be();
    if (id == 1) t.source = r.str();
    else if (id == 2) t.ts = r.i64be();
    else if (id == 3) {
      (void)r.u8();
      int32_t n = r.i32be();
      t.tags.resize(static_cast<size_t>(n));
      for (int32_t i = 0; i < n; ++i) t.tags[static_cast<size_t>(i)] = r.str();
    } else if (id == 4) {
      (void)r.u8();
      int32_t n = r.i32be();
      t.values.resize(static_cast<size_t>(n));
      for (int32_t i = 0; i < n; ++i) t.values[static_cast<size_t>(i)] = r.f64();
    } else r.skip(ty);
  }
  return t;
}

static void write_strings(Tw& w, const Strings& s) {
  w.field_begin(T_LIST, 1); w.u8(T_STRING); w.i32be(static_cast<int32_t>(s.items.size()));
  for (const auto& it : s.items) w.str(it);
  w.field_stop();
}
static Strings read_strings(Tr& r) {
  Strings s;
  while (true) {
    uint8_t t = r.u8();
    if (t == T_STOP) break;
    int16_t id = r.i16be();
    if (id == 1) {
      (void)r.u8();
      int32_t n = r.i32be();
      s.items.resize(static_cast<size_t>(n));
      for (int32_t i = 0; i < n; ++i) s.items[static_cast<size_t>(i)] = r.str();
    } else r.skip(t);
  }
  return s;
}

static void write_event(Tw& w, const Event& e) {
  w.field_begin(T_STRING, 1); w.str(e.event_id);
  w.field_begin(T_STRING, 2); w.str(e.event_type);
  w.field_begin(T_I64, 3); w.i64be(e.occurred_at);
  w.field_begin(T_STRING, 4); w.str(e.producer);
  w.field_begin(T_LIST, 5); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(e.attrs.size()));
  for (const auto& a : e.attrs) {
    w.field_begin(T_STRING, 1); w.str(a.key);
    w.field_begin(T_STRING, 2); w.str(a.value);
    w.field_stop();
  }
  w.field_stop();
}
static Event read_event(Tr& r) {
  Event e;
  while (true) {
    uint8_t t = r.u8();
    if (t == T_STOP) break;
    int16_t id = r.i16be();
    if (id == 1) e.event_id = r.str();
    else if (id == 2) e.event_type = r.str();
    else if (id == 3) e.occurred_at = r.i64be();
    else if (id == 4) e.producer = r.str();
    else if (id == 5) {
      (void)r.u8();
      int32_t n = r.i32be();
      e.attrs.resize(static_cast<size_t>(n));
      for (int32_t i = 0; i < n; ++i) {
        EventAttr a;
        while (true) {
          uint8_t t2 = r.u8();
          if (t2 == T_STOP) break;
          int16_t id2 = r.i16be();
          if (id2 == 1) a.key = r.str();
          else if (id2 == 2) a.value = r.str();
          else r.skip(t2);
        }
        e.attrs[static_cast<size_t>(i)] = std::move(a);
      }
    } else r.skip(t);
  }
  return e;
}

static std::vector<uint8_t> encode(const Value& v) {
  Tw w;
  std::visit(
      [&](const auto& x) {
        using T = std::decay_t<decltype(x)>;
        if constexpr (std::is_same_v<T, Message>) write_message(w, x);
        else if constexpr (std::is_same_v<T, Document>) write_document(w, x);
        else if constexpr (std::is_same_v<T, Telemetry>) write_telemetry(w, x);
        else if constexpr (std::is_same_v<T, Strings>) write_strings(w, x);
        else if constexpr (std::is_same_v<T, Event>) write_event(w, x);
        else if constexpr (std::is_same_v<T, std::vector<Message>>) {
          w.u8(T_LIST); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(x.size()));
          for (const auto& el : x) write_message(w, el);
        } else if constexpr (std::is_same_v<T, std::vector<Document>>) {
          w.u8(T_LIST); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(x.size()));
          for (const auto& el : x) write_document(w, el);
        } else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) {
          w.u8(T_LIST); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(x.size()));
          for (const auto& el : x) write_telemetry(w, el);
        } else if constexpr (std::is_same_v<T, std::vector<Strings>>) {
          w.u8(T_LIST); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(x.size()));
          for (const auto& el : x) write_strings(w, el);
        } else if constexpr (std::is_same_v<T, std::vector<Event>>) {
          w.u8(T_LIST); w.u8(T_STRUCT); w.i32be(static_cast<int32_t>(x.size()));
          for (const auto& el : x) write_event(w, el);
        }
      },
      v);
  return w.b;
}

static Value decode(const std::vector<uint8_t>& data, const std::string& type_id, int n) {
  Tr r(data);
  if (n > 1) {
    if (r.u8() != T_LIST) throw std::runtime_error("thrift batch expect list");
    (void)r.u8();
    int32_t count = r.i32be();
    if (type_id == "message") {
      std::vector<Message> v(static_cast<size_t>(count));
      for (int32_t i = 0; i < count; ++i) v[static_cast<size_t>(i)] = read_message(r);
      return v;
    }
    if (type_id == "document") {
      std::vector<Document> v(static_cast<size_t>(count));
      for (int32_t i = 0; i < count; ++i) v[static_cast<size_t>(i)] = read_document(r);
      return v;
    }
    if (type_id == "telemetry") {
      std::vector<Telemetry> v(static_cast<size_t>(count));
      for (int32_t i = 0; i < count; ++i) v[static_cast<size_t>(i)] = read_telemetry(r);
      return v;
    }
    if (type_id == "strings") {
      std::vector<Strings> v(static_cast<size_t>(count));
      for (int32_t i = 0; i < count; ++i) v[static_cast<size_t>(i)] = read_strings(r);
      return v;
    }
    std::vector<Event> v(static_cast<size_t>(count));
    for (int32_t i = 0; i < count; ++i) v[static_cast<size_t>(i)] = read_event(r);
    return v;
  }
  if (type_id == "message") return read_message(r);
  if (type_id == "document") return read_document(r);
  if (type_id == "telemetry") return read_telemetry(r);
  if (type_id == "strings") return read_strings(r);
  return read_event(r);
}

class ThriftSer final : public ISerializer {
 public:
  const char* name() const override { return "thrift"; }
  const char* version() const override { return "TBinaryProtocol"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override { return encode(value_); }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return decode(data, type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

SerializerPtr make_thrift() { return std::make_unique<ThriftSer>(); }

}  // namespace bench
