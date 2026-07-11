#include "bench/cells.hpp"
#include <unistd.h>

#include <cstdio>
#include <cstdlib>
#include <filesystem>
#include <fstream>
#include <sstream>
#include <stdexcept>

// Minimal JSON field extraction without a heavy dependency (resolved config is small).
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

static int json_int_field(const std::string& obj, const std::string& key, int def) {
  auto pos = obj.find("\"" + key + "\"");
  if (pos == std::string::npos) return def;
  pos = obj.find(':', pos);
  if (pos == std::string::npos) return def;
  ++pos;
  while (pos < obj.size() && (obj[pos] == ' ' || obj[pos] == '\t')) ++pos;
  try {
    return std::stoi(obj.substr(pos));
  } catch (...) {
    return def;
  }
}

static std::string json_string_field(const std::string& obj, const std::string& key) {
  auto pos = obj.find("\"" + key + "\"");
  if (pos == std::string::npos) return {};
  pos = obj.find(':', pos);
  if (pos == std::string::npos) return {};
  pos = obj.find('"', pos + 1);
  if (pos == std::string::npos) return {};
  ++pos;
  std::string out;
  while (pos < obj.size() && obj[pos] != '"') {
    if (obj[pos] == '\\' && pos + 1 < obj.size()) {
      out.push_back(obj[pos + 1]);
      pos += 2;
      continue;
    }
    out.push_back(obj[pos++]);
  }
  return out;
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
  std::string json = read_cmd(cmd.str());

  // Parse cells via a tiny Python helper for robustness (nested objects).
  const std::string helper = "/tmp/cpp_v2_cells_" + std::to_string(getpid()) + ".py";
  {
    std::ofstream hf(helper);
    hf << "import json,sys\n"
          "d=json.loads(sys.stdin.read())\n"
          "seed=d.get('seed'," << seed << ")\n"
          "modes=d.get('execution',{}).get('io_modes',['bytes','stream'])\n"
          "print('SEED', seed)\n"
          "print('MODES', ','.join(modes))\n"
          "for c in d['cells']:\n"
          "    tc=c.get('type_config') or {}\n"
          "    print('CELL', c['type_id'], c.get('data_type_instance_count',1),\n"
          "          c.get('type_config_hash',''),\n"
          "          tc.get('children',8), tc.get('points',32), tc.get('count',32),\n"
          "          tc.get('attr_count',4), tc.get('tag_count',2),\n"
          "          sep='\\t')\n";
  }
  std::ostringstream pycmd;
  pycmd << "python3 '" << helper << "' <<'JSON'\n" << json << "\nJSON";
  // Use file for JSON to avoid shell limits
  const std::string jpath = "/tmp/cpp_v2_resolved_" + std::to_string(getpid()) + ".json";
  {
    std::ofstream jf(jpath);
    jf << json;
  }
  std::ostringstream pycmd2;
  pycmd2 << "python3 -c \""
            "import json\n"
            "d=json.load(open('" << jpath << "'))\n"
            "seed=d.get('seed'," << seed << ")\n"
            "modes=d.get('execution',{}).get('io_modes',['bytes','stream'])\n"
            "print('SEED', seed)\n"
            "print('MODES', ','.join(modes))\n"
            "for c in d['cells']:\n"
            "  tc=c.get('type_config') or {}\n"
            "  print('CELL', c['type_id'], c.get('data_type_instance_count',1), c.get('type_config_hash',''), "
            "tc.get('children',8), tc.get('points',32), tc.get('count',32), tc.get('attr_count',4), tc.get('tag_count',2), sep='\\t')\n"
            "\"";
  std::string parsed = read_cmd(pycmd2.str());
  std::remove(jpath.c_str());
  std::remove(helper.c_str());

  ResolvedRun rr;
  rr.seed = seed;
  rr.io_modes = {"bytes", "stream"};
  std::istringstream iss(parsed);
  std::string line;
  while (std::getline(iss, line)) {
    if (line.rfind("SEED ", 0) == 0) {
      rr.seed = static_cast<uint64_t>(std::stoull(line.substr(5)));
    } else if (line.rfind("MODES ", 0) == 0) {
      rr.io_modes.clear();
      std::string modes = line.substr(6);
      std::stringstream ss(modes);
      std::string m;
      while (std::getline(ss, m, ',')) {
        if (!m.empty()) rr.io_modes.push_back(m);
      }
      if (rr.io_modes.empty()) rr.io_modes = {"bytes", "stream"};
    } else if (line.rfind("CELL\t", 0) == 0 || line.rfind("CELL ", 0) == 0) {
      // CELL\ttype\tN\thash\tchildren\tpoints\tcount\tattr\ttag
      std::vector<std::string> parts;
      std::string cur;
      // skip "CELL"
      size_t i = 0;
      while (i < line.size() && line[i] != '\t' && line[i] != ' ') ++i;
      while (i < line.size() && (line[i] == '\t' || line[i] == ' ')) ++i;
      auto rest = line.substr(i);
      std::stringstream ss(rest);
      std::string tok;
      while (std::getline(ss, tok, '\t')) parts.push_back(tok);
      if (parts.size() < 3) continue;
      Cell c;
      c.type_id = parts[0];
      c.data_type_instance_count = std::stoi(parts[1]);
      c.type_config_hash = parts.size() > 2 ? parts[2] : "";
      if (parts.size() > 3) c.type_config.children = std::stoi(parts[3]);
      if (parts.size() > 4) c.type_config.points = std::stoi(parts[4]);
      if (parts.size() > 5) c.type_config.count = std::stoi(parts[5]);
      if (parts.size() > 6) c.type_config.attr_count = std::stoi(parts[6]);
      if (parts.size() > 7) c.type_config.tag_count = std::stoi(parts[7]);
      rr.cells.push_back(std::move(c));
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
