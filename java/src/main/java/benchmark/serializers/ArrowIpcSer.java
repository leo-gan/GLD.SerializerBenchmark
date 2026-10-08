package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.V2Rows;
import org.apache.arrow.memory.ArrowBuf;
import org.apache.arrow.memory.BufferAllocator;
import org.apache.arrow.memory.RootAllocator;
import org.apache.arrow.vector.BigIntVector;
import org.apache.arrow.vector.FieldVector;
import org.apache.arrow.vector.Float8Vector;
import org.apache.arrow.vector.IntVector;
import org.apache.arrow.vector.TypeLayout;
import org.apache.arrow.vector.VarCharVector;
import org.apache.arrow.vector.VectorLoader;
import org.apache.arrow.vector.VectorSchemaRoot;
import org.apache.arrow.vector.complex.ListVector;
import org.apache.arrow.vector.complex.StructVector;
import org.apache.arrow.vector.dictionary.DictionaryProvider;
import org.apache.arrow.vector.ipc.ArrowStreamReader;
import org.apache.arrow.vector.ipc.ArrowStreamWriter;
import org.apache.arrow.vector.ipc.ReadChannel;
import org.apache.arrow.vector.ipc.message.ArrowFieldNode;
import org.apache.arrow.vector.ipc.message.ArrowRecordBatch;
import org.apache.arrow.vector.ipc.message.MessageChannelReader;
import org.apache.arrow.vector.ipc.message.MessageResult;
import org.apache.arrow.vector.ipc.message.MessageSerializer;
import org.apache.arrow.vector.types.FloatingPointPrecision;
import org.apache.arrow.vector.types.pojo.ArrowType;
import org.apache.arrow.vector.types.pojo.Field;
import org.apache.arrow.vector.types.pojo.FieldType;
import org.apache.arrow.vector.types.pojo.Schema;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.channels.Channels;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Arrow IPC stream ({@link ArrowStreamWriter} / {@link ArrowStreamReader}), not the file format.
 * {@code table_project} loads only the {@code f_float_0} node and its buffers.
 */
public final class ArrowIpcSer implements BenchSerializer {
  private static final Set<String> IDS =
      Set.of("table", "table_project", "nested_table", "signal");
  private static final ArrowType F64 = new ArrowType.FloatingPoint(FloatingPointPrecision.DOUBLE);
  private static final ArrowType I64 = new ArrowType.Int(64, true);
  private static final ArrowType I32 = new ArrowType.Int(32, true);
  private static final ArrowType UTF8 = new ArrowType.Utf8();

  private static final Schema TABLE = new Schema(tableFields());
  private static final Schema NESTED = new Schema(nestedFields());
  private static final Schema SIGNAL = new Schema(signalFields());
  private static final Schema FLOAT0 = new Schema(List.of(TABLE.getFields().get(0)));

  private String typeId;
  private boolean batch;
  private BufferAllocator allocator;

  @Override
  public String name() {
    return "arrow-ipc";
  }

