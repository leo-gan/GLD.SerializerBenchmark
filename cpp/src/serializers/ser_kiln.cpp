#include "bench/serializer.hpp"

#include "kiln/kiln.hpp"

#include <cstdint>
#include <cstdlib>
#include <cstring>
#include <limits>
#include <new>
#include <span>
#include <stdexcept>
#include <string>
#include <type_traits>
#include <utility>
#include <vector>

// gld-kiln (leo-gan/gld-kiln-cpp 0.2.0). Message, document, strings, and event
// still write the positional wire directly. Tensor, prompt, shard, and request
// call kiln::Writer::encode and kiln::decode_into on f32/i64 views, so the
// timed path is the library bulk copy. tensor_view borrows the f32 payload.
// A batch is one list of the struct. One instance is the struct alone. Tensor N is 1.
// https://leo-gan.github.io/gld-kiln/spec/
//
// Blocks of at least 256 KiB allocated while PoolOn is active are kept after
// delete and handed back on the next allocation. A fresh 4 MiB mmap is zeroed
// by the kernel on the first touch; warmup pays that, later reps do not.

namespace {

constexpr std::size_t kPoolMin = 256 * 1024;
constexpr int kPoolSlots = 8;

struct PoolBlock {
  void* p = nullptr;
  std::size_t n = 0;
};

thread_local PoolBlock g_pool[kPoolSlots];
thread_local int g_pool_n = 0;
thread_local PoolBlock g_live[kPoolSlots * 2];
thread_local int g_live_n = 0;
thread_local int g_pool_depth = 0;

void* take_block(std::size_t n) {
  for (int i = 0; i < g_pool_n; ++i) {
    if (g_pool[i].n >= n) {
      PoolBlock block = g_pool[i];
      g_pool[i] = g_pool[--g_pool_n];
      if (g_live_n < kPoolSlots * 2) g_live[g_live_n++] = block;
      return block.p;
    }
  }
  void* p = std::malloc(n);
  if (p == nullptr) throw std::bad_alloc();
  if (g_live_n < kPoolSlots * 2) g_live[g_live_n++] = PoolBlock{p, n};
  return p;
}

void release_block(void* p) {
  if (p == nullptr) return;
  for (int i = 0; i < g_live_n; ++i) {
    if (g_live[i].p == p) {
      PoolBlock block = g_live[i];
      g_live[i] = g_live[--g_live_n];
      if (g_pool_n < kPoolSlots) g_pool[g_pool_n++] = block;
      else std::free(p);
      return;
    }
  }
  std::free(p);
}

struct PoolOn {
  PoolOn() { ++g_pool_depth; }
  ~PoolOn() { --g_pool_depth; }
  PoolOn(const PoolOn&) = delete;
  PoolOn& operator=(const PoolOn&) = delete;
};

}  // namespace

void* operator new(std::size_t n) {
  if (n == 0) n = 1;
  if (g_pool_depth > 0 && n >= kPoolMin) return take_block(n);
  void* p = std::malloc(n);
  if (p == nullptr) throw std::bad_alloc();
  return p;
}

void operator delete(void* p) noexcept { release_block(p); }

void operator delete(void* p, std::size_t) noexcept { release_block(p); }

namespace bench {
namespace {

const kiln::Schema& message_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"f_bool", kiln::scalar(kiln::Kind::Bool)},
      {"f_int32", kiln::scalar(kiln::Kind::I32)},
      {"f_int64", kiln::scalar(kiln::Kind::I64)},
      {"f_float64", kiln::scalar(kiln::Kind::F64)},
      {"f_string", kiln::scalar(kiln::Kind::Str)},
      {"f_bool_2", kiln::scalar(kiln::Kind::Bool)},
      {"f_int32_2", kiln::scalar(kiln::Kind::I32)},
      {"f_string_2", kiln::scalar(kiln::Kind::Str)},
  });
  return schema;
}

const kiln::Schema& document_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"id", kiln::scalar(kiln::Kind::Str)},
      {"status", kiln::scalar(kiln::Kind::I32)},
      {"meta", kiln::struct_of({
                    {"region", kiln::scalar(kiln::Kind::Str)},
                    {"version", kiln::scalar(kiln::Kind::I32)},
                })},
      {"items", kiln::list_of(kiln::struct_of({
                    {"sku", kiln::scalar(kiln::Kind::Str)},
                    {"qty", kiln::scalar(kiln::Kind::I32)},
                    {"price_minor", kiln::scalar(kiln::Kind::I64)},
                }))},
  });
  return schema;
}

const kiln::Schema& telemetry_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"source", kiln::scalar(kiln::Kind::Str)},
      {"ts", kiln::scalar(kiln::Kind::I64)},
      {"tags", kiln::list_of(kiln::scalar(kiln::Kind::Str))},
      {"values", kiln::list_of(kiln::scalar(kiln::Kind::F64))},
  });
  return schema;
}

const kiln::Schema& strings_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"items", kiln::list_of(kiln::scalar(kiln::Kind::Str))},
  });
  return schema;
}

const kiln::Schema& tensor_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"rows", kiln::scalar(kiln::Kind::I32)},
      {"cols", kiln::scalar(kiln::Kind::I32)},
      {"values", kiln::list_of(kiln::scalar(kiln::Kind::F32))},
  });
  return schema;
}

