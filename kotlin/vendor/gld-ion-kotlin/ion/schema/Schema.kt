package ion.schema

import ion.Catalog
import ion.DecodeError
import ion.IonDoc
import ion.K_BLOB
import ion.K_BOOL
import ion.K_CLOB
import ion.K_DECIMAL
import ion.K_LIST
import ion.K_SEXP
import ion.K_STRING
import ion.K_STRUCT
import ion.K_SYMBOL
import ion.K_TIMESTAMP
import ion.decodeText
import java.io.File

const val TY_INT = 1
const val TY_BOOL = 2
const val TY_STRING = 3
const val TY_FLOAT = 4
const val TY_ION = 5
const val TY_BYTES = 6
const val TY_STRUCT = 7
const val TY_LIST = 8

class Schema {
    val typeName = ArrayList<String>()
    val typeKind = ArrayList<Int>()
    val typeExpect = ArrayList<Int>()
    val typeInner = ArrayList<Int>()
    val typeRef = ArrayList<String>()
    val typeClosed = ArrayList<Int>()
    val fieldAt = ArrayList<Int>()
    val fieldN = ArrayList<Int>()
    val fieldName = ArrayList<String>()
    val fieldType = ArrayList<Int>()
    val fieldReq = ArrayList<Boolean>()
    val fieldRef = ArrayList<String>()

    init {
        prim("int", TY_INT, 0)
        prim("bool", TY_BOOL, 0)
        prim("string", TY_STRING, 0)
        prim("float", TY_FLOAT, 0)
        prim("decimal", TY_ION, K_DECIMAL)
        prim("timestamp", TY_ION, K_TIMESTAMP)
        prim("symbol", TY_ION, K_SYMBOL)
        prim("blob", TY_BYTES, K_BLOB)
        prim("clob", TY_BYTES, K_CLOB)
        prim("sexp", TY_ION, K_SEXP)
    }

    private fun prim(name: String, kind: Int, expect: Int) {
        typeName.add(name)
        typeKind.add(kind)
        typeExpect.add(expect)
        typeInner.add(-1)
        typeRef.add("")
        typeClosed.add(0)
        fieldAt.add(0)
        fieldN.add(0)
    }

    fun find(name: String): Int {
        var i = 0
        while (i < typeName.size) {
            if (typeName[i] == name) return i
            i++
        }
        return -1
    }
}

fun parseSchemaFile(path: String): Schema {
    val data = File(path).readBytes()
    val doc = decodeText(data, Catalog())
    return schemaFromDoc(doc)
}

fun schemaFromDoc(doc: IonDoc): Schema {
    val schema = Schema()
    if (doc.top.isEmpty()) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    val first = doc.top[0]
    if (isJson(doc, first)) {
        jsonRoot(doc, schema, first, "Document")
    } else {
        var i = 0
        while (i < doc.top.size) {
            registerIon(doc, schema, doc.top[i])
            i++
        }
        i = 0
        while (i < doc.top.size) {
            fillIon(doc, schema, doc.top[i])
            i++
        }
    }
    resolve(schema)
    return schema
}

private fun isJson(doc: IonDoc, id: Int): Boolean {
    if (doc.nodes[id].kind != K_STRUCT) return false
    if (doc.nodes[id].annN != 0) return false
    return findField(doc, id, "properties") >= 0 ||
        findField(doc, id, "\$defs") >= 0 ||
        findField(doc, id, "definitions") >= 0
}

private fun registerIon(doc: IonDoc, schema: Schema, id: Int) {
    if (doc.nodes[id].kind != K_STRUCT) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    val name = typeNameOf(doc, id, "")
    if (name.isEmpty()) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    if (schema.find(name) < 0) alloc(schema, name, TY_STRUCT, 0, -1)
}

private fun fillIon(doc: IonDoc, schema: Schema, id: Int) {
    val name = typeNameOf(doc, id, "")
    val idx = schema.find(name)
    if (idx < 0) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    fillStruct(doc, schema, idx, id, name)
}

