package benchmark.serializers

import benchmark.model.Fixture
import benchmark.model.v2.Document
import benchmark.model.v2.DocumentItem
import benchmark.model.v2.DocumentMeta
import benchmark.model.v2.Event
import benchmark.model.v2.EventAttr
import benchmark.model.v2.Message
import benchmark.model.v2.NestedRow
import benchmark.model.v2.Signal
import benchmark.model.v2.Strings
import benchmark.model.v2.TableRow
import benchmark.model.v2.Telemetry
import benchmark.model.v2.V2Rows
import java.nio.charset.StandardCharsets

/**
 * gld-kiln-asm 0.2.0: pure x86-64 Assembly Kiln Wire Format v2 codec via shared JNI bridge
 * (`build/kiln-asm/libkiln_asm_jni.so`). Covers `suite` and `columnar` (`TableColumns` with
 * `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`).
 */
class KilnAsmSer : BenchSerializer {
    companion object {
        private val SUPPORTED = setOf(
            "message", "document", "telemetry", "strings", "event",
            "table", "table_project", "nested_table", "signal",
        )

        private fun strFromWire(wire: ByteArray, off: Int, len: Int): String =
            if (len == 0) "" else String(wire, off, len, StandardCharsets.UTF_8)
    }

    private var typeId: String = ""
    private var batch: Boolean = false

    private var strBuf = ByteArray(4096)
    private var strPos = 0
    private var boolBuf = ByteArray(256)
    private var intBufA = IntArray(1024)
    private var intBufB = IntArray(1024)
    private var strLenBuf = IntArray(1024)
    private var longBufA = LongArray(1024)
    private var longBufB = LongArray(1024)
    private var dblBuf = DoubleArray(2048)

    init {
        KilnAsmJni.ensureLoaded()
    }

    override fun name(): String = "gld-kiln-asm"

    override fun version(): String = KilnAsmJni.VERSION

    override fun streamMode(): String = "adapted"

    override fun nativeKind(): String = "schema"

    override fun supports(testDataName: String): Boolean = testDataName in SUPPORTED

    override fun prepare(fx: Fixture) {
        KilnAsmJni.ensureLoaded()
        require(fx.name in SUPPORTED) { "gld-kiln-asm unsupported: ${fx.name}" }
        typeId = fx.name
        batch = TypeUtil.isList(fx.value)
        val n = if (batch) (fx.value as List<*>).size else 1
        ensureBools(maxOf(2 * n, 16))
        ensureIntA(maxOf(8 * n, 64))
        ensureIntB(maxOf(32 * n, 256))
        ensureStrLens(maxOf(32 * n, 256))
        ensureLongA(maxOf(4 * n, 64))
        ensureLongB(maxOf(16 * n, 256))
        ensureDbl(maxOf(32 * n, 512))
    }

    private fun ensureStr(need: Int) {
        if (strBuf.size < need) strBuf = ByteArray(maxOf(need, strBuf.size * 2))
    }

    private fun ensureBools(need: Int) {
        if (boolBuf.size < need) boolBuf = ByteArray(maxOf(need, boolBuf.size * 2))
    }

    private fun ensureIntA(need: Int) {
        if (intBufA.size < need) intBufA = IntArray(maxOf(need, intBufA.size * 2))
    }

    private fun ensureIntB(need: Int) {
        if (intBufB.size < need) intBufB = IntArray(maxOf(need, intBufB.size * 2))
    }

    private fun ensureStrLens(need: Int) {
        if (strLenBuf.size < need) strLenBuf = IntArray(maxOf(need, strLenBuf.size * 2))
    }

    private fun ensureLongA(need: Int) {
        if (longBufA.size < need) longBufA = LongArray(maxOf(need, longBufA.size * 2))
    }

    private fun ensureLongB(need: Int) {
        if (longBufB.size < need) longBufB = LongArray(maxOf(need, longBufB.size * 2))
    }

    private fun ensureDbl(need: Int) {
        if (dblBuf.size < need) dblBuf = DoubleArray(maxOf(need, dblBuf.size * 2))
    }

