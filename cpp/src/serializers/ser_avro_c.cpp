#include "bench/serializer.hpp"

#if defined(HAS_AVRO_C) && HAS_AVRO_C
// Real Apache Avro C library (avro-c) called from C++ — dual-language with C harness.
// Optimal (same as c/src/serializers/ser_avro_c.c):
//   prepare: parse schema once, cache avro_value_iface_t
//   ser/de: avro_writer_memory / avro_reader_memory + avro_value_write/read
// Payload: kind + custom_binary bytes of domain (full fidelity via shared framing).

#include <avro.h>

#include <cstring>
#include <stdexcept>
#include <vector>

namespace bench {
namespace {

// Minimal length-prefixed domain pack (same field layout as custom_binary helpers).
// Duplicated lightly to avoid linking custom_binary internals.
static void append_u32(std::vector<uint8_t>& o, uint32_t v) {
  o.push_back(v & 0xff);
  o.push_back((v >> 8) & 0xff);
  o.push_back((v >> 16) & 0xff);
  o.push_back((v >> 24) & 0xff);
}
static void append_u64(std::vector<uint8_t>& o, uint64_t v) {
  for (int i = 0; i < 8; ++i) o.push_back((v >> (8 * i)) & 0xff);
}
static void append_f64(std::vector<uint8_t>& o, double d) {
  uint64_t u;
  std::memcpy(&u, &d, 8);
  append_u64(o, u);
}
static void append_str(std::vector<uint8_t>& o, const std::string& s) {
  append_u32(o, static_cast<uint32_t>(s.size()));
  o.insert(o.end(), s.begin(), s.end());
}

// Reuse custom_binary via serialize through a temporary factory? Avoid circular deps —
// pack domain with nlohmann msgpack? Simpler: use Avro native fields for Message only
// and generic record for all types matching full suite schemas.

// Full Avro JSON schemas for suite types (record field order = domain).
static const char* schema_for(const std::string& type_id, int n) {
  if (n > 1) {
    // array of records — build as wrapper
    return nullptr;  // dynamic below
  }
  if (type_id == "message")
    return R"({"type":"record","name":"Message","fields":[
      {"name":"f_bool","type":"boolean"},{"name":"f_int32","type":"int"},
      {"name":"f_int64","type":"long"},{"name":"f_float64","type":"double"},
      {"name":"f_string","type":"string"},{"name":"f_bool_2","type":"boolean"},
      {"name":"f_int32_2","type":"int"},{"name":"f_string_2","type":"string"}]})";
  if (type_id == "document")
    return R"({"type":"record","name":"Document","fields":[
      {"name":"id","type":"string"},{"name":"status","type":"int"},
      {"name":"meta","type":{"type":"record","name":"Meta","fields":[
        {"name":"region","type":"string"},{"name":"version","type":"int"}]}},
      {"name":"items","type":{"type":"array","items":{"type":"record","name":"Item","fields":[
        {"name":"sku","type":"string"},{"name":"qty","type":"int"},
        {"name":"price_minor","type":"long"}]}}}]})";
  if (type_id == "telemetry")
    return R"({"type":"record","name":"Telemetry","fields":[
      {"name":"source","type":"string"},{"name":"ts","type":"long"},
      {"name":"tags","type":{"type":"array","items":"string"}},
      {"name":"values","type":{"type":"array","items":"double"}}]})";
  if (type_id == "strings")
    return R"({"type":"record","name":"Strings","fields":[
      {"name":"items","type":{"type":"array","items":"string"}}]})";
  if (type_id == "event")
    return R"({"type":"record","name":"Event","fields":[
      {"name":"event_id","type":"string"},{"name":"event_type","type":"string"},
      {"name":"occurred_at","type":"long"},{"name":"producer","type":"string"},
      {"name":"attrs","type":{"type":"array","items":{"type":"record","name":"Attr","fields":[
        {"name":"key","type":"string"},{"name":"value","type":"string"}]}}}]})";
  return nullptr;
}

// Fallback envelope used for batches (and if schema build fails): kind + payload bytes
// where payload is suite custom length-prefixed packing via external encode from avro wire
// of single items concatenated — for simplicity batch uses array schema built as JSON.

class AvroCSer final : public ISerializer {
 public:
  const char* name() const override { return "avro_c"; }
  const char* version() const override { return "avro-c"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }

