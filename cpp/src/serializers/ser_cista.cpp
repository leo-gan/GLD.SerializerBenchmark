#include "bench/serializer.hpp"

#include <cista/serialization.h>
#include <cista/containers.h>
#include <cista/containers/string.h>
#include <cista/containers/vector.h>

// Cista++ — high-performance zero-copy-oriented C++ serialization (benchmark staple).
// Optimal: cista::serialize / cista::deserialize on offset-based graphs.
// Domain → cista model in prepare (untimed); timed path is codec only.

namespace bench {
namespace {

namespace data = cista::offset;

struct CMsg {
  bool f_bool{false};
  int32_t f_int32{0};
  int64_t f_int64{0};
  double f_float64{0};
  data::string f_string;
  bool f_bool_2{false};
  int32_t f_int32_2{0};
  data::string f_string_2;
};

struct CDocItem {
  data::string sku;
  int32_t qty{0};
  int64_t price_minor{0};
};

struct CDoc {
  data::string id;
  int32_t status{0};
  data::string region;
  int32_t version{0};
  data::vector<CDocItem> items;
};

struct CTel {
  data::string source;
  int64_t ts{0};
  data::vector<data::string> tags;
  data::vector<double> values;
};

struct CStr {
  data::vector<data::string> items;
};

struct CAttr {
  data::string key;
  data::string value;
};

struct CEv {
  data::string event_id;
  data::string event_type;
  int64_t occurred_at{0};
  data::string producer;
  data::vector<CAttr> attrs;
};

static data::string to_cs(const std::string& s) { return data::string{s}; }
static std::string from_cs(const data::string& s) { return std::string{s}; }

static CMsg to_cmsg(const Message& m) {
  return CMsg{m.f_bool, m.f_int32, m.f_int64, m.f_float64, to_cs(m.f_string), m.f_bool_2,
              m.f_int32_2, to_cs(m.f_string_2)};
}
static Message from_cmsg(const CMsg& m) {
  return Message{m.f_bool, m.f_int32, m.f_int64, m.f_float64, from_cs(m.f_string), m.f_bool_2,
                 m.f_int32_2, from_cs(m.f_string_2)};
}

static CDoc to_cdoc(const Document& d) {
  CDoc c;
  c.id = to_cs(d.id);
  c.status = d.status;
  c.region = to_cs(d.meta.region);
  c.version = d.meta.version;
  for (const auto& it : d.items)
    c.items.push_back(CDocItem{to_cs(it.sku), it.qty, it.price_minor});
  return c;
}
static Document from_cdoc(const CDoc& c) {
  Document d;
  d.id = from_cs(c.id);
  d.status = c.status;
  d.meta.region = from_cs(c.region);
  d.meta.version = c.version;
  for (const auto& it : c.items)
    d.items.push_back(DocumentItem{from_cs(it.sku), it.qty, it.price_minor});
  return d;
}

static CTel to_ctel(const Telemetry& t) {
  CTel c;
  c.source = to_cs(t.source);
  c.ts = t.ts;
  for (const auto& tg : t.tags) c.tags.push_back(to_cs(tg));
  for (double v : t.values) c.values.push_back(v);
  return c;
}
static Telemetry from_ctel(const CTel& c) {
  Telemetry t;
  t.source = from_cs(c.source);
  t.ts = c.ts;
  for (const auto& tg : c.tags) t.tags.push_back(from_cs(tg));
  for (double v : c.values) t.values.push_back(v);
  return t;
}

static CStr to_cstr(const Strings& s) {
  CStr c;
  for (const auto& it : s.items) c.items.push_back(to_cs(it));
  return c;
}
static Strings from_cstr(const CStr& c) {
  Strings s;
  for (const auto& it : c.items) s.items.push_back(from_cs(it));
  return s;
}

static CEv to_cev(const Event& e) {
  CEv c;
  c.event_id = to_cs(e.event_id);
  c.event_type = to_cs(e.event_type);
  c.occurred_at = e.occurred_at;
  c.producer = to_cs(e.producer);
  for (const auto& a : e.attrs) c.attrs.push_back(CAttr{to_cs(a.key), to_cs(a.value)});
  return c;
}
static Event from_cev(const CEv& c) {
  Event e;
  e.event_id = from_cs(c.event_id);
  e.event_type = from_cs(c.event_type);
  e.occurred_at = c.occurred_at;
  e.producer = from_cs(c.producer);
  for (const auto& a : c.attrs) e.attrs.push_back(EventAttr{from_cs(a.key), from_cs(a.value)});
  return e;
}

// Hold prepared bytes of cista graph via type-erased buffer of serialized domain→cista.
// Simpler: store Value and convert each time inside serialize is wrong for prepare contract.
// Store serialized-ready cista objects as byte copies of CMsg etc. in variant of vectors.

using CValue = std::variant<CMsg, CDoc, CTel, CStr, CEv, data::vector<CMsg>, data::vector<CDoc>,
                            data::vector<CTel>, data::vector<CStr>, data::vector<CEv>>;

class CistaSer final : public ISerializer {
 public:
  const char* name() const override { return "cista"; }
  const char* version() const override { return "0.15"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "archive"; }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    cval_ = std::visit(
        [](const auto& v) -> CValue {
          using T = std::decay_t<decltype(v)>;
          if constexpr (std::is_same_v<T, Message>) return to_cmsg(v);
          else if constexpr (std::is_same_v<T, Document>) return to_cdoc(v);
          else if constexpr (std::is_same_v<T, Telemetry>) return to_ctel(v);
          else if constexpr (std::is_same_v<T, Strings>) return to_cstr(v);
          else if constexpr (std::is_same_v<T, Event>) return to_cev(v);
          else if constexpr (std::is_same_v<T, std::vector<Message>>) {
            data::vector<CMsg> o;
            for (const auto& el : v) o.push_back(to_cmsg(el));
            return o;
          } else if constexpr (std::is_same_v<T, std::vector<Document>>) {
            data::vector<CDoc> o;
            for (const auto& el : v) o.push_back(to_cdoc(el));
            return o;
          } else if constexpr (std::is_same_v<T, std::vector<Telemetry>>) {
            data::vector<CTel> o;
            for (const auto& el : v) o.push_back(to_ctel(el));
            return o;
          } else if constexpr (std::is_same_v<T, std::vector<Strings>>) {
            data::vector<CStr> o;
            for (const auto& el : v) o.push_back(to_cstr(el));
            return o;
          } else if constexpr (std::is_same_v<T, std::vector<Event>>) {
            data::vector<CEv> o;
            for (const auto& el : v) o.push_back(to_cev(el));
            return o;
          }
          return CMsg{};
        },
        fx.value);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    return std::visit(
        [](const auto& v) {
          auto buf = cista::serialize(v);
          return std::vector<uint8_t>(buf.begin(), buf.end());
        },
        cval_);
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    auto run = [&](auto* tag) -> Value {
      using T = std::remove_pointer_t<decltype(tag)>;
      if (n_ > 1) {
        using VT = data::vector<T>;
        auto* p = cista::deserialize<VT>(data);
        if (!p) throw std::runtime_error("cista deser failed");
        if constexpr (std::is_same_v<T, CMsg>) {
          std::vector<Message> out;
          for (const auto& el : *p) out.push_back(from_cmsg(el));
          return out;
        } else if constexpr (std::is_same_v<T, CDoc>) {
          std::vector<Document> out;
          for (const auto& el : *p) out.push_back(from_cdoc(el));
          return out;
        } else if constexpr (std::is_same_v<T, CTel>) {
          std::vector<Telemetry> out;
          for (const auto& el : *p) out.push_back(from_ctel(el));
          return out;
        } else if constexpr (std::is_same_v<T, CStr>) {
          std::vector<Strings> out;
          for (const auto& el : *p) out.push_back(from_cstr(el));
          return out;
        } else {
          std::vector<Event> out;
          for (const auto& el : *p) out.push_back(from_cev(el));
          return out;
        }
      }
      auto* p = cista::deserialize<T>(data);
      if (!p) throw std::runtime_error("cista deser failed");
      if constexpr (std::is_same_v<T, CMsg>) return from_cmsg(*p);
      else if constexpr (std::is_same_v<T, CDoc>) return from_cdoc(*p);
      else if constexpr (std::is_same_v<T, CTel>) return from_ctel(*p);
      else if constexpr (std::is_same_v<T, CStr>) return from_cstr(*p);
      else return from_cev(*p);
    };
    if (type_id_ == "message") return run(static_cast<CMsg*>(nullptr));
    if (type_id_ == "document") return run(static_cast<CDoc*>(nullptr));
    if (type_id_ == "telemetry") return run(static_cast<CTel*>(nullptr));
    if (type_id_ == "strings") return run(static_cast<CStr*>(nullptr));
    return run(static_cast<CEv*>(nullptr));
  }

 private:
  std::string type_id_;
  int n_ = 1;
  CValue cval_;
};

}  // namespace

SerializerPtr make_cista() { return std::make_unique<CistaSer>(); }

}  // namespace bench
