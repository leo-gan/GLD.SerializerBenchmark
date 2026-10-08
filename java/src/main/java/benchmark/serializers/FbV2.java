package benchmark.serializers;

import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import com.google.flatbuffers.FlatBufferBuilder;
import com.google.flatbuffers.Table;

import java.nio.ByteBuffer;
import java.nio.ByteOrder;
import java.util.ArrayList;
import java.util.List;

/**
 * Hand-built FlatBuffers tables for the columnar types.
 * Slot order matches the Python builders. There is no shared {@code .fbs} for these types.
 * FlatBufferBuilder only accepts slots in descending order.
 */
public final class FbV2 {
  private FbV2() {}

  public static int packTable(FlatBufferBuilder b, TableRow row) {
    int s1 = b.createString(nz(row.fStr1));
    int s0 = b.createString(nz(row.fStr0));
    b.startTable(22);
    b.addOffset(21, s1, 0);
    b.addOffset(20, s0, 0);
    b.addLong(19, row.fInt3, 0);
    b.addLong(18, row.fInt2, 0);
    b.addLong(17, row.fInt1, 0);
    b.addLong(16, row.fInt0, 0);
    b.addDouble(15, row.fFloat15, 0.0);
    b.addDouble(14, row.fFloat14, 0.0);
    b.addDouble(13, row.fFloat13, 0.0);
    b.addDouble(12, row.fFloat12, 0.0);
    b.addDouble(11, row.fFloat11, 0.0);
    b.addDouble(10, row.fFloat10, 0.0);
    b.addDouble(9, row.fFloat9, 0.0);
    b.addDouble(8, row.fFloat8, 0.0);
    b.addDouble(7, row.fFloat7, 0.0);
    b.addDouble(6, row.fFloat6, 0.0);
    b.addDouble(5, row.fFloat5, 0.0);
    b.addDouble(4, row.fFloat4, 0.0);
    b.addDouble(3, row.fFloat3, 0.0);
    b.addDouble(2, row.fFloat2, 0.0);
    b.addDouble(1, row.fFloat1, 0.0);
    b.addDouble(0, row.fFloat0, 0.0);
    return b.endTable();
  }

  public static int packNested(FlatBufferBuilder b, NestedRow row) {
    NestedRow.NestedMeta meta = row.meta != null ? row.meta : new NestedRow.NestedMeta("", 0);
    int id = b.createString(nz(row.id));
    int region = b.createString(nz(meta.region));
    b.startTable(2);
    b.addInt(1, meta.version, 0);
    b.addOffset(0, region, 0);
    int metaOff = b.endTable();
    List<NestedRow.NestedItem> items = row.items != null ? row.items : List.of();
    int[] itemOffs = new int[items.size()];
    for (int i = 0; i < items.size(); i++) {
      NestedRow.NestedItem it = items.get(i);
      int sku = b.createString(nz(it.sku));
      b.startTable(3);
      b.addLong(2, it.priceMinor, 0);
      b.addInt(1, it.qty, 0);
      b.addOffset(0, sku, 0);
      itemOffs[i] = b.endTable();
    }
    int vec = b.createVectorOfTables(itemOffs);
    b.startTable(4);
    b.addOffset(3, vec, 0);
    b.addOffset(2, metaOff, 0);
    b.addInt(1, row.status, 0);
    b.addOffset(0, id, 0);
    return b.endTable();
  }

  public static int packSignal(FlatBufferBuilder b, Signal row) {
    int venue = b.createString(nz(row.venue));
    int symbol = b.createString(nz(row.symbol));
    List<Signal.SignalLeg> legs = row.legs != null ? row.legs : List.of();
    int[] legOffs = new int[legs.size()];
    for (int i = 0; i < legs.size(); i++) {
      Signal.SignalLeg leg = legs.get(i);
      b.startTable(3);
      b.addInt(2, leg.legPad, 0);
      b.addInt(1, leg.legQty, 0);
      b.addLong(0, leg.legId, 0);
      legOffs[i] = b.endTable();
    }
    int vec = b.createVectorOfTables(legOffs);
    b.startTable(8);
    b.addOffset(7, vec, 0);
    b.addOffset(6, venue, 0);
    b.addOffset(5, symbol, 0);
    b.addInt(4, row.flags, 0);
    b.addInt(3, row.qty, 0);
    b.addLong(2, row.priceMantissa, 0);
    b.addLong(1, row.ts, 0);
    b.addLong(0, row.seq, 0);
    return b.endTable();
  }

  /** One-field wrapper. Field 0 is a vector of the row tables. */
  public static int packBatch(FlatBufferBuilder b, int[] tables) {
    int vec = b.createVectorOfTables(tables);
    b.startTable(1);
    b.addOffset(0, vec, 0);
    return b.endTable();
  }

  public static TableRow readTable(ByteBuffer bb) {
    return tableFrom(FbTable.root(bb));
  }

