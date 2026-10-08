#include "bench/serializer.hpp"

#include <cstring>
#include <memory>
#include <stdexcept>
#include <string>
#include <utility>
#include <vector>

#if defined(HAS_ARROW) && HAS_ARROW

#include <arrow/adapters/orc/adapter.h>
#include <arrow/api.h>
#include <arrow/compute/api.h>
#include <arrow/io/memory.h>
#include <arrow/ipc/api.h>
#include <parquet/arrow/reader.h>
#include <parquet/arrow/writer.h>
#include <parquet/file_reader.h>

namespace bench {
namespace {

enum class ColKind { Ipc, Parquet, ParquetRaw, Orc, OrcRaw };

template <typename T>
T Take(arrow::Result<T> r) {
  if (!r.ok()) throw std::runtime_error(r.status().ToString());
  return std::move(r).ValueOrDie();
}

void Ok(const arrow::Status& s) {
  if (!s.ok()) throw std::runtime_error(s.ToString());
}

const char* CompName(arrow::Compression::type c) {
  switch (c) {
    case arrow::Compression::UNCOMPRESSED: return "UNCOMPRESSED";
    case arrow::Compression::SNAPPY: return "SNAPPY";
    case arrow::Compression::GZIP: return "GZIP";
    case arrow::Compression::BROTLI: return "BROTLI";
    case arrow::Compression::ZSTD: return "ZSTD";
    case arrow::Compression::LZ4: return "LZ4";
    case arrow::Compression::LZ4_FRAME: return "LZ4_FRAME";
    case arrow::Compression::LZO: return "LZO";
    case arrow::Compression::BZ2: return "BZ2";
    case arrow::Compression::LZ4_HADOOP: return "LZ4_HADOOP";
    default: return "OTHER";
  }
}

std::shared_ptr<arrow::io::RandomAccessFile> ReaderFor(const std::vector<uint8_t>& data) {
  auto raw = Take(arrow::AllocateBuffer(static_cast<int64_t>(data.size())));
  if (!data.empty()) std::memcpy(raw->mutable_data(), data.data(), data.size());
  auto buf = std::make_shared<arrow::io::BufferReader>(std::shared_ptr<arrow::Buffer>(std::move(raw)));
  return std::static_pointer_cast<arrow::io::RandomAccessFile>(buf);
}

std::vector<uint8_t> BytesOf(const std::shared_ptr<arrow::Buffer>& b) {
  if (!b || b->size() == 0) return {};
  return {b->data(), b->data() + b->size()};
}

std::shared_ptr<arrow::Array> Flatten(const std::shared_ptr<arrow::ChunkedArray>& c) {
  if (!c) throw std::runtime_error("arrow: null column");
  std::shared_ptr<arrow::Array> a;
  if (c->num_chunks() == 0) throw std::runtime_error("arrow: empty column");
  if (c->num_chunks() == 1) a = c->chunk(0);
  else a = Take(arrow::Concatenate(c->chunks()));
  if (a->type_id() == arrow::Type::DICTIONARY) {
    const auto& dt = static_cast<const arrow::DictionaryType&>(*a->type());
    a = Take(arrow::compute::Cast(arrow::Datum(a), dt.value_type())).make_array();
  }
  return a;
}

std::shared_ptr<arrow::Array> FlattenArray(const std::shared_ptr<arrow::Array>& in) {
  if (!in) throw std::runtime_error("arrow: null array");
  if (in->type_id() != arrow::Type::DICTIONARY) return in;
  const auto& dt = static_cast<const arrow::DictionaryType&>(*in->type());
  return Take(arrow::compute::Cast(arrow::Datum(in), dt.value_type())).make_array();
}

std::shared_ptr<arrow::Array> AsDouble(std::shared_ptr<arrow::Array> a) {
  a = FlattenArray(std::move(a));
  if (a->type_id() == arrow::Type::DOUBLE) return a;
  return Take(arrow::compute::Cast(arrow::Datum(a), arrow::float64())).make_array();
}

std::shared_ptr<arrow::Array> AsInt64(std::shared_ptr<arrow::Array> a) {
  a = FlattenArray(std::move(a));
  if (a->type_id() == arrow::Type::INT64) return a;
  return Take(arrow::compute::Cast(arrow::Datum(a), arrow::int64())).make_array();
}

std::shared_ptr<arrow::Array> AsInt32(std::shared_ptr<arrow::Array> a) {
  a = FlattenArray(std::move(a));
  if (a->type_id() == arrow::Type::INT32) return a;
  return Take(arrow::compute::Cast(arrow::Datum(a), arrow::int32())).make_array();
}

std::shared_ptr<arrow::Array> AsUtf8(std::shared_ptr<arrow::Array> a) {
  a = FlattenArray(std::move(a));
  if (a->type_id() == arrow::Type::STRING) return a;
  return Take(arrow::compute::Cast(arrow::Datum(a), arrow::utf8())).make_array();
}

std::shared_ptr<arrow::Array> Col(const arrow::Table& t, const char* name) {
  auto c = t.GetColumnByName(name);
  if (!c) throw std::runtime_error(std::string("arrow: missing column ") + name);
  return Flatten(c);
}

const arrow::StringArray& Strs(const arrow::Array& a) {
  return static_cast<const arrow::StringArray&>(a);
}

std::shared_ptr<arrow::Schema> TableSchema() {
  std::vector<std::shared_ptr<arrow::Field>> fields;
  fields.reserve(22);
  for (int i = 0; i < 16; ++i) {
    fields.push_back(arrow::field("f_float_" + std::to_string(i), arrow::float64()));
  }
  for (int i = 0; i < 4; ++i) {
    fields.push_back(arrow::field("f_int_" + std::to_string(i), arrow::int64()));
  }
  fields.push_back(arrow::field("f_str_0", arrow::utf8()));
  fields.push_back(arrow::field("f_str_1", arrow::utf8()));
  return arrow::schema(std::move(fields));
}

std::shared_ptr<arrow::DataType> MetaType() {
  return arrow::struct_({arrow::field("region", arrow::utf8()), arrow::field("version", arrow::int32())});
}

std::shared_ptr<arrow::DataType> ItemType() {
  return arrow::struct_({arrow::field("sku", arrow::utf8()), arrow::field("qty", arrow::int32()),
                         arrow::field("price_minor", arrow::int64())});
}

std::shared_ptr<arrow::DataType> LegType() {
  return arrow::struct_({arrow::field("leg_id", arrow::int64()), arrow::field("leg_qty", arrow::int32()),
                         arrow::field("leg_pad", arrow::int32())});
}

std::shared_ptr<arrow::Schema> NestedSchema() {
  return arrow::schema({arrow::field("id", arrow::utf8()), arrow::field("status", arrow::int32()),
                        arrow::field("meta", MetaType()), arrow::field("items", arrow::list(ItemType()))});
}

std::shared_ptr<arrow::Schema> SignalSchema() {
  return arrow::schema({arrow::field("seq", arrow::int64()), arrow::field("ts", arrow::int64()),
                        arrow::field("price_mantissa", arrow::int64()), arrow::field("qty", arrow::int32()),
                        arrow::field("flags", arrow::int32()), arrow::field("symbol", arrow::utf8()),
                        arrow::field("venue", arrow::utf8()), arrow::field("legs", arrow::list(LegType()))});
}

std::shared_ptr<arrow::Array> Finish(arrow::ArrayBuilder& b) { return Take(b.Finish()); }

std::shared_ptr<arrow::Table> BuildFlat(const std::vector<Table>& rows) {
  const int64_t n = static_cast<int64_t>(rows.size());
  arrow::DoubleBuilder floats[16];
  arrow::Int64Builder ints[4];
  arrow::StringBuilder s0;
  arrow::StringBuilder s1;
  for (int i = 0; i < 16; ++i) Ok(floats[i].Reserve(n));
  for (int i = 0; i < 4; ++i) Ok(ints[i].Reserve(n));
  Ok(s0.Reserve(n));
  Ok(s1.Reserve(n));
  for (const auto& row : rows) {
    for (int i = 0; i < 16; ++i) Ok(floats[i].Append(row.f_float[i]));
    for (int i = 0; i < 4; ++i) Ok(ints[i].Append(row.f_int[i]));
    Ok(s0.Append(row.f_str_0));
    Ok(s1.Append(row.f_str_1));
  }
  std::vector<std::shared_ptr<arrow::Array>> cols;
  cols.reserve(22);
  for (int i = 0; i < 16; ++i) cols.push_back(Finish(floats[i]));
  for (int i = 0; i < 4; ++i) cols.push_back(Finish(ints[i]));
  cols.push_back(Finish(s0));
  cols.push_back(Finish(s1));
  auto batch = arrow::RecordBatch::Make(TableSchema(), n, std::move(cols));
  return Take(arrow::Table::FromRecordBatches({batch}));
}

std::shared_ptr<arrow::Table> BuildNested(const std::vector<NestedRow>& rows) {
  const int64_t n = static_cast<int64_t>(rows.size());
  arrow::StringBuilder ids;
  arrow::Int32Builder status;
  arrow::StringBuilder regions;
  arrow::Int32Builder versions;
  arrow::Int32Builder offsets;
  arrow::StringBuilder skus;
  arrow::Int32Builder qtys;
  arrow::Int64Builder prices;
  Ok(offsets.Append(0));
  int32_t off = 0;
  for (const auto& row : rows) {
    Ok(ids.Append(row.id));
    Ok(status.Append(row.status));
    Ok(regions.Append(row.meta.region));
    Ok(versions.Append(row.meta.version));
    for (const auto& it : row.items) {
      Ok(skus.Append(it.sku));
      Ok(qtys.Append(it.qty));
      Ok(prices.Append(it.price_minor));
    }
    off += static_cast<int32_t>(row.items.size());
    Ok(offsets.Append(off));
  }
  auto meta = Take(arrow::StructArray::Make({Finish(regions), Finish(versions)},
                                            std::vector<std::string>{"region", "version"}));
  auto values = Take(arrow::StructArray::Make({Finish(skus), Finish(qtys), Finish(prices)},
                                              std::vector<std::string>{"sku", "qty", "price_minor"}));
  auto items = Take(arrow::ListArray::FromArrays(*Finish(offsets), *values));
  auto batch = arrow::RecordBatch::Make(NestedSchema(), n, {Finish(ids), Finish(status), meta, items});
  return Take(arrow::Table::FromRecordBatches({batch}));
}

std::shared_ptr<arrow::Table> BuildSignal(const std::vector<Signal>& rows) {
  const int64_t n = static_cast<int64_t>(rows.size());
  arrow::Int64Builder seq, ts, price;
  arrow::Int32Builder qty, flags;
  arrow::StringBuilder symbol, venue;
  arrow::Int32Builder offsets;
  arrow::Int64Builder leg_id;
  arrow::Int32Builder leg_qty, leg_pad;
  Ok(offsets.Append(0));
  int32_t off = 0;
  for (const auto& row : rows) {
    Ok(seq.Append(row.seq));
    Ok(ts.Append(row.ts));
    Ok(price.Append(row.price_mantissa));
    Ok(qty.Append(row.qty));
    Ok(flags.Append(row.flags));
    Ok(symbol.Append(row.symbol));
    Ok(venue.Append(row.venue));
    for (const auto& leg : row.legs) {
      Ok(leg_id.Append(leg.leg_id));
      Ok(leg_qty.Append(leg.leg_qty));
      Ok(leg_pad.Append(leg.leg_pad));
    }
    off += static_cast<int32_t>(row.legs.size());
    Ok(offsets.Append(off));
  }
  auto values = Take(arrow::StructArray::Make({Finish(leg_id), Finish(leg_qty), Finish(leg_pad)},
                                              std::vector<std::string>{"leg_id", "leg_qty", "leg_pad"}));
  auto legs = Take(arrow::ListArray::FromArrays(*Finish(offsets), *values));
  auto batch = arrow::RecordBatch::Make(
      SignalSchema(), n,
      {Finish(seq), Finish(ts), Finish(price), Finish(qty), Finish(flags), Finish(symbol), Finish(venue),
       legs});
  return Take(arrow::Table::FromRecordBatches({batch}));
}

struct ListSpan {
  std::shared_ptr<arrow::Array> values;
  std::vector<std::pair<int64_t, int64_t>> spans;
};

ListSpan ReadList(const std::shared_ptr<arrow::Array>& col) {
  auto a = FlattenArray(col);
  ListSpan out;
  if (a->type_id() == arrow::Type::LIST) {
    const auto& la = static_cast<const arrow::ListArray&>(*a);
    out.values = FlattenArray(la.values());
    out.spans.resize(static_cast<size_t>(la.length()));
    for (int64_t i = 0; i < la.length(); ++i) out.spans[static_cast<size_t>(i)] = {la.value_offset(i), la.value_length(i)};
    return out;
  }
  if (a->type_id() == arrow::Type::LARGE_LIST) {
    const auto& la = static_cast<const arrow::LargeListArray&>(*a);
    out.values = FlattenArray(la.values());
    out.spans.resize(static_cast<size_t>(la.length()));
    for (int64_t i = 0; i < la.length(); ++i) {
      out.spans[static_cast<size_t>(i)] = {la.value_offset(i), la.value_length(i)};
    }
    return out;
  }
  throw std::runtime_error("arrow: expected list, got " + a->type()->ToString());
}

std::shared_ptr<arrow::Array> StructField(const arrow::Array& arr, const char* name) {
  if (arr.type_id() != arrow::Type::STRUCT) {
    throw std::runtime_error("arrow: expected struct, got " + arr.type()->ToString());
  }
  const auto& st = static_cast<const arrow::StructArray&>(arr);
  auto ty = std::static_pointer_cast<arrow::StructType>(st.type());
  const int idx = ty->GetFieldIndex(name);
  if (idx < 0) throw std::runtime_error(std::string("arrow: missing struct field ") + name);
  return FlattenArray(st.field(idx));
}

std::vector<Table> ReadFlat(const arrow::Table& t) {
  std::shared_ptr<arrow::Array> floats[16];
  std::shared_ptr<arrow::Array> ints[4];
  for (int i = 0; i < 16; ++i) floats[i] = AsDouble(Col(t, ("f_float_" + std::to_string(i)).c_str()));
  for (int i = 0; i < 4; ++i) ints[i] = AsInt64(Col(t, ("f_int_" + std::to_string(i)).c_str()));
  auto s0 = AsUtf8(Col(t, "f_str_0"));
  auto s1 = AsUtf8(Col(t, "f_str_1"));
  const int64_t n = t.num_rows();
  std::vector<Table> rows(static_cast<size_t>(n));
  for (int64_t i = 0; i < n; ++i) {
    Table row;
    for (int c = 0; c < 16; ++c) {
      row.f_float[c] = static_cast<const arrow::DoubleArray&>(*floats[c]).Value(i);
    }
    for (int c = 0; c < 4; ++c) {
      row.f_int[c] = static_cast<const arrow::Int64Array&>(*ints[c]).Value(i);
    }
    row.f_str_0 = std::string(Strs(*s0).GetView(i));
    row.f_str_1 = std::string(Strs(*s1).GetView(i));
    rows[static_cast<size_t>(i)] = std::move(row);
  }
  return rows;
}

std::vector<NestedRow> ReadNested(const arrow::Table& t) {
  auto ids = AsUtf8(Col(t, "id"));
  auto status = AsInt32(Col(t, "status"));
  auto meta_col = Col(t, "meta");
  auto items_col = Col(t, "items");
  auto region = AsUtf8(StructField(*meta_col, "region"));
  auto version = AsInt32(StructField(*meta_col, "version"));
  auto list = ReadList(items_col);
  auto sku = AsUtf8(StructField(*list.values, "sku"));
  auto qty = AsInt32(StructField(*list.values, "qty"));
  auto price = AsInt64(StructField(*list.values, "price_minor"));
  const int64_t n = t.num_rows();
  std::vector<NestedRow> rows(static_cast<size_t>(n));
  for (int64_t i = 0; i < n; ++i) {
    NestedRow row;
    row.id = std::string(Strs(*ids).GetView(i));
    row.status = static_cast<const arrow::Int32Array&>(*status).Value(i);
    row.meta.region = std::string(Strs(*region).GetView(i));
    row.meta.version = static_cast<const arrow::Int32Array&>(*version).Value(i);
    const auto [start, len] = list.spans[static_cast<size_t>(i)];
    row.items.reserve(static_cast<size_t>(len));
    for (int64_t k = 0; k < len; ++k) {
      const int64_t j = start + k;
      NestedItem it;
      it.sku = std::string(Strs(*sku).GetView(j));
      it.qty = static_cast<const arrow::Int32Array&>(*qty).Value(j);
      it.price_minor = static_cast<const arrow::Int64Array&>(*price).Value(j);
      row.items.push_back(std::move(it));
    }
    rows[static_cast<size_t>(i)] = std::move(row);
  }
  return rows;
}

std::vector<Signal> ReadSignals(const arrow::Table& t) {
  auto seq = AsInt64(Col(t, "seq"));
  auto ts = AsInt64(Col(t, "ts"));
  auto price = AsInt64(Col(t, "price_mantissa"));
  auto qty = AsInt32(Col(t, "qty"));
  auto flags = AsInt32(Col(t, "flags"));
  auto symbol = AsUtf8(Col(t, "symbol"));
  auto venue = AsUtf8(Col(t, "venue"));
  auto list = ReadList(Col(t, "legs"));
  auto leg_id = AsInt64(StructField(*list.values, "leg_id"));
  auto leg_qty = AsInt32(StructField(*list.values, "leg_qty"));
  auto leg_pad = AsInt32(StructField(*list.values, "leg_pad"));
  const int64_t n = t.num_rows();
  std::vector<Signal> rows(static_cast<size_t>(n));
  for (int64_t i = 0; i < n; ++i) {
    Signal s;
    s.seq = static_cast<const arrow::Int64Array&>(*seq).Value(i);
    s.ts = static_cast<const arrow::Int64Array&>(*ts).Value(i);
    s.price_mantissa = static_cast<const arrow::Int64Array&>(*price).Value(i);
    s.qty = static_cast<const arrow::Int32Array&>(*qty).Value(i);
    s.flags = static_cast<const arrow::Int32Array&>(*flags).Value(i);
    s.symbol = std::string(Strs(*symbol).GetView(i));
    s.venue = std::string(Strs(*venue).GetView(i));
    const auto [start, len] = list.spans[static_cast<size_t>(i)];
    s.legs.reserve(static_cast<size_t>(len));
    for (int64_t k = 0; k < len; ++k) {
      const int64_t j = start + k;
      SignalLeg leg;
      leg.leg_id = static_cast<const arrow::Int64Array&>(*leg_id).Value(j);
      leg.leg_qty = static_cast<const arrow::Int32Array&>(*leg_qty).Value(j);
      leg.leg_pad = static_cast<const arrow::Int32Array&>(*leg_pad).Value(j);
      s.legs.push_back(leg);
    }
    rows[static_cast<size_t>(i)] = std::move(s);
  }
  return rows;
}

std::vector<uint8_t> WriteIpc(const std::shared_ptr<arrow::Table>& table) {
  auto sink = Take(arrow::io::BufferOutputStream::Create());
  auto writer = Take(arrow::ipc::MakeStreamWriter(sink, table->schema()));
  Ok(writer->WriteTable(*table));
  Ok(writer->Close());
  return BytesOf(Take(sink->Finish()));
}

std::vector<uint8_t> WriteParquet(const std::shared_ptr<arrow::Table>& table, bool uncompressed) {
  auto sink = Take(arrow::io::BufferOutputStream::Create());
  // Arrow C++ 25.0.1 WriterProperties defaults to UNCOMPRESSED. The suite
  // name `parquet` means Snappy, matching pyarrow, arrow-go, and arrow-rs.
  auto props = parquet::WriterProperties::Builder()
                   .compression(uncompressed ? arrow::Compression::UNCOMPRESSED
                                             : arrow::Compression::SNAPPY)
                   ->build();
  Ok(parquet::arrow::WriteTable(*table, arrow::default_memory_pool(), sink, 64 * 1024, props));
  return BytesOf(Take(sink->Finish()));
}

std::vector<uint8_t> WriteOrc(const std::shared_ptr<arrow::Table>& table, bool uncompressed) {
  auto sink = Take(arrow::io::BufferOutputStream::Create());
  std::unique_ptr<arrow::adapters::orc::ORCFileWriter> writer;
  // Adapter WriteOptions default is UNCOMPRESSED, not Apache ORC's Zlib.
  // Arrow names zlib GZIP; ORCFileWriter stores that value as ORC ZLIB.
  arrow::adapters::orc::WriteOptions opt;
  opt.compression = uncompressed ? arrow::Compression::UNCOMPRESSED : arrow::Compression::GZIP;
  writer = Take(arrow::adapters::orc::ORCFileWriter::Open(sink.get(), opt));
  Ok(writer->Write(*table));
  Ok(writer->Close());
  return BytesOf(Take(sink->Finish()));
}

std::shared_ptr<arrow::Table> ReadIpc(const std::vector<uint8_t>& bytes, bool project) {
  auto in = ReaderFor(bytes);
  auto opt = arrow::ipc::IpcReadOptions::Defaults();
  if (project) opt.included_fields = {0};
  // Raw pointer overload: `in` outlives ToTable() below.
  auto reader = Take(arrow::ipc::RecordBatchStreamReader::Open(in.get(), opt));
  return Take(reader->ToTable());
}

std::shared_ptr<arrow::Table> ReadParquet(const std::vector<uint8_t>& bytes, bool project) {
  auto in = ReaderFor(bytes);
  auto reader = Take(parquet::arrow::OpenFile(in, arrow::default_memory_pool()));
  if (project) return Take(reader->ReadTable(std::vector<int>{0}));
  return Take(reader->ReadTable());
}

std::shared_ptr<arrow::Table> ReadOrc(const std::vector<uint8_t>& bytes, bool project) {
  auto in = ReaderFor(bytes);
  auto reader = Take(arrow::adapters::orc::ORCFileReader::Open(in, arrow::default_memory_pool()));
  if (project) return Take(reader->Read(std::vector<std::string>{"f_float_0"}));
  return Take(reader->Read());
}

std::shared_ptr<arrow::Table> ReadArrow(ColKind kind, const std::vector<uint8_t>& bytes, bool project) {
  if (kind == ColKind::Ipc) return ReadIpc(bytes, project);
  if (kind == ColKind::Parquet || kind == ColKind::ParquetRaw) return ReadParquet(bytes, project);
  return ReadOrc(bytes, project);
}

ColKind KindOf(const std::string& name) {
  if (name == "arrow-ipc") return ColKind::Ipc;
  if (name == "parquet") return ColKind::Parquet;
  if (name == "parquet-uncompressed") return ColKind::ParquetRaw;
  if (name == "orc") return ColKind::Orc;
  if (name == "orc-uncompressed") return ColKind::OrcRaw;
  throw std::runtime_error("arrow: unknown codec " + name);
}

class ColumnarSer final : public ISerializer {
 public:
  explicit ColumnarSer(ColKind kind) : kind_(kind) {}
  const char* name() const override {
    switch (kind_) {
      case ColKind::Ipc: return "arrow-ipc";
      case ColKind::Parquet: return "parquet";
      case ColKind::ParquetRaw: return "parquet-uncompressed";
      case ColKind::Orc: return "orc";
      case ColKind::OrcRaw: return "orc-uncompressed";
    }
    return "arrow";
  }
  const char* version() const override { return ARROW_VERSION_STRING; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "table"; }
  bool supports(const std::string& type_id) const override {
    return type_id == "table" || type_id == "table_project" || type_id == "nested_table" ||
           type_id == "signal";
  }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    std::shared_ptr<arrow::Table> table;
    if (type_id_ == "table" || type_id_ == "table_project") table = BuildFlat(as_rows<Table>(value_));
    else if (type_id_ == "nested_table") table = BuildNested(as_rows<NestedRow>(value_));
    else if (type_id_ == "signal") table = BuildSignal(as_rows<Signal>(value_));
    else throw std::runtime_error(std::string(name()) + ": unsupported type " + type_id_);
    if (kind_ == ColKind::Ipc) return WriteIpc(table);
    if (kind_ == ColKind::Parquet) return WriteParquet(table, false);
    if (kind_ == ColKind::ParquetRaw) return WriteParquet(table, true);
    if (kind_ == ColKind::Orc) return WriteOrc(table, false);
    return WriteOrc(table, true);
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    const bool project = type_id_ == "table_project";
    auto table = ReadArrow(kind_, data, project);
    if (project) {
      auto col = AsDouble(Col(*table, "f_float_0"));
      const auto& d = static_cast<const arrow::DoubleArray&>(*col);
      std::vector<double> out(static_cast<size_t>(d.length()));
      for (int64_t i = 0; i < d.length(); ++i) out[static_cast<size_t>(i)] = d.Value(i);
      return out;
    }
    if (type_id_ == "table") {
      auto rows = ReadFlat(*table);
      if (n_ <= 1) return rows.at(0);
      return rows;
    }
    if (type_id_ == "nested_table") {
      auto rows = ReadNested(*table);
      if (n_ <= 1) return rows.at(0);
      return rows;
    }
    if (type_id_ == "signal") {
      auto rows = ReadSignals(*table);
      if (n_ <= 1) return rows.at(0);
      return rows;
    }
    throw std::runtime_error(std::string(name()) + ": unsupported type " + type_id_);
  }