  ~AvroCSer() override { reset_schema(); }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
    reset_schema();
    std::string schema_json;
    if (n_ > 1) {
      // array of the element schema
      const char* el = schema_for(type_id_, 1);
      if (!el) throw std::runtime_error("avro_c: unknown type");
      schema_json = std::string("{\"type\":\"array\",\"items\":") + el + "}";
    } else {
      const char* el = schema_for(type_id_, 1);
      if (!el) throw std::runtime_error("avro_c: unknown type");
      schema_json = el;
    }
    if (avro_schema_from_json_length(schema_json.c_str(), schema_json.size(), &schema_)) {
      throw std::runtime_error(std::string("avro schema: ") + avro_strerror());
    }
    iface_ = avro_generic_class_from_schema(schema_);
    if (!iface_) throw std::runtime_error("avro iface failed");
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    avro_value_t root;
    if (avro_generic_value_new(iface_, &root)) throw std::runtime_error("avro value new");
    try {
      fill_value(&root, value_);
    } catch (...) {
      avro_value_decref(&root);
      throw;
    }
    // avro_writer_memory needs a fixed capacity. Grow from a modest base — do NOT
    // zero-fill multi-MB buffers every call (was 8MiB; dominated n=1 and fake BATCH-AXIS).
    // Docs: https://avro.apache.org/docs/1.11.1/api/c/ (value write + memory writer)
    if (write_buf_.capacity() < 4096) write_buf_.reserve(4096);
    for (;;) {
      write_buf_.resize(write_buf_.capacity() > 0 ? write_buf_.capacity() : 4096);
      avro_writer_t w =
          avro_writer_memory(reinterpret_cast<char*>(write_buf_.data()), write_buf_.size());
      int rc = avro_value_write(w, &root);
      size_t n = avro_writer_tell(w);
      avro_writer_free(w);
      if (rc == 0) {
        avro_value_decref(&root);
        return std::vector<uint8_t>(write_buf_.begin(), write_buf_.begin() + static_cast<std::ptrdiff_t>(n));
      }
      // grow and retry (capacity exhaustion or other write error → grow once, then surface)
      if (write_buf_.capacity() >= 64 * 1024 * 1024) {
        avro_value_decref(&root);
        throw std::runtime_error(std::string("avro write: ") + avro_strerror());
      }
      write_buf_.reserve(write_buf_.capacity() * 2);
    }
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    avro_value_t root;
    if (avro_generic_value_new(iface_, &root)) throw std::runtime_error("avro value new");
    avro_reader_t r =
        avro_reader_memory(reinterpret_cast<const char*>(data.data()), data.size());
    if (avro_value_read(r, &root)) {
      avro_reader_free(r);
      avro_value_decref(&root);
      throw std::runtime_error(std::string("avro read: ") + avro_strerror());
    }
    avro_reader_free(r);
    Value out;
    try {
      out = extract_value(&root);
    } catch (...) {
      avro_value_decref(&root);
      throw;
    }
    avro_value_decref(&root);
    return out;
  }

 private:
  void reset_schema() {
    if (iface_) {
      avro_value_iface_decref(iface_);
      iface_ = nullptr;
    }
    if (schema_) {
      avro_schema_decref(schema_);
      schema_ = nullptr;
    }
  }

  static void set_string(avro_value_t* field, const std::string& s) {
    if (avro_value_set_string_len(field, s.c_str(), s.size() + 1))  // includes NUL per API
      throw std::runtime_error(avro_strerror());
  }

  void fill_message(avro_value_t* v, const Message& m) {
    avro_value_t f;
    avro_value_get_by_name(v, "f_bool", &f, nullptr);
    avro_value_set_boolean(&f, m.f_bool);
    avro_value_get_by_name(v, "f_int32", &f, nullptr);
    avro_value_set_int(&f, m.f_int32);
    avro_value_get_by_name(v, "f_int64", &f, nullptr);
    avro_value_set_long(&f, m.f_int64);
    avro_value_get_by_name(v, "f_float64", &f, nullptr);
    avro_value_set_double(&f, m.f_float64);
    avro_value_get_by_name(v, "f_string", &f, nullptr);
    set_string(&f, m.f_string);
    avro_value_get_by_name(v, "f_bool_2", &f, nullptr);
    avro_value_set_boolean(&f, m.f_bool_2);
    avro_value_get_by_name(v, "f_int32_2", &f, nullptr);
    avro_value_set_int(&f, m.f_int32_2);
    avro_value_get_by_name(v, "f_string_2", &f, nullptr);
    set_string(&f, m.f_string_2);
  }

  void fill_document(avro_value_t* v, const Document& d) {
    avro_value_t f, meta, items, item;
    avro_value_get_by_name(v, "id", &f, nullptr);
    set_string(&f, d.id);
    avro_value_get_by_name(v, "status", &f, nullptr);
    avro_value_set_int(&f, d.status);
    avro_value_get_by_name(v, "meta", &meta, nullptr);
    avro_value_get_by_name(&meta, "region", &f, nullptr);
    set_string(&f, d.meta.region);
    avro_value_get_by_name(&meta, "version", &f, nullptr);
    avro_value_set_int(&f, d.meta.version);
    avro_value_get_by_name(v, "items", &items, nullptr);
    for (size_t i = 0; i < d.items.size(); ++i) {
      size_t idx = 0;
      if (avro_value_append(&items, &item, &idx)) throw std::runtime_error(avro_strerror());
      avro_value_get_by_name(&item, "sku", &f, nullptr);
      set_string(&f, d.items[i].sku);
      avro_value_get_by_name(&item, "qty", &f, nullptr);
      avro_value_set_int(&f, d.items[i].qty);
      avro_value_get_by_name(&item, "price_minor", &f, nullptr);
      avro_value_set_long(&f, d.items[i].price_minor);
    }
  }

  void fill_telemetry(avro_value_t* v, const Telemetry& t) {
    avro_value_t f, arr, el;
    avro_value_get_by_name(v, "source", &f, nullptr);
    set_string(&f, t.source);
    avro_value_get_by_name(v, "ts", &f, nullptr);
    avro_value_set_long(&f, t.ts);
    avro_value_get_by_name(v, "tags", &arr, nullptr);
    for (size_t i = 0; i < t.tags.size(); ++i) {
      size_t idx = 0;
      if (avro_value_append(&arr, &el, &idx)) throw std::runtime_error(avro_strerror());
      set_string(&el, t.tags[i]);
    }
    avro_value_get_by_name(v, "values", &arr, nullptr);
    for (size_t i = 0; i < t.values.size(); ++i) {
      size_t idx = 0;
      if (avro_value_append(&arr, &el, &idx)) throw std::runtime_error(avro_strerror());
      avro_value_set_double(&el, t.values[i]);
    }
  }

  void fill_strings(avro_value_t* v, const Strings& s) {
    avro_value_t arr, el;
    avro_value_get_by_name(v, "items", &arr, nullptr);
    for (size_t i = 0; i < s.items.size(); ++i) {
      size_t idx = 0;
      if (avro_value_append(&arr, &el, &idx)) throw std::runtime_error(avro_strerror());
      set_string(&el, s.items[i]);
    }
  }

  void fill_event(avro_value_t* v, const Event& e) {
    avro_value_t f, arr, el, a;
    avro_value_get_by_name(v, "event_id", &f, nullptr);
    set_string(&f, e.event_id);
    avro_value_get_by_name(v, "event_type", &f, nullptr);
    set_string(&f, e.event_type);
    avro_value_get_by_name(v, "occurred_at", &f, nullptr);
    avro_value_set_long(&f, e.occurred_at);
    avro_value_get_by_name(v, "producer", &f, nullptr);
    set_string(&f, e.producer);
    avro_value_get_by_name(v, "attrs", &arr, nullptr);
    for (size_t i = 0; i < e.attrs.size(); ++i) {
      size_t idx = 0;
      if (avro_value_append(&arr, &el, &idx)) throw std::runtime_error(avro_strerror());
      avro_value_get_by_name(&el, "key", &a, nullptr);
      set_string(&a, e.attrs[i].key);
      avro_value_get_by_name(&el, "value", &a, nullptr);
      set_string(&a, e.attrs[i].value);
    }
  }

  void fill_value(avro_value_t* root, const Value& val) {
    std::visit(
        [&](const auto& x) {
          using T = std::decay_t<decltype(x)>;
          if constexpr (std::is_same_v<T, Message>) fill_message(root, x);
          else if constexpr (std::is_same_v<T, Document>) fill_document(root, x);
          else if constexpr (std::is_same_v<T, Telemetry>) fill_telemetry(root, x);
          else if constexpr (std::is_same_v<T, Strings>) fill_strings(root, x);
          else if constexpr (std::is_same_v<T, Event>) fill_event(root, x);
          else {
            // batch array
            for (size_t i = 0; i < x.size(); ++i) {
              avro_value_t el;
              size_t idx = 0;
              if (avro_value_append(root, &el, &idx)) throw std::runtime_error(avro_strerror());
              if constexpr (std::is_same_v<T, std::vector<Message>>) fill_message(&el, x[i]);
              else if constexpr (std::is_same_v<T, std::vector<Document>>) fill_document(&el, x[i]);
              else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) fill_telemetry(&el, x[i]);
              else if constexpr (std::is_same_v<T, std::vector<Strings>>) fill_strings(&el, x[i]);
              else if constexpr (std::is_same_v<T, std::vector<Event>>) fill_event(&el, x[i]);
            }
          }
        },
        val);
  }

  static std::string get_string(avro_value_t* f) {
    const char* s = nullptr;
    size_t len = 0;
    if (avro_value_get_string(f, &s, &len)) throw std::runtime_error(avro_strerror());
    // len includes trailing NUL
    if (len > 0) return std::string(s, len - 1);
    return {};
  }

  Message extract_message(avro_value_t* v) {
    Message m;
    avro_value_t f;
    int b = 0;
    avro_value_get_by_name(v, "f_bool", &f, nullptr);
    avro_value_get_boolean(&f, &b);
    m.f_bool = b != 0;
    avro_value_get_by_name(v, "f_int32", &f, nullptr);
    avro_value_get_int(&f, &m.f_int32);
    avro_value_get_by_name(v, "f_int64", &f, nullptr);
    avro_value_get_long(&f, &m.f_int64);
    avro_value_get_by_name(v, "f_float64", &f, nullptr);
    avro_value_get_double(&f, &m.f_float64);
    avro_value_get_by_name(v, "f_string", &f, nullptr);
    m.f_string = get_string(&f);
    avro_value_get_by_name(v, "f_bool_2", &f, nullptr);
    avro_value_get_boolean(&f, &b);
    m.f_bool_2 = b != 0;
    avro_value_get_by_name(v, "f_int32_2", &f, nullptr);
    avro_value_get_int(&f, &m.f_int32_2);
    avro_value_get_by_name(v, "f_string_2", &f, nullptr);
    m.f_string_2 = get_string(&f);
    return m;
  }

  Document extract_document(avro_value_t* v) {
    Document d;
    avro_value_t f, meta, items, item;
    size_t n = 0;
    avro_value_get_by_name(v, "id", &f, nullptr);
    d.id = get_string(&f);
    avro_value_get_by_name(v, "status", &f, nullptr);
    avro_value_get_int(&f, &d.status);
    avro_value_get_by_name(v, "meta", &meta, nullptr);
    avro_value_get_by_name(&meta, "region", &f, nullptr);
    d.meta.region = get_string(&f);
    avro_value_get_by_name(&meta, "version", &f, nullptr);
    avro_value_get_int(&f, &d.meta.version);
    avro_value_get_by_name(v, "items", &items, nullptr);
    avro_value_get_size(&items, &n);
    d.items.resize(n);
    for (size_t i = 0; i < n; ++i) {
      avro_value_get_by_index(&items, i, &item, nullptr);
      avro_value_get_by_name(&item, "sku", &f, nullptr);
      d.items[i].sku = get_string(&f);
      avro_value_get_by_name(&item, "qty", &f, nullptr);
      avro_value_get_int(&f, &d.items[i].qty);
      avro_value_get_by_name(&item, "price_minor", &f, nullptr);
      avro_value_get_long(&f, &d.items[i].price_minor);
    }
    return d;
  }

  Telemetry extract_telemetry(avro_value_t* v) {
    Telemetry t;
    avro_value_t f, arr, el;
    size_t n = 0;
    avro_value_get_by_name(v, "source", &f, nullptr);
    t.source = get_string(&f);
    avro_value_get_by_name(v, "ts", &f, nullptr);
    avro_value_get_long(&f, &t.ts);
    avro_value_get_by_name(v, "tags", &arr, nullptr);
    avro_value_get_size(&arr, &n);
    t.tags.resize(n);
    for (size_t i = 0; i < n; ++i) {
      avro_value_get_by_index(&arr, i, &el, nullptr);
      t.tags[i] = get_string(&el);
    }
    avro_value_get_by_name(v, "values", &arr, nullptr);
    avro_value_get_size(&arr, &n);
    t.values.resize(n);
    for (size_t i = 0; i < n; ++i) {
      avro_value_get_by_index(&arr, i, &el, nullptr);
      avro_value_get_double(&el, &t.values[i]);
    }
    return t;
  }

  Strings extract_strings(avro_value_t* v) {
    Strings s;
    avro_value_t arr, el;
    size_t n = 0;
    avro_value_get_by_name(v, "items", &arr, nullptr);
    avro_value_get_size(&arr, &n);
    s.items.resize(n);
    for (size_t i = 0; i < n; ++i) {
      avro_value_get_by_index(&arr, i, &el, nullptr);
      s.items[i] = get_string(&el);
    }
    return s;
  }

  Event extract_event(avro_value_t* v) {
    Event e;
    avro_value_t f, arr, el, a;
    size_t n = 0;
    avro_value_get_by_name(v, "event_id", &f, nullptr);
    e.event_id = get_string(&f);
    avro_value_get_by_name(v, "event_type", &f, nullptr);
    e.event_type = get_string(&f);
    avro_value_get_by_name(v, "occurred_at", &f, nullptr);
    avro_value_get_long(&f, &e.occurred_at);
    avro_value_get_by_name(v, "producer", &f, nullptr);
    e.producer = get_string(&f);
    avro_value_get_by_name(v, "attrs", &arr, nullptr);
    avro_value_get_size(&arr, &n);
    e.attrs.resize(n);
    for (size_t i = 0; i < n; ++i) {
      avro_value_get_by_index(&arr, i, &el, nullptr);
      avro_value_get_by_name(&el, "key", &a, nullptr);
      e.attrs[i].key = get_string(&a);
      avro_value_get_by_name(&el, "value", &a, nullptr);
      e.attrs[i].value = get_string(&a);
    }
    return e;
  }

  Value extract_value(avro_value_t* root) {
    if (n_ > 1) {
      size_t n = 0;
      avro_value_get_size(root, &n);
      avro_value_t el;
      if (type_id_ == "message") {
        std::vector<Message> v(n);
        for (size_t i = 0; i < n; ++i) {
          avro_value_get_by_index(root, i, &el, nullptr);
          v[i] = extract_message(&el);
        }
        return v;
      }
      if (type_id_ == "document") {
        std::vector<Document> v(n);
        for (size_t i = 0; i < n; ++i) {
          avro_value_get_by_index(root, i, &el, nullptr);
          v[i] = extract_document(&el);
        }
        return v;
      }
      if (type_id_ == "telemetry") {
        std::vector<Telemetry> v(n);
        for (size_t i = 0; i < n; ++i) {
          avro_value_get_by_index(root, i, &el, nullptr);
          v[i] = extract_telemetry(&el);
        }
        return v;
      }
      if (type_id_ == "strings") {
        std::vector<Strings> v(n);
        for (size_t i = 0; i < n; ++i) {
          avro_value_get_by_index(root, i, &el, nullptr);
          v[i] = extract_strings(&el);
        }
        return v;
      }
      std::vector<Event> v(n);
      for (size_t i = 0; i < n; ++i) {
        avro_value_get_by_index(root, i, &el, nullptr);
        v[i] = extract_event(&el);
      }
      return v;
    }
    if (type_id_ == "message") return extract_message(root);
    if (type_id_ == "document") return extract_document(root);
    if (type_id_ == "telemetry") return extract_telemetry(root);
    if (type_id_ == "strings") return extract_strings(root);
    return extract_event(root);
  }

  std::string type_id_;
  int n_ = 1;
  Value value_;
  avro_schema_t schema_ = nullptr;
  avro_value_iface_t* iface_ = nullptr;
  std::vector<uint8_t> write_buf_;  // reused capacity across timed serializes
};

}  // namespace

SerializerPtr make_avro_c() { return std::make_unique<AvroCSer>(); }

}  // namespace bench

#else
namespace bench {
SerializerPtr make_avro_c() { return nullptr; }
}
#endif
