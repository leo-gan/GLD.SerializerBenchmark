from std.collections import List, Span

from bson_runtime.decimal import decimal_from_list
from bson_runtime.error import DecodeError
from bson_wire.reader import WireReader
from bson_wire.types import (
    BK_ARRAY,
    BK_BINARY,
    BK_BOOL,
    BK_CODE,
    BK_CODEWS,
    BK_DATETIME,
    BK_DBPOINTER,
    BK_DECIMAL,
    BK_DOC,
    BK_DOUBLE,
    BK_INT32,
    BK_INT64,
    BK_MAXKEY,
    BK_MINKEY,
    BK_NULL,
    BK_OID,
    BK_REGEX,
    BK_STRING,
    BK_SYMBOL,
    BK_TIMESTAMP,
    BK_UNDEFINED,
    MAX_DEPTH,
    TY_ARRAY,
    TY_BINARY,
    TY_BOOL,
    TY_CODE,
    TY_CODEWS,
    TY_DATETIME,
    TY_DBPOINTER,
    TY_DECIMAL128,
    TY_DOCUMENT,
    TY_DOUBLE,
    TY_INT32,
    TY_INT64,
    TY_MAXKEY,
    TY_MINKEY,
    TY_NULL,
    TY_OBJECTID,
    TY_REGEX,
    TY_STRING,
    TY_SYMBOL,
    TY_TIMESTAMP,
    TY_UNDEFINED,
)
from bson_wire.writer import WireWriter, digit_count


struct Node(Movable):
    var kind: Int
    var key: String
    var s0: String
    var s1: String
    var i64: Int64
    var f64: Float64
    var raw: List[Byte]
    var sub: Int
    var kids: List[Int]

    def __init__(out self):
        self.kind = BK_NULL
        self.key = ""
        self.s0 = ""
        self.s1 = ""
        self.i64 = 0
        self.f64 = 0.0
        self.raw = List[Byte]()
        self.sub = 0
        self.kids = List[Int]()


struct BsonValue(Movable):
    var nodes: List[Node]
    var root: Int

    def __init__(out self):
        self.nodes = List[Node]()
        self.root = 0

    def add(mut self) -> Int:
        var i = len(self.nodes)
        self.nodes.append(Node())
        return i

    def new_document(mut self) -> Int:
        var i = self.add()
        self.nodes[i].kind = BK_DOC
        self.root = i
        return i

    def _child(mut self, parent: Int, kind: Int, key: String) -> Int:
        var i = self.add()
        self.nodes[i].kind = kind
        self.nodes[i].key = key
        self.nodes[parent].kids.append(i)
        return i

    def put_f64(mut self, parent: Int, key: String, v: Float64):
        var i = self._child(parent, BK_DOUBLE, key)
        self.nodes[i].f64 = v

    def put_bool(mut self, parent: Int, key: String, v: Bool):
        var i = self._child(parent, BK_BOOL, key)
        if v:
            self.nodes[i].i64 = 1
        else:
            self.nodes[i].i64 = 0

    def put_i32(mut self, parent: Int, key: String, v: Int32):
        var i = self._child(parent, BK_INT32, key)
        self.nodes[i].i64 = Int64(v)

    def put_i64(mut self, parent: Int, key: String, v: Int64):
        var i = self._child(parent, BK_INT64, key)
        self.nodes[i].i64 = v

    def put_string(mut self, parent: Int, key: String, v: String):
        var i = self._child(parent, BK_STRING, key)
        self.nodes[i].s0 = v

    def put_null(mut self, parent: Int, key: String):
        _ = self._child(parent, BK_NULL, key)

    def put_doc(mut self, parent: Int, key: String) -> Int:
        return self._child(parent, BK_DOC, key)

    def put_array(mut self, parent: Int, key: String) -> Int:
        return self._child(parent, BK_ARRAY, key)


def _key_len(key: String) -> Int:
    return 1 + key.byte_length() + 1


