package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.V2Rows;
import org.apache.avro.Schema;
import org.apache.avro.generic.GenericRecord;
import org.apache.avro.generic.IndexedRecord;
import org.apache.hadoop.conf.Configuration;
import org.apache.parquet.avro.AvroParquetReader;
import org.apache.parquet.avro.AvroParquetWriter;
import org.apache.parquet.avro.AvroReadSupport;
import org.apache.parquet.hadoop.ParquetFileReader;
import org.apache.parquet.hadoop.ParquetReader;
import org.apache.parquet.hadoop.ParquetWriter;
import org.apache.parquet.hadoop.metadata.CompressionCodecName;
import org.apache.parquet.io.InputFile;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * Parquet via parquet-avro.
 *
 * <p>parquet-java 1.18.1's {@link ParquetWriter#DEFAULT_COMPRESSION_CODEC_NAME} is
 * UNCOMPRESSED. {@code parquet} sets {@link CompressionCodecName#SNAPPY} so the suite name means
 * Snappy. {@code parquet-uncompressed} sets {@link CompressionCodecName#UNCOMPRESSED}.
 */
public abstract class AbstractParquetSer implements BenchSerializer {
  private static final Set<String> IDS =
      Set.of("table", "table_project", "nested_table", "signal");

  private final String rowName;
  private final boolean forceUncompressed;
  private String typeId;
  private boolean batch;
  private boolean project;
  private Schema schema;
  private Configuration writeConf;
  private Configuration readConf;

  protected AbstractParquetSer(String rowName, boolean forceUncompressed) {
    this.rowName = rowName;
    this.forceUncompressed = forceUncompressed;
  }

  @Override
  public String name() {
    return rowName;
  }

  @Override
  public String version() {
    return Versions.of(AvroParquetWriter.class);
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
    project = "table_project".equals(typeId);
    schema =
        switch (typeId) {
          case "table", "table_project" -> benchmark.v2.avro.Table.getClassSchema();
          case "nested_table" -> benchmark.v2.avro.NestedRow.getClassSchema();
          case "signal" -> benchmark.v2.avro.Signal.getClassSchema();
          default -> throw new IllegalArgumentException(typeId);
        };
    writeConf = new Configuration(false);
    readConf = new Configuration(false);
    if (project) {
      Schema projected = projectFloat0(schema);
      AvroReadSupport.setRequestedProjection(readConf, projected);
      AvroReadSupport.setAvroReadSchema(readConf, projected);
    }
  }

  @Override
  public byte[] serializeBytes(Fixture fx) throws Exception {
    MemOutputFile out = new MemOutputFile();
    var builder =
        AvroParquetWriter.<GenericRecord>builder(out)
            .withSchema(schema)
            .withDataModel(org.apache.avro.specific.SpecificData.get())
            .withConf(writeConf);
    builder.withCompressionCodec(
        forceUncompressed ? CompressionCodecName.UNCOMPRESSED : CompressionCodecName.SNAPPY);
    try (ParquetWriter<GenericRecord> writer = builder.build()) {
      for (GenericRecord rec : records(fx.value)) writer.write(rec);
    }
    return out.toByteArray();
  }

  @Override
  public Object deserializeBytes(byte[] data) throws Exception {
    InputFile in = new MemInputFile(data);
    try (ParquetReader<GenericRecord> reader =
        AvroParquetReader.<GenericRecord>builder(in)
            .withDataModel(
                project
                    ? org.apache.avro.generic.GenericData.get()
                    : org.apache.avro.specific.SpecificData.get())
            .withConf(readConf)
            .build()) {
      if (project) {
        List<Double> col = new ArrayList<>();
        GenericRecord rec;
        while ((rec = reader.read()) != null) {
          col.add(((Number) get(rec, "f_float_0")).doubleValue());
        }
        return col;
      }
      List<Object> rows = new ArrayList<>();
      GenericRecord rec;
      while ((rec = reader.read()) != null) rows.add(fromRecord(rec));
      return V2Rows.oneOrList(rows, batch);
    }
  }

  public static CompressionCodecName footerCodec(byte[] data) throws IOException {
    try (ParquetFileReader reader = ParquetFileReader.open(new MemInputFile(data))) {
      return reader.getFooter().getBlocks().get(0).getColumns().get(0).getCodec();
    }
  }

  private List<GenericRecord> records(Object value) {
    return switch (typeId) {
      case "table", "table_project" -> {
        List<GenericRecord> out = new ArrayList<>();
        for (TableRow row : V2Rows.tables(value)) out.add(tableRecord(row));
        yield out;
      }
      case "nested_table" -> {
        List<GenericRecord> out = new ArrayList<>();
        for (NestedRow row : V2Rows.nested(value)) out.add(nestedRecord(row));
        yield out;
      }
      case "signal" -> {
        List<GenericRecord> out = new ArrayList<>();
        for (Signal row : V2Rows.signals(value)) out.add(signalRecord(row));
        yield out;
      }
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static benchmark.v2.avro.Table tableRecord(TableRow row) {
    benchmark.v2.avro.Table rec = new benchmark.v2.avro.Table();
    put(rec, "f_float_0", row.fFloat0);
    put(rec, "f_float_1", row.fFloat1);
    put(rec, "f_float_2", row.fFloat2);
    put(rec, "f_float_3", row.fFloat3);
    put(rec, "f_float_4", row.fFloat4);
    put(rec, "f_float_5", row.fFloat5);
    put(rec, "f_float_6", row.fFloat6);
    put(rec, "f_float_7", row.fFloat7);
    put(rec, "f_float_8", row.fFloat8);
    put(rec, "f_float_9", row.fFloat9);
    put(rec, "f_float_10", row.fFloat10);
    put(rec, "f_float_11", row.fFloat11);
    put(rec, "f_float_12", row.fFloat12);
    put(rec, "f_float_13", row.fFloat13);
    put(rec, "f_float_14", row.fFloat14);
    put(rec, "f_float_15", row.fFloat15);
    put(rec, "f_int_0", row.fInt0);
    put(rec, "f_int_1", row.fInt1);
    put(rec, "f_int_2", row.fInt2);
    put(rec, "f_int_3", row.fInt3);
    put(rec, "f_str_0", nz(row.fStr0));
    put(rec, "f_str_1", nz(row.fStr1));
    return rec;
  }

  private static benchmark.v2.avro.NestedRow nestedRecord(NestedRow row) {
    benchmark.v2.avro.NestedMeta meta = new benchmark.v2.avro.NestedMeta();
    NestedRow.NestedMeta src = row.meta != null ? row.meta : new NestedRow.NestedMeta("", 0);
    put(meta, "region", nz(src.region));
    put(meta, "version", src.version);
    List<benchmark.v2.avro.NestedItem> items = new ArrayList<>();
    if (row.items != null) {
      for (NestedRow.NestedItem it : row.items) {
        benchmark.v2.avro.NestedItem rec = new benchmark.v2.avro.NestedItem();
        put(rec, "sku", nz(it.sku));
        put(rec, "qty", it.qty);
        put(rec, "price_minor", it.priceMinor);
        items.add(rec);
      }
    }
    benchmark.v2.avro.NestedRow rec = new benchmark.v2.avro.NestedRow();
    put(rec, "id", nz(row.id));
    put(rec, "status", row.status);
    put(rec, "meta", meta);
    put(rec, "items", items);
    return rec;
  }

  private static benchmark.v2.avro.Signal signalRecord(Signal row) {
    List<benchmark.v2.avro.SignalLeg> legs = new ArrayList<>();
    if (row.legs != null) {
      for (Signal.SignalLeg leg : row.legs) {
        benchmark.v2.avro.SignalLeg rec = new benchmark.v2.avro.SignalLeg();
        put(rec, "leg_id", leg.legId);
        put(rec, "leg_qty", leg.legQty);
        put(rec, "leg_pad", leg.legPad);
        legs.add(rec);
      }
    }
    benchmark.v2.avro.Signal rec = new benchmark.v2.avro.Signal();
    put(rec, "seq", row.seq);
    put(rec, "ts", row.ts);
    put(rec, "price_mantissa", row.priceMantissa);
    put(rec, "qty", row.qty);
    put(rec, "flags", row.flags);
    put(rec, "symbol", nz(row.symbol));
    put(rec, "venue", nz(row.venue));
    put(rec, "legs", legs);
    return rec;
  }

  private Object fromRecord(GenericRecord rec) {
    return switch (typeId) {
      case "table", "table_project" -> fromTable(rec);
      case "nested_table" -> fromNested(rec);
      case "signal" -> fromSignal(rec);
      default -> throw new IllegalArgumentException(typeId);
    };
  }

  private static TableRow fromTable(GenericRecord rec) {
    TableRow row = new TableRow();
    row.fFloat0 = num(get(rec, "f_float_0")).doubleValue();
    row.fFloat1 = num(get(rec, "f_float_1")).doubleValue();
    row.fFloat2 = num(get(rec, "f_float_2")).doubleValue();
    row.fFloat3 = num(get(rec, "f_float_3")).doubleValue();
    row.fFloat4 = num(get(rec, "f_float_4")).doubleValue();
    row.fFloat5 = num(get(rec, "f_float_5")).doubleValue();
    row.fFloat6 = num(get(rec, "f_float_6")).doubleValue();
    row.fFloat7 = num(get(rec, "f_float_7")).doubleValue();
    row.fFloat8 = num(get(rec, "f_float_8")).doubleValue();
    row.fFloat9 = num(get(rec, "f_float_9")).doubleValue();
    row.fFloat10 = num(get(rec, "f_float_10")).doubleValue();
    row.fFloat11 = num(get(rec, "f_float_11")).doubleValue();
    row.fFloat12 = num(get(rec, "f_float_12")).doubleValue();
    row.fFloat13 = num(get(rec, "f_float_13")).doubleValue();
    row.fFloat14 = num(get(rec, "f_float_14")).doubleValue();
    row.fFloat15 = num(get(rec, "f_float_15")).doubleValue();
    row.fInt0 = num(get(rec, "f_int_0")).longValue();
    row.fInt1 = num(get(rec, "f_int_1")).longValue();
    row.fInt2 = num(get(rec, "f_int_2")).longValue();
    row.fInt3 = num(get(rec, "f_int_3")).longValue();
    row.fStr0 = str(get(rec, "f_str_0"));
    row.fStr1 = str(get(rec, "f_str_1"));
    return row;
  }

  private static NestedRow fromNested(GenericRecord rec) {
    GenericRecord meta = (GenericRecord) get(rec, "meta");
    NestedRow row = new NestedRow();
    row.id = str(get(rec, "id"));
    row.status = num(get(rec, "status")).intValue();
    row.meta = new NestedRow.NestedMeta(str(get(meta, "region")), num(get(meta, "version")).intValue());
    Object items = get(rec, "items");
    if (items instanceof List<?> list) {
      for (Object o : list) {
        GenericRecord it = (GenericRecord) o;
        row.items.add(
            new NestedRow.NestedItem(
                str(get(it, "sku")),
                num(get(it, "qty")).intValue(),
                num(get(it, "price_minor")).longValue()));
      }
    }
    return row;
  }

  private static Signal fromSignal(GenericRecord rec) {
    Signal row = new Signal();
    row.seq = num(get(rec, "seq")).longValue();
    row.ts = num(get(rec, "ts")).longValue();
    row.priceMantissa = num(get(rec, "price_mantissa")).longValue();
    row.qty = num(get(rec, "qty")).intValue();
    row.flags = num(get(rec, "flags")).intValue();
    row.symbol = str(get(rec, "symbol"));
    row.venue = str(get(rec, "venue"));
    Object legs = get(rec, "legs");
    if (legs instanceof List<?> list) {
      for (Object o : list) {
        GenericRecord leg = (GenericRecord) o;
        row.legs.add(
            new Signal.SignalLeg(
                num(get(leg, "leg_id")).longValue(),
                num(get(leg, "leg_qty")).intValue(),
                num(get(leg, "leg_pad")).intValue()));
      }
    }
    return row;
  }

  private static Schema projectFloat0(Schema table) {
    Schema.Field src = table.getField("f_float_0");
    Schema.Field copy = new Schema.Field(src.name(), src.schema(), src.doc(), src.defaultVal());
    return Schema.createRecord(
        table.getName(), table.getDoc(), table.getNamespace(), false, List.of(copy));
  }

  private static void put(IndexedRecord rec, String name, Object value) {
    rec.put(rec.getSchema().getField(name).pos(), value);
  }

  private static Object get(IndexedRecord rec, String name) {
    return rec.get(rec.getSchema().getField(name).pos());
  }

  private static Number num(Object o) {
    if (o instanceof Number n) return n;
    throw new IllegalStateException("expected number, got " + o);
  }

  private static String str(Object o) {
    return o == null ? "" : o.toString();
  }

  private static String nz(String s) {
    return s == null ? "" : s;
  }
}
