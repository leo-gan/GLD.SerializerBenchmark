#pragma once
// Data Model v2 domain types (message, document, telemetry, strings, event).
// Within-language deterministic generators; cross-language payload identity not required.

#include <cmath>
#include <cstdint>
#include <string>
#include <utility>
#include <vector>

namespace bench {

inline bool nearly_eq(double a, double b) {
  const double scale = std::max(1.0, std::max(std::fabs(a), std::fabs(b)));
  return std::fabs(a - b) <= 1e-6 * scale;
}

inline constexpr int64_t kBaseTsMs = 1'704'067'200'000LL;

struct Message {
  bool f_bool = false;
  int32_t f_int32 = 0;
  int64_t f_int64 = 0;
  double f_float64 = 0;
  std::string f_string;
  bool f_bool_2 = false;
  int32_t f_int32_2 = 0;
  std::string f_string_2;

  bool operator==(const Message& o) const {
    return f_bool == o.f_bool && f_int32 == o.f_int32 && f_int64 == o.f_int64 &&
           nearly_eq(f_float64, o.f_float64) && f_string == o.f_string &&
           f_bool_2 == o.f_bool_2 && f_int32_2 == o.f_int32_2 && f_string_2 == o.f_string_2;
  }
};

struct DocumentMeta {
  std::string region;
  int32_t version = 0;
  bool operator==(const DocumentMeta& o) const {
    return region == o.region && version == o.version;
  }
};

struct DocumentItem {
  std::string sku;
  int32_t qty = 0;
  int64_t price_minor = 0;
  bool operator==(const DocumentItem& o) const {
    return sku == o.sku && qty == o.qty && price_minor == o.price_minor;
  }
};

struct Document {
  std::string id;
  int32_t status = 0;
  DocumentMeta meta;
  std::vector<DocumentItem> items;
  bool operator==(const Document& o) const {
    return id == o.id && status == o.status && meta == o.meta && items == o.items;
  }
};

struct Telemetry {
  std::string source;
  int64_t ts = 0;
  std::vector<std::string> tags;
  std::vector<double> values;
  bool operator==(const Telemetry& o) const {
    if (source != o.source || ts != o.ts || tags != o.tags || values.size() != o.values.size())
      return false;
    for (size_t i = 0; i < values.size(); ++i) {
      if (!nearly_eq(values[i], o.values[i])) return false;
    }
    return true;
  }
};

struct Strings {
  std::vector<std::string> items;
  bool operator==(const Strings& o) const { return items == o.items; }
};

struct EventAttr {
  std::string key;
  std::string value;
  bool operator==(const EventAttr& o) const { return key == o.key && value == o.value; }
};

struct Event {
  std::string event_id;
  std::string event_type;
  int64_t occurred_at = 0;
  std::string producer;
  std::vector<EventAttr> attrs;
  bool operator==(const Event& o) const {
    return event_id == o.event_id && event_type == o.event_type &&
           occurred_at == o.occurred_at && producer == o.producer && attrs == o.attrs;
  }
};

// Deterministic xorshift64* (within-language only). Zero-seed / avalanche uses
// floor(2^64/φ)=0x9E3779B97F4A7C15 (golden ratio; nothing-up-my-sleeve).
class Rng {
 public:
  explicit Rng(uint64_t seed) : state_(seed == 0 ? 0x9E3779B97F4A7C15ULL : seed) {}
  uint64_t next_u64() {
    uint64_t x = state_;
    x ^= x << 13;
    x ^= x >> 7;
    x ^= x << 17;
    state_ = x;
    return x;
  }
  int32_t next_int(int32_t lo, int32_t hi) {
    if (hi <= lo) return lo;
    return lo + static_cast<int32_t>(next_u64() % static_cast<uint64_t>(hi - lo + 1));
  }
  bool next_bool() { return (next_u64() & 1ULL) != 0; }
  double next_f64() {
    return static_cast<double>(next_u64() >> 11) / static_cast<double>(1ULL << 53);
  }
  std::string word(int min_l, int max_l) {
    int n = next_int(min_l, max_l);
    static constexpr char A[] = "abcdefghijklmnopqrstuvwxyz";
    std::string s;
    s.resize(static_cast<size_t>(n));
    for (int i = 0; i < n; ++i) s[static_cast<size_t>(i)] = A[next_u64() % 26];
    return s;
  }

 private:
  uint64_t state_;
};

inline uint64_t mix_seed(uint64_t seed, const std::string& type_id, int32_t idx) {
  uint64_t h = seed;
  for (unsigned char b : type_id) {
    h = (h ^ b) * 0x100000001B3ULL;
  }
  h ^= static_cast<uint64_t>(idx) * 0x9E3779B97F4A7C15ULL;
  return h == 0 ? 1 : h;
}

Message make_message(Rng& r);
Document make_document(Rng& r, int children);
Telemetry make_telemetry(Rng& r, int points, int tag_count);
Strings make_strings(Rng& r, int count);
Event make_event(Rng& r, int attr_count);

}  // namespace bench
