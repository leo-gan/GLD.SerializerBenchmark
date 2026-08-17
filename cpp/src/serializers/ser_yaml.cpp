#include "bench/serializer.hpp"

#include <yaml-cpp/yaml.h>

#include <sstream>
#include <string>
#include <variant>
#include <vector>

namespace bench {
namespace {

YAML::Node node_of(const Message& m) {
  YAML::Node n;
  n["f_bool"] = m.f_bool;
  n["f_int32"] = m.f_int32;
  n["f_int64"] = m.f_int64;
  n["f_float64"] = m.f_float64;
  n["f_string"] = m.f_string;
  n["f_bool_2"] = m.f_bool_2;
  n["f_int32_2"] = m.f_int32_2;
  n["f_string_2"] = m.f_string_2;
  return n;
}
void from_node(const YAML::Node& n, Message& m) {
  m.f_bool = n["f_bool"].as<bool>();
  m.f_int32 = n["f_int32"].as<int32_t>();
  m.f_int64 = n["f_int64"].as<int64_t>();
  m.f_float64 = n["f_float64"].as<double>();
  m.f_string = n["f_string"].as<std::string>("");
  m.f_bool_2 = n["f_bool_2"].as<bool>();
  m.f_int32_2 = n["f_int32_2"].as<int32_t>();
  m.f_string_2 = n["f_string_2"].as<std::string>("");
}

YAML::Node node_of(const Document& d) {
  YAML::Node n;
  n["id"] = d.id;
  n["status"] = d.status;
  n["meta"]["region"] = d.meta.region;
  n["meta"]["version"] = d.meta.version;
  for (const auto& it : d.items) {
    YAML::Node item;
    item["sku"] = it.sku;
    item["qty"] = it.qty;
    item["price_minor"] = it.price_minor;
    n["items"].push_back(item);
  }
  return n;
}
void from_node(const YAML::Node& n, Document& d) {
  d.id = n["id"].as<std::string>("");
  d.status = n["status"].as<int32_t>();
  if (n["meta"]) {
    d.meta.region = n["meta"]["region"].as<std::string>("");
    d.meta.version = n["meta"]["version"].as<int32_t>();
  }
  d.items.clear();
  if (n["items"]) {
    for (const auto& it : n["items"]) {
      DocumentItem item;
      item.sku = it["sku"].as<std::string>("");
      item.qty = it["qty"].as<int32_t>();
      item.price_minor = it["price_minor"].as<int64_t>();
      d.items.push_back(std::move(item));
    }
  }
}

YAML::Node node_of(const Telemetry& t) {
  YAML::Node n;
  n["source"] = t.source;
  n["ts"] = t.ts;
  for (const auto& tag : t.tags) n["tags"].push_back(tag);
  for (double v : t.values) n["values"].push_back(v);
  return n;
}
void from_node(const YAML::Node& n, Telemetry& t) {
  t.source = n["source"].as<std::string>("");
  t.ts = n["ts"].as<int64_t>();
  t.tags.clear();
  if (n["tags"])
    for (const auto& tag : n["tags"]) t.tags.push_back(tag.as<std::string>());
  t.values.clear();
  if (n["values"])
    for (const auto& v : n["values"]) t.values.push_back(v.as<double>());
}

YAML::Node node_of(const Strings& s) {
  YAML::Node n;
  for (const auto& it : s.items) n["items"].push_back(it);
  return n;
}
void from_node(const YAML::Node& n, Strings& s) {
  s.items.clear();
  if (n["items"])
    for (const auto& it : n["items"]) s.items.push_back(it.as<std::string>());
}

YAML::Node node_of(const Event& e) {
  YAML::Node n;
  n["event_id"] = e.event_id;
  n["event_type"] = e.event_type;
  n["occurred_at"] = e.occurred_at;
  n["producer"] = e.producer;
  for (const auto& a : e.attrs) {
    YAML::Node item;
    item["key"] = a.key;
    item["value"] = a.value;
    n["attrs"].push_back(item);
  }
  return n;
}
void from_node(const YAML::Node& n, Event& e) {
  e.event_id = n["event_id"].as<std::string>("");
  e.event_type = n["event_type"].as<std::string>("");
  e.occurred_at = n["occurred_at"].as<int64_t>();
  e.producer = n["producer"].as<std::string>("");
  e.attrs.clear();
  if (n["attrs"]) {
    for (const auto& a : n["attrs"]) {
      EventAttr item;
      item.key = a["key"].as<std::string>("");
      item.value = a["value"].as<std::string>("");
      e.attrs.push_back(std::move(item));
    }
  }
}

template <typename T>
YAML::Node node_of_list(const std::vector<T>& xs) {
  YAML::Node n(YAML::NodeType::Sequence);
  for (const auto& x : xs) n.push_back(node_of(x));
  return n;
}

class YamlCppSer final : public ISerializer {
 public:
  const char* name() const override { return "yaml-cpp"; }
  const char* version() const override { return "0.8.0"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    prepared_ = std::visit([](const auto& v) -> YAML::Node {
      using T = std::decay_t<decltype(v)>;
      if constexpr (std::is_same_v<T, Message> || std::is_same_v<T, Document> ||
                    std::is_same_v<T, Telemetry> || std::is_same_v<T, Strings> ||
                    std::is_same_v<T, Event>) {
        return node_of(v);
      } else {
        return node_of_list(v);
      }
    },
                           fx.value);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::string s = YAML::Dump(prepared_);
    return std::vector<uint8_t>(s.begin(), s.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    YAML::Node n = YAML::Load(std::string(data.begin(), data.end()));
    return load_value(n);
  }

  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    std::ostringstream oss;
    oss << prepared_;
    std::string s = oss.str();
    out.assign(s.begin(), s.end());
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    std::istringstream iss(std::string(data.begin(), data.end()));
    YAML::Node n = YAML::Load(iss);
    return load_value(n);
  }

 private:
  Value load_value(const YAML::Node& n) {
    if (n.IsSequence()) {
      if (type_id_ == "message") {
        std::vector<Message> xs;
        for (const auto& el : n) {
          Message m;
          from_node(el, m);
          xs.push_back(std::move(m));
        }
        return xs;
      }
      if (type_id_ == "document") {
        std::vector<Document> xs;
        for (const auto& el : n) {
          Document d;
          from_node(el, d);
          xs.push_back(std::move(d));
        }
        return xs;
      }
      if (type_id_ == "telemetry") {
        std::vector<Telemetry> xs;
        for (const auto& el : n) {
          Telemetry t;
          from_node(el, t);
          xs.push_back(std::move(t));
        }
        return xs;
      }
      if (type_id_ == "strings") {
        std::vector<Strings> xs;
        for (const auto& el : n) {
          Strings s;
          from_node(el, s);
          xs.push_back(std::move(s));
        }
        return xs;
      }
      std::vector<Event> xs;
      for (const auto& el : n) {
        Event e;
        from_node(el, e);
        xs.push_back(std::move(e));
      }
      return xs;
    }
    if (type_id_ == "message") {
      Message m;
      from_node(n, m);
      return m;
    }
    if (type_id_ == "document") {
      Document d;
      from_node(n, d);
      return d;
    }
    if (type_id_ == "telemetry") {
      Telemetry t;
      from_node(n, t);
      return t;
    }
    if (type_id_ == "strings") {
      Strings s;
      from_node(n, s);
      return s;
    }
    Event e;
    from_node(n, e);
    return e;
  }

  std::string type_id_;
  YAML::Node prepared_;
};

}  // namespace

SerializerPtr make_yaml_cpp() { return std::make_unique<YamlCppSer>(); }

}  // namespace bench
