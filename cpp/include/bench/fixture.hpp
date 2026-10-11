#pragma once

#include "bench/types.hpp"

#include <memory>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <variant>
#include <vector>

namespace bench {

// Single instance or batch (N>1) of a suite type.
// vector<double> is the table_project column (length N, including N=1), not a batch of rows.
using Value = std::variant<Message, Document, Telemetry, Strings, Event,
                           std::vector<Message>, std::vector<Document>,
                           std::vector<Telemetry>, std::vector<Strings>,
                           std::vector<Event>, Table, NestedRow, Signal,
                           std::vector<Table>, std::vector<NestedRow>,
                           std::vector<Signal>, std::vector<double>, Book,
                           std::vector<Book>, Grid>;

template <typename T>
inline constexpr bool is_columnar_alt_v =
    std::is_same_v<T, Table> || std::is_same_v<T, NestedRow> || std::is_same_v<T, Signal> ||
    std::is_same_v<T, std::vector<Table>> || std::is_same_v<T, std::vector<NestedRow>> ||
    std::is_same_v<T, std::vector<Signal>> || std::is_same_v<T, std::vector<double>>;

// Book is one graph: shared Region nodes and a Person ring. Not a tree.
template <typename T>
inline constexpr bool is_graph_alt_v =
    std::is_same_v<T, Book> || std::is_same_v<T, std::vector<Book>>;

template <typename T>
inline constexpr bool is_array_alt_v = std::is_same_v<T, Grid>;

// Copy one row or the batch. Used inside timed serialize.
template <typename T>
inline std::vector<T> as_rows(const Value& v) {
  if (const auto* one = std::get_if<T>(&v)) return {*one};
  if (const auto* many = std::get_if<std::vector<T>>(&v)) return *many;
  throw std::runtime_error("as_rows: value is not the requested row type");
}

struct Fixture {
  std::string type_id;
  Value value;
  int instance_count = 1;
  std::string type_config_hash;
};

// Negative sentinels mean "key absent". make_one applies the catalog default for that type_id.
// points/count/attr_count/tag_count keep their catalog defaults so an absent key matches today.
struct TypeConfig {
  int children = -1;
  int points = 32;
  int count = 32;
  int attr_count = 4;
  int tag_count = 2;
  int string_len_min = -1;
  int string_len_max = -1;
  int int_range_min = 0;
  int int_range_max = 1000000;
  bool has_int_range = false;
  double duplication = -1.0;
  int group_count = -1;
  int order_count = -1;
  int region_count = -1;
  int ring_size = -1;
  int nx = 512;
  int ny = 512;
  int x0 = 128;
  int y0 = 64;
  int wx = 256;
  int wy = 128;
};

// table_project compares the f_float_0 column (length N), not the full row(s).
inline Value expected_for_fidelity(const Fixture& fx) {
  if (fx.type_id == "grid" || fx.type_id == "grid_window") {
    const auto& grid = std::get<Grid>(fx.value);
    if (fx.type_id == "grid") return grid;
    Grid window;
    window.values = grid.window_values();
    return window;
  }
  if (fx.type_id != "table_project") return fx.value;
  std::vector<double> col;
  if (const auto* one = std::get_if<Table>(&fx.value)) {
    col.push_back(one->f_float[0]);
  } else if (const auto* many = std::get_if<std::vector<Table>>(&fx.value)) {
    col.reserve(many->size());
    for (const auto& row : *many) col.push_back(row.f_float[0]);
  } else {
    throw std::runtime_error("table_project fixture is not a Table");
  }
  return col;
}

Fixture make_fixture(const std::string& type_id, const TypeConfig& cfg, uint64_t seed,
                     int instance_count, const std::string& type_config_hash);

bool fidelity(const Value& a, const Value& b);

}  // namespace bench
