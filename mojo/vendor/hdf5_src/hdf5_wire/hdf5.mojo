from std.collections import List, Span

from hdf5_runtime.bytes import Buf, blank, blit, copy_span, pad_to, u16le, u32le, u64le
from hdf5_runtime.deflate import zlib_inflate, zlib_store
from hdf5_runtime.doc import (
    DT_F32,
    DT_F64,
    DT_I16,
    DT_I32,
    DT_I64,
    DT_I8,
    DT_STR,
    DT_U16,
    DT_U32,
    DT_U64,
    DT_U8,
    H5Doc,
    elem_size,
)
from hdf5_runtime.error import FormatError


comptime UNDEF = -1
comptime GROUP_BTREE_K = 16
comptime CHUNK_BTREE_K = 32
comptime SNOD_SLOTS = 8
comptime SNOD_BYTES = 8 + 8 * 40
comptime GZIP_LEVEL = 1


def align8(n: Int) -> Int:
    if n % 8 == 0:
        return n
    return n + (8 - (n % 8))


def logical_nbytes(rank: Int, n0: Int, n1: Int, es: Int) -> Int:
    if rank <= 0:
        return es
    if rank == 1:
        return n0 * es
    return n0 * n1 * es


def cmp_name(a: String, b: String) -> Int:
    var ab = a.as_bytes()
    var bb = b.as_bytes()
    var n = len(ab)
    if len(bb) < n:
        n = len(bb)
    var i = 0
    while i < n:
        var ca = Int(ab[i])
        var cb = Int(bb[i])
        if ca < cb:
            return -1
        if ca > cb:
            return 1
        i += 1
    if len(ab) < len(bb):
        return -1
    if len(ab) > len(bb):
        return 1
    return 0


def sort_names(mut names: List[String]):
    var i = 1
    while i < len(names):
        var j = i
        while j > 0:
            if cmp_name(names[j - 1], names[j]) <= 0:
                break
            var tmp = names[j - 1]
            names[j - 1] = names[j]
            names[j] = tmp
            j -= 1
        i += 1


struct Oh:
    var buf: Buf
    var nmsgs: Int

    def __init__(out self):
        self.buf = Buf()
        self.buf.zeros(16)
        self.nmsgs = 0

    def add(mut self, typ: Int, flags: Int, data: List[Byte]):
        self.buf.pad8()
        self.buf.u16(typ)
        self.buf.u16(len(data))
        self.buf.u8(flags)
        self.buf.zeros(3)
        self.buf.blob(data)
        self.nmsgs += 1

    def finish(mut self) -> List[Byte]:
        var size = self.buf.n() - 16
        self.buf.b[0] = Byte(1)
        self.buf.b[1] = Byte(0)
        self.buf.b[2] = Byte(self.nmsgs & 255)
        self.buf.b[3] = Byte((self.nmsgs >> 8) & 255)
        self.buf.b[4] = Byte(1)
        self.buf.b[5] = Byte(0)
        self.buf.b[6] = Byte(0)
        self.buf.b[7] = Byte(0)
        var s = size
        var i = 0
        while i < 4:
            self.buf.b[8 + i] = Byte(s & 255)
            s = s >> 8
            i += 1
        var out = List[Byte]()
        i = 0
        while i < self.buf.n():
            out.append(self.buf.b[i])
            i += 1
        return out^


def dtype_core(dt: Int) -> List[Byte]:
    var buf = Buf()
    if dt == DT_F64:
        buf.u8(0x11)
        buf.u8(0x20)
        buf.u8(0x3F)
        buf.u8(0x00)
        buf.u32(8)
        buf.u16(0)
        buf.u16(64)
        buf.u8(52)
        buf.u8(11)
        buf.u8(0)
        buf.u8(52)
        buf.u32(0x03FF)
        buf.u32(0)
        return buf.take()
    if dt == DT_F32:
        buf.u8(0x11)
        buf.u8(0x20)
        buf.u8(0x1F)
        buf.u8(0x00)
        buf.u32(4)
        buf.u16(0)
        buf.u16(32)
        buf.u8(23)
        buf.u8(8)
        buf.u8(0)
        buf.u8(23)
        buf.u32(0x007F)
        buf.u32(0)
        return buf.take()
    var es = elem_size(dt)
    var signed = dt >= DT_I8 and dt <= DT_I64
    buf.u8(0x10)
    if signed:
        buf.u8(0x08)
    else:
        buf.u8(0x00)
    buf.u8(0)
    buf.u8(0)
    buf.u32(es)
    buf.u16(0)
    buf.u16(es * 8)
    return buf.take()


def dtype_padded(dt: Int) -> List[Byte]:
    var buf = Buf()
    buf.blob(dtype_core(dt))
    buf.pad8()
    return buf.take()


def string_dtype(n: Int) -> List[Byte]:
    var buf = Buf()
    buf.u8(0x13)
    buf.u8(0x10)
    buf.u16(0)
    buf.u32(n)
    return buf.take()


def dataspace(rank: Int, n0: Int, n1: Int) -> List[Byte]:
    var buf = Buf()
    if rank <= 0:
        buf.u8(1)
        buf.zeros(7)
        return buf.take()
    buf.u8(1)
    buf.u8(rank)
    buf.u8(1)
    buf.zeros(5)
    buf.u64(n0)
    if rank > 1:
        buf.u64(n1)
    buf.u64(n0)
    if rank > 1:
        buf.u64(n1)
    return buf.take()