def _value_len(doc: BsonValue, idx: Int) -> Int:
    var k = doc.nodes[idx].kind
    if k == BK_DOUBLE or k == BK_DATETIME or k == BK_INT64:
        return 8
    if k == BK_INT32 or k == BK_BOOL:
        return 4 if k == BK_INT32 else 1
    if k == BK_NULL or k == BK_UNDEFINED or k == BK_MINKEY or k == BK_MAXKEY:
        return 0
    if k == BK_OID:
        return 12
    if k == BK_DECIMAL:
        return 16
    if k == BK_TIMESTAMP:
        return 8
    if k == BK_STRING or k == BK_CODE or k == BK_SYMBOL:
        return 4 + doc.nodes[idx].s0.byte_length() + 1
    if k == BK_REGEX:
        return doc.nodes[idx].s0.byte_length() + 1 + doc.nodes[idx].s1.byte_length() + 1
    if k == BK_BINARY:
        return 4 + 1 + len(doc.nodes[idx].raw)
    if k == BK_DBPOINTER:
        return 4 + doc.nodes[idx].s0.byte_length() + 1 + 12
    if k == BK_DOC or k == BK_ARRAY:
        return _container_len(doc, idx)
    if k == BK_CODEWS:
        var scope = 5
        if len(doc.nodes[idx].kids) > 0:
            scope = _container_len(doc, doc.nodes[idx].kids[0])
        return 4 + (4 + doc.nodes[idx].s0.byte_length() + 1) + scope
    return 0


def _container_len(doc: BsonValue, idx: Int) -> Int:
    var n = 5
    var kids = len(doc.nodes[idx].kids)
    var i = 0
    while i < kids:
        var c = doc.nodes[idx].kids[i]
        var key = doc.nodes[c].key
        if doc.nodes[idx].kind == BK_ARRAY:
            n += 1 + digit_count(i) + 1
        else:
            n += _key_len(key)
        n += _value_len(doc, c)
        i += 1
    return n


def encoded_document_len(doc: BsonValue) -> Int:
    return _container_len(doc, doc.root)


def _write_node(doc: BsonValue, idx: Int, mut w: WireWriter):
    var k = doc.nodes[idx].kind
    if k == BK_DOUBLE:
        w.write_f64(doc.nodes[idx].f64)
    elif k == BK_STRING:
        w.write_bson_string(doc.nodes[idx].s0)
    elif k == BK_BOOL:
        if doc.nodes[idx].i64 != Int64(0):
            w.write_byte(Byte(1))
        else:
            w.write_byte(Byte(0))
    elif k == BK_INT32:
        w.write_i32(Int32(doc.nodes[idx].i64))
    elif k == BK_INT64 or k == BK_DATETIME:
        w.write_i64(doc.nodes[idx].i64)
    elif k == BK_TIMESTAMP:
        var inc = Int32(doc.nodes[idx].i64 & Int64(0xFFFFFFFF))
        var t = Int32(doc.nodes[idx].i64 >> Int64(32))
        w.write_i32(inc)
        w.write_i32(t)
    elif k == BK_NULL or k == BK_UNDEFINED or k == BK_MINKEY or k == BK_MAXKEY:
        return
    elif k == BK_OID or k == BK_DECIMAL:
        w.write_list(doc.nodes[idx].raw)
    elif k == BK_BINARY:
        w.write_i32(Int32(len(doc.nodes[idx].raw)))
        w.write_byte(Byte(doc.nodes[idx].sub))
        w.write_list(doc.nodes[idx].raw)
    elif k == BK_REGEX:
        w.write_cstring(doc.nodes[idx].s0)
        w.write_cstring(doc.nodes[idx].s1)
    elif k == BK_CODE or k == BK_SYMBOL:
        w.write_bson_string(doc.nodes[idx].s0)
    elif k == BK_DBPOINTER:
        w.write_bson_string(doc.nodes[idx].s0)
        w.write_list(doc.nodes[idx].raw)
    elif k == BK_DOC or k == BK_ARRAY:
        _write_container(doc, idx, w)
    elif k == BK_CODEWS:
        # The int32 covers the string and the scope document. The scope
        # already ends in 0x00, so this frame does not add a second terminator.
        var at = w.pos
        w.write_i32(Int32(0))
        w.write_bson_string(doc.nodes[idx].s0)
        if len(doc.nodes[idx].kids) > 0:
            _write_container(doc, doc.nodes[idx].kids[0], w)
        else:
            var empty = w.begin_document()
            w.end_document(empty)
        w.patch_i32(at, Int32(w.pos - at))


