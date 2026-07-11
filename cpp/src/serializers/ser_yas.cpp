#include "bench/serializer.hpp"

#include <yas/serialize.hpp>
#include <yas/std_types.hpp>
#include <yas/binary_oarchive.hpp>
#include <yas/binary_iarchive.hpp>
#include <yas/object.hpp>

// YAS (Yet Another Serialization) — frequently tops C++ binary benchmarks.
// Optimal: yas::mem | yas::binary with YAS_OBJECT_NVP field packs; reuse flags.

namespace bench {
namespace {

constexpr auto kFlags = yas::mem | yas::binary;

template <typename T>
std::vector<uint8_t> yas_save_one(const T& obj, auto nvp_fn) {
  auto buf = yas::save<kFlags>(nvp_fn(obj));
  return std::vector<uint8_t>(buf.data.get(), buf.data.get() + buf.size);
}

class YasSer final : public ISerializer {
 public:
  const char* name() const override { return "yas"; }
  const char* version() const override { return "7.x"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "struct"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    return std::visit(
        [&](const auto& v) -> std::vector<uint8_t> {
          using T = std::decay_t<decltype(v)>;
          if constexpr (std::is_same_v<T, Message>) {
            auto buf = yas::save<kFlags>(YAS_OBJECT_NVP(
                "message", ("f_bool", v.f_bool), ("f_int32", v.f_int32), ("f_int64", v.f_int64),
                ("f_float64", v.f_float64), ("f_string", v.f_string), ("f_bool_2", v.f_bool_2),
                ("f_int32_2", v.f_int32_2), ("f_string_2", v.f_string_2)));
            return {buf.data.get(), buf.data.get() + buf.size};
          } else if constexpr (std::is_same_v<T, Document>) {
            auto buf = yas::save<kFlags>(YAS_OBJECT_NVP(
                "document", ("id", v.id), ("status", v.status), ("region", v.meta.region),
                ("version", v.meta.version), ("items", v.items)));
            return {buf.data.get(), buf.data.get() + buf.size};
          } else if constexpr (std::is_same_v<T, Telemetry>) {
            auto buf = yas::save<kFlags>(
                YAS_OBJECT_NVP("telemetry", ("source", v.source), ("ts", v.ts), ("tags", v.tags),
                               ("values", v.values)));
            return {buf.data.get(), buf.data.get() + buf.size};
          } else if constexpr (std::is_same_v<T, Strings>) {
            auto buf = yas::save<kFlags>(YAS_OBJECT_NVP("strings", ("items", v.items)));
            return {buf.data.get(), buf.data.get() + buf.size};
          } else if constexpr (std::is_same_v<T, Event>) {
            auto buf = yas::save<kFlags>(YAS_OBJECT_NVP(
                "event", ("event_id", v.event_id), ("event_type", v.event_type),
                ("occurred_at", v.occurred_at), ("producer", v.producer), ("attrs", v.attrs)));
            return {buf.data.get(), buf.data.get() + buf.size};
          } else {
            // Batch: serialize vector via YAS std support
            auto buf = yas::save<kFlags>(v);
            return {buf.data.get(), buf.data.get() + buf.size};
          }
        },
        value_);
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    yas::shared_buffer sbuf(reinterpret_cast<const char*>(data.data()), data.size());
    if (type_id_ == "message") {
      if (n_ > 1) {
        std::vector<Message> v;
        yas::load<kFlags>(sbuf, v);
        return v;
      }
      Message m;
      bool f_bool{}, f_bool_2{};
      int32_t f_int32{}, f_int32_2{};
      int64_t f_int64{};
      double f_float64{};
      std::string f_string, f_string_2;
      yas::load<kFlags>(sbuf, YAS_OBJECT_NVP("message", ("f_bool", f_bool), ("f_int32", f_int32),
                                             ("f_int64", f_int64), ("f_float64", f_float64),
                                             ("f_string", f_string), ("f_bool_2", f_bool_2),
                                             ("f_int32_2", f_int32_2), ("f_string_2", f_string_2)));
      return Message{f_bool, f_int32, f_int64, f_float64, f_string, f_bool_2, f_int32_2, f_string_2};
    }
    if (type_id_ == "document") {
      if (n_ > 1) {
        std::vector<Document> v;
        yas::load<kFlags>(sbuf, v);
        return v;
      }
      Document d;
      yas::load<kFlags>(sbuf, YAS_OBJECT_NVP("document", ("id", d.id), ("status", d.status),
                                             ("region", d.meta.region), ("version", d.meta.version),
                                             ("items", d.items)));
      return d;
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) {
        std::vector<Telemetry> v;
        yas::load<kFlags>(sbuf, v);
        return v;
      }
      Telemetry t;
      yas::load<kFlags>(sbuf, YAS_OBJECT_NVP("telemetry", ("source", t.source), ("ts", t.ts),
                                             ("tags", t.tags), ("values", t.values)));
      return t;
    }
    if (type_id_ == "strings") {
      if (n_ > 1) {
        std::vector<Strings> v;
        yas::load<kFlags>(sbuf, v);
        return v;
      }
      Strings s;
      yas::load<kFlags>(sbuf, YAS_OBJECT_NVP("strings", ("items", s.items)));
      return s;
    }
    if (n_ > 1) {
      std::vector<Event> v;
      yas::load<kFlags>(sbuf, v);
      return v;
    }
    Event e;
    yas::load<kFlags>(sbuf, YAS_OBJECT_NVP("event", ("event_id", e.event_id),
                                           ("event_type", e.event_type),
                                           ("occurred_at", e.occurred_at), ("producer", e.producer),
                                           ("attrs", e.attrs)));
    return e;
  }

 private:
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

SerializerPtr make_yas() { return std::make_unique<YasSer>(); }

}  // namespace bench

// YAS needs serialize free functions for nested DocumentItem / EventAttr when using vector save
namespace bench {
template <typename Ar>
void serialize(Ar& ar, DocumentItem& it) {
  ar& YAS_OBJECT_NVP("item", ("sku", it.sku), ("qty", it.qty), ("price_minor", it.price_minor));
}
template <typename Ar>
void serialize(Ar& ar, EventAttr& a) {
  ar& YAS_OBJECT_NVP("attr", ("key", a.key), ("value", a.value));
}
template <typename Ar>
void serialize(Ar& ar, Message& m) {
  ar& YAS_OBJECT_NVP("message", ("f_bool", m.f_bool), ("f_int32", m.f_int32), ("f_int64", m.f_int64),
                     ("f_float64", m.f_float64), ("f_string", m.f_string), ("f_bool_2", m.f_bool_2),
                     ("f_int32_2", m.f_int32_2), ("f_string_2", m.f_string_2));
}
template <typename Ar>
void serialize(Ar& ar, Document& d) {
  ar& YAS_OBJECT_NVP("document", ("id", d.id), ("status", d.status), ("region", d.meta.region),
                     ("version", d.meta.version), ("items", d.items));
}
template <typename Ar>
void serialize(Ar& ar, Telemetry& t) {
  ar& YAS_OBJECT_NVP("telemetry", ("source", t.source), ("ts", t.ts), ("tags", t.tags),
                     ("values", t.values));
}
template <typename Ar>
void serialize(Ar& ar, Strings& s) {
  ar& YAS_OBJECT_NVP("strings", ("items", s.items));
}
template <typename Ar>
void serialize(Ar& ar, Event& e) {
  ar& YAS_OBJECT_NVP("event", ("event_id", e.event_id), ("event_type", e.event_type),
                     ("occurred_at", e.occurred_at), ("producer", e.producer), ("attrs", e.attrs));
}
}  // namespace bench
