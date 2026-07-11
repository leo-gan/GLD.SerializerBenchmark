#include "bench/serializer.hpp"
#include <cstdio>
#include "bench/nlohmann_conv.hpp"

// nlohmann/json binary formats (same library as nlohmann_json text).
// Optimal APIs (docs): json::to_msgpack / from_msgpack, to_cbor / from_cbor,
// to_ubjson / from_ubjson, to_bson / from_bson — operate on structured json values.
// Prepare builds nlohmann::json once (untimed); timed path is format conversion only.

namespace bench {
namespace {

class NlohmannBinBase : public ISerializer {
 public:
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    j_ = value_to_json(fx.value);
  }

 protected:
  std::string type_id_;
  int n_ = 1;
  nlohmann::json j_;

  Value from_json_bytes(const std::vector<uint8_t>& /*unused*/, nlohmann::json j) {
    return json_to_value(j, type_id_, n_);
  }
};

class NlohmannMsgpack final : public NlohmannBinBase {
 public:
  const char* name() const override { return "nlohmann_msgpack"; }
  const char* version() const override {
    static char ver[32];
    std::snprintf(ver, sizeof ver, "%d.%d.%d", NLOHMANN_JSON_VERSION_MAJOR, NLOHMANN_JSON_VERSION_MINOR,
                  NLOHMANN_JSON_VERSION_PATCH);
    return ver;
  }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override { return nlohmann::json::to_msgpack(j_); }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return from_json_bytes(data, nlohmann::json::from_msgpack(data));
  }
};

class NlohmannCbor final : public NlohmannBinBase {
 public:
  const char* name() const override { return "nlohmann_cbor"; }
  const char* version() const override {
    static char ver[32];
    std::snprintf(ver, sizeof ver, "%d.%d.%d", NLOHMANN_JSON_VERSION_MAJOR, NLOHMANN_JSON_VERSION_MINOR,
                  NLOHMANN_JSON_VERSION_PATCH);
    return ver;
  }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override { return nlohmann::json::to_cbor(j_); }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return from_json_bytes(data, nlohmann::json::from_cbor(data));
  }
};

class NlohmannUbjson final : public NlohmannBinBase {
 public:
  const char* name() const override { return "nlohmann_ubjson"; }
  const char* version() const override {
    static char ver[32];
    std::snprintf(ver, sizeof ver, "%d.%d.%d", NLOHMANN_JSON_VERSION_MAJOR, NLOHMANN_JSON_VERSION_MINOR,
                  NLOHMANN_JSON_VERSION_PATCH);
    return ver;
  }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override { return nlohmann::json::to_ubjson(j_); }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return from_json_bytes(data, nlohmann::json::from_ubjson(data));
  }
};

class NlohmannBson final : public NlohmannBinBase {
 public:
  const char* name() const override { return "nlohmann_bson"; }
  const char* version() const override {
    static char ver[32];
    std::snprintf(ver, sizeof ver, "%d.%d.%d", NLOHMANN_JSON_VERSION_MAJOR, NLOHMANN_JSON_VERSION_MINOR,
                  NLOHMANN_JSON_VERSION_PATCH);
    return ver;
  }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    auto raw = value_to_json(fx.value);
    // BSON root must be an object.
    if (raw.is_object()) {
      j_ = std::move(raw);
      wrapped_ = false;
    } else {
      j_ = nlohmann::json{{"items", std::move(raw)}};
      wrapped_ = true;
    }
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override { return nlohmann::json::to_bson(j_); }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    auto j = nlohmann::json::from_bson(data);
    if (wrapped_ && j.is_object() && j.contains("items")) j = j["items"];
    return json_to_value(j, type_id_, n_);
  }

 private:
  bool wrapped_ = false;
};

}  // namespace

SerializerPtr make_nlohmann_msgpack() { return std::make_unique<NlohmannMsgpack>(); }
SerializerPtr make_nlohmann_cbor() { return std::make_unique<NlohmannCbor>(); }
SerializerPtr make_nlohmann_ubjson() { return std::make_unique<NlohmannUbjson>(); }
SerializerPtr make_nlohmann_bson() { return std::make_unique<NlohmannBson>(); }

}  // namespace bench
