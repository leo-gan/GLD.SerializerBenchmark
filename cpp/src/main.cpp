#include "bench/cells.hpp"
#include "bench/csv_log.hpp"
#include "bench/schedule.hpp"
#include "bench/serializer.hpp"

#include <chrono>
#include <cstring>
#include <filesystem>
#include <iostream>
#include <memory>
#include <string>
#include <tuple>
#include <unordered_map>
#include <unordered_set>
#include <vector>

namespace fs = std::filesystem;

static uint64_t now_ns() {
  using clock = std::chrono::steady_clock;
  return static_cast<uint64_t>(
      std::chrono::duration_cast<std::chrono::nanoseconds>(clock::now().time_since_epoch()).count());
}

static fs::path resolve_log_dir(const std::string& arg) {
  if (!arg.empty()) {
    fs::path p(arg);
    if (p.filename() == "cpp") return p;
    return p / "cpp";
  }
  if (const char* env = std::getenv("LOG_DIR"); env && env[0]) {
    fs::path p(env);
    if (p.filename() == "cpp") return p;
    return p / "cpp";
  }
  return fs::path(bench::repo_root()) / "logs" / "cpp";
}

struct Measure {
  uint64_t ser_ns = 0;
  uint64_t deser_ns = 0;
  size_t size = 0;
};

// Optimization barrier (issue #59) — mirrors Google Benchmark DoNotOptimize.
template <typename T>
static inline void do_not_optimize(const T& value) {
#if defined(__GNUC__) || defined(__clang__)
  asm volatile("" : : "g"(std::addressof(value)) : "memory");
#else
  (void)value;
#endif
}

static Measure measure_bytes(bench::ISerializer& ser, const bench::Fixture& fx,
                             std::vector<uint8_t>& /*unused_scratch*/) {
  Measure m;
  // Policy: timed path measures codec APIs that return/fill buffers. Many C++
  // codecs allocate a fresh vector each call; stream mode reuses scratch.
  // Warmup (rep 0) absorbs cold alloc; analysis drops it when exclude_warmup.
  uint64_t t0 = now_ns();
  auto buf = ser.serialize_bytes(fx);
  m.ser_ns = now_ns() - t0;
  do_not_optimize(buf);
  m.size = buf.size();
  t0 = now_ns();
  auto out = ser.deserialize_bytes(buf);
  m.deser_ns = now_ns() - t0;
  do_not_optimize(out);
  out = ser.to_domain(std::move(out));
  if (!bench::fidelity(fx.value, out)) {
    throw std::runtime_error(std::string("roundtrip fidelity failed for ") + ser.name());
  }
  return m;
}

static Measure measure_stream(bench::ISerializer& ser, const bench::Fixture& fx,
                              std::vector<uint8_t>& buf) {
  Measure m;
  buf.clear();  // capacity reused across reps (issue #59)
  uint64_t t0 = now_ns();
  size_t n = ser.serialize_stream(fx, buf);
  m.ser_ns = now_ns() - t0;
  do_not_optimize(buf);
  m.size = n > 0 ? n : buf.size();
  t0 = now_ns();
  auto out = ser.deserialize_stream(buf);
  m.deser_ns = now_ns() - t0;
  do_not_optimize(out);
  out = ser.to_domain(std::move(out));
  if (!bench::fidelity(fx.value, out)) {
    throw std::runtime_error(std::string("stream roundtrip fidelity failed for ") + ser.name());
  }
  return m;
}

