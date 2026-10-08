#include "bench/serializer.hpp"

#include <algorithm>
#include <cctype>

namespace bench {

SerializerPtr make_nlohmann_json();
SerializerPtr make_glaze();
SerializerPtr make_rapidjson();
SerializerPtr make_simdjson();
SerializerPtr make_arduinojson();
SerializerPtr make_yyjson();
SerializerPtr make_msgpack();
SerializerPtr make_nlohmann_msgpack();
SerializerPtr make_nlohmann_cbor();
SerializerPtr make_nlohmann_ubjson();
SerializerPtr make_nlohmann_bson();
SerializerPtr make_cereal();
SerializerPtr make_bitsery();
SerializerPtr make_zpp_bits();
SerializerPtr make_yas();
SerializerPtr make_cista();
SerializerPtr make_jsoncons_cbor();
SerializerPtr make_jsoncons_bson();
SerializerPtr make_jsoncons_msgpack();
SerializerPtr make_custom_binary();
SerializerPtr make_boost_serialization();
SerializerPtr make_protobuf();       // official libprotobuf (optional)
SerializerPtr make_protobuf_wire();  // in-tree proto3 wire
SerializerPtr make_avro();
SerializerPtr make_avro_c();
SerializerPtr make_thrift();
SerializerPtr make_capnproto();
SerializerPtr make_flexbuffers();
SerializerPtr make_flatbuffers();
SerializerPtr make_yaml_cpp();
SerializerPtr make_arrow_ipc();
SerializerPtr make_parquet();
SerializerPtr make_parquet_uncompressed();
SerializerPtr make_orc();
SerializerPtr make_orc_uncompressed();
SerializerPtr make_sbe();
SerializerPtr make_dagr_packed();         // Dagr, the four node layouts (ser_dagr.cpp)
SerializerPtr make_dagr_regular();
SerializerPtr make_dagr_frozen();
SerializerPtr make_dagr_frozen_packed();

static void add(std::vector<SerializerPtr>& v, SerializerPtr p) {
  if (p) v.push_back(std::move(p));
}

std::vector<SerializerPtr> all_serializers() {
  std::vector<SerializerPtr> v;
  add(v, make_nlohmann_json());
  add(v, make_glaze());
  add(v, make_rapidjson());
  add(v, make_simdjson());
  add(v, make_arduinojson());
  add(v, make_yyjson());
  add(v, make_msgpack());
  add(v, make_nlohmann_msgpack());
  add(v, make_nlohmann_cbor());
  add(v, make_nlohmann_ubjson());
  add(v, make_nlohmann_bson());
  add(v, make_cereal());
  add(v, make_bitsery());
  add(v, make_zpp_bits());
  add(v, make_yas());
  add(v, make_cista());
  add(v, make_jsoncons_cbor());
  add(v, make_jsoncons_bson());
  add(v, make_jsoncons_msgpack());
  add(v, make_custom_binary());
  add(v, make_boost_serialization());
  add(v, make_protobuf());
  add(v, make_protobuf_wire());
  add(v, make_avro());
  add(v, make_avro_c());
  add(v, make_thrift());
  add(v, make_capnproto());
  add(v, make_flexbuffers());
  add(v, make_flatbuffers());
  add(v, make_yaml_cpp());
  // Columnar rows stay at the end so the existing registration order is stable.
  // Arrow factories are nullptr when the prebuilt package is absent.
  add(v, make_arrow_ipc());
  add(v, make_parquet());
  add(v, make_parquet_uncompressed());
  add(v, make_orc());
  add(v, make_orc_uncompressed());
  add(v, make_sbe());
  // Dagr, the four node layouts (ser_dagr.cpp).
  add(v, make_dagr_packed());
  add(v, make_dagr_regular());
  add(v, make_dagr_frozen());
  add(v, make_dagr_frozen_packed());
  return v;
}

static std::string lower_copy(std::string s) {
  for (char& c : s) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  return s;
}

static std::string trim_copy(std::string s) {
  auto not_space = [](unsigned char c) { return !std::isspace(c); };
  s.erase(s.begin(), std::find_if(s.begin(), s.end(), not_space));
  s.erase(std::find_if(s.rbegin(), s.rend(), not_space).base(), s.end());
  return s;
}

std::vector<SerializerPtr> select_serializers(const std::string& filter) {
  auto all = all_serializers();
  if (filter.empty()) return all;
  // A comma means case-insensitive exact names. No comma keeps substring match
  // so a filter of "protobuf" still includes protobuf-wire.
  const bool exact = filter.find(',') != std::string::npos;
  std::vector<std::string> keys;
  if (exact) {
    std::string cur;
    for (size_t i = 0; i <= filter.size(); ++i) {
      if (i == filter.size() || filter[i] == ',') {
        auto token = lower_copy(trim_copy(cur));
        if (!token.empty()) keys.push_back(std::move(token));
        cur.clear();
      } else {
        cur.push_back(filter[i]);
      }
    }
  }
  const std::string needle = lower_copy(filter);
  std::vector<SerializerPtr> out;
  for (auto& s : all) {
    const std::string n = lower_copy(s->name());
    bool keep = false;
    if (exact) {
      for (const auto& k : keys) {
        if (n == k) keep = true;
      }
    } else {
      keep = n.find(needle) != std::string::npos;
    }
    if (keep) out.push_back(std::move(s));
  }
  return out;
}

}  // namespace bench
