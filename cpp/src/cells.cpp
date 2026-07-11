#include "bench/cells.hpp"

#include <nlohmann/json.hpp>

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <sstream>
#include <stdexcept>

// Resolve suite cells via scripts/resolve_run_config.py (Python), parse JSON in C++.
// No /tmp helpers: nlohmann_json is already a harness dependency.

namespace fs = std::filesystem;

namespace bench {

std::string repo_root() {
  if (const char* env = std::getenv("BENCHMARK_REPO_ROOT"); env && env[0]) {
    return env;
  }
  fs::path cur = fs::current_path();
  for (fs::path p = cur; !p.empty() && p != p.root_path(); p = p.parent_path()) {
    if (fs::is_regular_file(p / "config" / "benchmark_config.yaml")) {
      return p.string();
    }
  }
  return cur.string();
}

static std::string read_cmd(const std::string& cmd) {
  FILE* p = popen(cmd.c_str(), "r");
  if (!p) throw std::runtime_error("popen failed: " + cmd);
  std::string out;
  char buf[4096];
  while (std::fgets(buf, sizeof buf, p)) out += buf;
  int rc = pclose(p);
  if (rc != 0) throw std::runtime_error("command failed (" + std::to_string(rc) + "): " + cmd + "\n" + out);
  return out;
}

static int j_int(const nlohmann::json& o, const char* key, int def) {
  if (!o.is_object() || !o.contains(key) || o[key].is_null()) return def;
  if (o[key].is_number_integer()) return o[key].get<int>();
  if (o[key].is_number()) return static_cast<int>(o[key].get<double>());
  return def;
}

ResolvedRun load_resolved(const std::string& run_config_path, uint64_t seed) {
  const std::string root = repo_root();
  std::string cfg = run_config_path;
  if (cfg.empty()) cfg = root + "/config/library/default.yaml";
  else if (!fs::is_regular_file(cfg)) {
    fs::path cand = fs::path(root) / cfg;
    if (fs::is_regular_file(cand)) cfg = cand.string();
  }
  std::ostringstream cmd;
  cmd << "PYTHONPATH='" << root << "/analysis/src' python3 '" << root
      << "/scripts/resolve_run_config.py' '" << cfg << "' --seed " << seed;
  std::string json_text = read_cmd(cmd.str());

  nlohmann::json d = nlohmann::json::parse(json_text);
  ResolvedRun rr;
  rr.seed = d.value("seed", seed);

  rr.io_modes.clear();
  if (d.contains("execution") && d["execution"].is_object() &&
      d["execution"].contains("io_modes") && d["execution"]["io_modes"].is_array()) {
    for (const auto& m : d["execution"]["io_modes"]) {
      if (m.is_string()) rr.io_modes.push_back(m.get<std::string>());
    }
  }
  if (rr.io_modes.empty()) rr.io_modes = {"bytes", "stream"};

  if (d.contains("cells") && d["cells"].is_array()) {
    for (const auto& c_json : d["cells"]) {
      if (!c_json.is_object()) continue;
      Cell c;
      c.type_id = c_json.value("type_id", "");
      c.data_type_instance_count = j_int(c_json, "data_type_instance_count", 1);
      c.type_config_hash = c_json.value("type_config_hash", "");
      nlohmann::json tc = nlohmann::json::object();
      if (c_json.contains("type_config") && c_json["type_config"].is_object()) {
        tc = c_json["type_config"];
      }
      c.type_config.children = j_int(tc, "children", 8);
      c.type_config.points = j_int(tc, "points", 32);
      c.type_config.count = j_int(tc, "count", 32);
      c.type_config.attr_count = j_int(tc, "attr_count", 4);
      c.type_config.tag_count = j_int(tc, "tag_count", 2);
      if (!c.type_id.empty()) rr.cells.push_back(std::move(c));
    }
  }
  if (rr.cells.empty()) throw std::runtime_error("no cells from resolve_run_config");
  return rr;
}

Fixture fixture_from_cell(const Cell& cell, uint64_t seed) {
  return make_fixture(cell.type_id, cell.type_config, seed, cell.data_type_instance_count,
                      cell.type_config_hash);
}

}  // namespace bench
