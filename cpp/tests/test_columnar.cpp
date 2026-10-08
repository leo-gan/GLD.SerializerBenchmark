#include "bench/fixture.hpp"
#include "bench/serializer.hpp"

#include <chrono>
#include <cstdint>
#include <iostream>
#include <set>
#include <string>
#include <vector>

#if defined(HAS_ARROW) && HAS_ARROW
namespace bench {
std::pair<int, std::string> columnar_projected_schema(const std::string& codec,
                                                     const std::vector<uint8_t>& bytes);
std::string parquet_compression_name(const std::vector<uint8_t>& bytes);
std::string orc_compression_name(const std::vector<uint8_t>& bytes);
}  // namespace bench
#endif

namespace {

int g_fail = 0;

void expect(bool cond, const std::string& msg) {
  if (!cond) {
    std::cerr << "FAIL " << msg << "\n";
    ++g_fail;
  }
}

bench::ISerializer* find_ser(std::vector<bench::SerializerPtr>& sers, const std::string& name) {
  for (auto& s : sers) {
    if (s && s->name() == name) return s.get();
  }
  return nullptr;
}

void roundtrip_one(bench::ISerializer& ser, const bench::Fixture& fx, bool stream) {
  const auto expected = bench::expected_for_fidelity(fx);
  ser.prepare(fx);
  if (stream) {
    std::vector<uint8_t> buf;
    ser.serialize_stream(fx, buf);
    auto out = ser.to_domain(ser.deserialize_stream(buf));
    expect(bench::fidelity(expected, out),
           std::string("stream ") + ser.name() + " / " + fx.type_id + " N=" +
               std::to_string(fx.instance_count));
    return;
  }
  auto buf = ser.serialize_bytes(fx);
  expect(!buf.empty(), std::string("empty bytes ") + ser.name() + " / " + fx.type_id);
  auto out = ser.to_domain(ser.deserialize_bytes(buf));
  expect(bench::fidelity(expected, out),
         std::string("bytes ") + ser.name() + " / " + fx.type_id + " N=" +
             std::to_string(fx.instance_count) + " size=" + std::to_string(buf.size()));
  if (fx.type_id == "table_project") {
    const auto* col = std::get_if<std::vector<double>>(&out);
    expect(col && static_cast<int>(col->size()) == fx.instance_count,
           std::string("table_project length ") + ser.name() + " N=" +
               std::to_string(fx.instance_count));
  }
}

std::set<std::string> names_of(const std::vector<bench::SerializerPtr>& sers) {
  std::set<std::string> out;
  for (const auto& s : sers) {
    if (s) out.insert(s->name());
  }
  return out;
}

}  // namespace

