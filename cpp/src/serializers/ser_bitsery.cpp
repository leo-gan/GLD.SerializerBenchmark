#include "bench/serializer.hpp"
#include <bitsery/bitsery.h>
#include <bitsery/adapter/buffer.h>
#include <bitsery/traits/string.h>
#include <bitsery/traits/vector.h>
#include <type_traits>

namespace bitsery {
template <typename S>
void serialize(S& s, bench::Message& m) {
  s.value1b(m.f_bool); s.value4b(m.f_int32); s.value8b(m.f_int64); s.value8b(m.f_float64);
  s.text1b(m.f_string, 1024); s.value1b(m.f_bool_2); s.value4b(m.f_int32_2); s.text1b(m.f_string_2, 1024);
}
template <typename S>
void serialize(S& s, bench::DocumentMeta& m) { s.text1b(m.region, 256); s.value4b(m.version); }
template <typename S>
void serialize(S& s, bench::DocumentItem& m) {
  s.text1b(m.sku, 256); s.value4b(m.qty); s.value8b(m.price_minor);
}
template <typename S>
void serialize(S& s, bench::Document& m) {
  s.text1b(m.id, 256); s.value4b(m.status); s.object(m.meta); s.container(m.items, 10000);
}
template <typename S>
void serialize(S& s, bench::Telemetry& m) {
  s.text1b(m.source, 256); s.value8b(m.ts);
  s.container(m.tags, 10000, [](S& s2, std::string& t) { s2.text1b(t, 256); });
  s.container(m.values, 100000, [](S& s2, double& v) { s2.value8b(v); });
}
template <typename S>
void serialize(S& s, bench::Strings& m) {
  s.container(m.items, 100000, [](S& s2, std::string& t) { s2.text1b(t, 1024); });
}
template <typename S>
void serialize(S& s, bench::EventAttr& m) { s.text1b(m.key, 256); s.text1b(m.value, 256); }
template <typename S>
void serialize(S& s, bench::Event& m) {
  s.text1b(m.event_id, 256); s.text1b(m.event_type, 256); s.value8b(m.occurred_at);
  s.text1b(m.producer, 256); s.container(m.attrs, 10000);
}
}  // namespace bitsery

namespace bench {
namespace {
class BitserySer final : public ISerializer {
 public:
  using Buffer = std::vector<uint8_t>;
  using OutputAdapter = bitsery::OutputBufferAdapter<Buffer>;
  using InputAdapter = bitsery::InputBufferAdapter<Buffer>;
  const char* name() const override { return "bitsery"; }
  const char* version() const override { return "5.2.4"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id; n_ = fx.instance_count; value_ = fx.value;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    buf_.clear();
    bitsery::Serializer<OutputAdapter> ser{OutputAdapter{buf_}};
    std::visit([&](auto& v) {
      using T = std::decay_t<decltype(v)>;
      if constexpr (std::is_same_v<T, std::vector<Message>> || std::is_same_v<T, std::vector<Document>> ||
                    std::is_same_v<T, std::vector<Telemetry>> || std::is_same_v<T, std::vector<Strings>> ||
                    std::is_same_v<T, std::vector<Event>>) {
        ser.container(v, 100000);
      } else {
        ser.object(v);
      }
    }, value_);
    auto written = ser.adapter().writtenBytesCount();
    return {buf_.begin(), buf_.begin() + static_cast<std::ptrdiff_t>(written)};
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    Buffer in = data;
    bitsery::Deserializer<InputAdapter> des{InputAdapter{in.begin(), in.size()}};
    auto check = [&]() {
      auto err = des.adapter().error();
      if (err != bitsery::ReaderError::NoError) throw std::runtime_error("bitsery deser failed");
    };
    if (type_id_ == "message") {
      if (n_ > 1) { std::vector<Message> out; des.container(out, 100000); check(); return out; }
      Message out{}; des.object(out); check(); return out;
    }
    if (type_id_ == "document") {
      if (n_ > 1) { std::vector<Document> out; des.container(out, 100000); check(); return out; }
      Document out{}; des.object(out); check(); return out;
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) { std::vector<Telemetry> out; des.container(out, 100000); check(); return out; }
      Telemetry out{}; des.object(out); check(); return out;
    }
    if (type_id_ == "strings") {
      if (n_ > 1) { std::vector<Strings> out; des.container(out, 100000); check(); return out; }
      Strings out{}; des.object(out); check(); return out;
    }
    if (n_ > 1) { std::vector<Event> out; des.container(out, 100000); check(); return out; }
    Event out{}; des.object(out); check(); return out;
  }
 private:
  std::string type_id_; int n_ = 1; Value value_; Buffer buf_;
};
}
SerializerPtr make_bitsery() { return std::make_unique<BitserySer>(); }
}  // namespace bench
