#include "bench/serializer.hpp"
#include "bench/nlohmann_conv.hpp"

#include <cstring>
#include <stdexcept>

// Apache Avro binary encoding (spec) for suite fixtures.
// Field order matches avro JSON schemas under schemas/v2 mental model / catalog fields.
// Optimal path: binaryEncoder-style write of records/arrays into reused buffer;
// timed section is pure encode/decode (no schema parse — schema fixed for suite types).
// Dual language: C suite uses avro-c; this is the C++ Avro binary wire for the same family.

namespace bench {
namespace {

struct AvroWriter {
  std::vector<uint8_t> buf;
  void write_bool(bool v) { buf.push_back(v ? 1 : 0); }
  void write_long(int64_t n) {
    // zigzag + varint (Avro long/int)
    uint64_t zig = (static_cast<uint64_t>(n) << 1) ^ static_cast<uint64_t>(n >> 63);
    while (zig >= 0x80) {
      buf.push_back(static_cast<uint8_t>((zig & 0x7f) | 0x80));
      zig >>= 7;
    }
    buf.push_back(static_cast<uint8_t>(zig));
  }
  void write_int(int32_t n) { write_long(n); }
  void write_double(double d) {
    uint64_t u;
    static_assert(sizeof(d) == sizeof(u));
    std::memcpy(&u, &d, sizeof u);
    for (int i = 0; i < 8; ++i) buf.push_back(static_cast<uint8_t>((u >> (8 * i)) & 0xff));
  }
  void write_string(const std::string& s) {
    write_long(static_cast<int64_t>(s.size()));
    buf.insert(buf.end(), s.begin(), s.end());
  }
  void write_bytes(const std::vector<uint8_t>& b) {
    write_long(static_cast<int64_t>(b.size()));
    buf.insert(buf.end(), b.begin(), b.end());
  }
  // array of T: single block with count, then items, then 0
  template <typename F>
  void write_array(size_t n, F write_item) {
    if (n == 0) {
      write_long(0);
      return;
    }
    write_long(static_cast<int64_t>(n));
    for (size_t i = 0; i < n; ++i) write_item(i);
    write_long(0);
  }
};

struct AvroReader {
  const uint8_t* p;
  const uint8_t* end;
  explicit AvroReader(const std::vector<uint8_t>& d) : p(d.data()), end(d.data() + d.size()) {}
  void need(size_t n) {
    if (static_cast<size_t>(end - p) < n) throw std::runtime_error("avro trunc");
  }
  bool read_bool() {
    need(1);
    return *p++ != 0;
  }
  int64_t read_long() {
    uint64_t zig = 0;
    int shift = 0;
    while (true) {
      need(1);
      uint8_t b = *p++;
      zig |= static_cast<uint64_t>(b & 0x7f) << shift;
      if ((b & 0x80) == 0) break;
      shift += 7;
      if (shift > 63) throw std::runtime_error("avro varint overflow");
    }
    return static_cast<int64_t>((zig >> 1) ^ -(zig & 1));
  }
  int32_t read_int() { return static_cast<int32_t>(read_long()); }
  double read_double() {
    need(8);
    uint64_t u = 0;
    for (int i = 0; i < 8; ++i) u |= static_cast<uint64_t>(p[i]) << (8 * i);
    p += 8;
    double d;
    std::memcpy(&d, &u, sizeof d);
    return d;
  }
  std::string read_string() {
    int64_t n = read_long();
    if (n < 0) throw std::runtime_error("avro bad string len");
    need(static_cast<size_t>(n));
    std::string s(reinterpret_cast<const char*>(p), static_cast<size_t>(n));
    p += n;
    return s;
  }
  template <typename F>
  void read_array(F read_item) {
    while (true) {
      int64_t count = read_long();
      if (count == 0) break;
      if (count < 0) {
        // negative count: next long is byte size of block (skip size, use |count|)
        (void)read_long();
        count = -count;
      }
      for (int64_t i = 0; i < count; ++i) read_item();
    }
  }
};

static void write_message(AvroWriter& w, const Message& m) {
  w.write_bool(m.f_bool);
  w.write_int(m.f_int32);
  w.write_long(m.f_int64);
  w.write_double(m.f_float64);
  w.write_string(m.f_string);
  w.write_bool(m.f_bool_2);
  w.write_int(m.f_int32_2);
  w.write_string(m.f_string_2);
}
static Message read_message(AvroReader& r) {
  Message m;
  m.f_bool = r.read_bool();
  m.f_int32 = r.read_int();
  m.f_int64 = r.read_long();
  m.f_float64 = r.read_double();
  m.f_string = r.read_string();
  m.f_bool_2 = r.read_bool();
  m.f_int32_2 = r.read_int();
  m.f_string_2 = r.read_string();
  return m;
}

static void write_document(AvroWriter& w, const Document& d) {
  w.write_string(d.id);
  w.write_int(d.status);
  w.write_string(d.meta.region);
  w.write_int(d.meta.version);
  w.write_array(d.items.size(), [&](size_t i) {
    w.write_string(d.items[i].sku);
    w.write_int(d.items[i].qty);
    w.write_long(d.items[i].price_minor);
  });
}
static Document read_document(AvroReader& r) {
  Document d;
  d.id = r.read_string();
  d.status = r.read_int();
  d.meta.region = r.read_string();
  d.meta.version = r.read_int();
  r.read_array([&]() {
    DocumentItem it;
    it.sku = r.read_string();
    it.qty = r.read_int();
    it.price_minor = r.read_long();
    d.items.push_back(std::move(it));
  });
  return d;
}

static void write_telemetry(AvroWriter& w, const Telemetry& t) {
  w.write_string(t.source);
  w.write_long(t.ts);
  w.write_array(t.tags.size(), [&](size_t i) { w.write_string(t.tags[i]); });
  w.write_array(t.values.size(), [&](size_t i) { w.write_double(t.values[i]); });
}
static Telemetry read_telemetry(AvroReader& r) {
  Telemetry t;
  t.source = r.read_string();
  t.ts = r.read_long();
  r.read_array([&]() { t.tags.push_back(r.read_string()); });
  r.read_array([&]() { t.values.push_back(r.read_double()); });
  return t;
}

static void write_strings(AvroWriter& w, const Strings& s) {
  w.write_array(s.items.size(), [&](size_t i) { w.write_string(s.items[i]); });
}
static Strings read_strings(AvroReader& r) {
  Strings s;
  r.read_array([&]() { s.items.push_back(r.read_string()); });
  return s;
}

static void write_event(AvroWriter& w, const Event& e) {
  w.write_string(e.event_id);
  w.write_string(e.event_type);
  w.write_long(e.occurred_at);
  w.write_string(e.producer);
  w.write_array(e.attrs.size(), [&](size_t i) {
    w.write_string(e.attrs[i].key);
    w.write_string(e.attrs[i].value);
  });
}
static Event read_event(AvroReader& r) {
  Event e;
  e.event_id = r.read_string();
  e.event_type = r.read_string();
  e.occurred_at = r.read_long();
  e.producer = r.read_string();
  r.read_array([&]() {
    EventAttr a;
    a.key = r.read_string();
    a.value = r.read_string();
    e.attrs.push_back(std::move(a));
  });
  return e;
}

static std::vector<uint8_t> encode(const Value& v) {
  AvroWriter w;
  std::visit(
      [&](const auto& x) {
        using T = std::decay_t<decltype(x)>;
        if constexpr (std::is_same_v<T, Message>) write_message(w, x);
        else if constexpr (std::is_same_v<T, Document>) write_document(w, x);
        else if constexpr (std::is_same_v<T, Telemetry>) write_telemetry(w, x);
        else if constexpr (std::is_same_v<T, Strings>) write_strings(w, x);
        else if constexpr (std::is_same_v<T, Event>) write_event(w, x);
        else if constexpr (std::is_same_v<T, std::vector<Message>>) {
          w.write_array(x.size(), [&](size_t i) { write_message(w, x[i]); });
        } else if constexpr (std::is_same_v<T, std::vector<Document>>) {
          w.write_array(x.size(), [&](size_t i) { write_document(w, x[i]); });
        } else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) {
          w.write_array(x.size(), [&](size_t i) { write_telemetry(w, x[i]); });
        } else if constexpr (std::is_same_v<T, std::vector<Strings>>) {
          w.write_array(x.size(), [&](size_t i) { write_strings(w, x[i]); });
        } else if constexpr (std::is_same_v<T, std::vector<Event>>) {
          w.write_array(x.size(), [&](size_t i) { write_event(w, x[i]); });
        }
      },
      v);
  return w.buf;
}

static Value decode(const std::vector<uint8_t>& data, const std::string& type_id, int n) {
  AvroReader r(data);
  if (n > 1) {
    if (type_id == "message") {
      std::vector<Message> v;
      r.read_array([&]() { v.push_back(read_message(r)); });
      return v;
    }
    if (type_id == "document") {
      std::vector<Document> v;
      r.read_array([&]() { v.push_back(read_document(r)); });
      return v;
    }
    if (type_id == "telemetry") {
      std::vector<Telemetry> v;
      r.read_array([&]() { v.push_back(read_telemetry(r)); });
      return v;
    }
    if (type_id == "strings") {
      std::vector<Strings> v;
      r.read_array([&]() { v.push_back(read_strings(r)); });
      return v;
    }
    std::vector<Event> v;
    r.read_array([&]() { v.push_back(read_event(r)); });
    return v;
  }
  if (type_id == "message") return read_message(r);
  if (type_id == "document") return read_document(r);
  if (type_id == "telemetry") return read_telemetry(r);
  if (type_id == "strings") return read_strings(r);
  return read_event(r);
}

class AvroSer final : public ISerializer {
 public:
  const char* name() const override { return "avro"; }
  const char* version() const override { return "binary-1.11"; }
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

SerializerPtr make_avro() { return std::make_unique<AvroSer>(); }

}  // namespace bench
