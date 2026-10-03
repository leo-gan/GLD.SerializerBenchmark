package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.V2Rows;
import org.apache.hadoop.conf.Configuration;
import org.apache.hadoop.fs.Path;
import org.apache.orc.CompressionKind;
import org.apache.orc.OrcFile;
import org.apache.orc.Reader;
import org.apache.orc.RecordReader;
import org.apache.orc.TypeDescription;
import org.apache.orc.Writer;
import org.apache.orc.storage.ql.exec.vector.BytesColumnVector;
import org.apache.orc.storage.ql.exec.vector.ColumnVector;
import org.apache.orc.storage.ql.exec.vector.DoubleColumnVector;
import org.apache.orc.storage.ql.exec.vector.ListColumnVector;
import org.apache.orc.storage.ql.exec.vector.LongColumnVector;
import org.apache.orc.storage.ql.exec.vector.StructColumnVector;
import org.apache.orc.storage.ql.exec.vector.VectorizedRowBatch;

import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * ORC via orc-core.
 *
 * <p>ORC 2.3.1 {@code OrcConf.COMPRESS} defaults to ZSTD. {@code orc} does not call
 * {@code compress()}. {@code orc-uncompressed} sets {@link CompressionKind#NONE}. Both rows set
 * {@code blockPadding(false)} so the writer does not pad out to the default 256MB HDFS block.
 */
public abstract class AbstractOrcSer implements BenchSerializer {
  private static final Set<String> IDS =
      Set.of("table", "table_project", "nested_table", "signal");

  private final String rowName;
  private final boolean uncompressed;
  private String typeId;
  private boolean batch;
  private boolean project;
  private TypeDescription schema;
  private Configuration conf;
  private MemoryOrcFileSystem fs;
  private int seq;

  protected AbstractOrcSer(String rowName, boolean uncompressed) {
    this.rowName = rowName;
    this.uncompressed = uncompressed;
  }

  @Override
  public String name() {
    return rowName;
  }

  @Override
  public String version() {
    return Versions.of(OrcFile.class);
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
  public void prepare(Fixture fx) throws Exception {
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    project = "table_project".equals(typeId);
    schema =
        switch (typeId) {
          case "table", "table_project" -> tableSchema();
          case "nested_table" -> nestedSchema();
          case "signal" -> signalSchema();
          default -> throw new IllegalArgumentException(typeId);
        };
    if (conf == null) {
      conf = new Configuration(false);
      fs = new MemoryOrcFileSystem(conf);
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    Path path = new Path("mem:///w-" + (++seq) + ".orc");
    OrcFile.WriterOptions opts =
        OrcFile.writerOptions(conf).setSchema(schema).fileSystem(fs).blockPadding(false).overwrite(true);
    if (uncompressed) {
      opts.compress(CompressionKind.NONE);
    }
    try (Writer writer = OrcFile.createWriter(path, opts)) {
      VectorizedRowBatch rows = schema.createRowBatch();
      switch (typeId) {
        case "table", "table_project" -> writeTable(writer, rows, V2Rows.tables(fx.value));
        case "nested_table" -> writeNested(writer, rows, V2Rows.nested(fx.value));
        case "signal" -> writeSignal(writer, rows, V2Rows.signals(fx.value));
        default -> throw new IllegalArgumentException(typeId);
      }
    }
    return fs.take(path);
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    Path path = fs.putBytes(data);
    try (Reader reader = OrcFile.createReader(path, OrcFile.readerOptions(conf).filesystem(fs))) {
      TypeDescription fileSchema = reader.getSchema();
      Reader.Options options = reader.options();
      if (project) {
        boolean[] include = new boolean[fileSchema.getMaximumId() + 1];
        include[0] = true;
        include[fileSchema.getChildren().get(0).getId()] = true;
        options.include(include);
      }
      try (RecordReader rows = reader.rows(options)) {
        VectorizedRowBatch batchRows = fileSchema.createRowBatch();
        if (project) {
          List<Double> col = new ArrayList<>();
          while (rows.nextBatch(batchRows)) {
            DoubleColumnVector v = (DoubleColumnVector) batchRows.cols[0];
            for (int r = 0; r < batchRows.size; r++) col.add(dbl(v, r));
          }
          return col;
        }
        List<Object> out = new ArrayList<>();
        while (rows.nextBatch(batchRows)) {
          for (int r = 0; r < batchRows.size; r++) out.add(readRow(batchRows, r));
        }
        return V2Rows.oneOrList(out, batch);
      }
    } finally {
      fs.delete(path, false);
    }
  }

  private Object readRow(VectorizedRowBatch batchRows, int r) {
    return switch (typeId) {
      case "table", "table_project" -> readTable(batchRows, r);
      case "nested_table" -> readNested(batchRows, r);
      case "signal" -> readSignal(batchRows, r);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static void writeTable(Writer writer, VectorizedRowBatch batch, List<TableRow> rows)
      throws java.io.IOException {
    DoubleColumnVector[] floats = new DoubleColumnVector[16];
    LongColumnVector[] ints = new LongColumnVector[4];
    for (int i = 0; i < 16; i++) floats[i] = (DoubleColumnVector) batch.cols[i];
    for (int i = 0; i < 4; i++) ints[i] = (LongColumnVector) batch.cols[16 + i];
    BytesColumnVector s0 = (BytesColumnVector) batch.cols[20];
    BytesColumnVector s1 = (BytesColumnVector) batch.cols[21];
    for (TableRow row : rows) {
      int r = batch.size++;
      putDoubles(floats, r, row);
      ints[0].vector[r] = row.fInt0;
      ints[1].vector[r] = row.fInt1;
      ints[2].vector[r] = row.fInt2;
      ints[3].vector[r] = row.fInt3;
      s0.setVal(r, bytes(row.fStr0));
      s1.setVal(r, bytes(row.fStr1));
      if (batch.size == batch.getMaxSize()) {
        writer.addRowBatch(batch);
        batch.reset();
      }
    }
    if (batch.size != 0) writer.addRowBatch(batch);
  }

  private static void writeNested(Writer writer, VectorizedRowBatch batch, List<NestedRow> rows)
      throws java.io.IOException {
    BytesColumnVector ids = (BytesColumnVector) batch.cols[0];
    LongColumnVector status = (LongColumnVector) batch.cols[1];
    StructColumnVector meta = (StructColumnVector) batch.cols[2];
    BytesColumnVector region = (BytesColumnVector) meta.fields[0];
    LongColumnVector version = (LongColumnVector) meta.fields[1];
    ListColumnVector items = (ListColumnVector) batch.cols[3];
    StructColumnVector child = (StructColumnVector) items.child;
    BytesColumnVector sku = (BytesColumnVector) child.fields[0];
    LongColumnVector qty = (LongColumnVector) child.fields[1];
    LongColumnVector price = (LongColumnVector) child.fields[2];
    for (NestedRow row : rows) {
      int r = batch.size++;
      ids.setVal(r, bytes(row.id));
      status.vector[r] = row.status;
      NestedRow.NestedMeta m = row.meta != null ? row.meta : new NestedRow.NestedMeta("", 0);
      region.setVal(r, bytes(m.region));
      version.vector[r] = m.version;
      int n = row.items == null ? 0 : row.items.size();
      grow(child, items.childCount + n);
      int start = items.childCount;
      for (int j = 0; j < n; j++) {
        NestedRow.NestedItem it = row.items.get(j);
        int idx = start + j;
        sku.setVal(idx, bytes(it.sku));
        qty.vector[idx] = it.qty;
        price.vector[idx] = it.priceMinor;
      }
      items.offsets[r] = start;
      items.lengths[r] = n;
      items.childCount = start + n;
      if (batch.size == batch.getMaxSize()) {
        writer.addRowBatch(batch);
        batch.reset();
      }
    }
    if (batch.size != 0) writer.addRowBatch(batch);
  }

  private static void writeSignal(Writer writer, VectorizedRowBatch batch, List<Signal> rows)
      throws java.io.IOException {
    LongColumnVector seq = (LongColumnVector) batch.cols[0];
    LongColumnVector ts = (LongColumnVector) batch.cols[1];
    LongColumnVector price = (LongColumnVector) batch.cols[2];
    LongColumnVector qty = (LongColumnVector) batch.cols[3];
    LongColumnVector flags = (LongColumnVector) batch.cols[4];
    BytesColumnVector symbol = (BytesColumnVector) batch.cols[5];
    BytesColumnVector venue = (BytesColumnVector) batch.cols[6];
    ListColumnVector legs = (ListColumnVector) batch.cols[7];
    StructColumnVector child = (StructColumnVector) legs.child;
    LongColumnVector legId = (LongColumnVector) child.fields[0];
    LongColumnVector legQty = (LongColumnVector) child.fields[1];
    LongColumnVector legPad = (LongColumnVector) child.fields[2];
    for (Signal row : rows) {
      int r = batch.size++;
      seq.vector[r] = row.seq;
      ts.vector[r] = row.ts;
      price.vector[r] = row.priceMantissa;
      qty.vector[r] = row.qty;
      flags.vector[r] = row.flags;
      symbol.setVal(r, bytes(row.symbol));
      venue.setVal(r, bytes(row.venue));
      int n = row.legs == null ? 0 : row.legs.size();
      grow(child, legs.childCount + n);
      int start = legs.childCount;
      for (int j = 0; j < n; j++) {
        Signal.SignalLeg leg = row.legs.get(j);
        int idx = start + j;
        legId.vector[idx] = leg.legId;
        legQty.vector[idx] = leg.legQty;
        legPad.vector[idx] = 0;
      }
      legs.offsets[r] = start;
      legs.lengths[r] = n;
      legs.childCount = start + n;
      if (batch.size == batch.getMaxSize()) {
        writer.addRowBatch(batch);
        batch.reset();
      }
    }
    if (batch.size != 0) writer.addRowBatch(batch);
  }

  private static TableRow readTable(VectorizedRowBatch batch, int r) {
    TableRow row = new TableRow();
    row.fFloat0 = dbl((DoubleColumnVector) batch.cols[0], r);
    row.fFloat1 = dbl((DoubleColumnVector) batch.cols[1], r);
    row.fFloat2 = dbl((DoubleColumnVector) batch.cols[2], r);
    row.fFloat3 = dbl((DoubleColumnVector) batch.cols[3], r);
    row.fFloat4 = dbl((DoubleColumnVector) batch.cols[4], r);
    row.fFloat5 = dbl((DoubleColumnVector) batch.cols[5], r);
    row.fFloat6 = dbl((DoubleColumnVector) batch.cols[6], r);
    row.fFloat7 = dbl((DoubleColumnVector) batch.cols[7], r);
    row.fFloat8 = dbl((DoubleColumnVector) batch.cols[8], r);
    row.fFloat9 = dbl((DoubleColumnVector) batch.cols[9], r);
    row.fFloat10 = dbl((DoubleColumnVector) batch.cols[10], r);
    row.fFloat11 = dbl((DoubleColumnVector) batch.cols[11], r);
    row.fFloat12 = dbl((DoubleColumnVector) batch.cols[12], r);
    row.fFloat13 = dbl((DoubleColumnVector) batch.cols[13], r);
    row.fFloat14 = dbl((DoubleColumnVector) batch.cols[14], r);
    row.fFloat15 = dbl((DoubleColumnVector) batch.cols[15], r);
    row.fInt0 = lng((LongColumnVector) batch.cols[16], r);
    row.fInt1 = lng((LongColumnVector) batch.cols[17], r);
    row.fInt2 = lng((LongColumnVector) batch.cols[18], r);
    row.fInt3 = lng((LongColumnVector) batch.cols[19], r);
    row.fStr0 = str((BytesColumnVector) batch.cols[20], r);
    row.fStr1 = str((BytesColumnVector) batch.cols[21], r);
    return row;
  }

  private static NestedRow readNested(VectorizedRowBatch batch, int r) {
    StructColumnVector meta = (StructColumnVector) batch.cols[2];
    ListColumnVector items = (ListColumnVector) batch.cols[3];
    StructColumnVector child = (StructColumnVector) items.child;
    NestedRow row = new NestedRow();
    row.id = str((BytesColumnVector) batch.cols[0], r);
    row.status = (int) lng((LongColumnVector) batch.cols[1], r);
    row.meta =
        new NestedRow.NestedMeta(
            str((BytesColumnVector) meta.fields[0], r),
            (int) lng((LongColumnVector) meta.fields[1], r));
    int n = (int) items.lengths[r];
    int start = (int) items.offsets[r];
    for (int j = 0; j < n; j++) {
      int idx = start + j;
      row.items.add(
          new NestedRow.NestedItem(
              str((BytesColumnVector) child.fields[0], idx),
              (int) lng((LongColumnVector) child.fields[1], idx),
              lng((LongColumnVector) child.fields[2], idx)));
    }
    return row;
  }

  private static Signal readSignal(VectorizedRowBatch batch, int r) {
    ListColumnVector legs = (ListColumnVector) batch.cols[7];
    StructColumnVector child = (StructColumnVector) legs.child;
    Signal row = new Signal();
    row.seq = lng((LongColumnVector) batch.cols[0], r);
    row.ts = lng((LongColumnVector) batch.cols[1], r);
    row.priceMantissa = lng((LongColumnVector) batch.cols[2], r);
    row.qty = (int) lng((LongColumnVector) batch.cols[3], r);
    row.flags = (int) lng((LongColumnVector) batch.cols[4], r);
    row.symbol = str((BytesColumnVector) batch.cols[5], r);
    row.venue = str((BytesColumnVector) batch.cols[6], r);
    int n = (int) legs.lengths[r];
    int start = (int) legs.offsets[r];
    for (int j = 0; j < n; j++) {
      int idx = start + j;
      row.legs.add(
          new Signal.SignalLeg(
              lng((LongColumnVector) child.fields[0], idx),
              (int) lng((LongColumnVector) child.fields[1], idx),
              (int) lng((LongColumnVector) child.fields[2], idx)));
    }
    return row;
  }

  private static void putDoubles(DoubleColumnVector[] cols, int r, TableRow row) {
    cols[0].vector[r] = row.fFloat0;
    cols[1].vector[r] = row.fFloat1;
    cols[2].vector[r] = row.fFloat2;
    cols[3].vector[r] = row.fFloat3;
    cols[4].vector[r] = row.fFloat4;
    cols[5].vector[r] = row.fFloat5;
    cols[6].vector[r] = row.fFloat6;
    cols[7].vector[r] = row.fFloat7;
    cols[8].vector[r] = row.fFloat8;
    cols[9].vector[r] = row.fFloat9;
    cols[10].vector[r] = row.fFloat10;
    cols[11].vector[r] = row.fFloat11;
    cols[12].vector[r] = row.fFloat12;
    cols[13].vector[r] = row.fFloat13;
    cols[14].vector[r] = row.fFloat14;
    cols[15].vector[r] = row.fFloat15;
  }

  private static void grow(ColumnVector child, int size) {
    if (size > 0) child.ensureSize(size, true);
  }

  private static double dbl(DoubleColumnVector v, int row) {
    if (v.isRepeating) row = 0;
    return v.vector[row];
  }

  private static long lng(LongColumnVector v, int row) {
    if (v.isRepeating) row = 0;
    return v.vector[row];
  }

  private static String str(BytesColumnVector v, int row) {
    if (v.isRepeating) row = 0;
    if (!v.noNulls && v.isNull[row]) return "";
    String s = v.toString(row);
    return s == null ? "" : s;
  }

  private static byte[] bytes(String s) {
    return (s == null ? "" : s).getBytes(StandardCharsets.UTF_8);
  }

  private static TypeDescription tableSchema() {
    TypeDescription schema = TypeDescription.createStruct();
    for (int i = 0; i < 16; i++) schema.addField("f_float_" + i, TypeDescription.createDouble());
    for (int i = 0; i < 4; i++) schema.addField("f_int_" + i, TypeDescription.createLong());
    schema.addField("f_str_0", TypeDescription.createString());
    schema.addField("f_str_1", TypeDescription.createString());
    return schema;
  }

  private static TypeDescription nestedSchema() {
    TypeDescription meta =
        TypeDescription.createStruct()
            .addField("region", TypeDescription.createString())
            .addField("version", TypeDescription.createInt());
    TypeDescription item =
        TypeDescription.createStruct()
            .addField("sku", TypeDescription.createString())
            .addField("qty", TypeDescription.createInt())
            .addField("price_minor", TypeDescription.createLong());
    return TypeDescription.createStruct()
        .addField("id", TypeDescription.createString())
        .addField("status", TypeDescription.createInt())
        .addField("meta", meta)
        .addField("items", TypeDescription.createList(item));
  }

  private static TypeDescription signalSchema() {
    TypeDescription leg =
        TypeDescription.createStruct()
            .addField("leg_id", TypeDescription.createLong())
            .addField("leg_qty", TypeDescription.createInt())
            .addField("leg_pad", TypeDescription.createInt());
    return TypeDescription.createStruct()
        .addField("seq", TypeDescription.createLong())
        .addField("ts", TypeDescription.createLong())
        .addField("price_mantissa", TypeDescription.createLong())
        .addField("qty", TypeDescription.createInt())
        .addField("flags", TypeDescription.createInt())
        .addField("symbol", TypeDescription.createString())
        .addField("venue", TypeDescription.createString())
        .addField("legs", TypeDescription.createList(leg));
  }
}