int run_columnar_checks() {
  using namespace bench;
  TypeConfig cfg;
  auto a = make_fixture("table", cfg, 42, 40, "t");
  auto b = make_fixture("table", cfg, 42, 40, "t");
  expect(fidelity(a.value, b.value), "table determinism");
  auto other = make_fixture("table", cfg, 99, 40, "t");
  expect(!fidelity(a.value, other.value), "table different seed");

  const auto& rows = std::get<std::vector<Table>>(a.value);
  expect(rows.size() == 40, "40-row batch");
  std::set<std::string> uniq;
  for (const auto& row : rows) {
    uniq.insert(row.f_str_0);
    uniq.insert(row.f_str_1);
    expect(row.f_float[0] >= 0.0 && row.f_float[0] <= 1000.0, "float range");
  }
  expect(uniq.size() < 80, "duplication 0.5 repeats a string");

  TypeConfig dup1 = cfg;
  dup1.duplication = 1.0;
  auto packed = std::get<std::vector<Table>>(make_fixture("table", dup1, 7, 40, "t").value);
  std::set<std::string> vocab_used;
  for (const auto& row : packed) {
    vocab_used.insert(row.f_str_0);
    vocab_used.insert(row.f_str_1);
  }
  expect(vocab_used.size() <= 32, "duplication 1.0 stays inside the 32-word vocab");

  TypeConfig dup0 = cfg;
  dup0.duplication = 0.0;
  auto fresh = std::get<std::vector<Table>>(make_fixture("table", dup0, 8, 40, "t").value);
  std::set<std::string> fresh_used;
  for (const auto& row : fresh) {
    fresh_used.insert(row.f_str_0);
    fresh_used.insert(row.f_str_1);
  }
  expect(fresh_used.size() >= 72, "duplication 0 is mostly unique");

  TypeConfig ir = cfg;
  ir.has_int_range = true;
  ir.int_range_min = 7;
  ir.int_range_max = 7;
  ir.string_len_min = 5;
  ir.string_len_max = 5;
  auto fixed_fx = make_fixture("table", ir, 9, 1, "t");
  const auto& fixed = std::get<Table>(fixed_fx.value);
  expect(fixed.f_int[0] == 7 && fixed.f_int[1] == 7 && fixed.f_int[2] == 7 && fixed.f_int[3] == 7,
         "int_range 7..7");
  expect(fixed.f_str_0.size() == 5 && fixed.f_str_1.size() == 5, "string_len 5..5");

  auto nested_fx = make_fixture("nested_table", cfg, 3, 1, "t");
  const auto& nested = std::get<NestedRow>(nested_fx.value);
  expect(nested.items.size() == 4, "nested_table default children 4");
  TypeConfig kids = cfg;
  kids.children = 2;
  expect(std::get<NestedRow>(make_fixture("nested_table", kids, 3, 1, "t").value).items.size() == 2,
         "nested_table children=2");
  expect(std::get<Document>(make_fixture("document", cfg, 3, 1, "t").value).items.size() == 8,
         "document default children still 8");

  auto sig_fx = make_fixture("signal", cfg, 11, 1, "t");
  const auto& sig = std::get<Signal>(sig_fx.value);
  expect(std::holds_alternative<Signal>(sig_fx.value), "signal N=1 is a bare Signal");
  expect(sig.legs.size() == 4, "signal default group_count 4");
  expect(!sig.symbol.empty() && !sig.venue.empty(), "signal symbol and venue");
  expect(sig.seq >= 0 && sig.seq <= 1000000000, "signal seq range");
  expect(sig.ts >= kBaseTsMs && sig.ts <= kBaseTsMs + 86400000, "signal ts window");
  bool pad0 = true;
  for (const auto& leg : sig.legs) {
    if (leg.leg_pad != 0) pad0 = false;
  }
  expect(pad0, "signal leg_pad is 0");
  TypeConfig groups = cfg;
  groups.group_count = 2;
  expect(std::get<Signal>(make_fixture("signal", groups, 11, 1, "t").value).legs.size() == 2,
         "signal group_count=2");

  auto all = all_serializers();
  std::cout << "COUNT " << all.size() << "\n";
  const std::string allow =
      "arrow-ipc,parquet,parquet-uncompressed,orc,orc-uncompressed,sbe,nlohmann_json,protobuf,"
      "flatbuffers,avro";
  auto selected = select_serializers(allow);
  auto got = names_of(selected);
  std::cout << "ALLOW";
  for (auto& s : selected) std::cout << " " << s->name() << "=" << s->version();
  std::cout << "\n";
  for (const char* banned : {"protobuf-wire", "avro_c", "nlohmann_msgpack", "capnproto"}) {
    expect(!got.count(banned), std::string("allow-list excluded ") + banned);
  }
#if defined(HAS_ARROW) && HAS_ARROW
  const bool arrow_on = true;
#else
  const bool arrow_on = false;
#endif
  std::set<std::string> want{"sbe", "nlohmann_json", "protobuf", "flatbuffers", "avro"};
  if (arrow_on) {
    want.insert({"arrow-ipc", "parquet", "parquet-uncompressed", "orc", "orc-uncompressed"});
  }
  expect(got == want, "allow-list exact names");

  auto sub = select_serializers("protobuf");
  auto sub_names = names_of(sub);
  expect(sub_names.count("protobuf") == 1, "substring keeps protobuf");
  expect(sub_names.count("protobuf-wire") == 1, "substring keeps protobuf-wire");
  auto exact = names_of(select_serializers("protobuf,avro"));
  expect(exact == std::set<std::string>({"protobuf", "avro"}), "comma filter is exact");
  auto exact_case = names_of(select_serializers("Protobuf, Avro"));
  expect(exact_case == std::set<std::string>({"protobuf", "avro"}), "comma filter is case-insensitive");

  const char* codecs[] = {"arrow-ipc",
                          "parquet",
                          "parquet-uncompressed",
                          "orc",
                          "orc-uncompressed",
                          "sbe",
                          "nlohmann_json",
                          "protobuf",
                          "flatbuffers",
                          "avro"};
  const char* types[] = {"table", "table_project", "nested_table", "signal"};
  for (const char* codec : codecs) {
    auto* ser = find_ser(all, codec);
    const bool optional_arrow = std::string(codec) != "sbe" && std::string(codec) != "nlohmann_json" &&
                                std::string(codec) != "protobuf" && std::string(codec) != "flatbuffers" &&
                                std::string(codec) != "avro";
    if (!ser) {
      expect(!arrow_on && optional_arrow, std::string("missing serializer ") + codec);
      continue;
    }
    for (const char* tid : types) {
      if (!ser->supports(tid)) {
        expect(std::string(codec) == "sbe" && std::string(tid) == "nested_table",
               std::string(codec) + " unexpectedly rejected " + tid);
        continue;
      }
      for (int n : {1, 100}) {
        Fixture fx = make_fixture(tid, cfg, 42, n, "col");
        try {
          roundtrip_one(*ser, fx, false);
        } catch (const std::exception& e) {
          expect(false, std::string(codec) + " / " + tid + " N=" + std::to_string(n) + ": " + e.what());
        }
      }
      try {
        Fixture fx = make_fixture(tid, cfg, 42, 1, "col");
        roundtrip_one(*ser, fx, true);
      } catch (const std::exception& e) {
        expect(false, std::string("stream ") + codec + " / " + tid + ": " + e.what());
      }
    }
  }

#if defined(HAS_ARROW) && HAS_ARROW
  auto* pq = find_ser(all, "parquet");
  auto* raw = find_ser(all, "parquet-uncompressed");
  auto* orc = find_ser(all, "orc");
  auto* orc_raw = find_ser(all, "orc-uncompressed");
  Fixture wide = make_fixture("table", cfg, 42, 100, "cmp");
  if (pq && raw && orc && orc_raw) {
    pq->prepare(wide);
    raw->prepare(wide);
    orc->prepare(wide);
    orc_raw->prepare(wide);
    auto pq_bytes = pq->serialize_bytes(wide);
    auto raw_bytes = raw->serialize_bytes(wide);
    auto orc_bytes = orc->serialize_bytes(wide);
    auto orc_raw_bytes = orc_raw->serialize_bytes(wide);
    const std::string pq_c = parquet_compression_name(pq_bytes);
    const std::string raw_c = parquet_compression_name(raw_bytes);
    const std::string orc_c = orc_compression_name(orc_bytes);
    const std::string orc_raw_c = orc_compression_name(orc_raw_bytes);
    std::cout << "PARQUET codec=" << pq_c << " size=" << pq_bytes.size() << " raw_codec=" << raw_c
              << " raw_size=" << raw_bytes.size() << "\n";
    std::cout << "ORC codec=" << orc_c << " size=" << orc_bytes.size() << " raw_codec=" << orc_raw_c
              << " raw_size=" << orc_raw_bytes.size() << "\n";
    expect(pq_c == "SNAPPY", "parquet codec is Snappy");
    expect(raw_c == "UNCOMPRESSED", "parquet-uncompressed codec");
    expect(pq_bytes.size() != raw_bytes.size(), "parquet Snappy size differs from uncompressed");
    // Arrow's GZIP enum is what the ORC adapter writes as ZLIB.
    expect(orc_c == "GZIP", "orc codec is Arrow GZIP (ORC ZLIB)");
    expect(orc_raw_c == "UNCOMPRESSED", "orc-uncompressed codec");
    expect(orc_bytes.size() != orc_raw_bytes.size(), "orc Zlib size differs from uncompressed");

    for (const char* codec : {"arrow-ipc", "parquet", "orc"}) {
      auto* ser = find_ser(all, codec);
      ser->prepare(wide);
      auto bytes = ser->serialize_bytes(wide);
      auto schema = columnar_projected_schema(codec, bytes);
      std::cout << "PROJECT " << codec << " fields=" << schema.first << " name=" << schema.second
                << "\n";
      expect(schema.first == 1 && schema.second == "f_float_0",
             std::string("projected schema ") + codec);
    }

    Fixture big = make_fixture("table", cfg, 42, 10000, "time");
    Fixture bigp = make_fixture("table_project", cfg, 42, 10000, "time");
    for (const char* codec : {"arrow-ipc", "parquet", "orc"}) {
      auto* ser = find_ser(all, codec);
      ser->prepare(big);
      auto full = ser->serialize_bytes(big);
      ser->prepare(bigp);
      auto proj = ser->serialize_bytes(bigp);
      auto time_one = [&](const Fixture& fx, const std::vector<uint8_t>& bytes) {
        ser->prepare(fx);
        uint64_t sum = 0;
        size_t sink = 0;
        for (int rep = 0; rep < 3; ++rep) {
          auto t0 = std::chrono::steady_clock::now();
          auto out = ser->deserialize_bytes(bytes);
          auto t1 = std::chrono::steady_clock::now();
          sum += static_cast<uint64_t>(
              std::chrono::duration_cast<std::chrono::nanoseconds>(t1 - t0).count());
          if (const auto* col = std::get_if<std::vector<double>>(&out)) sink += col->size();
          else if (const auto* rs = std::get_if<std::vector<Table>>(&out)) sink += rs->size();
          else sink += 1;
        }
        volatile size_t keep = sink;
        if (keep == 0) std::cerr << "timing sink collapsed\n";
        return sum / 3;
      };
      const auto full_ns = time_one(big, full);
      const auto proj_ns = time_one(bigp, proj);
      std::cout << "TIMING " << codec << " table_deser_ns=" << full_ns
                << " table_project_deser_ns=" << proj_ns << " N=10000 reps=3\n";
      expect(proj_ns < full_ns, std::string("projection faster than full read for ") + codec);
    }
  }
#endif

  if (g_fail) {
    std::cerr << g_fail << " columnar failure(s)\n";
    return 1;
  }
  std::cout << "columnar checks OK\n";
  return 0;
}
