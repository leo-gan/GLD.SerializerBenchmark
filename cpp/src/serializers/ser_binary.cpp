#include "bench/serializer.hpp"
#include "bench/stream_util.hpp"

#include <msgpack.hpp>

#include <cstring>
#include <string_view>
#include <type_traits>

// Non-intrusive msgpack-c adaptor specializations for the domain structs.
// Wire format is identical to what intrusive MSGPACK_DEFINE_MAP(...) inside
// the structs would produce (map keyed by field name); keeping them here
// avoids a msgpack dependency in the shared bench/types.hpp. With these,
// packer::pack() and object::convert()/as() move data directly between
// msgpack and the structs with no intermediate DOM.
namespace msgpack {
MSGPACK_API_VERSION_NAMESPACE(MSGPACK_DEFAULT_API_NS) {
namespace adaptor {

inline std::string_view mp_key(const msgpack::object& k) {
  if (k.type != msgpack::type::STR) throw msgpack::type_error();
  return {k.via.str.ptr, k.via.str.size};
}

template <>
struct pack<bench::Message> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::Message& m) const {
    pk.pack_map(8);
    pk.pack("f_bool"); pk.pack(m.f_bool);
    pk.pack("f_int32"); pk.pack(m.f_int32);
    pk.pack("f_int64"); pk.pack(m.f_int64);
    pk.pack("f_float64"); pk.pack(m.f_float64);
    pk.pack("f_string"); pk.pack(m.f_string);
    pk.pack("f_bool_2"); pk.pack(m.f_bool_2);
    pk.pack("f_int32_2"); pk.pack(m.f_int32_2);
    pk.pack("f_string_2"); pk.pack(m.f_string_2);
    return pk;
  }
};
template <>
struct convert<bench::Message> {
  const msgpack::object& operator()(const msgpack::object& o, bench::Message& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "f_bool") kv.val.convert(m.f_bool);
      else if (k == "f_int32") kv.val.convert(m.f_int32);
      else if (k == "f_int64") kv.val.convert(m.f_int64);
      else if (k == "f_float64") kv.val.convert(m.f_float64);
      else if (k == "f_string") kv.val.convert(m.f_string);
      else if (k == "f_bool_2") kv.val.convert(m.f_bool_2);
      else if (k == "f_int32_2") kv.val.convert(m.f_int32_2);
      else if (k == "f_string_2") kv.val.convert(m.f_string_2);
    }
    return o;
  }
};

template <>
struct pack<bench::DocumentMeta> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::DocumentMeta& m) const {
    pk.pack_map(2);
    pk.pack("region"); pk.pack(m.region);
    pk.pack("version"); pk.pack(m.version);
    return pk;
  }
};
template <>
struct convert<bench::DocumentMeta> {
  const msgpack::object& operator()(const msgpack::object& o, bench::DocumentMeta& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "region") kv.val.convert(m.region);
      else if (k == "version") kv.val.convert(m.version);
    }
    return o;
  }
};

template <>
struct pack<bench::DocumentItem> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::DocumentItem& m) const {
    pk.pack_map(3);
    pk.pack("sku"); pk.pack(m.sku);
    pk.pack("qty"); pk.pack(m.qty);
    pk.pack("price_minor"); pk.pack(m.price_minor);
    return pk;
  }
};
template <>
struct convert<bench::DocumentItem> {
  const msgpack::object& operator()(const msgpack::object& o, bench::DocumentItem& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "sku") kv.val.convert(m.sku);
      else if (k == "qty") kv.val.convert(m.qty);
      else if (k == "price_minor") kv.val.convert(m.price_minor);
    }
    return o;
  }
};

template <>
struct pack<bench::Document> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::Document& m) const {
    pk.pack_map(4);
    pk.pack("id"); pk.pack(m.id);
    pk.pack("status"); pk.pack(m.status);
    pk.pack("meta"); pk.pack(m.meta);
    pk.pack("items"); pk.pack(m.items);
    return pk;
  }
};
template <>
struct convert<bench::Document> {
  const msgpack::object& operator()(const msgpack::object& o, bench::Document& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "id") kv.val.convert(m.id);
      else if (k == "status") kv.val.convert(m.status);
      else if (k == "meta") kv.val.convert(m.meta);
      else if (k == "items") kv.val.convert(m.items);
    }
    return o;
  }
};

