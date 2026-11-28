package benchmark.serializers;

import benchmark.model.Fixture;
import benchmark.model.v2.Document;
import benchmark.model.v2.Event;
import benchmark.model.v2.Message;
import benchmark.model.v2.NestedRow;
import benchmark.model.v2.Prompt;
import benchmark.model.v2.Request;
import benchmark.model.v2.Shard;
import benchmark.model.v2.Signal;
import benchmark.model.v2.Strings;
import benchmark.model.v2.TableRow;
import benchmark.model.v2.Telemetry;
import benchmark.model.v2.TensorMatrix;
import benchmark.model.v2.V2Rows;
import java.nio.charset.StandardCharsets;
import java.util.ArrayList;
import java.util.List;
import java.util.Set;

/**
 * gld-kiln-asm 0.2.0: pure x86-64 Assembly Kiln Wire Format v2 codec via shared JNI bridge
 * ({@code build/kiln-asm/libkiln_asm_jni.so}). Covers suite, columnar (TableColumns with
 * {@code KILN_OPT_EMBEDDED} O(1) column-skip for {@code table_project}), and tensor
 * (KLNT v2 with genuine zero-copy {@code tensor_view}).
 */
public final class KilnAsmSer implements BenchSerializer {
  private static final Set<String> SUPPORTED =
      Set.of(
          "message",
          "document",
          "telemetry",
          "strings",
          "event",
          "table",
          "table_project",
          "nested_table",
          "signal",
          "tensor",
          "tensor_view",
          "prompt",
          "shard",
          "request");

  private String typeId = "";
  private boolean batch;

  // Reused scratch buffers (no per-trial allocations in timed path).
  private byte[] strBuf = new byte[4096];
  private int strPos;
  private byte[] boolBuf = new byte[256];
  private int[] intBufA = new int[1024];
  private int[] intBufB = new int[1024];
  private int[] strLenBuf = new int[1024];
  private long[] longBufA = new long[1024];
  private long[] longBufB = new long[1024];
  private double[] dblBuf = new double[2048];
  private final int[] meta4 = new int[4];
  private final long[] reqId1 = new long[1];
  private final float[] temp1 = new float[1];
  private final long[][] promptOut = new long[3][];
  private final float[][] shardOut = new float[4][];

  public KilnAsmSer() {
    KilnAsmJni.ensureLoaded();
  }

  @Override
  public String name() {
    return "gld-kiln-asm";
  }

  @Override
  public String version() {
    return KilnAsmJni.VERSION;
  }

  @Override
  public String streamMode() {
    return "adapted";
  }

  @Override
  public String nativeKind() {
    return "schema";
  }

  @Override
  public boolean supports(String testDataName) {
    return SUPPORTED.contains(testDataName);
  }

  @Override
  public void prepare(Fixture fx) {
    KilnAsmJni.ensureLoaded();
    if (!SUPPORTED.contains(fx.name)) {
      throw new IllegalArgumentException("gld-kiln-asm unsupported: " + fx.name);
    }
    typeId = fx.name;
    batch = TypeUtil.isList(fx.value);
    int n = batch ? ((List<?>) fx.value).size() : 1;
    // Pre-size scratch arrays cleanly outside the timed loop.
    ensureBools(Math.max(2 * n, 16));
    ensureIntA(Math.max(8 * n, 64));
    ensureIntB(Math.max(32 * n, 256));
    ensureStrLens(Math.max(32 * n, 256));
    ensureLongA(Math.max(4 * n, 64));
    ensureLongB(Math.max(16 * n, 256));
    ensureDbl(Math.max(32 * n, 512));
  }

  private void ensureStr(int need) {
    if (strBuf.length < need) strBuf = new byte[Math.max(need, strBuf.length * 2)];
  }

  private void ensureBools(int need) {
    if (boolBuf.length < need) boolBuf = new byte[Math.max(need, boolBuf.length * 2)];
  }

  private void ensureIntA(int need) {
    if (intBufA.length < need) intBufA = new int[Math.max(need, intBufA.length * 2)];
  }

  private void ensureIntB(int need) {
    if (intBufB.length < need) intBufB = new int[Math.max(need, intBufB.length * 2)];
  }

  private void ensureStrLens(int need) {
    if (strLenBuf.length < need) strLenBuf = new int[Math.max(need, strLenBuf.length * 2)];
  }