const kiln::Schema& prompt_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"batch", kiln::scalar(kiln::Kind::I32)},
      {"seq", kiln::scalar(kiln::Kind::I32)},
      {"input_ids", kiln::list_of(kiln::scalar(kiln::Kind::I64))},
      {"attention_mask", kiln::list_of(kiln::scalar(kiln::Kind::I64))},
      {"position_ids", kiln::list_of(kiln::scalar(kiln::Kind::I64))},
  });
  return schema;
}

const kiln::Schema& shard_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"vocab", kiln::scalar(kiln::Kind::I32)},
      {"hidden", kiln::scalar(kiln::Kind::I32)},
      {"ffn", kiln::scalar(kiln::Kind::I32)},
      {"tok_emb", kiln::list_of(kiln::scalar(kiln::Kind::F32))},
      {"attn", kiln::list_of(kiln::scalar(kiln::Kind::F32))},
      {"ffn_weight", kiln::list_of(kiln::scalar(kiln::Kind::F32))},
      {"norm", kiln::list_of(kiln::scalar(kiln::Kind::F32))},
  });
  return schema;
}

const kiln::Schema& request_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"request_id", kiln::scalar(kiln::Kind::I64)},
      {"model", kiln::scalar(kiln::Kind::Str)},
      {"temperature", kiln::scalar(kiln::Kind::F32)},
      {"inputs", prompt_schema()},
  });
  return schema;
}

const kiln::Schema& event_schema() {
  static const kiln::Schema schema = kiln::struct_of({
      {"event_id", kiln::scalar(kiln::Kind::Str)},
      {"event_type", kiln::scalar(kiln::Kind::Str)},
      {"occurred_at", kiln::scalar(kiln::Kind::I64)},
      {"producer", kiln::scalar(kiln::Kind::Str)},
      {"attrs", kiln::list_of(kiln::struct_of({
                   {"key", kiln::scalar(kiln::Kind::Str)},
                   {"value", kiln::scalar(kiln::Kind::Str)},
               }))},
  });
  return schema;
}

const kiln::Value& field_at(const kiln::Value::Dict& dict, std::size_t index) {
  if (index >= dict.size()) throw std::runtime_error("gld-kiln: short struct");
  return dict[index].second;
}

kiln::Value message_value(const Message& row) {
  return kiln::Value::dict({
      {"f_bool", kiln::Value::boolean(row.f_bool)},
      {"f_int32", kiln::Value::i64(row.f_int32)},
      {"f_int64", kiln::Value::i64(row.f_int64)},
      {"f_float64", kiln::Value::f64(row.f_float64)},
      {"f_string", kiln::Value::str(row.f_string)},
      {"f_bool_2", kiln::Value::boolean(row.f_bool_2)},
      {"f_int32_2", kiln::Value::i64(row.f_int32_2)},
      {"f_string_2", kiln::Value::str(row.f_string_2)},
  });
}

kiln::Value document_value(const Document& row) {
  kiln::Value::List items;
  items.reserve(row.items.size());
  for (const DocumentItem& item : row.items) {
    items.push_back(kiln::Value::dict({
        {"sku", kiln::Value::str(item.sku)},
        {"qty", kiln::Value::i64(item.qty)},
        {"price_minor", kiln::Value::i64(item.price_minor)},
    }));
  }
  return kiln::Value::dict({
      {"id", kiln::Value::str(row.id)},
      {"status", kiln::Value::i64(row.status)},
      {"meta", kiln::Value::dict({
                    {"region", kiln::Value::str(row.meta.region)},
                    {"version", kiln::Value::i64(row.meta.version)},
                })},
      {"items", kiln::Value::list(std::move(items))},
  });
}

kiln::Value telemetry_value(const Telemetry& row) {
  kiln::Value::List tags;
  tags.reserve(row.tags.size());
  for (const std::string& tag : row.tags) tags.push_back(kiln::Value::str(tag));
  return kiln::Value::dict({
      {"source", kiln::Value::str(row.source)},
      {"ts", kiln::Value::i64(row.ts)},
      {"tags", kiln::Value::list(std::move(tags))},
      {"values", kiln::Value::f64_view(row.values.data(), row.values.size())},
  });
}

kiln::Value strings_value(const Strings& row) {
  kiln::Value::List items;
  items.reserve(row.items.size());
  for (const std::string& item : row.items) items.push_back(kiln::Value::str(item));
  return kiln::Value::dict({{"items", kiln::Value::list(std::move(items))}});
}

kiln::Value f32_list(const std::vector<float>& values) {
  return kiln::Value::f32_view(values.data(), values.size());
}

kiln::Value i64_list(const std::vector<int64_t>& values) {
  return kiln::Value::i64_view(values.data(), values.size());
}

kiln::Value f64_list(const std::vector<double>& values) {
  return kiln::Value::f64_view(values.data(), values.size());
}

kiln::Value prompt_value(const Prompt& row) {
  return kiln::Value::dict({
      {"batch", kiln::Value::i64(row.batch)},
      {"seq", kiln::Value::i64(row.seq)},
      {"input_ids", i64_list(row.input_ids)},
      {"attention_mask", i64_list(row.attention_mask)},
      {"position_ids", i64_list(row.position_ids)},
  });
}

