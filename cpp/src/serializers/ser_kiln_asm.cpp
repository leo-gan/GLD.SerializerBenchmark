#include "bench/serializer.hpp"

#include <cstdint>
#include <cstring>
#include <memory>
#include <span>
#include <stdexcept>
#include <string>
#include <vector>

#if defined(HAS_KILN_ASM) && HAS_KILN_ASM
#include "kiln_asm_bench.h"

namespace bench {
namespace {

constexpr uint16_t kDtypeF64 = 1;
constexpr uint16_t kDtypeF32 = 2;
constexpr uint16_t kDtypeI64 = 14;

inline kiln_str_t kstr(const std::string& s) {
  return {reinterpret_cast<const uint8_t*>(s.data()), static_cast<uint64_t>(s.size())};
}

inline std::string from_kstr(kiln_str_t s) {
  return s.len ? std::string(reinterpret_cast<const char*>(s.ptr), static_cast<size_t>(s.len)) : std::string();
}

inline size_t align16(size_t n) { return (n + 15u) & ~size_t(15u); }

void check_ok(kiln_err_t err, const char* op) {
  if (err != KILN_OK) {
    throw std::runtime_error(std::string("gld-kiln-asm ") + op + ": " + kiln_asm_err_name(err));
  }
}

void set_tensor_2d(kiln_tensor_t& t, uint16_t dtype, uint64_t d0, uint64_t d1,
                   const void* data, size_t nbytes) {
  kiln_tensor_init(&t);
  t.dtype = dtype;
  t.rank = 2;
  t.shape[0] = d0;
  t.shape[1] = d1;
  t.data = reinterpret_cast<const uint8_t*>(data);
  t.data_len = static_cast<uint64_t>(nbytes);
}

void set_tensor_1d(kiln_tensor_t& t, uint16_t dtype, uint64_t d0,
                   const void* data, size_t nbytes) {
  kiln_tensor_init(&t);
  t.dtype = dtype;
  t.rank = 1;
  t.shape[0] = d0;
  t.data = reinterpret_cast<const uint8_t*>(data);
  t.data_len = static_cast<uint64_t>(nbytes);
}

void fill_prompt_tensors(const Prompt& p, kiln_tensor_t ts[3], kiln_tensor_dir_t& dir) {
  const size_t nbytes = p.input_ids.size() * sizeof(int64_t);
  set_tensor_2d(ts[0], kDtypeI64, static_cast<uint64_t>(p.batch), static_cast<uint64_t>(p.seq),
                p.input_ids.data(), nbytes);
  set_tensor_2d(ts[1], kDtypeI64, static_cast<uint64_t>(p.batch), static_cast<uint64_t>(p.seq),
                p.attention_mask.data(), nbytes);
  set_tensor_2d(ts[2], kDtypeI64, static_cast<uint64_t>(p.batch), static_cast<uint64_t>(p.seq),
                p.position_ids.data(), nbytes);
  dir.items = ts;
  dir.count = 3;
  dir.block_length = 0;
  dir.flags = 2;
  dir.version = 2;
}

Prompt read_prompt_tensors(const kiln_tensor_dir_t& dir) {
  if (dir.count != 3 || !dir.items) throw std::runtime_error("gld-kiln-asm: bad prompt tensor dir");
  if (dir.items[0].dtype != kDtypeI64 || dir.items[0].rank != 2)
    throw std::runtime_error("gld-kiln-asm: bad prompt tensor meta");
  const uint64_t batch = dir.items[0].shape[0];
  const uint64_t seq = dir.items[0].shape[1];
  const size_t n = static_cast<size_t>(batch * seq);
  const size_t nbytes = n * sizeof(int64_t);
  for (int i = 0; i < 3; ++i) {
    if (dir.items[i].dtype != kDtypeI64 || dir.items[i].rank != 2 ||
        dir.items[i].shape[0] != batch || dir.items[i].shape[1] != seq ||
        dir.items[i].data_len != nbytes) {
      throw std::runtime_error("gld-kiln-asm: prompt tensor shape mismatch");
    }
  }
  Prompt out;
  out.batch = static_cast<int32_t>(batch);
  out.seq = static_cast<int32_t>(seq);
  out.input_ids.resize(n);
  out.attention_mask.resize(n);
  out.position_ids.resize(n);
  if (nbytes) {
    std::memcpy(out.input_ids.data(), dir.items[0].data, nbytes);
    std::memcpy(out.attention_mask.data(), dir.items[1].data, nbytes);
    std::memcpy(out.position_ids.data(), dir.items[2].data, nbytes);
  }
  return out;
}

void fill_msg(const Message& m, bench_message_t& d) {
  d.f_bool = m.f_bool ? 1 : 0;
  d.f_int32 = m.f_int32;
  d.f_int64 = m.f_int64;
  d.f_float64 = m.f_float64;
  d.f_string = kstr(m.f_string);
  d.f_bool_2 = m.f_bool_2 ? 1 : 0;
  d.f_int32_2 = m.f_int32_2;
  d.f_string_2 = kstr(m.f_string_2);
}

Message read_msg(const bench_message_t& s) {
  Message m;
  m.f_bool = s.f_bool != 0;
  m.f_int32 = s.f_int32;
  m.f_int64 = s.f_int64;
  m.f_float64 = s.f_float64;
  m.f_string = from_kstr(s.f_string);
  m.f_bool_2 = s.f_bool_2 != 0;
  m.f_int32_2 = s.f_int32_2;
  m.f_string_2 = from_kstr(s.f_string_2);
  return m;
}

void fill_doc(const Document& doc, bench_document_t& d, bench_document_document_item_t* pool) {
  d.id = kstr(doc.id);
  d.status = doc.status;
  d.meta.region = kstr(doc.meta.region);
  d.meta.version = doc.meta.version;
  d.items.items = doc.items.empty() ? nullptr : pool;
  d.items.count = static_cast<uint64_t>(doc.items.size());
  for (size_t i = 0; i < doc.items.size(); ++i) {
    pool[i].sku = kstr(doc.items[i].sku);
    pool[i].qty = doc.items[i].qty;
    pool[i].price_minor = doc.items[i].price_minor;
  }
}

Document read_doc(const bench_document_t& s) {
  Document d;
  d.id = from_kstr(s.id);
  d.status = s.status;
  d.meta.region = from_kstr(s.meta.region);
  d.meta.version = s.meta.version;
  d.items.resize(static_cast<size_t>(s.items.count));
  for (uint64_t i = 0; i < s.items.count; ++i) {
    d.items[i].sku = from_kstr(s.items.items[i].sku);
    d.items[i].qty = s.items.items[i].qty;
    d.items[i].price_minor = s.items.items[i].price_minor;
  }
  return d;
}

void fill_tel(const Telemetry& t, bench_telemetry_t& d, kiln_str_t* tag_pool) {
  d.source = kstr(t.source);
  d.ts = t.ts;
  d.tags.items = t.tags.empty() ? nullptr : tag_pool;
  d.tags.count = static_cast<uint64_t>(t.tags.size());
  for (size_t i = 0; i < t.tags.size(); ++i) tag_pool[i] = kstr(t.tags[i]);
  d.values.items = t.values.empty() ? nullptr : const_cast<double*>(t.values.data());
  d.values.count = static_cast<uint64_t>(t.values.size());
}

Telemetry read_tel(const bench_telemetry_t& s) {
  Telemetry t;
  t.source = from_kstr(s.source);
  t.ts = s.ts;
  t.tags.resize(static_cast<size_t>(s.tags.count));
  for (uint64_t i = 0; i < s.tags.count; ++i) t.tags[i] = from_kstr(s.tags.items[i]);
  t.values.resize(static_cast<size_t>(s.values.count));
  if (s.values.count) {
    std::memcpy(t.values.data(), s.values.items, static_cast<size_t>(s.values.count) * sizeof(double));
  }
  return t;
}

void fill_strs(const Strings& s, bench_strings_t& d, kiln_str_t* pool) {
  d.items.items = s.items.empty() ? nullptr : pool;
  d.items.count = static_cast<uint64_t>(s.items.size());
  for (size_t i = 0; i < s.items.size(); ++i) pool[i] = kstr(s.items[i]);
}

Strings read_strs(const bench_strings_t& s) {
  Strings out;
  out.items.resize(static_cast<size_t>(s.items.count));
  for (uint64_t i = 0; i < s.items.count; ++i) out.items[i] = from_kstr(s.items.items[i]);
  return out;
}

void fill_ev(const Event& e, bench_event_t& d, bench_event_event_attr_t* pool) {
  d.event_id = kstr(e.event_id);
  d.event_type = kstr(e.event_type);
  d.occurred_at = e.occurred_at;
  d.producer = kstr(e.producer);
  d.attrs.items = e.attrs.empty() ? nullptr : pool;
  d.attrs.count = static_cast<uint64_t>(e.attrs.size());
  for (size_t i = 0; i < e.attrs.size(); ++i) {
    pool[i].key = kstr(e.attrs[i].key);
    pool[i].value = kstr(e.attrs[i].value);
  }
}

Event read_ev(const bench_event_t& s) {
  Event e;
  e.event_id = from_kstr(s.event_id);
  e.event_type = from_kstr(s.event_type);
  e.occurred_at = s.occurred_at;
  e.producer = from_kstr(s.producer);
  e.attrs.resize(static_cast<size_t>(s.attrs.count));
  for (uint64_t i = 0; i < s.attrs.count; ++i) {
    e.attrs[i].key = from_kstr(s.attrs.items[i].key);
    e.attrs[i].value = from_kstr(s.attrs.items[i].value);
  }
  return e;
}

void fill_nested(const NestedRow& r, bench_nested_row_t& d, bench_nested_table_nested_item_t* pool) {
  d.id = kstr(r.id);
  d.status = r.status;
  d.meta.region = kstr(r.meta.region);
  d.meta.version = r.meta.version;
  d.items.items = r.items.empty() ? nullptr : pool;
  d.items.count = static_cast<uint64_t>(r.items.size());
  for (size_t i = 0; i < r.items.size(); ++i) {
    pool[i].sku = kstr(r.items[i].sku);
    pool[i].qty = r.items[i].qty;
    pool[i].price_minor = r.items[i].price_minor;
  }
}

NestedRow read_nested(const bench_nested_row_t& s) {
  NestedRow r;
  r.id = from_kstr(s.id);
  r.status = s.status;
  r.meta.region = from_kstr(s.meta.region);
  r.meta.version = s.meta.version;
  r.items.resize(static_cast<size_t>(s.items.count));
  for (uint64_t i = 0; i < s.items.count; ++i) {
    r.items[i].sku = from_kstr(s.items.items[i].sku);
    r.items[i].qty = s.items.items[i].qty;
    r.items[i].price_minor = s.items.items[i].price_minor;
  }
  return r;
}

void fill_signal(const Signal& sg, bench_signal_t& d, bench_signal_signal_leg_t* pool) {
  d.seq = sg.seq;
  d.ts = sg.ts;
  d.price_mantissa = sg.price_mantissa;
  d.qty = sg.qty;
  d.flags = sg.flags;
  d.symbol = kstr(sg.symbol);
  d.venue = kstr(sg.venue);
  d.legs.items = sg.legs.empty() ? nullptr : pool;
  d.legs.count = static_cast<uint64_t>(sg.legs.size());
  for (size_t i = 0; i < sg.legs.size(); ++i) {
    pool[i].leg_id = sg.legs[i].leg_id;
    pool[i].leg_qty = sg.legs[i].leg_qty;
    pool[i].leg_pad = sg.legs[i].leg_pad;
  }
}

Signal read_signal(const bench_signal_t& s) {
  Signal sg;
  sg.seq = s.seq;
  sg.ts = s.ts;
  sg.price_mantissa = s.price_mantissa;
  sg.qty = s.qty;
  sg.flags = s.flags;
  sg.symbol = from_kstr(s.symbol);
  sg.venue = from_kstr(s.venue);
  sg.legs.resize(static_cast<size_t>(s.legs.count));
  for (uint64_t i = 0; i < s.legs.count; ++i) {
    sg.legs[i].leg_id = s.legs.items[i].leg_id;
    sg.legs[i].leg_qty = s.legs.items[i].leg_qty;
    sg.legs[i].leg_pad = s.legs.items[i].leg_pad;
  }
  return sg;
}

enum class Cell {
  Message, Document, Telemetry, Strings, Event,
  Table, TableProject, NestedTable, Signal,
  Grid, GridWindow,
  Tensor, TensorView, Prompt, Shard, Request
};

class KilnAsmSer final : public ISerializer {
 public:
  const char* name() const override { return "gld-kiln-asm"; }
  const char* version() const override { return kiln_asm_version(); }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }

