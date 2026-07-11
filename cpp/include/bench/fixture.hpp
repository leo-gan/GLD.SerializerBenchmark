#pragma once

#include "bench/types.hpp"

#include <memory>
#include <string>
#include <variant>
#include <vector>

namespace bench {

// Single instance or batch (N>1) of a suite type.
using Value = std::variant<Message, Document, Telemetry, Strings, Event,
                           std::vector<Message>, std::vector<Document>,
                           std::vector<Telemetry>, std::vector<Strings>,
                           std::vector<Event>>;

struct Fixture {
  std::string type_id;
  Value value;
  int instance_count = 1;
  std::string type_config_hash;
};

struct TypeConfig {
  int children = 8;
  int points = 32;
  int count = 32;
  int attr_count = 4;
  int tag_count = 2;
};

Fixture make_fixture(const std::string& type_id, const TypeConfig& cfg, uint64_t seed,
                     int instance_count, const std::string& type_config_hash);

bool fidelity(const Value& a, const Value& b);

}  // namespace bench
