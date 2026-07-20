#include "capnp_bridge.h"
#include "benchmark.capnp.h"

#include <capnp/message.h>
#include <capnp/serialize.h>
#include <kj/array.h>

#include <cstdlib>
#include <cstring>
#include <string>
#include <vector>

static char* dup_str(const char* s) {
  if (!s) s = "";
  size_t n = std::strlen(s) + 1;
  char* p = (char*)std::malloc(n);
  if (p) std::memcpy(p, s, n);
  return p;
}

void capnp_free(void* p) { std::free(p); }

const char* capnp_bridge_version(void) { return "capnproto-1.0.2"; }

template <typename BuilderFn>
static void* encode_message_bytes(BuilderFn fill, size_t* out_len) {
  try {
    ::capnp::MallocMessageBuilder message;
    fill(message);
    kj::Array<capnp::word> words = messageToFlatArray(message);
    size_t bytes = words.size() * sizeof(capnp::word);
    void* buf = std::malloc(bytes);
    if (!buf) return nullptr;
    std::memcpy(buf, words.begin(), bytes);
    if (out_len) *out_len = bytes;
    return buf;
  } catch (...) {
    return nullptr;
  }
}

static void fill_message(::Message::Builder b, const CapnpCMessage* m) {
  b.setFBool(m->f_bool);
  b.setFInt32(m->f_int32);
  b.setFInt64(m->f_int64);
  b.setFFloat64(m->f_float64);
  b.setFString(m->f_string ? m->f_string : "");
  b.setFBool2(m->f_bool_2);
  b.setFInt32B(m->f_int32_2);
  b.setFStringB(m->f_string_2 ? m->f_string_2 : "");
}

void* capnp_encode_message(const CapnpCMessage* m, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    fill_message(msg.initRoot<::Message>(), m);
  }, out_len);
}

void* capnp_encode_batch_message(const CapnpCMessage* items, size_t n, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    auto root = msg.initRoot<::BatchMessage>();
    auto list = root.initItems((unsigned)n);
    for (size_t i = 0; i < n; ++i) fill_message(list[i], &items[i]);
  }, out_len);
}

static void fill_document(::Document::Builder b, const CapnpCDocument* d) {
  b.setId(d->id ? d->id : "");
  b.setStatus(d->status);
  auto meta = b.initMeta();
  meta.setRegion(d->meta.region ? d->meta.region : "");
  meta.setVersion(d->meta.version);
  auto items = b.initItems((unsigned)d->items_count);
  for (size_t i = 0; i < d->items_count; ++i) {
    items[i].setSku(d->items[i].sku ? d->items[i].sku : "");
    items[i].setQty(d->items[i].qty);
    items[i].setPriceMinor(d->items[i].price_minor);
  }
}

void* capnp_encode_document(const CapnpCDocument* d, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    fill_document(msg.initRoot<::Document>(), d);
  }, out_len);
}

void* capnp_encode_batch_document(const CapnpCDocument* items, size_t n, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    auto root = msg.initRoot<::BatchDocument>();
    auto list = root.initItems((unsigned)n);
    for (size_t i = 0; i < n; ++i) fill_document(list[i], &items[i]);
  }, out_len);
}

static void fill_telemetry(::Telemetry::Builder b, const CapnpCTelemetry* t) {
  b.setSource(t->source ? t->source : "");
  b.setTs(t->ts);
  auto tags = b.initTags((unsigned)t->tags_count);
  for (size_t i = 0; i < t->tags_count; ++i)
    tags.set(i, t->tags[i] ? t->tags[i] : "");
  auto vals = b.initValues((unsigned)t->values_count);
  for (size_t i = 0; i < t->values_count; ++i) vals.set(i, t->values[i]);
}

void* capnp_encode_telemetry(const CapnpCTelemetry* t, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    fill_telemetry(msg.initRoot<::Telemetry>(), t);
  }, out_len);
}