kiln::Value tensor_value(const TensorMatrix& row) {
  return kiln::Value::dict({
      {"rows", kiln::Value::i64(row.rows)},
      {"cols", kiln::Value::i64(row.cols)},
      {"values", f32_list(row.values)},
  });
}

kiln::Value shard_value(const Shard& row) {
  return kiln::Value::dict({
      {"vocab", kiln::Value::i64(row.vocab)},
      {"hidden", kiln::Value::i64(row.hidden)},
      {"ffn", kiln::Value::i64(row.ffn)},
      {"tok_emb", f32_list(row.tok_emb)},
      {"attn", f32_list(row.attn)},
      {"ffn_weight", f32_list(row.ffn_weight)},
      {"norm", f32_list(row.norm)},
  });
}

kiln::Value request_value(const Request& row) {
  return kiln::Value::dict({
      {"request_id", kiln::Value::i64(row.request_id)},
      {"model", kiln::Value::str(row.model)},
      {"temperature", kiln::Value::f32(row.temperature)},
      {"inputs", prompt_value(row.inputs)},
  });
}

kiln::Value event_value(const Event& row) {
  kiln::Value::List attrs;
  attrs.reserve(row.attrs.size());
  for (const EventAttr& attr : row.attrs) {
    attrs.push_back(kiln::Value::dict({
        {"key", kiln::Value::str(attr.key)},
        {"value", kiln::Value::str(attr.value)},
    }));
  }
  return kiln::Value::dict({
      {"event_id", kiln::Value::str(row.event_id)},
      {"event_type", kiln::Value::str(row.event_type)},
      {"occurred_at", kiln::Value::i64(row.occurred_at)},
      {"producer", kiln::Value::str(row.producer)},
      {"attrs", kiln::Value::list(std::move(attrs))},
  });
}

template <typename T, typename F>
kiln::Value encode_batch(const Value& value, F&& one) {
  const auto& rows = std::get<std::vector<T>>(value);
  kiln::Value::List list;
  list.reserve(rows.size());
  for (const T& row : rows) list.push_back(one(row));
  return kiln::Value::list(std::move(list));
}

Message message_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Message out;
  out.f_bool = field_at(d, 0).as_bool();
  out.f_int32 = static_cast<int32_t>(field_at(d, 1).as_i64());
  out.f_int64 = field_at(d, 2).as_i64();
  out.f_float64 = field_at(d, 3).as_f64();
  out.f_string = field_at(d, 4).as_str();
  out.f_bool_2 = field_at(d, 5).as_bool();
  out.f_int32_2 = static_cast<int32_t>(field_at(d, 6).as_i64());
  out.f_string_2 = field_at(d, 7).as_str();
  return out;
}

Document document_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Document out;
  out.id = field_at(d, 0).as_str();
  out.status = static_cast<int32_t>(field_at(d, 1).as_i64());
  const auto& meta = field_at(d, 2).as_dict();
  out.meta.region = field_at(meta, 0).as_str();
  out.meta.version = static_cast<int32_t>(field_at(meta, 1).as_i64());
  const auto& items = field_at(d, 3).as_list();
  out.items.reserve(items.size());
  for (const kiln::Value& item : items) {
    const auto& fields = item.as_dict();
    DocumentItem row;
    row.sku = field_at(fields, 0).as_str();
    row.qty = static_cast<int32_t>(field_at(fields, 1).as_i64());
    row.price_minor = field_at(fields, 2).as_i64();
    out.items.push_back(std::move(row));
  }
  return out;
}

Telemetry telemetry_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Telemetry out;
  out.source = field_at(d, 0).as_str();
  out.ts = field_at(d, 1).as_i64();
  const auto& tags = field_at(d, 2).as_list();
  out.tags.reserve(tags.size());
  for (const kiln::Value& tag : tags) out.tags.push_back(tag.as_str());
  if (field_at(d, 3).pod_kind() == kiln::PodKind::F64) {
    const auto span = field_at(d, 3).as_f64s();
    out.values.assign(span.begin(), span.end());
  } else {
    const auto& values = field_at(d, 3).as_list();
    out.values.reserve(values.size());
    for (const kiln::Value& item : values) out.values.push_back(item.as_f64());
  }
  return out;
}

Strings strings_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Strings out;
  const auto& items = field_at(d, 0).as_list();
  out.items.reserve(items.size());
  for (const kiln::Value& item : items) out.items.push_back(item.as_str());
  return out;
}

std::vector<float> f32_from_list(const kiln::Value& value) {
  if (value.pod_kind() == kiln::PodKind::F32) {
    const auto span = value.as_f32s();
    return std::vector<float>(span.begin(), span.end());
  }
  const auto& items = value.as_list();
  std::vector<float> out(items.size());
  for (size_t i = 0; i < items.size(); ++i) out[i] = f32_from_bits(items[i].f32_bits());
  return out;
}

std::vector<int64_t> i64_from_list(const kiln::Value& value) {
  if (value.pod_kind() == kiln::PodKind::I64) {
    const auto span = value.as_i64s();
    return std::vector<int64_t>(span.begin(), span.end());
  }
  const auto& items = value.as_list();
  std::vector<int64_t> out(items.size());
  for (size_t i = 0; i < items.size(); ++i) out[i] = items[i].as_i64();
  return out;
}

int32_t i32_field(const kiln::Value::Dict& dict, size_t index) {
  return static_cast<int32_t>(field_at(dict, index).as_i64());
}

