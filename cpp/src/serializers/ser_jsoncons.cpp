#include "bench/serializer.hpp"
#include "bench/stream_util.hpp"

#include <jsoncons/config/version.hpp>
#include <jsoncons/json.hpp>
#include <jsoncons/json_traits_macros.hpp>
#include <jsoncons_ext/bson/bson.hpp>
#include <jsoncons_ext/cbor/cbor.hpp>
#include <jsoncons_ext/msgpack/msgpack.hpp>

#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>

// Reflection traits for the suite domain structs (no nlohmann hop).
JSONCONS_ALL_MEMBER_TRAITS(bench::Message, f_bool, f_int32, f_int64, f_float64, f_string,
                           f_bool_2, f_int32_2, f_string_2)
JSONCONS_ALL_MEMBER_TRAITS(bench::DocumentMeta, region, version)
JSONCONS_ALL_MEMBER_TRAITS(bench::DocumentItem, sku, qty, price_minor)
JSONCONS_ALL_MEMBER_TRAITS(bench::Document, id, status, meta, items)
JSONCONS_ALL_MEMBER_TRAITS(bench::Telemetry, source, ts, tags, values)
JSONCONS_ALL_MEMBER_TRAITS(bench::Strings, items)
JSONCONS_ALL_MEMBER_TRAITS(bench::EventAttr, key, value)
JSONCONS_ALL_MEMBER_TRAITS(bench::Event, event_id, event_type, occurred_at, producer, attrs)

namespace bench {
namespace {

#define BENCH_JSONCONS_STR_HELPER(x) #x
#define BENCH_JSONCONS_STR(x) BENCH_JSONCONS_STR_HELPER(x)

const char* jsoncons_version() {
  return BENCH_JSONCONS_STR(JSONCONS_VERSION_MAJOR) "." BENCH_JSONCONS_STR(
      JSONCONS_VERSION_MINOR) "." BENCH_JSONCONS_STR(JSONCONS_VERSION_PATCH);
}

// Encode the concrete alternative, not Value (jsoncons variant traits wrap
// as an array and decode is ambiguous across object-shaped types).
template <typename Encode>
void encode_value(const Value& value, Encode&& encode) {
  std::visit([&](const auto& v) { encode(v); }, value);
}

struct CborBytesSrc {
  const std::vector<uint8_t>& data;
  template <class T>
  T get() const {
    return jsoncons::cbor::decode_cbor<T>(data);
  }
};
struct CborStreamSrc {
  std::istream& is;
  template <class T>
  T get() const {
    return jsoncons::cbor::decode_cbor<T>(is);
  }
};
struct MsgpackBytesSrc {
  const std::vector<uint8_t>& data;
  template <class T>
  T get() const {
    return jsoncons::msgpack::decode_msgpack<T>(data);
  }
};
struct MsgpackStreamSrc {
  std::istream& is;
  template <class T>
  T get() const {
    return jsoncons::msgpack::decode_msgpack<T>(is);
  }
};
struct BsonBytesSrc {
  const std::vector<uint8_t>& data;
  template <class T>
  T get() const {
    return jsoncons::bson::decode_bson<T>(data);
  }
};
struct BsonStreamSrc {
  std::istream& is;
  template <class T>
  T get() const {
    return jsoncons::bson::decode_bson<T>(is);
  }
};
struct BsonItemsSrc {
  const jsoncons::json& items;
  template <class T>
  T get() const {
    return items.template as<T>();
  }
};

// Src must provide `template <class T> T get() const`.
template <typename Src>
Value decode_typed(const std::string& type_id, int n, const Src& src) {
  const bool batch = n > 1;
  if (type_id == "message") {
    if (batch) return src.template get<std::vector<Message>>();
    return src.template get<Message>();
  }
  if (type_id == "document") {
    if (batch) return src.template get<std::vector<Document>>();
    return src.template get<Document>();
  }
  if (type_id == "telemetry") {
    if (batch) return src.template get<std::vector<Telemetry>>();
    return src.template get<Telemetry>();
  }
  if (type_id == "strings") {
    if (batch) return src.template get<std::vector<Strings>>();
    return src.template get<Strings>();
  }
  if (type_id == "event") {
    if (batch) return src.template get<std::vector<Event>>();
    return src.template get<Event>();
  }
  throw std::runtime_error("jsoncons: unknown type_id " + type_id);
}

class JsonconsCbor final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_cbor"; }
  const char* version() const override { return jsoncons_version(); }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture& fixture) override {
    std::vector<uint8_t> buf;
    encode_value(fixture.value, [&](const auto& v) { jsoncons::cbor::encode_cbor(v, buf); });
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return decode_typed(type_id_, n_, CborBytesSrc{data});
  }
  // Docs: encode_cbor(j, ostream) / decode_cbor(istream).
  size_t serialize_stream(const Fixture& fixture, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    encode_value(fixture.value, [&](const auto& v) { jsoncons::cbor::encode_cbor(v, os); });
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return decode_typed(type_id_, n_, CborStreamSrc{is});
  }

