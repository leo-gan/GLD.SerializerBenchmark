from std.collections import List

from parquet_runtime.error import DecodeError


comptime PHY_BOOL = 0
comptime PHY_I32 = 1
comptime PHY_I64 = 2
comptime PHY_I96 = 3
comptime PHY_F32 = 4
comptime PHY_F64 = 5
comptime PHY_BA = 6
comptime PHY_FIXED = 7

comptime REP_REQ = 0
comptime REP_OPT = 1
comptime REP_REPEATED = 2

comptime L_NONE = 0
comptime L_STRING = 1
comptime L_MAP = 2
comptime L_LIST = 3
comptime L_ENUM = 4
comptime L_DECIMAL = 5
comptime L_DATE = 6
comptime L_TIME = 7
comptime L_TIMESTAMP = 8
comptime L_INTEGER = 10
comptime L_UNKNOWN = 11
comptime L_JSON = 12
comptime L_BSON = 13
comptime L_UUID = 14
comptime L_FLOAT16 = 15
comptime L_VARIANT = 16
comptime L_GEOMETRY = 17
comptime L_GEOGRAPHY = 18
comptime L_FILE = 19

comptime UNIT_MILLIS = 1
comptime UNIT_MICROS = 2
comptime UNIT_NANOS = 3

comptime ENC_PLAIN = 0
comptime ENC_DICT = 2
comptime ENC_RLE = 3
comptime ENC_BITPACK = 4
comptime ENC_DELTA = 5
comptime ENC_DELTA_LEN = 6
comptime ENC_DELTA_BA = 7
comptime ENC_RLE_DICT = 8
comptime ENC_BSS = 9
comptime ENC_ALP = 10

comptime CODEC_NONE = 0
comptime CODEC_SNAPPY = 1
comptime CODEC_GZIP = 2
comptime CODEC_LZO = 3
comptime CODEC_BROTLI = 4
comptime CODEC_LZ4 = 5
comptime CODEC_ZSTD = 6
comptime CODEC_LZ4_RAW = 7

comptime MAX_DEPTH = 1024


struct Schema:
    var name: List[String]
    var physical: List[Int]
    var rep: List[Int]
    var type_len: List[Int]
    var nchild: List[Int]
    var logical: List[Int]
    var converted: List[Int]
    var scale: List[Int]
    var precision: List[Int]
    var bit_width: List[Int]
    var is_signed: List[Int]
    var time_unit: List[Int]
    var adjusted: List[Int]
    var field_id: List[Int]
    var crs: List[String]
    var geo_algo: List[Int]
    var variant_spec: List[Int]
    var max_def: List[Int]
    var max_rep: List[Int]
    var span_end: List[Int]
    var leaf_of: List[Int]
    var nleaves: Int

    def __init__(out self):
        self.name = List[String]()
        self.physical = List[Int]()
        self.rep = List[Int]()
        self.type_len = List[Int]()
        self.nchild = List[Int]()
        self.logical = List[Int]()
        self.converted = List[Int]()
        self.scale = List[Int]()
        self.precision = List[Int]()
        self.bit_width = List[Int]()
        self.is_signed = List[Int]()
        self.time_unit = List[Int]()
        self.adjusted = List[Int]()
        self.field_id = List[Int]()
        self.crs = List[String]()
        self.geo_algo = List[Int]()
        self.variant_spec = List[Int]()
        self.max_def = List[Int]()
        self.max_rep = List[Int]()
        self.span_end = List[Int]()
        self.leaf_of = List[Int]()
        self.nleaves = 0

    def add(
        mut self,
        name: String,
        physical: Int,
        rep: Int,
        type_len: Int,
        nchild: Int,
        logical: Int,
    ):
        self.name.append(name)
        self.physical.append(physical)
        self.rep.append(rep)
        self.type_len.append(type_len)
        self.nchild.append(nchild)
        self.logical.append(logical)
        self.converted.append(-1)
        self.scale.append(0)
        self.precision.append(0)
        self.bit_width.append(0)
        self.is_signed.append(1)
        self.time_unit.append(0)
        self.adjusted.append(0)
        self.field_id.append(-1)
        self.crs.append("")
        self.geo_algo.append(-1)
        self.variant_spec.append(-1)
        self.max_def.append(0)
        self.max_rep.append(0)
        self.span_end.append(0)
        self.leaf_of.append(-1)

    def child(self, node: Int, k: Int) -> Int:
        var at = node + 1
        var c = 0
        while c < k:
            at = self.span_end[at]
            c += 1
        return at

    def finish(mut self) raises DecodeError:
        var n = len(self.name)
        if n == 0:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        var i = n - 1
        while i >= 0:
            if self.nchild[i] == 0:
                self.span_end[i] = i + 1
            else:
                var at = i + 1
                var c = 0
                var last = i + 1
                while c < self.nchild[i]:
                    if at >= n:
                        raise DecodeError(DecodeError.KIND_SCHEMA, i)
                    last = self.span_end[at]
                    at = last
                    c += 1
                self.span_end[i] = last
            i -= 1
        if self.span_end[0] != n:
            raise DecodeError(DecodeError.KIND_SCHEMA, 0)
        self._levels(0, 0, 0, 0)
        self.nleaves = 0
        self._leaves(0)

    def _levels(mut self, node: Int, d: Int, r: Int, depth: Int) raises DecodeError:
        if depth > MAX_DEPTH:
            raise DecodeError(DecodeError.KIND_DEPTH, node)
        self.max_def[node] = d
        self.max_rep[node] = r
        var c = 0
        while c < self.nchild[node]:
            var ch = self.child(node, c)
            var d2 = d
            var r2 = r
            if self.rep[ch] != REP_REQ:
                d2 += 1
            if self.rep[ch] == REP_REPEATED:
                r2 += 1
            self._levels(ch, d2, r2, depth + 1)
            c += 1

    def _leaves(mut self, node: Int):
        if self.physical[node] >= 0:
            self.leaf_of[node] = self.nleaves
            self.nleaves += 1
            return
        self.leaf_of[node] = -1
        var c = 0
        while c < self.nchild[node]:
            self._leaves(self.child(node, c))
            c += 1


