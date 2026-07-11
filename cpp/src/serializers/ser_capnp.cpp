#include "bench/serializer.hpp"

#if defined(HAS_CAPNP) && HAS_CAPNP
#include "benchmark.capnp.h"
#include <capnp/message.h>
#include <capnp/serialize.h>
#include <kj/array.h>
#include <kj/io.h>
#endif

#include <stdexcept>

// Cap'n Proto — high-value zero-copy schema codec (C++ first-class).
// Bytes: messageToFlatArray / FlatArrayMessageReader.
// Stream: writeMessage(VectorOutputStream) / InputStreamMessageReader(ArrayInputStream).

namespace bench {
#if defined(HAS_CAPNP) && HAS_CAPNP
namespace {

class CapnpSer final : public ISerializer {
 public:
  const char* name() const override { return "capnproto"; }
  const char* version() const override { return "1.0.x"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "schema"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    capnp::MallocMessageBuilder msg;
    fill_root(msg);
    kj::Array<capnp::word> words = capnp::messageToFlatArray(msg);
    auto bytes = words.asBytes();
    return std::vector<uint8_t>(bytes.begin(), bytes.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (data.size() % sizeof(capnp::word) != 0)
      throw std::runtime_error("capnp: size not multiple of word");
    kj::ArrayPtr<const capnp::word> words(
        reinterpret_cast<const capnp::word*>(data.data()), data.size() / sizeof(capnp::word));
    capnp::FlatArrayMessageReader reader(words);
    return read_from(reader);
  }

  // Docs (capnp/serialize.h): writeMessage(OutputStream&) / InputStreamMessageReader.
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    capnp::MallocMessageBuilder msg;
    fill_root(msg);
    kj::VectorOutputStream vos;
    capnp::writeMessage(vos, msg);
    auto arr = vos.getArray();
    out.assign(arr.begin(), arr.end());
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    kj::ArrayInputStream ais(kj::ArrayPtr<const kj::byte>(
        reinterpret_cast<const kj::byte*>(data.data()), data.size()));
    capnp::InputStreamMessageReader reader(ais);
    return read_from(reader);
  }

 private:
  void fill_root(capnp::MallocMessageBuilder& msg) {
    if (type_id_ == "message") {
      if (n_ > 1) {
        auto root = msg.initRoot<::BatchMessage>();
        const auto& vec = std::get<std::vector<Message>>(value_);
        auto list = root.initItems(vec.size());
        for (size_t i = 0; i < vec.size(); ++i) fill_message(list[i], vec[i]);
      } else {
        fill_message(msg.initRoot<::Message>(), std::get<Message>(value_));
      }
    } else if (type_id_ == "document") {
      if (n_ > 1) {
        auto root = msg.initRoot<::BatchDocument>();
        const auto& vec = std::get<std::vector<Document>>(value_);
        auto list = root.initItems(vec.size());
        for (size_t i = 0; i < vec.size(); ++i) fill_document(list[i], vec[i]);
      } else {
        fill_document(msg.initRoot<::Document>(), std::get<Document>(value_));
      }
    } else if (type_id_ == "telemetry") {
      if (n_ > 1) {
        auto root = msg.initRoot<::BatchTelemetry>();
        const auto& vec = std::get<std::vector<Telemetry>>(value_);
        auto list = root.initItems(vec.size());
        for (size_t i = 0; i < vec.size(); ++i) fill_telemetry(list[i], vec[i]);
      } else {
        fill_telemetry(msg.initRoot<::Telemetry>(), std::get<Telemetry>(value_));
      }
    } else if (type_id_ == "strings") {
      if (n_ > 1) {
        auto root = msg.initRoot<::BatchStrings>();
        const auto& vec = std::get<std::vector<Strings>>(value_);
        auto list = root.initItems(vec.size());
        for (size_t i = 0; i < vec.size(); ++i) fill_strings(list[i], vec[i]);
      } else {
        fill_strings(msg.initRoot<::Strings>(), std::get<Strings>(value_));
      }
    } else {
      if (n_ > 1) {
        auto root = msg.initRoot<::BatchEvent>();
        const auto& vec = std::get<std::vector<Event>>(value_);
        auto list = root.initItems(vec.size());
        for (size_t i = 0; i < vec.size(); ++i) fill_event(list[i], vec[i]);
      } else {
        fill_event(msg.initRoot<::Event>(), std::get<Event>(value_));
      }
    }
  }