 private:
  std::string type_id_;
  int n_ = 1;
};

class JsonconsMsgpack final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_msgpack"; }
  const char* version() const override { return jsoncons_version(); }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture& fixture) override {
    std::vector<uint8_t> buf;
    encode_value(fixture.value,
                 [&](const auto& v) { jsoncons::msgpack::encode_msgpack(v, buf); });
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return decode_typed(type_id_, n_, MsgpackBytesSrc{data});
  }
  // Docs: encode_msgpack(j, ostream) / decode_msgpack(istream).
  size_t serialize_stream(const Fixture& fixture, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    encode_value(fixture.value, [&](const auto& v) { jsoncons::msgpack::encode_msgpack(v, os); });
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return decode_typed(type_id_, n_, MsgpackStreamSrc{is});
  }

 private:
  std::string type_id_;
  int n_ = 1;
};

class JsonconsBson final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_bson"; }
  const char* version() const override { return jsoncons_version(); }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture& fixture) override {
    std::vector<uint8_t> buf;
    encode_bson(fixture.value, buf);
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return decode_bson_buf(data);
  }
  // Docs: encode_bson(j, ostream) / decode_bson(istream).
  size_t serialize_stream(const Fixture& fixture, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    encode_bson_os(fixture.value, os);
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return decode_bson_is(is);
  }

 private:
  // BSON root must be a document. A batch (N>1) is an array — wrap it.
  void encode_bson(const Value& value, std::vector<uint8_t>& buf) {
    if (n_ > 1) {
      jsoncons::json obj(jsoncons::json_object_arg);
      std::visit([&](const auto& v) { obj["items"] = v; }, value);
      jsoncons::bson::encode_bson(obj, buf);
      return;
    }
    encode_value(value, [&](const auto& v) { jsoncons::bson::encode_bson(v, buf); });
  }
  void encode_bson_os(const Value& value, std::ostream& os) {
    if (n_ > 1) {
      jsoncons::json obj(jsoncons::json_object_arg);
      std::visit([&](const auto& v) { obj["items"] = v; }, value);
      jsoncons::bson::encode_bson(obj, os);
      return;
    }
    encode_value(value, [&](const auto& v) { jsoncons::bson::encode_bson(v, os); });
  }
  Value decode_bson_buf(const std::vector<uint8_t>& data) {
    if (n_ > 1) {
      auto obj = jsoncons::bson::decode_bson<jsoncons::json>(data);
      return decode_typed(type_id_, n_, BsonItemsSrc{obj.at("items")});
    }
    return decode_typed(type_id_, n_, BsonBytesSrc{data});
  }
  Value decode_bson_is(std::istream& is) {
    if (n_ > 1) {
      auto obj = jsoncons::bson::decode_bson<jsoncons::json>(is);
      return decode_typed(type_id_, n_, BsonItemsSrc{obj.at("items")});
    }
    return decode_typed(type_id_, n_, BsonStreamSrc{is});
  }

  std::string type_id_;
  int n_ = 1;
};

}  // namespace

SerializerPtr make_jsoncons_cbor() { return std::make_unique<JsonconsCbor>(); }
SerializerPtr make_jsoncons_bson() { return std::make_unique<JsonconsBson>(); }
SerializerPtr make_jsoncons_msgpack() { return std::make_unique<JsonconsMsgpack>(); }

}  // namespace bench