TensorMatrix tensor_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  TensorMatrix out;
  out.rows = i32_field(d, 0);
  out.cols = i32_field(d, 1);
  out.values = f32_from_list(field_at(d, 2));
  return out;
}

// Header is rows:i32, cols:i32, count:u32. The f32 payload is borrowed, not copied.
TensorView tensor_view_from(const std::vector<uint8_t>& data) {
  if (data.size() < 12) throw std::runtime_error("gld-kiln: short tensor_view");
  const auto rows = static_cast<int32_t>(kiln::load_u32(data.data()));
  const auto cols = static_cast<int32_t>(kiln::load_u32(data.data() + 4));
  const auto count = kiln::load_u32(data.data() + 8);
  if (count > (std::numeric_limits<size_t>::max() - 12) / 4) {
    throw std::runtime_error("gld-kiln: tensor_view length");
  }
  const size_t bytes = static_cast<size_t>(count) * 4;
  if (data.size() != 12 + bytes) throw std::runtime_error("gld-kiln: tensor_view length");
  TensorView out;
  out.rows = rows;
  out.cols = cols;
  out.values = std::span<const uint8_t>(data.data() + 12, bytes);
  return out;
}

Prompt prompt_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Prompt out;
  out.batch = i32_field(d, 0);
  out.seq = i32_field(d, 1);
  out.input_ids = i64_from_list(field_at(d, 2));
  out.attention_mask = i64_from_list(field_at(d, 3));
  out.position_ids = i64_from_list(field_at(d, 4));
  return out;
}

Shard shard_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Shard out;
  out.vocab = i32_field(d, 0);
  out.hidden = i32_field(d, 1);
  out.ffn = i32_field(d, 2);
  out.tok_emb = f32_from_list(field_at(d, 3));
  out.attn = f32_from_list(field_at(d, 4));
  out.ffn_weight = f32_from_list(field_at(d, 5));
  out.norm = f32_from_list(field_at(d, 6));
  return out;
}

Request request_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Request out;
  out.request_id = field_at(d, 0).as_i64();
  out.model = field_at(d, 1).as_str();
  out.temperature = f32_from_bits(field_at(d, 2).f32_bits());
  out.inputs = prompt_from(field_at(d, 3));
  return out;
}

Event event_from(const kiln::Value& value) {
  const auto& d = value.as_dict();
  Event out;
  out.event_id = field_at(d, 0).as_str();
  out.event_type = field_at(d, 1).as_str();
  out.occurred_at = field_at(d, 2).as_i64();
  out.producer = field_at(d, 3).as_str();
  const auto& attrs = field_at(d, 4).as_list();
  out.attrs.reserve(attrs.size());
  for (const kiln::Value& attr : attrs) {
    const auto& fields = attr.as_dict();
    EventAttr row;
    row.key = field_at(fields, 0).as_str();
    row.value = field_at(fields, 1).as_str();
    out.attrs.push_back(std::move(row));
  }
  return out;
}

template <typename T, typename F>
Value decode_batch(const kiln::Value& value, F&& one) {
  const auto& list = value.as_list();
  std::vector<T> out;
  out.reserve(list.size());
  for (const kiln::Value& item : list) out.push_back(one(item));
  return out;
}

kiln::Value encode_message(const Value& value) { return message_value(std::get<Message>(value)); }
kiln::Value encode_messages(const Value& value) { return encode_batch<Message>(value, message_value); }
kiln::Value encode_document(const Value& value) { return document_value(std::get<Document>(value)); }
kiln::Value encode_documents(const Value& value) { return encode_batch<Document>(value, document_value); }
kiln::Value encode_telemetry(const Value& value) { return telemetry_value(std::get<Telemetry>(value)); }
kiln::Value encode_telemetries(const Value& value) {
  return encode_batch<Telemetry>(value, telemetry_value);
}
kiln::Value encode_strings(const Value& value) { return strings_value(std::get<Strings>(value)); }
kiln::Value encode_strings_batch(const Value& value) {
  return encode_batch<Strings>(value, strings_value);
}
kiln::Value encode_event(const Value& value) { return event_value(std::get<Event>(value)); }
kiln::Value encode_events(const Value& value) { return encode_batch<Event>(value, event_value); }
kiln::Value encode_tensor(const Value& value) { return tensor_value(std::get<TensorMatrix>(value)); }
kiln::Value encode_prompt(const Value& value) { return prompt_value(std::get<Prompt>(value)); }
kiln::Value encode_shard(const Value& value) { return shard_value(std::get<Shard>(value)); }
kiln::Value encode_request(const Value& value) { return request_value(std::get<Request>(value)); }

Value decode_message(const kiln::Value& value) { return message_from(value); }
Value decode_messages(const kiln::Value& value) { return decode_batch<Message>(value, message_from); }
Value decode_document(const kiln::Value& value) { return document_from(value); }
Value decode_documents(const kiln::Value& value) { return decode_batch<Document>(value, document_from); }
Value decode_telemetry(const kiln::Value& value) { return telemetry_from(value); }
Value decode_telemetries(const kiln::Value& value) {
  return decode_batch<Telemetry>(value, telemetry_from);
}
Value decode_strings(const kiln::Value& value) { return strings_from(value); }
Value decode_strings_batch(const kiln::Value& value) {
  return decode_batch<Strings>(value, strings_from);
}
Value decode_event(const kiln::Value& value) { return event_from(value); }
Value decode_events(const kiln::Value& value) { return decode_batch<Event>(value, event_from); }
Value decode_tensor(const kiln::Value& value) { return tensor_from(value); }
Value decode_prompt(const kiln::Value& value) { return prompt_from(value); }
Value decode_shard(const kiln::Value& value) { return shard_from(value); }
Value decode_request(const kiln::Value& value) { return request_from(value); }