def fill_body(chunked: Int) -> List[Byte]:
    var buf = Buf()
    buf.u8(2)
    if chunked != 0:
        buf.u8(3)
    else:
        buf.u8(2)
    buf.u8(2)
    buf.u8(1)
    buf.u32(0)
    return buf.take()


def layout_contig(addr: Int, nbytes: Int) -> List[Byte]:
    var buf = Buf()
    buf.u8(3)
    buf.u8(1)
    buf.u64(addr)
    buf.u64(nbytes)
    buf.zeros(6)
    return buf.take()


def layout_chunked(addr: Int, rank: Int, c0: Int, c1: Int, es: Int) -> List[Byte]:
    var buf = Buf()
    buf.u8(3)
    buf.u8(2)
    buf.u8(rank + 1)
    buf.u64(addr)
    buf.u32(c0)
    if rank > 1:
        buf.u32(c1)
    buf.u32(es)
    buf.pad8()
    return buf.take()


def filter_deflate() -> List[Byte]:
    var buf = Buf()
    buf.u8(1)
    buf.u8(1)
    buf.zeros(6)
    buf.u16(1)
    buf.u16(8)
    buf.u16(1)
    buf.u16(1)
    buf.ascii(String("deflate"))
    buf.u8(0)
    buf.u32(GZIP_LEVEL)
    buf.u32(0)
    return buf.take()


def attr_body(name: String, dt: List[Byte], space: List[Byte], data: List[Byte]) -> List[Byte]:
    var buf = Buf()
    var nb = name.as_bytes()
    buf.u8(1)
    buf.u8(0)
    buf.u16(len(nb) + 1)
    buf.u16(len(dt))
    buf.u16(len(space))
    var i = 0
    while i < len(nb):
        buf.u8(Int(nb[i]))
        i += 1
    buf.u8(0)
    buf.pad8()
    buf.blob(dt)
    buf.pad8()
    buf.blob(space)
    buf.pad8()
    buf.blob(data)
    buf.pad8()
    return buf.take()


def add_owner_attrs(mut oh: Oh, doc: H5Doc, kind: Int, owner: Int) raises:
    var i = 0
    while i < len(doc.a_name):
        if doc.a_kind[i] == kind and doc.a_owner[i] == owner:
            var body: List[Byte]
            if doc.a_dtype[i] == DT_STR:
                body = attr_body(
                    doc.a_name[i],
                    string_dtype(len(doc.a_raw[i])),
                    dataspace(0, 0, 0),
                    doc.a_raw[i],
                )
            else:
                var es = elem_size(doc.a_dtype[i])
                if es == 0 or len(doc.a_raw[i]) != es:
                    raise FormatError(0, String("numeric attribute width does not match its type"))
                body = attr_body(doc.a_name[i], dtype_core(doc.a_dtype[i]), dataspace(0, 0, 0), doc.a_raw[i])
            oh.add(0x000C, 0, body^)
        i += 1


def chunk_btree_bytes(rank: Int) -> Int:
    var key_size = 8 + 8 * (rank + 1)
    var nslots = CHUNK_BTREE_K * 2
    return 24 + (nslots + 1) * key_size + nslots * 8


def group_btree_bytes() -> Int:
    var nslots = GROUP_BTREE_K * 2
    return 24 + (nslots + 1) * 8 + nslots * 8


def name_off(names: List[String], index: Int) -> Int:
    var pos = 8
    var i = 0
    while i < index:
        var n = names[i].byte_length() + 1
        pos += n
        pos = align8(pos)
        i += 1
    return pos


def build_heap_data(names: List[String]) -> List[Byte]:
    var buf = Buf()
    buf.zeros(8)
    var i = 0
    while i < len(names):
        buf.ascii(names[i])
        buf.u8(0)
        buf.pad8()
        i += 1
    buf.u64(1)
    buf.u64(16)
    return buf.take()


def heap_header(data_size: Int, free_off: Int, data_addr: Int) -> List[Byte]:
    var buf = Buf()
    buf.ascii(String("HEAP"))
    buf.zeros(4)
    buf.u64(data_size)
    buf.u64(free_off)
    buf.u64(data_addr)
    return buf.take()


def build_snod(names: List[String], begin: Int, count: Int, oh_of: List[Int]) -> List[Byte]:
    var buf = Buf(SNOD_BYTES)
    buf.ascii(String("SNOD"))
    buf.u8(1)
    buf.u8(0)
    buf.u16(count)
    var i = 0
    while i < count:
        var nm = names[begin + i]
        buf.u64(name_off(names, begin + i))
        buf.u64(oh_of[begin + i])
        buf.u32(0)
        buf.u32(0)
        buf.zeros(16)
        _ = nm
        i += 1
    return pad_to(buf.take(), SNOD_BYTES)


def build_group_btree(names: List[String], snod_addrs: List[Int]) -> List[Byte]:
    var buf = Buf(group_btree_bytes())
    buf.ascii(String("TREE"))
    buf.u8(0)
    buf.u8(0)
    buf.u16(len(snod_addrs))
    buf.u64(UNDEF)
    buf.u64(UNDEF)
    buf.u64(0)
    var i = 0
    while i < len(snod_addrs):
        var last = (i + 1) * SNOD_SLOTS - 1
        if last >= len(names):
            last = len(names) - 1
        buf.u64(snod_addrs[i])
        if len(names) == 0:
            buf.u64(0)
        else:
            buf.u64(name_off(names, last))
        i += 1
    return pad_to(buf.take(), group_btree_bytes())


