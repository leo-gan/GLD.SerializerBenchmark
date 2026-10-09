#pragma once
// Data Model v2 domain types (message, document, telemetry, strings, event, graph).
// Within-language deterministic generators; cross-language payload identity not required.

#include <cmath>
#include <cstdint>
#include <memory>
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

// Wide flat row. Domain order is fixed columns, then the two strings.
// SBE wire order matches that order; signal's wire order does not.
struct Table {
  double f_float[16]{};
  int64_t f_int[4]{};
  std::string f_str_0;
  std::string f_str_1;
  bool operator==(const Table& o) const {
    for (int i = 0; i < 16; ++i) {
      if (!nearly_eq(f_float[i], o.f_float[i])) return false;
    }
    for (int i = 0; i < 4; ++i) {
      if (f_int[i] != o.f_int[i]) return false;
    }
    return f_str_0 == o.f_str_0 && f_str_1 == o.f_str_1;
  }
};

struct NestedMeta {
  std::string region;
  int32_t version = 0;
  bool operator==(const NestedMeta& o) const {
    return region == o.region && version == o.version;
  }
};

struct NestedItem {
  std::string sku;
  int32_t qty = 0;
  int64_t price_minor = 0;
  bool operator==(const NestedItem& o) const {
    return sku == o.sku && qty == o.qty && price_minor == o.price_minor;
  }
};

// Domain order: id, status, meta, items. Distinct from Document so both can live in Value.
struct NestedRow {
  std::string id;
  int32_t status = 0;
  NestedMeta meta;
  std::vector<NestedItem> items;
  bool operator==(const NestedRow& o) const {
    return id == o.id && status == o.status && meta == o.meta && items == o.items;
  }
};

struct SignalLeg {
  int64_t leg_id = 0;
  int32_t leg_qty = 0;
  int32_t leg_pad = 0;
  bool operator==(const SignalLeg& o) const {
    return leg_id == o.leg_id && leg_qty == o.leg_qty && leg_pad == o.leg_pad;
  }
};

// Domain order: fixed scalars, then symbol and venue, then legs.
// SBE wire order is fixed scalars, then the legs group, then symbol and venue.
struct Signal {
  int64_t seq = 0;
  int64_t ts = 0;
  int64_t price_mantissa = 0;
  int32_t qty = 0;
  int32_t flags = 0;
  std::string symbol;
  std::string venue;
  std::vector<SignalLeg> legs;
  bool operator==(const Signal& o) const {
    return seq == o.seq && ts == o.ts && price_mantissa == o.price_mantissa && qty == o.qty &&
           flags == o.flags && symbol == o.symbol && venue == o.venue && legs == o.legs;
  }
};

// One graph. `regions` and `people` own the nodes; Order::region and Person::next do not.
// A copy keeps sharing inside the copy and does not alias the source. No operator==:
// Person::next is a ring, so fidelity() compares identity with a visited set.
struct Region {
  std::string code;
  std::string note;
  int32_t version = 0;
};

struct Order {
  std::string sku;
  int32_t qty = 0;
  Region* region = nullptr;
};

struct Person {
  std::string name;
  Person* next = nullptr;
};

struct Book {
  std::vector<std::unique_ptr<Region>> regions;
  std::vector<Order> orders;
  std::vector<std::unique_ptr<Person>> people;

  Book() = default;
  Book(const Book& other);
  Book& operator=(const Book& other);
  Book(Book&&) noexcept = default;
  Book& operator=(Book&&) noexcept = default;
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

Message make_message(Rng& r, int32_t lo, int32_t hi, int smin, int smax);
Document make_document(Rng& r, int children, int smin, int smax);
Telemetry make_telemetry(Rng& r, int points, int tag_count, int smin, int smax);
Strings make_strings(Rng& r, int count, int smin, int smax, double duplication);
Event make_event(Rng& r, int attr_count, int smin, int smax);

}  // namespace bench
