from std.collections import List, Span

from avro_runtime.error import DecodeError
from avro_runtime.logical import (
    LT_DURATION,
    LT_TIME_MICROS,
    LT_TIME_MILLIS,
    LT_UUID,
    logical_kind,
    logical_underlying_ok,
    time_micros_valid,
    time_millis_valid,
    uuid_is_valid,
)
from avro_schema.model import (
    ST_ARRAY,
    ST_BOOL,
    ST_BYTES,
    ST_DOUBLE,
    ST_ENUM,
    ST_FIXED,
    ST_FLOAT,
    ST_INT,
    ST_LONG,
    ST_MAP,
    ST_NULL,
    ST_RECORD,
    ST_REF,
    ST_STRING,
    ST_UNION,
    SchemaPool,
)
from avro_wire.reader import WireReader
from avro_wire.writer import WireWriter


comptime AV_NULL = 0
comptime AV_BOOL = 1
comptime AV_INT = 2
comptime AV_LONG = 3
comptime AV_FLOAT = 4
comptime AV_DOUBLE = 5
comptime AV_BYTES = 6
comptime AV_STRING = 7
comptime AV_ENUM = 8
comptime AV_FIXED = 9
comptime AV_ARRAY = 10
comptime AV_MAP = 11
comptime AV_RECORD = 12
comptime AV_UNION = 13


struct AvroNode(Copyable, Movable, Defaultable, ImplicitlyCopyable):
    var kind: Int
    var b: Bool
    var i: Int64
    var s: String
    var first: Int
    var count: Int
    var schema_id: Int

    def __init__(out self):
        self.kind = AV_NULL
        self.b = False
        self.i = 0
        self.s = String()
        self.first = 0
        self.count = 0
        self.schema_id = -1


