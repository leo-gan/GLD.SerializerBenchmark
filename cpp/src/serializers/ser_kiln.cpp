#include "bench/serializer.hpp"

#include "kiln/kiln.hpp"

#include <cstdint>
#include <cstring>
#include <limits>
#include <span>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

// gld-kiln (leo-gan/gld-kiln-cpp 0.2.0). Schema is built once in prepare.
// Timed encode builds a kiln::Value and calls Writer::encode, which clears and
// reuses its buffer. Timed decode is kiln::decode, then field reads.
// tensor_view decode borrows the f32 payload and does not copy the matrix.
// A batch is one list of the struct. One instance is the struct alone. Tensor N is 1.
// https://leo-gan.github.io/gld-kiln/spec/

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
  kiln::Value::List values;
  values.reserve(row.values.size());
  for (double value : row.values) values.push_back(kiln::Value::f64(value));
  return kiln::Value::dict({
      {"source", kiln::Value::str(row.source)},
      {"ts", kiln::Value::i64(row.ts)},
      {"tags", kiln::Value::list(std::move(tags))},
      {"values", kiln::Value::list(std::move(values))},
  });
}

kiln::Value strings_value(const Strings& row) {
  kiln::Value::List items;
  items.reserve(row.items.size());
  for (const std::string& item : row.items) items.push_back(kiln::Value::str(item));
  return kiln::Value::dict({{"items", kiln::Value::list(std::move(items))}});
}

kiln::Value::List f32_list(const std::vector<float>& values) {
  kiln::Value::List out;
  out.reserve(values.size());
  for (float value : values) out.push_back(kiln::Value::f32(value));
  return out;
}

kiln::Value::List i64_list(const std::vector<int64_t>& values) {
  kiln::Value::List out;
  out.reserve(values.size());
  for (int64_t value : values) out.push_back(kiln::Value::i64(value));
  return out;
}

kiln::Value prompt_value(const Prompt& row) {
  return kiln::Value::dict({
      {"batch", kiln::Value::i64(row.batch)},
      {"seq", kiln::Value::i64(row.seq)},
      {"input_ids", kiln::Value::list(i64_list(row.input_ids))},
      {"attention_mask", kiln::Value::list(i64_list(row.attention_mask))},
      {"position_ids", kiln::Value::list(i64_list(row.position_ids))},
  });
}

kiln::Value tensor_value(const TensorMatrix& row) {
  return kiln::Value::dict({
      {"rows", kiln::Value::i64(row.rows)},
      {"cols", kiln::Value::i64(row.cols)},
      {"values", kiln::Value::list(f32_list(row.values))},
  });
}

kiln::Value shard_value(const Shard& row) {
  return kiln::Value::dict({
      {"vocab", kiln::Value::i64(row.vocab)},
      {"hidden", kiln::Value::i64(row.hidden)},
      {"ffn", kiln::Value::i64(row.ffn)},
      {"tok_emb", kiln::Value::list(f32_list(row.tok_emb))},
      {"attn", kiln::Value::list(f32_list(row.attn))},
      {"ffn_weight", kiln::Value::list(f32_list(row.ffn_weight))},
      {"norm", kiln::Value::list(f32_list(row.norm))},
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
  const auto& values = field_at(d, 3).as_list();
  out.values.reserve(values.size());
  for (const kiln::Value& item : values) out.values.push_back(item.as_f64());
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
  const auto& items = value.as_list();
  std::vector<float> out(items.size());
  for (size_t i = 0; i < items.size(); ++i) out[i] = f32_from_bits(items[i].f32_bits());
  return out;
}

std::vector<int64_t> i64_from_list(const kiln::Value& value) {
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
    borrow_ = false;
    const bool batch = fx.instance_count > 1;
    if (fx.type_id == "message") {
      schema_ = batch ? kiln::list_of(message_schema()) : message_schema();
      encode_ = batch ? encode_messages : encode_message;
      decode_ = batch ? decode_messages : decode_message;
    } else if (fx.type_id == "document") {
      schema_ = batch ? kiln::list_of(document_schema()) : document_schema();
      encode_ = batch ? encode_documents : encode_document;
      decode_ = batch ? decode_documents : decode_document;
    } else if (fx.type_id == "telemetry") {
      schema_ = batch ? kiln::list_of(telemetry_schema()) : telemetry_schema();
      encode_ = batch ? encode_telemetries : encode_telemetry;
      decode_ = batch ? decode_telemetries : decode_telemetry;
    } else if (fx.type_id == "strings") {
      schema_ = batch ? kiln::list_of(strings_schema()) : strings_schema();
      encode_ = batch ? encode_strings_batch : encode_strings;
      decode_ = batch ? decode_strings_batch : decode_strings;
    } else if (fx.type_id == "event") {
      schema_ = batch ? kiln::list_of(event_schema()) : event_schema();
      encode_ = batch ? encode_events : encode_event;
      decode_ = batch ? decode_events : decode_event;
    } else if (fx.type_id == "tensor" || fx.type_id == "tensor_view") {
      if (batch) throw std::runtime_error("gld-kiln: tensor N must be 1");
      schema_ = tensor_schema();
      encode_ = encode_tensor;
      decode_ = decode_tensor;
      borrow_ = fx.type_id == "tensor_view";
    } else if (fx.type_id == "prompt") {
      if (batch) throw std::runtime_error("gld-kiln: prompt N must be 1");
      schema_ = prompt_schema();
      encode_ = encode_prompt;
      decode_ = decode_prompt;
    } else if (fx.type_id == "shard") {
      if (batch) throw std::runtime_error("gld-kiln: shard N must be 1");
      schema_ = shard_schema();
      encode_ = encode_shard;
      decode_ = decode_shard;
    } else if (fx.type_id == "request") {
      if (batch) throw std::runtime_error("gld-kiln: request N must be 1");
      schema_ = request_schema();
      encode_ = encode_request;
      decode_ = decode_request;
    } else {
      throw std::runtime_error("gld-kiln: unsupported type " + fx.type_id);
    }
  }

  std::vector<uint8_t> serialize_bytes(const Fixture& fx) override {
    if (!encode_) throw std::runtime_error("gld-kiln: prepare was not called");
    const std::span<const std::uint8_t> raw = writer_.encode(schema_, encode_(fx.value));
    return std::vector<uint8_t>(raw.begin(), raw.end());
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (borrow_) return tensor_view_from(data);
    if (!decode_) throw std::runtime_error("gld-kiln: prepare was not called");
    const kiln::Value decoded = kiln::decode(
        schema_, std::span<const std::uint8_t>(data.data(), data.size()));
    return decode_(decoded);
  }

 private:
  kiln::Writer writer_{256};
  kiln::Schema schema_;
  kiln::Value (*encode_)(const Value&) = nullptr;
  Value (*decode_)(const kiln::Value&) = nullptr;
  bool borrow_ = false;
};

}  // namespace

SerializerPtr make_gld_kiln() { return std::make_unique<KilnSer>(); }

}  // namespace bench