def build_chunk_btree(rank: Int, es: Int, off0: List[Int], off1: List[Int], sizes: List[Int], addrs: List[Int]) -> List[Byte]:
    var buf = Buf(chunk_btree_bytes(rank))
    buf.ascii(String("TREE"))
    buf.u8(1)
    buf.u8(0)
    buf.u16(len(addrs))
    buf.u64(UNDEF)
    buf.u64(UNDEF)
    var i = 0
    while i < len(addrs):
        buf.u32(sizes[i])
        buf.u32(0)
        buf.u64(off0[i])
        if rank > 1:
            buf.u64(off1[i])
        buf.u64(0)
        buf.u64(addrs[i])
        i += 1
    if len(addrs) == 0:
        buf.u32(0)
        buf.u32(0)
        buf.u64(0)
        if rank > 1:
            buf.u64(0)
        buf.u64(0)
    else:
        var last = len(addrs) - 1
        buf.u32(0)
        buf.u32(0)
        buf.u64(off0[last])
        if rank > 1:
            buf.u64(off1[last])
        buf.u64(es)
    return pad_to(buf.take(), chunk_btree_bytes(rank))


def full_chunk(data: List[Byte], rank: Int, n0: Int, n1: Int, es: Int, off0: Int, off1: Int, c0: Int, c1: Int) -> List[Byte]:
    var nbytes = c0 * es
    if rank > 1:
        nbytes = c0 * c1 * es
    var raw = List[Byte]()
    var i = 0
    while i < nbytes:
        raw.append(Byte(0))
        i += 1
    if rank <= 1:
        var j = 0
        while j < c0 and off0 + j < n0:
            var s = (off0 + j) * es
            var d = j * es
            var b = 0
            while b < es:
                raw[d + b] = data[s + b]
                b += 1
            j += 1
    else:
        var r = 0
        while r < c0 and off0 + r < n0:
            var c = 0
            while c < c1 and off1 + c < n1:
                var s = ((off0 + r) * n1 + (off1 + c)) * es
                var d = (r * c1 + c) * es
                var b = 0
                while b < es:
                    raw[d + b] = data[s + b]
                    b += 1
                c += 1
            r += 1
    return raw^


def store_chunk(raw: List[Byte], gzip: Int) -> List[Byte]:
    if gzip != 0:
        return zlib_store(Span(raw))
    var out = List[Byte]()
    var i = 0
    while i < len(raw):
        out.append(raw[i])
        i += 1
    return out^


struct Cursor:
    var n: Int

    def __init__(out self, n: Int):
        self.n = n

    def alloc(mut self, size: Int, align: Int) -> Int:
        if align > 1 and self.n % align != 0:
            self.n += align - (self.n % align)
        var addr = self.n
        self.n += size
        return addr


def child_names(doc: H5Doc, parent: Int) raises -> List[String]:
    var names = List[String]()
    var i = 0
    while i < len(doc.g_name):
        if doc.g_parent[i] == parent:
            if doc.g_name[i].byte_length() == 0:
                raise FormatError(0, String("a group link name is empty"))
            names.append(doc.g_name[i])
        i += 1
    i = 0
    while i < len(doc.d_name):
        if doc.d_parent[i] == parent:
            if doc.d_name[i].byte_length() == 0:
                raise FormatError(0, String("a dataset link name is empty"))
            names.append(doc.d_name[i])
        i += 1
    sort_names(names)
    i = 1
    while i < len(names):
        if names[i] == names[i - 1]:
            raise FormatError(0, String("duplicate link name"))
        i += 1
    if len(names) > GROUP_BTREE_K * 2 * SNOD_SLOTS:
        raise FormatError(0, String("too many links in one group"))
    return names^


def find_group(doc: H5Doc, parent: Int, name: String) -> Int:
    var i = 0
    while i < len(doc.g_name):
        if doc.g_parent[i] == parent and doc.g_name[i] == name:
            return i
        i += 1
    return -1


def find_dataset(doc: H5Doc, parent: Int, name: String) -> Int:
    var i = 0
    while i < len(doc.d_name):
        if doc.d_parent[i] == parent and doc.d_name[i] == name:
            return i
        i += 1
    return -1


def dataset_oh(doc: H5Doc, di: Int, layout_addr: Int, data_addr: Int) raises -> List[Byte]:
    var rank = doc.d_rank[di]
    var es = elem_size(doc.d_dtype[di])
    var oh = Oh()
    oh.add(0x0001, 0, dataspace(rank, doc.d_n0[di], doc.d_n1[di]))
    oh.add(0x0003, 1, dtype_padded(doc.d_dtype[di]))
    oh.add(0x0005, 1, fill_body(doc.d_chunked[di]))
    if doc.d_gzip[di] != 0:
        oh.add(0x000B, 1, filter_deflate())
    if doc.d_chunked[di] != 0:
        oh.add(0x0008, 0, layout_chunked(layout_addr, rank, doc.d_c0[di], doc.d_c1[di], es))
    else:
        var nbytes = logical_nbytes(rank, doc.d_n0[di], doc.d_n1[di], es)
        oh.add(0x0008, 0, layout_contig(data_addr, nbytes))
    add_owner_attrs(oh, doc, 1, di)
    return oh.finish()


