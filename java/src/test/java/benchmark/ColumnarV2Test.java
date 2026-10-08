package benchmark;

import benchmark.model.Fixture;
import benchmark.model.v2.Generators;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Rng;
import benchmark.model.v2.Signal;
import benchmark.model.v2.TableRow;
import benchmark.serializers.AbstractParquetSer;
import benchmark.serializers.BenchSerializer;
import benchmark.serializers.OrcSer;
import benchmark.serializers.OrcUncompressedSer;
import benchmark.serializers.ParquetSer;
import benchmark.serializers.ParquetUncompressedSer;
import benchmark.serializers.Registry;
import benchmark.serializers.SbeSer;
import org.apache.parquet.hadoop.metadata.CompressionCodecName;
import org.junit.jupiter.api.Test;

import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNotEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ColumnarV2Test {
  private static final String[] TYPES = {"table", "table_project", "nested_table", "signal"};
  private static final String ALLOW =
      "arrow-ipc,parquet,parquet-uncompressed,orc,orc-uncompressed,sbe,jackson,protobuf,flatbuffers,avro";

  @Test
  void deterministicAndDistinctSeeds() {
    for (String id : TYPES) {
      assertEquals(Generators.makeOne(id, Map.of(), 42L, 3), Generators.makeOne(id, Map.of(), 42L, 3));
      assertNotEquals(
          Generators.makeOne(id, Map.of(), 42L, 3), Generators.makeOne(id, Map.of(), 42L, 4));
    }
    assertNotEquals(
        Generators.makeOne("table", Map.of(), 42L, 0),
        Generators.makeOne("table_project", Map.of(), 42L, 0));
  }

  @Test
  void tableStringsRepeatAcrossFortyRows() {
    List<Object> rows = Generators.instances("table", Map.of(), 42L, 40);
    List<Object> again = Generators.instances("table", Map.of(), 42L, 40);
    assertEquals(rows, again);
    Set<String> uniq = new HashSet<>();
    for (Object o : rows) uniq.add(((TableRow) o).fStr0);
    assertTrue(uniq.size() < rows.size(), "unique f_str_0 " + uniq.size());
  }

  @Test
  void signalDomainOrderAndLegPad() {
    Signal s = (Signal) Generators.makeOne("signal", Map.of(), 9L, 0);
    Rng r = new Rng(Rng.mixSeed(9L, "signal", 0));
    assertEquals(r.nextInt(0, 1_000_000_000), s.seq);
    assertEquals(1_704_067_200_000L + r.nextInt(0, 86_400_000), s.ts);
    assertEquals(r.nextInt(0, 1_000_000_000), s.priceMantissa);
    assertEquals(r.nextInt(0, 10_000), s.qty);
    assertEquals(r.nextInt(0, 65_535), s.flags);
    assertEquals(r.word(3, 12), s.symbol);
    assertEquals(r.word(3, 12), s.venue);
    assertEquals(4, s.legs.size());
    for (Signal.SignalLeg leg : s.legs) {
      assertEquals(r.nextInt(0, 1_000_000), leg.legId);
      assertEquals(r.nextInt(0, 10_000), leg.legQty);
      assertEquals(0, leg.legPad);
    }
    Signal shortGroup =
        (Signal) Generators.makeOne("signal", Map.of("group_count", 2), 1L, 0);
    assertEquals(2, shortGroup.legs.size());
  }

  @Test
  void nestedDefaults() {
    NestedRow row = (NestedRow) Generators.makeOne("nested_table", Map.of(), 5L, 1);
    assertEquals(4, row.items.size());
    assertFalse(row.id.isEmpty());
    assertFalse(row.meta.region.isEmpty());
    assertTrue(row.status >= 0 && row.status <= 5);
    assertTrue(row.meta.version >= 1 && row.meta.version <= 10);
  }

  @Test
  void filterAllowListPreservesRegistryOrder() {
    List<String> names = Registry.names();
    assertEquals(27, names.size());
    assertEquals(names, Main.selectSerializerNames(names, ""));
    List<String> jackson = Main.selectSerializerNames(names, "jackson");
    assertTrue(jackson.contains("jackson"));
    assertTrue(jackson.contains("jackson-cbor"));
    assertTrue(jackson.size() > 1);
    assertEquals(List.of("jackson"), Main.selectSerializerNames(names, "jackson,"));
    assertEquals(List.of("orc", "orc-uncompressed"), Main.selectSerializerNames(names, "orc"));
    assertEquals(List.of("orc"), Main.selectSerializerNames(names, "orc,"));
    assertEquals(
        List.of(
            "jackson",
            "protobuf",
            "avro",
            "flatbuffers",
            "arrow-ipc",
            "parquet",
            "parquet-uncompressed",
            "orc",
            "orc-uncompressed",
            "sbe"),
        Main.selectSerializerNames(names, ALLOW));
  }

  @Test
  void roundTripNewRowsAndPeers() throws Exception {
    List<String> names =
        List.of(
            "arrow-ipc",
            "parquet",
            "parquet-uncompressed",
            "orc",
            "orc-uncompressed",
            "sbe",
            "jackson",
            "protobuf",
            "flatbuffers",
            "avro");
    List<BenchSerializer> sers = Registry.byNames(names);
    assertEquals(names, sers.stream().map(BenchSerializer::name).toList());
    for (String type : TYPES) {
      for (int n : new int[] {1, 100}) {
        Fixture fx = fixture(type, n);
        Object expected = Fidelity.expectedForFidelity(type, fx.value);
        for (BenchSerializer ser : sers) {
          if (!ser.supports(type)) {
            assertEquals("sbe", ser.name());
            assertEquals("nested_table", type);
            continue;
          }
          ser.prepare(fx);
          byte[] buf = ser.serializeBytes(fx);
          Object out = ser.toDomain(ser.deserializeBytes(buf));
          assertTrue(Fidelity.check(expected, out), ser.name() + " " + type + " N=" + n);
          if ("table_project".equals(type)) {
            assertTrue(out instanceof List<?>);
            assertEquals(n, ((List<?>) out).size());
          }
          ByteArrayOutputStream baos = new ByteArrayOutputStream();
          int written = ser.serializeStream(fx, baos);
          assertTrue(written >= 0);
          Object streamed =
              ser.toDomain(ser.deserializeStream(new ByteArrayInputStream(baos.toByteArray())));
          assertTrue(
              Fidelity.check(expected, streamed), "stream " + ser.name() + " " + type + " N=" + n);
        }
      }
    }
    assertFalse(new SbeSer().supports("nested_table"));
    assertFalse(new SbeSer().supports("message"));
    assertTrue(new SbeSer().supports("signal"));
  }

  @Test
  void orcPayloadsDifferAndParquetSetsSnappy() throws Exception {
    Fixture fx = fixture("table", 100);
    OrcSer orc = new OrcSer();
    OrcUncompressedSer raw = new OrcUncompressedSer();
    orc.prepare(fx);
    raw.prepare(fx);
    byte[] zstd = orc.serializeBytes(fx);
    byte[] none = raw.serializeBytes(fx);
    assertFalse(Arrays.equals(zstd, none), "orc and orc-uncompressed payloads match");

    ParquetSer parquet = new ParquetSer();
    ParquetUncompressedSer uncompressed = new ParquetUncompressedSer();
    parquet.prepare(fx);
    uncompressed.prepare(fx);
    byte[] def = parquet.serializeBytes(fx);
    byte[] unc = uncompressed.serializeBytes(fx);
    assertEquals(CompressionCodecName.SNAPPY, AbstractParquetSer.footerCodec(def));
    assertEquals(CompressionCodecName.UNCOMPRESSED, AbstractParquetSer.footerCodec(unc));
    assertFalse(Arrays.equals(def, unc));
  }

  @Test
  void projectionDeserializeTimes() throws Exception {
    int n = 10_000;
    int reps = 5;
    for (String name : List.of("arrow-ipc", "parquet", "orc")) {
      BenchSerializer ser = Registry.byNames(List.of(name)).get(0);
      long full = medianDeser(ser, "table", n, reps);
      long proj = medianDeser(ser, "table_project", n, reps);
      System.out.printf(
          "PROJECTION %s table_ns=%d table_project_ns=%d ratio=%.3f%n",
          name, full, proj, proj / (double) full);
    }
  }

  private static long medianDeser(BenchSerializer ser, String type, int n, int reps) throws Exception {
    Fixture fx = fixture(type, n);
    ser.prepare(fx);
    byte[] buf = ser.serializeBytes(fx);
    Object expected = Fidelity.expectedForFidelity(type, fx.value);
    ser.deserializeBytes(buf);
    long[] samples = new long[reps];
    for (int i = 0; i < reps; i++) {
      long t0 = System.nanoTime();
      Object out = ser.toDomain(ser.deserializeBytes(buf));
      samples[i] = System.nanoTime() - t0;
      assertTrue(Fidelity.check(expected, out), ser.name() + " " + type);
    }
    Arrays.sort(samples);
    return samples[samples.length / 2];
  }

  private static Fixture fixture(String type, int n) {
    List<Object> inst = Generators.instances(type, Map.of(), 42L, n);
    if (n == 1) return new Fixture(type, inst.get(0));
    return new Fixture(type, new ArrayList<>(inst));
  }
}
