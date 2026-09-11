// C++ compliance runner (nlohmann JSON / CBOR / MessagePack / UBJSON / BSON).
// Built ad-hoc by run-compliance.sh when nlohmann headers are present.
#include <nlohmann/json.hpp>
#include <filesystem>
#include <fstream>
#include <iostream>
#include <sstream>
#include <string>
#include <vector>

using json = nlohmann::json;
namespace fs = std::filesystem;

static std::string repo_root() {
  auto dir = fs::current_path();
  for (int i = 0; i < 8; i++) {
    if (fs::is_directory(dir / "compliance" / "data")) return dir.string();
    if (!dir.has_parent_path()) break;
    dir = dir.parent_path();
  }
  throw std::runtime_error("cannot locate compliance/data");
}

static std::vector<uint8_t> from_hex(const std::string& s) {
  std::string c;
  for (char ch : s) if (!isspace(static_cast<unsigned char>(ch))) c.push_back(ch);
  std::vector<uint8_t> out;
  for (size_t i = 0; i + 1 < c.size(); i += 2) {
    out.push_back(static_cast<uint8_t>(std::stoi(c.substr(i, 2), nullptr, 16)));
  }
  return out;
}

int main(int argc, char** argv) {
  std::string json_out;
  std::vector<std::string> formats;
  for (int i = 1; i < argc; i++) {
    std::string a = argv[i];
    if ((a == "--json-out" || a == "-o") && i + 1 < argc) json_out = argv[++i];
    else if ((a == "--format" || a == "-f") && i + 1 < argc) formats.push_back(argv[++i]);
  }
  auto root = repo_root();
  json results = json::array();
  json adapter_errs = json::array();
  int p = 0, f = 0, s = 0, e = 0;
  for (auto const& fmt_dir : fs::directory_iterator(root + "/compliance/data")) {
    if (!fmt_dir.is_directory()) continue;
    for (auto const& file : fs::directory_iterator(fmt_dir)) {
      if (file.path().extension() != ".json") continue;
      std::ifstream in(file.path());
      json suite;
      in >> suite;
      if (!suite.contains("cases") || !suite.contains("format")) continue;
      std::string fmt = suite["format"].get<std::string>();
      if (!formats.empty()) {
        bool ok = false;
        for (auto& w : formats) if (w == fmt) ok = true;
        if (!ok) continue;
      }
      auto decode = [&](const std::vector<uint8_t>& raw) -> json {
        if (fmt == "json") return json::parse(raw.begin(), raw.end());
        if (fmt == "cbor") return json::from_cbor(raw, true, false);
        if (fmt == "msgpack") return json::from_msgpack(raw, true, false);
        if (fmt == "ubjson") return json::from_ubjson(raw, true, false);
        if (fmt == "bson") return json::from_bson(raw, true, false);
        throw std::runtime_error("no adapter");
      };
      if (fmt != "json" && fmt != "cbor" && fmt != "msgpack" && fmt != "ubjson" && fmt != "bson") {
        adapter_errs.push_back("No adapter registered for format " + fmt);
        continue;
      }
      std::string ser = "nlohmann_" + fmt;
      if (fmt == "json") ser = "nlohmann_json";
      for (auto& c : suite["cases"]) {
        json row = {
          {"id", c.value("id", "")}, {"language", "cpp"}, {"serializer", ser},
          {"serializer_version", "3.11.3"}, {"format", fmt},
          {"standard", suite.value("standard", "")}, {"standard_url", suite.value("standard_url", "")},
          {"version", suite.value("version", "")},
          {"version_key", fmt + "." + suite.value("version", "")},
          {"requirement", c.value("requirement", "")}, {"expect", c.value("expect", "")},
          {"section", c.value("section", "")}, {"section_title", c.value("section_title", "")},
          {"section_url", c.value("section_url", "")}, {"paragraph", c.value("paragraph", "")},
          {"title", c.value("title", "")}, {"input", c.value("input", "")},
          {"input_encoding", c.value("input_encoding", "utf-8")},
          {"detail", ""}, {"observed", ""}, {"outcome", "pass"},
        };
        std::vector<uint8_t> raw;
        try {
          if (c.value("input_encoding", "utf-8") == "hex") raw = from_hex(c.value("input", ""));
          else {
            auto s = c.value("input", "");
            raw.assign(s.begin(), s.end());
          }
          auto got = decode(raw);
          if (c.value("expect", "") == "reject") {
            row["outcome"] = "fail";
            row["detail"] = "parser accepted input the spec requires to be rejected";
            row["observed"] = std::string("accepted as ") + got.dump();
            f++;
          } else {
            try {
              row["observed"] = got.dump();
            } catch (...) {
              row["observed"] = "ok";
            }
            p++;
          }
        } catch (const std::exception& ex) {
          if (c.value("expect", "") == "reject" || c.value("expect", "") == "any") {
            row["observed"] = ex.what();
            p++;
          } else {
            row["outcome"] = "fail";
            row["detail"] = "parser rejected input the spec requires to accept";
            row["observed"] = ex.what();
            f++;
          }
        }
        results.push_back(row);
      }
    }
  }
  std::cout << "Serialization compliance (library deviations are catalogued, not a red build)\n";
  std::cout << "  " << p << " pass  " << f << " fail  " << s << " skip  " << e << " error  "
            << results.size() << " total\n";
  if (!json_out.empty()) {
    json doc = {
      {"schema", "gld.dashboard.compliance/1"},
      {"generated_at", ""},
      {"language", "cpp"},
      {"languages", json::array({"cpp"})},
      {"policy", "report-only"},
      {"scope", {{"formats", json::array({"json", "cbor", "msgpack", "ubjson", "bson"})}}},
      {"passed", p}, {"failed", f}, {"skipped", s}, {"errors", e},
      {"catalog_errors", json::array()},
      {"serializer_errors", adapter_errs},
      {"results", results},
    };
    fs::create_directories(fs::path(json_out).parent_path());
    std::ofstream(json_out) << doc.dump(2, ' ', false, json::error_handler_t::replace) << "\n";
    std::cout << "\nWrote " << json_out << "\n";
  }
  return 0;
}
