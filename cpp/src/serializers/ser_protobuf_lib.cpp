// Official Google Protocol Buffers C++ runtime (libprotobuf) + protoc-generated stubs.
// Shared schema: schemas/v2/protobuf/benchmark_v2.proto
// Fair path: domain→Message in prepare (untimed); timed SerializeToArray / ParseFromArray.

#include "bench/serializer.hpp"

#include "benchmark_v2.pb.h"

#include <google/protobuf/message_lite.h>
#include <google/protobuf/stubs/common.h>

#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <vector>

namespace bench {
namespace {

using google::protobuf::MessageLite;

std::string pb_version() {
  // GOOGLE_PROTOBUF_VERSION is e.g. 3012004 → 3.12.4
  const int v = GOOGLE_PROTOBUF_VERSION;
  const int major = v / 1000000;
  const int minor = (v / 1000) % 1000;
  const int patch = v % 1000;
  return std::to_string(major) + "." + std::to_string(minor) + "." + std::to_string(patch);
}

benchmark::v2::Message to_pb_message(const Message& m) {
  benchmark::v2::Message out;
  out.set_f_bool(m.f_bool);
  out.set_f_int32(m.f_int32);
  out.set_f_int64(m.f_int64);
  out.set_f_float64(m.f_float64);
  out.set_f_string(m.f_string);
  out.set_f_bool_2(m.f_bool_2);
  out.set_f_int32_2(m.f_int32_2);
  out.set_f_string_2(m.f_string_2);
  return out;
}

Message from_pb_message(const benchmark::v2::Message& m) {
  Message out;
  out.f_bool = m.f_bool();
  out.f_int32 = m.f_int32();
  out.f_int64 = m.f_int64();
  out.f_float64 = m.f_float64();
  out.f_string = m.f_string();
  out.f_bool_2 = m.f_bool_2();
  out.f_int32_2 = m.f_int32_2();
  out.f_string_2 = m.f_string_2();
  return out;
}

benchmark::v2::Document to_pb_document(const Document& d) {
  benchmark::v2::Document out;
  out.set_id(d.id);
  out.set_status(d.status);
  out.mutable_meta()->set_region(d.meta.region);
  out.mutable_meta()->set_version(d.meta.version);
  for (const auto& it : d.items) {
    auto* p = out.add_items();
    p->set_sku(it.sku);
    p->set_qty(it.qty);
    p->set_price_minor(it.price_minor);
  }
  return out;
}

Document from_pb_document(const benchmark::v2::Document& d) {
  Document out;
  out.id = d.id();
  out.status = d.status();
  out.meta.region = d.meta().region();
  out.meta.version = d.meta().version();
  out.items.reserve(static_cast<size_t>(d.items_size()));
  for (const auto& it : d.items()) {
    DocumentItem x;
    x.sku = it.sku();
    x.qty = it.qty();
    x.price_minor = it.price_minor();
    out.items.push_back(std::move(x));
  }
  return out;
}

benchmark::v2::Telemetry to_pb_telemetry(const Telemetry& t) {
  benchmark::v2::Telemetry out;
  out.set_source(t.source);
  out.set_ts(t.ts);
  for (const auto& tg : t.tags) out.add_tags(tg);
  for (double v : t.values) out.add_values(v);
  return out;
}

Telemetry from_pb_telemetry(const benchmark::v2::Telemetry& t) {
  Telemetry out;
  out.source = t.source();
  out.ts = t.ts();
  out.tags.assign(t.tags().begin(), t.tags().end());
  out.values.assign(t.values().begin(), t.values().end());
  return out;
}

benchmark::v2::Strings to_pb_strings(const Strings& s) {
  benchmark::v2::Strings out;
  for (const auto& it : s.items) out.add_items(it);
  return out;
}

Strings from_pb_strings(const benchmark::v2::Strings& s) {
  Strings out;
  out.items.assign(s.items().begin(), s.items().end());
  return out;
}

benchmark::v2::Event to_pb_event(const Event& e) {
  benchmark::v2::Event out;
  out.set_event_id(e.event_id);
  out.set_event_type(e.event_type);
  out.set_occurred_at(e.occurred_at);
  out.set_producer(e.producer);
  for (const auto& a : e.attrs) {
    auto* p = out.add_attrs();
    p->set_key(a.key);
    p->set_value(a.value);
  }
  return out;
}

Event from_pb_event(const benchmark::v2::Event& e) {
  Event out;
  out.event_id = e.event_id();
  out.event_type = e.event_type();
  out.occurred_at = e.occurred_at();
  out.producer = e.producer();
  out.attrs.reserve(static_cast<size_t>(e.attrs_size()));
  for (const auto& a : e.attrs()) {
    EventAttr x;
    x.key = a.key();
    x.value = a.value();
    out.attrs.push_back(std::move(x));
  }
  return out;
}

std::unique_ptr<MessageLite> to_proto(const Fixture& fx) {
  if (fx.instance_count > 1) {
    if (fx.type_id == "message") {
      auto batch = std::make_unique<benchmark::v2::BatchMessage>();
      for (const auto& m : std::get<std::vector<Message>>(fx.value)) {
        *batch->add_items() = to_pb_message(m);
      }
      return batch;
    }
    if (fx.type_id == "document") {
      auto batch = std::make_unique<benchmark::v2::BatchDocument>();
      for (const auto& d : std::get<std::vector<Document>>(fx.value)) {
        *batch->add_items() = to_pb_document(d);
      }
      return batch;
    }
    if (fx.type_id == "telemetry") {
      auto batch = std::make_unique<benchmark::v2::BatchTelemetry>();
      for (const auto& t : std::get<std::vector<Telemetry>>(fx.value)) {
        *batch->add_items() = to_pb_telemetry(t);
      }
      return batch;
    }
    if (fx.type_id == "strings") {
      auto batch = std::make_unique<benchmark::v2::BatchStrings>();
      for (const auto& s : std::get<std::vector<Strings>>(fx.value)) {
        *batch->add_items() = to_pb_strings(s);
      }
      return batch;
    }
    if (fx.type_id == "event") {
      auto batch = std::make_unique<benchmark::v2::BatchEvent>();
      for (const auto& e : std::get<std::vector<Event>>(fx.value)) {
        *batch->add_items() = to_pb_event(e);
      }
      return batch;
    }
  }
  if (fx.type_id == "message") {
    return std::make_unique<benchmark::v2::Message>(to_pb_message(std::get<Message>(fx.value)));
  }
  if (fx.type_id == "document") {
    return std::make_unique<benchmark::v2::Document>(to_pb_document(std::get<Document>(fx.value)));
  }
  if (fx.type_id == "telemetry") {
    return std::make_unique<benchmark::v2::Telemetry>(to_pb_telemetry(std::get<Telemetry>(fx.value)));
  }
  if (fx.type_id == "strings") {
    return std::make_unique<benchmark::v2::Strings>(to_pb_strings(std::get<Strings>(fx.value)));
  }
  if (fx.type_id == "event") {
    return std::make_unique<benchmark::v2::Event>(to_pb_event(std::get<Event>(fx.value)));
  }
  throw std::runtime_error("libprotobuf: unsupported type " + fx.type_id);
}

Value from_proto(const std::string& type_id, int n, const MessageLite& msg) {
  // Concrete types are known from prepare; static_cast is safe (same as Java/Go toDomain).
  if (n > 1) {
    if (type_id == "message") {
      std::vector<Message> out;
      const auto& b = static_cast<const benchmark::v2::BatchMessage&>(msg);
      out.reserve(static_cast<size_t>(b.items_size()));
      for (const auto& it : b.items()) out.push_back(from_pb_message(it));
      return out;
    }
    if (type_id == "document") {
      std::vector<Document> out;
      const auto& b = static_cast<const benchmark::v2::BatchDocument&>(msg);
      for (const auto& it : b.items()) out.push_back(from_pb_document(it));
      return out;
    }
    if (type_id == "telemetry") {
      std::vector<Telemetry> out;
      const auto& b = static_cast<const benchmark::v2::BatchTelemetry&>(msg);
      for (const auto& it : b.items()) out.push_back(from_pb_telemetry(it));
      return out;
    }
    if (type_id == "strings") {
      std::vector<Strings> out;
      const auto& b = static_cast<const benchmark::v2::BatchStrings&>(msg);
      for (const auto& it : b.items()) out.push_back(from_pb_strings(it));
      return out;
    }
    if (type_id == "event") {
      std::vector<Event> out;
      const auto& b = static_cast<const benchmark::v2::BatchEvent&>(msg);
      for (const auto& it : b.items()) out.push_back(from_pb_event(it));
      return out;
    }
  }
  if (type_id == "message") {
    return from_pb_message(static_cast<const benchmark::v2::Message&>(msg));
  }
  if (type_id == "document") {
    return from_pb_document(static_cast<const benchmark::v2::Document&>(msg));
  }
  if (type_id == "telemetry") {
    return from_pb_telemetry(static_cast<const benchmark::v2::Telemetry&>(msg));
  }
  if (type_id == "strings") {
    return from_pb_strings(static_cast<const benchmark::v2::Strings&>(msg));
  }
  return from_pb_event(static_cast<const benchmark::v2::Event&>(msg));
}

class LibProtobufSer final : public ISerializer {
 public:
  const char* name() const override { return "protobuf"; }
  const char* version() const override { return version_.c_str(); }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "message"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    prepared_ = to_proto(fx);
    // Fresh parse target of the same concrete type.
    dst_.reset(prepared_->New());
    ser_buf_.clear();
    ser_buf_.reserve(static_cast<size_t>(prepared_->ByteSizeLong()) + 64);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    if (!prepared_) throw std::runtime_error("libprotobuf: prepare required");
    // ByteSizeLong is part of the encode path for libprotobuf (matches typical clients).
    const int sz = static_cast<int>(prepared_->ByteSizeLong());
    ser_buf_.resize(static_cast<size_t>(sz));
    if (sz > 0 && !prepared_->SerializeToArray(ser_buf_.data(), sz)) {
      throw std::runtime_error("libprotobuf: SerializeToArray failed");
    }
    return ser_buf_;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (!dst_) throw std::runtime_error("libprotobuf: prepare required");
    dst_->Clear();
    if (!dst_->ParseFromArray(data.data(), static_cast<int>(data.size()))) {
      throw std::runtime_error("libprotobuf: ParseFromArray failed");
    }
    // Timed path ends at MessageLite; domain conversion is untimed in to_domain.
    // Placeholder Value (variant cannot hold MessageLite*).
    return Message{};
  }

  Value to_domain(Value /*decoded*/) override {
    if (!dst_) return Message{};
    return from_proto(type_id_, n_, *dst_);
  }

 private:
  std::string version_ = pb_version();
  std::string type_id_;
  int n_ = 1;
  std::unique_ptr<MessageLite> prepared_;
  std::unique_ptr<MessageLite> dst_;
  std::vector<uint8_t> ser_buf_;
};

}  // namespace

SerializerPtr make_protobuf() { return std::make_unique<LibProtobufSer>(); }

}  // namespace bench
