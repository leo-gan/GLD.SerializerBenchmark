#include "bench/types.hpp"
#include "bench/fixture.hpp"

#include <stdexcept>

namespace bench {

Message make_message(Rng& r) {
  return Message{r.next_bool(),
                 r.next_int(0, 1'000'000),
                 static_cast<int64_t>(r.next_int(0, 1'000'000)),
                 r.next_f64() * 1000.0,
                 r.word(3, 16),
                 r.next_bool(),
                 r.next_int(0, 1'000'000),
                 r.word(3, 16)};
}

Document make_document(Rng& r, int children) {
  Document d;
  d.id = r.word(8, 12);
  d.status = r.next_int(0, 5);
  d.meta = DocumentMeta{r.word(2, 4), r.next_int(1, 10)};
  d.items.reserve(static_cast<size_t>(children));
  for (int i = 0; i < children; ++i) {
    d.items.push_back(DocumentItem{r.word(3, 12), r.next_int(1, 100),
                                   static_cast<int64_t>(r.next_int(0, 100'000))});
  }
  return d;
}

Telemetry make_telemetry(Rng& r, int points, int tag_count) {
  Telemetry t;
  t.source = r.word(3, 10);
  t.ts = kBaseTsMs + r.next_int(0, 86'400'000);
  t.tags.reserve(static_cast<size_t>(tag_count));
  for (int i = 0; i < tag_count; ++i) t.tags.push_back(r.word(3, 10));
  t.values.reserve(static_cast<size_t>(points));
  for (int i = 0; i < points; ++i) t.values.push_back(r.next_f64() * 100.0);
  return t;
}

Strings make_strings(Rng& r, int count) {
  Strings s;
  s.items.reserve(static_cast<size_t>(count));
  for (int i = 0; i < count; ++i) s.items.push_back(r.word(3, 16));
  return s;
}

Event make_event(Rng& r, int attr_count) {
  Event e;
  e.event_id = r.word(8, 12);
  e.event_type = r.word(3, 12);
  e.occurred_at = kBaseTsMs + r.next_int(0, 86'400'000);
  e.producer = r.word(3, 12);
  e.attrs.reserve(static_cast<size_t>(attr_count));
  for (int i = 0; i < attr_count; ++i) {
    e.attrs.push_back(EventAttr{r.word(3, 12), r.word(3, 12)});
  }
  return e;
}

static Value make_one(const std::string& type_id, const TypeConfig& cfg, uint64_t seed, int idx) {
  Rng r(mix_seed(seed, type_id, idx));
  if (type_id == "message") return make_message(r);
  if (type_id == "document") return make_document(r, cfg.children);
  if (type_id == "telemetry") return make_telemetry(r, cfg.points, cfg.tag_count);
  if (type_id == "strings") return make_strings(r, cfg.count);
  if (type_id == "event") return make_event(r, cfg.attr_count);
  throw std::runtime_error("unknown type_id: " + type_id);
}

Fixture make_fixture(const std::string& type_id, const TypeConfig& cfg, uint64_t seed,
                     int instance_count, const std::string& type_config_hash) {
  Fixture fx;
  fx.type_id = type_id;
  fx.instance_count = instance_count < 1 ? 1 : instance_count;
  fx.type_config_hash = type_config_hash;
  if (fx.instance_count == 1) {
    fx.value = make_one(type_id, cfg, seed, 0);
    return fx;
  }
  if (type_id == "message") {
    std::vector<Message> v;
    v.reserve(static_cast<size_t>(fx.instance_count));
    for (int i = 0; i < fx.instance_count; ++i)
      v.push_back(std::get<Message>(make_one(type_id, cfg, seed, i)));
    fx.value = std::move(v);
  } else if (type_id == "document") {
    std::vector<Document> v;
    v.reserve(static_cast<size_t>(fx.instance_count));
    for (int i = 0; i < fx.instance_count; ++i)
      v.push_back(std::get<Document>(make_one(type_id, cfg, seed, i)));
    fx.value = std::move(v);
  } else if (type_id == "telemetry") {
    std::vector<Telemetry> v;
    v.reserve(static_cast<size_t>(fx.instance_count));
    for (int i = 0; i < fx.instance_count; ++i)
      v.push_back(std::get<Telemetry>(make_one(type_id, cfg, seed, i)));
    fx.value = std::move(v);
  } else if (type_id == "strings") {
    std::vector<Strings> v;
    v.reserve(static_cast<size_t>(fx.instance_count));
    for (int i = 0; i < fx.instance_count; ++i)
      v.push_back(std::get<Strings>(make_one(type_id, cfg, seed, i)));
    fx.value = std::move(v);
  } else if (type_id == "event") {
    std::vector<Event> v;
    v.reserve(static_cast<size_t>(fx.instance_count));
    for (int i = 0; i < fx.instance_count; ++i)
      v.push_back(std::get<Event>(make_one(type_id, cfg, seed, i)));
    fx.value = std::move(v);
  } else {
    throw std::runtime_error("unknown type_id: " + type_id);
  }
  return fx;
}

bool fidelity(const Value& a, const Value& b) {
  if (a.index() != b.index()) return false;
  return std::visit(
      [&](const auto& left) -> bool {
        using T = std::decay_t<decltype(left)>;
        return left == std::get<T>(b);
      },
      a);
}

}  // namespace bench
