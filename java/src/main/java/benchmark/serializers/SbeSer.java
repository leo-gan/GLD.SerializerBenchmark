package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.V2Rows;
import benchmark.v2.MessageHeaderDecoder;
import benchmark.v2.MessageHeaderEncoder;
import benchmark.v2.SignalDecoder;
import benchmark.v2.SignalEncoder;
import benchmark.v2.TableDecoder;
import benchmark.v2.TableEncoder;
import org.agrona.ExpandableArrayBuffer;
import org.agrona.concurrent.UnsafeBuffer;

import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

/**
 * SBE 1.40.2 flyweight codecs generated from {@code schemas/v2/sbe/signal.xml}.
 * The flyweight is filled inside {@link #serializeBytes}. {@code nested_table} is not in the schema.
 * Wire order for signal is fixed fields, then the legs group, then symbol and venue.
 */
public final class SbeSer implements BenchSerializer {
  private String typeId;
  private boolean batch;

  @Override
  public String name() {
    return "sbe";
  }

  @Override
  public String version() {
    return "1.40.2";
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  public boolean supports(String testDataName) {
    return "table".equals(testDataName)
        || "table_project".equals(testDataName)
        || "signal".equals(testDataName);
  }

  @Override
  public void prepare(Fixture fx) {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
  }

  @Override
  public byte[] serializeBytes(Fixture fx) {
    List<?> rows =
        switch (typeId) {
          case "table", "table_project" -> V2Rows.tables(fx.value);
          case "signal" -> V2Rows.signals(fx.value);
          default -> throw new IllegalArgumentException(typeId);
        };
    ExpandableArrayBuffer buf = new ExpandableArrayBuffer(Math.max(256, rows.size() * 256));
    buf.putInt(0, rows.size(), ByteOrder.LITTLE_ENDIAN);
    int offset = Integer.BYTES;
    if ("signal".equals(typeId)) {
      MessageHeaderEncoder header = new MessageHeaderEncoder();
      SignalEncoder enc = new SignalEncoder();
      for (Object o : rows) {
        Signal s = (Signal) o;
        enc.wrapAndApplyHeader(buf, offset, header);
        enc.seq(s.seq);
        enc.ts(s.ts);
        enc.price_mantissa(s.priceMantissa);
        enc.qty(s.qty);
        enc.flags(s.flags);
        SignalEncoder.LegsEncoder legs = enc.legsCount(s.legs == null ? 0 : s.legs.size());
        if (s.legs != null) {
          for (Signal.SignalLeg leg : s.legs) {
            legs.next().leg_id(leg.legId).leg_qty(leg.legQty).leg_pad(0);
          }
        }
        enc.symbol(s.symbol == null ? "" : s.symbol);
        enc.venue(s.venue == null ? "" : s.venue);
        offset = enc.limit();
      }
    } else {
      MessageHeaderEncoder header = new MessageHeaderEncoder();
      TableEncoder enc = new TableEncoder();
      for (Object o : rows) {
        TableRow row = (TableRow) o;
        enc.wrapAndApplyHeader(buf, offset, header);
        enc.f_float_0(row.fFloat0);
        enc.f_float_1(row.fFloat1);
        enc.f_float_2(row.fFloat2);
        enc.f_float_3(row.fFloat3);
        enc.f_float_4(row.fFloat4);
        enc.f_float_5(row.fFloat5);
        enc.f_float_6(row.fFloat6);
        enc.f_float_7(row.fFloat7);
        enc.f_float_8(row.fFloat8);
        enc.f_float_9(row.fFloat9);
        enc.f_float_10(row.fFloat10);
        enc.f_float_11(row.fFloat11);
        enc.f_float_12(row.fFloat12);
        enc.f_float_13(row.fFloat13);
        enc.f_float_14(row.fFloat14);
        enc.f_float_15(row.fFloat15);
        enc.f_int_0(row.fInt0);
        enc.f_int_1(row.fInt1);
        enc.f_int_2(row.fInt2);
        enc.f_int_3(row.fInt3);
        enc.f_str_0(row.fStr0 == null ? "" : row.fStr0);
        enc.f_str_1(row.fStr1 == null ? "" : row.fStr1);
        offset = enc.limit();
      }
    }
    byte[] out = new byte[offset];
    buf.getBytes(0, out, 0, offset);
    return out;
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    UnsafeBuffer buf = new UnsafeBuffer(data);
    int count = buf.getInt(0, ByteOrder.LITTLE_ENDIAN);
    int offset = Integer.BYTES;
    if ("signal".equals(typeId)) {
      MessageHeaderDecoder header = new MessageHeaderDecoder();
      SignalDecoder dec = new SignalDecoder();
      List<Signal> rows = new ArrayList<>(count);
      for (int i = 0; i < count; i++) {
        dec.wrapAndApplyHeader(buf, offset, header);
        Signal s = new Signal();
        s.seq = dec.seq();
        s.ts = dec.ts();
        s.priceMantissa = dec.price_mantissa();
        s.qty = dec.qty();
        s.flags = dec.flags();
        SignalDecoder.LegsDecoder legs = dec.legs();
        int n = legs.count();
        for (int j = 0; j < n; j++) {
          legs.next();
          s.legs.add(new Signal.SignalLeg(legs.leg_id(), legs.leg_qty(), legs.leg_pad()));
        }
        s.symbol = dec.symbol();
        s.venue = dec.venue();
        offset = dec.limit();
        rows.add(s);
      }
      return V2Rows.oneOrList(rows, batch);
    }
    MessageHeaderDecoder header = new MessageHeaderDecoder();
    TableDecoder dec = new TableDecoder();
    List<TableRow> rows = new ArrayList<>(count);
    for (int i = 0; i < count; i++) {
      dec.wrapAndApplyHeader(buf, offset, header);
      TableRow row = new TableRow();
      row.fFloat0 = dec.f_float_0();
      row.fFloat1 = dec.f_float_1();
      row.fFloat2 = dec.f_float_2();
      row.fFloat3 = dec.f_float_3();
      row.fFloat4 = dec.f_float_4();
      row.fFloat5 = dec.f_float_5();
      row.fFloat6 = dec.f_float_6();
      row.fFloat7 = dec.f_float_7();
      row.fFloat8 = dec.f_float_8();
      row.fFloat9 = dec.f_float_9();
      row.fFloat10 = dec.f_float_10();
      row.fFloat11 = dec.f_float_11();
      row.fFloat12 = dec.f_float_12();
      row.fFloat13 = dec.f_float_13();
      row.fFloat14 = dec.f_float_14();
      row.fFloat15 = dec.f_float_15();
      row.fInt0 = dec.f_int_0();
      row.fInt1 = dec.f_int_1();
      row.fInt2 = dec.f_int_2();
      row.fInt3 = dec.f_int_3();
      row.fStr0 = dec.f_str_0();
      row.fStr1 = dec.f_str_1();
      offset = dec.limit();
      rows.add(row);
    }
    if ("table_project".equals(typeId)) return V2Rows.float0(rows);
    return V2Rows.oneOrList(rows, batch);
  }
}