[[noreturn]] void fail(const char* what) { throw std::runtime_error(std::string("gld-kiln: ") + what); }

void append_bytes(std::vector<uint8_t>& b, const void* p, std::size_t n) {
  const auto* c = static_cast<const std::uint8_t*>(p);
  b.insert(b.end(), c, c + n);
}

void append_u32(std::vector<uint8_t>& b, std::uint32_t v) {
  std::uint8_t t[4];
  kiln::store_u32(t, v);
  append_bytes(b, t, 4);
}

void append_count(std::vector<uint8_t>& b, std::size_t n) {
  if (n > kiln::kCap || n > 0xffffffffu) fail("LIMIT");
  append_u32(b, static_cast<std::uint32_t>(n));
}

void append_bool(std::vector<uint8_t>& b, bool v) { b.push_back(v ? 1 : 0); }

void append_i32(std::vector<uint8_t>& b, std::int32_t v) {
  append_u32(b, static_cast<std::uint32_t>(v));
}

void append_i64(std::vector<uint8_t>& b, std::int64_t v) {
  std::uint8_t t[8];
  kiln::store_u64(t, static_cast<std::uint64_t>(v));
  append_bytes(b, t, 8);
}

void append_f32(std::vector<uint8_t>& b, float v) {
  std::uint8_t t[4];
  kiln::store_f32(t, v);
  append_bytes(b, t, 4);
}

void append_f64(std::vector<uint8_t>& b, double v) {
  std::uint8_t t[8];
  kiln::store_f64(t, v);
  append_bytes(b, t, 8);
}

void append_str(std::vector<uint8_t>& b, const std::string& s) {
  append_count(b, s.size());
  if (!s.empty()) append_bytes(b, s.data(), s.size());
}

template <typename T>
void append_pod(std::vector<uint8_t>& b, const std::vector<T>& values) {
  static_assert(std::is_trivially_copyable_v<T>);
  append_count(b, values.size());
  if (values.empty()) return;
#if __BYTE_ORDER__ == __ORDER_LITTLE_ENDIAN__
  append_bytes(b, values.data(), values.size() * sizeof(T));
#else
  for (const T& value : values) {
    if constexpr (std::is_same_v<T, float>) append_f32(b, value);
    else if constexpr (std::is_same_v<T, double>) append_f64(b, value);
    else append_i64(b, value);
  }
#endif
}

void append_message(std::vector<uint8_t>& b, const Message& row) {
  append_bool(b, row.f_bool);
  append_i32(b, row.f_int32);
  append_i64(b, row.f_int64);
  append_f64(b, row.f_float64);
  append_str(b, row.f_string);
  append_bool(b, row.f_bool_2);
  append_i32(b, row.f_int32_2);
  append_str(b, row.f_string_2);
}

void append_document(std::vector<uint8_t>& b, const Document& row) {
  append_str(b, row.id);
  append_i32(b, row.status);
  append_str(b, row.meta.region);
  append_i32(b, row.meta.version);
  append_count(b, row.items.size());
  for (const DocumentItem& item : row.items) {
    append_str(b, item.sku);
    append_i32(b, item.qty);
    append_i64(b, item.price_minor);
  }
}

void append_telemetry(std::vector<uint8_t>& b, const Telemetry& row) {
  append_str(b, row.source);
  append_i64(b, row.ts);
  append_count(b, row.tags.size());
  for (const std::string& tag : row.tags) append_str(b, tag);
  append_pod(b, row.values);
}

void append_strings(std::vector<uint8_t>& b, const Strings& row) {
  append_count(b, row.items.size());
  for (const std::string& item : row.items) append_str(b, item);
}

void append_event(std::vector<uint8_t>& b, const Event& row) {
  append_str(b, row.event_id);
  append_str(b, row.event_type);
  append_i64(b, row.occurred_at);
  append_str(b, row.producer);
  append_count(b, row.attrs.size());
  for (const EventAttr& attr : row.attrs) {
    append_str(b, attr.key);
    append_str(b, attr.value);
  }
}

void append_tensor(std::vector<uint8_t>& b, const TensorMatrix& row) {
  append_i32(b, row.rows);
  append_i32(b, row.cols);
  append_pod(b, row.values);
}

void append_prompt(std::vector<uint8_t>& b, const Prompt& row) {
  append_i32(b, row.batch);
  append_i32(b, row.seq);
  append_pod(b, row.input_ids);
  append_pod(b, row.attention_mask);
  append_pod(b, row.position_ids);
}

void append_shard(std::vector<uint8_t>& b, const Shard& row) {
  append_i32(b, row.vocab);
  append_i32(b, row.hidden);
  append_i32(b, row.ffn);
  append_pod(b, row.tok_emb);
  append_pod(b, row.attn);
  append_pod(b, row.ffn_weight);
  append_pod(b, row.norm);
}

