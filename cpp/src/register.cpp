#include "bench/serializer.hpp"

#include <algorithm>
#include <cctype>

namespace bench {

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
SerializerPtr make_boost_serialization();
SerializerPtr make_protobuf();
SerializerPtr make_avro();
SerializerPtr make_avro_c();
SerializerPtr make_thrift();
SerializerPtr make_capnproto();
SerializerPtr make_flexbuffers();
SerializerPtr make_flatbuffers();

static void add(std::vector<SerializerPtr>& v, SerializerPtr p) {
  if (p) v.push_back(std::move(p));
}

std::vector<SerializerPtr> all_serializers() {
  std::vector<SerializerPtr> v;
  add(v, make_nlohmann_json());
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
  add(v, make_avro());
  add(v, make_avro_c());
  add(v, make_thrift());
  add(v, make_capnproto());
  add(v, make_flexbuffers());
  add(v, make_flatbuffers());
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
