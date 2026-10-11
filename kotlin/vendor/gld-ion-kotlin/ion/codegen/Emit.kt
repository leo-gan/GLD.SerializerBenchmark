package ion.codegen

import ion.DecodeError
import ion.schema.Schema
import ion.schema.TY_BOOL
import ion.schema.TY_BYTES
import ion.schema.TY_FLOAT
import ion.schema.TY_INT
import ion.schema.TY_ION
import ion.schema.TY_LIST
import ion.schema.TY_STRING
import ion.schema.TY_STRUCT

private val KEYWORDS = setOf(
    "as", "break", "class", "continue", "do", "else", "false", "for", "fun", "if", "in",
    "interface", "is", "null", "object", "package", "return", "super", "this", "throw",
    "true", "try", "typealias", "typeof", "val", "var", "when", "while", "by", "catch",
    "constructor", "delegate", "dynamic", "field", "file", "finally", "get", "import",
    "init", "param", "property", "receiver", "set", "setparam", "where", "actual",
    "abstract", "annotation", "companion", "const", "crossinline", "data", "enum",
    "expect", "external", "final", "infix", "inline", "inner", "internal", "lateinit",
    "noinline", "open", "operator", "out", "override", "private", "protected", "public",
    "reified", "sealed", "suspend", "tailrec", "vararg", "yield", "it",
)

fun sanitize(name: String): String {
    val out = StringBuilder()
    var i = 0
    while (i < name.length) {
        val c = name[i]
        val ok = c in 'A'..'Z' || c in 'a'..'z' || c == '_' || (i > 0 && c in '0'..'9')
        if (ok) out.append(c) else out.append('_')
        i++
    }
    if (out.isEmpty()) return "Value"
    if (out[0] in '0'..'9') out.insert(0, "T_")
    return out.toString()
}

private fun kt(name: String): String {
    val s = sanitize(name)
    return if (s in KEYWORDS) "`$s`" else s
}

fun emitAll(schema: Schema): List<String> {
    val out = ArrayList<String>()
    var i = 0
    while (i < schema.typeName.size) {
        if (schema.typeKind[i] == TY_STRUCT && schema.typeName[i].isNotEmpty()) {
            val name = kt(schema.typeName[i])
            out.add(name.removeSurrounding("`"))
            out.add(emitStruct(schema, i, name))
        }
        i++
    }
    if (out.isEmpty()) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    return out
}