  private void ensureLongA(int need) {
    if (longBufA.length < need) longBufA = new long[Math.max(need, longBufA.length * 2)];
  }

  private void ensureLongB(int need) {
    if (longBufB.length < need) longBufB = new long[Math.max(need, longBufB.length * 2)];
  }

  private void ensureDbl(int need) {
    if (dblBuf.length < need) dblBuf = new double[Math.max(need, dblBuf.length * 2)];
  }

  private int pushStr(String s) {
    if (s == null || s.isEmpty()) return 0;
    int n = s.length();
    ensureStr(strPos + n * 3);
    int start = strPos;
    for (int i = 0; i < n; i++) {
      char c = s.charAt(i);
      if (c < 0x80) {
        strBuf[strPos++] = (byte) c;
      } else {
        strPos = start;
        byte[] utf8 = s.getBytes(StandardCharsets.UTF_8);
        ensureStr(strPos + utf8.length);
        System.arraycopy(utf8, 0, strBuf, strPos, utf8.length);
        strPos += utf8.length;
        return utf8.length;
      }
    }
    return n;
  }

  private static String strFromWire(byte[] wire, int off, int len) {
    return len == 0 ? "" : new String(wire, off, len, StandardCharsets.UTF_8);
  }

  @Override
  @SuppressWarnings("unchecked")
  public byte[] serializeBytes(Fixture fx) {
    strPos = 0;
    Object v = fx.value;
    return switch (typeId) {
      case "message" -> {
        if (!batch) {
          Message m = (Message) v;
          byte[] s1 = m.fString == null ? new byte[0] : m.fString.getBytes(StandardCharsets.UTF_8);
          byte[] s2 = m.fString2 == null ? new byte[0] : m.fString2.getBytes(StandardCharsets.UTF_8);
          yield KilnAsmJni.encodeMessage(
              m.fBool, m.fInt32, m.fInt64, m.fFloat64, s1, m.fBool2, m.fInt32_2, s2);
        }
        List<Message> list = (List<Message>) v;
        int n = list.size();
        ensureBools(2 * n);
        ensureIntA(2 * n);
        ensureLongA(n);
        ensureDbl(n);
        ensureStrLens(2 * n);
        for (int i = 0; i < n; i++) {
          Message m = list.get(i);
          boolBuf[2 * i] = m.fBool ? (byte) 1 : (byte) 0;
          boolBuf[2 * i + 1] = m.fBool2 ? (byte) 1 : (byte) 0;
          intBufA[2 * i] = m.fInt32;
          intBufA[2 * i + 1] = m.fInt32_2;
          longBufA[i] = m.fInt64;
          dblBuf[i] = m.fFloat64;
          strLenBuf[2 * i] = pushStr(m.fString);
          strLenBuf[2 * i + 1] = pushStr(m.fString2);
        }
        yield KilnAsmJni.encodeMessageBatch(
            n, boolBuf, intBufA, longBufA, dblBuf, strBuf, strPos, strLenBuf);
      }

      case "document" -> {
        List<Document> list = batch ? (List<Document>) v : List.of((Document) v);
        int n = list.size();
        int totItems = 0;
        for (int i = 0; i < n; i++) {
          List<Document.DocumentItem> ch = list.get(i).items;
          if (ch != null) totItems += ch.size();
        }
        ensureIntA(3 * n);
        ensureIntB(Math.max(totItems, 1));
        ensureLongA(Math.max(totItems, 1));
        ensureStrLens(2 * n + totItems);
        int si = 0, ki = 0;
        for (int i = 0; i < n; i++) {
          Document d = list.get(i);
          strLenBuf[si++] = pushStr(d.id);
          intBufA[3 * i] = d.status;
          strLenBuf[si++] = pushStr(d.meta != null ? d.meta.region : "");
          intBufA[3 * i + 1] = d.meta != null ? d.meta.version : 0;
          List<Document.DocumentItem> ch = d.items;
          int m = ch == null ? 0 : ch.size();
          intBufA[3 * i + 2] = m;
          for (int j = 0; j < m; j++) {
            Document.DocumentItem it = ch.get(j);
            strLenBuf[si++] = pushStr(it.sku);
            intBufB[ki] = it.qty;
            longBufA[ki] = it.priceMinor;
            ki++;
          }
        }
        yield KilnAsmJni.encodeDocument(
            false, batch, n, intBufA, intBufB, longBufA, strBuf, strPos, strLenBuf);
      }

      case "nested_table" -> {
        List<NestedRow> list = V2Rows.nested(v);
        int n = list.size();
        int totItems = 0;
        for (int i = 0; i < n; i++) {
          List<NestedRow.NestedItem> ch = list.get(i).items;
          if (ch != null) totItems += ch.size();
        }
        ensureIntA(3 * n);
        ensureIntB(Math.max(totItems, 1));
        ensureLongA(Math.max(totItems, 1));
        ensureStrLens(2 * n + totItems);
        int si = 0, ki = 0;
        for (int i = 0; i < n; i++) {
          NestedRow d = list.get(i);
          strLenBuf[si++] = pushStr(d.id);
          intBufA[3 * i] = d.status;
          strLenBuf[si++] = pushStr(d.meta != null ? d.meta.region : "");
          intBufA[3 * i + 1] = d.meta != null ? d.meta.version : 0;
          List<NestedRow.NestedItem> ch = d.items;
          int m = ch == null ? 0 : ch.size();
          intBufA[3 * i + 2] = m;
          for (int j = 0; j < m; j++) {
            NestedRow.NestedItem it = ch.get(j);
            strLenBuf[si++] = pushStr(it.sku);
            intBufB[ki] = it.qty;
            longBufA[ki] = it.priceMinor;
            ki++;
          }
        }
        yield KilnAsmJni.encodeDocument(
            true, batch, n, intBufA, intBufB, longBufA, strBuf, strPos, strLenBuf);
      }

      case "telemetry" -> {
        List<Telemetry> list = batch ? (List<Telemetry>) v : List.of((Telemetry) v);
        int n = list.size();
        int totTags = 0, totVals = 0;
        for (int i = 0; i < n; i++) {
          Telemetry t = list.get(i);
          if (t.tags != null) totTags += t.tags.size();
          if (t.values != null) totVals += t.values.length;
        }
        ensureLongA(n);
        ensureIntA(2 * n);
        ensureStrLens(n + totTags);
        ensureDbl(Math.max(totVals, 1));
        int si = 0, vi = 0;
        for (int i = 0; i < n; i++) {
          Telemetry t = list.get(i);
          strLenBuf[si++] = pushStr(t.source);
          longBufA[i] = t.ts;
          int nt = t.tags == null ? 0 : t.tags.size();
          int nv = t.values == null ? 0 : t.values.length;
          intBufA[2 * i] = nt;
          intBufA[2 * i + 1] = nv;
          for (int j = 0; j < nt; j++) strLenBuf[si++] = pushStr(t.tags.get(j));
          if (nv > 0) {
            System.arraycopy(t.values, 0, dblBuf, vi, nv);
            vi += nv;
          }
        }
        yield KilnAsmJni.encodeTelemetry(
            batch, n, longBufA, intBufA, dblBuf, strBuf, strPos, strLenBuf);
      }

      case "strings" -> {
        List<Strings> list = batch ? (List<Strings>) v : List.of((Strings) v);
        int n = list.size();
        int tot = 0;
        for (int i = 0; i < n; i++) {
          List<String> ss = list.get(i).items;
          if (ss != null) tot += ss.size();
        }
        ensureIntA(n);
        ensureStrLens(Math.max(tot, 1));
        int si = 0;
        for (int i = 0; i < n; i++) {
          List<String> ss = list.get(i).items;
          int m = ss == null ? 0 : ss.size();
          intBufA[i] = m;
          for (int j = 0; j < m; j++) strLenBuf[si++] = pushStr(ss.get(j));
        }
        yield KilnAsmJni.encodeStrings(batch, n, intBufA, strBuf, strPos, strLenBuf);
      }

      case "event" -> {
        List<Event> list = batch ? (List<Event>) v : List.of((Event) v);
        int n = list.size();
        int totAttrs = 0;
        for (int i = 0; i < n; i++) {
          List<Event.EventAttr> at = list.get(i).attrs;
          if (at != null) totAttrs += at.size();
        }
        ensureLongA(n);
        ensureIntA(n);
        ensureStrLens(3 * n + 2 * totAttrs);
        int si = 0;
        for (int i = 0; i < n; i++) {
          Event e = list.get(i);
          strLenBuf[si++] = pushStr(e.eventId);
          strLenBuf[si++] = pushStr(e.eventType);
          longBufA[i] = e.occurredAt;
          strLenBuf[si++] = pushStr(e.producer);
          List<Event.EventAttr> at = e.attrs;
          int na = at == null ? 0 : at.size();
          intBufA[i] = na;
          for (int j = 0; j < na; j++) {
            Event.EventAttr a = at.get(j);
            strLenBuf[si++] = pushStr(a.key);
            strLenBuf[si++] = pushStr(a.value);
          }
        }
        yield KilnAsmJni.encodeEvent(batch, n, longBufA, intBufA, strBuf, strPos, strLenBuf);
      }

      case "signal" -> {
        List<Signal> list = V2Rows.signals(v);
        int n = list.size();
        int totLegs = 0;
        for (int i = 0; i < n; i++) {
          List<Signal.SignalLeg> lg = list.get(i).legs;
          if (lg != null) totLegs += lg.size();
        }
        ensureLongA(3 * n);
        ensureIntA(3 * n);
        ensureLongB(Math.max(totLegs, 1));
        ensureIntB(Math.max(2 * totLegs, 2));
        ensureStrLens(2 * n);
        int ki = 0;
        for (int i = 0; i < n; i++) {
          Signal s = list.get(i);
          longBufA[3 * i] = s.seq;
          longBufA[3 * i + 1] = s.ts;
          longBufA[3 * i + 2] = s.priceMantissa;
          intBufA[3 * i] = s.qty;
          intBufA[3 * i + 1] = s.flags;
          strLenBuf[2 * i] = pushStr(s.symbol);
          strLenBuf[2 * i + 1] = pushStr(s.venue);
          List<Signal.SignalLeg> lg = s.legs;
          int nl = lg == null ? 0 : lg.size();
          intBufA[3 * i + 2] = nl;
          for (int j = 0; j < nl; j++) {
            Signal.SignalLeg l = lg.get(j);
            longBufB[ki] = l.legId;
            intBufB[2 * ki] = l.legQty;
            intBufB[2 * ki + 1] = l.legPad;
            ki++;
          }
        }
        yield KilnAsmJni.encodeSignal(
            batch, n, longBufA, intBufA, longBufB, intBufB, strBuf, strPos, strLenBuf);
      }

      case "table", "table_project" -> {
        // Transpose rows -> 22 contiguous column arrays on the clock, then encode in one ASM call.
        List<TableRow> rows = V2Rows.tables(v);
        int n = rows.size();
        ensureDbl(16 * n);
        ensureLongA(4 * n);
        ensureStrLens(2 * n);
        for (int r = 0; r < n; r++) {
          TableRow row = rows.get(r);
          dblBuf[r] = row.fFloat0;
          dblBuf[n + r] = row.fFloat1;
          dblBuf[2 * n + r] = row.fFloat2;
          dblBuf[3 * n + r] = row.fFloat3;
          dblBuf[4 * n + r] = row.fFloat4;
          dblBuf[5 * n + r] = row.fFloat5;
          dblBuf[6 * n + r] = row.fFloat6;
          dblBuf[7 * n + r] = row.fFloat7;
          dblBuf[8 * n + r] = row.fFloat8;
          dblBuf[9 * n + r] = row.fFloat9;
          dblBuf[10 * n + r] = row.fFloat10;
          dblBuf[11 * n + r] = row.fFloat11;
          dblBuf[12 * n + r] = row.fFloat12;
          dblBuf[13 * n + r] = row.fFloat13;
          dblBuf[14 * n + r] = row.fFloat14;
          dblBuf[15 * n + r] = row.fFloat15;
          longBufA[r] = row.fInt0;
          longBufA[n + r] = row.fInt1;
          longBufA[2 * n + r] = row.fInt2;
          longBufA[3 * n + r] = row.fInt3;
        }
        for (int r = 0; r < n; r++) strLenBuf[r] = pushStr(rows.get(r).fStr0);
        for (int r = 0; r < n; r++) strLenBuf[n + r] = pushStr(rows.get(r).fStr1);
        yield KilnAsmJni.encodeTableColumns(n, dblBuf, longBufA, strBuf, strPos, strLenBuf);
      }

      case "tensor", "tensor_view" -> {
        TensorMatrix mx = (TensorMatrix) v;
        yield KilnAsmJni.encodeTensor(mx.rows, mx.cols, mx.values);
      }

      case "prompt" -> {
        Prompt p = (Prompt) v;
        yield KilnAsmJni.encodePrompt(p.batch, p.seq, p.inputIds, p.attentionMask, p.positionIds);
      }

      case "shard" -> {
        Shard sh = (Shard) v;
        yield KilnAsmJni.encodeShard(
            sh.vocab, sh.hidden, sh.ffn, sh.tokEmb, sh.attn, sh.ffnWeight, sh.norm);
      }

      case "request" -> {
        Request rq = (Request) v;
        Prompt p = rq.inputs;
        byte[] mBytes = rq.model == null ? new byte[0] : rq.model.getBytes(StandardCharsets.UTF_8);
        yield KilnAsmJni.encodeRequest(
            rq.requestId, mBytes, rq.temperature, p.batch, p.seq, p.inputIds, p.attentionMask, p.positionIds);
      }

      default -> throw new IllegalArgumentException("gld-kiln-asm unsupported: " + typeId);
    };
  }

