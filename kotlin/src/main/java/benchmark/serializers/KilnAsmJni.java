package benchmark.serializers;

import java.nio.file.Files;
import java.nio.file.Path;

/**
 * Shared JNI bridge to {@code build/kiln-asm/libkiln_asm_jni.so} (statically linking
 * {@code libkiln_asm_bench.a}, gld-kiln-asm 0.2.0). Used by both Java and Kotlin harnesses.
 */
public final class KilnAsmJni {
  public static final String VERSION = "0.2.0";

  private static volatile boolean loaded;

  private KilnAsmJni() {}

  public static void ensureLoaded() {
    if (loaded) return;
    synchronized (KilnAsmJni.class) {
      if (loaded) return;
      String envPath = System.getenv("KILN_ASM_JNI_LIB");
      if (envPath != null && !envPath.isEmpty() && Files.isRegularFile(Path.of(envPath))) {
        System.load(Path.of(envPath).toAbsolutePath().toString());
        loaded = true;
        return;
      }
      Path dir = Path.of("").toAbsolutePath();
      for (int i = 0; i < 10 && dir != null; i++) {
        Path cand = dir.resolve("build/kiln-asm/libkiln_asm_jni.so");
        if (Files.isRegularFile(cand)) {
          System.load(cand.toAbsolutePath().toString());
          loaded = true;
          return;
        }
        dir = dir.getParent();
      }
      System.loadLibrary("kiln_asm_jni");
      loaded = true;
    }
  }

  /** Map a compliance/data/kiln/v2.json schema value (String or Map.toString()) to JNI tag. */
  public static int schemaTag(String schemaText) {
    if (schemaText == null) return -1;
    if ("tensor-v2".equals(schemaText)) return 0;
    if ("frame".equals(schemaText)) return 1;
    if (schemaText.contains("type=struct") || schemaText.contains("\"struct\"")) return 2;
    if (schemaText.contains("type=list") || schemaText.contains("\"list\"")) {
      if (schemaText.contains("f32")) return 3;
      if (schemaText.contains("str") && !schemaText.contains("struct")) return 4;
      if (schemaText.contains("struct{a:i64}")) return 5;
    }
    return -1;
  }

  public static native byte[] encodeMessage(
      boolean b1, int i1, long l1, double d1, byte[] s1, boolean b2, int i2, byte[] s2);

  public static native byte[] encodeMessageBatch(
      int n,
      byte[] bools2n,
      int[] ints2n,
      long[] longs,
      double[] doubles,
      byte[] strUtf8,
      int strLen,
      int[] strLens2n);

  public static native int decodeMessage(
      boolean batch,
      byte[] wire,
      byte[] outBools2n,
      int[] outInts6n,
      long[] outLongs,
      double[] outDoubles);

  public static native byte[] encodeDocument(
      boolean nested,
      boolean batch,
      int n,
      int[] docMeta3n,
      int[] itemQtys,
      long[] itemPrices,
      byte[] strUtf8,
      int strLen,
      int[] strLens);

  public static native int decodeDocument(
      boolean nested,
      boolean batch,
      byte[] wire,
      int[] outDocInts7n,
      int[] outItemInts3m,
      long[] outItemPrices);

  public static native byte[] encodeTelemetry(
      boolean batch,
      int n,
      long[] ts,
      int[] counts2n,
      double[] vals,
      byte[] strUtf8,
      int strLen,
      int[] strLens);

  public static native int decodeTelemetry(
      boolean batch,
      byte[] wire,
      long[] outTs,
      int[] outCounts2n,
      int[] outStrOffLen,
      double[] outVals);

  public static native byte[] encodeStrings(
      boolean batch, int n, int[] counts, byte[] strUtf8, int strLen, int[] strLens);

  public static native int decodeStrings(
      boolean batch, byte[] wire, int[] outCounts, int[] outStrOffLen);

  public static native byte[] encodeEvent(
      boolean batch,
      int n,
      long[] occurredAt,
      int[] attrCounts,
      byte[] strUtf8,
      int strLen,
      int[] strLens);

  public static native int decodeEvent(
      boolean batch, byte[] wire, long[] outOccurredAt, int[] outAttrCounts, int[] outStrOffLen);

  public static native byte[] encodeSignal(
      boolean batch,
      int n,
      long[] longs3n,
      int[] ints3n,
      long[] legIds,
      int[] legInts2m,
      byte[] strUtf8,
      int strLen,
      int[] strLens2n);

  public static native int decodeSignal(
      boolean batch,
      byte[] wire,
      long[] outLongs3n,
      int[] outInts7n,
      long[] outLegIds,
      int[] outLegInts2m);

  public static native byte[] encodeTableColumns(
      int n,
      double[] floats16n,
      long[] ints4n,
      byte[] strUtf8,
      int strLen,
      int[] strLens2n);

  public static native int decodeTableColumns(
      byte[] wire, double[] outFloats16n, long[] outInts4n, int[] outStrOffLen4n);

  public static native double[] decodeTableProject(byte[] wire);

  public static native byte[] encodeTensor(int rows, int cols, float[] values);

  public static native float[] decodeTensor(byte[] wire, int[] outShape2);

  public static native int decodeTensorView(byte[] wire, int[] outMeta4);

  public static native byte[] encodePrompt(
      int batch, int seq, long[] ids, long[] mask, long[] pos);

  public static native int decodePrompt(byte[] wire, int[] outMeta2, long[][] outArrays3);

  public static native byte[] encodeShard(
      int vocab, int hidden, int ffn, float[] tok, float[] attn, float[] ffnW, float[] norm);

  public static native int decodeShard(byte[] wire, int[] outDims3, float[][] outArrays4);

  public static native byte[] encodeRequest(
      long reqId,
      byte[] modelUtf8,
      float temp,
      int batch,
      int seq,
      long[] ids,
      long[] mask,
      long[] pos);

  public static native int decodeRequest(
      byte[] wire,
      long[] outReqId1,
      float[] outTemp1,
      int[] outMeta4,
      long[][] outArrays3);

  public static native String complianceDecodeJson(byte[] wire, int schemaTag);
}
