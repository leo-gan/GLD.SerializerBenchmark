package ion

fun decode(raw: ByteArray, cat: Catalog): IonDoc {
    if (
        raw.size >= 4 &&
        u8(raw, 0) == 0xE0 &&
        u8(raw, 1) == 0x01 &&
        u8(raw, 3) == 0xEA
    ) {
        return decodeBinary(raw, cat)
    }
    return decodeText(raw, cat)
}

fun encode(doc: IonDoc, options: EncodeOptions, cat: Catalog): ByteArray {
    return if (options.binary) encodeBinary(doc, options, cat) else encodeText(doc, options)
}

fun decodeAny(raw: ByteArray): IonDoc = decode(raw, Catalog())

fun fieldName(doc: IonDoc, id: Int, index: Int): String {
    val sym = doc.fieldAt(id, index)
    if (sym < 0) return ""
    return doc.symText(sym)
}

fun asI64(doc: IonDoc, id: Int): Long {
    val n = doc.nodes[id]
    if (n.kind != K_INT) throw DecodeError(DecodeError.KIND_TYPE, 0)
    if (n.b == 0) return 0
    if (n.b > 2) throw DecodeError(DecodeError.KIND_RANGE, 0)
    return limbsOfPublic(doc, n.a, n.b, n.c != 0).toI64(0)
}

private fun limbsOfPublic(doc: IonDoc, at: Int, n: Int, neg: Boolean): BigInt {
    val b = BigInt()
    var i = 0
    while (i < n) {
        b.limbs.add(doc.limbs[at + i])
        i++
    }
    b.neg = neg && !b.isZero()
    return b
}

fun asBool(doc: IonDoc, id: Int): Boolean {
    val n = doc.nodes[id]
    if (n.kind != K_BOOL) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return n.a != 0
}

fun asString(doc: IonDoc, id: Int): String {
    if (doc.nodes[id].kind != K_STRING) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.textAt(id)
}

fun asF64(doc: IonDoc, id: Int): Double {
    val n = doc.nodes[id]
    if (n.kind != K_FLOAT) throw DecodeError(DecodeError.KIND_TYPE, 0)
    if (n.a != 0 && n.a != 2 && n.a != 4 && n.a != 8) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return floatValue(doc.floats[n.b], n.a)
}

fun asBytes(doc: IonDoc, id: Int, kind: Int): ByteArray {
    val n = doc.nodes[id]
    if (n.kind != kind) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return doc.blobBytes(n.a)
}

fun ionText(doc: IonDoc, id: Int, expect: Int): String {
    if (expect != 0 && doc.nodes[id].kind != expect) throw DecodeError(DecodeError.KIND_TYPE, 0)
    return formatValue(doc, id)
}
