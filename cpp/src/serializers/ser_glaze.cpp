#include "bench/serializer.hpp"

#include <glaze/glaze.hpp>

#include <stdexcept>
#include <string>
#include <utility>
#include <variant>
#include <vector>

// glaze (stephenberry/glaze) — last C++20 release (v2.9.5).
// Optimal: glz::write_json / glz::read_json into a reused std::string
// (docs: prefer the in-place buffer overloads when the call is repeated).
// Domain structs get explicit glz::meta so reflection does not depend on
// aggregate status (they define operator==).
// Stream: no istream/ostream codec in this pin → adapted (bytes path).
// CBOR arrived in later (C++23) glaze; not registered here.

namespace glz {

template <>
struct meta<bench::Message> {
  using T = bench::Message;
  static constexpr auto value = object(&T::f_bool, &T::f_int32, &T::f_int64, &T::f_float64,
                                       &T::f_string, &T::f_bool_2, &T::f_int32_2, &T::f_string_2);
};
template <>
struct meta<bench::DocumentMeta> {
  using T = bench::DocumentMeta;
  static constexpr auto value = object(&T::region, &T::version);
};
template <>
struct meta<bench::DocumentItem> {
  using T = bench::DocumentItem;
  static constexpr auto value = object(&T::sku, &T::qty, &T::price_minor);
};
template <>
struct meta<bench::Document> {
  using T = bench::Document;
  static constexpr auto value = object(&T::id, &T::status, &T::meta, &T::items);
};
template <>
struct meta<bench::Telemetry> {
  using T = bench::Telemetry;
  static constexpr auto value = object(&T::source, &T::ts, &T::tags, &T::values);
};
template <>
struct meta<bench::Strings> {
  using T = bench::Strings;
  static constexpr auto value = object(&T::items);
};
template <>
struct meta<bench::EventAttr> {
  using T = bench::EventAttr;
  static constexpr auto value = object(&T::key, &T::value);
};
template <>
struct meta<bench::Event> {
  using T = bench::Event;
  static constexpr auto value = object(&T::event_id, &T::event_type, &T::occurred_at, &T::producer,
                                       &T::attrs);
};

}  // namespace glz

namespace bench {
namespace {

void check_glaze(auto ec, const char* what, const std::string& buf) {
  if (ec) {
    throw std::runtime_error(std::string(what) + ": " + glz::format_error(ec, buf));
  }
}

template <class T>
void write_json_into(const T& v, std::string& buf) {
  buf.clear();
  auto ec = glz::write_json(v, buf);
  check_glaze(ec, "glaze write_json", buf);
}

template <class T>
T read_json_from(const std::vector<uint8_t>& data) {
  // Docs: prefer a null-terminated std::string for read_json.
  std::string buf(data.begin(), data.end());
  T out{};
  auto ec = glz::read_json(out, buf);
  check_glaze(ec, "glaze read_json", buf);
  return out;
}

Value decode_json(const std::string& type_id, int n, const std::vector<uint8_t>& data) {
  if (n > 1) {
    if (type_id == "message") return read_json_from<std::vector<Message>>(data);
    if (type_id == "document") return read_json_from<std::vector<Document>>(data);
    if (type_id == "telemetry") return read_json_from<std::vector<Telemetry>>(data);
    if (type_id == "strings") return read_json_from<std::vector<Strings>>(data);
    if (type_id == "event") return read_json_from<std::vector<Event>>(data);
  } else {
    if (type_id == "message") return read_json_from<Message>(data);
    if (type_id == "document") return read_json_from<Document>(data);
    if (type_id == "telemetry") return read_json_from<Telemetry>(data);
    if (type_id == "strings") return read_json_from<Strings>(data);
    if (type_id == "event") return read_json_from<Event>(data);
  }
  throw std::runtime_error("glaze: unknown type " + type_id);
}

class GlazeJson final : public ISerializer {
 public:
  const char* name() const override { return "glaze"; }
  const char* version() const override { return "2.9.5"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "struct"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
    buf_.clear();
    buf_.reserve(256);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::visit([&](const auto& v) { write_json_into(v, buf_); }, value_);
    return std::vector<uint8_t>(buf_.begin(), buf_.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return decode_json(type_id_, n_, data);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  Value value_;
  std::string buf_;
};

}  // namespace

SerializerPtr make_glaze() { return std::make_unique<GlazeJson>(); }

}  // namespace bench