def group_oh(doc: H5Doc, gi: Int, btree: Int, heap: Int) raises -> List[Byte]:
    var oh = Oh()
    var sym = Buf()
    sym.u64(btree)
    sym.u64(heap)
    oh.add(0x0011, 0, sym.take())
    add_owner_attrs(oh, doc, 0, gi)
    return oh.finish()


def check_dataset(doc: H5Doc, di: Int) raises:
    var es = elem_size(doc.d_dtype[di])
    if es == 0:
        raise FormatError(0, String("dataset type is not numeric"))
    var rank = doc.d_rank[di]
    if rank < 0 or rank > 2:
        raise FormatError(0, String("only scalar, 1-D, and 2-D datasets are supported"))
    if rank > 0 and doc.d_n0[di] < 0:
        raise FormatError(0, String("negative dimension"))
    if rank > 1 and doc.d_n1[di] < 0:
        raise FormatError(0, String("negative dimension"))
    var expect = logical_nbytes(rank, doc.d_n0[di], doc.d_n1[di], es)
    if len(doc.d_data[di]) != expect:
        raise FormatError(0, String("dataset byte length does not match its shape"))
    if doc.d_chunked[di] != 0:
        if rank == 0 or doc.d_c0[di] <= 0:
            raise FormatError(0, String("chunked layout needs a positive chunk length"))
        if rank > 1 and doc.d_c1[di] <= 0:
            raise FormatError(0, String("2-D chunks need two positive sizes"))
        if doc.d_gzip[di] != 0 and rank == 0:
            raise FormatError(0, String("gzip needs a chunked array"))