void* capnp_encode_batch_telemetry(const CapnpCTelemetry* items, size_t n, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    auto root = msg.initRoot<::BatchTelemetry>();
    auto list = root.initItems((unsigned)n);
    for (size_t i = 0; i < n; ++i) fill_telemetry(list[i], &items[i]);
  }, out_len);
}

static void fill_strings(::Strings::Builder b, const CapnpCStrings* s) {
  auto items = b.initItems((unsigned)s->items_count);
  for (size_t i = 0; i < s->items_count; ++i)
    items.set(i, s->items[i] ? s->items[i] : "");
}

void* capnp_encode_strings(const CapnpCStrings* s, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    fill_strings(msg.initRoot<::Strings>(), s);
  }, out_len);
}

void* capnp_encode_batch_strings(const CapnpCStrings* items, size_t n, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    auto root = msg.initRoot<::BatchStrings>();
    auto list = root.initItems((unsigned)n);
    for (size_t i = 0; i < n; ++i) fill_strings(list[i], &items[i]);
  }, out_len);
}

static void fill_event(::Event::Builder b, const CapnpCEvent* e) {
  b.setEventId(e->event_id ? e->event_id : "");
  b.setEventType(e->event_type ? e->event_type : "");
  b.setOccurredAt(e->occurred_at);
  b.setProducer(e->producer ? e->producer : "");
  auto attrs = b.initAttrs((unsigned)e->attrs_count);
  for (size_t i = 0; i < e->attrs_count; ++i) {
    attrs[i].setKey(e->attrs[i].key ? e->attrs[i].key : "");
    attrs[i].setValue(e->attrs[i].value ? e->attrs[i].value : "");
  }
}

void* capnp_encode_event(const CapnpCEvent* e, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    fill_event(msg.initRoot<::Event>(), e);
  }, out_len);
}

void* capnp_encode_batch_event(const CapnpCEvent* items, size_t n, size_t* out_len) {
  return encode_message_bytes([&](::capnp::MallocMessageBuilder& msg) {
    auto root = msg.initRoot<::BatchEvent>();
    auto list = root.initItems((unsigned)n);
    for (size_t i = 0; i < n; ++i) fill_event(list[i], &items[i]);
  }, out_len);
}

/* ---- decode helpers ---- */
template <typename Root, typename Fn>
static int with_reader(const void* data, size_t len, Fn fn) {
  try {
    if (len % sizeof(capnp::word) != 0) return -1;
    kj::ArrayPtr<const capnp::word> words(
        reinterpret_cast<const capnp::word*>(data), len / sizeof(capnp::word));
    ::capnp::FlatArrayMessageReader reader(words);
    fn(reader.getRoot<Root>());
    return 0;
  } catch (...) {
    return -1;
  }
}

static void read_message(::Message::Reader r, CapnpCMessage* out) {
  std::memset(out, 0, sizeof(*out));
  out->f_bool = r.getFBool();
  out->f_int32 = r.getFInt32();
  out->f_int64 = r.getFInt64();
  out->f_float64 = r.getFFloat64();
  out->f_string = dup_str(r.getFString().cStr());
  out->f_bool_2 = r.getFBool2();
  out->f_int32_2 = r.getFInt32B();
  out->f_string_2 = dup_str(r.getFStringB().cStr());
}

int capnp_decode_message(const void* data, size_t len, CapnpCMessage* out) {
  return with_reader<::Message>(data, len, [&](auto r) { read_message(r, out); });
}

int capnp_decode_batch_message(const void* data, size_t len, CapnpCMessage** out, size_t* out_n) {
  return with_reader<::BatchMessage>(data, len, [&](auto r) {
    auto items = r.getItems();
    size_t n = items.size();
    auto* arr = (CapnpCMessage*)std::calloc(n, sizeof(CapnpCMessage));
    for (size_t i = 0; i < n; ++i) read_message(items[i], &arr[i]);
    *out = arr;
    *out_n = n;
  });
}

