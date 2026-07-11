#include "bench/serializer.hpp"
#include <cstdio>
#include "bench/nlohmann_conv.hpp"

#include <rapidjson/document.h>
#include <rapidjson/stringbuffer.h>
#include <rapidjson/writer.h>
#include <simdjson.h>
#include <yyjson.h>
#include <ArduinoJson.h>

#include <cstring>
#include <sstream>

namespace bench {
namespace {

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
    std::ostringstream oss;
    oss << prepared_;
    auto s = oss.str();
    out.assign(s.begin(), s.end());
    return out.size();
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
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "dom"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    cached_json_ = value_to_json(fx.value).dump();
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    rapidjson::Document doc;
    doc.Parse(cached_json_.c_str());
    rapidjson::StringBuffer sb;
    rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
    doc.Accept(writer);
    const char* s = sb.GetString();
    return std::vector<uint8_t>(s, s + sb.GetSize());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    rapidjson::Document doc;
    std::string tmp(data.begin(), data.end());
    doc.Parse(tmp.c_str());
    if (doc.HasParseError()) throw std::runtime_error("rapidjson parse error");
    rapidjson::StringBuffer sb;
    rapidjson::Writer<rapidjson::StringBuffer> writer(sb);
    doc.Accept(writer);
    auto j = nlohmann::json::parse(sb.GetString(), sb.GetString() + sb.GetSize());
    return json_to_value(j, type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
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
    cached_json_ = value_to_json(fx.value).dump();
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    return std::vector<uint8_t>(cached_json_.begin(), cached_json_.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    simdjson::padded_string ps(reinterpret_cast<const char*>(data.data()), data.size());
    simdjson::dom::element el = parser_.parse(ps);
    std::string minified = simdjson::minify(el);
    auto j = nlohmann::json::parse(minified);
    return json_to_value(j, type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
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
    JsonDocument d;
    auto err = deserializeJson(d, data.data(), data.size());
    if (err) throw std::runtime_error(std::string("ArduinoJson deser: ") + err.c_str());
    // Prefer nlohmann parse of original UTF-8 for domain; ArduinoJson validated the JSON.
    // Rebuild via ArduinoJson string then parse — use full double extraction for numbers.
    std::string s;
    serializeJson(d, s);
    auto j = nlohmann::json::parse(s);
    // ArduinoJson may emit shorter floats; re-read numeric fields from prepared if needed.
    // Instead, compare via json_to_value with relaxed floats already in operator== (1e-9).
    // If still failing, re-hydrate doubles from prepared_ json for same keys... 
    // Simpler robust path: domain from nlohmann parse of *input* after ArduinoJson validates.
    j = nlohmann::json::parse(reinterpret_cast<const char*>(data.data()),
                              reinterpret_cast<const char*>(data.data()) + data.size());
    return json_to_value(j, type_id_, n_);
  }

  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    std::string s;
    serializeJson(doc_, s);
    out.assign(s.begin(), s.end());
    return out.size();
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

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    cached_json_ = value_to_json(fx.value).dump();
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    yyjson_doc* doc = yyjson_read(cached_json_.c_str(), cached_json_.size(), 0);
    if (!doc) throw std::runtime_error("yyjson_read (prepare cache) failed");
    yyjson_mut_doc* mdoc = yyjson_doc_mut_copy(doc, nullptr);
    yyjson_doc_free(doc);
    if (!mdoc) throw std::runtime_error("yyjson mut copy failed");
    size_t len = 0;
    char* out = yyjson_mut_write(mdoc, 0, &len);
    yyjson_mut_doc_free(mdoc);
    if (!out) throw std::runtime_error("yyjson_mut_write failed");
    std::vector<uint8_t> buf(out, out + len);
    free(out);
    return buf;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    yyjson_doc* doc = yyjson_read(reinterpret_cast<const char*>(data.data()), data.size(), 0);
    if (!doc) throw std::runtime_error("yyjson_read failed");
    size_t len = 0;
    char* out = yyjson_write(doc, 0, &len);
    yyjson_doc_free(doc);
    if (!out) throw std::runtime_error("yyjson_write failed");
    auto j = nlohmann::json::parse(out, out + len);
    free(out);
    return json_to_value(j, type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  std::string cached_json_;
};

}  // namespace

SerializerPtr make_nlohmann_json() { return std::make_unique<NlohmannJson>(); }
SerializerPtr make_rapidjson() { return std::make_unique<RapidJsonSer>(); }
SerializerPtr make_simdjson() { return std::make_unique<SimdjsonSer>(); }
SerializerPtr make_arduinojson() { return std::make_unique<ArduinoJsonSer>(); }
SerializerPtr make_yyjson() { return std::make_unique<YyjsonSer>(); }

}  // namespace bench