    private fun pushStr(s: String?): Int {
        if (s.isNullOrEmpty()) return 0
        val n = s.length
        ensureStr(strPos + n * 3)
        val start = strPos
        for (i in 0 until n) {
            val c = s[i].code
            if (c < 0x80) {
                strBuf[strPos++] = c.toByte()
            } else {
                strPos = start
                val utf8 = s.toByteArray(StandardCharsets.UTF_8)
                ensureStr(strPos + utf8.size)
                System.arraycopy(utf8, 0, strBuf, strPos, utf8.size)
                strPos += utf8.size
                return utf8.size
            }
        }
        return n
    }

    @Suppress("UNCHECKED_CAST")
    override fun serializeBytes(fx: Fixture): ByteArray {
        strPos = 0
        val v = fx.value
        return when (typeId) {
            "message" -> {
                if (!batch) {
                    val m = v as Message
                    KilnAsmJni.encodeMessage(
                        m.fBool, m.fInt32, m.fInt64, m.fFloat64,
                        m.fString.toByteArray(StandardCharsets.UTF_8),
                        m.fBool2, m.fInt32_2,
                        m.fString2.toByteArray(StandardCharsets.UTF_8),
                    )
                } else {
                    val list = v as List<Message>
                    val n = list.size
                    ensureBools(2 * n)
                    ensureIntA(2 * n)
                    ensureLongA(n)
                    ensureDbl(n)
                    ensureStrLens(2 * n)
                    for (i in 0 until n) {
                        val m = list[i]
                        boolBuf[2 * i] = if (m.fBool) 1 else 0
                        boolBuf[2 * i + 1] = if (m.fBool2) 1 else 0
                        intBufA[2 * i] = m.fInt32
                        intBufA[2 * i + 1] = m.fInt32_2
                        longBufA[i] = m.fInt64
                        dblBuf[i] = m.fFloat64
                        strLenBuf[2 * i] = pushStr(m.fString)
                        strLenBuf[2 * i + 1] = pushStr(m.fString2)
                    }
                    KilnAsmJni.encodeMessageBatch(
                        n, boolBuf, intBufA, longBufA, dblBuf, strBuf, strPos, strLenBuf,
                    )
                }
            }

            "document" -> {
                val list = if (batch) v as List<Document> else listOf(v as Document)
                val n = list.size
                var totItems = 0
                for (i in 0 until n) totItems += list[i].items.size
                ensureIntA(3 * n)
                ensureIntB(maxOf(totItems, 1))
                ensureLongA(maxOf(totItems, 1))
                ensureStrLens(2 * n + totItems)
                var si = 0
                var ki = 0
                for (i in 0 until n) {
                    val d = list[i]
                    strLenBuf[si++] = pushStr(d.id)
                    intBufA[3 * i] = d.status
                    strLenBuf[si++] = pushStr(d.meta.region)
                    intBufA[3 * i + 1] = d.meta.version
                    val ch = d.items
                    intBufA[3 * i + 2] = ch.size
                    for (j in 0 until ch.size) {
                        val it = ch[j]
                        strLenBuf[si++] = pushStr(it.sku)
                        intBufB[ki] = it.qty
                        longBufA[ki] = it.priceMinor
                        ki++
                    }
                }
                KilnAsmJni.encodeDocument(
                    false, batch, n, intBufA, intBufB, longBufA, strBuf, strPos, strLenBuf,
                )
            }

            "nested_table" -> {
                val list = V2Rows.nested(v)
                val n = list.size
                var totItems = 0
                for (i in 0 until n) totItems += list[i].items.size
                ensureIntA(3 * n)
                ensureIntB(maxOf(totItems, 1))
                ensureLongA(maxOf(totItems, 1))
                ensureStrLens(2 * n + totItems)
                var si = 0
                var ki = 0
                for (i in 0 until n) {
                    val d = list[i]
                    strLenBuf[si++] = pushStr(d.id)
                    intBufA[3 * i] = d.status
                    strLenBuf[si++] = pushStr(d.meta.region)
                    intBufA[3 * i + 1] = d.meta.version
                    val ch = d.items
                    intBufA[3 * i + 2] = ch.size
                    for (j in 0 until ch.size) {
                        val it = ch[j]
                        strLenBuf[si++] = pushStr(it.sku)
                        intBufB[ki] = it.qty
                        longBufA[ki] = it.priceMinor
                        ki++
                    }
                }
                KilnAsmJni.encodeDocument(
                    true, batch, n, intBufA, intBufB, longBufA, strBuf, strPos, strLenBuf,
                )
            }

            "telemetry" -> {
                val list = if (batch) v as List<Telemetry> else listOf(v as Telemetry)
                val n = list.size
                var totTags = 0
                var totVals = 0
                for (i in 0 until n) {
                    totTags += list[i].tags.size
                    totVals += list[i].values.size
                }
                ensureLongA(n)
                ensureIntA(2 * n)
                ensureStrLens(n + totTags)
                ensureDbl(maxOf(totVals, 1))
                var si = 0
                var vi = 0
                for (i in 0 until n) {
                    val t = list[i]
                    strLenBuf[si++] = pushStr(t.source)
                    longBufA[i] = t.ts
                    val nt = t.tags.size
                    val nv = t.values.size
                    intBufA[2 * i] = nt
                    intBufA[2 * i + 1] = nv
                    for (j in 0 until nt) strLenBuf[si++] = pushStr(t.tags[j])
                    for (j in 0 until nv) dblBuf[vi++] = t.values[j]
                }
                KilnAsmJni.encodeTelemetry(
                    batch, n, longBufA, intBufA, dblBuf, strBuf, strPos, strLenBuf,
                )
            }

            "strings" -> {
                val list = if (batch) v as List<Strings> else listOf(v as Strings)
                val n = list.size
                var tot = 0
                for (i in 0 until n) tot += list[i].items.size
                ensureIntA(n)
                ensureStrLens(maxOf(tot, 1))
                var si = 0
                for (i in 0 until n) {
                    val ss = list[i].items
                    intBufA[i] = ss.size
                    for (j in 0 until ss.size) strLenBuf[si++] = pushStr(ss[j])
                }
                KilnAsmJni.encodeStrings(batch, n, intBufA, strBuf, strPos, strLenBuf)
            }

            "event" -> {
                val list = if (batch) v as List<Event> else listOf(v as Event)
                val n = list.size
                var totAttrs = 0
                for (i in 0 until n) totAttrs += list[i].attrs.size
                ensureLongA(n)
                ensureIntA(n)
                ensureStrLens(3 * n + 2 * totAttrs)
                var si = 0
                for (i in 0 until n) {
                    val e = list[i]
                    strLenBuf[si++] = pushStr(e.eventId)
                    strLenBuf[si++] = pushStr(e.eventType)
                    longBufA[i] = e.occurredAt
                    strLenBuf[si++] = pushStr(e.producer)
                    val at = e.attrs
                    intBufA[i] = at.size
                    for (j in 0 until at.size) {
                        strLenBuf[si++] = pushStr(at[j].key)
                        strLenBuf[si++] = pushStr(at[j].value)
                    }
                }
                KilnAsmJni.encodeEvent(batch, n, longBufA, intBufA, strBuf, strPos, strLenBuf)
            }

            "signal" -> {
                val list = V2Rows.signals(v)
                val n = list.size
                var totLegs = 0
                for (i in 0 until n) totLegs += list[i].legs.size
                ensureLongA(3 * n)
                ensureIntA(3 * n)
                ensureLongB(maxOf(totLegs, 1))
                ensureIntB(maxOf(2 * totLegs, 2))
                ensureStrLens(2 * n)
                var ki = 0
                for (i in 0 until n) {
                    val s = list[i]
                    longBufA[3 * i] = s.seq
                    longBufA[3 * i + 1] = s.ts
                    longBufA[3 * i + 2] = s.priceMantissa
                    intBufA[3 * i] = s.qty
                    intBufA[3 * i + 1] = s.flags
                    strLenBuf[2 * i] = pushStr(s.symbol)
                    strLenBuf[2 * i + 1] = pushStr(s.venue)
                    val lg = s.legs
                    intBufA[3 * i + 2] = lg.size
                    for (j in 0 until lg.size) {
                        val l = lg[j]
                        longBufB[ki] = l.legId
                        intBufB[2 * ki] = l.legQty
                        intBufB[2 * ki + 1] = l.legPad
                        ki++
                    }
                }
                KilnAsmJni.encodeSignal(
                    batch, n, longBufA, intBufA, longBufB, intBufB, strBuf, strPos, strLenBuf,
                )
            }

            "table", "table_project" -> {
                val rows = V2Rows.tables(v)
                val n = rows.size
                ensureDbl(16 * n)
                ensureLongA(4 * n)
                ensureStrLens(2 * n)
                for (r in 0 until n) {
                    val row = rows[r]
                    dblBuf[r] = row.fFloat0
                    dblBuf[n + r] = row.fFloat1
                    dblBuf[2 * n + r] = row.fFloat2
                    dblBuf[3 * n + r] = row.fFloat3
                    dblBuf[4 * n + r] = row.fFloat4
                    dblBuf[5 * n + r] = row.fFloat5
                    dblBuf[6 * n + r] = row.fFloat6
                    dblBuf[7 * n + r] = row.fFloat7
                    dblBuf[8 * n + r] = row.fFloat8
                    dblBuf[9 * n + r] = row.fFloat9
                    dblBuf[10 * n + r] = row.fFloat10
                    dblBuf[11 * n + r] = row.fFloat11
                    dblBuf[12 * n + r] = row.fFloat12
                    dblBuf[13 * n + r] = row.fFloat13
                    dblBuf[14 * n + r] = row.fFloat14
                    dblBuf[15 * n + r] = row.fFloat15
                    longBufA[r] = row.fInt0
                    longBufA[n + r] = row.fInt1
                    longBufA[2 * n + r] = row.fInt2
                    longBufA[3 * n + r] = row.fInt3
                }
                for (r in 0 until n) strLenBuf[r] = pushStr(rows[r].fStr0)
                for (r in 0 until n) strLenBuf[n + r] = pushStr(rows[r].fStr1)
                KilnAsmJni.encodeTableColumns(n, dblBuf, longBufA, strBuf, strPos, strLenBuf)
            }

            else -> error("gld-kiln-asm unsupported: $typeId")
        }
    }

