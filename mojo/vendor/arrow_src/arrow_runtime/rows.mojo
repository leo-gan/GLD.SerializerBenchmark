from std.collections import List, Span

from arrow_runtime.error import DecodeError
from arrow_runtime.model import (
    TY_BINARY,
    TY_BOOL,
    TY_INT,
    TY_LARGE_BINARY,
    TY_LARGE_LIST,
    TY_LARGE_UTF8,
    TY_LIST,
    TY_MAP,
    TY_NULL,
    TY_STRUCT,
    TY_UTF8,
    ArrayRec,
    Columnar,
    FieldRec,
    bit_get,
    byte_width_of,
    put_width,
    read_width,
)


struct RowNode(Copyable, ImplicitlyCopyable):
    var kind: Int
    var is_null: Int
    var a: Int
    var b: Int
    var child: Int
    var nchild: Int

    def __init__(out self):
        self.kind = TY_NULL
        self.is_null = 0
        self.a = 0
        self.b = 0
        self.child = 0
        self.nchild = 0


struct RowDoc:
    var nodes: List[RowNode]
    var edges: List[Int]
    var texts: List[String]
    var blobs: List[Byte]
    var blob_off: List[Int]
    var blob_len: List[Int]
    var rows: List[Int]

    def __init__(out self):
        self.nodes = List[RowNode]()
        self.edges = List[Int]()
        self.texts = List[String]()
        self.blobs = List[Byte]()
        self.blob_off = List[Int]()
        self.blob_len = List[Int]()
        self.rows = List[Int]()

    def add_text(mut self, text: String) -> Int:
        self.texts.append(text)
        return len(self.texts) - 1

    def add_blob(mut self, raw: List[Byte]) -> Int:
        var id = len(self.blob_off)
        self.blob_off.append(len(self.blobs))
        self.blob_len.append(len(raw))
        var i = 0
        while i < len(raw):
            self.blobs.append(raw[i])
            i += 1
        return id

    def push(mut self, n: RowNode) -> Int:
        self.nodes.append(n)
        return len(self.nodes) - 1


def rows_from_batch(c: Columnar, batch: Int) raises DecodeError -> RowDoc:
    var doc = RowDoc()
    var b = c.batches[batch]
    var row = 0
    while row < b.length:
        var top = RowNode()
        top.kind = TY_STRUCT
        var ids = List[Int]()
        var col = 0
        while col < b.ncol:
            var aid = c.batch_cols[b.col0 + col]
            ids.append(_value(c, doc, aid, row, 0))
            col += 1
        top.child = len(doc.edges)
        var k = 0
        while k < len(ids):
            doc.edges.append(ids[k])
            k += 1
        top.nchild = len(ids)
        doc.rows.append(doc.push(top))
        row += 1
    return doc^


def _value(c: Columnar, mut doc: RowDoc, aid: Int, row: Int, depth: Int) raises DecodeError -> Int:
    if depth > 64:
        raise DecodeError(DecodeError.KIND_DEPTH, row)
    var a = c.arrays[aid]
    var f = c.fields[a.field]
    var n = RowNode()
    n.kind = f.kind
    if _null(c, a, row):
        n.is_null = 1
        return doc.push(n)
    if f.dict_id >= 0 and a.dict >= 0:
        var idx = _fixed(c, a, 1, row, f.dict_index_width, f.dict_index_signed != 0)
        return _value(c, doc, a.dict, idx, depth + 1)
    if f.kind == TY_BOOL:
        var bits = c.buf_copy(c.abufs[a.buf0 + 1])
        n.a = 0
        if bit_get(bits, row):
            n.a = 1
        return doc.push(n)
    var width = byte_width_of(f)
    if width > 0 and width <= 8 and f.kind != TY_BOOL:
        var signed = True
        if f.kind == TY_INT:
            signed = f.is_signed != 0
        n.a = _fixed(c, a, 1, row, width, signed)
        return doc.push(n)
    if f.kind == TY_UTF8 or f.kind == TY_LARGE_UTF8 or f.kind == TY_BINARY or f.kind == TY_LARGE_BINARY:
        var wide = 4
        if f.kind == TY_LARGE_UTF8 or f.kind == TY_LARGE_BINARY:
            wide = 8
        var off = c.buf_copy(c.abufs[a.buf0 + 1])
        var data = c.buf_copy(c.abufs[a.buf0 + 2])
        var s0 = read_width(off, row * wide, wide, True)
        var s1 = read_width(off, (row + 1) * wide, wide, True)
        var slice = List[Byte]()
        var i = s0
        while i < s1:
            slice.append(data[i])
            i += 1
        if f.kind == TY_UTF8 or f.kind == TY_LARGE_UTF8:
            n.a = doc.add_text(String(unsafe_from_utf8=Span(slice)))
        else:
            n.a = doc.add_blob(slice)
        return doc.push(n)
    if f.kind == TY_LIST or f.kind == TY_LARGE_LIST or f.kind == TY_MAP:
        var wide = 4
        if f.kind == TY_LARGE_LIST:
            wide = 8
        var off = c.buf_copy(c.abufs[a.buf0 + 1])
        var s0 = read_width(off, row * wide, wide, True)
        var s1 = read_width(off, (row + 1) * wide, wide, True)
        var child_a = c.achilds[a.child0]
        var ids = List[Int]()
        var i = s0
        while i < s1:
            ids.append(_value(c, doc, child_a, i, depth + 1))
            i += 1
        n.child = len(doc.edges)
        i = 0
        while i < len(ids):
            doc.edges.append(ids[i])
            i += 1
        n.nchild = len(ids)
        return doc.push(n)
    if f.kind == TY_STRUCT:
        var ids = List[Int]()
        var ch = 0
        while ch < a.nchild:
            ids.append(_value(c, doc, c.achilds[a.child0 + ch], row, depth + 1))
            ch += 1
        n.child = len(doc.edges)
        ch = 0
        while ch < len(ids):
            doc.edges.append(ids[ch])
            ch += 1
        n.nchild = len(ids)
        return doc.push(n)
    if f.kind == TY_NULL:
        n.is_null = 1
        return doc.push(n)
    raise DecodeError(DecodeError.KIND_TYPE, f.kind)


def _null(c: Columnar, a: ArrayRec, row: Int) -> Bool:
    if a.null_count == 0 or a.nbuf == 0:
        return False
    var bm = c.buf_copy(c.abufs[a.buf0])
    if len(bm) == 0:
        return False
    return not bit_get(bm, row)


def _fixed(c: Columnar, a: ArrayRec, slot: Int, row: Int, width: Int, signed: Bool) raises DecodeError -> Int:
    var raw = c.buf_copy(c.abufs[a.buf0 + slot])
    return read_width(raw, row * width, width, signed)


def text_at(doc: RowDoc, node: Int) -> String:
    return doc.texts[doc.nodes[node].a]


def child_at(doc: RowDoc, node: Int, i: Int) -> Int:
    var n = doc.nodes[node]
    return doc.edges[n.child + i]