void append_request(std::vector<uint8_t>& b, const Request& row) {
  append_i64(b, row.request_id);
  append_str(b, row.model);
  append_f32(b, row.temperature);
  append_prompt(b, row.inputs);
}

struct Cursor {
  const std::uint8_t* p;
  const std::uint8_t* end;
  explicit Cursor(const std::vector<uint8_t>& data) : p(data.data()), end(data.data() + data.size()) {}
  std::size_t left() const { return static_cast<std::size_t>(end - p); }
  void need(std::size_t n) const {
    if (left() < n) fail("EOF");
  }
  std::uint32_t u32() {
    need(4);
    const std::uint32_t v = kiln::load_u32(p);
    p += 4;
    return v;
  }
  std::uint32_t count(std::size_t width) {
    const std::uint32_t n = u32();
    if (static_cast<std::uint64_t>(n) > kiln::kCap) fail("LIMIT");
    if (width != 0 && static_cast<std::uint64_t>(n) > left() / width) fail("EOF");
    return n;
  }
  bool boolean() {
    need(1);
    const std::uint8_t v = *p++;
    if (v > 1) fail("TYPE");
    return v == 1;
  }
  std::int32_t i32() { return static_cast<std::int32_t>(u32()); }
  std::int64_t i64() {
    need(8);
    const std::uint64_t v = kiln::load_u64(p);
    p += 8;
    return static_cast<std::int64_t>(v);
  }
  float f32() {
    need(4);
    const float v = kiln::load_f32(p);
    p += 4;
    return v;
  }
  double f64() {
    need(8);
    const double v = kiln::load_f64(p);
    p += 8;
    return v;
  }
  std::string str() {
    const std::uint32_t n = count(1);
    need(n);
    if (!kiln::utf8_ok(p, n)) fail("UTF8");
    std::string out(reinterpret_cast<const char*>(p), n);
    p += n;
    return out;
  }
  void finish() const {
    if (p != end) fail("TRAILING");
  }
};

template <typename T>
std::vector<T> read_pod(Cursor& in) {
  static_assert(std::is_trivially_copyable_v<T>);
  const std::uint32_t n = in.count(sizeof(T));
  std::vector<T> out;
  if (n == 0) return out;
  const std::size_t bytes = static_cast<std::size_t>(n) * sizeof(T);
  in.need(bytes);
  {
    PoolOn pool;
    out.reserve(n);
  }
  const bool aligned = (reinterpret_cast<std::uintptr_t>(in.p) % alignof(T)) == 0;
  if (aligned) {
    const T* src = reinterpret_cast<const T*>(in.p);
    out.insert(out.end(), src, src + n);
  } else if (n >= 4096) {
    out.insert(out.end(), n, T{});
    std::memcpy(out.data(), in.p, bytes);
  } else {
    for (std::uint32_t i = 0; i < n; ++i) {
      T value;
      std::memcpy(&value, in.p + i * sizeof(T), sizeof(T));
      out.push_back(value);
    }
  }
  in.p += bytes;
  return out;
}

Message read_message(Cursor& in) {
  Message out;
  out.f_bool = in.boolean();
  out.f_int32 = in.i32();
  out.f_int64 = in.i64();
  out.f_float64 = in.f64();
  out.f_string = in.str();
  out.f_bool_2 = in.boolean();
  out.f_int32_2 = in.i32();
  out.f_string_2 = in.str();
  return out;
}

Document read_document(Cursor& in) {
  Document out;
  out.id = in.str();
  out.status = in.i32();
  out.meta.region = in.str();
  out.meta.version = in.i32();
  const std::uint32_t n = in.count(16);
  {
    PoolOn pool;
    out.items.reserve(n);
  }
  for (std::uint32_t i = 0; i < n; ++i) {
    DocumentItem item;
    item.sku = in.str();
    item.qty = in.i32();
    item.price_minor = in.i64();
    out.items.push_back(std::move(item));
  }
  return out;
}

Telemetry read_telemetry(Cursor& in) {
  Telemetry out;
  out.source = in.str();
  out.ts = in.i64();
  const std::uint32_t tags = in.count(4);
  out.tags.reserve(tags);
  for (std::uint32_t i = 0; i < tags; ++i) out.tags.push_back(in.str());
  out.values = read_pod<double>(in);
  return out;
}

Strings read_strings(Cursor& in) {
  Strings out;
  const std::uint32_t n = in.count(4);
  out.items.reserve(n);
  for (std::uint32_t i = 0; i < n; ++i) out.items.push_back(in.str());
  return out;
}

Event read_event(Cursor& in) {
  Event out;
  out.event_id = in.str();
  out.event_type = in.str();
  out.occurred_at = in.i64();
  out.producer = in.str();
  const std::uint32_t n = in.count(8);
  out.attrs.reserve(n);
  for (std::uint32_t i = 0; i < n; ++i) {
    EventAttr attr;
    attr.key = in.str();
    attr.value = in.str();
    out.attrs.push_back(std::move(attr));
  }
  return out;
}

TensorMatrix read_tensor(Cursor& in) {
  TensorMatrix out;
  out.rows = in.i32();
  out.cols = in.i32();
  out.values = read_pod<float>(in);
  return out;
}

Prompt read_prompt(Cursor& in) {
  Prompt out;
  out.batch = in.i32();
  out.seq = in.i32();
  out.input_ids = read_pod<std::int64_t>(in);
  out.attention_mask = read_pod<std::int64_t>(in);
  out.position_ids = read_pod<std::int64_t>(in);
  return out;
}

