#pragma once
// B-1 deterministic block_shuffle schedule (must match analysis golden vector).

#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace bench {

std::string normalize_mode(const std::string& mode);

uint64_t derive_schedule_seed(uint64_t base_seed, const std::string& type_id, int instance_count,
                              const std::string& type_config_hash, const std::string& mode, int rep);

template <typename T>
std::vector<T> fisher_yates(const std::vector<T>& items, uint64_t seed) {
  std::vector<T> arr = items;
  uint64_t state = seed;
  auto next_u64 = [&state]() -> uint64_t {
    state += 0x9E3779B97F4A7C15ULL;
    uint64_t z = state;
    z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
    z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
    return z ^ (z >> 31);
  };
  for (int i = static_cast<int>(arr.size()) - 1; i > 0; --i) {
    int j = static_cast<int>(next_u64() % static_cast<uint64_t>(i + 1));
    std::swap(arr[static_cast<size_t>(i)], arr[static_cast<size_t>(j)]);
  }
  return arr;
}

std::vector<std::string> shuffle_serializer_names(const std::vector<std::string>& names,
                                                  uint64_t base_seed, const std::string& type_id,
                                                  int instance_count,
                                                  const std::string& type_config_hash,
                                                  const std::string& mode, int rep);

std::string resolve_schedule_strategy();
bool resolve_record_run_order();

// Golden: A,B,C @ 42|message|1|abc|bytes|0 → C,B,A; seed == 15992650003647724414.
// Returns 0 on success.
int verify_schedule_golden();

}  // namespace bench
