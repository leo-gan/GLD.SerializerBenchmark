#include "bench/serializer.hpp"
#include "bench/nlohmann_conv.hpp"
#include "bench/stream_util.hpp"

#include <msgpack.hpp>
#include <jsoncons/json.hpp>
#include <jsoncons_ext/cbor/cbor.hpp>
#include <jsoncons_ext/bson/bson.hpp>
#include <jsoncons_ext/msgpack/msgpack.hpp>

#include <cstring>
#include <type_traits>

namespace bench {
namespace {

template <typename Stream>
void pack_value(Stream& pk, const Message& m) {
  pk.pack_map(8);
  pk.pack("f_bool"); pk.pack(m.f_bool);
  pk.pack("f_int32"); pk.pack(m.f_int32);
  pk.pack("f_int64"); pk.pack(m.f_int64);
  pk.pack("f_float64"); pk.pack(m.f_float64);
  pk.pack("f_string"); pk.pack(m.f_string);
  pk.pack("f_bool_2"); pk.pack(m.f_bool_2);
  pk.pack("f_int32_2"); pk.pack(m.f_int32_2);
  pk.pack("f_string_2"); pk.pack(m.f_string_2);
}
template <typename Stream>
void pack_value(Stream& pk, const DocumentMeta& m) {
  pk.pack_map(2); pk.pack("region"); pk.pack(m.region); pk.pack("version"); pk.pack(m.version);
}
template <typename Stream>
void pack_value(Stream& pk, const DocumentItem& m) {
  pk.pack_map(3); pk.pack("sku"); pk.pack(m.sku); pk.pack("qty"); pk.pack(m.qty);
  pk.pack("price_minor"); pk.pack(m.price_minor);
}
template <typename Stream>
void pack_value(Stream& pk, const Document& m) {
  pk.pack_map(4); pk.pack("id"); pk.pack(m.id); pk.pack("status"); pk.pack(m.status);
  pk.pack("meta"); pack_value(pk, m.meta);
  pk.pack("items"); pk.pack_array(m.items.size());
  for (const auto& it : m.items) pack_value(pk, it);
}
template <typename Stream>
void pack_value(Stream& pk, const Telemetry& m) {
  pk.pack_map(4); pk.pack("source"); pk.pack(m.source); pk.pack("ts"); pk.pack(m.ts);
  pk.pack("tags"); pk.pack(m.tags); pk.pack("values"); pk.pack(m.values);
}
template <typename Stream>
void pack_value(Stream& pk, const Strings& m) {
  pk.pack_map(1); pk.pack("items"); pk.pack(m.items);
}
template <typename Stream>
void pack_value(Stream& pk, const EventAttr& m) {
  pk.pack_map(2); pk.pack("key"); pk.pack(m.key); pk.pack("value"); pk.pack(m.value);
}
template <typename Stream>
void pack_value(Stream& pk, const Event& m) {
  pk.pack_map(5); pk.pack("event_id"); pk.pack(m.event_id); pk.pack("event_type"); pk.pack(m.event_type);
  pk.pack("occurred_at"); pk.pack(m.occurred_at); pk.pack("producer"); pk.pack(m.producer);
  pk.pack("attrs"); pk.pack_array(m.attrs.size());
  for (const auto& a : m.attrs) pack_value(pk, a);
}

static nlohmann::json mp_to_json(const msgpack::object& o) {
  switch (o.type) {
    case msgpack::type::NIL: return nullptr;
    case msgpack::type::BOOLEAN: return o.via.boolean;
    case msgpack::type::POSITIVE_INTEGER: return o.via.u64;
    case msgpack::type::NEGATIVE_INTEGER: return o.via.i64;
    case msgpack::type::FLOAT32:
    case msgpack::type::FLOAT64: return o.via.f64;
    case msgpack::type::STR: return std::string(o.via.str.ptr, o.via.str.size);
    case msgpack::type::BIN: return std::string(o.via.bin.ptr, o.via.bin.size);
    case msgpack::type::ARRAY: {
      nlohmann::json a = nlohmann::json::array();
      for (uint32_t i = 0; i < o.via.array.size; ++i) a.push_back(mp_to_json(o.via.array.ptr[i]));
      return a;
    }
    case msgpack::type::MAP: {
      nlohmann::json m = nlohmann::json::object();
      for (uint32_t i = 0; i < o.via.map.size; ++i) {
        auto k = mp_to_json(o.via.map.ptr[i].key);
        m[k.is_string() ? k.get<std::string>() : k.dump()] = mp_to_json(o.via.map.ptr[i].val);
      }
      return m;
    }
    default: throw std::runtime_error("msgpack type unsupported");
  }
}

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
    auto oh = msgpack::unpack(reinterpret_cast<const char*>(data.data()), data.size());
    return json_to_value(mp_to_json(oh.get()), type_id_, n_);
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
    return json_to_value(mp_to_json(oh.get()), type_id_, n_);
  }

