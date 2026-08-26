#include "bench/serializer.hpp"
#include <cstdio>
#include "bench/nlohmann_conv.hpp"

#include <rapidjson/document.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/writer.h>
#include <rapidjson/ostreamwrapper.h>
#include <rapidjson/istreamwrapper.h>
#include "bench/stream_util.hpp"
#include <simdjson.h>
#include <yyjson.h>
#include <ArduinoJson.h>

#include <cstdint>
#include <cstring>
#include <sstream>

namespace bench {
namespace {

nlohmann::json rapid_to_json(const rapidjson::Value& v) {
  if (v.IsNull()) return nullptr;
  if (v.IsBool()) return v.GetBool();
  if (v.IsInt64()) return v.GetInt64();
  if (v.IsUint64()) return v.GetUint64();
  if (v.IsDouble()) return v.GetDouble();
  if (v.IsString()) return std::string(v.GetString(), v.GetStringLength());
  if (v.IsArray()) {
    nlohmann::json a = nlohmann::json::array();
    for (auto it = v.Begin(); it != v.End(); ++it) a.push_back(rapid_to_json(*it));
    return a;
  }
  if (v.IsObject()) {
    nlohmann::json o = nlohmann::json::object();
    for (auto it = v.MemberBegin(); it != v.MemberEnd(); ++it) {
      o[std::string(it->name.GetString(), it->name.GetStringLength())] = rapid_to_json(it->value);
    }
    return o;
  }
  return nullptr;
}

nlohmann::json simd_to_json(simdjson::dom::element e) {
  switch (e.type()) {
    case simdjson::dom::element_type::ARRAY: {
      nlohmann::json a = nlohmann::json::array();
      for (auto x : e.get_array()) a.push_back(simd_to_json(x));
      return a;
    }
    case simdjson::dom::element_type::OBJECT: {
      nlohmann::json o = nlohmann::json::object();
      for (auto [k, v] : e.get_object()) o[std::string(k)] = simd_to_json(v);
      return o;
    }
    case simdjson::dom::element_type::STRING:
      return std::string(e.get_string().value());
    case simdjson::dom::element_type::INT64:
      return int64_t(e.get_int64());
    case simdjson::dom::element_type::UINT64:
      return uint64_t(e.get_uint64());
    case simdjson::dom::element_type::DOUBLE:
      return double(e.get_double());
    case simdjson::dom::element_type::BOOL:
      return bool(e.get_bool());
    case simdjson::dom::element_type::NULL_VALUE:
    default:
      return nullptr;
  }
}

nlohmann::json yy_to_json(yyjson_val* v) {
  if (!v) return nullptr;
  switch (yyjson_get_type(v)) {
    case YYJSON_TYPE_NULL:
      return nullptr;
    case YYJSON_TYPE_BOOL:
      return yyjson_get_bool(v);
    case YYJSON_TYPE_NUM:
      if (yyjson_is_int(v)) return yyjson_get_sint(v);
      if (yyjson_is_uint(v)) return yyjson_get_uint(v);
      return yyjson_get_real(v);
    case YYJSON_TYPE_STR:
      return std::string(yyjson_get_str(v), yyjson_get_len(v));
    case YYJSON_TYPE_ARR: {
      nlohmann::json a = nlohmann::json::array();
      size_t idx, max;
      yyjson_val* hit;
      yyjson_arr_foreach(v, idx, max, hit) a.push_back(yy_to_json(hit));
      return a;
    }
    case YYJSON_TYPE_OBJ: {
      nlohmann::json o = nlohmann::json::object();
      size_t idx, max;
      yyjson_val *key, *hit;
      yyjson_obj_foreach(v, idx, max, key, hit) {
        o[std::string(yyjson_get_str(key), yyjson_get_len(key))] = yy_to_json(hit);
      }
      return o;
    }
    default:
      return nullptr;
  }
}

nlohmann::json aj_to_json(JsonVariantConst v) {
  if (v.isNull()) return nullptr;
  if (v.is<bool>()) return v.as<bool>();
  if (v.is<const char*>()) return std::string(v.as<const char*>());
  if (v.is<double>()) return v.as<double>();
  if (v.is<long>()) return v.as<long>();
  if (v.is<JsonArrayConst>()) {
    nlohmann::json a = nlohmann::json::array();
    for (JsonVariantConst x : v.as<JsonArrayConst>()) a.push_back(aj_to_json(x));
    return a;
  }
  if (v.is<JsonObjectConst>()) {
    nlohmann::json o = nlohmann::json::object();
    for (JsonPairConst kv : v.as<JsonObjectConst>()) o[kv.key().c_str()] = aj_to_json(kv.value());
    return o;
  }
  return nullptr;
}

// ---------------------------------------------------------------------------
// nlohmann/json — de-facto C++ JSON. Optimal: compact dump / parse iterators.
// ---------------------------------------------------------------------------
class NlohmannJson final : public ISerializer {
 public:
  const char* name() const override { return "nlohmann_json"; }
  const char* version() const override {
    static char ver[32];
    std::snprintf(ver, sizeof ver, "%d.%d.%d", NLOHMANN_JSON_VERSION_MAJOR, NLOHMANN_JSON_VERSION_MINOR,
                  NLOHMANN_JSON_VERSION_PATCH);
    return ver;
  }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    prepared_ = value_to_json(fx.value);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::string s = prepared_.dump();
    return std::vector<uint8_t>(s.begin(), s.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    auto j = nlohmann::json::parse(data.begin(), data.end());
    return json_to_value(j, type_id_, n_);
  }

  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    // Docs: operator<< on ostream is the recommended stream dump path.
    out.clear();
    VecOutStream os(out);
    os << prepared_;
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    // Docs: json::parse(istream&) / parse from stream input.
    VecInStream is(data);
    auto j = nlohmann::json::parse(is);
    return json_to_value(j, type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  nlohmann::json prepared_;
};

// ---------------------------------------------------------------------------
// RapidJSON — Writer serialize + Document parse (recommended hot path).
// ---------------------------------------------------------------------------
class RapidJsonSer final : public ISerializer {
 public:
  const char* name() const override { return "rapidjson"; }
  const char* version() const override { return RAPIDJSON_VERSION_STRING; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "dom"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    // Untimed: build Document once so timed ser is Writer-only (not re-parse).
    cached_json_ = value_to_json(fx.value).dump();
    doc_.SetNull();
    doc_.GetAllocator().Clear();
    doc_.Parse(cached_json_.c_str());
    if (doc_.HasParseError()) throw std::runtime_error("rapidjson prepare parse error");
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    rapidjson::StringBuffer sb;
    rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
    doc_.Accept(writer);
    const char* s = sb.GetString();
    return std::vector<uint8_t>(s, s + sb.GetSize());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    rapidjson::Document doc;
    std::string tmp(data.begin(), data.end());
    doc.Parse(tmp.c_str());
    if (doc.HasParseError()) throw std::runtime_error("rapidjson parse error");
    return json_to_value(rapid_to_json(doc), type_id_, n_);
  }

