package ion

internal fun sysName(sid: Int): String = when (sid) {
    1 -> "\$ion"
    2 -> "\$ion_1_0"
    3 -> "\$ion_symbol_table"
    4 -> "name"
    5 -> "version"
    6 -> "imports"
    7 -> "symbols"
    8 -> "max_id"
    9 -> "\$ion_shared_symbol_table"
    else -> ""
}

internal class TabSlot {
    val tab = LocalTab()
    var busy = false
}

internal val tabSlot = ThreadLocal.withInitial { TabSlot() }

internal inline fun <T> withLocalTab(body: (LocalTab) -> T): T {
    val slot = tabSlot.get()
    if (slot.busy) return body(LocalTab())
    slot.busy = true
    slot.tab.resetSystem()
    try {
        return body(slot.tab)
    } finally {
        slot.busy = false
    }
}

internal fun sysSid(text: String): Int {
    if (text.isEmpty()) return 0
    return when (text) {
        "name" -> 4
        "\$ion" -> 1
        "\$ion_1_0" -> 2
        "\$ion_symbol_table" -> 3
        "version" -> 5
        "imports" -> 6
        "symbols" -> 7
        "max_id" -> 8
        "\$ion_shared_symbol_table" -> 9
        else -> 0
    }
}

class SharedTable(val name: String, val version: Int) {
    val texts = ArrayList<String>()
    val gap = ArrayList<Boolean>()

    fun add(text: String, isGap: Boolean) {
        texts.add(text)
        gap.add(isGap)
    }
}

class Catalog {
    val tables = ArrayList<SharedTable>()

    fun add(table: SharedTable) {
        tables.add(table)
    }

    fun exact(name: String, version: Int): Int {
        var i = 0
        while (i < tables.size) {
            if (tables[i].name == name && tables[i].version == version) return i
            i++
        }
        return -1
    }

    fun greatest(name: String): Int {
        var best = -1
        var bestVer = -1
        var i = 0
        while (i < tables.size) {
            if (tables[i].name == name && tables[i].version > bestVer) {
                best = i
                bestVer = tables[i].version
            }
            i++
        }
        return best
    }
}

internal class TabSeg {
    var start: Int = 0
    var count: Int = 0
    var flatAt: Int = -1
    var flatN: Int = 0
    var nameAt: Int = -1
}

internal class Resolved {
    var known: Boolean = false
    var text: String = ""
    var imp: String = ""
    var impSid: Int = 0
}

internal class LocalTab {
    val text = ArrayList<String>()
    val known = ArrayList<Boolean>()
    val names = ArrayList<String>()
    val segs = ArrayList<TabSeg>()
    var maxId: Int = SYS_MAX
    private val resolved = Resolved()

    init {
        text.add("")
        known.add(false)
        val seg = TabSeg()
        seg.start = 1
        seg.count = SYS_MAX
        seg.flatAt = 1
        seg.flatN = 0
        segs.add(seg)
    }

    fun resetSystem() {
        while (segs.size > 1) segs.removeAt(segs.lastIndex)
        while (text.size > 1) {
            text.removeAt(text.lastIndex)
            known.removeAt(known.lastIndex)
        }
        maxId = SYS_MAX
        val seg = segs[0]
        seg.count = SYS_MAX
        seg.flatN = 0
    }

    private fun addFlat(value: String, isKnown: Boolean): Int {
        val lastI = segs.size - 1
        val last = segs[lastI]
        if (last.nameAt < 0 && last.start + last.count == maxId + 1 && lastI > 0) {
            text.add(value)
            known.add(isKnown)
            last.count++
            last.flatN++
            maxId++
            return maxId
        }
        val seg = TabSeg()
        seg.start = maxId + 1
        seg.count = 1
        seg.flatAt = text.size
        seg.flatN = 1
        text.add(value)
        known.add(isKnown)
        segs.add(seg)
        maxId++
        return maxId
    }

    fun addText(value: String): Int = addFlat(value, true)

    fun addGap(): Int = addFlat("", false)

    fun lookup(sid: Int, offset: Int): Resolved {
        if (sid < 0 || sid > maxId) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
        val out = resolved
        out.known = false
        out.text = ""
        out.imp = ""
        out.impSid = 0
        if (sid == 0) return out
        if (sid <= SYS_MAX) {
            out.known = true
            out.text = sysName(sid)
            return out
        }
        var s = 0
        while (s < segs.size) {
            val seg = segs[s]
            if (sid >= seg.start && sid < seg.start + seg.count) {
                val off = sid - seg.start
                if (seg.nameAt < 0) {
                    val at = seg.flatAt + off
                    if (known[at]) {
                        out.known = true
                        out.text = text[at]
                    }
                    return out
                }
                if (off < seg.flatN && known[seg.flatAt + off]) {
                    out.known = true
                    out.text = text[seg.flatAt + off]
                    return out
                }
                out.imp = names[seg.nameAt]
                out.impSid = off + 1
                return out
            }
            s++
        }
        throw DecodeError(DecodeError.KIND_SYMBOL, offset)
    }

    fun importTable(table: SharedTable, maxIn: Int, offset: Int) {
        if (maxIn < 0) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
        var prefix = table.texts.size
        if (prefix > maxIn) prefix = maxIn
        val seg = TabSeg()
        seg.start = maxId + 1
        seg.count = maxIn
        seg.nameAt = names.size
        names.add(table.name)
        if (prefix > 0) {
            seg.flatAt = text.size
            seg.flatN = prefix
            var i = 0
            while (i < prefix) {
                if (table.gap[i]) {
                    text.add("")
                    known.add(false)
                } else {
                    text.add(table.texts[i])
                    known.add(true)
                }
                i++
            }
        }
        segs.add(seg)
        maxId += maxIn
    }
}