 private:
  template <typename Packer>
  void pack_all(Packer& pk) {
    std::visit(
        [&](const auto& v) {
          using T = std::decay_t<decltype(v)>;
          if constexpr (std::is_same_v<T, std::vector<Message>> || std::is_same_v<T, std::vector<Document>> ||
                        std::is_same_v<T, std::vector<Telemetry>> || std::is_same_v<T, std::vector<Strings>> ||
                        std::is_same_v<T, std::vector<Event>>) {
            pk.pack_array(v.size());
            for (const auto& el : v) pack_value(pk, el);
          } else {
            pack_value(pk, v);
          }
        },
        value_);
  }
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

class JsonconsCbor final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_cbor"; }
  const char* version() const override { return "0.177.0"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "dom"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    j_ = jsoncons::json::parse(value_to_json(fx.value).dump());
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::vector<uint8_t> buf;
    jsoncons::cbor::encode_cbor(j_, buf);
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    auto j = jsoncons::cbor::decode_cbor<jsoncons::json>(data);
    return json_to_value(nlohmann::json::parse(j.to_string()), type_id_, n_);
  }
  // Docs: encode_cbor(j, ostream) / decode_cbor(istream).
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    jsoncons::cbor::encode_cbor(j_, os);
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    auto j = jsoncons::cbor::decode_cbor<jsoncons::json>(is);
    return json_to_value(nlohmann::json::parse(j.to_string()), type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  jsoncons::json j_;
};

class JsonconsBson final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_bson"; }
  const char* version() const override { return "0.177.0"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "dom"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    wrapped_ = false;
    auto raw = jsoncons::json::parse(value_to_json(fx.value).dump());
    if (raw.is_object()) {
      j_ = std::move(raw);
    } else {
      // BSON root must be a document (object). Wrap arrays/scalars.
      j_ = jsoncons::json::object();
      j_["items"] = raw;
      wrapped_ = true;
    }
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::vector<uint8_t> buf;
    jsoncons::bson::encode_bson(j_, buf);
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    return unwrap(jsoncons::bson::decode_bson<jsoncons::json>(data));
  }
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    jsoncons::bson::encode_bson(j_, os);
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return unwrap(jsoncons::bson::decode_bson<jsoncons::json>(is));
  }

 private:
  Value unwrap(jsoncons::json j) {
    const jsoncons::json* payload = &j;
    if (wrapped_ && j.is_object() && j.contains("items")) payload = &j.at("items");
    return json_to_value(nlohmann::json::parse(payload->to_string()), type_id_, n_);
  }
  std::string type_id_;
  int n_ = 1;
  jsoncons::json j_;
  bool wrapped_ = false;
};

class JsonconsMsgpack final : public ISerializer {
 public:
  const char* name() const override { return "jsoncons_msgpack"; }
  const char* version() const override { return "0.177.0"; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "dom"; }
  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    j_ = jsoncons::json::parse(value_to_json(fx.value).dump());
  }
  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::vector<uint8_t> buf;
    jsoncons::msgpack::encode_msgpack(j_, buf);
    return buf;
  }
  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    auto j = jsoncons::msgpack::decode_msgpack<jsoncons::json>(data);
    return json_to_value(nlohmann::json::parse(j.to_string()), type_id_, n_);
  }
  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    jsoncons::msgpack::encode_msgpack(j_, os);
    return out.size();
  }
  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    auto j = jsoncons::msgpack::decode_msgpack<jsoncons::json>(is);
    return json_to_value(nlohmann::json::parse(j.to_string()), type_id_, n_);
  }

 private:
  std::string type_id_;
  int n_ = 1;
  jsoncons::json j_;
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
SerializerPtr make_jsoncons_cbor() { return std::make_unique<JsonconsCbor>(); }
SerializerPtr make_jsoncons_bson() { return std::make_unique<JsonconsBson>(); }
SerializerPtr make_jsoncons_msgpack() { return std::make_unique<JsonconsMsgpack>(); }
SerializerPtr make_custom_binary() { return std::make_unique<CustomBinary>(); }

}  // namespace bench