 private:
  ColKind kind_;
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

std::pair<int, std::string> columnar_projected_schema(const std::string& codec,
                                                     const std::vector<uint8_t>& bytes) {
  auto table = ReadArrow(KindOf(codec), bytes, true);
  const int n = table->schema()->num_fields();
  std::string field = n > 0 ? table->schema()->field(0)->name() : "";
  return {n, field};
}

std::string parquet_compression_name(const std::vector<uint8_t>& bytes) {
  auto in = ReaderFor(bytes);
  auto reader = parquet::ParquetFileReader::Open(in);
  auto meta = reader->metadata();
  if (!meta || meta->num_row_groups() < 1 || meta->RowGroup(0)->num_columns() < 1) return "EMPTY";
  return CompName(meta->RowGroup(0)->ColumnChunk(0)->compression());
}

std::string orc_compression_name(const std::vector<uint8_t>& bytes) {
  auto in = ReaderFor(bytes);
  auto reader = Take(arrow::adapters::orc::ORCFileReader::Open(in, arrow::default_memory_pool()));
  return CompName(Take(reader->GetCompression()));
}

SerializerPtr make_arrow_ipc() { return std::make_unique<ColumnarSer>(ColKind::Ipc); }
SerializerPtr make_parquet() { return std::make_unique<ColumnarSer>(ColKind::Parquet); }
SerializerPtr make_parquet_uncompressed() { return std::make_unique<ColumnarSer>(ColKind::ParquetRaw); }
SerializerPtr make_orc() { return std::make_unique<ColumnarSer>(ColKind::Orc); }
SerializerPtr make_orc_uncompressed() { return std::make_unique<ColumnarSer>(ColKind::OrcRaw); }

}  // namespace bench

#else

namespace bench {
SerializerPtr make_arrow_ipc() { return nullptr; }
SerializerPtr make_parquet() { return nullptr; }
SerializerPtr make_parquet_uncompressed() { return nullptr; }
SerializerPtr make_orc() { return nullptr; }
SerializerPtr make_orc_uncompressed() { return nullptr; }
}  // namespace bench

#endif