struct GenericDatum(Movable):
    var pool: SchemaPool
    var nodes: List[AvroNode]
    var bytes_store: List[Byte]
    var bytes_start: List[Int]
    var bytes_len: List[Int]
    var refs: List[Int]
    var root: Int

    def __init__(out self, var pool: SchemaPool):
        self.pool = pool^
        self.nodes = List[AvroNode]()
        self.bytes_store = List[Byte]()
        self.bytes_start = List[Int]()
        self.bytes_len = List[Int]()
        self.refs = List[Int]()
        self.root = -1

    def add_node(mut self, var n: AvroNode) -> Int:
        var id = len(self.nodes)
        self.nodes.append(n)
        return id

    def store_bytes(mut self, data: List[Byte]) -> Int:
        var start = len(self.bytes_store)
        var i = 0
        while i < len(data):
            self.bytes_store.append(data[i])
            i += 1
        self.bytes_start.append(start)
        self.bytes_len.append(len(data))
        return len(self.bytes_start) - 1

    def encode(self) -> List[Byte]:
        var enc = WireWriter()
        self._enc(enc, self.root, self.pool.root)
        return enc^.finish()

    def _enc(self, mut enc: WireWriter, nid: Int, sid: Int):
        var sid2 = self.pool.resolve(sid)
        var k = self.pool.nodes[sid2].kind
        if k == ST_NULL:
            return
        if k == ST_BOOL:
            enc.write_bool(self.nodes[nid].b)
            return
        if k == ST_INT:
            enc.write_int(Int32(self.nodes[nid].i))
            return
        if k == ST_LONG:
            enc.write_long(self.nodes[nid].i)
            return
        if k == ST_FLOAT:
            enc.write_float(Float32(from_bits=UInt32(self.nodes[nid].i)))
            return
        if k == ST_DOUBLE:
            enc.write_double(Float64(from_bits=UInt64(self.nodes[nid].i)))
            return
        if k == ST_STRING:
            enc.write_string(self.nodes[nid].s)
            return
        if k == ST_BYTES or k == ST_FIXED:
            var bi = Int(self.nodes[nid].i)
            var start = self.bytes_start[bi]
            var n = self.bytes_len[bi]
            if k == ST_BYTES:
                enc.write_long(Int64(n))
            var j = 0
            while j < n:
                enc.write_byte(self.bytes_store[start + j])
                j += 1
            return
        if k == ST_ENUM:
            enc.write_int(Int32(self.nodes[nid].i))
            return
        if k == ST_RECORD:
            var fs = self.pool.nodes[sid2].field_start
            var fc = self.pool.nodes[sid2].field_count
            var i = 0
            while i < fc:
                self._enc(enc, self.refs[self.nodes[nid].first + i], self.pool.field_type[fs + i])
                i += 1
            return
        if k == ST_ARRAY:
            var c = self.nodes[nid].count
            if c > 0:
                enc.write_block_start(Int64(c))
                var i = 0
                while i < c:
                    self._enc(enc, self.refs[self.nodes[nid].first + i], self.pool.nodes[sid2].item_id)
                    i += 1
            enc.write_block_end()
            return
        if k == ST_MAP:
            var c = self.nodes[nid].count
            if c > 0:
                enc.write_block_start(Int64(c))
                var i = 0
                while i < c:
                    var key_id = self.refs[self.nodes[nid].first + i * 2]
                    var val_id = self.refs[self.nodes[nid].first + i * 2 + 1]
                    enc.write_string(self.nodes[key_id].s)
                    self._enc(enc, val_id, self.pool.nodes[sid2].value_id)
                    i += 1
            enc.write_block_end()
            return
        if k == ST_UNION:
            var idx = Int(self.nodes[nid].i)
            enc.write_long(Int64(idx))
            var bs = self.pool.nodes[sid2].branch_start
            var child = self.refs[self.nodes[nid].first]
            self._enc(enc, child, self.pool.branch_id[bs + idx])

    def decode[origin: ImmOrigin](mut self, buf: Span[Byte, origin]) raises DecodeError:
        var dec = WireReader[origin](buf)
        self.root = self._dec(dec, self.pool.root)

    def _dec[
        origin: ImmOrigin
    ](mut self, mut dec: WireReader[origin], sid: Int) raises DecodeError -> Int:
        var sid2 = self.pool.resolve(sid)
        var k = self.pool.nodes[sid2].kind
        var n = AvroNode()
        n.schema_id = sid2
        if k == ST_NULL:
            n.kind = AV_NULL
            return self.add_node(n)
        if k == ST_BOOL:
            n.kind = AV_BOOL
            n.b = dec.read_bool()
            return self.add_node(n)
        if k == ST_INT:
            n.kind = AV_INT
            n.i = Int64(dec.read_int())
            var iid = self.add_node(n)
            self._check_logical(sid2, iid, dec.position())
            return iid
        if k == ST_LONG:
            n.kind = AV_LONG
            n.i = dec.read_long()
            var lid = self.add_node(n)
            self._check_logical(sid2, lid, dec.position())
            return lid
        if k == ST_FLOAT:
            n.kind = AV_FLOAT
            n.i = Int64(UInt32(dec.read_float().to_bits()))
            return self.add_node(n)
        if k == ST_DOUBLE:
            n.kind = AV_DOUBLE
            n.i = Int64(dec.read_double().to_bits())
            return self.add_node(n)
        if k == ST_STRING:
            n.kind = AV_STRING
            n.s = dec.read_string()
            var sidn = self.add_node(n)
            self._check_logical(sid2, sidn, dec.position())
            return sidn
        if k == ST_BYTES:
            n.kind = AV_BYTES
            var b = dec.read_bytes()
            n.i = Int64(self.store_bytes(b))
            var bid = self.add_node(n)
            self._check_logical(sid2, bid, dec.position())
            return bid
        if k == ST_FIXED:
            n.kind = AV_FIXED
            var b = dec.read_fixed(self.pool.nodes[sid2].size)
            n.i = Int64(self.store_bytes(b))
            var fid = self.add_node(n)
            self._check_logical(sid2, fid, dec.position())
            return fid
        if k == ST_ENUM:
            n.kind = AV_ENUM
            var idx = Int(dec.read_int())
            if idx < 0 or idx >= self.pool.nodes[sid2].symbol_count:
                raise DecodeError(DecodeError.KIND_BAD_ENUM, dec.position())
            n.i = Int64(idx)
            return self.add_node(n)
        if k == ST_RECORD:
            n.kind = AV_RECORD
            var first = len(self.refs)
            var fs = self.pool.nodes[sid2].field_start
            var fc = self.pool.nodes[sid2].field_count
            var i = 0
            while i < fc:
                var cid = self._dec(dec, self.pool.field_type[fs + i])
                self.refs.append(cid)
                i += 1
            n.first = first
            n.count = fc
            return self.add_node(n)
        if k == ST_ARRAY:
            n.kind = AV_ARRAY
            var first = len(self.refs)
            var total = 0
            while True:
                var count, _hint = dec.read_block_count()
                if count == 0:
                    break
                var j = Int64(0)
                while j < count:
                    var cid = self._dec(dec, self.pool.nodes[sid2].item_id)
                    self.refs.append(cid)
                    total += 1
                    j += 1
            n.first = first
            n.count = total
            return self.add_node(n)
        if k == ST_MAP:
            n.kind = AV_MAP
            var first = len(self.refs)
            var total = 0
            while True:
                var count, _hint = dec.read_block_count()
                if count == 0:
                    break
                var j = Int64(0)
                while j < count:
                    var kn = AvroNode()
                    kn.kind = AV_STRING
                    kn.s = dec.read_string()
                    var kid = self.add_node(kn)
                    var vid = self._dec(dec, self.pool.nodes[sid2].value_id)
                    self.refs.append(kid)
                    self.refs.append(vid)
                    total += 1
                    j += 1
            n.first = first
            n.count = total
            return self.add_node(n)
        if k == ST_UNION:
            n.kind = AV_UNION
            var idx = dec.read_long()
            if idx < 0 or idx >= Int64(self.pool.nodes[sid2].branch_count):
                raise DecodeError(DecodeError.KIND_BAD_UNION, dec.position())
            n.i = idx
            var bid = self.pool.branch_id[self.pool.nodes[sid2].branch_start + Int(idx)]
            var cid = self._dec(dec, bid)
            n.first = len(self.refs)
            self.refs.append(cid)
            n.count = 1
            return self.add_node(n)
        raise DecodeError(DecodeError.KIND_SCHEMA, dec.position())

    def _check_logical(self, sid2: Int, nid: Int, offset: Int) raises DecodeError:
        var lt = self.pool.nodes[sid2].logical_type
        if lt.byte_length() == 0:
            return
        var kind = logical_kind(lt)
        if not logical_underlying_ok(
            self.pool.nodes[sid2].kind, self.pool.nodes[sid2].size, kind
        ):
            return
        if kind == LT_UUID:
            if not uuid_is_valid(self.nodes[nid].s):
                raise DecodeError(DecodeError.KIND_RANGE, offset)
            return
        if kind == LT_TIME_MILLIS:
            if not time_millis_valid(Int32(self.nodes[nid].i)):
                raise DecodeError(DecodeError.KIND_RANGE, offset)
            return
        if kind == LT_TIME_MICROS:
            if not time_micros_valid(self.nodes[nid].i):
                raise DecodeError(DecodeError.KIND_RANGE, offset)
            return
        if kind == LT_DURATION:
            var bi = Int(self.nodes[nid].i)
            if bi < 0 or bi >= len(self.bytes_len) or self.bytes_len[bi] != 12:
                raise DecodeError(DecodeError.KIND_RANGE, offset)

    def is_null(self) -> Bool:
        return self.root >= 0 and self.nodes[self.root].kind == AV_NULL

    def as_int(self) raises DecodeError -> Int32:
        if self.root < 0 or (
            self.nodes[self.root].kind != AV_INT and self.nodes[self.root].kind != AV_LONG
        ):
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return Int32(self.nodes[self.root].i)

    def as_long(self) raises DecodeError -> Int64:
        if self.root < 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return self.nodes[self.root].i

    def as_string(self) raises DecodeError -> String:
        if self.root < 0 or self.nodes[self.root].kind != AV_STRING:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return self.nodes[self.root].s

    def as_record(self) raises DecodeError -> GenericRecord:
        if self.root < 0 or self.nodes[self.root].kind != AV_RECORD:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return GenericRecord(self.root)

    def as_array(self) raises DecodeError -> GenericArray:
        if self.root < 0 or self.nodes[self.root].kind != AV_ARRAY:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return GenericArray(self.root)

    def as_map(self) raises DecodeError -> GenericMap:
        if self.root < 0 or self.nodes[self.root].kind != AV_MAP:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return GenericMap(self.root)

    def as_union(self) raises DecodeError -> GenericUnion:
        if self.root < 0 or self.nodes[self.root].kind != AV_UNION:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return GenericUnion(self.root)

    def field_count(self, rec: GenericRecord) -> Int:
        return self.nodes[rec.node_index].count

    def field_name(self, rec: GenericRecord, i: Int) raises DecodeError -> String:
        var sid = self.pool.resolve(self.nodes[rec.node_index].schema_id)
        if i < 0 or i >= self.pool.nodes[sid].field_count:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return self.pool.field_name[self.pool.nodes[sid].field_start + i]

    def get_at(self, rec: GenericRecord, i: Int) raises DecodeError -> Int:
        if i < 0 or i >= self.nodes[rec.node_index].count:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        return self.refs[self.nodes[rec.node_index].first + i]

    def get_field(self, rec: GenericRecord, name: String) raises DecodeError -> Int:
        var n = self.field_count(rec)
        var i = 0
        while i < n:
            if self.field_name(rec, i) == name:
                return self.get_at(rec, i)
            i += 1
        raise DecodeError(DecodeError.KIND_SCHEMA, 0)

    def set_at(mut self, rec: GenericRecord, i: Int, child: Int) raises DecodeError:
        if i < 0 or i >= self.nodes[rec.node_index].count:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        self.refs[self.nodes[rec.node_index].first + i] = child

    def child_int(self, nid: Int) -> Int64:
        return self.nodes[nid].i

    def array_len(self, arr: GenericArray) -> Int:
        return self.nodes[arr.node_index].count

    def union_branch(self, u: GenericUnion) -> Int:
        return Int(self.nodes[u.node_index].i)


struct GenericRecord(Copyable, Movable, ImplicitlyCopyable):
    var node_index: Int

    def __init__(out self, node_index: Int):
        self.node_index = node_index


struct GenericArray(Copyable, Movable, ImplicitlyCopyable):
    var node_index: Int

    def __init__(out self, node_index: Int):
        self.node_index = node_index


struct GenericMap(Copyable, Movable, ImplicitlyCopyable):
    var node_index: Int

    def __init__(out self, node_index: Int):
        self.node_index = node_index


struct GenericUnion(Copyable, Movable, ImplicitlyCopyable):
    var node_index: Int

    def __init__(out self, node_index: Int):
        self.node_index = node_index