static void read_document(::Document::Reader r, CapnpCDocument* out) {
  std::memset(out, 0, sizeof(*out));
  out->id = dup_str(r.getId().cStr());
  out->status = r.getStatus();
  out->meta.region = dup_str(r.getMeta().getRegion().cStr());
  out->meta.version = r.getMeta().getVersion();
  auto items = r.getItems();
  out->items_count = items.size();
  auto* arr = (CapnpCDocumentItem*)std::calloc(out->items_count, sizeof(CapnpCDocumentItem));
  for (size_t i = 0; i < out->items_count; ++i) {
    arr[i].sku = dup_str(items[i].getSku().cStr());
    arr[i].qty = items[i].getQty();
    arr[i].price_minor = items[i].getPriceMinor();
  }
  out->items = arr;
}

int capnp_decode_document(const void* data, size_t len, CapnpCDocument* out) {
  return with_reader<::Document>(data, len, [&](auto r) { read_document(r, out); });
}

int capnp_decode_batch_document(const void* data, size_t len, CapnpCDocument** out, size_t* out_n) {
  return with_reader<::BatchDocument>(data, len, [&](auto r) {
    auto items = r.getItems();
    size_t n = items.size();
    auto* arr = (CapnpCDocument*)std::calloc(n, sizeof(CapnpCDocument));
    for (size_t i = 0; i < n; ++i) read_document(items[i], &arr[i]);
    *out = arr;
    *out_n = n;
  });
}

static void read_telemetry(::Telemetry::Reader r, CapnpCTelemetry* out) {
  std::memset(out, 0, sizeof(*out));
  out->source = dup_str(r.getSource().cStr());
  out->ts = r.getTs();
  auto tags = r.getTags();
  out->tags_count = tags.size();
  auto* tarr = (const char**)std::calloc(out->tags_count, sizeof(char*));
  for (size_t i = 0; i < out->tags_count; ++i) tarr[i] = dup_str(tags[i].cStr());
  out->tags = tarr;
  auto vals = r.getValues();
  out->values_count = vals.size();
  auto* varr = (double*)std::malloc(out->values_count * sizeof(double));
  for (size_t i = 0; i < out->values_count; ++i) varr[i] = vals[i];
  out->values = varr;
}

int capnp_decode_telemetry(const void* data, size_t len, CapnpCTelemetry* out) {
  return with_reader<::Telemetry>(data, len, [&](auto r) { read_telemetry(r, out); });
}

int capnp_decode_batch_telemetry(const void* data, size_t len, CapnpCTelemetry** out, size_t* out_n) {
  return with_reader<::BatchTelemetry>(data, len, [&](auto r) {
    auto items = r.getItems();
    size_t n = items.size();
    auto* arr = (CapnpCTelemetry*)std::calloc(n, sizeof(CapnpCTelemetry));
    for (size_t i = 0; i < n; ++i) read_telemetry(items[i], &arr[i]);
    *out = arr;
    *out_n = n;
  });
}

static void read_strings(::Strings::Reader r, CapnpCStrings* out) {
  std::memset(out, 0, sizeof(*out));
  auto items = r.getItems();
  out->items_count = items.size();
  auto* arr = (const char**)std::calloc(out->items_count, sizeof(char*));
  for (size_t i = 0; i < out->items_count; ++i) arr[i] = dup_str(items[i].cStr());
  out->items = arr;
}

int capnp_decode_strings(const void* data, size_t len, CapnpCStrings* out) {
  return with_reader<::Strings>(data, len, [&](auto r) { read_strings(r, out); });
}

int capnp_decode_batch_strings(const void* data, size_t len, CapnpCStrings** out, size_t* out_n) {
  return with_reader<::BatchStrings>(data, len, [&](auto r) {
    auto items = r.getItems();
    size_t n = items.size();
    auto* arr = (CapnpCStrings*)std::calloc(n, sizeof(CapnpCStrings));
    for (size_t i = 0; i < n; ++i) read_strings(items[i], &arr[i]);
    *out = arr;
    *out_n = n;
  });
}