  public static List<TableRow> readTableBatch(ByteBuffer bb) {
    FbTable root = FbTable.root(bb);
    int n = root.vectorLen(0);
    List<TableRow> out = new ArrayList<>(n);
    for (int i = 0; i < n; i++) out.add(tableFrom(root.vectorTable(0, i)));
    return out;
  }

  public static NestedRow readNested(ByteBuffer bb) {
    return nestedFrom(FbTable.root(bb));
  }

  public static List<NestedRow> readNestedBatch(ByteBuffer bb) {
    FbTable root = FbTable.root(bb);
    int n = root.vectorLen(0);
    List<NestedRow> out = new ArrayList<>(n);
    for (int i = 0; i < n; i++) out.add(nestedFrom(root.vectorTable(0, i)));
    return out;
  }

  public static Signal readSignal(ByteBuffer bb) {
    return signalFrom(FbTable.root(bb));
  }

  public static List<Signal> readSignalBatch(ByteBuffer bb) {
    FbTable root = FbTable.root(bb);
    int n = root.vectorLen(0);
    List<Signal> out = new ArrayList<>(n);
    for (int i = 0; i < n; i++) out.add(signalFrom(root.vectorTable(0, i)));
    return out;
  }

  private static TableRow tableFrom(FbTable t) {
    TableRow row = new TableRow();
    row.fFloat0 = t.f64(0);
    row.fFloat1 = t.f64(1);
    row.fFloat2 = t.f64(2);
    row.fFloat3 = t.f64(3);
    row.fFloat4 = t.f64(4);
    row.fFloat5 = t.f64(5);
    row.fFloat6 = t.f64(6);
    row.fFloat7 = t.f64(7);
    row.fFloat8 = t.f64(8);
    row.fFloat9 = t.f64(9);
    row.fFloat10 = t.f64(10);
    row.fFloat11 = t.f64(11);
    row.fFloat12 = t.f64(12);
    row.fFloat13 = t.f64(13);
    row.fFloat14 = t.f64(14);
    row.fFloat15 = t.f64(15);
    row.fInt0 = t.i64(16);
    row.fInt1 = t.i64(17);
    row.fInt2 = t.i64(18);
    row.fInt3 = t.i64(19);
    row.fStr0 = t.str(20);
    row.fStr1 = t.str(21);
    return row;
  }

  private static NestedRow nestedFrom(FbTable t) {
    FbTable meta = t.table(2);
    NestedRow.NestedMeta m =
        meta == null ? new NestedRow.NestedMeta("", 0) : new NestedRow.NestedMeta(meta.str(0), meta.i32(1));
    int n = t.vectorLen(3);
    List<NestedRow.NestedItem> items = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      FbTable it = t.vectorTable(3, i);
      items.add(new NestedRow.NestedItem(it.str(0), it.i32(1), it.i64(2)));
    }
    return new NestedRow(t.str(0), t.i32(1), m, items);
  }

  private static Signal signalFrom(FbTable t) {
    int n = t.vectorLen(7);
    List<Signal.SignalLeg> legs = new ArrayList<>(n);
    for (int i = 0; i < n; i++) {
      FbTable leg = t.vectorTable(7, i);
      legs.add(new Signal.SignalLeg(leg.i64(0), leg.i32(1), leg.i32(2)));
    }
    return new Signal(t.i64(0), t.i64(1), t.i64(2), t.i32(3), t.i32(4), t.str(5), t.str(6), legs);
  }

  private static String nz(String s) {
    return s == null ? "" : s;
  }

  static final class FbTable extends Table {
    static FbTable root(ByteBuffer bb) {
      bb.order(ByteOrder.LITTLE_ENDIAN);
      int pos = bb.position();
      FbTable t = new FbTable();
      t.__reset(bb.getInt(pos) + pos, bb);
      return t;
    }

    static FbTable at(ByteBuffer bb, int pos) {
      FbTable t = new FbTable();
      t.__reset(pos, bb);
      return t;
    }

    int field(int slot) {
      return __offset(4 + slot * 2);
    }

    double f64(int slot) {
      int o = field(slot);
      return o == 0 ? 0.0 : bb.getDouble(o + bb_pos);
    }

    long i64(int slot) {
      int o = field(slot);
      return o == 0 ? 0L : bb.getLong(o + bb_pos);
    }

    int i32(int slot) {
      int o = field(slot);
      return o == 0 ? 0 : bb.getInt(o + bb_pos);
    }

    String str(int slot) {
      int o = field(slot);
      return o == 0 ? "" : __string(o + bb_pos);
    }

    FbTable table(int slot) {
      int o = field(slot);
      if (o == 0) return null;
      return at(bb, __indirect(o + bb_pos));
    }

    int vectorLen(int slot) {
      int o = field(slot);
      return o == 0 ? 0 : __vector_len(o);
    }

    FbTable vectorTable(int slot, int index) {
      int o = field(slot);
      return at(bb, __indirect(__vector(o) + index * 4));
    }
  }
}
