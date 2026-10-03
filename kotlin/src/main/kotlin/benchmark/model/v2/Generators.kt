package benchmark.model.v2

/** Data Model v2 make_one generators (within-language deterministic). */
object Generators {
    private const val BASE_TS_MS = 1_704_067_200_000L

    fun makeOne(typeId: String, typeConfig: Map<String, Any?>, seed: Long, instanceIndex: Int): Any {
        val r = Rng(Rng.mixSeed(seed, typeId, instanceIndex))
        return when (typeId) {
            "message" -> makeMessage(r)
            "document" -> makeDocument(r, typeConfig)
            "telemetry" -> makeTelemetry(r, typeConfig)
            "strings" -> makeStrings(r, typeConfig)
            "event" -> makeEvent(r, typeConfig)
            "table", "table_project" -> makeTable(r, typeConfig, seed, typeId)
            "nested_table" -> makeNested(r, typeConfig)
            "signal" -> makeSignal(r, typeConfig)
            else -> throw IllegalArgumentException("unknown type_id: $typeId")
        }
    }

    fun instances(typeId: String, typeConfig: Map<String, Any?>, seed: Long, n: Int): List<Any> =
        (0 until n).map { makeOne(typeId, typeConfig, seed, it) }

    private fun cfgInt(m: Map<String, Any?>?, key: String, def: Int): Int {
        val v = m?.get(key) ?: return def
        return if (v is Number) v.toInt() else def
    }

    private fun cfgDouble(m: Map<String, Any?>?, key: String, def: Double): Double {
        val v = m?.get(key) ?: return def
        return if (v is Number) v.toDouble() else def
    }

    private fun cfgMap(m: Map<String, Any?>?, key: String): Map<String, Any?> {
        val raw = m?.get(key) as? Map<*, *> ?: return emptyMap()
        return raw.entries.associate { it.key.toString() to it.value }
    }

    /** Catalog string_len, or [defMin]..[defMax] when the key is absent. */
    private fun slen(cfg: Map<String, Any?>, defMin: Int, defMax: Int): IntArray {
        val sl = cfgMap(cfg, "string_len")
        return intArrayOf(cfgInt(sl, "min", defMin), cfgInt(sl, "max", defMax))
    }

    private fun irange(cfg: Map<String, Any?>): IntArray {
        val ir = cfgMap(cfg, "int_range")
        return intArrayOf(cfgInt(ir, "min", 0), cfgInt(ir, "max", 1_000_000))
    }

    private fun makeMessage(r: Rng): Message =
        Message(
            fBool = r.nextBool(),
            fInt32 = r.nextInt(0, 1_000_000),
            fInt64 = r.nextInt(0, 1_000_000).toLong(),
            fFloat64 = r.nextF64() * 1000,
            fString = r.word(3, 16),
            fBool2 = r.nextBool(),
            fInt32_2 = r.nextInt(0, 1_000_000),
            fString2 = r.word(3, 16),
        )

    private fun makeDocument(r: Rng, cfg: Map<String, Any?>): Document {
        val n = cfgInt(cfg, "children", 8)
        val items = MutableList(n) {
            DocumentItem(r.word(3, 12), r.nextInt(1, 100), r.nextInt(0, 100_000).toLong())
        }
        return Document(
            id = r.word(8, 12),
            status = r.nextInt(0, 5),
            meta = DocumentMeta(r.word(2, 4), r.nextInt(1, 10)),
            items = items,
        )
    }

    private fun makeTelemetry(r: Rng, cfg: Map<String, Any?>): Telemetry {
        val pts = cfgInt(cfg, "points", 32)
        val tagsN = cfgInt(cfg, "tag_count", 2)
        val tags = MutableList(tagsN) { r.word(3, 10) }
        val vals = MutableList(pts) { r.nextF64() * 100 }
        return Telemetry(r.word(3, 10), BASE_TS_MS + r.nextInt(0, 86_400_000), tags, vals)
    }

    private fun makeStrings(r: Rng, cfg: Map<String, Any?>): Strings {
        val n = cfgInt(cfg, "count", 32)
        return Strings(MutableList(n) { r.word(3, 16) })
    }