def write_hdf5(doc: H5Doc) raises -> List[Byte]:
    """Write an HDF5 file using superblock version 0.

    Offsets and lengths are 8 bytes. Groups use a version-1 B-tree and one or
    more symbol-table nodes. Datasets are contiguous or single-index chunked
    through a version-1 raw-data B-tree. Gzip is zlib stored-block deflate,
    filter id 1.
    """
    if len(doc.g_name) == 0 or doc.g_parent[0] != -1:
        raise FormatError(0, String("the document needs a root group"))
    var di = 0
    while di < len(doc.d_name):
        check_dataset(doc, di)
        di += 1

    var names_of = List[List[String]]()
    var gi = 0
    while gi < len(doc.g_name):
        names_of.append(child_names(doc, gi))
        gi += 1

    var ch_data = List[List[Byte]]()
    var ch_off0 = List[Int]()
    var ch_off1 = List[Int]()
    var ch_ds = List[Int]()
    var ch_at = List[Int]()
    var ch_n = List[Int]()
    di = 0
    while di < len(doc.d_name):
        ch_at.append(len(ch_data))
        var nch = 0
        if doc.d_chunked[di] != 0:
            var es = elem_size(doc.d_dtype[di])
            var rank = doc.d_rank[di]
            if rank <= 1:
                var off = 0
                while off < doc.d_n0[di] or (doc.d_n0[di] == 0 and nch == 0 and False):
                    if off >= doc.d_n0[di]:
                        break
                    var raw = full_chunk(doc.d_data[di], 1, doc.d_n0[di], 0, es, off, 0, doc.d_c0[di], 1)
                    var stored = store_chunk(raw^, doc.d_gzip[di])
                    ch_data.append(stored^)
                    ch_off0.append(off)
                    ch_off1.append(0)
                    ch_ds.append(di)
                    nch += 1
                    off += doc.d_c0[di]
            else:
                var r = 0
                while r < doc.d_n1[di] or r < doc.d_n0[di]:
                    if r >= doc.d_n0[di]:
                        break
                    var c = 0
                    while c < doc.d_n1[di]:
                        var raw = full_chunk(
                            doc.d_data[di],
                            2,
                            doc.d_n0[di],
                            doc.d_n1[di],
                            es,
                            r,
                            c,
                            doc.d_c0[di],
                            doc.d_c1[di],
                        )
                        var stored = store_chunk(raw^, doc.d_gzip[di])
                        ch_data.append(stored^)
                        ch_off0.append(r)
                        ch_off1.append(c)
                        ch_ds.append(di)
                        nch += 1
                        c += doc.d_c1[di]
                    r += doc.d_c0[di]
        ch_n.append(nch)
        di += 1

    var heap_blobs = List[List[Byte]]()
    var g_nsnod = List[Int]()
    gi = 0
    while gi < len(doc.g_name):
        var nsn = 1
        if len(names_of[gi]) > 0:
            nsn = (len(names_of[gi]) + SNOD_SLOTS - 1) // SNOD_SLOTS
        g_nsnod.append(nsn)
        heap_blobs.append(build_heap_data(names_of[gi]))
        gi += 1

    # Address order follows a sorted depth-first walk. The reader rebuilds the
    # document in that same order, so a rewrite lays the file out again.
    var order_kind = List[Int]()
    var order_idx = List[Int]()
    order_kind.append(0)
    order_idx.append(0)
    var stack_g = List[Int]()
    var stack_i = List[Int]()
    stack_g.append(0)
    stack_i.append(0)
    var top = 1
    while top > 0:
        var g = stack_g[top - 1]
        var ci2 = stack_i[top - 1]
        if ci2 >= len(names_of[g]):
            top -= 1
            continue
        stack_i[top - 1] = ci2 + 1
        var child = names_of[g][ci2]
        var cg = find_group(doc, g, child)
        if cg >= 0:
            order_kind.append(0)
            order_idx.append(cg)
            if top == len(stack_g):
                stack_g.append(cg)
                stack_i.append(0)
            else:
                stack_g[top] = cg
                stack_i[top] = 0
            top += 1
        else:
            order_kind.append(1)
            order_idx.append(find_dataset(doc, g, child))

    var cur = Cursor(96)
    var g_oh = List[Int]()
    var g_btree = List[Int]()
    var g_heap = List[Int]()
    var g_heap_data = List[Int]()
    var g_snod = List[Int]()
    gi = 0
    while gi < len(doc.g_name):
        g_oh.append(0)
        g_btree.append(0)
        g_heap.append(0)
        g_heap_data.append(0)
        g_snod.append(0)
        gi += 1
    var d_oh = List[Int]()
    var d_btree = List[Int]()
    var d_data_addr = List[Int]()
    di = 0
    while di < len(doc.d_name):
        d_oh.append(0)
        d_btree.append(0)
        d_data_addr.append(0)
        di += 1
    var ch_addr = List[Int]()
    var ci = 0
    while ci < len(ch_data):
        ch_addr.append(0)
        ci += 1

    var step = 0
    while step < len(order_kind):
        if order_kind[step] == 0:
            var gix = order_idx[step]
            var dummy = group_oh(doc, gix, 0, 0)
            g_oh[gix] = cur.alloc(len(dummy), 8)
            g_btree[gix] = cur.alloc(group_btree_bytes(), 8)
            g_heap[gix] = cur.alloc(32 + len(heap_blobs[gix]), 8)
            g_heap_data[gix] = g_heap[gix] + 32
            g_snod[gix] = cur.alloc(SNOD_BYTES * g_nsnod[gix], 8)
        else:
            var dix = order_idx[step]
            if doc.d_chunked[dix] != 0:
                var bt = cur.alloc(chunk_btree_bytes(doc.d_rank[dix]), 8)
                d_btree[dix] = bt
                var k = 0
                while k < ch_n[dix]:
                    var idx = ch_at[dix] + k
                    ch_addr[idx] = cur.alloc(len(ch_data[idx]), 1)
                    k += 1
                var ohb = dataset_oh(doc, dix, bt, 0)
                d_oh[dix] = cur.alloc(len(ohb), 8)
            else:
                var es2 = elem_size(doc.d_dtype[dix])
                var nbytes = logical_nbytes(doc.d_rank[dix], doc.d_n0[dix], doc.d_n1[dix], es2)
                var data_addr = 0
                if nbytes > 0:
                    data_addr = cur.alloc(nbytes, 8)
                d_data_addr[dix] = data_addr
                var ohc = dataset_oh(doc, dix, 0, data_addr)
                d_oh[dix] = cur.alloc(len(ohc), 8)
        step += 1

    # Object headers were sized before later objects moved the cursor, but the
    # addresses above were assigned in one pass. Dataset object-header sizes do
    # not depend on the address values, so the allocated spans match the bytes
    # written below. Rebuild in address order into a zeroed file.
    var eof = cur.n
    var out = blank(eof)

    var sb = Buf()
    sb.u8(0x89)
    sb.ascii(String("HDF"))
    sb.u8(0x0D)
    sb.u8(0x0A)
    sb.u8(0x1A)
    sb.u8(0x0A)
    sb.u8(0)
    sb.u8(0)
    sb.u8(0)
    sb.u8(0)
    sb.u8(0)
    sb.u8(8)
    sb.u8(8)
    sb.u8(0)
    sb.u16(4)
    sb.u16(16)
    sb.u32(0)
    sb.u64(0)
    sb.u64(UNDEF)
    sb.u64(eof)
    sb.u64(UNDEF)
    sb.u64(0)
    sb.u64(g_oh[0])
    sb.u32(1)
    sb.u32(0)
    sb.u64(g_btree[0])
    sb.u64(g_heap[0])
    if sb.n() != 96:
        raise FormatError(0, String("superblock is not 96 bytes"))
    blit(out, 0, sb.take())

    gi = 0
    while gi < len(doc.g_name):
        var ohb = group_oh(doc, gi, g_btree[gi], g_heap[gi])
        blit(out, g_oh[gi], ohb^)
        var snod_addrs = List[Int]()
        var s = 0
        while s < g_nsnod[gi]:
            snod_addrs.append(g_snod[gi] + s * SNOD_BYTES)
            s += 1
        var oh_of = List[Int]()
        var nm = 0
        while nm < len(names_of[gi]):
            var gch = find_group(doc, gi, names_of[gi][nm])
            if gch >= 0:
                oh_of.append(g_oh[gch])
            else:
                var dch = find_dataset(doc, gi, names_of[gi][nm])
                oh_of.append(d_oh[dch])
            nm += 1
        if len(names_of[gi]) == 0:
            blit(out, g_btree[gi], build_group_btree(names_of[gi], List[Int]()))
            blit(out, g_snod[gi], build_snod(names_of[gi], 0, 0, oh_of^))
        else:
            blit(out, g_btree[gi], build_group_btree(names_of[gi], snod_addrs^))
            s = 0
            while s < g_nsnod[gi]:
                var begin = s * SNOD_SLOTS
                var count = len(names_of[gi]) - begin
                if count > SNOD_SLOTS:
                    count = SNOD_SLOTS
                blit(out, g_snod[gi] + s * SNOD_BYTES, build_snod(names_of[gi], begin, count, oh_of))
                s += 1
        var free_off = len(heap_blobs[gi]) - 16
        var hdr = heap_header(len(heap_blobs[gi]), free_off, g_heap_data[gi])
        blit(out, g_heap[gi], hdr^)
        blit(out, g_heap_data[gi], heap_blobs[gi])
        gi += 1

    di = 0
    while di < len(doc.d_name):
        if doc.d_chunked[di] != 0:
            var o0 = List[Int]()
            var o1 = List[Int]()
            var sz = List[Int]()
            var ad = List[Int]()
            var k = 0
            while k < ch_n[di]:
                var idx = ch_at[di] + k
                o0.append(ch_off0[idx])
                o1.append(ch_off1[idx])
                sz.append(len(ch_data[idx]))
                ad.append(ch_addr[idx])
                blit(out, ch_addr[idx], ch_data[idx])
                k += 1
            var tree = build_chunk_btree(doc.d_rank[di], elem_size(doc.d_dtype[di]), o0^, o1^, sz^, ad^)
            blit(out, d_btree[di], tree^)
            var ohb = dataset_oh(doc, di, d_btree[di], 0)
            blit(out, d_oh[di], ohb^)
        else:
            if len(doc.d_data[di]) > 0:
                blit(out, d_data_addr[di], doc.d_data[di])
            var ohc = dataset_oh(doc, di, 0, d_data_addr[di])
            blit(out, d_oh[di], ohc^)
        di += 1
    return out^