  // Docs (rapidjson.org Stream): Writer<OStreamWrapper> / ParseStream(IStreamWrapper).
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    rapidjson::OStreamWrapper osw(os);
    rapidjson::Writer<rapidjson::OStreamWrapper> writer(osw);
    doc_.Accept(writer);
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    rapidjson::IStreamWrapper isw(is);
    rapidjson::Document doc;
    doc.ParseStream(isw);
    if (doc.HasParseError()) throw std::runtime_error("rapidjson ParseStream error");
    return json_to_value(rapid_to_json(doc), type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
  rapidjson::Document doc_;
};

// ---------------------------------------------------------------------------
// simdjson — DOM parse (library strength); ser = prepared minified JSON.
// ---------------------------------------------------------------------------
class SimdjsonSer final : public ISerializer {
 public:
  const char* name() const override { return "simdjson"; }
  const char* version() const override { return SIMDJSON_VERSION; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    // Native JSON object only. Timed serialize must write the bytes.
    prepared_ = value_to_json(fx.value);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::string s = prepared_.dump();
    return std::vector<uint8_t>(s.begin(), s.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    simdjson::padded_string ps(reinterpret_cast<const char*>(data.data()), data.size());
    simdjson::dom::element el = parser_.parse(ps);
    return json_to_value(simd_to_json(el), type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  nlohmann::json prepared_;
  simdjson::dom::parser parser_;
};

// ---------------------------------------------------------------------------
// ArduinoJson — widely used embedded/IoT C++ JSON (v7 JsonDocument API).
// Optimal: serializeJson / deserializeJson into reused JsonDocument.
// ---------------------------------------------------------------------------
class ArduinoJsonSer final : public ISerializer {
 public:
  const char* name() const override { return "arduinojson"; }
  const char* version() const override { return ARDUINOJSON_VERSION; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "dom"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    // Use max float digits so ArduinoJson does not shorten doubles for fidelity.
    cached_json_ = value_to_json(fx.value).dump(-1, ' ', false, nlohmann::json::error_handler_t::replace);
    doc_.clear();
    auto err = deserializeJson(doc_, cached_json_);
    if (err) throw std::runtime_error(std::string("ArduinoJson prepare: ") + err.c_str());
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::string s;
    serializeJson(doc_, s);
    return std::vector<uint8_t>(s.begin(), s.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    // Docs: deserializeJson(doc, input, size) is the recommended bytes path.
    JsonDocument d;
    auto err = deserializeJson(d, data.data(), data.size());
    if (err) throw std::runtime_error(std::string("ArduinoJson deser: ") + err.c_str());
    return json_to_value(aj_to_json(d.as<JsonVariantConst>()), type_id_, n_);
  }

  // Docs: serializeJson(doc, stream) / deserializeJson(doc, stream).
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    serializeJson(doc_, os);
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    JsonDocument d;
    VecInStream is(data);
    auto err = deserializeJson(d, is);
    if (err) throw std::runtime_error(std::string("ArduinoJson stream deser: ") + err.c_str());
    return json_to_value(aj_to_json(d.as<JsonVariantConst>()), type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
  JsonDocument doc_;
};

// ---------------------------------------------------------------------------
// yyjson — C library (also first-class from C++). Dual C/C++ suite entry.
// ---------------------------------------------------------------------------
class YyjsonSer final : public ISerializer {
 public:
  const char* name() const override { return "yyjson"; }
  const char* version() const override { return YYJSON_VERSION_STRING; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }

  ~YyjsonSer() override { free_doc(); }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    // Untimed: parse once; timed ser is yyjson_write only.
    free_doc();
    cached_json_ = value_to_json(fx.value).dump();
    doc_ = yyjson_read(cached_json_.c_str(), cached_json_.size(), 0);
    if (!doc_) throw std::runtime_error("yyjson_read failed in prepare");
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    if (!doc_) throw std::runtime_error("yyjson: not prepared");
    size_t len = 0;
    char* out = yyjson_write(doc_, 0, &len);
    if (!out) throw std::runtime_error("yyjson_write failed");
    std::vector<uint8_t> buf(out, out + len);
    free(out);
    return buf;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    yyjson_doc* doc = yyjson_read(reinterpret_cast<const char*>(data.data()), data.size(), 0);
    if (!doc) throw std::runtime_error("yyjson_read failed");
    auto j = yy_to_json(yyjson_doc_get_root(doc));
    yyjson_doc_free(doc);
    return json_to_value(j, type_id_, n_);
  }

 private:
  void free_doc() {
    if (doc_) {
      yyjson_doc_free(doc_);
      doc_ = nullptr;
    }
  }

  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
  yyjson_doc* doc_ = nullptr;
};

}  // namespace

SerializerPtr make_nlohmann_json() { return std::make_unique<NlohmannJson>(); }
SerializerPtr make_rapidjson() { return std::make_unique<RapidJsonSer>(); }
SerializerPtr make_simdjson() { return std::make_unique<SimdjsonSer>(); }
SerializerPtr make_arduinojson() { return std::make_unique<ArduinoJsonSer>(); }
SerializerPtr make_yyjson() { return std::make_unique<YyjsonSer>(); }

}  // namespace bench
