"""gld-kiln-asm: pure x86-64 Assembly Kiln Wire Format v2 codec loaded via
shared `build/kiln-asm/libkiln_asm_bench.so` (Tier 1 zero-cost C ABI).

Covers all 4 supported Data Sets: `suite`, `columnar`, `array`, and `tensor`.
Full RFC 3629 UTF-8 validation is always active (no `KILN_OPT_TRUSTED`).
"""

from std.benchmark import keep
from std.collections import List, Span
from std.ffi import OwnedDLHandle
from std.memory import unsafe_memcpy
from std.os import getenv

from bench.data import (
    Document,
    DocumentItem,
    DocumentMeta,
    Event,
    EventAttr,
    Fixture,
    Grid,
    Message,
    NestedItem,
    NestedMeta,
    NestedRow,
    PromptValue,
    RequestValue,
    ShardValue,
    SignalLeg,
    SignalRow,
    Strings,
    TableRow,
    Telemetry,
    TensorValue,
)

comptime KILN_OK: UInt32 = 0
comptime KILN_OPT_EMBEDDED: UInt32 = 1 << 3
comptime KILN_DTYPE_F64: UInt16 = 1
comptime KILN_DTYPE_F32: UInt16 = 2
comptime KILN_DTYPE_I64: UInt16 = 14

comptime FnEncOne = def (UInt64, UInt64, Int, UInt64, UInt64) thin abi("C") -> UInt32
comptime FnDecOne = def (UInt64, Int, UInt64, UInt64, UInt64, UInt64) thin abi("C") -> UInt32
comptime FnEncBatch = def (UInt64, Int, UInt64, Int, UInt64, UInt64) thin abi("C") -> UInt32
comptime FnDecBatch = def (UInt64, Int, UInt64, UInt64, UInt64, UInt64, UInt64) thin abi("C") -> UInt32


