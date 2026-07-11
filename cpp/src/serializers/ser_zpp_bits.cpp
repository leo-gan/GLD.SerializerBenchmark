#include "bench/serializer.hpp"
#include <zpp_bits.h>
#include <cstring>

namespace bench {
namespace {
class ZppBitsSer final : public ISerializer {
 public:
  const char* name() const override { return "zpp_bits"; }
  const char* version() const override { return "4.4.25"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id; n_ = fx.instance_count; value_ = fx.value;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::vector<std::byte> data;
    zpp::bits::out out(data);
    auto r = std::visit([&](const auto& v) -> zpp::bits::errc {
      using T = std::decay_t<decltype(v)>;
      if constexpr (std::is_same_v<T, Message>)
        return out(v.f_bool, v.f_int32, v.f_int64, v.f_float64, v.f_string, v.f_bool_2, v.f_int32_2, v.f_string_2);
      else if constexpr (std::is_same_v<T, Document>) {
        auto ec = out(v.id, v.status, v.meta.region, v.meta.version, v.items.size());
        if (zpp::bits::failure(ec)) return ec;
        for (const auto& it : v.items) { ec = out(it.sku, it.qty, it.price_minor); if (zpp::bits::failure(ec)) return ec; }
        return {};
      } else if constexpr (std::is_same_v<T, Telemetry>) return out(v.source, v.ts, v.tags, v.values);
      else if constexpr (std::is_same_v<T, Strings>) return out(v.items);
      else if constexpr (std::is_same_v<T, Event>) {
        auto ec = out(v.event_id, v.event_type, v.occurred_at, v.producer, v.attrs.size());
        if (zpp::bits::failure(ec)) return ec;
        for (const auto& a : v.attrs) { ec = out(a.key, a.value); if (zpp::bits::failure(ec)) return ec; }
        return {};
      } else if constexpr (std::is_same_v<T, std::vector<Message>>) {
        auto ec = out(v.size()); if (zpp::bits::failure(ec)) return ec;
        for (const auto& el : v) {
          ec = out(el.f_bool, el.f_int32, el.f_int64, el.f_float64, el.f_string, el.f_bool_2, el.f_int32_2, el.f_string_2);
          if (zpp::bits::failure(ec)) return ec;
        }
        return {};
      } else if constexpr (std::is_same_v<T, std::vector<Document>>) {
        auto ec = out(v.size()); if (zpp::bits::failure(ec)) return ec;
        for (const auto& el : v) {
          ec = out(el.id, el.status, el.meta.region, el.meta.version, el.items.size());
          if (zpp::bits::failure(ec)) return ec;
          for (const auto& it : el.items) { ec = out(it.sku, it.qty, it.price_minor); if (zpp::bits::failure(ec)) return ec; }
        }
        return {};
      } else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) {
        auto ec = out(v.size()); if (zpp::bits::failure(ec)) return ec;
        for (const auto& el : v) { ec = out(el.source, el.ts, el.tags, el.values); if (zpp::bits::failure(ec)) return ec; }
        return {};
      } else if constexpr (std::is_same_v<T, std::vector<Strings>>) {
        auto ec = out(v.size()); if (zpp::bits::failure(ec)) return ec;
        for (const auto& el : v) { ec = out(el.items); if (zpp::bits::failure(ec)) return ec; }
        return {};
      } else if constexpr (std::is_same_v<T, std::vector<Event>>) {
        auto ec = out(v.size()); if (zpp::bits::failure(ec)) return ec;
        for (const auto& el : v) {
          ec = out(el.event_id, el.event_type, el.occurred_at, el.producer, el.attrs.size());
          if (zpp::bits::failure(ec)) return ec;
          for (const auto& a : el.attrs) { ec = out(a.key, a.value); if (zpp::bits::failure(ec)) return ec; }
        }
        return {};
      }
      return std::errc::invalid_argument;
    }, value_);
    if (zpp::bits::failure(r)) throw std::runtime_error("zpp_bits ser failed");
    std::vector<uint8_t> buf(data.size());
    std::memcpy(buf.data(), data.data(), data.size());
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    std::vector<std::byte> bytes(data.size());
    std::memcpy(bytes.data(), data.data(), data.size());
    zpp::bits::in in(bytes);
    auto check = [&](zpp::bits::errc r) {
      if (zpp::bits::failure(r)) throw std::runtime_error("zpp_bits deser failed");
    };
    if (type_id_ == "message") {
      if (n_ > 1) {
        size_t n=0; check(in(n)); std::vector<Message> v(n);
        for (auto& m:v) check(in(m.f_bool,m.f_int32,m.f_int64,m.f_float64,m.f_string,m.f_bool_2,m.f_int32_2,m.f_string_2));
        return v;
      }
      Message m; check(in(m.f_bool,m.f_int32,m.f_int64,m.f_float64,m.f_string,m.f_bool_2,m.f_int32_2,m.f_string_2)); return m;
    }
    if (type_id_ == "document") {
      auto rd=[&](Document& d){ size_t ni=0; check(in(d.id,d.status,d.meta.region,d.meta.version,ni)); d.items.resize(ni);
        for(auto& it:d.items) check(in(it.sku,it.qty,it.price_minor)); };
      if (n_ > 1) { size_t n=0; check(in(n)); std::vector<Document> v(n); for(auto& d:v) rd(d); return v; }
      Document d; rd(d); return d;
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) { size_t n=0; check(in(n)); std::vector<Telemetry> v(n); for(auto& t:v) check(in(t.source,t.ts,t.tags,t.values)); return v; }
      Telemetry t; check(in(t.source,t.ts,t.tags,t.values)); return t;
    }
    if (type_id_ == "strings") {
      if (n_ > 1) { size_t n=0; check(in(n)); std::vector<Strings> v(n); for(auto& s:v) check(in(s.items)); return v; }
      Strings s; check(in(s.items)); return s;
    }
    auto re=[&](Event& e){ size_t na=0; check(in(e.event_id,e.event_type,e.occurred_at,e.producer,na)); e.attrs.resize(na);
      for(auto& a:e.attrs) check(in(a.key,a.value)); };
    if (n_ > 1) { size_t n=0; check(in(n)); std::vector<Event> v(n); for(auto& e:v) re(e); return v; }
    Event e; re(e); return e;
  }
 private:
  std::string type_id_; int n_ = 1; Value value_;
};
}
SerializerPtr make_zpp_bits() { return std::make_unique<ZppBitsSer>(); }
}  // namespace bench