    override fun deserializeBytes(data: ByteArray): Any {
        return when (typeId) {
            "message" -> {
                var cnt = KilnAsmJni.decodeMessage(batch, data, boolBuf, intBufA, longBufA, dblBuf)
                if (cnt < 0) {
                    val need = -cnt
                    ensureBools(2 * need)
                    ensureIntA(6 * need)
                    ensureLongA(need)
                    ensureDbl(need)
                    cnt = KilnAsmJni.decodeMessage(batch, data, boolBuf, intBufA, longBufA, dblBuf)
                }
                if (!batch) {
                    Message(
                        boolBuf[0] != 0.toByte(), intBufA[0], longBufA[0], dblBuf[0],
                        strFromWire(data, intBufA[2], intBufA[3]),
                        boolBuf[1] != 0.toByte(), intBufA[1],
                        strFromWire(data, intBufA[4], intBufA[5]),
                    )
                } else {
                    val out = ArrayList<Message>(cnt)
                    for (i in 0 until cnt) {
                        out.add(
                            Message(
                                boolBuf[2 * i] != 0.toByte(), intBufA[6 * i], longBufA[i], dblBuf[i],
                                strFromWire(data, intBufA[6 * i + 2], intBufA[6 * i + 3]),
                                boolBuf[2 * i + 1] != 0.toByte(), intBufA[6 * i + 1],
                                strFromWire(data, intBufA[6 * i + 4], intBufA[6 * i + 5]),
                            )
                        )
                    }
                    out
                }
            }

            "document" -> {
                var cnt = KilnAsmJni.decodeDocument(false, batch, data, intBufA, intBufB, longBufA)
                if (cnt < 0) {
                    val need = -cnt
                    ensureIntA(7 * need)
                    ensureIntB(3 * need)
                    ensureLongA(need)
                    cnt = KilnAsmJni.decodeDocument(false, batch, data, intBufA, intBufB, longBufA)
                }
                val out = ArrayList<Document>(cnt)
                var ki = 0
                for (i in 0 until cnt) {
                    val status = intBufA[7 * i]
                    val version = intBufA[7 * i + 1]
                    val ic = intBufA[7 * i + 2]
                    val id = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4])
                    val region = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6])
                    val items = ArrayList<DocumentItem>(ic)
                    for (j in 0 until ic) {
                        val qty = intBufB[3 * ki]
                        val sku = strFromWire(data, intBufB[3 * ki + 1], intBufB[3 * ki + 2])
                        items.add(DocumentItem(sku, qty, longBufA[ki]))
                        ki++
                    }
                    out.add(Document(id, status, DocumentMeta(region, version), items))
                }
                if (batch) out else out[0]
            }

            "nested_table" -> {
                var cnt = KilnAsmJni.decodeDocument(true, batch, data, intBufA, intBufB, longBufA)
                if (cnt < 0) {
                    val need = -cnt
                    ensureIntA(7 * need)
                    ensureIntB(3 * need)
                    ensureLongA(need)
                    cnt = KilnAsmJni.decodeDocument(true, batch, data, intBufA, intBufB, longBufA)
                }
                val out = ArrayList<NestedRow>(cnt)
                var ki = 0
                for (i in 0 until cnt) {
                    val status = intBufA[7 * i]
                    val version = intBufA[7 * i + 1]
                    val ic = intBufA[7 * i + 2]
                    val id = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4])
                    val region = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6])
                    val items = ArrayList<NestedRow.NestedItem>(ic)
                    for (j in 0 until ic) {
                        val qty = intBufB[3 * ki]
                        val sku = strFromWire(data, intBufB[3 * ki + 1], intBufB[3 * ki + 2])
                        items.add(NestedRow.NestedItem(sku, qty, longBufA[ki]))
                        ki++
                    }
                    out.add(NestedRow(id, status, NestedRow.NestedMeta(region, version), items))
                }
                V2Rows.oneOrList(out, batch)
            }

            "telemetry" -> {
                var cnt = KilnAsmJni.decodeTelemetry(batch, data, longBufA, intBufA, intBufB, dblBuf)
                if (cnt < 0) {
                    val need = -cnt
                    ensureLongA(need)
                    ensureIntA(2 * need)
                    ensureIntB(2 * need)
                    ensureDbl(need)
                    cnt = KilnAsmJni.decodeTelemetry(batch, data, longBufA, intBufA, intBufB, dblBuf)
                }
                val out = ArrayList<Telemetry>(cnt)
                var si = 0
                var vi = 0
                for (i in 0 until cnt) {
                    val nt = intBufA[2 * i]
                    val nv = intBufA[2 * i + 1]
                    val source = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1])
                    si++
                    val tags = ArrayList<String>(nt)
                    for (j in 0 until nt) {
                        tags.add(strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]))
                        si++
                    }
                    val vals = ArrayList<Double>(nv)
                    for (j in 0 until nv) vals.add(dblBuf[vi++])
                    out.add(Telemetry(source, longBufA[i], tags, vals))
                }
                if (batch) out else out[0]
            }

            "strings" -> {
                var cnt = KilnAsmJni.decodeStrings(batch, data, intBufA, intBufB)
                if (cnt < 0) {
                    val need = -cnt
                    ensureIntA(need)
                    ensureIntB(2 * need)
                    cnt = KilnAsmJni.decodeStrings(batch, data, intBufA, intBufB)
                }
                val out = ArrayList<Strings>(cnt)
                var si = 0
                for (i in 0 until cnt) {
                    val m = intBufA[i]
                    val ss = ArrayList<String>(m)
                    for (j in 0 until m) {
                        ss.add(strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]))
                        si++
                    }
                    out.add(Strings(ss))
                }
                if (batch) out else out[0]
            }

            "event" -> {
                var cnt = KilnAsmJni.decodeEvent(batch, data, longBufA, intBufA, intBufB)
                if (cnt < 0) {
                    val need = -cnt
                    ensureLongA(need)
                    ensureIntA(need)
                    ensureIntB(2 * need)
                    cnt = KilnAsmJni.decodeEvent(batch, data, longBufA, intBufA, intBufB)
                }
                val out = ArrayList<Event>(cnt)
                var si = 0
                for (i in 0 until cnt) {
                    val eid = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++
                    val etype = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++
                    val prod = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++
                    val na = intBufA[i]
                    val attrs = ArrayList<EventAttr>(na)
                    for (j in 0 until na) {
                        val k = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++
                        val v = strFromWire(data, intBufB[2 * si], intBufB[2 * si + 1]); si++
                        attrs.add(EventAttr(k, v))
                    }
                    out.add(Event(eid, etype, longBufA[i], prod, attrs))
                }
                if (batch) out else out[0]
            }

            "signal" -> {
                var cnt = KilnAsmJni.decodeSignal(batch, data, longBufA, intBufA, longBufB, intBufB)
                if (cnt < 0) {
                    val need = -cnt
                    ensureLongA(3 * need)
                    ensureIntA(7 * need)
                    ensureLongB(need)
                    ensureIntB(2 * need)
                    cnt = KilnAsmJni.decodeSignal(batch, data, longBufA, intBufA, longBufB, intBufB)
                }
                val out = ArrayList<Signal>(cnt)
                var ki = 0
                for (i in 0 until cnt) {
                    val qty = intBufA[7 * i]
                    val flags = intBufA[7 * i + 1]
                    val nl = intBufA[7 * i + 2]
                    val sym = strFromWire(data, intBufA[7 * i + 3], intBufA[7 * i + 4])
                    val ven = strFromWire(data, intBufA[7 * i + 5], intBufA[7 * i + 6])
                    val legs = ArrayList<Signal.SignalLeg>(nl)
                    for (j in 0 until nl) {
                        legs.add(Signal.SignalLeg(longBufB[ki], intBufB[2 * ki], intBufB[2 * ki + 1]))
                        ki++
                    }
                    out.add(Signal(longBufA[3 * i], longBufA[3 * i + 1], longBufA[3 * i + 2], qty, flags, sym, ven, legs))
                }
                V2Rows.oneOrList(out, batch)
            }

            "table" -> {
                var n = KilnAsmJni.decodeTableColumns(data, dblBuf, longBufA, intBufB)
                if (n < 0) {
                    val need = -n
                    ensureDbl(16 * need)
                    ensureLongA(4 * need)
                    ensureIntB(4 * need)
                    n = KilnAsmJni.decodeTableColumns(data, dblBuf, longBufA, intBufB)
                }
                val rows = ArrayList<TableRow>(n)
                for (r in 0 until n) {
                    rows.add(
                        TableRow(
                            fFloat0 = dblBuf[r],
                            fFloat1 = dblBuf[n + r],
                            fFloat2 = dblBuf[2 * n + r],
                            fFloat3 = dblBuf[3 * n + r],
                            fFloat4 = dblBuf[4 * n + r],
                            fFloat5 = dblBuf[5 * n + r],
                            fFloat6 = dblBuf[6 * n + r],
                            fFloat7 = dblBuf[7 * n + r],
                            fFloat8 = dblBuf[8 * n + r],
                            fFloat9 = dblBuf[9 * n + r],
                            fFloat10 = dblBuf[10 * n + r],
                            fFloat11 = dblBuf[11 * n + r],
                            fFloat12 = dblBuf[12 * n + r],
                            fFloat13 = dblBuf[13 * n + r],
                            fFloat14 = dblBuf[14 * n + r],
                            fFloat15 = dblBuf[15 * n + r],
                            fInt0 = longBufA[r],
                            fInt1 = longBufA[n + r],
                            fInt2 = longBufA[2 * n + r],
                            fInt3 = longBufA[3 * n + r],
                            fStr0 = strFromWire(data, intBufB[2 * r], intBufB[2 * r + 1]),
                            fStr1 = strFromWire(data, intBufB[2 * (n + r)], intBufB[2 * (n + r) + 1]),
                        )
                    )
                }
                V2Rows.oneOrList(rows, batch)
            }

            "table_project" -> {
                val col0 = KilnAsmJni.decodeTableProject(data)
                val out = ArrayList<Double>(col0.size)
                for (x in col0) out.add(x)
                out
            }

            else -> error("gld-kiln-asm unsupported: $typeId")
        }
    }
}