struct KilnArena(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var base: UInt64
    var cur: UInt64
    var end: UInt64

    def __init__(out self):
        self.base = 0
        self.cur = 0
        self.end = 0


struct KilnReadOpts(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var max_count: UInt64
    var max_bytes: UInt64
    var max_depth: UInt32
    var flags: UInt32

    def __init__(out self):
        self.max_count = 0
        self.max_bytes = 0
        self.max_depth = 0
        self.flags = 0


struct KilnResult(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var bytes: UInt64
    var hash: UInt64

    def __init__(out self):
        self.bytes = 0
        self.hash = 0


struct KilnStr(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var ptr: UInt64
    var length: UInt64

    def __init__(out self):
        self.ptr = 0
        self.length = 0


struct KilnList(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var items: UInt64
    var count: UInt64

    def __init__(out self):
        self.items = 0
        self.count = 0


struct KilnTensor(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var name: UInt64
    var name_len: UInt64
    var layout: UInt64
    var layout_len: UInt64
    var data: UInt64
    var data_len: UInt64
    var s0: UInt64
    var s1: UInt64
    var s2: UInt64
    var s3: UInt64
    var s4: UInt64
    var s5: UInt64
    var s6: UInt64
    var s7: UInt64
    var dtype: UInt16
    var rank: UInt8
    var _pad0: UInt8
    var quant_scheme: UInt16
    var quant_axis: UInt16
    var group_size: UInt32
    var scale_index: UInt32
    var outer_index: UInt32
    var block_size: UInt32
    var elem_count: UInt64

    def __init__(out self):
        self.name = 0
        self.name_len = 0
        self.layout = 0
        self.layout_len = 0
        self.data = 0
        self.data_len = 0
        self.s0 = 0
        self.s1 = 0
        self.s2 = 0
        self.s3 = 0
        self.s4 = 0
        self.s5 = 0
        self.s6 = 0
        self.s7 = 0
        self.dtype = 0
        self.rank = 0
        self._pad0 = 0
        self.quant_scheme = 0
        self.quant_axis = 0xFFFF
        self.group_size = 0
        self.scale_index = 0xFFFFFFFF
        self.outer_index = 0xFFFFFFFF
        self.block_size = 0
        self.elem_count = 0


struct KilnTensorDir(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var items: UInt64
    var count: UInt64
    var block_length: UInt64
    var flags: UInt32
    var version: UInt32

    def __init__(out self):
        self.items = 0
        self.count = 0
        self.block_length = 0
        self.flags = 2
        self.version = 2


struct BenchMessage(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var f_bool: UInt8
    var _p0: UInt8
    var _p1: UInt16
    var f_int32: Int32
    var f_int64: Int64
    var f_float64: Float64
    var f_string: KilnStr
    var f_bool_2: UInt8
    var _p2: UInt8
    var _p3: UInt16
    var f_int32_2: Int32
    var f_string_2: KilnStr

    def __init__(out self):
        self.f_bool = 0
        self._p0 = 0
        self._p1 = 0
        self.f_int32 = 0
        self.f_int64 = 0
        self.f_float64 = 0.0
        self.f_string = KilnStr()
        self.f_bool_2 = 0
        self._p2 = 0
        self._p3 = 0
        self.f_int32_2 = 0
        self.f_string_2 = KilnStr()


struct BenchDocMeta(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var region: KilnStr
    var version: Int32
    var _p0: Int32

    def __init__(out self):
        self.region = KilnStr()
        self.version = 0
        self._p0 = 0


struct BenchDocItem(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var sku: KilnStr
    var qty: Int32
    var _p0: Int32
    var price_minor: Int64

    def __init__(out self):
        self.sku = KilnStr()
        self.qty = 0
        self._p0 = 0
        self.price_minor = 0


struct BenchDocument(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var id: KilnStr
    var status: Int32
    var _p0: Int32
    var meta: BenchDocMeta
    var items: KilnList

    def __init__(out self):
        self.id = KilnStr()
        self.status = 0
        self._p0 = 0
        self.meta = BenchDocMeta()
        self.items = KilnList()


struct BenchTelemetry(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var source: KilnStr
    var ts: Int64
    var tags: KilnList
    var values: KilnList

    def __init__(out self):
        self.source = KilnStr()
        self.ts = 0
        self.tags = KilnList()
        self.values = KilnList()


struct BenchStrings(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var items: KilnList

    def __init__(out self):
        self.items = KilnList()


struct BenchEventAttr(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var key: KilnStr
    var value: KilnStr

    def __init__(out self):
        self.key = KilnStr()
        self.value = KilnStr()


struct BenchEvent(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var event_id: KilnStr
    var event_type: KilnStr
    var occurred_at: Int64
    var producer: KilnStr
    var attrs: KilnList

    def __init__(out self):
        self.event_id = KilnStr()
        self.event_type = KilnStr()
        self.occurred_at = 0
        self.producer = KilnStr()
        self.attrs = KilnList()


struct BenchTableProject(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var f_float_0: KilnList

    def __init__(out self):
        self.f_float_0 = KilnList()


struct BenchSignalLeg(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var leg_id: Int64
    var leg_qty: Int32
    var leg_pad: Int32

    def __init__(out self):
        self.leg_id = 0
        self.leg_qty = 0
        self.leg_pad = 0


struct BenchSignal(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var seq: Int64
    var ts: Int64
    var price_mantissa: Int64
    var qty: Int32
    var flags: Int32
    var symbol: KilnStr
    var venue: KilnStr
    var legs: KilnList

    def __init__(out self):
        self.seq = 0
        self.ts = 0
        self.price_mantissa = 0
        self.qty = 0
        self.flags = 0
        self.symbol = KilnStr()
        self.venue = KilnStr()
        self.legs = KilnList()


struct BenchRequest(Copyable, ImplicitlyCopyable, Movable, Defaultable):
    var request_id: Int64
    var model: KilnStr
    var temperature: Float32
    var _p0: UInt32
    var inputs: KilnTensorDir

    def __init__(out self):
        self.request_id = 0
        self.model = KilnStr()
        self.temperature = 0.0
        self._p0 = 0
        self.inputs = KilnTensorDir()


@always_inline
def _kstr(ref s: String) -> KilnStr:
    var b = s.as_bytes()
    var ks = KilnStr()
    ks.length = UInt64(len(b))
    if len(b) > 0:
        ks.ptr = UInt64(Int(b.unsafe_ptr()))
    return ks^


@always_inline
def _from_kstr(ks: KilnStr) -> String:
    var n = Int(ks.length)
    var out = String(unsafe_uninit_length=n)
    if n > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr_mut(),
            src=Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(ks.ptr)),
            count=n,
        )
    return out^


@always_inline
def _copy_f64_raw(addr: UInt64, count: Int) -> List[Float64]:
    var out = List[Float64](unsafe_uninit_length=count)
    if count > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(addr)),
            count=count * 8,
        )
    return out^


@always_inline
def _copy_i64_raw(addr: UInt64, count: Int) -> List[Int64]:
    var out = List[Int64](unsafe_uninit_length=count)
    if count > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(addr)),
            count=count * 8,
        )
    return out^


@always_inline
def _copy_f32_raw(addr: UInt64, count: Int) -> List[Float32]:
    var out = List[Float32](unsafe_uninit_length=count)
    if count > 0:
        unsafe_memcpy(
            dest=out.unsafe_ptr().unsafe_bitcast[UInt8](),
            src=Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(addr)),
            count=count * 4,
        )
    return out^


def _set_tensor_1d(dtype: UInt16, d0: UInt64, addr: UInt64, nbytes: UInt64) -> KilnTensor:
    var t = KilnTensor()
    t.dtype = dtype
    t.rank = 1
    t.s0 = d0
    t.data = addr if nbytes > 0 else UInt64(0)
    t.data_len = nbytes
    t.elem_count = d0
    return t^


def _set_tensor_2d(dtype: UInt16, d0: UInt64, d1: UInt64, addr: UInt64, nbytes: UInt64) -> KilnTensor:
    var t = KilnTensor()
    t.dtype = dtype
    t.rank = 2
    t.s0 = d0
    t.s1 = d1
    t.data = addr if nbytes > 0 else UInt64(0)
    t.data_len = nbytes
    t.elem_count = d0 * d1
    return t^


def _fill_msg(ref m: Message) -> BenchMessage:
    var bm = BenchMessage()
    bm.f_bool = UInt8(1) if m.f_bool else UInt8(0)
    bm.f_int32 = m.f_int32
    bm.f_int64 = m.f_int64
    bm.f_float64 = m.f_float64
    bm.f_string = _kstr(m.f_string)
    bm.f_bool_2 = UInt8(1) if m.f_bool_2 else UInt8(0)
    bm.f_int32_2 = m.f_int32_2
    bm.f_string_2 = _kstr(m.f_string_2)
    return bm^


def _read_msg(bm: BenchMessage) -> Message:
    return Message(
        bm.f_bool != 0,
        bm.f_int32,
        bm.f_int64,
        bm.f_float64,
        _from_kstr(bm.f_string),
        bm.f_bool_2 != 0,
        bm.f_int32_2,
        _from_kstr(bm.f_string_2),
    )


def _read_doc(bd: BenchDocument) -> Document:
    var n = Int(bd.items.count)
    var items = List[DocumentItem](capacity=n)
    if n > 0:
        var p = Pointer[BenchDocItem, ImmutAnyOrigin](unsafe_from_address=Int(bd.items.items))
        var i = 0
        while i < n:
            var it = p.unsafe_offset(i)[]
            items.append(DocumentItem(_from_kstr(it.sku), it.qty, it.price_minor))
            i += 1
    return Document(
        _from_kstr(bd.id),
        bd.status,
        DocumentMeta(_from_kstr(bd.meta.region), bd.meta.version),
        items^,
    )


def _read_nested(bd: BenchDocument) -> NestedRow:
    var n = Int(bd.items.count)
    var items = List[NestedItem](capacity=n)
    if n > 0:
        var p = Pointer[BenchDocItem, ImmutAnyOrigin](unsafe_from_address=Int(bd.items.items))
        var i = 0
        while i < n:
            var it = p.unsafe_offset(i)[]
            items.append(NestedItem(_from_kstr(it.sku), it.qty, it.price_minor))
            i += 1
    return NestedRow(
        _from_kstr(bd.id),
        bd.status,
        NestedMeta(_from_kstr(bd.meta.region), bd.meta.version),
        items^,
    )


def _read_tel(bt: BenchTelemetry) -> Telemetry:
    var nt = Int(bt.tags.count)
    var tags = List[String](capacity=nt)
    if nt > 0:
        var p = Pointer[KilnStr, ImmutAnyOrigin](unsafe_from_address=Int(bt.tags.items))
        var i = 0
        while i < nt:
            tags.append(_from_kstr(p.unsafe_offset(i)[]))
            i += 1
    var values = _copy_f64_raw(bt.values.items, Int(bt.values.count))
    return Telemetry(_from_kstr(bt.source), bt.ts, tags^, values^)


def _read_strs(bs: BenchStrings) -> Strings:
    var n = Int(bs.items.count)
    var items = List[String](capacity=n)
    if n > 0:
        var p = Pointer[KilnStr, ImmutAnyOrigin](unsafe_from_address=Int(bs.items.items))
        var i = 0
        while i < n:
            items.append(_from_kstr(p.unsafe_offset(i)[]))
            i += 1
    return Strings(items^)


def _read_ev(be: BenchEvent) -> Event:
    var n = Int(be.attrs.count)
    var attrs = List[EventAttr](capacity=n)
    if n > 0:
        var p = Pointer[BenchEventAttr, ImmutAnyOrigin](unsafe_from_address=Int(be.attrs.items))
        var i = 0
        while i < n:
            var a = p.unsafe_offset(i)[]
            attrs.append(EventAttr(_from_kstr(a.key), _from_kstr(a.value)))
            i += 1
    return Event(
        _from_kstr(be.event_id),
        _from_kstr(be.event_type),
        be.occurred_at,
        _from_kstr(be.producer),
        attrs^,
    )


def _read_sig(bs: BenchSignal) -> SignalRow:
    var n = Int(bs.legs.count)
    var legs = List[SignalLeg](capacity=n)
    if n > 0:
        var p = Pointer[BenchSignalLeg, ImmutAnyOrigin](unsafe_from_address=Int(bs.legs.items))
        var i = 0
        while i < n:
            var l = p.unsafe_offset(i)[]
            legs.append(SignalLeg(l.leg_id, l.leg_qty, l.leg_pad))
            i += 1
    return SignalRow(
        bs.seq,
        bs.ts,
        bs.price_mantissa,
        bs.qty,
        bs.flags,
        _from_kstr(bs.symbol),
        _from_kstr(bs.venue),
        legs^,
    )


def _read_prompt_dir(dir: KilnTensorDir) raises -> PromptValue:
    if dir.count != 3 or dir.items == 0:
        raise Error("gld-kiln-asm: invalid prompt tensor dir")
    var p = Pointer[KilnTensor, ImmutAnyOrigin](unsafe_from_address=Int(dir.items))
    var t0 = p.unsafe_offset(0)[]
    var t1 = p.unsafe_offset(1)[]
    var t2 = p.unsafe_offset(2)[]
    if t0.dtype != KILN_DTYPE_I64 or t0.rank != 2:
        raise Error("gld-kiln-asm: invalid prompt tensor meta")
    var n = Int(t0.elem_count)
    return PromptValue(
        Int32(t0.s0),
        Int32(t0.s1),
        _copy_i64_raw(t0.data, n),
        _copy_i64_raw(t1.data, n),
        _copy_i64_raw(t2.data, n),
    )


def _open_kiln_asm_lib() raises -> OwnedDLHandle:
    var env_p = getenv("GLD_KILN_ASM_BENCH_SO")
    if env_p.byte_length() > 0:
        return OwnedDLHandle(env_p)
    try:
        return OwnedDLHandle("../build/kiln-asm/libkiln_asm_bench.so")
    except:
        return OwnedDLHandle("build/kiln-asm/libkiln_asm_bench.so")


struct KilnAsmSer(Movable):
    var version: String
    var lib: OwnedDLHandle
    var fn_enc_msg: FnEncOne
    var fn_dec_msg: FnDecOne
    var fn_enc_msg_batch: FnEncBatch
    var fn_dec_msg_batch: FnDecBatch
    var fn_enc_doc: FnEncOne
    var fn_dec_doc: FnDecOne
    var fn_enc_doc_batch: FnEncBatch
    var fn_dec_doc_batch: FnDecBatch
    var fn_enc_tel: FnEncOne
    var fn_dec_tel: FnDecOne
    var fn_enc_tel_batch: FnEncBatch
    var fn_dec_tel_batch: FnDecBatch
    var fn_enc_strs: FnEncOne
    var fn_dec_strs: FnDecOne
    var fn_enc_strs_batch: FnEncBatch
    var fn_dec_strs_batch: FnDecBatch
    var fn_enc_ev: FnEncOne
    var fn_dec_ev: FnDecOne
    var fn_enc_ev_batch: FnEncBatch
    var fn_dec_ev_batch: FnDecBatch
    var fn_enc_tc: FnEncOne
    var fn_dec_tc: FnDecOne
    var fn_dec_tp: FnDecOne
    var fn_enc_nr: FnEncOne
    var fn_dec_nr: FnDecOne
    var fn_enc_nr_batch: FnEncBatch
    var fn_dec_nr_batch: FnDecBatch
    var fn_enc_sig: FnEncOne
    var fn_dec_sig: FnDecOne
    var fn_enc_sig_batch: FnEncBatch
    var fn_dec_sig_batch: FnDecBatch
    var fn_enc_req: FnEncOne
    var fn_dec_req: FnDecOne
    var fn_enc_tensors: FnEncOne
    var fn_dec_tensors: FnDecOne

    var arena_buf: List[UInt8]
    var arena_hdr: List[UInt64]
    var res_buf: List[UInt64]
    var pair_buf: List[UInt64]
    var opts_large: List[KilnReadOpts]
    var opts_emb: List[KilnReadOpts]
    var dec_scratch: List[UInt8]
    var enc_dir: List[KilnTensorDir]
    var enc_req: List[BenchRequest]
    var enc_msg: List[BenchMessage]
    var enc_doc: List[BenchDocument]
    var enc_doc_items: List[BenchDocItem]
    var enc_tel: List[BenchTelemetry]
    var enc_str_items: List[KilnStr]
    var enc_strs: List[BenchStrings]
    var enc_ev: List[BenchEvent]
    var enc_ev_attrs: List[BenchEventAttr]
    var enc_sig: List[BenchSignal]
    var enc_sig_legs: List[BenchSignalLeg]
    var enc_f64: List[Float64]
    var enc_i64: List[Int64]
    var enc_col_str: List[KilnStr]
    var enc_tc: List[KilnList]
    var enc_tensors: List[KilnTensor]

    def __init__(out self) raises:
        self.version = "0.2.0"
        self.lib = _open_kiln_asm_lib()
        self.fn_enc_msg = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_message")
        self.fn_dec_msg = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_message")
        self.fn_enc_msg_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_message_batch")
        self.fn_dec_msg_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_message_batch")
        self.fn_enc_doc = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_document")
        self.fn_dec_doc = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_document")
        self.fn_enc_doc_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_document_batch")
        self.fn_dec_doc_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_document_batch")
        self.fn_enc_tel = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_telemetry")
        self.fn_dec_tel = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_telemetry")
        self.fn_enc_tel_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_telemetry_batch")
        self.fn_dec_tel_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_telemetry_batch")
        self.fn_enc_strs = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_strings")
        self.fn_dec_strs = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_strings")
        self.fn_enc_strs_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_strings_batch")
        self.fn_dec_strs_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_strings_batch")
        self.fn_enc_ev = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_event")
        self.fn_dec_ev = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_event")
        self.fn_enc_ev_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_event_batch")
        self.fn_dec_ev_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_event_batch")
        self.fn_enc_tc = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_table_columns")
        self.fn_dec_tc = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_table_columns")
        self.fn_dec_tp = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_table_project")
        self.fn_enc_nr = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_nested_row")
        self.fn_dec_nr = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_nested_row")
        self.fn_enc_nr_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_nested_row_batch")
        self.fn_dec_nr_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_nested_row_batch")
        self.fn_enc_sig = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_signal")
        self.fn_dec_sig = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_signal")
        self.fn_enc_sig_batch = self.lib._handle.get_function[FnEncBatch]("kiln_asm_encode_bench_signal_batch")
        self.fn_dec_sig_batch = self.lib._handle.get_function[FnDecBatch]("kiln_asm_decode_bench_signal_batch")
        self.fn_enc_req = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_bench_request")
        self.fn_dec_req = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_bench_request")
        self.fn_enc_tensors = self.lib._handle.get_function[FnEncOne]("kiln_asm_encode_tensors")
        self.fn_dec_tensors = self.lib._handle.get_function[FnDecOne]("kiln_asm_decode_tensors")

        self.arena_buf = List[UInt8](unsafe_uninit_length=131072)
        self.arena_hdr = List[UInt64](length=3, fill=0)
        self.res_buf = List[UInt64](length=2, fill=0)
        self.pair_buf = List[UInt64](length=2, fill=0)
        self.opts_large = List[KilnReadOpts](capacity=1)
        var lo = KilnReadOpts()
        lo.max_count = UInt64(1) << 28
        lo.max_bytes = UInt64(1) << 28
        self.opts_large.append(lo)
        self.opts_emb = List[KilnReadOpts](capacity=1)
        var eo = KilnReadOpts()
        eo.flags = KILN_OPT_EMBEDDED
        self.opts_emb.append(eo)
        self.dec_scratch = List[UInt8](length=512, fill=0)
        self.enc_dir = List[KilnTensorDir](capacity=1)
        self.enc_dir.append(KilnTensorDir())
        self.enc_req = List[BenchRequest](capacity=1)
        self.enc_req.append(BenchRequest())
        self.enc_msg = List[BenchMessage]()
        self.enc_doc = List[BenchDocument]()
        self.enc_doc_items = List[BenchDocItem]()
        self.enc_tel = List[BenchTelemetry]()
        self.enc_str_items = List[KilnStr]()
        self.enc_strs = List[BenchStrings]()
        self.enc_ev = List[BenchEvent]()
        self.enc_ev_attrs = List[BenchEventAttr]()
        self.enc_sig = List[BenchSignal]()
        self.enc_sig_legs = List[BenchSignalLeg]()
        self.enc_f64 = List[Float64]()
        self.enc_i64 = List[Int64]()
        self.enc_col_str = List[KilnStr]()
        self.enc_tc = List[KilnList](capacity=22)
        var i = 0
        while i < 22:
            self.enc_tc.append(KilnList())
            i += 1
        self.enc_tensors = List[KilnTensor](capacity=4)
        i = 0
        while i < 4:
            self.enc_tensors.append(KilnTensor())
            i += 1

    def name(self) -> String:
        return "gld-kiln-asm"

    def supports(self, type_id: String) -> Bool:
        if type_id == "message" or type_id == "document" or type_id == "telemetry":
            return True
        if type_id == "strings" or type_id == "event":
            return True
        if type_id == "table" or type_id == "table_project" or type_id == "nested_table" or type_id == "signal":
            return True
        if type_id == "grid" or type_id == "grid_window":
            return True
        if type_id == "tensor" or type_id == "tensor_view" or type_id == "prompt" or type_id == "shard" or type_id == "request":
            return True
        return False

    def _ensure_arena_p(mut self, need: Int) -> UInt64:
        if len(self.arena_buf) < need:
            self.arena_buf = List[UInt8](unsafe_uninit_length=need)
        var base = UInt64(Int(self.arena_buf.unsafe_ptr()))
        self.arena_hdr[0] = base
        self.arena_hdr[1] = base
        self.arena_hdr[2] = base + UInt64(len(self.arena_buf))
        return UInt64(Int(self.arena_hdr.unsafe_ptr()))

    def _wire_cap(self, fx: Fixture) -> Int:
        var tid = fx.type_id
        var n = fx.n
        if tid == "message":
            return n * 256 + 1024
        if tid == "document":
            var items = 0
            for i in range(len(fx.documents)):
                items += len(fx.documents[i].items)
            return n * 128 + items * 64 + 1024
        if tid == "telemetry":
            var tags = 0
            var vals = 0
            for i in range(len(fx.telemetries)):
                tags += len(fx.telemetries[i].tags)
                vals += len(fx.telemetries[i].values)
            return n * 128 + tags * 48 + vals * 8 + 1024
        if tid == "strings":
            var items = 0
            for i in range(len(fx.strings)):
                items += len(fx.strings[i].items)
            return n * 16 + items * 48 + 1024
        if tid == "event":
            var attrs = 0
            for i in range(len(fx.events)):
                attrs += len(fx.events[i].attrs)
            return n * 192 + attrs * 96 + 1024
        if tid == "table" or tid == "table_project":
            return len(fx.tables) * 280 + 4096
        if tid == "nested_table":
            var items = 0
            for i in range(len(fx.nested_rows)):
                items += len(fx.nested_rows[i].items)
            return n * 128 + items * 64 + 1024
        if tid == "signal":
            var legs = 0
            for i in range(len(fx.signals)):
                legs += len(fx.signals[i].legs)
            return n * 160 + legs * 16 + 1024
        if tid == "grid" or tid == "grid_window":
            return len(fx.grids[0].values) * 8 + 1024
        if tid == "tensor" or tid == "tensor_view":
            return len(fx.tensors[0].values) * 4 + 1024
        if tid == "prompt":
            return len(fx.prompts[0].input_ids) * 24 + 2048
        if tid == "shard":
            ref s = fx.shards[0]
            return (len(s.tok_emb) + len(s.attn) + len(s.ffn_weight) + len(s.norm)) * 4 + 2048
        if tid == "request":
            return len(fx.requests[0].inputs.input_ids) * 24 + fx.requests[0].model.byte_length() + 2048
        return 4096

    def serialize_bytes(mut self, fx: Fixture) raises -> List[UInt8]:
        var cap = self._wire_cap(fx)
        var out = List[UInt8](unsafe_uninit_length=cap)
        var dst = UInt64(Int(out.unsafe_ptr()))
        self.res_buf[0] = 0
        self.res_buf[1] = 0
        var res_p = UInt64(Int(self.res_buf.unsafe_ptr()))
        var large_p = UInt64(Int(self.opts_large.unsafe_ptr()))
        var err: UInt32
        var tid = fx.type_id

        if tid == "message":
            self.enc_msg.clear()
            for i in range(len(fx.messages)):
                self.enc_msg.append(_fill_msg(fx.messages[i]))
            if fx.n == 1:
                err = self.fn_enc_msg(UInt64(Int(self.enc_msg.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_msg_batch(UInt64(Int(self.enc_msg.unsafe_ptr())), len(self.enc_msg), dst, cap, 0, res_p)
        elif tid == "document":
            self.enc_doc.clear()
            self.enc_doc_items.clear()
            for i in range(len(fx.documents)):
                for j in range(len(fx.documents[i].items)):
                    var it = BenchDocItem()
                    it.sku = _kstr(fx.documents[i].items[j].sku)
                    it.qty = fx.documents[i].items[j].qty
                    it.price_minor = fx.documents[i].items[j].price_minor
                    self.enc_doc_items.append(it^)
            var base = UInt64(Int(self.enc_doc_items.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.documents)):
                var cnt = len(fx.documents[i].items)
                var bd = BenchDocument()
                bd.id = _kstr(fx.documents[i].id)
                bd.status = fx.documents[i].status
                bd.meta.region = _kstr(fx.documents[i].meta.region)
                bd.meta.version = fx.documents[i].meta.version
                bd.items.items = base + UInt64(off * 32) if cnt > 0 else UInt64(0)
                bd.items.count = UInt64(cnt)
                off += cnt
                self.enc_doc.append(bd^)
            if fx.n == 1:
                err = self.fn_enc_doc(UInt64(Int(self.enc_doc.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_doc_batch(UInt64(Int(self.enc_doc.unsafe_ptr())), len(self.enc_doc), dst, cap, 0, res_p)
        elif tid == "telemetry":
            self.enc_tel.clear()
            self.enc_str_items.clear()
            for i in range(len(fx.telemetries)):
                for j in range(len(fx.telemetries[i].tags)):
                    self.enc_str_items.append(_kstr(fx.telemetries[i].tags[j]))
            var base = UInt64(Int(self.enc_str_items.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.telemetries)):
                var nt = len(fx.telemetries[i].tags)
                var nv = len(fx.telemetries[i].values)
                var bt = BenchTelemetry()
                bt.source = _kstr(fx.telemetries[i].source)
                bt.ts = fx.telemetries[i].ts
                bt.tags.items = base + UInt64(off * 16) if nt > 0 else UInt64(0)
                bt.tags.count = UInt64(nt)
                bt.values.items = UInt64(Int(fx.telemetries[i].values.unsafe_ptr())) if nv > 0 else UInt64(0)
                bt.values.count = UInt64(nv)
                off += nt
                self.enc_tel.append(bt^)
            if fx.n == 1:
                err = self.fn_enc_tel(UInt64(Int(self.enc_tel.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_tel_batch(UInt64(Int(self.enc_tel.unsafe_ptr())), len(self.enc_tel), dst, cap, 0, res_p)
        elif tid == "strings":
            self.enc_strs.clear()
            self.enc_str_items.clear()
            for i in range(len(fx.strings)):
                for j in range(len(fx.strings[i].items)):
                    self.enc_str_items.append(_kstr(fx.strings[i].items[j]))
            var base = UInt64(Int(self.enc_str_items.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.strings)):
                var cnt = len(fx.strings[i].items)
                var bs = BenchStrings()
                bs.items.items = base + UInt64(off * 16) if cnt > 0 else UInt64(0)
                bs.items.count = UInt64(cnt)
                off += cnt
                self.enc_strs.append(bs^)
            if fx.n == 1:
                err = self.fn_enc_strs(UInt64(Int(self.enc_strs.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_strs_batch(UInt64(Int(self.enc_strs.unsafe_ptr())), len(self.enc_strs), dst, cap, 0, res_p)
        elif tid == "event":
            self.enc_ev.clear()
            self.enc_ev_attrs.clear()
            for i in range(len(fx.events)):
                for j in range(len(fx.events[i].attrs)):
                    var a = BenchEventAttr()
                    a.key = _kstr(fx.events[i].attrs[j].key)
                    a.value = _kstr(fx.events[i].attrs[j].value)
                    self.enc_ev_attrs.append(a^)
            var base = UInt64(Int(self.enc_ev_attrs.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.events)):
                var cnt = len(fx.events[i].attrs)
                var be = BenchEvent()
                be.event_id = _kstr(fx.events[i].event_id)
                be.event_type = _kstr(fx.events[i].event_type)
                be.occurred_at = fx.events[i].occurred_at
                be.producer = _kstr(fx.events[i].producer)
                be.attrs.items = base + UInt64(off * 32) if cnt > 0 else UInt64(0)
                be.attrs.count = UInt64(cnt)
                off += cnt
                self.enc_ev.append(be^)
            if fx.n == 1:
                err = self.fn_enc_ev(UInt64(Int(self.enc_ev.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_ev_batch(UInt64(Int(self.enc_ev.unsafe_ptr())), len(self.enc_ev), dst, cap, 0, res_p)
        elif tid == "table" or tid == "table_project":
            var n = len(fx.tables)
            if len(self.enc_f64) < 16 * n:
                self.enc_f64 = List[Float64](unsafe_uninit_length=16 * n)
            if len(self.enc_i64) < 4 * n:
                self.enc_i64 = List[Int64](unsafe_uninit_length=4 * n)
            if len(self.enc_col_str) < 2 * n:
                self.enc_col_str = List[KilnStr](capacity=2 * n)
                for _ in range(2 * n):
                    self.enc_col_str.append(KilnStr())
            for r in range(n):
                ref row = fx.tables[r]
                for c in range(16):
                    self.enc_f64[c * n + r] = row.floats[c]
                for c in range(4):
                    self.enc_i64[c * n + r] = row.ints[c]
                self.enc_col_str[r] = _kstr(row.strs[0])
                self.enc_col_str[n + r] = _kstr(row.strs[1])
            var fb = UInt64(Int(self.enc_f64.unsafe_ptr()))
            var ib = UInt64(Int(self.enc_i64.unsafe_ptr()))
            var sb = UInt64(Int(self.enc_col_str.unsafe_ptr()))
            for c in range(16):
                self.enc_tc[c].items = fb + UInt64(c * n * 8) if n > 0 else UInt64(0)
                self.enc_tc[c].count = UInt64(n)
            for c in range(4):
                self.enc_tc[16 + c].items = ib + UInt64(c * n * 8) if n > 0 else UInt64(0)
                self.enc_tc[16 + c].count = UInt64(n)
            self.enc_tc[20].items = sb if n > 0 else UInt64(0)
            self.enc_tc[20].count = UInt64(n)
            self.enc_tc[21].items = sb + UInt64(n * 16) if n > 0 else UInt64(0)
            self.enc_tc[21].count = UInt64(n)
            err = self.fn_enc_tc(UInt64(Int(self.enc_tc.unsafe_ptr())), dst, cap, 0, res_p)
        elif tid == "nested_table":
            self.enc_doc.clear()
            self.enc_doc_items.clear()
            for i in range(len(fx.nested_rows)):
                for j in range(len(fx.nested_rows[i].items)):
                    var it = BenchDocItem()
                    it.sku = _kstr(fx.nested_rows[i].items[j].sku)
                    it.qty = fx.nested_rows[i].items[j].qty
                    it.price_minor = fx.nested_rows[i].items[j].price_minor
                    self.enc_doc_items.append(it^)
            var base = UInt64(Int(self.enc_doc_items.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.nested_rows)):
                var cnt = len(fx.nested_rows[i].items)
                var bd = BenchDocument()
                bd.id = _kstr(fx.nested_rows[i].id)
                bd.status = fx.nested_rows[i].status
                bd.meta.region = _kstr(fx.nested_rows[i].meta.region)
                bd.meta.version = fx.nested_rows[i].meta.version
                bd.items.items = base + UInt64(off * 32) if cnt > 0 else UInt64(0)
                bd.items.count = UInt64(cnt)
                off += cnt
                self.enc_doc.append(bd^)
            if fx.n == 1:
                err = self.fn_enc_nr(UInt64(Int(self.enc_doc.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_nr_batch(UInt64(Int(self.enc_doc.unsafe_ptr())), len(self.enc_doc), dst, cap, 0, res_p)
        elif tid == "signal":
            self.enc_sig.clear()
            self.enc_sig_legs.clear()
            for i in range(len(fx.signals)):
                for j in range(len(fx.signals[i].legs)):
                    var lg = BenchSignalLeg()
                    lg.leg_id = fx.signals[i].legs[j].leg_id
                    lg.leg_qty = fx.signals[i].legs[j].leg_qty
                    lg.leg_pad = fx.signals[i].legs[j].leg_pad
                    self.enc_sig_legs.append(lg^)
            var base = UInt64(Int(self.enc_sig_legs.unsafe_ptr()))
            var off = 0
            for i in range(len(fx.signals)):
                var cnt = len(fx.signals[i].legs)
                var bs = BenchSignal()
                bs.seq = fx.signals[i].seq
                bs.ts = fx.signals[i].ts
                bs.price_mantissa = fx.signals[i].price_mantissa
                bs.qty = fx.signals[i].qty
                bs.flags = fx.signals[i].flags
                bs.symbol = _kstr(fx.signals[i].symbol)
                bs.venue = _kstr(fx.signals[i].venue)
                bs.legs.items = base + UInt64(off * 16) if cnt > 0 else UInt64(0)
                bs.legs.count = UInt64(cnt)
                off += cnt
                self.enc_sig.append(bs^)
            if fx.n == 1:
                err = self.fn_enc_sig(UInt64(Int(self.enc_sig.unsafe_ptr())), dst, cap, 0, res_p)
            else:
                err = self.fn_enc_sig_batch(UInt64(Int(self.enc_sig.unsafe_ptr())), len(self.enc_sig), dst, cap, 0, res_p)
        elif tid == "grid" or tid == "grid_window":
            ref g = fx.grids[0]
            self.enc_tensors[0] = _set_tensor_2d(
                KILN_DTYPE_F64, UInt64(g.ny), UInt64(g.nx),
                UInt64(Int(g.values.unsafe_ptr())), UInt64(len(g.values) * 8),
            )
            self.enc_dir[0] = KilnTensorDir()
            self.enc_dir[0].items = UInt64(Int(self.enc_tensors.unsafe_ptr()))
            self.enc_dir[0].count = 1
            err = self.fn_enc_tensors(UInt64(Int(self.enc_dir.unsafe_ptr())), dst, cap, large_p, res_p)
        elif tid == "tensor" or tid == "tensor_view":
            ref tm = fx.tensors[0]
            self.enc_tensors[0] = _set_tensor_2d(
                KILN_DTYPE_F32, UInt64(tm.rows), UInt64(tm.cols),
                UInt64(Int(tm.values.unsafe_ptr())), UInt64(len(tm.values) * 4),
            )
            self.enc_dir[0] = KilnTensorDir()
            self.enc_dir[0].items = UInt64(Int(self.enc_tensors.unsafe_ptr()))
            self.enc_dir[0].count = 1
            err = self.fn_enc_tensors(UInt64(Int(self.enc_dir.unsafe_ptr())), dst, cap, large_p, res_p)
        elif tid == "prompt":
            ref p = fx.prompts[0]
            var b = UInt64(p.batch)
            var s = UInt64(p.seq)
            var nb = UInt64(len(p.input_ids) * 8)
            self.enc_tensors[0] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.input_ids.unsafe_ptr())), nb)
            self.enc_tensors[1] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.attention_mask.unsafe_ptr())), nb)
            self.enc_tensors[2] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.position_ids.unsafe_ptr())), nb)
            self.enc_dir[0] = KilnTensorDir()
            self.enc_dir[0].items = UInt64(Int(self.enc_tensors.unsafe_ptr()))
            self.enc_dir[0].count = 3
            err = self.fn_enc_tensors(UInt64(Int(self.enc_dir.unsafe_ptr())), dst, cap, large_p, res_p)
        elif tid == "shard":
            ref sh = fx.shards[0]
            self.enc_tensors[0] = _set_tensor_2d(KILN_DTYPE_F32, UInt64(sh.vocab), UInt64(sh.hidden), UInt64(Int(sh.tok_emb.unsafe_ptr())), UInt64(len(sh.tok_emb) * 4))
            self.enc_tensors[1] = _set_tensor_2d(KILN_DTYPE_F32, UInt64(sh.hidden), UInt64(sh.hidden), UInt64(Int(sh.attn.unsafe_ptr())), UInt64(len(sh.attn) * 4))
            self.enc_tensors[2] = _set_tensor_2d(KILN_DTYPE_F32, UInt64(sh.ffn), UInt64(sh.hidden), UInt64(Int(sh.ffn_weight.unsafe_ptr())), UInt64(len(sh.ffn_weight) * 4))
            self.enc_tensors[3] = _set_tensor_1d(KILN_DTYPE_F32, UInt64(sh.hidden), UInt64(Int(sh.norm.unsafe_ptr())), UInt64(len(sh.norm) * 4))
            self.enc_dir[0] = KilnTensorDir()
            self.enc_dir[0].items = UInt64(Int(self.enc_tensors.unsafe_ptr()))
            self.enc_dir[0].count = 4
            err = self.fn_enc_tensors(UInt64(Int(self.enc_dir.unsafe_ptr())), dst, cap, large_p, res_p)
        elif tid == "request":
            ref q = fx.requests[0]
            ref p = q.inputs
            var b = UInt64(p.batch)
            var s = UInt64(p.seq)
            var nb = UInt64(len(p.input_ids) * 8)
            self.enc_tensors[0] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.input_ids.unsafe_ptr())), nb)
            self.enc_tensors[1] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.attention_mask.unsafe_ptr())), nb)
            self.enc_tensors[2] = _set_tensor_2d(KILN_DTYPE_I64, b, s, UInt64(Int(p.position_ids.unsafe_ptr())), nb)
            var rq = BenchRequest()
            rq.request_id = q.request_id
            rq.model = _kstr(q.model)
            rq.temperature = q.temperature
            rq.inputs.items = UInt64(Int(self.enc_tensors.unsafe_ptr()))
            rq.inputs.count = 3
            self.enc_req[0] = rq
            err = self.fn_enc_req(UInt64(Int(self.enc_req.unsafe_ptr())), dst, cap, large_p, res_p)
        else:
            raise Error("gld-kiln-asm: unsupported " + tid)

        keep(out)
        if err != KILN_OK:
            raise Error("gld-kiln-asm encode failed: err=" + String(err))
        out.shrink(Int(self.res_buf[0]))
        return out^

    def deserialize_bytes(mut self, fx: Fixture, data: List[UInt8]) raises -> Fixture:
        var out = Fixture.empty(fx.type_id, fx.n, fx.hash)
        var tid = fx.type_id
        var src = UInt64(Int(data.unsafe_ptr()))
        var slen = len(data)
        var arena_need = 131072
        if tid == "table":
            arena_need = fx.n * 48 + 65536
        elif tid == "strings":
            arena_need = fx.n * 2048 + 65536
        elif tid == "document" or tid == "nested_table" or tid == "event":
            arena_need = fx.n * 1024 + 65536
        var arena_p = self._ensure_arena_p(arena_need)
        self.res_buf[0] = 0
        self.res_buf[1] = 0
        var res_p = UInt64(Int(self.res_buf.unsafe_ptr()))
        var large_p = UInt64(Int(self.opts_large.unsafe_ptr()))
        var scratch_p = UInt64(Int(self.dec_scratch.unsafe_ptr()))
        var pair_ptr_p = UInt64(Int(self.pair_buf.unsafe_ptr()))
        var pair_cnt_p = pair_ptr_p + 8

        if tid == "message":
            if fx.n == 1:
                if self.fn_dec_msg(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode message failed")
                var bm = Pointer[BenchMessage, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[Message](capacity=1)
                one.append(_read_msg(bm))
                out.messages = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_msg_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode message batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchMessage, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ms = List[Message](capacity=cnt)
                for i in range(cnt):
                    ms.append(_read_msg(p.unsafe_offset(i)[]))
                out.messages = ms^
        elif tid == "document":
            if fx.n == 1:
                if self.fn_dec_doc(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode document failed")
                var bd = Pointer[BenchDocument, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[Document](capacity=1)
                one.append(_read_doc(bd))
                out.documents = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_doc_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode document batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchDocument, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ds = List[Document](capacity=cnt)
                for i in range(cnt):
                    ds.append(_read_doc(p.unsafe_offset(i)[]))
                out.documents = ds^
        elif tid == "telemetry":
            if fx.n == 1:
                if self.fn_dec_tel(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode telemetry failed")
                var bt = Pointer[BenchTelemetry, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[Telemetry](capacity=1)
                one.append(_read_tel(bt))
                out.telemetries = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_tel_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode telemetry batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchTelemetry, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ts = List[Telemetry](capacity=cnt)
                for i in range(cnt):
                    ts.append(_read_tel(p.unsafe_offset(i)[]))
                out.telemetries = ts^
        elif tid == "strings":
            if fx.n == 1:
                if self.fn_dec_strs(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode strings failed")
                var bs = Pointer[BenchStrings, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[Strings](capacity=1)
                one.append(_read_strs(bs))
                out.strings = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_strs_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode strings batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchStrings, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ss = List[Strings](capacity=cnt)
                for i in range(cnt):
                    ss.append(_read_strs(p.unsafe_offset(i)[]))
                out.strings = ss^
        elif tid == "event":
            if fx.n == 1:
                if self.fn_dec_ev(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode event failed")
                var be = Pointer[BenchEvent, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[Event](capacity=1)
                one.append(_read_ev(be))
                out.events = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_ev_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode event batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchEvent, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var es = List[Event](capacity=cnt)
                for i in range(cnt):
                    es.append(_read_ev(p.unsafe_offset(i)[]))
                out.events = es^
        elif tid == "table_project":
            var emb_p = UInt64(Int(self.opts_emb.unsafe_ptr()))
            if self.fn_dec_tp(src, slen, scratch_p, arena_p, emb_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode table_project failed")
            var tp = Pointer[BenchTableProject, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            out.projected = _copy_f64_raw(tp.f_float_0.items, Int(tp.f_float_0.count))
        elif tid == "table":
            if self.fn_dec_tc(src, slen, UInt64(Int(self.enc_tc.unsafe_ptr())), arena_p, 0, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode table failed")
            var n = Int(self.enc_tc[0].count)
            var s0p = Pointer[KilnStr, ImmutAnyOrigin](unsafe_from_address=Int(self.enc_tc[20].items))
            var s1p = Pointer[KilnStr, ImmutAnyOrigin](unsafe_from_address=Int(self.enc_tc[21].items))
            var rows = List[TableRow](capacity=n)
            for r in range(n):
                var fs = List[Float64](unsafe_uninit_length=16)
                for c in range(16):
                    var fp = Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(self.enc_tc[c].items) + r * 8)
                    unsafe_memcpy(dest=fs.unsafe_ptr().unsafe_offset(c).unsafe_bitcast[UInt8](), src=fp, count=8)
                var ivs = List[Int64](unsafe_uninit_length=4)
                for c in range(4):
                    var ip = Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(self.enc_tc[16 + c].items) + r * 8)
                    unsafe_memcpy(dest=ivs.unsafe_ptr().unsafe_offset(c).unsafe_bitcast[UInt8](), src=ip, count=8)
                var ss = List[String](capacity=2)
                ss.append(_from_kstr(s0p.unsafe_offset(r)[]))
                ss.append(_from_kstr(s1p.unsafe_offset(r)[]))
                rows.append(TableRow(fs^, ivs^, ss^))
            out.tables = rows^
        elif tid == "nested_table":
            if fx.n == 1:
                if self.fn_dec_nr(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode nested_table failed")
                var bd = Pointer[BenchDocument, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[NestedRow](capacity=1)
                one.append(_read_nested(bd))
                out.nested_rows = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_nr_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode nested_table batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchDocument, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ds = List[NestedRow](capacity=cnt)
                for i in range(cnt):
                    ds.append(_read_nested(p.unsafe_offset(i)[]))
                out.nested_rows = ds^
        elif tid == "signal":
            if fx.n == 1:
                if self.fn_dec_sig(src, slen, scratch_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode signal failed")
                var bs = Pointer[BenchSignal, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
                var one = List[SignalRow](capacity=1)
                one.append(_read_sig(bs))
                out.signals = one^
            else:
                self.pair_buf[0] = 0
                self.pair_buf[1] = 0
                if self.fn_dec_sig_batch(src, slen, pair_ptr_p, pair_cnt_p, arena_p, 0, res_p) != KILN_OK:
                    raise Error("gld-kiln-asm decode signal batch failed")
                var cnt = Int(self.pair_buf[1])
                var p = Pointer[BenchSignal, ImmutAnyOrigin](unsafe_from_address=Int(self.pair_buf[0]))
                var ss = List[SignalRow](capacity=cnt)
                for i in range(cnt):
                    ss.append(_read_sig(p.unsafe_offset(i)[]))
                out.signals = ss^
        elif tid == "grid" or tid == "grid_window":
            if self.fn_dec_tensors(src, slen, scratch_p, arena_p, large_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode grid failed")
            var dir = Pointer[KilnTensorDir, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            if dir.count != 1 or dir.items == 0:
                raise Error("gld-kiln-asm invalid grid dir")
            var kt = Pointer[KilnTensor, ImmutAnyOrigin](unsafe_from_address=Int(dir.items))[]
            var ny = Int(kt.s0)
            var nx = Int(kt.s1)
            var one = List[Grid](capacity=1)
            if tid == "grid_window":
                ref g = fx.grids[0]
                var nread = g.wx * g.wy
                var vals = List[Float64](unsafe_uninit_length=nread)
                var row_bytes = g.wx * 8
                for r in range(g.wy):
                    var src_off = ((g.y0 + r) * nx + g.x0) * 8
                    unsafe_memcpy(
                        dest=vals.unsafe_ptr().unsafe_offset(r * g.wx).unsafe_bitcast[UInt8](),
                        src=Pointer[UInt8, ImmutAnyOrigin](unsafe_from_address=Int(kt.data) + src_off),
                        count=row_bytes,
                    )
                one.append(Grid(g.wx, g.wy, vals^, 0, 0, 0, 0))
            else:
                var vals = _copy_f64_raw(kt.data, nx * ny)
                one.append(Grid(nx, ny, vals^, 0, 0, 0, 0))
            out.grids = one^
        elif tid == "tensor" or tid == "tensor_view":
            if self.fn_dec_tensors(src, slen, scratch_p, arena_p, large_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode tensor failed")
            var dir = Pointer[KilnTensorDir, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            if dir.count != 1 or dir.items == 0:
                raise Error("gld-kiln-asm invalid tensor dir")
            var kt = Pointer[KilnTensor, ImmutAnyOrigin](unsafe_from_address=Int(dir.items))[]
            var rows = Int32(kt.s0)
            var cols = Int32(kt.s1)
            var nbytes = Int(kt.data_len)
            if tid == "tensor_view":
                var b0 = Int(src)
                var b1 = b0 + slen
                var p0 = Int(kt.data)
                if nbytes > 0 and (p0 < b0 or p0 > b1 or nbytes > b1 - p0):
                    raise Error("gld-kiln-asm tensor_view out of range")
                out.view_ok = True
                out.view_addr = p0
                out.view_nbytes = nbytes
            else:
                var vals = _copy_f32_raw(kt.data, nbytes // 4)
                var one = List[TensorValue](capacity=1)
                one.append(TensorValue(rows, cols, vals^))
                out.tensors = one^
        elif tid == "prompt":
            if self.fn_dec_tensors(src, slen, scratch_p, arena_p, large_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode prompt failed")
            var dir = Pointer[KilnTensorDir, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            var one = List[PromptValue](capacity=1)
            one.append(_read_prompt_dir(dir))
            out.prompts = one^
        elif tid == "shard":
            if self.fn_dec_tensors(src, slen, scratch_p, arena_p, large_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode shard failed")
            var dir = Pointer[KilnTensorDir, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            if dir.count != 4 or dir.items == 0:
                raise Error("gld-kiln-asm invalid shard dir")
            var tp = Pointer[KilnTensor, ImmutAnyOrigin](unsafe_from_address=Int(dir.items))
            var t0 = tp.unsafe_offset(0)[]
            var t1 = tp.unsafe_offset(1)[]
            var t2 = tp.unsafe_offset(2)[]
            var t3 = tp.unsafe_offset(3)[]
            var one = List[ShardValue](capacity=1)
            one.append(
                ShardValue(
                    Int32(t0.s0),
                    Int32(t0.s1),
                    Int32(t2.s0),
                    _copy_f32_raw(t0.data, Int(t0.data_len) // 4),
                    _copy_f32_raw(t1.data, Int(t1.data_len) // 4),
                    _copy_f32_raw(t2.data, Int(t2.data_len) // 4),
                    _copy_f32_raw(t3.data, Int(t3.data_len) // 4),
                )
            )
            out.shards = one^
        elif tid == "request":
            if self.fn_dec_req(src, slen, scratch_p, arena_p, large_p, res_p) != KILN_OK:
                raise Error("gld-kiln-asm decode request failed")
            var rq = Pointer[BenchRequest, ImmutAnyOrigin](unsafe_from_address=Int(scratch_p))[]
            var one = List[RequestValue](capacity=1)
            one.append(
                RequestValue(
                    rq.request_id,
                    _from_kstr(rq.model),
                    rq.temperature,
                    _read_prompt_dir(rq.inputs),
                )
            )
            out.requests = one^
        else:
            raise Error("gld-kiln-asm: unsupported " + tid)
        keep(data)
        return out^