template <>
struct pack<bench::Telemetry> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::Telemetry& m) const {
    pk.pack_map(4);
    pk.pack("source"); pk.pack(m.source);
    pk.pack("ts"); pk.pack(m.ts);
    pk.pack("tags"); pk.pack(m.tags);
    pk.pack("values"); pk.pack(m.values);
    return pk;
  }
};
template <>
struct convert<bench::Telemetry> {
  const msgpack::object& operator()(const msgpack::object& o, bench::Telemetry& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "source") kv.val.convert(m.source);
      else if (k == "ts") kv.val.convert(m.ts);
      else if (k == "tags") kv.val.convert(m.tags);
      else if (k == "values") kv.val.convert(m.values);
    }
    return o;
  }
};

template <>
struct pack<bench::Strings> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::Strings& m) const {
    pk.pack_map(1);
    pk.pack("items"); pk.pack(m.items);
    return pk;
  }
};
template <>
struct convert<bench::Strings> {
  const msgpack::object& operator()(const msgpack::object& o, bench::Strings& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      if (mp_key(kv.key) == "items") kv.val.convert(m.items);
    }
    return o;
  }
};

template <>
struct pack<bench::EventAttr> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::EventAttr& m) const {
    pk.pack_map(2);
    pk.pack("key"); pk.pack(m.key);
    pk.pack("value"); pk.pack(m.value);
    return pk;
  }
};
template <>
struct convert<bench::EventAttr> {
  const msgpack::object& operator()(const msgpack::object& o, bench::EventAttr& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "key") kv.val.convert(m.key);
      else if (k == "value") kv.val.convert(m.value);
    }
    return o;
  }
};

template <>
struct pack<bench::Event> {
  template <typename Stream>
  msgpack::packer<Stream>& operator()(msgpack::packer<Stream>& pk, const bench::Event& m) const {
    pk.pack_map(5);
    pk.pack("event_id"); pk.pack(m.event_id);
    pk.pack("event_type"); pk.pack(m.event_type);
    pk.pack("occurred_at"); pk.pack(m.occurred_at);
    pk.pack("producer"); pk.pack(m.producer);
    pk.pack("attrs"); pk.pack(m.attrs);
    return pk;
  }
};
template <>
struct convert<bench::Event> {
  const msgpack::object& operator()(const msgpack::object& o, bench::Event& m) const {
    if (o.type != msgpack::type::MAP) throw msgpack::type_error();
    for (uint32_t i = 0; i < o.via.map.size; ++i) {
      const msgpack::object_kv& kv = o.via.map.ptr[i];
      const auto k = mp_key(kv.key);
      if (k == "event_id") kv.val.convert(m.event_id);
      else if (k == "event_type") kv.val.convert(m.event_type);
      else if (k == "occurred_at") kv.val.convert(m.occurred_at);
      else if (k == "producer") kv.val.convert(m.producer);
      else if (k == "attrs") kv.val.convert(m.attrs);
    }
    return o;
  }
};

}  // namespace adaptor
}  // MSGPACK_API_VERSION_NAMESPACE
}  // namespace msgpack

namespace bench {
namespace {

class MsgpackSer final : public ISerializer {
 public:
  const char* name() const override { return "msgpack"; }
  const char* version() const override { return "msgpack-cxx"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    msgpack::sbuffer sbuf;
    msgpack::packer<msgpack::sbuffer> pk(&sbuf);
    pack_all(pk);
    return {sbuf.data(), sbuf.data() + sbuf.size()};
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    // Reference func: keep STR/BIN as references into `data` (alive for the
    // whole call) instead of copying into the zone; convert() then copies
    // once, straight into the domain structs. The stream path needs no
    // equivalent — msgpack::unpacker's default_reference_func already
    // references its refcounted internal buffer.
    auto oh = msgpack::unpack(reinterpret_cast<const char*>(data.data()), data.size(),
                              [](msgpack::type::object_type, std::size_t, void*) { return true; });
    return obj_to_value(oh.get());
  }
  // Docs: packer<Stream> where Stream::write(const char*, size_t); unpacker for stream feed.
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    MsgpackVecStream stream{out};
    msgpack::packer<MsgpackVecStream> pk(stream);
    pack_all(pk);
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    msgpack::unpacker unp;
    unp.reserve_buffer(data.size());
    std::memcpy(unp.buffer(), data.data(), data.size());
    unp.buffer_consumed(data.size());
    msgpack::object_handle oh;
    if (!unp.next(oh)) throw std::runtime_error("msgpack unpacker: no object");
    return obj_to_value(oh.get());
  }