    private fun makeEvent(r: Rng, cfg: Map<String, Any?>): Event {
        val n = cfgInt(cfg, "attr_count", 4)
        val attrs = MutableList(n) { EventAttr(r.word(3, 12), r.word(3, 12)) }
        return Event(
            r.word(8, 12),
            r.word(3, 12),
            BASE_TS_MS + r.nextInt(0, 86_400_000),
            r.word(3, 12),
            attrs,
        )
    }

    private fun vocab(seed: Long, typeId: String, smin: Int, smax: Int): List<String> {
        val vr = Rng(Rng.mixSeed(seed, "$typeId#vocab", 0))
        return List(32) { vr.word(smin, smax) }
    }

    private fun pick(r: Rng, vocab: List<String>, duplication: Double, smin: Int, smax: Int): String {
        if (vocab.isNotEmpty() && r.nextF64() < duplication) {
            return vocab[r.nextInt(0, vocab.size - 1)]
        }
        return r.word(smin, smax)
    }

    private fun makeTable(r: Rng, cfg: Map<String, Any?>, seed: Long, typeId: String): TableRow {
        val sl = slen(cfg, 3, 16)
        val ir = irange(cfg)
        val dup = cfgDouble(cfg, "duplication", 0.5)
        val words = vocab(seed, typeId, sl[0], sl[1])
        val f = DoubleArray(16) { r.nextF64() * 1000.0 }
        val n = LongArray(4) { r.nextInt(ir[0], ir[1]).toLong() }
        return TableRow(
            fFloat0 = f[0],
            fFloat1 = f[1],
            fFloat2 = f[2],
            fFloat3 = f[3],
            fFloat4 = f[4],
            fFloat5 = f[5],
            fFloat6 = f[6],
            fFloat7 = f[7],
            fFloat8 = f[8],
            fFloat9 = f[9],
            fFloat10 = f[10],
            fFloat11 = f[11],
            fFloat12 = f[12],
            fFloat13 = f[13],
            fFloat14 = f[14],
            fFloat15 = f[15],
            fInt0 = n[0],
            fInt1 = n[1],
            fInt2 = n[2],
            fInt3 = n[3],
            fStr0 = pick(r, words, dup, sl[0], sl[1]),
            fStr1 = pick(r, words, dup, sl[0], sl[1]),
        )
    }

    /** Draw order: id, status, meta, then items. */
    private fun makeNested(r: Rng, cfg: Map<String, Any?>): NestedRow {
        val sl = slen(cfg, 3, 12)
        val children = cfgInt(cfg, "children", 4)
        val row =
            NestedRow(
                id = r.word(8, 12),
                status = r.nextInt(0, 5),
                meta = NestedRow.NestedMeta(r.word(2, 4), r.nextInt(1, 10)),
            )
        repeat(children) {
            row.items.add(
                NestedRow.NestedItem(r.word(sl[0], sl[1]), r.nextInt(1, 100), r.nextInt(0, 100_000).toLong()),
            )
        }
        return row
    }

    /**
     * Domain draw order is fixed fields, then symbol and venue, then legs.
     * leg_pad is the constant 0 and does not consume the PRNG.
     */
    private fun makeSignal(r: Rng, cfg: Map<String, Any?>): Signal {
        val sl = slen(cfg, 3, 12)
        val groups = cfgInt(cfg, "group_count", 4)
        val row =
            Signal(
                seq = r.nextInt(0, 1_000_000_000).toLong(),
                ts = BASE_TS_MS + r.nextInt(0, 86_400_000),
                priceMantissa = r.nextInt(0, 1_000_000_000).toLong(),
                qty = r.nextInt(0, 10_000),
                flags = r.nextInt(0, 65_535),
                symbol = r.word(sl[0], sl[1]),
                venue = r.word(sl[0], sl[1]),
            )
        repeat(groups) {
            row.legs.add(Signal.SignalLeg(r.nextInt(0, 1_000_000).toLong(), r.nextInt(0, 10_000), 0))
        }
        return row
    }
}
