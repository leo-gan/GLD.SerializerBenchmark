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
            else -> throw IllegalArgumentException("unknown type_id: $typeId")
        }
    }

    fun instances(typeId: String, typeConfig: Map<String, Any?>, seed: Long, n: Int): List<Any> =
        (0 until n).map { makeOne(typeId, typeConfig, seed, it) }

    private fun cfgInt(m: Map<String, Any?>?, key: String, def: Int): Int {
        val v = m?.get(key) ?: return def
        return if (v is Number) v.toInt() else def
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
}