struct ObjInfo:
    var is_group: Int
    var btree: Int
    var heap: Int
    var rank: Int
    var n0: Int
    var n1: Int
    var dtype: Int
    var layout: Int
    var data_addr: Int
    var data_size: Int
    var chunk_addr: Int
    var c0: Int
    var c1: Int
    var es: Int
    var gzip: Int
    var attr_name: List[String]
    var attr_dtype: List[Int]
    var attr_text: List[String]
    var attr_raw: List[List[Byte]]

    def __init__(out self):
        self.is_group = 0
        self.btree = 0
        self.heap = 0
        self.rank = 0
        self.n0 = 0
        self.n1 = 0
        self.dtype = 0
        self.layout = 0
        self.data_addr = 0
        self.data_size = 0
        self.chunk_addr = 0
        self.c0 = 0
        self.c1 = 0
        self.es = 0
        self.gzip = 0
        self.attr_name = List[String]()
        self.attr_dtype = List[Int]()
        self.attr_text = List[String]()
        self.attr_raw = List[List[Byte]]()


def text_of(raw: List[Byte]) -> String:
    var n = len(raw)
    var i = 0
    while i < len(raw):
        if Int(raw[i]) == 0:
            n = i
            break
        i += 1
    var tmp = List[Byte]()
    i = 0
    while i < n:
        tmp.append(raw[i])
        i += 1
    if len(tmp) == 0:
        return String()
    return String(unsafe_from_utf8=Span(tmp))


def parse_dtype[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int) raises -> Int:
    if n < 8:
        raise FormatError(at, String("datatype message is too short"))
    var cls = Int(raw[at]) & 0x0F
    var sz = u32le(raw, at + 4)
    if cls == 0:
        var signed = (Int(raw[at + 1]) & 0x08) != 0
        if sz == 1:
            if signed:
                return DT_I8
            return DT_U8
        if sz == 2:
            if signed:
                return DT_I16
            return DT_U16
        if sz == 4:
            if signed:
                return DT_I32
            return DT_U32
        if sz == 8:
            if signed:
                return DT_I64
            return DT_U64
    if cls == 1 and sz == 4:
        return DT_F32
    if cls == 1 and sz == 8:
        return DT_F64
    if cls == 3:
        return DT_STR
    raise FormatError(at, String("unsupported datatype"))


def parse_space[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int, mut rank: Int, mut n0: Int, mut n1: Int) raises:
    if n < 4:
        raise FormatError(at, String("dataspace message is too short"))
    var ver = Int(raw[at])
    if ver == 1:
        rank = Int(raw[at + 1])
        var flags = Int(raw[at + 2])
        var pos = at + 8
        if rank > 2:
            raise FormatError(at, String("rank above 2 is not supported"))
        if rank >= 1:
            n0 = u64le(raw, pos)
            pos += 8
        if rank >= 2:
            n1 = u64le(raw, pos)
            pos += 8
        if (flags & 1) != 0:
            pos += rank * 8
        if pos > at + n:
            raise FormatError(at, String("dataspace overruns its message"))
        return
    raise FormatError(at, String("dataspace version is not 1"))


def parse_attr[origin: ImmOrigin](raw: Span[Byte, origin], at: Int, n: Int, mut info: ObjInfo) raises:
    if n < 8 or Int(raw[at]) != 1:
        raise FormatError(at, String("only attribute message version 1 is supported"))
    var name_n = u16le(raw, at + 2)
    var dt_n = u16le(raw, at + 4)
    var sp_n = u16le(raw, at + 6)
    var pos = 8
    if pos + name_n > n:
        raise FormatError(at, String("attribute name overruns the message"))
    var name_bytes = List[Byte]()
    var i = 0
    var keep = name_n
    if keep > 0 and Int(raw[at + pos + keep - 1]) == 0:
        keep -= 1
    while i < keep:
        name_bytes.append(raw[at + pos + i])
        i += 1
    var name = String()
    if len(name_bytes) > 0:
        name = String(unsafe_from_utf8=Span(name_bytes))
    pos = align8(pos + name_n)
    if pos + dt_n > n:
        raise FormatError(at, String("attribute datatype overruns the message"))
    var dt = parse_dtype(raw, at + pos, dt_n)
    pos = align8(pos + dt_n)
    var rank = 0
    var n0 = 0
    var n1 = 0
    parse_space(raw, at + pos, sp_n, rank, n0, n1)
    pos = align8(pos + sp_n)
    var raw_n = elem_size(dt)
    if dt == DT_STR:
        var dt_at = align8(8 + name_n)
        raw_n = u32le(raw, at + dt_at + 4)
    if pos + raw_n > n:
        raise FormatError(at, String("attribute value overruns the message"))
    var val = List[Byte]()
    i = 0
    while i < raw_n:
        val.append(raw[at + pos + i])
        i += 1
    info.attr_name.append(name)
    info.attr_dtype.append(dt)
    if dt == DT_STR:
        info.attr_text.append(text_of(val))
    else:
        info.attr_text.append(String())
    info.attr_raw.append(val^)


