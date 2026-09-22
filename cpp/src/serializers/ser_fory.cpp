#include "bench/serializer.hpp"
#include "fory/serialization/fory.h"

namespace bench {
FORY_STRUCT(Message, f_bool, f_int32, f_int64, f_float64, f_string,
            f_bool_2, f_int32_2, f_string_2);
FORY_STRUCT(DocumentMeta, region, version);
FORY_STRUCT(DocumentItem, sku, qty, price_minor);
FORY_STRUCT(Document, id, status, meta, items);
FORY_STRUCT(Telemetry, source, ts, tags, values);
FORY_STRUCT(Strings, items);
FORY_STRUCT(EventAttr, key, value);
FORY_STRUCT(Event, event_id, event_type, occurred_at, producer, attrs);

namespace {
class ForySer final : public ISerializer {
 public:
  ForySer() {
    fory_.register_struct<Message>(1);
    fory_.register_struct<DocumentMeta>(2);
    fory_.register_struct<DocumentItem>(3);
    fory_.register_struct<Document>(4);
    fory_.register_struct<Telemetry>(5);
    fory_.register_struct<Strings>(6);
    fory_.register_struct<EventAttr>(7);
    fory_.register_struct<Event>(8);
  }
  const char* name() const override { return "fory"; }
  const char* version() const override { return "1.7.4"; }
  void prepare(const Fixture& fx) override {
    std::visit([this](const auto& value) {
      using T = std::decay_t<decltype(value)>;
      decode_ = [](fory::serialization::Fory& f, const std::vector<uint8_t>& bytes) -> Value {
        return f.deserialize<T>(bytes).value();
      };
    }, fx.value);
    deserialize_bytes(serialize_bytes(fx));
  }
  std::vector<uint8_t> serialize_bytes(const Fixture& fx) override {
    return std::visit([this](const auto& value) {
      return fory_.serialize(value).value();
    }, fx.value);
  }
  Value deserialize_bytes(const std::vector<uint8_t>& bytes) override {
    return decode_(fory_, bytes);
  }
 private:
  fory::serialization::Fory fory_ = fory::serialization::Fory::builder().xlang(false).build();
  Value (*decode_)(fory::serialization::Fory&, const std::vector<uint8_t>&) = nullptr;
};
}
SerializerPtr make_fory() { return std::make_unique<ForySer>(); }
}  // namespace bench