  @Override
  public Object deserializeBytes(byte[] data) {
    return switch (typeId) {
      case "message" -> {
        int cnt = KilnAsmJni.decodeMessage(batch, data, boolBuf, intBufA, longBufA, dblBuf);
        if (cnt < 0) {
          int need = -cnt;
          ensureBools(2 * need);
          ensureIntA(6 * need);
          ensureLongA(need);
          ensureDbl(need);
          cnt = KilnAsmJni.decodeMessage(batch, data, boolBuf, intBufA, longBufA, dblBuf);
        }
        if (!batch) {
          yield new Message(
              boolBuf[0] != 0,
              intBufA[0],
              longBufA[0],
              dblBuf[0],
              strFromWire(data, intBufA[2], intBufA[3]),
              boolBuf[1] != 0,
              intBufA[1],
              strFromWire(data, intBufA[4], intBufA[5]));
        }
        List<Message> out = new ArrayList<>(cnt);
        for (int i = 0; i < cnt; i++) {
          out.add(
              new Message(
                  boolBuf[2 * i] != 0,
                  intBufA[6 * i],
                  longBufA[i],
                  dblBuf[i],
                  strFromWire(data, intBufA[6 * i + 2], intBufA[6 * i + 3]),
                  boolBuf[2 * i + 1] != 0,
                  intBufA[6 * i + 1],
                  strFromWire(data, intBufA[6 * i + 4], intBufA[6 * i + 5])));
        }
        yield out;
      }

      case "document" -> {
        int cnt = KilnAsmJni.decodeDocument(false, batch, data, intBufA, intBufB, longBufA);
        if (cnt < 0) {
          int need = -cnt;
          ensureIntA(7 * need);
          ensureIntB(3 * need);
          ensureLongA(need);
          cnt = KilnAsmJni.decodeDocument(false, batch, data, intBufA, intBufB, longBufA);
        }
        List<Document> out = new ArrayList<>(cnt);
        int ki = 0;
        for (int i = 0; i < cnt; i++) {
          int status = intBufA[7 * i];
          int version = intBufA[7 * i + 1];
          int ic = intBufA[7 * i + 2];
          String id = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4]);
          String region = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6]);
          List<Document.DocumentItem> items = new ArrayList<>(ic);
          for (int j = 0; j < ic; j++) {
            int qty = intBufB[3 * ki];
            String sku = strFromWire(data, intBufB[3 * ki + 1], intBufB[3 * ki + 2]);
            items.add(new Document.DocumentItem(sku, qty, longBufA[ki]));
            ki++;
          }
          out.add(new Document(id, status, new Document.DocumentMeta(region, version), items));
        }
        yield batch ? out : out.get(0);
      }

      case "nested_table" -> {
        int cnt = KilnAsmJni.decodeDocument(true, batch, data, intBufA, intBufB, longBufA);
        if (cnt < 0) {
          int need = -cnt;
          ensureIntA(7 * need);
          ensureIntB(3 * need);
          ensureLongA(need);
          cnt = KilnAsmJni.decodeDocument(true, batch, data, intBufA, intBufB, longBufA);
        }
        List<NestedRow> out = new ArrayList<>(cnt);
        int ki = 0;
        for (int i = 0; i < cnt; i++) {
          int status = intBufA[7 * i];
          int version = intBufA[7 * i + 1];
          int ic = intBufA[7 * i + 2];
          String id = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4]);
          String region = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6]);
          List<NestedRow.NestedItem> items = new ArrayList<>(ic);
          for (int j = 0; j < ic; j++) {
            int qty = intBufB[3 * ki];
            String sku = strFromWire(data, intBufB[3 * ki + 1], intBufB[3 * ki + 2]);
            items.add(new NestedRow.NestedItem(sku, qty, longBufA[ki]));
            ki++;
          }
          out.add(new NestedRow(id, status, new NestedRow.NestedMeta(region, version), items));
        }
        yield V2Rows.oneOrList(out, batch);
      }

      case "telemetry" -> {
        int cnt = KilnAsmJni.decodeTelemetry(batch, data, longBufA, intBufA, intBufB, dblBuf);
        if (cnt < 0) {
          int need = -cnt;
          ensureLongA(need);
          ensureIntA(2 * need);
          ensureIntB(2 * need);
          ensureDbl(need);
          cnt = KilnAsmJni.decodeTelemetry(batch, data, longBufA, intBufA, intBufB, dblBuf);
        }
        List<Telemetry> out = new ArrayList<>(cnt);
        int si = 0, vi = 0;
        for (int i = 0; i < cnt; i++) {
          int nt = intBufA[2 * i];
          int nv = intBufA[2 * i + 1];
          String source = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]);
          si++;
          List<String> tags = new ArrayList<>(nt);
          for (int j = 0; j < nt; j++) {
            tags.add(strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]));
            si++;
          }
          double[] vals = new double[nv];
          if (nv > 0) {
            System.arraycopy(dblBuf, vi, vals, 0, nv);
            vi += nv;
          }
          out.add(new Telemetry(source, longBufA[i], tags, vals));
        }
        yield batch ? out : out.get(0);
      }

      case "strings" -> {
        int cnt = KilnAsmJni.decodeStrings(batch, data, intBufA, intBufB);
        if (cnt < 0) {
          int need = -cnt;
          ensureIntA(need);
          ensureIntB(2 * need);
          cnt = KilnAsmJni.decodeStrings(batch, data, intBufA, intBufB);
        }
        List<Strings> out = new ArrayList<>(cnt);
        int si = 0;
        for (int i = 0; i < cnt; i++) {
          int m = intBufA[i];
          List<String> ss = new ArrayList<>(m);
          for (int j = 0; j < m; j++) {
            ss.add(strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]));
            si++;
          }
          out.add(new Strings(ss));
        }
        yield batch ? out : out.get(0);
      }

      case "event" -> {
        int cnt = KilnAsmJni.decodeEvent(batch, data, longBufA, intBufA, intBufB);
        if (cnt < 0) {
          int need = -cnt;
          ensureLongA(need);
          ensureIntA(need);
          ensureIntB(2 * need);
          cnt = KilnAsmJni.decodeEvent(batch, data, longBufA, intBufA, intBufB);
        }
        List<Event> out = new ArrayList<>(cnt);
        int si = 0;
        for (int i = 0; i < cnt; i++) {
          String eid = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++;
          String etype = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++;
          String prod = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++;
          int na = intBufA[i];
          List<Event.EventAttr> attrs = new ArrayList<>(na);
          for (int j = 0; j < na; j++) {
            String k = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++;
            String val = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++;
            attrs.add(new Event.EventAttr(k, val));
          }
          out.add(new Event(eid, etype, longBufA[i], prod, attrs));
        }
        yield batch ? out : out.get(0);
      }

      case "signal" -> {
        int cnt = KilnAsmJni.decodeSignal(batch, data, longBufA, intBufA, longBufB, intBufB);
        if (cnt < 0) {
          int need = -cnt;
          ensureLongA(3 * need);
          ensureIntA(7 * need);
          ensureLongB(need);
          ensureIntB(2 * need);
          cnt = KilnAsmJni.decodeSignal(batch, data, longBufA, intBufA, longBufB, intBufB);
        }
        List<Signal> out = new ArrayList<>(cnt);
        int ki = 0;
        for (int i = 0; i < cnt; i++) {
          int qty = intBufA[7 * i];
          int flags = intBufA[7 * i + 1];
          int nl = intBufA[7 * i + 2];
          String sym = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4]);
          String ven = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6]);
          List<Signal.SignalLeg> legs = new ArrayList<>(nl);
          for (int j = 0; j < nl; j++) {
            legs.add(new Signal.SignalLeg(longBufB[ki], intBufB[2 * ki], intBufB[2 * ki + 1]));
            ki++;
          }
          out.add(new Signal(longBufA[3 * i], longBufA[3 * i + 1], longBufA[3 * i + 2], qty, flags, sym, ven, legs));
        }
        yield V2Rows.oneOrList(out, batch);
      }

      case "table" -> {
        int n = KilnAsmJni.decodeTableColumns(data, dblBuf, longBufA, intBufB);
        if (n < 0) {
          int need = -n;
          ensureDbl(16 * need);
          ensureLongA(4 * need);
          ensureIntB(4 * need);
          n = KilnAsmJni.decodeTableColumns(data, dblBuf, longBufA, intBufB);
        }
        List<TableRow> rows = new ArrayList<>(n);
        for (int r = 0; r < n; r++) {
          TableRow row = new TableRow();
          row.fFloat0 = dblBuf[r];
          row.fFloat1 = dblBuf[n + r];
          row.fFloat2 = dblBuf[2 * n + r];
          row.fFloat3 = dblBuf[3 * n + r];
          row.fFloat4 = dblBuf[4 * n + r];
          row.fFloat5 = dblBuf[5 * n + r];
          row.fFloat6 = dblBuf[6 * n + r];
          row.fFloat7 = dblBuf[7 * n + r];
          row.fFloat8 = dblBuf[8 * n + r];
          row.fFloat9 = dblBuf[9 * n + r];
          row.fFloat10 = dblBuf[10 * n + r];
          row.fFloat11 = dblBuf[11 * n + r];
          row.fFloat12 = dblBuf[12 * n + r];
          row.fFloat13 = dblBuf[13 * n + r];
          row.fFloat14 = dblBuf[14 * n + r];
          row.fFloat15 = dblBuf[15 * n + r];
          row.fInt0 = longBufA[r];
          row.fInt1 = longBufA[n + r];
          row.fInt2 = longBufA[2 * n + r];
          row.fInt3 = longBufA[3 * n + r];
          row.fStr0 = strFromWire(data, intBufB[2 * r], intBufB[2 * r + 1]);
          row.fStr1 = strFromWire(data, intBufB[2 * (n + r)], intBufB[2 * (n + r) + 1]);
          rows.add(row);
        }
        yield V2Rows.oneOrList(rows, batch);
      }

      case "table_project" -> {
        double[] col0 = KilnAsmJni.decodeTableProject(data);
        List<Double> out = new ArrayList<>(col0.length);
        for (double x : col0) out.add(x);
        yield out;
      }

      case "tensor" -> {
        float[] vals = KilnAsmJni.decodeTensor(data, meta4);
        yield new TensorMatrix(meta4[0], meta4[1], vals);
      }

      case "tensor_view" -> {
        // Genuine zero-copy borrow of the encoded byte[].
        KilnAsmJni.decodeTensorView(data, meta4);
        yield new TensorMatrix.View(meta4[0], meta4[1], data, meta4[2], meta4[3]);
      }

      case "prompt" -> {
        KilnAsmJni.decodePrompt(data, meta4, promptOut);
        yield new Prompt(meta4[0], meta4[1], promptOut[0], promptOut[1], promptOut[2]);
      }

      case "shard" -> {
        KilnAsmJni.decodeShard(data, meta4, shardOut);
        yield new Shard(meta4[0], meta4[1], meta4[2], shardOut[0], shardOut[1], shardOut[2], shardOut[3]);
      }

      case "request" -> {
        KilnAsmJni.decodeRequest(data, reqId1, temp1, meta4, promptOut);
        String model = strFromWire(data, meta4[2], meta4[3]);
        Prompt inputs = new Prompt(meta4[0], meta4[1], promptOut[0], promptOut[1], promptOut[2]);
        yield new Request(reqId1[0], model, temp1[0], inputs);
      }

      default -> throw new IllegalArgumentException("gld-kiln-asm unsupported: " + typeId);
    };
  }
}
