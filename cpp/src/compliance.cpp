// C++ compliance runner (nlohmann JSON / CBOR / MessagePack / UBJSON / BSON).
// Built ad-hoc by run-compliance.sh when nlohmann headers are present.
#include <nlohmann/json.hpp>
#include <cstdint>
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

static uint64_t pb_varint(const std::vector<uint8_t>& d, size_t& i) {
  uint64_t r = 0;
  int shift = 0;
  while (i < d.size()) {
    uint8_t b = d[i++];
    r |= uint64_t(b & 0x7f) << shift;
    if ((b & 0x80) == 0) return r;
    shift += 7;
    if (shift > 63) throw std::runtime_error("varint too long");
  }
  throw std::runtime_error("truncated varint");
}

static int32_t pb_i32(uint64_t v) { return static_cast<int32_t>(v); }

static json decode_protobuf(const std::vector<uint8_t>& raw, const std::string& schema) {
  if (schema == "json") {
    json v = json::parse(raw.begin(), raw.end());
    if (!v.is_object()) throw std::runtime_error("proto3 JSON message must be an object");
    json doc = {{"n", 0}, {"s", ""}, {"ok", false}, {"tags", json::array()}};
    if (v.contains("n") && !v["n"].is_null()) {
      if (v["n"].is_number_integer()) doc["n"] = v["n"].get<int>();
      else if (v["n"].is_string()) doc["n"] = std::stoi(v["n"].get<std::string>());
      else throw std::runtime_error("int32 must be a number or digit string");
    }
    if (v.contains("s") && !v["s"].is_null()) {
      if (!v["s"].is_string()) throw std::runtime_error("s must be a string");
      doc["s"] = v["s"];
    }
    if (v.contains("ok") && !v["ok"].is_null()) {
      if (!v["ok"].is_boolean()) throw std::runtime_error("ok must be a bool");
      doc["ok"] = v["ok"];
    }
    if (v.contains("tags") && !v["tags"].is_null()) {
      if (!v["tags"].is_array()) throw std::runtime_error("tags must be an array");
      json tags = json::array();
      for (auto& t : v["tags"]) {
        if (t.is_number_integer()) tags.push_back(t.get<int>());
        else if (t.is_string()) tags.push_back(std::stoi(t.get<std::string>()));
        else throw std::runtime_error("int32 must be a number or digit string");
      }
      doc["tags"] = tags;
    }
    return doc;
  }
  int32_t n = 0;
  std::string s;
  bool ok = false;
  json tags = json::array();
  size_t i = 0;
  while (i < raw.size()) {
    uint64_t key = pb_varint(raw, i);
    uint32_t field = uint32_t(key >> 3);
    uint32_t wt = uint32_t(key & 7);
    if (wt == 0) {
      uint64_t v = pb_varint(raw, i);
      if (field == 1) n = pb_i32(v);
      else if (field == 3) ok = v != 0;
      else if (field == 4) tags.push_back(pb_i32(v));
    } else if (wt == 1) {
      if (i + 8 > raw.size()) throw std::runtime_error("truncated fixed64");
      i += 8;
    } else if (wt == 5) {
      if (i + 4 > raw.size()) throw std::runtime_error("truncated fixed32");
      i += 4;
    } else if (wt == 2) {
      uint64_t nlen = pb_varint(raw, i);
      if (i + nlen > raw.size()) throw std::runtime_error("truncated length-delimited");
      if (field == 2) s.assign(reinterpret_cast<const char*>(raw.data() + i), size_t(nlen));
      else if (field == 4) {
        size_t end = i + size_t(nlen);
        size_t j = i;
        while (j < end) tags.push_back(pb_i32(pb_varint(raw, j)));
      }
      i += size_t(nlen);
    } else {
      throw std::runtime_error("invalid wire type");
    }
  }
  return json{{"n", n}, {"s", s}, {"ok", ok}, {"tags", tags}};
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
      auto decode = [&](const std::vector<uint8_t>& raw, const std::string& schema) -> json {
        if (fmt == "json") return json::parse(raw.begin(), raw.end());
        if (fmt == "cbor") return json::from_cbor(raw, true, false);
        if (fmt == "msgpack") return json::from_msgpack(raw, true, false);
        if (fmt == "ubjson") return json::from_ubjson(raw, true, false);
        if (fmt == "bson") return json::from_bson(raw, true, false);
        if (fmt == "protobuf") return decode_protobuf(raw, schema);
        throw std::runtime_error("no adapter");
      };
      if (fmt != "json" && fmt != "cbor" && fmt != "msgpack" && fmt != "ubjson" && fmt != "bson" && fmt != "protobuf") {
        adapter_errs.push_back("No adapter registered for format " + fmt);
        continue;
      }
      std::string ser = "nlohmann_" + fmt;
      if (fmt == "json") ser = "nlohmann_json";
      if (fmt == "protobuf") ser = "protobuf-wire";
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
          std::string schema;
          if (c.contains("schema") && c["schema"].is_string()) schema = c["schema"].get<std::string>();
          auto got = decode(raw, schema);
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