Shard read_shard(Cursor& in) {
  Shard out;
  out.vocab = in.i32();
  out.hidden = in.i32();
  out.ffn = in.i32();
  out.tok_emb = read_pod<float>(in);
  out.attn = read_pod<float>(in);
  out.ffn_weight = read_pod<float>(in);
  out.norm = read_pod<float>(in);
  return out;
}

Request read_request(Cursor& in) {
  Request out;
  out.request_id = in.i64();
  out.model = in.str();
  out.temperature = in.f32();
  out.inputs = read_prompt(in);
  return out;
}

std::size_t str_wire(const std::string& s) {
  if (s.size() > kiln::kCap) fail("LIMIT");
  return 4 + s.size();
}

std::size_t message_wire(const Message& row) {
  return 26 + str_wire(row.f_string) + str_wire(row.f_string_2);
}

std::size_t pod_wire(std::size_t n, std::size_t width) { return 4 + n * width; }

std::size_t prompt_wire(const Prompt& row) {
  return 8 + pod_wire(row.input_ids.size(), 8) + pod_wire(row.attention_mask.size(), 8) +
         pod_wire(row.position_ids.size(), 8);
}

template <typename T>
std::size_t rows_wire(const std::vector<T>& rows, std::size_t (*one)(const T&)) {
  std::size_t n = 4;
  for (const T& row : rows) n += one(row);
  return n;
}

void lock_wire_once() {
  static bool done = false;
  if (done) return;
  done = true;
  Message message;
  message.f_bool = true;
  message.f_int32 = -2;
  message.f_int64 = -99;
  message.f_float64 = -0.0;
  message.f_string = "ab";
  message.f_bool_2 = false;
  message.f_int32_2 = 4;
  message.f_string_2 = "z";
  std::vector<uint8_t> direct;
  append_message(direct, message);
  const std::vector<uint8_t> library = kiln::encode(message_schema(), message_value(message));
  if (direct != library) fail("message wire");
  TensorMatrix tensor;
  tensor.rows = 1;
  tensor.cols = 2;
  tensor.values = {f32_from_bits(0x80000000u), f32_from_bits(0x7fc00000u)};
  direct.clear();
  append_tensor(direct, tensor);
  if (direct != kiln::encode(tensor_schema(), tensor_value(tensor))) fail("tensor wire");
  Cursor back(direct);
  const TensorMatrix round = read_tensor(back);
  back.finish();
  if (!(round == tensor)) fail("tensor round");
}

enum class Cell : int {
  Message,
  Document,
  Telemetry,
  Strings,
  Event,
  Tensor,
  Prompt,
  Shard,
  Request
};

class KilnSer final : public ISerializer {
 public:
  const char* name() const override { return "gld-kiln"; }
  const char* version() const override { return kiln::kVersion; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }

  bool supports(const std::string& type_id) const override {
    return type_id == "message" || type_id == "document" || type_id == "telemetry" ||
           type_id == "strings" || type_id == "event" || type_id == "tensor" ||
           type_id == "tensor_view" || type_id == "prompt" || type_id == "shard" ||
           type_id == "request";
  }

  void prepare(const Fixture& fx) override {
    lock_wire_once();
    borrow_ = false;
    batch_ = fx.instance_count > 1;
    ready_ = true;
    if (fx.type_id == "message") cell_ = Cell::Message;
    else if (fx.type_id == "document") cell_ = Cell::Document;
    else if (fx.type_id == "telemetry") cell_ = Cell::Telemetry;
    else if (fx.type_id == "strings") cell_ = Cell::Strings;
    else if (fx.type_id == "event") cell_ = Cell::Event;
    else if (fx.type_id == "tensor" || fx.type_id == "tensor_view") {
      if (batch_) fail("tensor N must be 1");
      cell_ = Cell::Tensor;
      borrow_ = fx.type_id == "tensor_view";
    } else if (fx.type_id == "prompt") {
      if (batch_) fail("prompt N must be 1");
      cell_ = Cell::Prompt;
    } else if (fx.type_id == "shard") {
      if (batch_) fail("shard N must be 1");
      cell_ = Cell::Shard;
    } else if (fx.type_id == "request") {
      if (batch_) fail("request N must be 1");
      cell_ = Cell::Request;
    } else {
      throw std::runtime_error("gld-kiln: unsupported type " + fx.type_id);
    }
  }

  std::vector<uint8_t> serialize_bytes(const Fixture& fx) override {
    if (!ready_) fail("prepare was not called");
    PoolOn pool;
    if (library_cell()) {
      // release() is the encoded buffer. The next encode allocates again;
      // PoolOn recycles blocks of at least 256 KiB.
      writer_.encode(active_schema(), library_value(fx));
      return writer_.release();
    }
    std::vector<uint8_t> out;
    out.reserve(wire_size(fx));
    write_fixture(out, fx);
    return out;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (!ready_) fail("prepare was not called");
    if (borrow_) return tensor_view_from(data);
    if (library_cell()) {
      // Domain vectors of at least 256 KiB go through PoolOn. decode_into keeps
      // its own pod buffers and copies once; copying into the returned vector
      // is the second copy.
      PoolOn pool;
      kiln::decode_into(active_schema(), std::span<const std::uint8_t>(data.data(), data.size()), slot_);
      switch (cell_) {
        case Cell::Tensor:
          return tensor_from(slot_);
        case Cell::Prompt:
          return prompt_from(slot_);
        case Cell::Shard:
          return shard_from(slot_);
        case Cell::Request:
          return request_from(slot_);
        default:
          break;
      }
    }
    Cursor in(data);
    Value out = read_fixture(in);
    in.finish();
    return out;
  }