def parse_oh[origin: ImmOrigin](raw: Span[Byte, origin], addr: Int) raises -> ObjInfo:
    if addr < 0 or addr + 16 > len(raw):
        raise FormatError(addr, String("object header is outside the file"))
    if Int(raw[addr]) != 1:
        raise FormatError(addr, String("object header version is not 1"))
    var nmsgs = u16le(raw, addr + 2)
    var oh_size = u32le(raw, addr + 8)
    var start = addr + 12
    if start % 8 != 0:
        start += 8 - (start % 8)
    var end = start + oh_size
    if end > len(raw):
        raise FormatError(addr, String("object header overruns the file"))
    var info = ObjInfo()
    var pos = start
    var seen = 0
    while seen < nmsgs and pos + 8 <= end:
        var typ = u16le(raw, pos)
        var sz = u16le(raw, pos + 2)
        var data_at = pos + 8
        if typ != 0 and data_at + sz > len(raw):
            raise FormatError(pos, String("header message overruns the file"))
        if typ == 0:
            break
        if typ == 1:
            parse_space(raw, data_at, sz, info.rank, info.n0, info.n1)
        elif typ == 3:
            info.dtype = parse_dtype(raw, data_at, sz)
            info.es = elem_size(info.dtype)
        elif typ == 8:
            if sz < 4 or Int(raw[data_at]) != 3:
                raise FormatError(data_at, String("layout message is not version 3"))
            var cls = Int(raw[data_at + 1])
            info.layout = cls
            if cls == 1:
                info.data_addr = u64le(raw, data_at + 2)
                info.data_size = u64le(raw, data_at + 10)
            elif cls == 2:
                var nd = Int(raw[data_at + 2])
                info.chunk_addr = u64le(raw, data_at + 3)
                var p = data_at + 11
                if nd >= 1:
                    info.c0 = u32le(raw, p)
                    p += 4
                if nd >= 3:
                    info.c1 = u32le(raw, p)
                    p += 4
                elif nd == 2:
                    info.c1 = 0
                if p + 4 <= data_at + sz:
                    info.es = u32le(raw, p)
            else:
                raise FormatError(data_at, String("unsupported layout class"))
        elif typ == 0x0B:
            if sz >= 2 and Int(raw[data_at + 1]) >= 1:
                info.gzip = 1
        elif typ == 0x0C:
            parse_attr(raw, data_at, sz, info)
        elif typ == 0x11:
            info.is_group = 1
            info.btree = u64le(raw, data_at)
            info.heap = u64le(raw, data_at + 8)
        seen += 1
        pos = data_at + sz
        if pos % 8 != 0:
            pos += 8 - (pos % 8)
    return info^


def cstring_at[origin: ImmOrigin](raw: Span[Byte, origin], at: Int) raises -> String:
    if at < 0 or at >= len(raw):
        raise FormatError(at, String("name is outside the file"))
    var tmp = List[Byte]()
    var i = at
    while i < len(raw) and Int(raw[i]) != 0:
        tmp.append(raw[i])
        i += 1
    if len(tmp) == 0:
        return String()
    return String(unsafe_from_utf8=Span(tmp))


def load_group_links[origin: ImmOrigin](
    raw: Span[Byte, origin],
    btree: Int,
    heap: Int,
    mut names: List[String],
    mut ohs: List[Int],
) raises:
    if heap < 0 or heap + 32 > len(raw):
        raise FormatError(heap, String("local heap is outside the file"))
    if Int(raw[heap]) != 72 or Int(raw[heap + 1]) != 69 or Int(raw[heap + 2]) != 65 or Int(raw[heap + 3]) != 80:
        raise FormatError(heap, String("local heap signature mismatch"))
    var data_size = u64le(raw, heap + 8)
    var data_addr = u64le(raw, heap + 24)
    if data_addr < 0 or data_addr + data_size > len(raw):
        raise FormatError(heap, String("local heap data is outside the file"))
    if btree < 0 or btree + 24 > len(raw):
        raise FormatError(btree, String("group B-tree is outside the file"))
    var nent = u16le(raw, btree + 6)
    var pos = btree + 24 + 8
    var s = 0
    while s < nent:
        var snod = u64le(raw, pos)
        pos += 16
        if snod < 0 or snod + 8 > len(raw):
            raise FormatError(snod, String("symbol table node is outside the file"))
        var nsym = u16le(raw, snod + 6)
        var e = 0
        var ep = snod + 8
        while e < nsym:
            var name_at = u64le(raw, ep)
            var oh = u64le(raw, ep + 8)
            names.append(cstring_at(raw, data_addr + name_at))
            ohs.append(oh)
            ep += 40
            e += 1
        s += 1


