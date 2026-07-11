#pragma once

#include "bench/fixture.hpp"

#include <cstdint>
#include <memory>
#include <string>
#include <vector>

namespace bench {

// prepare / timed call-path contract (aligned with Java/Go/Rust/Python).
//
// prepare(fixture)                 # untimed
// serialize_bytes / stream         # timed
// deserialize_bytes / stream       # timed (codec only)
// to_domain (optional)             # untimed
// fidelity                         # untimed
class ISerializer {
 public:
  virtual ~ISerializer() = default;

  virtual const char* name() const = 0;
  virtual const char* version() const = 0;
  /** "native" | "adapted" */
  virtual const char* stream_mode() const { return "adapted"; }
  /** "struct" | "dom" | "message" | "schema" | "archive" */
  virtual const char* native_kind() const { return "struct"; }
  virtual bool supports(const std::string& /*type_id*/) const { return true; }

  virtual void prepare(const Fixture& fx) = 0;
  virtual std::vector<uint8_t> serialize_bytes(const Fixture& fx) = 0;
  virtual Value deserialize_bytes(const std::vector<uint8_t>& data) = 0;

  // Default stream: adapted bytes path (write/read full buffer).
  virtual size_t serialize_stream(const Fixture& fx, std::vector<uint8_t>& out) {
    auto b = serialize_bytes(fx);
    out = std::move(b);
    return out.size();
  }
  virtual Value deserialize_stream(const std::vector<uint8_t>& data) {
    return deserialize_bytes(data);
  }

  // Optional untimed library-native → suite domain (e.g. protobuf Message).
  virtual Value to_domain(Value decoded) { return decoded; }
};

using SerializerPtr = std::unique_ptr<ISerializer>;
std::vector<SerializerPtr> all_serializers();
std::vector<SerializerPtr> select_serializers(const std::string& filter);

}  // namespace bench