private fun jsonRoot(doc: IonDoc, schema: Schema, id: Int, fallback: String) {
    var defs = findField(doc, id, "\$defs")
    if (defs < 0) defs = findField(doc, id, "definitions")
    if (defs >= 0) {
        var i = 0
        while (i < doc.nodes[defs].nchild) {
            val nm = fieldName(doc, defs, i)
            if (schema.find(nm) < 0) alloc(schema, nm, TY_STRUCT, 0, -1)
            i++
        }
        i = 0
        while (i < doc.nodes[defs].nchild) {
            val child = doc.childAt(defs, i)
            val nm = fieldName(doc, defs, i)
            val idx = schema.find(nm)
            fillStruct(doc, schema, idx, child, nm)
            i++
        }
    }
    val name = typeNameOf(doc, id, fallback)
    var idx = schema.find(name)
    if (idx < 0) idx = alloc(schema, name, TY_STRUCT, 0, -1)
    fillStruct(doc, schema, idx, id, name)
}

private fun fillStruct(doc: IonDoc, schema: Schema, idx: Int, id: Int, parent: String) {
    if (schema.fieldN[idx] != 0) return
    var closed = 0
    val addl = findField(doc, id, "additionalProperties")
    if (addl >= 0 && doc.nodes[addl].kind == K_BOOL && doc.nodes[addl].a == 0) closed = 1
    val content = findField(doc, id, "content")
    if (content >= 0 && nodeText(doc, content) == "closed") closed = 1
    schema.typeClosed[idx] = closed
    var fields = findField(doc, id, "fields")
    if (fields < 0) fields = findField(doc, id, "properties")
    val required = findField(doc, id, "required")
    val at = schema.fieldName.size
    var n = 0
    if (fields >= 0 && doc.nodes[fields].kind == K_STRUCT) {
        var i = 0
        while (i < doc.nodes[fields].nchild) {
            val fname = fieldName(doc, fields, i)
            val child = doc.childAt(fields, i)
            var req = true
            if (required >= 0) req = listHas(doc, required, fname)
            else if (occursOptional(doc, child)) req = false
            val tid = valueType(doc, schema, parent, fname, child)
            schema.fieldName.add(fname)
            schema.fieldType.add(tid)
            schema.fieldReq.add(req)
            schema.fieldRef.add(if (tid < 0) refName(doc, child) else "")
            n++
            i++
        }
    }
    schema.fieldAt[idx] = at
    schema.fieldN[idx] = n
}

private fun valueType(doc: IonDoc, schema: Schema, parent: String, hint: String, id: Int): Int {
    if (id < 0) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    val kind = doc.nodes[id].kind
    if (kind == K_SYMBOL || kind == K_STRING) return lookup(schema, nodeText(doc, id))
    if (kind != K_STRUCT) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    val link = findField(doc, id, "\$ref")
    if (link >= 0) return lookup(schema, lastSegment(nodeText(doc, link)))
    var label = ""
    val ionT = findField(doc, id, "ionType")
    if (ionT >= 0) label = nodeText(doc, ionT)
    else {
        val ty = findField(doc, id, "type")
        if (ty >= 0) label = nodeText(doc, ty)
    }
    if (label == "object" || label == "struct" || findField(doc, id, "properties") >= 0 || findField(doc, id, "fields") >= 0) {
        val nm = typeNameOf(doc, id, parent + "_" + hint)
        var idx = schema.find(nm)
        if (idx < 0) idx = alloc(schema, nm, TY_STRUCT, 0, -1)
        fillStruct(doc, schema, idx, id, nm)
        return idx
    }
    if (label == "array" || label == "list") {
        var elem = findField(doc, id, "items")
        if (elem < 0) elem = findField(doc, id, "element")
        if (elem < 0) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
        val inner = valueType(doc, schema, parent, hint + "_item", elem)
        val listId = alloc(schema, "", TY_LIST, 0, inner)
        if (inner < 0) schema.typeRef[listId] = refName(doc, elem)
        return listId
    }
    if (label == "sexp") return 9
    if (label.isEmpty()) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
    return lookup(schema, label)
}