  bool supports(const std::string& type_id) const override {
    return type_id == "message" || type_id == "document" || type_id == "telemetry" ||
           type_id == "strings" || type_id == "event" ||
           type_id == "table" || type_id == "table_project" ||
           type_id == "nested_table" || type_id == "signal" ||
           type_id == "grid" || type_id == "grid_window" ||
           type_id == "tensor" || type_id == "tensor_view" ||
           type_id == "prompt" || type_id == "shard" || type_id == "request";
  }

  void prepare(const Fixture& fx) override {
    batch_ = fx.instance_count > 1;
    n_ = static_cast<size_t>(fx.instance_count > 0 ? fx.instance_count : 1);
    size_t wire_need = 4096;
    size_t enc_need = 4096;
    size_t arena_need = 65536;

    const auto& t = fx.type_id;
    if (t == "message") {
      cell_ = Cell::Message;
      wire_need = n_ * 256 + 1024;
      enc_need = n_ * sizeof(bench_message_t) + 256;
      arena_need = n_ * sizeof(bench_message_t) + 4096;
    } else if (t == "document") {
      cell_ = Cell::Document;
      size_t items_total = 0;
      if (batch_) {
        for (const auto& d : std::get<std::vector<Document>>(fx.value)) items_total += d.items.size();
      } else {
        items_total = std::get<Document>(fx.value).items.size();
      }
      wire_need = n_ * 128 + items_total * 64 + 1024;
      enc_need = align16(n_ * sizeof(bench_document_t)) + items_total * sizeof(bench_document_document_item_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "telemetry") {
      cell_ = Cell::Telemetry;
      size_t tags_total = 0, vals_total = 0;
      if (batch_) {
        for (const auto& row : std::get<std::vector<Telemetry>>(fx.value)) {
          tags_total += row.tags.size();
          vals_total += row.values.size();
        }
      } else {
        const auto& row = std::get<Telemetry>(fx.value);
        tags_total = row.tags.size();
        vals_total = row.values.size();
      }
      wire_need = n_ * 128 + tags_total * 48 + vals_total * 8 + 1024;
      enc_need = align16(n_ * sizeof(bench_telemetry_t)) + tags_total * sizeof(kiln_str_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "strings") {
      cell_ = Cell::Strings;
      size_t items_total = 0;
      if (batch_) {
        for (const auto& row : std::get<std::vector<Strings>>(fx.value)) items_total += row.items.size();
      } else {
        items_total = std::get<Strings>(fx.value).items.size();
      }
      wire_need = n_ * 16 + items_total * 48 + 1024;
      enc_need = align16(n_ * sizeof(bench_strings_t)) + items_total * sizeof(kiln_str_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "event") {
      cell_ = Cell::Event;
      size_t attrs_total = 0;
      if (batch_) {
        for (const auto& row : std::get<std::vector<Event>>(fx.value)) attrs_total += row.attrs.size();
      } else {
        attrs_total = std::get<Event>(fx.value).attrs.size();
      }
      wire_need = n_ * 192 + attrs_total * 96 + 1024;
      enc_need = align16(n_ * sizeof(bench_event_t)) + attrs_total * sizeof(bench_event_event_attr_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "table" || t == "table_project") {
      cell_ = (t == "table") ? Cell::Table : Cell::TableProject;
      wire_need = n_ * 260 + 4096;
      enc_need = n_ * 192 + 4096;
      arena_need = n_ * 48 + 65536;
    } else if (t == "nested_table") {
      cell_ = Cell::NestedTable;
      size_t items_total = 0;
      if (batch_) {
        for (const auto& row : std::get<std::vector<NestedRow>>(fx.value)) items_total += row.items.size();
      } else {
        items_total = std::get<NestedRow>(fx.value).items.size();
      }
      wire_need = n_ * 128 + items_total * 64 + 1024;
      enc_need = align16(n_ * sizeof(bench_nested_row_t)) + items_total * sizeof(bench_nested_table_nested_item_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "signal") {
      cell_ = Cell::Signal;
      size_t legs_total = 0;
      if (batch_) {
        for (const auto& row : std::get<std::vector<Signal>>(fx.value)) legs_total += row.legs.size();
      } else {
        legs_total = std::get<Signal>(fx.value).legs.size();
      }
      wire_need = n_ * 160 + legs_total * 16 + 1024;
      enc_need = align16(n_ * sizeof(bench_signal_t)) + legs_total * sizeof(bench_signal_signal_leg_t) + 256;
      arena_need = enc_need + 8192;
    } else if (t == "grid" || t == "grid_window") {
      cell_ = (t == "grid") ? Cell::Grid : Cell::GridWindow;
      const auto& g = std::get<Grid>(fx.value);
      nx_ = g.nx; ny_ = g.ny; x0_ = g.x0; y0_ = g.y0; wx_ = g.wx; wy_ = g.wy;
      wire_need = g.values.size() * sizeof(double) + 1024;
    } else if (t == "tensor" || t == "tensor_view") {
      cell_ = (t == "tensor") ? Cell::Tensor : Cell::TensorView;
      const auto& tm = std::get<TensorMatrix>(fx.value);
      wire_need = tm.values.size() * sizeof(float) + 1024;
    } else if (t == "prompt") {
      cell_ = Cell::Prompt;
      const auto& p = std::get<Prompt>(fx.value);
      wire_need = p.input_ids.size() * sizeof(int64_t) * 3 + 2048;
    } else if (t == "shard") {
      cell_ = Cell::Shard;
      const auto& s = std::get<Shard>(fx.value);
      wire_need = (s.tok_emb.size() + s.attn.size() + s.ffn_weight.size() + s.norm.size()) * sizeof(float) + 2048;
    } else if (t == "request") {
      cell_ = Cell::Request;
      const auto& q = std::get<Request>(fx.value);
      wire_need = q.inputs.input_ids.size() * sizeof(int64_t) * 3 + q.model.size() + 2048;
    } else {
      throw std::runtime_error("gld-kiln-asm: unsupported type " + t);
    }

    wire_cap_ = wire_need;
    if (enc_buf_.size() < enc_need) enc_buf_.resize(enc_need);
    if (arena_buf_.size() < arena_need) arena_buf_.resize(arena_need);
  }

  std::vector<uint8_t> serialize_bytes(const Fixture& fx) override {
    std::vector<uint8_t> out(wire_cap_);
    kiln_result_t res{0, 0};
    kiln_err_t err = KILN_ERR_TYPE;

    switch (cell_) {
      case Cell::Message:
        if (batch_) {
          const auto& rows = std::get<std::vector<Message>>(fx.value);
          auto* arr = reinterpret_cast<bench_message_t*>(enc_buf_.data());
          for (size_t i = 0; i < rows.size(); ++i) fill_msg(rows[i], arr[i]);
          err = kiln_asm_encode_bench_message_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          bench_message_t m;
          fill_msg(std::get<Message>(fx.value), m);
          err = kiln_asm_encode_bench_message(&m, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Document:
        if (batch_) {
          const auto& rows = std::get<std::vector<Document>>(fx.value);
          auto* arr = reinterpret_cast<bench_document_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<bench_document_document_item_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_document_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_doc(rows[i], arr[i], pool);
            pool += rows[i].items.size();
          }
          err = kiln_asm_encode_bench_document_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& doc = std::get<Document>(fx.value);
          bench_document_t d;
          auto* pool = reinterpret_cast<bench_document_document_item_t*>(enc_buf_.data());
          fill_doc(doc, d, pool);
          err = kiln_asm_encode_bench_document(&d, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Telemetry:
        if (batch_) {
          const auto& rows = std::get<std::vector<Telemetry>>(fx.value);
          auto* arr = reinterpret_cast<bench_telemetry_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<kiln_str_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_telemetry_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_tel(rows[i], arr[i], pool);
            pool += rows[i].tags.size();
          }
          err = kiln_asm_encode_bench_telemetry_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& row = std::get<Telemetry>(fx.value);
          bench_telemetry_t t;
          auto* pool = reinterpret_cast<kiln_str_t*>(enc_buf_.data());
          fill_tel(row, t, pool);
          err = kiln_asm_encode_bench_telemetry(&t, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Strings:
        if (batch_) {
          const auto& rows = std::get<std::vector<Strings>>(fx.value);
          auto* arr = reinterpret_cast<bench_strings_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<kiln_str_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_strings_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_strs(rows[i], arr[i], pool);
            pool += rows[i].items.size();
          }
          err = kiln_asm_encode_bench_strings_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& row = std::get<Strings>(fx.value);
          bench_strings_t s;
          auto* pool = reinterpret_cast<kiln_str_t*>(enc_buf_.data());
          fill_strs(row, s, pool);
          err = kiln_asm_encode_bench_strings(&s, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Event:
        if (batch_) {
          const auto& rows = std::get<std::vector<Event>>(fx.value);
          auto* arr = reinterpret_cast<bench_event_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<bench_event_event_attr_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_event_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_ev(rows[i], arr[i], pool);
            pool += rows[i].attrs.size();
          }
          err = kiln_asm_encode_bench_event_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& row = std::get<Event>(fx.value);
          bench_event_t e;
          auto* pool = reinterpret_cast<bench_event_event_attr_t*>(enc_buf_.data());
          fill_ev(row, e, pool);
          err = kiln_asm_encode_bench_event(&e, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Table:
      case Cell::TableProject: {
        const Table* rows_ptr = nullptr;
        size_t n = 0;
        if (const auto* one = std::get_if<Table>(&fx.value)) {
          rows_ptr = one;
          n = 1;
        } else {
          const auto& many = std::get<std::vector<Table>>(fx.value);
          rows_ptr = many.data();
          n = many.size();
        }
        auto* fbase = reinterpret_cast<double*>(enc_buf_.data());
        auto* ibase = reinterpret_cast<int64_t*>(fbase + 16u * n);
        auto* sbase = reinterpret_cast<kiln_str_t*>(ibase + 4u * n);
        kiln_str_t* s0 = sbase;
        kiln_str_t* s1 = sbase + n;
        for (size_t r = 0; r < n; ++r) {
          const Table& row = rows_ptr[r];
          for (int c = 0; c < 16; ++c) fbase[static_cast<size_t>(c) * n + r] = row.f_float[c];
          for (int c = 0; c < 4; ++c) ibase[static_cast<size_t>(c) * n + r] = row.f_int[c];
          s0[r] = kstr(row.f_str_0);
          s1[r] = kstr(row.f_str_1);
        }
        bench_table_columns_t tc;
        auto* fcols = &tc.f_float_0;
        auto* icols = &tc.f_int_0;
        for (int c = 0; c < 16; ++c) {
          fcols[c].items = fbase + static_cast<size_t>(c) * n;
          fcols[c].count = static_cast<uint64_t>(n);
        }
        for (int c = 0; c < 4; ++c) {
          icols[c].items = ibase + static_cast<size_t>(c) * n;
          icols[c].count = static_cast<uint64_t>(n);
        }
        tc.f_str_0 = {s0, static_cast<uint64_t>(n)};
        tc.f_str_1 = {s1, static_cast<uint64_t>(n)};
        err = kiln_asm_encode_bench_table_columns(&tc, out.data(), out.size(), nullptr, &res);
        break;
      }

      case Cell::NestedTable:
        if (batch_) {
          const auto& rows = std::get<std::vector<NestedRow>>(fx.value);
          auto* arr = reinterpret_cast<bench_nested_row_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<bench_nested_table_nested_item_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_nested_row_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_nested(rows[i], arr[i], pool);
            pool += rows[i].items.size();
          }
          err = kiln_asm_encode_bench_nested_row_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& row = std::get<NestedRow>(fx.value);
          bench_nested_row_t nr;
          auto* pool = reinterpret_cast<bench_nested_table_nested_item_t*>(enc_buf_.data());
          fill_nested(row, nr, pool);
          err = kiln_asm_encode_bench_nested_row(&nr, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Signal:
        if (batch_) {
          const auto& rows = std::get<std::vector<Signal>>(fx.value);
          auto* arr = reinterpret_cast<bench_signal_t*>(enc_buf_.data());
          auto* pool = reinterpret_cast<bench_signal_signal_leg_t*>(
              enc_buf_.data() + align16(rows.size() * sizeof(bench_signal_t)));
          for (size_t i = 0; i < rows.size(); ++i) {
            fill_signal(rows[i], arr[i], pool);
            pool += rows[i].legs.size();
          }
          err = kiln_asm_encode_bench_signal_batch(arr, rows.size(), out.data(), out.size(), nullptr, &res);
        } else {
          const auto& row = std::get<Signal>(fx.value);
          bench_signal_t sg;
          auto* pool = reinterpret_cast<bench_signal_signal_leg_t*>(enc_buf_.data());
          fill_signal(row, sg, pool);
          err = kiln_asm_encode_bench_signal(&sg, out.data(), out.size(), nullptr, &res);
        }
        break;

      case Cell::Grid:
      case Cell::GridWindow: {
        const auto& g = std::get<Grid>(fx.value);
        kiln_tensor_t t;
        set_tensor_2d(t, kDtypeF64, static_cast<uint64_t>(g.ny), static_cast<uint64_t>(g.nx),
                      g.values.data(), g.values.size() * sizeof(double));
        kiln_tensor_dir_t dir{&t, 1, 0, 2, 2};
        err = kiln_asm_encode_tensors(&dir, out.data(), out.size(), nullptr, &res);
        break;
      }

      case Cell::Tensor:
      case Cell::TensorView: {
        const auto& tm = std::get<TensorMatrix>(fx.value);
        kiln_tensor_t t;
        set_tensor_2d(t, kDtypeF32, static_cast<uint64_t>(tm.rows), static_cast<uint64_t>(tm.cols),
                      tm.values.data(), tm.values.size() * sizeof(float));
        kiln_tensor_dir_t dir{&t, 1, 0, 2, 2};
        err = kiln_asm_encode_tensors(&dir, out.data(), out.size(), nullptr, &res);
        break;
      }

      case Cell::Prompt: {
        kiln_tensor_t ts[3];
        kiln_tensor_dir_t dir;
        fill_prompt_tensors(std::get<Prompt>(fx.value), ts, dir);
        err = kiln_asm_encode_tensors(&dir, out.data(), out.size(), nullptr, &res);
        break;
      }

      case Cell::Shard: {
        const auto& s = std::get<Shard>(fx.value);
        kiln_tensor_t ts[4];
        set_tensor_2d(ts[0], kDtypeF32, static_cast<uint64_t>(s.vocab), static_cast<uint64_t>(s.hidden),
                      s.tok_emb.data(), s.tok_emb.size() * sizeof(float));
        set_tensor_2d(ts[1], kDtypeF32, static_cast<uint64_t>(s.hidden), static_cast<uint64_t>(s.hidden),
                      s.attn.data(), s.attn.size() * sizeof(float));
        set_tensor_2d(ts[2], kDtypeF32, static_cast<uint64_t>(s.ffn), static_cast<uint64_t>(s.hidden),
                      s.ffn_weight.data(), s.ffn_weight.size() * sizeof(float));
        set_tensor_1d(ts[3], kDtypeF32, static_cast<uint64_t>(s.hidden),
                      s.norm.data(), s.norm.size() * sizeof(float));
        kiln_tensor_dir_t dir{ts, 4, 0, 2, 2};
        err = kiln_asm_encode_tensors(&dir, out.data(), out.size(), nullptr, &res);
        break;
      }

      case Cell::Request: {
        const auto& q = std::get<Request>(fx.value);
        kiln_tensor_t ts[3];
        bench_request_t rq;
        rq.request_id = q.request_id;
        rq.model = kstr(q.model);
        rq.temperature = q.temperature;
        fill_prompt_tensors(q.inputs, ts, rq.inputs);
        err = kiln_asm_encode_bench_request(&rq, out.data(), out.size(), nullptr, &res);
        break;
      }
    }

    check_ok(err, "encode");
    out.resize(static_cast<size_t>(res.bytes));
    return out;
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    kiln_arena_t arena;
    kiln_arena_init(&arena, arena_buf_.data(), arena_buf_.size());
    kiln_result_t res{0, 0};

    switch (cell_) {
      case Cell::Message:
        if (batch_) {
          bench_message_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_message_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode message batch");
          std::vector<Message> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_msg(arr[i]));
          return out;
        } else {
          bench_message_t m;
          check_ok(kiln_asm_decode_bench_message(data.data(), data.size(), &m, &arena, nullptr, &res),
                   "decode message");
          return read_msg(m);
        }

      case Cell::Document:
        if (batch_) {
          bench_document_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_document_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode document batch");
          std::vector<Document> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_doc(arr[i]));
          return out;
        } else {
          bench_document_t d;
          check_ok(kiln_asm_decode_bench_document(data.data(), data.size(), &d, &arena, nullptr, &res),
                   "decode document");
          return read_doc(d);
        }

      case Cell::Telemetry:
        if (batch_) {
          bench_telemetry_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_telemetry_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode telemetry batch");
          std::vector<Telemetry> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_tel(arr[i]));
          return out;
        } else {
          bench_telemetry_t t;
          check_ok(kiln_asm_decode_bench_telemetry(data.data(), data.size(), &t, &arena, nullptr, &res),
                   "decode telemetry");
          return read_tel(t);
        }

      case Cell::Strings:
        if (batch_) {
          bench_strings_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_strings_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode strings batch");
          std::vector<Strings> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_strs(arr[i]));
          return out;
        } else {
          bench_strings_t s;
          check_ok(kiln_asm_decode_bench_strings(data.data(), data.size(), &s, &arena, nullptr, &res),
                   "decode strings");
          return read_strs(s);
        }

      case Cell::Event:
        if (batch_) {
          bench_event_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_event_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode event batch");
          std::vector<Event> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_ev(arr[i]));
          return out;
        } else {
          bench_event_t e;
          check_ok(kiln_asm_decode_bench_event(data.data(), data.size(), &e, &arena, nullptr, &res),
                   "decode event");
          return read_ev(e);
        }

      case Cell::Table: {
        bench_table_columns_t tc;
        check_ok(kiln_asm_decode_bench_table_columns(data.data(), data.size(), &tc, &arena, nullptr, &res),
                 "decode table_columns");
        const size_t n = static_cast<size_t>(tc.f_float_0.count);
        const auto* fcols = &tc.f_float_0;
        const auto* icols = &tc.f_int_0;
        for (int c = 1; c < 16; ++c) {
          if (fcols[c].count != n) throw std::runtime_error("gld-kiln-asm: table column length mismatch");
        }
        for (int c = 0; c < 4; ++c) {
          if (icols[c].count != n) throw std::runtime_error("gld-kiln-asm: table int column length mismatch");
        }
        if (tc.f_str_0.count != n || tc.f_str_1.count != n) {
          throw std::runtime_error("gld-kiln-asm: table str column length mismatch");
        }
        std::vector<Table> rows(n);
        for (int c = 0; c < 16; ++c) {
          const auto* p = reinterpret_cast<const uint8_t*>(fcols[c].items);
          for (size_t r = 0; r < n; ++r) std::memcpy(&rows[r].f_float[c], p + r * 8u, 8u);
        }
        for (int c = 0; c < 4; ++c) {
          const auto* p = reinterpret_cast<const uint8_t*>(icols[c].items);
          for (size_t r = 0; r < n; ++r) std::memcpy(&rows[r].f_int[c], p + r * 8u, 8u);
        }
        for (size_t r = 0; r < n; ++r) {
          rows[r].f_str_0 = from_kstr(tc.f_str_0.items[r]);
          rows[r].f_str_1 = from_kstr(tc.f_str_1.items[r]);
        }
        if (!batch_) {
          if (rows.empty()) throw std::runtime_error("gld-kiln-asm: empty table");
          return std::move(rows[0]);
        }
        return rows;
      }

      case Cell::TableProject: {
        const kiln_read_opts_t opts{0, 0, 0, KILN_OPT_EMBEDDED};
        bench_table_project_t proj;
        check_ok(kiln_asm_decode_bench_table_project(data.data(), data.size(), &proj, &arena, &opts, &res),
                 "decode table_project");
        const size_t n = static_cast<size_t>(proj.f_float_0.count);
        std::vector<double> col(n);
        if (n) std::memcpy(col.data(), proj.f_float_0.items, n * sizeof(double));
        return col;
      }

      case Cell::NestedTable:
        if (batch_) {
          bench_nested_row_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_nested_row_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode nested_table batch");
          std::vector<NestedRow> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_nested(arr[i]));
          return out;
        } else {
          bench_nested_row_t nr;
          check_ok(kiln_asm_decode_bench_nested_row(data.data(), data.size(), &nr, &arena, nullptr, &res),
                   "decode nested_table");
          return read_nested(nr);
        }

      case Cell::Signal:
        if (batch_) {
          bench_signal_t* arr = nullptr;
          size_t cnt = 0;
          check_ok(kiln_asm_decode_bench_signal_batch(data.data(), data.size(), &arr, &cnt, &arena, nullptr, &res),
                   "decode signal batch");
          std::vector<Signal> out;
          out.reserve(cnt);
          for (size_t i = 0; i < cnt; ++i) out.push_back(read_signal(arr[i]));
          return out;
        } else {
          bench_signal_t sg;
          check_ok(kiln_asm_decode_bench_signal(data.data(), data.size(), &sg, &arena, nullptr, &res),
                   "decode signal");
          return read_signal(sg);
        }

      case Cell::Grid:
      case Cell::GridWindow: {
        kiln_tensor_dir_t dir;
        check_ok(kiln_asm_decode_tensors(data.data(), data.size(), &dir, &arena, nullptr, &res),
                 "decode grid");
        if (dir.count != 1 || !dir.items || dir.items[0].dtype != kDtypeF64 || dir.items[0].rank != 2) {
          throw std::runtime_error("gld-kiln-asm: invalid grid tensor");
        }
        const int ny = static_cast<int>(dir.items[0].shape[0]);
        const int nx = static_cast<int>(dir.items[0].shape[1]);
        Grid out;
        if (cell_ == Cell::GridWindow) {
          out.nx = wx_;
          out.ny = wy_;
          out.values.resize(static_cast<size_t>(wx_) * static_cast<size_t>(wy_));
          const size_t row_bytes = static_cast<size_t>(wx_) * sizeof(double);
          for (int r = 0; r < wy_; ++r) {
            const size_t src_off = (static_cast<size_t>(y0_ + r) * static_cast<size_t>(nx) +
                                    static_cast<size_t>(x0_)) * sizeof(double);
            std::memcpy(out.values.data() + static_cast<size_t>(r) * static_cast<size_t>(wx_),
                        dir.items[0].data + src_off, row_bytes);
          }
        } else {
          out.nx = nx;
          out.ny = ny;
          out.values.resize(static_cast<size_t>(nx) * static_cast<size_t>(ny));
          std::memcpy(out.values.data(), dir.items[0].data, static_cast<size_t>(dir.items[0].data_len));
        }
        return out;
      }

      case Cell::Tensor:
      case Cell::TensorView: {
        kiln_tensor_dir_t dir;
        check_ok(kiln_asm_decode_tensors(data.data(), data.size(), &dir, &arena, nullptr, &res),
                 "decode tensor");
        if (dir.count != 1 || !dir.items || dir.items[0].dtype != kDtypeF32 || dir.items[0].rank != 2) {
          throw std::runtime_error("gld-kiln-asm: invalid tensor");
        }
        const int32_t rows = static_cast<int32_t>(dir.items[0].shape[0]);
        const int32_t cols = static_cast<int32_t>(dir.items[0].shape[1]);
        const size_t nbytes = static_cast<size_t>(dir.items[0].data_len);
        if (cell_ == Cell::TensorView) {
          const uintptr_t b0 = reinterpret_cast<uintptr_t>(data.data());
          const uintptr_t b1 = b0 + data.size();
          const uintptr_t p0 = reinterpret_cast<uintptr_t>(dir.items[0].data);
          if (nbytes > 0 && (p0 < b0 || p0 > b1 || nbytes > b1 - p0)) {
            throw std::runtime_error("gld-kiln-asm: tensor_view pointer out of buffer");
          }
          TensorView tv;
          tv.rows = rows;
          tv.cols = cols;
          tv.values = std::span<const uint8_t>(dir.items[0].data, nbytes);
          return tv;
        }
        TensorMatrix tm;
        tm.rows = rows;
        tm.cols = cols;
        tm.values.resize(nbytes / sizeof(float));
        if (nbytes) std::memcpy(tm.values.data(), dir.items[0].data, nbytes);
        return tm;
      }

      case Cell::Prompt: {
        kiln_tensor_dir_t dir;
        check_ok(kiln_asm_decode_tensors(data.data(), data.size(), &dir, &arena, nullptr, &res),
                 "decode prompt");
        return read_prompt_tensors(dir);
      }

      case Cell::Shard: {
        kiln_tensor_dir_t dir;
        check_ok(kiln_asm_decode_tensors(data.data(), data.size(), &dir, &arena, nullptr, &res),
                 "decode shard");
        if (dir.count != 4 || !dir.items) throw std::runtime_error("gld-kiln-asm: bad shard dir");
        Shard s;
        s.vocab = static_cast<int32_t>(dir.items[0].shape[0]);
        s.hidden = static_cast<int32_t>(dir.items[0].shape[1]);
        s.ffn = static_cast<int32_t>(dir.items[2].shape[0]);
        s.tok_emb.resize(static_cast<size_t>(dir.items[0].data_len) / sizeof(float));
        s.attn.resize(static_cast<size_t>(dir.items[1].data_len) / sizeof(float));
        s.ffn_weight.resize(static_cast<size_t>(dir.items[2].data_len) / sizeof(float));
        s.norm.resize(static_cast<size_t>(dir.items[3].data_len) / sizeof(float));
        if (!s.tok_emb.empty()) std::memcpy(s.tok_emb.data(), dir.items[0].data, static_cast<size_t>(dir.items[0].data_len));
        if (!s.attn.empty()) std::memcpy(s.attn.data(), dir.items[1].data, static_cast<size_t>(dir.items[1].data_len));
        if (!s.ffn_weight.empty()) std::memcpy(s.ffn_weight.data(), dir.items[2].data, static_cast<size_t>(dir.items[2].data_len));
        if (!s.norm.empty()) std::memcpy(s.norm.data(), dir.items[3].data, static_cast<size_t>(dir.items[3].data_len));
        return s;
      }

      case Cell::Request: {
        bench_request_t rq;
        check_ok(kiln_asm_decode_bench_request(data.data(), data.size(), &rq, &arena, nullptr, &res),
                 "decode request");
        Request out;
        out.request_id = rq.request_id;
        out.model = from_kstr(rq.model);
        out.temperature = rq.temperature;
        out.inputs = read_prompt_tensors(rq.inputs);
        return out;
      }
    }
    throw std::runtime_error("gld-kiln-asm: invalid cell");
  }

 private:
  Cell cell_ = Cell::Message;
  bool batch_ = false;
  size_t n_ = 1;
  size_t wire_cap_ = 4096;
  int nx_ = 0, ny_ = 0, x0_ = 0, y0_ = 0, wx_ = 0, wy_ = 0;
  std::vector<uint8_t> enc_buf_;
  std::vector<uint8_t> arena_buf_;
};

}  // namespace

SerializerPtr make_gld_kiln_asm() { return std::make_unique<KilnAsmSer>(); }

}  // namespace bench

#else

namespace bench {
SerializerPtr make_gld_kiln_asm() { return nullptr; }
}  // namespace bench

#endif
