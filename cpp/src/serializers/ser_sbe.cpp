#include "bench/serializer.hpp"

#include <cstring>
#include <stdexcept>
#include <string>
#include <vector>

// Vendored header-only codecs from sbe-tool 1.40.2 (schemas/v2/sbe/signal.xml).
// Both headers repeat the same SBE macros; the TU is compiled with -Wno-macro-redefined.
#include "Signal.h"
#include "Table.h"

namespace bench {
namespace {

using SbeSignal = benchmark::v2::Signal;
using SbeTable = benchmark::v2::Table;
using SbeHeader = benchmark::v2::MessageHeader;

size_t signal_bytes(const Signal& s) {
  return 8 + 32 + 4 + s.legs.size() * 16 + 8 + s.symbol.size() + s.venue.size() + 16;
}

size_t table_bytes(const Table& t) {
  return 8 + 16 * 8 + 4 * 8 + 8 + t.f_str_0.size() + t.f_str_1.size() + 16;
}

void write_signal(char* buf, uint64_t cap, uint64_t& off, const Signal& s) {
  SbeSignal enc;
  enc.wrapAndApplyHeader(buf, off, cap);
  enc.seq(s.seq);
  enc.ts(s.ts);
  enc.price_mantissa(s.price_mantissa);
  enc.qty(s.qty);
  enc.flags(s.flags);
  auto& legs = enc.legsCount(static_cast<uint16_t>(s.legs.size()));
  for (const auto& leg : s.legs) {
    legs.next().leg_id(leg.leg_id).leg_qty(leg.leg_qty).leg_pad(leg.leg_pad);
  }
  enc.putSymbol(s.symbol);
  enc.putVenue(s.venue);
  off = enc.sbePosition();
}

void write_table(char* buf, uint64_t cap, uint64_t& off, const Table& t) {
  SbeTable enc;
  enc.wrapAndApplyHeader(buf, off, cap);
  enc.f_float_0(t.f_float[0]);
  enc.f_float_1(t.f_float[1]);
  enc.f_float_2(t.f_float[2]);
  enc.f_float_3(t.f_float[3]);
  enc.f_float_4(t.f_float[4]);
  enc.f_float_5(t.f_float[5]);
  enc.f_float_6(t.f_float[6]);
  enc.f_float_7(t.f_float[7]);
  enc.f_float_8(t.f_float[8]);
  enc.f_float_9(t.f_float[9]);
  enc.f_float_10(t.f_float[10]);
  enc.f_float_11(t.f_float[11]);
  enc.f_float_12(t.f_float[12]);
  enc.f_float_13(t.f_float[13]);
  enc.f_float_14(t.f_float[14]);
  enc.f_float_15(t.f_float[15]);
  enc.f_int_0(t.f_int[0]);
  enc.f_int_1(t.f_int[1]);
  enc.f_int_2(t.f_int[2]);
  enc.f_int_3(t.f_int[3]);
  enc.putF_str_0(t.f_str_0);
  enc.putF_str_1(t.f_str_1);
  off = enc.sbePosition();
}

Signal read_signal(char* buf, uint64_t cap, uint64_t body, uint64_t block, uint64_t ver, uint64_t& next) {
  SbeSignal dec;
  dec.wrapForDecode(buf, body, block, ver, cap);
  Signal s;
  s.seq = dec.seq();
  s.ts = dec.ts();
  s.price_mantissa = dec.price_mantissa();
  s.qty = dec.qty();
  s.flags = dec.flags();
  auto& legs = dec.legs();
  while (legs.hasNext()) {
    auto& leg = legs.next();
    SignalLeg x;
    x.leg_id = leg.leg_id();
    x.leg_qty = leg.leg_qty();
    x.leg_pad = leg.leg_pad();
    s.legs.push_back(x);
  }
  s.symbol = dec.getSymbolAsString();
  s.venue = dec.getVenueAsString();
  next = dec.sbePosition();
  return s;
}

Table read_table(char* buf, uint64_t cap, uint64_t body, uint64_t block, uint64_t ver, uint64_t& next) {
  SbeTable dec;
  dec.wrapForDecode(buf, body, block, ver, cap);
  Table t;
  t.f_float[0] = dec.f_float_0();
  t.f_float[1] = dec.f_float_1();
  t.f_float[2] = dec.f_float_2();
  t.f_float[3] = dec.f_float_3();
  t.f_float[4] = dec.f_float_4();
  t.f_float[5] = dec.f_float_5();
  t.f_float[6] = dec.f_float_6();
  t.f_float[7] = dec.f_float_7();
  t.f_float[8] = dec.f_float_8();
  t.f_float[9] = dec.f_float_9();
  t.f_float[10] = dec.f_float_10();
  t.f_float[11] = dec.f_float_11();
  t.f_float[12] = dec.f_float_12();
  t.f_float[13] = dec.f_float_13();
  t.f_float[14] = dec.f_float_14();
  t.f_float[15] = dec.f_float_15();
  t.f_int[0] = dec.f_int_0();
  t.f_int[1] = dec.f_int_1();
  t.f_int[2] = dec.f_int_2();
  t.f_int[3] = dec.f_int_3();
  t.f_str_0 = dec.getF_str_0AsString();
  t.f_str_1 = dec.getF_str_1AsString();
  next = dec.sbePosition();
  return t;
}

class SbeSer final : public ISerializer {
 public:
  const char* name() const override { return "sbe"; }
  const char* version() const override { return "1.40.2"; }
  const char* stream_mode() const override { return "adapted"; }
  const char* native_kind() const override { return "schema"; }
  bool supports(const std::string& type_id) const override {
    return type_id == "table" || type_id == "table_project" || type_id == "signal";
  }