 private:
  template <typename Packer>
  void pack_all(Packer& pk) {
    // Adaptor pack; std::vector<T> goes through the library's vector adaptor.
    std::visit([&](const auto& v) { pk.pack(v); }, value_);
  }
  // Direct object → struct conversion via the convert<> adaptors above.
  Value obj_to_value(const msgpack::object& o) const {
    if (n_ > 1) {
      if (type_id_ == "message") return o.as<std::vector<Message>>();
      if (type_id_ == "document") return o.as<std::vector<Document>>();
      if (type_id_ == "telemetry") return o.as<std::vector<Telemetry>>();
      if (type_id_ == "strings") return o.as<std::vector<Strings>>();
      return o.as<std::vector<Event>>();
    }
    if (type_id_ == "message") return o.as<Message>();
    if (type_id_ == "document") return o.as<Document>();
    if (type_id_ == "telemetry") return o.as<Telemetry>();
    if (type_id_ == "strings") return o.as<Strings>();
    return o.as<Event>();
  }
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

// Hand-packed length-prefixed baseline (independent of third-party codecs).
class CustomBinary final : public ISerializer {
 public:
  const char* name() const override { return "custom_binary"; }
  const char* version() const override { return "harness"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "struct"; }
  void prepare(const Fixture& fx) override { type_id_ = fx.type_id; n_ = fx.instance_count; value_ = fx.value; }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::vector<uint8_t> out;
    auto w_u32 = [&](uint32_t v) {
      out.push_back(v & 0xff); out.push_back((v >> 8) & 0xff);
      out.push_back((v >> 16) & 0xff); out.push_back((v >> 24) & 0xff);
    };
    auto w_u64 = [&](uint64_t v) { for (int i = 0; i < 8; ++i) out.push_back((v >> (8 * i)) & 0xff); };
    auto w_f64 = [&](double d) { uint64_t u; std::memcpy(&u, &d, 8); w_u64(u); };
    auto w_str = [&](const std::string& s) { w_u32((uint32_t)s.size()); out.insert(out.end(), s.begin(), s.end()); };
    auto w_msg = [&](const Message& m) {
      out.push_back(m.f_bool ? 1 : 0); w_u32((uint32_t)m.f_int32); w_u64((uint64_t)m.f_int64);
      w_f64(m.f_float64); w_str(m.f_string); out.push_back(m.f_bool_2 ? 1 : 0);
      w_u32((uint32_t)m.f_int32_2); w_str(m.f_string_2);
    };
    auto w_doc = [&](const Document& d) {
      w_str(d.id); w_u32((uint32_t)d.status); w_str(d.meta.region); w_u32((uint32_t)d.meta.version);
      w_u32((uint32_t)d.items.size());
      for (const auto& it : d.items) { w_str(it.sku); w_u32((uint32_t)it.qty); w_u64((uint64_t)it.price_minor); }
    };
    auto w_tel = [&](const Telemetry& t) {
      w_str(t.source); w_u64((uint64_t)t.ts); w_u32((uint32_t)t.tags.size());
      for (const auto& tg : t.tags) w_str(tg);
      w_u32((uint32_t)t.values.size()); for (double v : t.values) w_f64(v);
    };
    auto w_str_s = [&](const Strings& s) {
      w_u32((uint32_t)s.items.size()); for (const auto& it : s.items) w_str(it);
    };
    auto w_ev = [&](const Event& e) {
      w_str(e.event_id); w_str(e.event_type); w_u64((uint64_t)e.occurred_at); w_str(e.producer);
      w_u32((uint32_t)e.attrs.size());
      for (const auto& a : e.attrs) { w_str(a.key); w_str(a.value); }
    };
    std::visit([&](const auto& v) {
      using T = std::decay_t<decltype(v)>;
      if constexpr (std::is_same_v<T, Message>) w_msg(v);
      else if constexpr (std::is_same_v<T, Document>) w_doc(v);
      else if constexpr (std::is_same_v<T, Telemetry>) w_tel(v);
      else if constexpr (std::is_same_v<T, Strings>) w_str_s(v);
      else if constexpr (std::is_same_v<T, Event>) w_ev(v);
      else if constexpr (std::is_same_v<T, std::vector<Message>>) {
        w_u32((uint32_t)v.size()); for (const auto& el : v) w_msg(el);
      } else if constexpr (std::is_same_v<T, std::vector<Document>>) {
        w_u32((uint32_t)v.size()); for (const auto& el : v) w_doc(el);
      } else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) {
        w_u32((uint32_t)v.size()); for (const auto& el : v) w_tel(el);
      } else if constexpr (std::is_same_v<T, std::vector<Strings>>) {
        w_u32((uint32_t)v.size()); for (const auto& el : v) w_str_s(el);
      } else if constexpr (std::is_same_v<T, std::vector<Event>>) {
        w_u32((uint32_t)v.size()); for (const auto& el : v) w_ev(el);
      }
    }, value_);
    return out;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    size_t off = 0;
    auto need = [&](size_t n) { if (off + n > data.size()) throw std::runtime_error("custom_binary trunc"); };
    auto r_u32 = [&]() {
      need(4); uint32_t v = data[off] | (data[off+1]<<8) | (data[off+2]<<16) | (data[off+3]<<24); off += 4; return v;
    };
    auto r_u64 = [&]() {
      need(8); uint64_t v = 0; for (int i = 0; i < 8; ++i) v |= (uint64_t)data[off+i] << (8*i); off += 8; return v;
    };
    auto r_f64 = [&]() { uint64_t u = r_u64(); double d; std::memcpy(&d, &u, 8); return d; };
    auto r_str = [&]() {
      uint32_t n = r_u32(); need(n); std::string s((const char*)data.data()+off, n); off += n; return s;
    };
    auto r_msg = [&]() {
      Message m; need(1); m.f_bool = data[off++] != 0; m.f_int32 = (int32_t)r_u32(); m.f_int64 = (int64_t)r_u64();
      m.f_float64 = r_f64(); m.f_string = r_str(); need(1); m.f_bool_2 = data[off++] != 0;
      m.f_int32_2 = (int32_t)r_u32(); m.f_string_2 = r_str(); return m;
    };
    auto r_doc = [&]() {
      Document d; d.id = r_str(); d.status = (int32_t)r_u32(); d.meta.region = r_str(); d.meta.version = (int32_t)r_u32();
      uint32_t ni = r_u32(); d.items.resize(ni);
      for (uint32_t i = 0; i < ni; ++i) {
        d.items[i].sku = r_str(); d.items[i].qty = (int32_t)r_u32(); d.items[i].price_minor = (int64_t)r_u64();
      }
      return d;
    };
    auto r_tel = [&]() {
      Telemetry t; t.source = r_str(); t.ts = (int64_t)r_u64();
      uint32_t nt = r_u32(); t.tags.resize(nt); for (uint32_t i = 0; i < nt; ++i) t.tags[i] = r_str();
      uint32_t nv = r_u32(); t.values.resize(nv); for (uint32_t i = 0; i < nv; ++i) t.values[i] = r_f64();
      return t;
    };
    auto r_strings = [&]() {
      Strings s; uint32_t n = r_u32(); s.items.resize(n); for (uint32_t i = 0; i < n; ++i) s.items[i] = r_str(); return s;
    };
    auto r_ev = [&]() {
      Event e; e.event_id = r_str(); e.event_type = r_str(); e.occurred_at = (int64_t)r_u64(); e.producer = r_str();
      uint32_t na = r_u32(); e.attrs.resize(na);
      for (uint32_t i = 0; i < na; ++i) { e.attrs[i].key = r_str(); e.attrs[i].value = r_str(); }
      return e;
    };
    if (n_ > 1) {
      uint32_t count = r_u32();
      if (type_id_ == "message") { std::vector<Message> v(count); for (uint32_t i=0;i<count;++i) v[i]=r_msg(); return v; }
      if (type_id_ == "document") { std::vector<Document> v(count); for (uint32_t i=0;i<count;++i) v[i]=r_doc(); return v; }
      if (type_id_ == "telemetry") { std::vector<Telemetry> v(count); for (uint32_t i=0;i<count;++i) v[i]=r_tel(); return v; }
      if (type_id_ == "strings") { std::vector<Strings> v(count); for (uint32_t i=0;i<count;++i) v[i]=r_strings(); return v; }
      std::vector<Event> v(count); for (uint32_t i=0;i<count;++i) v[i]=r_ev(); return v;
    }
    if (type_id_ == "message") return r_msg();
    if (type_id_ == "document") return r_doc();
    if (type_id_ == "telemetry") return r_tel();
    if (type_id_ == "strings") return r_strings();
    return r_ev();
  }
 private:
  std::string type_id_; int n_ = 1; Value value_;
};

}  // namespace

SerializerPtr make_msgpack() { return std::make_unique<MsgpackSer>(); }
SerializerPtr make_custom_binary() { return std::make_unique<CustomBinary>(); }

}  // namespace bench
