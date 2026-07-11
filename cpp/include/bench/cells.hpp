#pragma once

#include "bench/fixture.hpp"

#include <string>
#include <vector>

namespace bench {

struct Cell {
  std::string type_id;
  TypeConfig type_config;
  std::string type_config_hash;
  int data_type_instance_count = 1;
};

struct ResolvedRun {
  std::vector<Cell> cells;
  std::vector<std::string> io_modes;
  uint64_t seed = 42;
};

std::string repo_root();
ResolvedRun load_resolved(const std::string& run_config_path, uint64_t seed);
Fixture fixture_from_cell(const Cell& cell, uint64_t seed);

}  // namespace bench