  void prepare(const Fixture& fx) override {
    type_id_ = fx.type_id;
    n_ = fx.instance_count;
    value_ = fx.value;
  }

  std::vector<uint8_t> serialize_bytes(const Fixture&) override {
    if (!supports(type_id_)) throw std::runtime_error("sbe: unsupported type " + type_id_);
    size_t cap = 64;
    if (type_id_ == "signal") {
      for (const auto& row : as_rows<Signal>(value_)) cap += signal_bytes(row);
    } else {
      for (const auto& row : as_rows<Table>(value_)) cap += table_bytes(row);
    }
    std::vector<char> buf(cap);
    uint64_t off = 0;
    if (type_id_ == "signal") {
      for (const auto& row : as_rows<Signal>(value_)) write_signal(buf.data(), cap, off, row);
    } else {
      for (const auto& row : as_rows<Table>(value_)) write_table(buf.data(), cap, off, row);
    }
    return std::vector<uint8_t>(buf.begin(), buf.begin() + static_cast<std::ptrdiff_t>(off));
  }

  Value deserialize_bytes(const std::vector<uint8_t>& data) override {
    if (!supports(type_id_)) throw std::runtime_error("sbe: unsupported type " + type_id_);
    std::vector<char> buf(data.begin(), data.end());
    const uint64_t cap = buf.size();
    uint64_t off = 0;
    const bool project = type_id_ == "table_project";
    if (type_id_ == "signal") {
      std::vector<Signal> rows;
      while (off + SbeHeader::encodedLength() <= cap) {
        SbeHeader hdr;
        hdr.wrap(buf.data(), off, 0, cap);
        uint64_t next = off;
        rows.push_back(read_signal(buf.data(), cap, off + SbeHeader::encodedLength(), hdr.blockLength(),
                                   hdr.version(), next));
        if (next <= off) break;
        off = next;
      }
      if (n_ <= 1) {
        if (rows.empty()) throw std::runtime_error("sbe: empty signal");
        return rows[0];
      }
      return rows;
    }
    std::vector<Table> rows;
    while (off + SbeHeader::encodedLength() <= cap) {
      SbeHeader hdr;
      hdr.wrap(buf.data(), off, 0, cap);
      uint64_t next = off;
      rows.push_back(read_table(buf.data(), cap, off + SbeHeader::encodedLength(), hdr.blockLength(),
                                hdr.version(), next));
      if (next <= off) break;
      off = next;
    }
    if (project) {
      std::vector<double> col;
      col.reserve(rows.size());
      for (const auto& row : rows) col.push_back(row.f_float[0]);
      return col;
    }
    if (n_ <= 1) {
      if (rows.empty()) throw std::runtime_error("sbe: empty table");
      return rows[0];
    }
    return rows;
  }

 private:
  std::string type_id_;
  int n_ = 1;
  Value value_;
};

}  // namespace

SerializerPtr make_sbe() { return std::make_unique<SbeSer>(); }

}  // namespace bench
