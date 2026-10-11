package ion

internal fun symUnknown(): SymRef = SymRef(-1, 0, -1, 0)

internal fun symFromSid(doc: IonDoc, tab: LocalTab, sid: Int, offset: Int): Int {
    if (sid < 0) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
    val got = tab.lookup(sid, offset)
    if (sid == 0 || (!got.known && got.imp.isEmpty())) {
        return doc.addSymbolRef(symUnknown())
    }
    if (got.known) {
        val sym = doc.symbolRef(got.text)
        doc.syms[sym].sid = sid
        return doc.wrapSym(sym)
    }
    val imp = doc.intern(got.imp)
    return doc.addSymbolRef(SymRef(-1, sid, imp, got.impSid))
}

internal fun isLocalTable(doc: IonDoc, id: Int): Boolean {
    val n = doc.nodes[id]
    if (n.annN == 0) return false
    val s = doc.syms[doc.anns[n.ann]]
    if (s.text < 0) return false
    if (doc.texts[s.text] != "\$ion_symbol_table") return false
    if (n.kind == K_STRUCT) return true
    return n.kind == K_NULL && n.a == K_STRUCT
}

private fun countField(doc: IonDoc, id: Int, name: String): Int {
    var n = 0
    var i = 0
    val node = doc.nodes[id]
    while (i < node.nchild) {
        val sym = doc.fieldAt(id, i)
        val s = doc.syms[sym]
        if (s.text >= 0 && doc.texts[s.text] == name) n++
        i++
    }
    return n
}

private fun field(doc: IonDoc, id: Int, name: String): Int {
    var i = 0
    val node = doc.nodes[id]
    while (i < node.nchild) {
        val sym = doc.fieldAt(id, i)
        val s = doc.syms[sym]
        if (s.text >= 0 && doc.texts[s.text] == name) return doc.childAt(id, i)
        i++
    }
    return -1
}

private fun asTabInt(doc: IonDoc, id: Int, offset: Int): Long {
    val n = doc.nodes[id]
    if (n.kind != K_INT) throw DecodeError(DecodeError.KIND_TYPE, offset)
    if (n.b == 0) return 0L
    if (n.b > 2) throw DecodeError(DecodeError.KIND_RANGE, offset)
    var mag = u32(doc.limbs[n.a])
    if (n.b > 1) mag = mag or (u32(doc.limbs[n.a + 1]) shl 32)
    if (n.c != 0) {
        if (mag < 0L && mag != Long.MIN_VALUE) throw DecodeError(DecodeError.KIND_RANGE, offset)
        if (mag == Long.MIN_VALUE) throw DecodeError(DecodeError.KIND_RANGE, offset)
        return -mag
    }
    if (mag < 0L) throw DecodeError(DecodeError.KIND_RANGE, offset)
    return mag
}

internal fun applyLst(doc: IonDoc, id: Int, tab: LocalTab, cat: Catalog, offset: Int) {
    val n = doc.nodes[id]
    if (n.kind == K_NULL) {
        tab.resetSystem()
        return
    }
    val imp = field(doc, id, "imports")
    if (countField(doc, id, "imports") > 1 || countField(doc, id, "symbols") > 1) {
        throw DecodeError(DecodeError.KIND_SYMBOL, offset)
    }
    val extend = imp >= 0 && doc.nodes[imp].kind == K_SYMBOL && doc.symText(doc.nodes[imp].a) == "\$ion_symbol_table"
    if (!extend) {
        if (imp >= 0 && doc.nodes[imp].kind == K_LIST) {
            tab.resetSystem()
            var i = 0
            while (i < doc.nodes[imp].nchild) {
                val el = doc.childAt(imp, i)
                if (doc.nodes[el].kind == K_STRUCT) importOne(doc, el, tab, cat, offset)
                i++
            }
        } else if (imp < 0 || doc.nodes[imp].kind == K_NULL) {
            tab.resetSystem()
        } else {
            throw DecodeError(DecodeError.KIND_SYMBOL, offset)
        }
    }
    val syms = field(doc, id, "symbols")
    if (syms >= 0 && doc.nodes[syms].kind == K_LIST) {
        var i = 0
        while (i < doc.nodes[syms].nchild) {
            val el = doc.childAt(syms, i)
            if (doc.nodes[el].kind == K_STRING) tab.addText(doc.textAt(el)) else tab.addGap()
            i++
        }
    }
}

private fun importOne(doc: IonDoc, id: Int, tab: LocalTab, cat: Catalog, offset: Int) {
    val nameId = field(doc, id, "name")
    if (nameId < 0 || doc.nodes[nameId].kind != K_STRING) return
    val name = doc.textAt(nameId)
    if (name.isEmpty() || name == "\$ion") return
    var version = 1
    val verId = field(doc, id, "version")
    if (verId >= 0 && doc.nodes[verId].kind == K_INT) {
        val v = asTabInt(doc, verId, offset)
        if (v >= 1) version = v.toInt()
    }
    var hasMax = false
    var maxId = 0
    val maxAt = field(doc, id, "max_id")
    if (maxAt >= 0 && doc.nodes[maxAt].kind == K_INT) {
        val m = asTabInt(doc, maxAt, offset)
        if (m >= 0) {
            if (m > Int.MAX_VALUE) throw DecodeError(DecodeError.KIND_RANGE, offset)
            hasMax = true
            maxId = m.toInt()
        }
    }
    if (hasMax && maxId == 0) return
    var idx = cat.exact(name, version)
    if (idx < 0) {
        if (!hasMax) throw DecodeError(DecodeError.KIND_SYMBOL, offset)
        idx = cat.greatest(name)
    }
    if (idx < 0) {
        tab.importTable(SharedTable(name, version), maxId, offset)
        return
    }
    if (!hasMax) maxId = cat.tables[idx].texts.size
    tab.importTable(cat.tables[idx], maxId, offset)
}
