// Official Google libprotobuf for C harness — Data Model v2 only.
// Schema: schemas/v2/protobuf/benchmark_v2.proto

#include "bench.h"
#include "ser_common.h"
#include "benchmark_v2.pb.h"

#include <google/protobuf/stubs/common.h>
#include <cstring>
#include <memory>
#include <string>
#include <vector>

namespace {

using google::protobuf::MessageLite;
std::string g_version;
std::unique_ptr<MessageLite> g_dst;
test_data_kind_t g_kind = TD_COUNT;

const char* pb_version_cstr() {
  if (g_version.empty()) {
    const int v = GOOGLE_PROTOBUF_VERSION;
    g_version = std::to_string(v / 1000000) + "." +
                std::to_string((v / 1000) % 1000) + "." + std::to_string(v % 1000);
  }
  return g_version.c_str();
}

std::unique_ptr<MessageLite> to_proto(const test_fixture_t* fx) {
  switch (fx->kind) {
    case TD_MESSAGE: {
      auto m = std::make_unique<benchmark::v2::Message>();
      const auto& s = fx->message;
      m->set_f_bool(s.f_bool);
      m->set_f_int32(s.f_int32);
      m->set_f_int64(s.f_int64);
      m->set_f_float64(s.f_float64);
      m->set_f_string(s.f_string);
      m->set_f_bool_2(s.f_bool_2);
      m->set_f_int32_2(s.f_int32_2);
      m->set_f_string_2(s.f_string_2);
      return m;
    }
    case TD_DOCUMENT: {
      auto d = std::make_unique<benchmark::v2::Document>();
      const auto& s = fx->document;
      d->set_id(s.id);
      d->set_status(s.status);
      d->mutable_meta()->set_region(s.meta.region);
      d->mutable_meta()->set_version(s.meta.version);
      for (int i = 0; i < s.item_count; i++) {
        auto* it = d->add_items();
        it->set_sku(s.items[i].sku);
        it->set_qty(s.items[i].qty);
        it->set_price_minor(s.items[i].price_minor);
      }
      return d;
    }
    case TD_TELEMETRY: {
      auto t = std::make_unique<benchmark::v2::Telemetry>();
      const auto& s = fx->telemetry;
      t->set_source(s.source);
      t->set_ts(s.ts);
      for (int i = 0; i < s.tag_count; i++) t->add_tags(s.tags[i]);
      for (int i = 0; i < s.value_count; i++) t->add_values(s.values[i]);
      return t;
    }
    case TD_STRINGS: {
      auto st = std::make_unique<benchmark::v2::Strings>();
      for (int i = 0; i < fx->strings.count; i++) st->add_items(fx->strings.items[i]);
      return st;
    }
    case TD_EVENT: {
      auto e = std::make_unique<benchmark::v2::Event>();
      const auto& s = fx->event;
      e->set_event_id(s.event_id);
      e->set_event_type(s.event_type);
      e->set_occurred_at(s.occurred_at);
      e->set_producer(s.producer);
      for (int i = 0; i < s.attr_count; i++) {
        auto* a = e->add_attrs();
        a->set_key(s.attrs[i].key);
        a->set_value(s.attrs[i].value);
      }
      return e;
    }
    default:
      return nullptr;
  }
}

void from_proto(test_fixture_t* out, test_data_kind_t kind, const MessageLite& msg) {
  memset(out, 0, sizeof(*out));
  out->kind = kind;
  out->name = test_data_name(kind);
  out->batch_n = 1;
  switch (kind) {
    case TD_MESSAGE: {
      const auto& m = static_cast<const benchmark::v2::Message&>(msg);
      message_t* o = &out->message;
      o->f_bool = m.f_bool();
      o->f_int32 = m.f_int32();
      o->f_int64 = m.f_int64();
      o->f_float64 = m.f_float64();
      std::snprintf(o->f_string, sizeof o->f_string, "%s", m.f_string().c_str());
      o->f_bool_2 = m.f_bool_2();
      o->f_int32_2 = m.f_int32_2();
      std::snprintf(o->f_string_2, sizeof o->f_string_2, "%s", m.f_string_2().c_str());
      break;
    }
    case TD_DOCUMENT: {
      const auto& d = static_cast<const benchmark::v2::Document&>(msg);
      document_t* o = &out->document;
      std::snprintf(o->id, sizeof o->id, "%s", d.id().c_str());
      o->status = d.status();
      std::snprintf(o->meta.region, sizeof o->meta.region, "%s", d.meta().region().c_str());
      o->meta.version = d.meta().version();
      int n = d.items_size();
      if (n > V2_MAX_CHILDREN) n = V2_MAX_CHILDREN;
      o->item_count = n;
      for (int i = 0; i < n; i++) {
        std::snprintf(o->items[i].sku, sizeof o->items[i].sku, "%s", d.items(i).sku().c_str());
        o->items[i].qty = d.items(i).qty();
        o->items[i].price_minor = d.items(i).price_minor();
      }
      break;
    }
    case TD_TELEMETRY: {
      const auto& t = static_cast<const benchmark::v2::Telemetry&>(msg);
      telemetry_t* o = &out->telemetry;
      std::snprintf(o->source, sizeof o->source, "%s", t.source().c_str());
      o->ts = t.ts();
      int nt = t.tags_size();
      if (nt > V2_MAX_TAGS) nt = V2_MAX_TAGS;
      o->tag_count = nt;
      for (int i = 0; i < nt; i++)
        std::snprintf(o->tags[i], sizeof o->tags[i], "%s", t.tags(i).c_str());
      int nv = t.values_size();
      if (nv > V2_MAX_POINTS) nv = V2_MAX_POINTS;
      o->value_count = nv;
      for (int i = 0; i < nv; i++) o->values[i] = t.values(i);
      break;
    }
    case TD_STRINGS: {
      const auto& s = static_cast<const benchmark::v2::Strings&>(msg);
      int n = s.items_size();
      if (n > V2_MAX_STRINGS) n = V2_MAX_STRINGS;
      out->strings.count = n;
      for (int i = 0; i < n; i++)
        std::snprintf(out->strings.items[i], sizeof out->strings.items[i], "%s", s.items(i).c_str());
      break;
    }
    case TD_EVENT: {
      const auto& e = static_cast<const benchmark::v2::Event&>(msg);
      event_t* o = &out->event;
      std::snprintf(o->event_id, sizeof o->event_id, "%s", e.event_id().c_str());
      std::snprintf(o->event_type, sizeof o->event_type, "%s", e.event_type().c_str());
      o->occurred_at = e.occurred_at();
      std::snprintf(o->producer, sizeof o->producer, "%s", e.producer().c_str());
      int n = e.attrs_size();
      if (n > V2_MAX_ATTRS) n = V2_MAX_ATTRS;
      o->attr_count = n;
      for (int i = 0; i < n; i++) {
        std::snprintf(o->attrs[i].key, sizeof o->attrs[i].key, "%s", e.attrs(i).key().c_str());
        std::snprintf(o->attrs[i].value, sizeof o->attrs[i].value, "%s", e.attrs(i).value().c_str());
      }
      break;
    }
    default:
      break;
  }
}

/*
 * Official libprotobuf path (MessageLite::SerializeToArray / ParseFromArray).
 * Docs: https://protobuf.dev/reference/cpp/api-docs/google.protobuf.message_lite/
 *
 * Batch cells (N>1) call serialize once per instance with distinct fixtures
 * (see batch_cell.c). We must encode *that* fixture — not a single prepared
 * message — or fidelity fails and the runner drops the whole N cell.
 */
int prep(test_data_kind_t k, const test_fixture_t* fx) {
  g_kind = k;
  /* Validate conversion + allocate typed parse target (untimed). */
  auto probe = to_proto(fx);
  if (!probe) return -1;
  g_dst.reset(probe->New());
  return 0;
}

int ser(const test_fixture_t* fx, uint8_t* buf, size_t cap, size_t* ol) {
  if (!fx) return -1;
  /* Always build from the fixture passed by the harness (batch-safe). */
  auto msg = to_proto(fx);
  if (!msg) return -1;
  int sz = static_cast<int>(msg->ByteSizeLong());
  if (sz < 0 || static_cast<size_t>(sz) > cap) return -1;
  if (sz > 0 && !msg->SerializeToArray(buf, sz)) return -1;
  *ol = static_cast<size_t>(sz);
  return 0;
}

int de(const uint8_t* buf, size_t len, test_fixture_t* out, test_data_kind_t kind) {
  if (!g_dst) return -1;
  g_dst->Clear();
  if (!g_dst->ParseFromArray(buf, static_cast<int>(len))) return -1;
  from_proto(out, kind, *g_dst);
  return 0;
}

}  // namespace

extern "C" void bench_register_protobuf_google(serializer_t* o, int* c) {
  o[*c].name = "protobuf";
  o[*c].version = pb_version_cstr();
  o[*c].category = "schema";
  o[*c].supports = supports_all;
  o[*c].prepare = prep;
  o[*c].serialize = ser;
  o[*c].deserialize = de;
  o[*c].fidelity = fidelity_fx;
  (*c)++;
}