  Value read_from(capnp::MessageReader& reader) {
    if (type_id_ == "message") {
      if (n_ > 1) {
        auto root = reader.getRoot<::BatchMessage>();
        std::vector<Message> v;
        v.reserve(root.getItems().size());
        for (auto item : root.getItems()) v.push_back(read_message(item));
        return v;
      }
      return read_message(reader.getRoot<::Message>());
    }
    if (type_id_ == "document") {
      if (n_ > 1) {
        auto root = reader.getRoot<::BatchDocument>();
        std::vector<Document> v;
        for (auto item : root.getItems()) v.push_back(read_document(item));
        return v;
      }
      return read_document(reader.getRoot<::Document>());
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) {
        auto root = reader.getRoot<::BatchTelemetry>();
        std::vector<Telemetry> v;
        for (auto item : root.getItems()) v.push_back(read_telemetry(item));
        return v;
      }
      return read_telemetry(reader.getRoot<::Telemetry>());
    }
    if (type_id_ == "strings") {
      if (n_ > 1) {
        auto root = reader.getRoot<::BatchStrings>();
        std::vector<Strings> v;
        for (auto item : root.getItems()) v.push_back(read_strings(item));
        return v;
      }
      return read_strings(reader.getRoot<::Strings>());
    }
    if (n_ > 1) {
      auto root = reader.getRoot<::BatchEvent>();
      std::vector<Event> v;
      for (auto item : root.getItems()) v.push_back(read_event(item));
      return v;
    }
    return read_event(reader.getRoot<::Event>());
  }

  static void fill_message(::Message::Builder b, const bench::Message& m) {
    b.setFBool(m.f_bool);
    b.setFInt32(m.f_int32);
    b.setFInt64(m.f_int64);
    b.setFFloat64(m.f_float64);
    b.setFString(m.f_string);
    b.setFBool2(m.f_bool_2);
    b.setFInt32B(m.f_int32_2);
    b.setFStringB(m.f_string_2);
  }
  static bench::Message read_message(::Message::Reader r) {
    return bench::Message{r.getFBool(), r.getFInt32(), r.getFInt64(), r.getFFloat64(),
                          r.getFString(), r.getFBool2(), r.getFInt32B(), r.getFStringB()};
  }
  static void fill_document(::Document::Builder b, const bench::Document& d) {
    b.setId(d.id);
    b.setStatus(d.status);
    auto meta = b.initMeta();
    meta.setRegion(d.meta.region);
    meta.setVersion(d.meta.version);
    auto items = b.initItems(d.items.size());
    for (size_t i = 0; i < d.items.size(); ++i) {
      items[i].setSku(d.items[i].sku);
      items[i].setQty(d.items[i].qty);
      items[i].setPriceMinor(d.items[i].price_minor);
    }
  }
  static bench::Document read_document(::Document::Reader r) {
    bench::Document d;
    d.id = r.getId();
    d.status = r.getStatus();
    d.meta.region = r.getMeta().getRegion();
    d.meta.version = r.getMeta().getVersion();
    for (auto it : r.getItems())
      d.items.push_back(DocumentItem{it.getSku(), it.getQty(), it.getPriceMinor()});
    return d;
  }
  static void fill_telemetry(::Telemetry::Builder b, const bench::Telemetry& t) {
    b.setSource(t.source);
    b.setTs(t.ts);
    auto tags = b.initTags(t.tags.size());
    for (size_t i = 0; i < t.tags.size(); ++i) tags.set(i, t.tags[i]);
    auto vals = b.initValues(t.values.size());
    for (size_t i = 0; i < t.values.size(); ++i) vals.set(i, t.values[i]);
  }
  static bench::Telemetry read_telemetry(::Telemetry::Reader r) {
    bench::Telemetry t;
    t.source = r.getSource();
    t.ts = r.getTs();
    for (auto tg : r.getTags()) t.tags.emplace_back(tg);
    for (auto v : r.getValues()) t.values.push_back(v);
    return t;
  }
  static void fill_strings(::Strings::Builder b, const bench::Strings& s) {
    auto items = b.initItems(s.items.size());
    for (size_t i = 0; i < s.items.size(); ++i) items.set(i, s.items[i]);
  }
  static bench::Strings read_strings(::Strings::Reader r) {
    bench::Strings s;
    for (auto it : r.getItems()) s.items.emplace_back(it);
    return s;
  }
  static void fill_event(::Event::Builder b, const bench::Event& e) {
    b.setEventId(e.event_id);
    b.setEventType(e.event_type);
    b.setOccurredAt(e.occurred_at);
    b.setProducer(e.producer);
    auto attrs = b.initAttrs(e.attrs.size());
    for (size_t i = 0; i < e.attrs.size(); ++i) {
      attrs[i].setKey(e.attrs[i].key);
      attrs[i].setValue(e.attrs[i].value);
    }
  }
  static bench::Event read_event(::Event::Reader r) {
    bench::Event e;
    e.event_id = r.getEventId();
    e.event_type = r.getEventType();
    e.occurred_at = r.getOccurredAt();
    e.producer = r.getProducer();
    for (auto a : r.getAttrs()) e.attrs.push_back(EventAttr{a.getKey(), a.getValue()});
    return e;
  }

  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

SerializerPtr make_capnproto() { return std::make_unique<CapnpSer>(); }

#else

SerializerPtr make_capnproto() {
  return nullptr;  // registered only when HAS_CAPNP
}

#endif
}  // namespace bench
