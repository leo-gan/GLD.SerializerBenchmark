#include "bench/csv_log.hpp"

#include <cstdint>
#include <stdexcept>
#include <tuple>
#include <vector>

namespace bench {

CsvLogger::CsvLogger(const std::string& path) {
  f_ = std::fopen(path.c_str(), "w");
  if (!f_) throw std::runtime_error("cannot create CSV: " + path);
  std::fprintf(f_,
               "Language,StringOrStream,TestDataName,Repetitions,RepetitionIndex,SerializerName,"
               "SerializerVersion,TimeSer,TimeDeser,Size,TimeSerAndDeser,OpPerSecSer,OpPerSecDeser,"
               "OpPerSecSerAndDeser,MemoryPeakBytes,FidelityScore,NativeKind,StreamMode,"
               "DataTypeInstanceCount,TypeConfigHash\n");
}

CsvLogger::~CsvLogger() {
  if (f_) std::fclose(f_);
}

void CsvLogger::write_row(const std::string& mode, const std::string& test_data, int reps,
                          int rep_idx, const std::string& ser, const std::string& version,
                          uint64_t ser_ns, uint64_t deser_ns, size_t size, double fidelity,
                          const std::string& native_kind, const std::string& stream_mode,
                          int instance_count, const std::string& type_config_hash) {
  uint64_t tot = ser_ns + deser_ns;
  double ops_s = ser_ns ? 1e9 / static_cast<double>(ser_ns) : 0;
  double ops_d = deser_ns ? 1e9 / static_cast<double>(deser_ns) : 0;
  double ops_t = tot ? 1e9 / static_cast<double>(tot) : 0;
  if (instance_count < 1) instance_count = 1;
  std::fprintf(f_,
               "cpp,%s,%s,%d,%d,%s,%s,%llu,%llu,%zu,%llu,%.6f,%.6f,%.6f,0,%.1f,%s,%s,%d,%s\n",
               mode.c_str(), test_data.c_str(), reps, rep_idx, ser.c_str(), version.c_str(),
               static_cast<unsigned long long>(ser_ns), static_cast<unsigned long long>(deser_ns),
               size, static_cast<unsigned long long>(tot), ops_s, ops_d, ops_t, fidelity,
               native_kind.c_str(), stream_mode.c_str(), instance_count, type_config_hash.c_str());
}

void save_errors(
    const std::string& path,
    const std::vector<std::tuple<std::string, std::string, std::string, int, std::string>>& errors) {
  if (errors.empty()) {
    std::remove(path.c_str());
    return;
  }
  FILE* f = std::fopen(path.c_str(), "w");
  if (!f) return;
  std::fprintf(f, "TestDataName,SerializerName,StringOrStream,Repetition,ErrorText\n");
  for (const auto& e : errors) {
    std::string text = std::get<4>(e);
    for (char& c : text) {
      if (c == '\n' || c == '\r') c = ' ';
      if (c == ',') c = ';';
    }
    std::fprintf(f, "%s,%s,%s,%d,%s\n", std::get<0>(e).c_str(), std::get<1>(e).c_str(),
                 std::get<2>(e).c_str(), std::get<3>(e), text.c_str());
  }
  std::fclose(f);
}

}  // namespace bench