def _write_container(doc: BsonValue, idx: Int, mut w: WireWriter):
    var at = w.begin_document()
    var kids = len(doc.nodes[idx].kids)
    var i = 0
    while i < kids:
        var c = doc.nodes[idx].kids[i]
        var kind = doc.nodes[c].kind
        var typ = _type_of(kind)
        if doc.nodes[idx].kind == BK_ARRAY:
            w.write_type_index(typ, i)
        else:
            w.write_type_key(typ, doc.nodes[c].key)
        _write_node(doc, c, w)
        i += 1
    w.end_document(at)


def _type_of(kind: Int) -> Int:
    if kind == BK_DOUBLE:
        return TY_DOUBLE
    if kind == BK_STRING:
        return TY_STRING
    if kind == BK_DOC:
        return TY_DOCUMENT
    if kind == BK_ARRAY:
        return TY_ARRAY
    if kind == BK_BINARY:
        return TY_BINARY
    if kind == BK_UNDEFINED:
        return TY_UNDEFINED
    if kind == BK_OID:
        return TY_OBJECTID
    if kind == BK_BOOL:
        return TY_BOOL
    if kind == BK_DATETIME:
        return TY_DATETIME
    if kind == BK_NULL:
        return TY_NULL
    if kind == BK_REGEX:
        return TY_REGEX
    if kind == BK_DBPOINTER:
        return TY_DBPOINTER
    if kind == BK_CODE:
        return TY_CODE
    if kind == BK_SYMBOL:
        return TY_SYMBOL
    if kind == BK_CODEWS:
        return TY_CODEWS
    if kind == BK_INT32:
        return TY_INT32
    if kind == BK_TIMESTAMP:
        return TY_TIMESTAMP
    if kind == BK_INT64:
        return TY_INT64
    if kind == BK_DECIMAL:
        return TY_DECIMAL128
    if kind == BK_MINKEY:
        return TY_MINKEY
    return TY_MAXKEY


def encode_document(doc: BsonValue) -> List[Byte]:
    var n = encoded_document_len(doc)
    var w = WireWriter(capacity=n)
    _write_container(doc, doc.root, w)
    return w^.finish()