private fun emitStruct(schema: Schema, idx: Int, name: String): String {
    val rawName = name.removeSurrounding("`")
    val src = StringBuilder()
    src.append("package ion.generated\n\n")
    src.append("import ion.Catalog\n")
    src.append("import ion.DecodeError\n")
    src.append("import ion.EncodeOptions\n")
    src.append("import ion.IonDoc\n")
    src.append("import ion.K_BLOB\n")
    src.append("import ion.K_CLOB\n")
    src.append("import ion.K_LIST\n")
    src.append("import ion.K_STRUCT\n")
    src.append("import ion.asBool\n")
    src.append("import ion.asBytes\n")
    src.append("import ion.asF64\n")
    src.append("import ion.asI64\n")
    src.append("import ion.asString\n")
    src.append("import ion.decodeAny\n")
    src.append("import ion.encodeBinary\n")
    src.append("import ion.encodeText\n")
    src.append("import ion.fieldName\n")
    src.append("import ion.ionText\n")
    src.append("import ion.parseIon\n")
    val seen = ArrayList<String>()
    var f = 0
    while (f < schema.fieldN[idx]) {
        noteImport(schema, schema.fieldType[schema.fieldAt[idx] + f], rawName, seen)
        f++
    }
    for (s in seen) src.append("import ion.generated.").append(s).append("\n")
    src.append("\nclass ").append(name).append(" {\n")
    f = 0
    while (f < schema.fieldN[idx]) {
        val at = schema.fieldAt[idx] + f
        val ident = kt(schema.fieldName[at])
        val tid = schema.fieldType[at]
        if (!schema.fieldReq[at]) {
            src.append("    var ").append(flag(schema.fieldName[at])).append(": Boolean = false\n")
        }
        src.append("    var ").append(ident).append(": ").append(ktype(schema, tid)).append(" = ")
            .append(defaultExpr(schema, tid)).append("\n")
        f++
    }
    src.append("\n    fun encodedLength(options: EncodeOptions): Int = encodeTo(options).size\n")
    src.append("\n    fun encode(options: EncodeOptions): ByteArray = encodeTo(options)\n")
    src.append("\n    fun encodeTo(options: EncodeOptions): ByteArray {\n")
    src.append("        val doc = toDoc()\n")
    src.append("        val cat = Catalog()\n")
    src.append("        return if (options.binary) encodeBinary(doc, options, cat) else encodeText(doc, options)\n")
    src.append("    }\n")
    src.append("\n    fun toDoc(): IonDoc {\n")
    src.append("        val doc = IonDoc()\n")
    src.append("        val st = writeInto(doc)\n")
    src.append("        doc.addTop(st)\n")
    src.append("        return doc\n")
    src.append("    }\n")
    src.append("\n    fun writeInto(doc: IonDoc): Int {\n")
    src.append("        val st = doc.startContainer(K_STRUCT)\n")
    f = 0
    while (f < schema.fieldN[idx]) {
        val at = schema.fieldAt[idx] + f
        src.append(writeField(schema, schema.fieldName[at], schema.fieldType[at], schema.fieldReq[at]))
        f++
    }
    src.append("        return st\n")
    src.append("    }\n")
    src.append("\n    companion object {\n")
    src.append("        fun decode(raw: ByteArray): ").append(name).append(" = decodeFrom(raw)\n\n")
    src.append("        fun decodeFrom(raw: ByteArray): ").append(name).append(" {\n")
    src.append("            val doc = decodeAny(raw)\n")
    src.append("            if (doc.top.size != 1) throw DecodeError(DecodeError.KIND_TYPE, 0)\n")
    src.append("            return fromDoc(doc, doc.top[0])\n")
    src.append("        }\n")
    src.append("\n        fun fromDoc(doc: IonDoc, id: Int): ").append(name).append(" {\n")
    src.append("            if (doc.nodes[id].kind != K_STRUCT) throw DecodeError(DecodeError.KIND_TYPE, 0)\n")
    src.append("            val out = ").append(name).append("()\n")
    f = 0
    while (f < schema.fieldN[idx]) {
        val at = schema.fieldAt[idx] + f
        if (schema.fieldReq[at]) {
            src.append("            var got_").append(slug(schema.fieldName[at])).append(" = false\n")
        }
        f++
    }
    src.append("            var i = 0\n")
    src.append("            while (i < doc.nodes[id].nchild) {\n")
    src.append("                val fname = fieldName(doc, id, i)\n")
    src.append("                val child = doc.childAt(id, i)\n")
    f = 0
    while (f < schema.fieldN[idx]) {
        val at = schema.fieldAt[idx] + f
        val kw = if (f == 0) "if" else "else if"
        src.append("                ").append(kw).append(" (fname == \"")
            .append(escape(schema.fieldName[at])).append("\") {\n")
        src.append(readField(schema, schema.fieldName[at], schema.fieldType[at], schema.fieldReq[at]))
        src.append("                }\n")
        f++
    }
    if (schema.fieldN[idx] == 0) {
        src.append("                fname.length\n")
    } else {
        src.append("                else {\n")
        if (schema.typeClosed[idx] != 0) {
            src.append("                    throw DecodeError(DecodeError.KIND_SCHEMA, 0)\n")
        }
        src.append("                }\n")
    }
    src.append("                i++\n")
    src.append("            }\n")
    f = 0
    while (f < schema.fieldN[idx]) {
        val at = schema.fieldAt[idx] + f
        if (schema.fieldReq[at]) {
            val slug = slug(schema.fieldName[at])
            src.append("            if (!got_").append(slug).append(") throw DecodeError(DecodeError.KIND_SCHEMA, 0)\n")
        }
        f++
    }
    src.append("            return out\n")
    src.append("        }\n")
    src.append("    }\n")
    src.append("}\n")
    return src.toString()
}

private fun noteImport(schema: Schema, tid: Int, selfName: String, seen: ArrayList<String>) {
    val kind = schema.typeKind[tid]
    if (kind == TY_STRUCT) {
        val nm = sanitize(schema.typeName[tid])
        if (nm != selfName && nm !in seen) seen.add(nm)
        return
    }
    if (kind == TY_LIST) noteImport(schema, schema.typeInner[tid], selfName, seen)
}

private fun flag(ionName: String): String {
    val s = sanitize(ionName)
    val text = "has" + s.replaceFirstChar { it.uppercase() }
    return if (text in KEYWORDS) "`$text`" else text
}

private fun slug(text: String): String {
    val out = StringBuilder()
    for (c in text) {
        if (c in 'A'..'Z' || c in 'a'..'z' || c in '0'..'9') out.append(c) else out.append('_')
    }
    return out.toString()
}

private fun escape(text: String): String = text.replace("\\", "\\\\").replace("\"", "\\\"")

private fun ktype(schema: Schema, tid: Int): String {
    return when (schema.typeKind[tid]) {
        TY_INT -> "Long"
        TY_BOOL -> "Boolean"
        TY_STRING, TY_ION -> "String"
        TY_FLOAT -> "Double"
        TY_BYTES -> "ByteArray"
        TY_STRUCT -> kt(schema.typeName[tid])
        TY_LIST -> "MutableList<" + ktype(schema, schema.typeInner[tid]) + ">"
        else -> throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    }
}

private fun defaultExpr(schema: Schema, tid: Int): String {
    return when (schema.typeKind[tid]) {
        TY_INT -> "0L"
        TY_BOOL -> "false"
        TY_STRING, TY_ION -> "\"\""
        TY_FLOAT -> "0.0"
        TY_BYTES -> "ByteArray(0)"
        TY_LIST -> "mutableListOf()"
        TY_STRUCT -> kt(schema.typeName[tid]) + "()"
        else -> throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    }
}