struct Cols:
    var schema_i: List[Int]
    var level_b: List[Int]
    var level_n: List[Int]
    var val_b: List[Int]
    var val_n: List[Int]
    var byte_b: List[Int]
    var defs: List[Int]
    var reps: List[Int]
    var i64s: List[Int]
    var bits: List[UInt64]
    var raw: List[Byte]
    var ends: List[Int]
    var cur: Int

    def __init__(out self):
        self.schema_i = List[Int]()
        self.level_b = List[Int]()
        self.level_n = List[Int]()
        self.val_b = List[Int]()
        self.val_n = List[Int]()
        self.byte_b = List[Int]()
        self.defs = List[Int]()
        self.reps = List[Int]()
        self.i64s = List[Int]()
        self.bits = List[UInt64]()
        self.raw = List[Byte]()
        self.ends = List[Int]()
        self.cur = -1

    def begin(mut self, schema_i: Int, physical: Int):
        self.schema_i.append(schema_i)
        self.level_b.append(len(self.defs))
        self.level_n.append(0)
        if physical == PHY_F32 or physical == PHY_F64:
            self.val_b.append(len(self.bits))
        elif physical == PHY_BA or physical == PHY_FIXED or physical == PHY_I96:
            self.val_b.append(len(self.ends))
        else:
            self.val_b.append(len(self.i64s))
        self.val_n.append(0)
        self.byte_b.append(len(self.raw))
        self.cur = len(self.schema_i) - 1

    def use(mut self, slot: Int):
        self.cur = slot

    def add_level(mut self, d: Int, r: Int):
        var leaf = self.cur
        self.defs.append(d)
        self.reps.append(r)
        self.level_n[leaf] += 1

    def add_i64(mut self, v: Int):
        var leaf = self.cur
        self.i64s.append(v)
        self.val_n[leaf] += 1

    def add_bits(mut self, v: UInt64):
        var leaf = self.cur
        self.bits.append(v)
        self.val_n[leaf] += 1

    def add_bytes(mut self, raw: List[Byte]):
        var leaf = self.cur
        var i = 0
        while i < len(raw):
            self.raw.append(raw[i])
            i += 1
        self.ends.append(len(self.raw))
        self.val_n[leaf] += 1


struct WriteOpts:
    var codec: Int
    var encoding: Int
    var page_v2: Int
    var page_size: Int
    var rg_rows: Int
    var stats: Int
    var page_index: Int
    var bloom: Int
    var crc: Int
    var dictionary: Int
    var alp: Int

    def __init__(out self):
        self.codec = CODEC_NONE
        self.encoding = -1
        self.page_v2 = 0
        self.page_size = 1048576
        self.rg_rows = 1048576
        self.stats = 1
        self.page_index = 0
        self.bloom = 0
        self.crc = 1
        self.dictionary = 0
        self.alp = 0


def phy_width(physical: Int, type_len: Int) -> Int:
    if physical == PHY_BOOL:
        return 1
    if physical == PHY_I32 or physical == PHY_F32:
        return 4
    if physical == PHY_I64 or physical == PHY_F64:
        return 8
    if physical == PHY_I96:
        return 12
    if physical == PHY_FIXED or physical == PHY_BA:
        return type_len
    return 0