int main(int argc, char** argv) {
  int reps = 10;
  std::string ser_filter;
  std::string data_filter;
  std::string log_dir_arg;

  for (int i = 1; i < argc; ++i) {
    std::string a = argv[i];
    if (a == "--reps" && i + 1 < argc) {
      reps = std::atoi(argv[++i]);
    } else if (a == "--serializer" && i + 1 < argc) {
      ser_filter = argv[++i];
    } else if (a == "--data" && i + 1 < argc) {
      data_filter = argv[++i];
    } else if (a == "--log-dir" && i + 1 < argc) {
      log_dir_arg = argv[++i];
    } else if (!a.empty() && a[0] != '-') {
      if (reps == 10 && std::isdigit(static_cast<unsigned char>(a[0]))) {
        reps = std::atoi(a.c_str());
      } else if (ser_filter.empty()) {
        ser_filter = a;
      } else if (data_filter.empty()) {
        data_filter = a;
      }
    }
  }

  fs::path log_dir = resolve_log_dir(log_dir_arg);
  fs::create_directories(log_dir);

  std::string ts;
  if (const char* env = std::getenv("BENCHMARK_TS"); env && env[0]) {
    ts = env;
  } else {
    auto t = std::chrono::system_clock::now();
    std::time_t tt = std::chrono::system_clock::to_time_t(t);
    std::tm tm{};
    localtime_r(&tt, &tm);
    char buf[32];
    std::strftime(buf, sizeof buf, "%Y-%m-%d-%H%M%S", &tm);
    ts = buf;
  }

  fs::path log_path = log_dir / (ts + ".csv");
  fs::path err_path = log_dir / (ts + ".errors.csv");

  std::cerr << "[PROGRESS] Writing results under " << log_dir << "\n";

  auto sers = bench::select_serializers(ser_filter);
  uint64_t seed = 42;
  if (const char* env = std::getenv("BENCHMARK_SEED"); env && env[0]) {
    seed = static_cast<uint64_t>(std::stoull(env));
  }
  std::string run_cfg;
  if (const char* env = std::getenv("BENCHMARK_RUN_CONFIG"); env && env[0]) {
    run_cfg = env;
  }

  auto resolved = bench::load_resolved(run_cfg, seed);
  seed = resolved.seed;
  auto modes = resolved.io_modes;
  if (modes.empty()) modes = {"bytes", "stream"};

  std::vector<std::pair<bench::Fixture, const bench::Cell*>> work;
  for (const auto& c : resolved.cells) {
    if (!data_filter.empty()) {
      auto tid = c.type_id;
      auto f = data_filter;
      for (char& ch : tid) ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
      for (char& ch : f) ch = static_cast<char>(std::tolower(static_cast<unsigned char>(ch)));
      if (tid.find(f) == std::string::npos) continue;
    }
    work.emplace_back(bench::fixture_from_cell(c, seed), &c);
  }

  std::string strategy = bench::resolve_schedule_strategy();
  bool record_ro = bench::resolve_record_run_order();
  int run_order = 0;

  std::cout << "[PROGRESS] C++ Data Model v2: " << sers.size() << " serializers, " << work.size()
            << " cells, " << reps << " reps schedule=" << strategy
            << " record_run_order=" << (record_ro ? 1 : 0) << "\n";

  using Err = std::tuple<std::string, std::string, std::string, int, std::string>;
  std::vector<Err> errors;
  {
    bench::CsvLogger logger(log_path.string());
    for (auto& [fx, cell] : work) {
      std::cout << "[PROGRESS] Testing Data: " << fx.type_id << " (N=" << fx.instance_count << ")\n";

      // Untimed prepare once; per-serializer stream scratch under block_shuffle (B-1).
      struct Prepared {
        bench::ISerializer* ser = nullptr;
        std::vector<uint8_t> stream_scratch;
      };
      std::vector<Prepared> ready;
      std::unordered_set<std::string> failed;
      std::unordered_map<std::string, size_t> by_name;

      for (auto& ser : sers) {
        if (!ser->supports(fx.type_id)) continue;
        try {
          ser->prepare(fx);
        } catch (const std::exception& e) {
          std::cerr << "[ERROR] prepare " << ser->name() << " / " << fx.type_id << ": " << e.what()
                    << "\n";
          errors.emplace_back(fx.type_id, ser->name(), "prepare", 0, e.what());
          failed.insert(ser->name());
          continue;
        }
        Prepared p;
        p.ser = ser.get();
        p.stream_scratch.reserve(64 * 1024);
        by_name[ser->name()] = ready.size();
        ready.push_back(std::move(p));
      }

      auto write_measure = [&](bench::ISerializer& ser, const std::string& mode, int rep_idx,
                               int pos, std::vector<uint8_t>& scratch) {
        Measure m = (mode == "bytes") ? measure_bytes(ser, fx, scratch)
                                      : measure_stream(ser, fx, scratch);
        int ro = -1, sp = -1;
        if (record_ro) {
          ro = run_order;
          sp = pos;
          ++run_order;
        }
        logger.write_row(mode, fx.type_id, reps, rep_idx, ser.name(), ser.version(), m.ser_ns,
                         m.deser_ns, m.size, 1.0, ser.native_kind(), ser.stream_mode(),
                         fx.instance_count, fx.type_config_hash, ro, sp);
      };

      if (strategy == "none") {
        // Legacy nesting: serializer → mode → all reps
        for (auto& p : ready) {
          if (failed.count(p.ser->name())) continue;
          for (const auto& mode : modes) {
            bool had_error = false;
            for (int i = 0; i < reps; ++i) {
              if (had_error) break;
              try {
                write_measure(*p.ser, mode, i, 0, p.stream_scratch);
              } catch (const std::exception& e) {
                std::cerr << "[ERROR] " << p.ser->name() << " / " << fx.type_id << " / " << mode
                          << ": " << e.what() << "\n";
                errors.emplace_back(fx.type_id, p.ser->name(), mode, i, e.what());
                failed.insert(p.ser->name());
                had_error = true;
              }
            }
          }
        }
      } else {
        // block_shuffle: mode → rep → shuffled serializers
        for (const auto& mode : modes) {
          for (int i = 0; i < reps; ++i) {
            std::vector<std::string> pool;
            pool.reserve(ready.size());
            for (const auto& p : ready) {
              if (!failed.count(p.ser->name())) pool.push_back(p.ser->name());
            }
            auto order = bench::shuffle_serializer_names(pool, seed, fx.type_id, fx.instance_count,
                                                         fx.type_config_hash, mode, i);
            for (int pos = 0; pos < static_cast<int>(order.size()); ++pos) {
              const std::string& nm = order[static_cast<size_t>(pos)];
              if (failed.count(nm)) continue;
              auto it = by_name.find(nm);
              if (it == by_name.end()) continue;
              Prepared& p = ready[it->second];
              try {
                write_measure(*p.ser, mode, i, pos, p.stream_scratch);
              } catch (const std::exception& e) {
                std::cerr << "[ERROR] " << p.ser->name() << " / " << fx.type_id << " / " << mode
                          << ": " << e.what() << "\n";
                errors.emplace_back(fx.type_id, p.ser->name(), mode, i, e.what());
                failed.insert(p.ser->name());
              }
            }
          }
        }
      }
    }
  }

  bench::save_errors(err_path.string(), errors);
  std::cout << "[PROGRESS] Complete. Results: " << log_path << "\n";
  return errors.empty() ? 0 : 1;
}