private fun writeField(schema: Schema, ionName: String, tid: Int, required: Boolean): String {
    val ident = kt(ionName)
    val body = StringBuilder()
    var pad = "        "
    if (!required) {
        body.append(pad).append("if (").append(flag(ionName)).append(") {\n")
        pad = "            "
    }
    val sym = "sym_" + slug(ionName)
    val slot = "slot_" + slug(ionName)
    val dest = "val_" + slug(ionName)
    body.append(pad).append("val ").append(sym).append(" = doc.addSymbolText(\"").append(escape(ionName)).append("\")\n")
    body.append(pad).append("val ").append(slot).append(" = doc.nodes[").append(sym).append("].a\n")
    body.append(writeValue(schema, tid, ident, dest, pad))
    body.append(pad).append("doc.addChild(st, ").append(dest).append(", ").append(slot).append(")\n")
    if (!required) body.append("        }\n")
    return body.toString()
}

private fun writeValue(schema: Schema, tid: Int, expr: String, dest: String, pad: String): String {
    return when (schema.typeKind[tid]) {
        TY_INT -> pad + "val " + dest + " = doc.addI64(" + expr + ")\n"
        TY_BOOL -> pad + "val " + dest + " = doc.addBool(" + expr + ")\n"
        TY_STRING -> pad + "val " + dest + " = doc.addString(" + expr + ")\n"
        TY_FLOAT -> pad + "val " + dest + " = doc.addFloat(8, " + expr + ".toRawBits())\n"
        TY_ION -> pad + "val " + dest + " = parseIon(doc, " + expr + ", " + schema.typeExpect[tid] + ")\n"
        TY_BYTES -> pad + "val " + dest + " = doc.addBytes(" + schema.typeExpect[tid] + ", " + expr + ")\n"
        TY_STRUCT -> pad + "val " + dest + " = " + expr + ".writeInto(doc)\n"
        TY_LIST -> {
            val inner = schema.typeInner[tid]
            val item = "item_" + slug(dest)
            val j = "j_" + slug(dest)
            val line = StringBuilder()
            line.append(pad).append("val ").append(dest).append(" = doc.startContainer(K_LIST)\n")
            line.append(pad).append("var ").append(j).append(" = 0\n")
            line.append(pad).append("while (").append(j).append(" < ").append(expr).append(".size) {\n")
            line.append(writeValue(schema, inner, expr + "[" + j + "]", item, pad + "    "))
            line.append(pad).append("    doc.addChild(").append(dest).append(", ").append(item).append(", -1)\n")
            line.append(pad).append("    ").append(j).append("++\n")
            line.append(pad).append("}\n")
            line.toString()
        }
        else -> throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    }
}

private fun readField(schema: Schema, ionName: String, tid: Int, required: Boolean): String {
    val ident = "out." + kt(ionName)
    val body = StringBuilder()
    body.append(readValue(schema, tid, "child", ident, "                    "))
    if (!required) {
        body.append("                    out.").append(flag(ionName)).append(" = true\n")
    } else {
        body.append("                    got_").append(slug(ionName)).append(" = true\n")
    }
    return body.toString()
}

private fun readValue(schema: Schema, tid: Int, expr: String, dest: String, pad: String): String {
    return when (schema.typeKind[tid]) {
        TY_INT -> pad + dest + " = asI64(doc, " + expr + ")\n"
        TY_BOOL -> pad + dest + " = asBool(doc, " + expr + ")\n"
        TY_STRING -> pad + dest + " = asString(doc, " + expr + ")\n"
        TY_FLOAT -> pad + dest + " = asF64(doc, " + expr + ")\n"
        TY_ION -> pad + dest + " = ionText(doc, " + expr + ", " + schema.typeExpect[tid] + ")\n"
        TY_BYTES -> pad + dest + " = asBytes(doc, " + expr + ", " + schema.typeExpect[tid] + ")\n"
        TY_STRUCT -> pad + dest + " = " + kt(schema.typeName[tid]) + ".fromDoc(doc, " + expr + ")\n"
        TY_LIST -> {
            val inner = schema.typeInner[tid]
            val item = "item_" + slug(dest)
            val j = "j_" + slug(dest)
            val line = StringBuilder()
            line.append(pad).append("if (doc.nodes[").append(expr).append("].kind != K_LIST) {\n")
            line.append(pad).append("    throw DecodeError(DecodeError.KIND_TYPE, 0)\n")
            line.append(pad).append("}\n")
            line.append(pad).append("var ").append(item).append(" = ").append(defaultExpr(schema, inner)).append("\n")
            line.append(pad).append("var ").append(j).append(" = 0\n")
            line.append(pad).append("while (").append(j).append(" < doc.nodes[").append(expr).append("].nchild) {\n")
            line.append(readValue(schema, inner, "doc.childAt(" + expr + ", " + j + ")", item, pad + "    "))
            line.append(pad).append("    ").append(dest).append(".add(").append(item).append(")\n")
            line.append(pad).append("    ").append(j).append("++\n")
            line.append(pad).append("}\n")
            line.toString()
        }
        else -> throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    }
}
