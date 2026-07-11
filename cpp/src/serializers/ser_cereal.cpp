#include "bench/serializer.hpp"
#include "bench/nlohmann_conv.hpp"
#include "bench/stream_util.hpp"

#include <cereal/archives/binary.hpp>
#include <cereal/types/string.hpp>
#include <cereal/types/vector.hpp>

#include <sstream>

// cereal — BinaryOutput/InputArchive are stream-native (std::ostream / std::istream).
// Bytes path: stringstream; stream path: VecOutStream / VecInStream into the harness vector.

namespace bench {
template <class Archive>
void serialize(Archive& ar, Message& m) {
  ar(m.f_bool, m.f_int32, m.f_int64, m.f_float64, m.f_string, m.f_bool_2, m.f_int32_2, m.f_string_2);
}
template <class Archive>
void serialize(Archive& ar, DocumentMeta& m) { ar(m.region, m.version); }
template <class Archive>
void serialize(Archive& ar, DocumentItem& m) { ar(m.sku, m.qty, m.price_minor); }
template <class Archive>
void serialize(Archive& ar, Document& m) { ar(m.id, m.status, m.meta, m.items); }
template <class Archive>
void serialize(Archive& ar, Telemetry& m) { ar(m.source, m.ts, m.tags, m.values); }
template <class Archive>
void serialize(Archive& ar, Strings& m) { ar(m.items); }
template <class Archive>
void serialize(Archive& ar, EventAttr& m) { ar(m.key, m.value); }
template <class Archive>
void serialize(Archive& ar, Event& m) {
  ar(m.event_id, m.event_type, m.occurred_at, m.producer, m.attrs);
}

namespace {
class CerealSer final : public ISerializer {
 public:
  const char* name() const override { return "cereal"; }
  const char* version() const override { return "1.3.2"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::ostringstream oss(std::ios::binary);
    {
      cereal::BinaryOutputArchive ar(oss);
      std::visit([&](auto& v) { ar(v); }, value_);
    }
    auto s = oss.str();
    return {s.begin(), s.end()};
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    std::string s(data.begin(), data.end());
    std::istringstream iss(s, std::ios::binary);
    return load_from(iss);
  }
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    {
      cereal::BinaryOutputArchive ar(os);
      std::visit([&](auto& v) { ar(v); }, value_);
    }
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return load_from(is);
  }

 private:
  Value load_from(std::istream& is) {
    cereal::BinaryInputArchive ar(is);
    if (type_id_ == "message") {
      if (n_ > 1) {
        std::vector<Message> v;
        ar(v);
        return v;
      }
      Message m;
      ar(m);
      return m;
    }
    if (type_id_ == "document") {
      if (n_ > 1) {
        std::vector<Document> v;
        ar(v);
        return v;
      }
      Document m;
      ar(m);
      return m;
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) {
        std::vector<Telemetry> v;
        ar(v);
        return v;
      }
      Telemetry m;
      ar(m);
      return m;
    }
    if (type_id_ == "strings") {
      if (n_ > 1) {
        std::vector<Strings> v;
        ar(v);
        return v;
      }
      Strings m;
      ar(m);
      return m;
    }
    if (n_ > 1) {
      std::vector<Event> v;
      ar(v);
      return v;
    }
    Event m;
    ar(m);
    return m;
  }

  std::string type_id_;
  int n_ = 1;
  Value value_;
};
}  // namespace
SerializerPtr make_cereal() { return std::make_unique<CerealSer>(); }
}  // namespace bench