static void read_event(::Event::Reader r, CapnpCEvent* out) {
  std::memset(out, 0, sizeof(*out));
  out->event_id = dup_str(r.getEventId().cStr());
  out->event_type = dup_str(r.getEventType().cStr());
  out->occurred_at = r.getOccurredAt();
  out->producer = dup_str(r.getProducer().cStr());
  auto attrs = r.getAttrs();
  out->attrs_count = attrs.size();
  auto* arr = (CapnpCEventAttr*)std::calloc(out->attrs_count, sizeof(CapnpCEventAttr));
  for (size_t i = 0; i < out->attrs_count; ++i) {
    arr[i].key = dup_str(attrs[i].getKey().cStr());
    arr[i].value = dup_str(attrs[i].getValue().cStr());
  }
  out->attrs = arr;
}

int capnp_decode_event(const void* data, size_t len, CapnpCEvent* out) {
  return with_reader<::Event>(data, len, [&](auto r) { read_event(r, out); });
}

int capnp_decode_batch_event(const void* data, size_t len, CapnpCEvent** out, size_t* out_n) {
  return with_reader<::BatchEvent>(data, len, [&](auto r) {
    auto items = r.getItems();
    size_t n = items.size();
    auto* arr = (CapnpCEvent*)std::calloc(n, sizeof(CapnpCEvent));
    for (size_t i = 0; i < n; ++i) read_event(items[i], &arr[i]);
    *out = arr;
    *out_n = n;
  });
}

void capnp_free_message(CapnpCMessage* m) {
  if (!m) return;
  std::free((void*)m->f_string);
  std::free((void*)m->f_string_2);
}
void capnp_free_document(CapnpCDocument* d) {
  if (!d) return;
  std::free((void*)d->id);
  std::free((void*)d->meta.region);
  if (d->items) {
    for (size_t i = 0; i < d->items_count; ++i) std::free((void*)d->items[i].sku);
    std::free((void*)d->items);
  }
}
void capnp_free_telemetry(CapnpCTelemetry* t) {
  if (!t) return;
  std::free((void*)t->source);
  if (t->tags) {
    for (size_t i = 0; i < t->tags_count; ++i) std::free((void*)t->tags[i]);
    std::free((void*)t->tags);
  }
  std::free((void*)t->values);
}
void capnp_free_strings(CapnpCStrings* s) {
  if (!s) return;
  if (s->items) {
    for (size_t i = 0; i < s->items_count; ++i) std::free((void*)s->items[i]);
    std::free((void*)s->items);
  }
}
void capnp_free_event(CapnpCEvent* e) {
  if (!e) return;
  std::free((void*)e->event_id);
  std::free((void*)e->event_type);
  std::free((void*)e->producer);
  if (e->attrs) {
    for (size_t i = 0; i < e->attrs_count; ++i) {
      std::free((void*)e->attrs[i].key);
      std::free((void*)e->attrs[i].value);
    }
    std::free((void*)e->attrs);
  }
}
void capnp_free_batch_message(CapnpCMessage* items, size_t n) {
  if (!items) return;
  for (size_t i = 0; i < n; ++i) capnp_free_message(&items[i]);
  std::free(items);
}
void capnp_free_batch_document(CapnpCDocument* items, size_t n) {
  if (!items) return;
  for (size_t i = 0; i < n; ++i) capnp_free_document(&items[i]);
  std::free(items);
}
void capnp_free_batch_telemetry(CapnpCTelemetry* items, size_t n) {
  if (!items) return;
  for (size_t i = 0; i < n; ++i) capnp_free_telemetry(&items[i]);
  std::free(items);
}
void capnp_free_batch_strings(CapnpCStrings* items, size_t n) {
  if (!items) return;
  for (size_t i = 0; i < n; ++i) capnp_free_strings(&items[i]);
  std::free(items);
}
void capnp_free_batch_event(CapnpCEvent* items, size_t n) {
  if (!items) return;
  for (size_t i = 0; i < n; ++i) capnp_free_event(&items[i]);
  std::free(items);
}