 private:
  std::size_t wire_size(const Fixture& fx) const {
    switch (cell_) {
      case Cell::Message:
        return batch_ ? rows_wire(std::get<std::vector<Message>>(fx.value), message_wire)
                      : message_wire(std::get<Message>(fx.value));
      case Cell::Tensor: {
        const auto& row = std::get<TensorMatrix>(fx.value);
        return 12 + row.values.size() * 4;
      }
      case Cell::Prompt:
        return prompt_wire(std::get<Prompt>(fx.value));
      case Cell::Shard: {
        const auto& row = std::get<Shard>(fx.value);
        return 28 + 4 * (row.tok_emb.size() + row.attn.size() + row.ffn_weight.size() + row.norm.size());
      }
      case Cell::Request: {
        const auto& row = std::get<Request>(fx.value);
        return 12 + str_wire(row.model) + prompt_wire(row.inputs);
      }
      default:
        return batch_ ? static_cast<std::size_t>(fx.instance_count) * 256 : 256;
    }
  }

  void write_fixture(std::vector<uint8_t>& out, const Fixture& fx) const {
    switch (cell_) {
      case Cell::Message:
        write_rows<Message>(out, fx, append_message);
        break;
      case Cell::Document:
        write_rows<Document>(out, fx, append_document);
        break;
      case Cell::Telemetry:
        write_rows<Telemetry>(out, fx, append_telemetry);
        break;
      case Cell::Strings:
        write_rows<Strings>(out, fx, append_strings);
        break;
      case Cell::Event:
        write_rows<Event>(out, fx, append_event);
        break;
      case Cell::Tensor:
        append_tensor(out, std::get<TensorMatrix>(fx.value));
        break;
      case Cell::Prompt:
        append_prompt(out, std::get<Prompt>(fx.value));
        break;
      case Cell::Shard:
        append_shard(out, std::get<Shard>(fx.value));
        break;
      case Cell::Request:
        append_request(out, std::get<Request>(fx.value));
        break;
    }
  }

  template <typename T>
  void write_rows(std::vector<uint8_t>& out, const Fixture& fx, void (*one)(std::vector<uint8_t>&, const T&)) const {
    if (!batch_) {
      one(out, std::get<T>(fx.value));
      return;
    }
    const auto& rows = std::get<std::vector<T>>(fx.value);
    append_count(out, rows.size());
    for (const T& row : rows) one(out, row);
  }

  Value read_fixture(Cursor& in) const {
    switch (cell_) {
      case Cell::Message:
        return read_rows<Message>(in, read_message, 34);
      case Cell::Document:
        return read_rows<Document>(in, read_document, 20);
      case Cell::Telemetry:
        return read_rows<Telemetry>(in, read_telemetry, 20);
      case Cell::Strings:
        return read_rows<Strings>(in, read_strings, 4);
      case Cell::Event:
        return read_rows<Event>(in, read_event, 24);
      case Cell::Tensor:
        return read_tensor(in);
      case Cell::Prompt:
        return read_prompt(in);
      case Cell::Shard:
        return read_shard(in);
      case Cell::Request:
        return read_request(in);
    }
    fail("prepare was not called");
  }

  template <typename T>
  Value read_rows(Cursor& in, T (*one)(Cursor&), std::size_t min_size) const {
    if (!batch_) return one(in);
    const std::uint32_t n = in.count(min_size);
    std::vector<T> rows;
    {
      PoolOn pool;
      rows.reserve(n);
    }
    for (std::uint32_t i = 0; i < n; ++i) rows.push_back(one(in));
    return rows;
  }

  bool library_cell() const {
    return cell_ == Cell::Tensor || cell_ == Cell::Prompt || cell_ == Cell::Shard || cell_ == Cell::Request;
  }

  const kiln::Schema& active_schema() const {
    switch (cell_) {
      case Cell::Tensor:
        return tensor_schema();
      case Cell::Prompt:
        return prompt_schema();
      case Cell::Shard:
        return shard_schema();
      case Cell::Request:
        return request_schema();
      default:
        fail("prepare was not called");
    }
  }

  kiln::Value library_value(const Fixture& fx) const {
    switch (cell_) {
      case Cell::Tensor:
        return tensor_value(std::get<TensorMatrix>(fx.value));
      case Cell::Prompt:
        return prompt_value(std::get<Prompt>(fx.value));
      case Cell::Shard:
        return shard_value(std::get<Shard>(fx.value));
      case Cell::Request:
        return request_value(std::get<Request>(fx.value));
      default:
        fail("prepare was not called");
    }
  }

  Cell cell_ = Cell::Message;
  bool batch_ = false;
  bool borrow_ = false;
  bool ready_ = false;
  kiln::Writer writer_;
  kiln::Value slot_;
};

}  // namespace

SerializerPtr make_gld_kiln() { return std::make_unique<KilnSer>(); }

}  // namespace bench