def place_chunk(mut dst: List[Byte], rank: Int, n0: Int, n1: Int, es: Int, off0: Int, off1: Int, c0: Int, c1: Int, src: List[Byte]):
    if rank <= 1:
        var j = 0
        while j < c0 and off0 + j < n0:
            var s = j * es
            var d = (off0 + j) * es
            if s + es <= len(src) and d + es <= len(dst):
                var b = 0
                while b < es:
                    dst[d + b] = src[s + b]
                    b += 1
            j += 1
        return
    var r = 0
    while r < c0 and off0 + r < n0:
        var c = 0
        while c < c1 and off1 + c < n1:
            var s = (r * c1 + c) * es
            var d = ((off0 + r) * n1 + (off1 + c)) * es
            if s + es <= len(src) and d + es <= len(dst):
                var b = 0
                while b < es:
                    dst[d + b] = src[s + b]
                    b += 1
            c += 1
        r += 1


def read_payload[origin: ImmOrigin](raw: Span[Byte, origin], info: ObjInfo) raises -> List[Byte]:
    var es = info.es
    if es == 0:
        es = elem_size(info.dtype)
    var total = logical_nbytes(info.rank, info.n0, info.n1, es)
    if info.layout == 1:
        if total == 0:
            return List[Byte]()
        if info.data_addr < 0 or info.data_addr + total > len(raw):
            raise FormatError(info.data_addr, String("contiguous data is outside the file"))
        return copy_span(raw, info.data_addr, total)
    var dst = blank(total)
    if info.layout != 2:
        raise FormatError(0, String("dataset has no data layout"))
    var rank = info.rank
    if rank <= 0:
        rank = 1
    var key_dims = rank + 1
    var key_size = 8 + 8 * key_dims
    var btree = info.chunk_addr
    if btree < 0 or btree + 24 > len(raw):
        raise FormatError(btree, String("chunk B-tree is outside the file"))
    var nent = u16le(raw, btree + 6)
    var pos = btree + 24
    var c = 0
    while c < nent:
        var nbytes = u32le(raw, pos)
        var off0 = u64le(raw, pos + 8)
        var off1 = 0
        if rank > 1:
            off1 = u64le(raw, pos + 16)
        var addr = u64le(raw, pos + key_size)
        if addr < 0 or nbytes < 0 or addr + nbytes > len(raw):
            raise FormatError(addr, String("chunk payload is outside the file"))
        var blob = List[Byte]()
        var k = 0
        while k < nbytes:
            blob.append(raw[addr + k])
            k += 1
        if info.gzip != 0:
            var plain = zlib_inflate(Span(blob))
            place_chunk(dst, rank, info.n0, info.n1, es, off0, off1, info.c0, info.c1, plain^)
        else:
            place_chunk(dst, rank, info.n0, info.n1, es, off0, off1, info.c0, info.c1, blob^)
        pos += key_size + 8
        c += 1
    return dst^


def attach_attrs(mut doc: H5Doc, info: ObjInfo, kind: Int, owner: Int):
    var i = 0
    while i < len(info.attr_name):
        doc.a_kind.append(kind)
        doc.a_owner.append(owner)
        doc.a_name.append(info.attr_name[i])
        doc.a_dtype.append(info.attr_dtype[i])
        doc.a_text.append(info.attr_text[i])
        doc.a_raw.append(info.attr_raw[i].copy())
        i += 1


def read_object[origin: ImmOrigin](raw: Span[Byte, origin], addr: Int, parent: Int, name: String, mut doc: H5Doc) raises:
    var info = parse_oh(raw, addr)
    if info.is_group != 0:
        var gi = doc.add_group(parent, name)
        attach_attrs(doc, info, 0, gi)
        var names = List[String]()
        var ohs = List[Int]()
        load_group_links(raw, info.btree, info.heap, names, ohs)
        var i = 0
        while i < len(names):
            read_object(raw, ohs[i], gi, names[i], doc)
            i += 1
        return
    var chunked = 0
    var c0 = 0
    var c1 = 0
    if info.layout == 2:
        chunked = 1
        c0 = info.c0
        c1 = info.c1
    var data = read_payload(raw, info)
    var di = doc.add_dataset(
        parent,
        name,
        info.dtype,
        info.rank,
        info.n0,
        info.n1,
        data^,
        chunked,
        c0,
        c1,
        info.gzip,
    )
    attach_attrs(doc, info, 1, di)


def read_hdf5[origin: ImmOrigin](raw: Span[Byte, origin]) raises -> H5Doc:
    """Read a superblock version 0 file written by `write_hdf5`."""
    if len(raw) < 96:
        raise FormatError(0, String("file is shorter than a superblock"))
    if Int(raw[0]) != 0x89 or Int(raw[1]) != 72 or Int(raw[2]) != 68 or Int(raw[3]) != 70:
        raise FormatError(0, String("HDF5 signature mismatch"))
    if Int(raw[8]) != 0:
        raise FormatError(8, String("reader supports superblock version 0 only"))
    if Int(raw[13]) != 8 or Int(raw[14]) != 8:
        raise FormatError(13, String("only 8-byte offsets and lengths are supported"))
    var root_oh = u64le(raw, 56 + 8)
    var doc = H5Doc()
    read_object(raw, root_oh, -1, String(""), doc)
    return doc^
