#pragma once

#include <cstdint>
#include <cstdio>
#include <cstddef>
#include <string>
#include <tuple>
#include <vector>

namespace bench {

class CsvLogger {
 public:
  explicit CsvLogger(const std::string& path);
  ~CsvLogger();
  CsvLogger(const CsvLogger&) = delete;
  CsvLogger& operator=(const CsvLogger&) = delete;

  void write_row(const std::string& mode, const std::string& test_data, int reps, int rep_idx,
                 const std::string& ser, const std::string& version, uint64_t ser_ns,
                 uint64_t deser_ns, size_t size, double fidelity, const std::string& native_kind,
                 const std::string& stream_mode, int instance_count,
                 const std::string& type_config_hash);

 private:
  FILE* f_ = nullptr;
};

void save_errors(const std::string& path,
                 const std::vector<std::tuple<std::string, std::string, std::string, int, std::string>>&
                     errors);

}  // namespace bench