def _read_into[origin: ImmOrigin](mut doc: BsonValue, mut r: WireReader[origin], typ: Int, key: String, depth: Int) raises DecodeError -> Int:
    if depth > MAX_DEPTH:
        raise DecodeError(DecodeError.KIND_DEPTH, r.pos, depth)
    var i = doc.add()
    doc.nodes[i].key = key
    if typ == TY_DOUBLE:
        doc.nodes[i].kind = BK_DOUBLE
        doc.nodes[i].f64 = r.read_f64()
    elif typ == TY_STRING:
        doc.nodes[i].kind = BK_STRING
        doc.nodes[i].s0 = r.read_bson_string()
    elif typ == TY_DOCUMENT or typ == TY_ARRAY:
        if typ == TY_DOCUMENT:
            doc.nodes[i].kind = BK_DOC
        else:
            doc.nodes[i].kind = BK_ARRAY
        var end = r.enter_document()
        var kids = List[Int]()
        var ordinal = 0
        while r.pos < end - 1:
            var ct = r.read_u8()
            var ck = r.read_cstring()
            if typ == TY_ARRAY:
                ck = String(ordinal)
            var child = _read_into(doc, r, ct, ck, depth + 1)
            kids.append(child)
            ordinal += 1
        r.finish_document(end)
        var k = 0
        while k < len(kids):
            doc.nodes[i].kids.append(kids[k])
            k += 1
    elif typ == TY_BINARY:
        doc.nodes[i].kind = BK_BINARY
        var n = Int(r.read_i32())
        doc.nodes[i].sub = r.read_u8()
        doc.nodes[i].raw = r.read_raw(n)
    elif typ == TY_UNDEFINED:
        doc.nodes[i].kind = BK_UNDEFINED
    elif typ == TY_OBJECTID:
        doc.nodes[i].kind = BK_OID
        doc.nodes[i].raw = r.read_raw(12)
    elif typ == TY_BOOL:
        doc.nodes[i].kind = BK_BOOL
        var b = r.read_u8()
        if b != 0 and b != 1:
            raise DecodeError(DecodeError.KIND_TYPE, r.pos, b)
        doc.nodes[i].i64 = Int64(b)
    elif typ == TY_DATETIME:
        doc.nodes[i].kind = BK_DATETIME
        doc.nodes[i].i64 = r.read_i64()
    elif typ == TY_NULL:
        doc.nodes[i].kind = BK_NULL
    elif typ == TY_REGEX:
        doc.nodes[i].kind = BK_REGEX
        doc.nodes[i].s0 = r.read_cstring()
        doc.nodes[i].s1 = r.read_cstring()
    elif typ == TY_DBPOINTER:
        doc.nodes[i].kind = BK_DBPOINTER
        doc.nodes[i].s0 = r.read_bson_string()
        doc.nodes[i].raw = r.read_raw(12)
    elif typ == TY_CODE:
        doc.nodes[i].kind = BK_CODE
        doc.nodes[i].s0 = r.read_bson_string()
    elif typ == TY_SYMBOL:
        doc.nodes[i].kind = BK_SYMBOL
        doc.nodes[i].s0 = r.read_bson_string()
    elif typ == TY_CODEWS:
        doc.nodes[i].kind = BK_CODEWS
        var end = r.enter_document()
        doc.nodes[i].s0 = r.read_bson_string()
        var scope = _read_into(doc, r, TY_DOCUMENT, "", depth + 1)
        doc.nodes[i].kids.append(scope)
        if r.pos != end:
            raise DecodeError(DecodeError.KIND_SIZE, r.pos, end)
    elif typ == TY_INT32:
        doc.nodes[i].kind = BK_INT32
        doc.nodes[i].i64 = Int64(r.read_i32())
    elif typ == TY_TIMESTAMP:
        doc.nodes[i].kind = BK_TIMESTAMP
        var inc = Int(r.read_i32())
        var t = Int(r.read_i32())
        if inc < 0:
            inc += 0x100000000
        if t < 0:
            t += 0x100000000
        doc.nodes[i].i64 = (Int64(t) << Int64(32)) | Int64(inc)
    elif typ == TY_INT64:
        doc.nodes[i].kind = BK_INT64
        doc.nodes[i].i64 = r.read_i64()
    elif typ == TY_DECIMAL128:
        doc.nodes[i].kind = BK_DECIMAL
        doc.nodes[i].raw = r.read_raw(16)
        _ = decimal_from_list(doc.nodes[i].raw)
    elif typ == TY_MINKEY:
        doc.nodes[i].kind = BK_MINKEY
    elif typ == TY_MAXKEY:
        doc.nodes[i].kind = BK_MAXKEY
    else:
        raise DecodeError(DecodeError.KIND_TYPE, r.pos, typ)
    return i


def decode_document[origin: ImmOrigin](buf: Span[Byte, origin]) raises DecodeError -> BsonValue:
    var doc = BsonValue()
    var r = WireReader[origin](buf)
    var root = _read_into(doc, r, TY_DOCUMENT, "", 0)
    doc.root = root
    if r.remaining() != 0:
        raise DecodeError(DecodeError.KIND_TRAILING, r.pos, r.remaining())
    return doc^