  @Override
  public String version() {
    return Versions.of(VectorSchemaRoot.class);
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  public boolean supports(String testDataName) {
    return IDS.contains(testDataName);
  }

  @Override
  public void prepare(Fixture fx) {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    allocator();
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    Schema schema =
        switch (typeId) {
          case "table", "table_project" -> TABLE;
          case "nested_table" -> NESTED;
          case "signal" -> SIGNAL;
          default -> throw new IllegalArgumentException(typeId);
        };
    ByteArrayOutputStream bos = new ByteArrayOutputStream();
    try (VectorSchemaRoot root = VectorSchemaRoot.create(schema, allocator())) {
      switch (typeId) {
        case "table", "table_project" -> fillTable(root, V2Rows.tables(fx.value));
        case "nested_table" -> fillNested(root, V2Rows.nested(fx.value));
        case "signal" -> fillSignal(root, V2Rows.signals(fx.value));
        default -> throw new IllegalArgumentException(typeId);
      }
      try (ArrowStreamWriter writer =
          new ArrowStreamWriter(root, new DictionaryProvider.MapDictionaryProvider(), bos)) {
        writer.start();
        writer.writeBatch();
        writer.end();
      }
    }
    return bos.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    if ("table_project".equals(typeId)) return readFloat0(data);
    try (ArrowStreamReader reader = new ArrowStreamReader(new ByteArrayInputStream(data), allocator())) {
      VectorSchemaRoot root = reader.getVectorSchemaRoot();
      List<Object> rows = new ArrayList<>();
      while (reader.loadNextBatch()) {
        int n = root.getRowCount();
        for (int i = 0; i < n; i++) rows.add(readRow(root, i));
      }
      return V2Rows.oneOrList(rows, batch);
    }
  }

  private List<Double> readFloat0(byte[] data) throws Exception {
    List<Double> out = new ArrayList<>();
    try (MessageChannelReader reader =
        new MessageChannelReader(
            new ReadChannel(Channels.newChannel(new ByteArrayInputStream(data))), allocator())) {
      MessageResult schemaResult = reader.readNext();
      if (schemaResult == null) throw new IllegalStateException("empty arrow stream");
      MessageSerializer.deserializeSchema(schemaResult.getMessage());
      ArrowBuf schemaBody = schemaResult.getBodyBuffer();
      if (schemaBody != null) schemaBody.close();
      MessageResult result;
      while ((result = reader.readNext()) != null) {
        ArrowBuf body = result.getBodyBuffer();
        try (ArrowRecordBatch full =
            MessageSerializer.deserializeRecordBatch(result.getMessage(), body)) {
          int bufferCount = TypeLayout.getTypeBufferCount(FLOAT0.getFields().get(0).getType());
          List<ArrowBuf> bufs = new ArrayList<>(bufferCount);
          for (int i = 0; i < bufferCount; i++) bufs.add(full.getBuffers().get(i));
          List<ArrowFieldNode> nodes = List.of(full.getNodes().get(0));
          try (ArrowRecordBatch slice = new ArrowRecordBatch(full.getLength(), nodes, bufs);
              VectorSchemaRoot one = VectorSchemaRoot.create(FLOAT0, allocator())) {
            new VectorLoader(one).load(slice);
            Float8Vector values = (Float8Vector) one.getVector(0);
            for (int i = 0; i < one.getRowCount(); i++) out.add(values.get(i));
          }
        }
      }
    }
    return out;
  }

  private Object readRow(VectorSchemaRoot root, int i) {
    return switch (typeId) {
      case "table", "table_project" -> readTable(root, i);
      case "nested_table" -> readNested(root, i);
      case "signal" -> readSignal(root, i);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private void fillTable(VectorSchemaRoot root, List<TableRow> rows) {
    int n = rows.size();
    alloc(root, n);
    Float8Vector[] floats = new Float8Vector[16];
    BigIntVector[] ints = new BigIntVector[4];
    for (int c = 0; c < 16; c++) floats[c] = (Float8Vector) root.getVector("f_float_" + c);
    for (int c = 0; c < 4; c++) ints[c] = (BigIntVector) root.getVector("f_int_" + c);
    VarCharVector s0 = (VarCharVector) root.getVector("f_str_0");
    VarCharVector s1 = (VarCharVector) root.getVector("f_str_1");
    for (int r = 0; r < n; r++) {
      TableRow row = rows.get(r);
      floats[0].setSafe(r, row.fFloat0);
      floats[1].setSafe(r, row.fFloat1);
      floats[2].setSafe(r, row.fFloat2);
      floats[3].setSafe(r, row.fFloat3);
      floats[4].setSafe(r, row.fFloat4);
      floats[5].setSafe(r, row.fFloat5);
      floats[6].setSafe(r, row.fFloat6);
      floats[7].setSafe(r, row.fFloat7);
      floats[8].setSafe(r, row.fFloat8);
      floats[9].setSafe(r, row.fFloat9);
      floats[10].setSafe(r, row.fFloat10);
      floats[11].setSafe(r, row.fFloat11);
      floats[12].setSafe(r, row.fFloat12);
      floats[13].setSafe(r, row.fFloat13);
      floats[14].setSafe(r, row.fFloat14);
      floats[15].setSafe(r, row.fFloat15);
      ints[0].setSafe(r, row.fInt0);
      ints[1].setSafe(r, row.fInt1);
      ints[2].setSafe(r, row.fInt2);
      ints[3].setSafe(r, row.fInt3);
      s0.setSafe(r, bytes(row.fStr0));
      s1.setSafe(r, bytes(row.fStr1));
    }
    root.setRowCount(n);
  }

  private void fillNested(VectorSchemaRoot root, List<NestedRow> rows) {
    int n = rows.size();
    int children = 0;
    for (NestedRow row : rows) children += row.items == null ? 0 : row.items.size();
    alloc(root, n);
    ListVector items = (ListVector) root.getVector("items");
    allocList(items, n, children);
    VarCharVector ids = (VarCharVector) root.getVector("id");
    IntVector status = (IntVector) root.getVector("status");
    StructVector meta = (StructVector) root.getVector("meta");
    VarCharVector region = meta.getChild("region", VarCharVector.class);
    IntVector version = meta.getChild("version", IntVector.class);
    StructVector child = (StructVector) items.getDataVector();
    VarCharVector sku = child.getChild("sku", VarCharVector.class);
    IntVector qty = child.getChild("qty", IntVector.class);
    BigIntVector price = child.getChild("price_minor", BigIntVector.class);
    for (int r = 0; r < n; r++) {
      NestedRow row = rows.get(r);
      ids.setSafe(r, bytes(row.id));
      status.setSafe(r, row.status);
      meta.setIndexDefined(r);
      NestedRow.NestedMeta m = row.meta != null ? row.meta : new NestedRow.NestedMeta("", 0);
      region.setSafe(r, bytes(m.region));
      version.setSafe(r, m.version);
      int count = row.items == null ? 0 : row.items.size();
      int start = items.startNewValue(r);
      for (int j = 0; j < count; j++) {
        NestedRow.NestedItem it = row.items.get(j);
        int idx = start + j;
        child.setIndexDefined(idx);
        sku.setSafe(idx, bytes(it.sku));
        qty.setSafe(idx, it.qty);
        price.setSafe(idx, it.priceMinor);
      }
      items.endValue(r, count);
    }
    root.setRowCount(n);
  }

  private void fillSignal(VectorSchemaRoot root, List<Signal> rows) {
    int n = rows.size();
    int children = 0;
    for (Signal row : rows) children += row.legs == null ? 0 : row.legs.size();
    alloc(root, n);
    ListVector legs = (ListVector) root.getVector("legs");
    allocList(legs, n, children);
    BigIntVector seq = (BigIntVector) root.getVector("seq");
    BigIntVector ts = (BigIntVector) root.getVector("ts");
    BigIntVector price = (BigIntVector) root.getVector("price_mantissa");
    IntVector qty = (IntVector) root.getVector("qty");
    IntVector flags = (IntVector) root.getVector("flags");
    VarCharVector symbol = (VarCharVector) root.getVector("symbol");
    VarCharVector venue = (VarCharVector) root.getVector("venue");
    StructVector child = (StructVector) legs.getDataVector();
    BigIntVector legId = child.getChild("leg_id", BigIntVector.class);
    IntVector legQty = child.getChild("leg_qty", IntVector.class);
    IntVector legPad = child.getChild("leg_pad", IntVector.class);
    for (int r = 0; r < n; r++) {
      Signal row = rows.get(r);
      seq.setSafe(r, row.seq);
      ts.setSafe(r, row.ts);
      price.setSafe(r, row.priceMantissa);
      qty.setSafe(r, row.qty);
      flags.setSafe(r, row.flags);
      symbol.setSafe(r, bytes(row.symbol));
      venue.setSafe(r, bytes(row.venue));
      int count = row.legs == null ? 0 : row.legs.size();
      int start = legs.startNewValue(r);
      for (int j = 0; j < count; j++) {
        Signal.SignalLeg leg = row.legs.get(j);
        int idx = start + j;
        child.setIndexDefined(idx);
        legId.setSafe(idx, leg.legId);
        legQty.setSafe(idx, leg.legQty);
        legPad.setSafe(idx, 0);
      }
      legs.endValue(r, count);
    }
    root.setRowCount(n);
  }

  private static TableRow readTable(VectorSchemaRoot root, int i) {
    TableRow row = new TableRow();
    row.fFloat0 = ((Float8Vector) root.getVector("f_float_0")).get(i);
    row.fFloat1 = ((Float8Vector) root.getVector("f_float_1")).get(i);
    row.fFloat2 = ((Float8Vector) root.getVector("f_float_2")).get(i);
    row.fFloat3 = ((Float8Vector) root.getVector("f_float_3")).get(i);
    row.fFloat4 = ((Float8Vector) root.getVector("f_float_4")).get(i);
    row.fFloat5 = ((Float8Vector) root.getVector("f_float_5")).get(i);
    row.fFloat6 = ((Float8Vector) root.getVector("f_float_6")).get(i);
    row.fFloat7 = ((Float8Vector) root.getVector("f_float_7")).get(i);
    row.fFloat8 = ((Float8Vector) root.getVector("f_float_8")).get(i);
    row.fFloat9 = ((Float8Vector) root.getVector("f_float_9")).get(i);
    row.fFloat10 = ((Float8Vector) root.getVector("f_float_10")).get(i);
    row.fFloat11 = ((Float8Vector) root.getVector("f_float_11")).get(i);
    row.fFloat12 = ((Float8Vector) root.getVector("f_float_12")).get(i);
    row.fFloat13 = ((Float8Vector) root.getVector("f_float_13")).get(i);
    row.fFloat14 = ((Float8Vector) root.getVector("f_float_14")).get(i);
    row.fFloat15 = ((Float8Vector) root.getVector("f_float_15")).get(i);
    row.fInt0 = ((BigIntVector) root.getVector("f_int_0")).get(i);
    row.fInt1 = ((BigIntVector) root.getVector("f_int_1")).get(i);
    row.fInt2 = ((BigIntVector) root.getVector("f_int_2")).get(i);
    row.fInt3 = ((BigIntVector) root.getVector("f_int_3")).get(i);
    row.fStr0 = utf8((VarCharVector) root.getVector("f_str_0"), i);
    row.fStr1 = utf8((VarCharVector) root.getVector("f_str_1"), i);
    return row;
  }

  private static NestedRow readNested(VectorSchemaRoot root, int i) {
    StructVector meta = (StructVector) root.getVector("meta");
    ListVector items = (ListVector) root.getVector("items");
    StructVector child = (StructVector) items.getDataVector();
    NestedRow row = new NestedRow();
    row.id = utf8((VarCharVector) root.getVector("id"), i);
    row.status = ((IntVector) root.getVector("status")).get(i);
    row.meta =
        new NestedRow.NestedMeta(
            utf8(meta.getChild("region", VarCharVector.class), i),
            meta.getChild("version", IntVector.class).get(i));
    int start = items.getElementStartIndex(i);
    int end = items.getElementEndIndex(i);
    for (int idx = start; idx < end; idx++) {
      row.items.add(
          new NestedRow.NestedItem(
              utf8(child.getChild("sku", VarCharVector.class), idx),
              child.getChild("qty", IntVector.class).get(idx),
              child.getChild("price_minor", BigIntVector.class).get(idx)));
    }
    return row;
  }

  private static Signal readSignal(VectorSchemaRoot root, int i) {
    ListVector legs = (ListVector) root.getVector("legs");
    StructVector child = (StructVector) legs.getDataVector();
    Signal row = new Signal();
    row.seq = ((BigIntVector) root.getVector("seq")).get(i);
    row.ts = ((BigIntVector) root.getVector("ts")).get(i);
    row.priceMantissa = ((BigIntVector) root.getVector("price_mantissa")).get(i);
    row.qty = ((IntVector) root.getVector("qty")).get(i);
    row.flags = ((IntVector) root.getVector("flags")).get(i);
    row.symbol = utf8((VarCharVector) root.getVector("symbol"), i);
    row.venue = utf8((VarCharVector) root.getVector("venue"), i);
    int start = legs.getElementStartIndex(i);
    int end = legs.getElementEndIndex(i);
    for (int idx = start; idx < end; idx++) {
      row.legs.add(
          new Signal.SignalLeg(
              child.getChild("leg_id", BigIntVector.class).get(idx),
              child.getChild("leg_qty", IntVector.class).get(idx),
              child.getChild("leg_pad", IntVector.class).get(idx)));
    }
    return row;
  }

  private static void alloc(VectorSchemaRoot root, int rows) {
    for (FieldVector v : root.getFieldVectors()) {
      v.setInitialCapacity(Math.max(rows, 1));
      v.allocateNew();
    }
  }

  private static void allocList(ListVector list, int rows, int children) {
    list.setInitialCapacity(Math.max(rows, 1));
    list.allocateNew();
    FieldVector data = list.getDataVector();
    data.setInitialCapacity(Math.max(children, 1));
    data.allocateNew();
  }

  private BufferAllocator allocator() {
    if (allocator == null) allocator = new RootAllocator(Long.MAX_VALUE);
    return allocator;
  }

  private static byte[] bytes(String s) {
    return (s == null ? "" : s).getBytes(StandardCharsets.UTF_8);
  }

  private static String utf8(VarCharVector v, int i) {
    if (v.isNull(i)) return "";
    byte[] b = v.get(i);
    return b == null ? "" : new String(b, StandardCharsets.UTF_8);
  }

  private static Field field(String name, ArrowType type) {
    return new Field(name, FieldType.nullable(type), null);
  }

  private static Field struct(String name, List<Field> children) {
    return new Field(name, FieldType.nullable(new ArrowType.Struct()), children);
  }

  private static Field list(String name, Field child) {
    return new Field(name, FieldType.nullable(new ArrowType.List()), List.of(child));
  }

  private static List<Field> tableFields() {
    List<Field> fields = new ArrayList<>();
    for (int i = 0; i < 16; i++) fields.add(field("f_float_" + i, F64));
    for (int i = 0; i < 4; i++) fields.add(field("f_int_" + i, I64));
    fields.add(field("f_str_0", UTF8));
    fields.add(field("f_str_1", UTF8));
    return fields;
  }

  private static List<Field> nestedFields() {
    return List.of(
        field("id", UTF8),
        field("status", I32),
        struct("meta", List.of(field("region", UTF8), field("version", I32))),
        list(
            "items",
            struct(
                "item",
                List.of(field("sku", UTF8), field("qty", I32), field("price_minor", I64)))));
  }

  private static List<Field> signalFields() {
    return List.of(
        field("seq", I64),
        field("ts", I64),
        field("price_mantissa", I64),
        field("qty", I32),
        field("flags", I32),
        field("symbol", UTF8),
        field("venue", UTF8),
        list(
            "legs",
            struct(
                "item",
                List.of(field("leg_id", I64), field("leg_qty", I32), field("leg_pad", I32)))));
  }
}
