#pragma once
// ADL converters for nlohmann::json and shared domain ↔ JSON helpers.

#include "bench/types.hpp"
#include "bench/fixture.hpp"

#include <nlohmann/json.hpp>
#include <stdexcept>
#include <type_traits>

namespace bench {

inline void to_json(nlohmann::json& j, const Message& m) {
  j = nlohmann::json{{"f_bool", m.f_bool},       {"f_int32", m.f_int32},
                     {"f_int64", m.f_int64},       {"f_float64", m.f_float64},
                     {"f_string", m.f_string},     {"f_bool_2", m.f_bool_2},
                     {"f_int32_2", m.f_int32_2},   {"f_string_2", m.f_string_2}};
}
inline void from_json(const nlohmann::json& j, Message& m) {
  j.at("f_bool").get_to(m.f_bool);
  j.at("f_int32").get_to(m.f_int32);
  j.at("f_int64").get_to(m.f_int64);
  j.at("f_float64").get_to(m.f_float64);
  j.at("f_string").get_to(m.f_string);
  j.at("f_bool_2").get_to(m.f_bool_2);
  j.at("f_int32_2").get_to(m.f_int32_2);
  j.at("f_string_2").get_to(m.f_string_2);
}

inline void to_json(nlohmann::json& j, const DocumentMeta& m) {
  j = nlohmann::json{{"region", m.region}, {"version", m.version}};
}
inline void from_json(const nlohmann::json& j, DocumentMeta& m) {
  j.at("region").get_to(m.region);
  j.at("version").get_to(m.version);
}
inline void to_json(nlohmann::json& j, const DocumentItem& m) {
  j = nlohmann::json{{"sku", m.sku}, {"qty", m.qty}, {"price_minor", m.price_minor}};
}
inline void from_json(const nlohmann::json& j, DocumentItem& m) {
  j.at("sku").get_to(m.sku);
  j.at("qty").get_to(m.qty);
  j.at("price_minor").get_to(m.price_minor);
}
inline void to_json(nlohmann::json& j, const Document& m) {
  j = nlohmann::json{{"id", m.id}, {"status", m.status}, {"meta", m.meta}, {"items", m.items}};
}
inline void from_json(const nlohmann::json& j, Document& m) {
  j.at("id").get_to(m.id);
  j.at("status").get_to(m.status);
  j.at("meta").get_to(m.meta);
  j.at("items").get_to(m.items);
}

inline void to_json(nlohmann::json& j, const Telemetry& m) {
  j = nlohmann::json{{"source", m.source}, {"ts", m.ts}, {"tags", m.tags}, {"values", m.values}};
}
inline void from_json(const nlohmann::json& j, Telemetry& m) {
  j.at("source").get_to(m.source);
  j.at("ts").get_to(m.ts);
  j.at("tags").get_to(m.tags);
  j.at("values").get_to(m.values);
}

inline void to_json(nlohmann::json& j, const Strings& m) { j = nlohmann::json{{"items", m.items}}; }
inline void from_json(const nlohmann::json& j, Strings& m) { j.at("items").get_to(m.items); }

inline void to_json(nlohmann::json& j, const EventAttr& m) {
  j = nlohmann::json{{"key", m.key}, {"value", m.value}};
}
inline void from_json(const nlohmann::json& j, EventAttr& m) {
  j.at("key").get_to(m.key);
  j.at("value").get_to(m.value);
}
inline void to_json(nlohmann::json& j, const Event& m) {
  j = nlohmann::json{{"event_id", m.event_id},
                     {"event_type", m.event_type},
                     {"occurred_at", m.occurred_at},
                     {"producer", m.producer},
                     {"attrs", m.attrs}};
}
inline void from_json(const nlohmann::json& j, Event& m) {
  j.at("event_id").get_to(m.event_id);
  j.at("event_type").get_to(m.event_type);
  j.at("occurred_at").get_to(m.occurred_at);
  j.at("producer").get_to(m.producer);
  j.at("attrs").get_to(m.attrs);
}

inline void to_json(nlohmann::json& j, const Table& m) {
  j = nlohmann::json::object();
  for (int i = 0; i < 16; ++i) j["f_float_" + std::to_string(i)] = m.f_float[i];
  for (int i = 0; i < 4; ++i) j["f_int_" + std::to_string(i)] = m.f_int[i];
  j["f_str_0"] = m.f_str_0;
  j["f_str_1"] = m.f_str_1;
}
inline void from_json(const nlohmann::json& j, Table& m) {
  for (int i = 0; i < 16; ++i) m.f_float[i] = j.at("f_float_" + std::to_string(i)).get<double>();
  for (int i = 0; i < 4; ++i) m.f_int[i] = j.at("f_int_" + std::to_string(i)).get<int64_t>();
  j.at("f_str_0").get_to(m.f_str_0);
  j.at("f_str_1").get_to(m.f_str_1);
}

inline void to_json(nlohmann::json& j, const NestedMeta& m) {
  j = nlohmann::json{{"region", m.region}, {"version", m.version}};
}
inline void from_json(const nlohmann::json& j, NestedMeta& m) {
  j.at("region").get_to(m.region);
  j.at("version").get_to(m.version);
}
inline void to_json(nlohmann::json& j, const NestedItem& m) {
  j = nlohmann::json{{"sku", m.sku}, {"qty", m.qty}, {"price_minor", m.price_minor}};
}
inline void from_json(const nlohmann::json& j, NestedItem& m) {
  j.at("sku").get_to(m.sku);
  j.at("qty").get_to(m.qty);
  j.at("price_minor").get_to(m.price_minor);
}
inline void to_json(nlohmann::json& j, const NestedRow& m) {
  j = nlohmann::json{{"id", m.id}, {"status", m.status}, {"meta", m.meta}, {"items", m.items}};
}
inline void from_json(const nlohmann::json& j, NestedRow& m) {
  j.at("id").get_to(m.id);
  j.at("status").get_to(m.status);
  j.at("meta").get_to(m.meta);
  j.at("items").get_to(m.items);
}

inline void to_json(nlohmann::json& j, const SignalLeg& m) {
  j = nlohmann::json{{"leg_id", m.leg_id}, {"leg_qty", m.leg_qty}, {"leg_pad", m.leg_pad}};
}
inline void from_json(const nlohmann::json& j, SignalLeg& m) {
  j.at("leg_id").get_to(m.leg_id);
  j.at("leg_qty").get_to(m.leg_qty);
  j.at("leg_pad").get_to(m.leg_pad);
}
inline void to_json(nlohmann::json& j, const Signal& m) {
  j = nlohmann::json{{"seq", m.seq},
                     {"ts", m.ts},
                     {"price_mantissa", m.price_mantissa},
                     {"qty", m.qty},
                     {"flags", m.flags},
                     {"symbol", m.symbol},
                     {"venue", m.venue},
                     {"legs", m.legs}};
}
inline void from_json(const nlohmann::json& j, Signal& m) {
  j.at("seq").get_to(m.seq);
  j.at("ts").get_to(m.ts);
  j.at("price_mantissa").get_to(m.price_mantissa);
  j.at("qty").get_to(m.qty);
  j.at("flags").get_to(m.flags);
  j.at("symbol").get_to(m.symbol);
  j.at("venue").get_to(m.venue);
  j.at("legs").get_to(m.legs);
}

inline nlohmann::json value_to_json(const Value& v) {
  return std::visit(
      [](const auto& x) -> nlohmann::json {
        using T = std::decay_t<decltype(x)>;
        if constexpr (is_graph_alt_v<T> || is_array_alt_v<T>) {
          throw std::runtime_error("json: graph type unsupported");
        } else {
          return x;
        }
      },
      v);
}

inline Value json_to_value(const nlohmann::json& j, const std::string& type_id, int n) {
  // Full table is encoded; fidelity compares only f_float_0, length N even when N=1.
  if (type_id == "table_project") {
    std::vector<double> col;
    if (n > 1) {
      col.reserve(j.size());
      for (const auto& row : j) col.push_back(row.at("f_float_0").get<double>());
    } else {
      col.push_back(j.at("f_float_0").get<double>());
    }
    return col;
  }
  if (n > 1) {
    if (type_id == "message") return j.get<std::vector<Message>>();
    if (type_id == "document") return j.get<std::vector<Document>>();
    if (type_id == "telemetry") return j.get<std::vector<Telemetry>>();
    if (type_id == "strings") return j.get<std::vector<Strings>>();
    if (type_id == "event") return j.get<std::vector<Event>>();
    if (type_id == "table") return j.get<std::vector<Table>>();
    if (type_id == "nested_table") return j.get<std::vector<NestedRow>>();
    if (type_id == "signal") return j.get<std::vector<Signal>>();
  } else {
    if (type_id == "message") return j.get<Message>();
    if (type_id == "document") return j.get<Document>();
    if (type_id == "telemetry") return j.get<Telemetry>();
    if (type_id == "strings") return j.get<Strings>();
    if (type_id == "event") return j.get<Event>();
    if (type_id == "table") return j.get<Table>();
    if (type_id == "nested_table") return j.get<NestedRow>();
    if (type_id == "signal") return j.get<Signal>();
  }
  throw std::runtime_error("json_to_value: unknown type " + type_id);
}

}  // namespace bench
