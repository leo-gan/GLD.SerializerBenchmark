#include "bench/serializer.hpp"

#include <algorithm>
#include <cctype>

namespace bench {

// Factory decls (defined in ser_*.cpp)
SerializerPtr make_nlohmann_json();
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
SerializerPtr make_protobuf();
SerializerPtr make_avro();
SerializerPtr make_flexbuffers();
SerializerPtr make_flatbuffers();

std::vector<SerializerPtr> all_serializers() {
  std::vector<SerializerPtr> v;
  // JSON text
  v.push_back(make_nlohmann_json());
  v.push_back(make_rapidjson());
  v.push_back(make_simdjson());
  v.push_back(make_arduinojson());
  v.push_back(make_yyjson());
  // Schemaless binary
  v.push_back(make_msgpack());
  v.push_back(make_nlohmann_msgpack());
  v.push_back(make_nlohmann_cbor());
  v.push_back(make_nlohmann_ubjson());
  v.push_back(make_nlohmann_bson());
  v.push_back(make_cereal());
  v.push_back(make_bitsery());
  v.push_back(make_zpp_bits());
  v.push_back(make_yas());
  v.push_back(make_cista());
  v.push_back(make_jsoncons_cbor());
  v.push_back(make_jsoncons_bson());
  v.push_back(make_jsoncons_msgpack());
  v.push_back(make_custom_binary());
  // Schema / IDL family
  v.push_back(make_protobuf());
  v.push_back(make_avro());
  v.push_back(make_flexbuffers());
  v.push_back(make_flatbuffers());
  return v;
}

std::vector<SerializerPtr> select_serializers(const std::string& filter) {
  auto all = all_serializers();
  if (filter.empty()) return all;
  std::string f = filter;
  for (char& c : f) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
  std::vector<SerializerPtr> out;
  for (auto& s : all) {
    std::string n = s->name();
    for (char& c : n) c = static_cast<char>(std::tolower(static_cast<unsigned char>(c)));
    if (n.find(f) != std::string::npos) out.push_back(std::move(s));
  }
  return out;
}

}  // namespace bench