private fun lookup(schema: Schema, name: String): Int = when (name) {
    "integer" -> 0
    "boolean" -> 1
    "number" -> 3
    else -> schema.find(name)
}

private fun refName(doc: IonDoc, id: Int): String {
    if (doc.nodes[id].kind == K_SYMBOL || doc.nodes[id].kind == K_STRING) return nodeText(doc, id)
    val link = findField(doc, id, "\$ref")
    if (link >= 0) return lastSegment(nodeText(doc, link))
    val ty = findField(doc, id, "type")
    if (ty >= 0) return nodeText(doc, ty)
    var elem = findField(doc, id, "element")
    if (elem < 0) elem = findField(doc, id, "items")
    if (elem >= 0) return refName(doc, elem)
    return ""
}

private fun occursOptional(doc: IonDoc, id: Int): Boolean {
    if (doc.nodes[id].kind != K_STRUCT) return false
    val occ = findField(doc, id, "occurs")
    if (occ < 0) return false
    return nodeText(doc, occ) == "optional"
}

private fun resolve(schema: Schema) {
    var i = 0
    while (i < schema.fieldName.size) {
        if (schema.fieldType[i] < 0) {
            val idx = schema.find(schema.fieldRef[i])
            if (idx < 0) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
            schema.fieldType[i] = idx
        }
        i++
    }
    i = 0
    while (i < schema.typeName.size) {
        if (schema.typeKind[i] == TY_LIST && schema.typeInner[i] < 0) {
            val idx = schema.find(schema.typeRef[i])
            if (idx < 0) throw DecodeError(DecodeError.KIND_SCHEMA, 0)
            schema.typeInner[i] = idx
        }
        i++
    }
}

private fun alloc(schema: Schema, name: String, kind: Int, expect: Int, inner: Int): Int {
    schema.typeName.add(name)
    schema.typeKind.add(kind)
    schema.typeExpect.add(expect)
    schema.typeInner.add(inner)
    schema.typeRef.add("")
    schema.typeClosed.add(0)
    schema.fieldAt.add(0)
    schema.fieldN.add(0)
    return schema.typeName.size - 1
}

private fun typeNameOf(doc: IonDoc, id: Int, fallback: String): String {
    val title = findField(doc, id, "title")
    if (title >= 0) {
        val text = nodeText(doc, title)
        if (text.isNotEmpty()) return text
    }
    val name = findField(doc, id, "name")
    if (name >= 0) {
        val text = nodeText(doc, name)
        if (text.isNotEmpty()) return text
    }
    val idField = findField(doc, id, "\$id")
    if (idField >= 0) return lastSegment(nodeText(doc, idField))
    return fallback
}

private fun lastSegment(text: String): String {
    val slash = text.lastIndexOf('/')
    return if (slash < 0) text else text.substring(slash + 1)
}

private fun findField(doc: IonDoc, id: Int, name: String): Int {
    if (id < 0 || doc.nodes[id].kind != K_STRUCT) return -1
    var i = 0
    while (i < doc.nodes[id].nchild) {
        if (fieldName(doc, id, i) == name) return doc.childAt(id, i)
        i++
    }
    return -1
}

private fun fieldName(doc: IonDoc, id: Int, index: Int): String {
    val sym = doc.fieldAt(id, index)
    if (sym < 0) return ""
    return doc.symText(sym)
}

private fun nodeText(doc: IonDoc, id: Int): String {
    val kind = doc.nodes[id].kind
    if (kind == K_STRING) return doc.textAt(id)
    if (kind == K_SYMBOL) return doc.symText(doc.nodes[id].a)
    return ""
}

private fun listHas(doc: IonDoc, id: Int, name: String): Boolean {
    if (doc.nodes[id].kind != K_LIST) return false
    var i = 0
    while (i < doc.nodes[id].nchild) {
        if (nodeText(doc, doc.childAt(id, i)) == name) return true
        i++
    }
    return false
}
