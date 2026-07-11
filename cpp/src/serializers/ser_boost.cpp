#include "bench/serializer.hpp"

#if defined(HAS_BOOST_SERIALIZATION) && HAS_BOOST_SERIALIZATION
#include <boost/archive/binary_iarchive.hpp>
#include <boost/archive/binary_oarchive.hpp>
#include <boost/serialization/string.hpp>
#include <boost/serialization/vector.hpp>

#include "bench/stream_util.hpp"

#include <sstream>

// Boost.Serialization — classic C++ native archive (medium value / historical staple).
// Optimal: binary_oarchive / binary_iarchive on ostream/istream; free serialize in type ns.
// Bytes: stringstream; stream: VecOutStream / VecInStream.
// Linked only when libboost_serialization is found (HAS_BOOST_SERIALIZATION).

namespace boost {
namespace serialization {

template <class Archive>
void serialize(Archive& ar, bench::Message& m, const unsigned int) {
  ar & m.f_bool & m.f_int32 & m.f_int64 & m.f_float64 & m.f_string & m.f_bool_2 & m.f_int32_2 &
      m.f_string_2;
}
template <class Archive>
void serialize(Archive& ar, bench::DocumentMeta& m, const unsigned int) {
  ar & m.region & m.version;
}
template <class Archive>
void serialize(Archive& ar, bench::DocumentItem& m, const unsigned int) {
  ar & m.sku & m.qty & m.price_minor;
}
template <class Archive>
void serialize(Archive& ar, bench::Document& m, const unsigned int) {
  ar & m.id & m.status & m.meta & m.items;
}
template <class Archive>
void serialize(Archive& ar, bench::Telemetry& m, const unsigned int) {
  ar & m.source & m.ts & m.tags & m.values;
}
template <class Archive>
void serialize(Archive& ar, bench::Strings& m, const unsigned int) {
  ar & m.items;
}
template <class Archive>
void serialize(Archive& ar, bench::EventAttr& m, const unsigned int) {
  ar & m.key & m.value;
}
template <class Archive>
void serialize(Archive& ar, bench::Event& m, const unsigned int) {
  ar & m.event_id & m.event_type & m.occurred_at & m.producer & m.attrs;
}

}  // namespace serialization
}  // namespace boost

namespace bench {
namespace {

class BoostSer final : public ISerializer {
 public:
  const char* name() const override { return "boost_serialization"; }
  const char* version() const override { return BOOST_LIB_VERSION; }
  const char* stream_mode() const override { return "native"; }
  const char* native_kind() const override { return "struct"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::ostringstream oss(std::ios::binary);
    {
      boost::archive::binary_oarchive oa(oss, boost::archive::no_header);
      std::visit([&](auto& v) { oa << v; }, value_);
    }
    auto s = oss.str();
    return {s.begin(), s.end()};
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    std::string s(data.begin(), data.end());
    std::istringstream iss(s, std::ios::binary);
    return load_from(iss);
  }

  size_t serialize_stream(const Fixture&, std::vector<uint8_t>& out) override {
    out.clear();
    VecOutStream os(out);
    {
      boost::archive::binary_oarchive oa(os, boost::archive::no_header);
      std::visit([&](auto& v) { oa << v; }, value_);
    }
    return out.size();
  }

  Value deserialize_stream(const std::vector<uint8_t>& data) override {
    VecInStream is(data);
    return load_from(is);
  }

 private:
  Value load_from(std::istream& is) {
    boost::archive::binary_iarchive ia(is, boost::archive::no_header);
    if (type_id_ == "message") {
      if (n_ > 1) {
        std::vector<Message> v;
        ia >> v;
        return v;
      }
      Message m;
      ia >> m;
      return m;
    }
    if (type_id_ == "document") {
      if (n_ > 1) {
        std::vector<Document> v;
        ia >> v;
        return v;
      }
      Document m;
      ia >> m;
      return m;
    }
    if (type_id_ == "telemetry") {
      if (n_ > 1) {
        std::vector<Telemetry> v;
        ia >> v;
        return v;
      }
      Telemetry m;
      ia >> m;
      return m;
    }
    if (type_id_ == "strings") {
      if (n_ > 1) {
        std::vector<Strings> v;
        ia >> v;
        return v;
      }
      Strings m;
      ia >> m;
      return m;
    }
    if (n_ > 1) {
      std::vector<Event> v;
      ia >> v;
      return v;
    }
    Event m;
    ia >> m;
    return m;
  }

  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

SerializerPtr make_boost_serialization() { return std::make_unique<BoostSer>(); }

}  // namespace bench

#else
namespace bench {
SerializerPtr make_boost_serialization() { return nullptr; }
}
#endif
