//! gld-kiln-asm: pure x86-64 Assembly Kiln Wire Format v2 codec linked via
//! shared `build/kiln-asm/libkiln_asm_bench.a` (Tier 1 zero-cost C ABI).
//!
//! Covers all 4 supported Data Sets: `suite`, `columnar`, `array`, and `tensor`.
//! Full RFC 3629 UTF-8 validation is always active (no `KILN_OPT_TRUSTED`).

use crate::data::{
    is_array_id, is_columnar_id, is_tensor_id, take_f32_buf, Document, DocumentItem, DocumentMeta,
    Event, EventAttr, F32Payload, Fixture, Grid, InferenceRequest, Message, NestedItem, NestedMeta,
    NestedRow, Prompt, Shard, Signal, SignalLeg, Strings, TableRow, Telemetry, TensorMatrix,
};
use crate::serializers::{BenchSerializer, NativeKind, StreamMode};
use anyhow::{bail, Result};
use std::ffi::CStr;
use std::io::Read;
use std::os::raw::c_char;

#[cfg(has_kiln_asm)]
mod ffi {
    use std::os::raw::c_char;

    pub const KILN_OK: u32 = 0;
    pub const KILN_OPT_EMBEDDED: u32 = 1 << 3;
    pub const KILN_DTYPE_F64: u16 = 1;
    pub const KILN_DTYPE_F32: u16 = 2;
    pub const KILN_DTYPE_I64: u16 = 14;

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KilnArena {
        pub base: *mut u8,
        pub cur: *mut u8,
        pub end: *mut u8,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct KilnReadOpts {
        pub max_count: u64,
        pub max_bytes: u64,
        pub max_depth: u32,
        pub flags: u32,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct KilnResult {
        pub bytes: u64,
        pub hash: u64,
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KilnStr {
        pub ptr: *const u8,
        pub len: u64,
    }
    impl Default for KilnStr {
        fn default() -> Self {
            Self {
                ptr: std::ptr::null(),
                len: 0,
            }
        }
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KilnList<T> {
        pub items: *mut T,
        pub count: u64,
    }
    impl<T> Default for KilnList<T> {
        fn default() -> Self {
            Self {
                items: std::ptr::null_mut(),
                count: 0,
            }
        }
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KilnTensor {
        pub name: *const u8,
        pub name_len: u64,
        pub layout: *const u8,
        pub layout_len: u64,
        pub data: *const u8,
        pub data_len: u64,
        pub shape: [u64; 8],
        pub dtype: u16,
        pub rank: u8,
        pub _pad0: u8,
        pub quant_scheme: u16,
        pub quant_axis: u16,
        pub group_size: u32,
        pub scale_index: u32,
        pub outer_index: u32,
        pub block_size: u32,
        pub elem_count: u64,
    }
    impl Default for KilnTensor {
        fn default() -> Self {
            Self {
                name: std::ptr::null(),
                name_len: 0,
                layout: std::ptr::null(),
                layout_len: 0,
                data: std::ptr::null(),
                data_len: 0,
                shape: [0; 8],
                dtype: 0,
                rank: 0,
                _pad0: 0,
                quant_scheme: 0,
                quant_axis: 0xFFFF,
                group_size: 0,
                scale_index: 0xFFFF_FFFF,
                outer_index: 0xFFFF_FFFF,
                block_size: 0,
                elem_count: 0,
            }
        }
    }

    #[repr(C)]
    #[derive(Clone, Copy)]
    pub struct KilnTensorDir {
        pub items: *mut KilnTensor,
        pub count: u64,
        pub block_length: u64,
        pub flags: u32,
        pub version: u32,
    }
    impl Default for KilnTensorDir {
        fn default() -> Self {
            Self {
                items: std::ptr::null_mut(),
                count: 0,
                block_length: 0,
                flags: 2,
                version: 2,
            }
        }
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchMessage {
        pub f_bool: u8,
        pub f_int32: i32,
        pub f_int64: i64,
        pub f_float64: f64,
        pub f_string: KilnStr,
        pub f_bool_2: u8,
        pub f_int32_2: i32,
        pub f_string_2: KilnStr,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchDocMeta {
        pub region: KilnStr,
        pub version: i32,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchDocItem {
        pub sku: KilnStr,
        pub qty: i32,
        pub price_minor: i64,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchDocument {
        pub id: KilnStr,
        pub status: i32,
        pub meta: BenchDocMeta,
        pub items: KilnList<BenchDocItem>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchTelemetry {
        pub source: KilnStr,
        pub ts: i64,
        pub tags: KilnList<KilnStr>,
        pub values: KilnList<f64>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchStrings {
        pub items: KilnList<KilnStr>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchEventAttr {
        pub key: KilnStr,
        pub value: KilnStr,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchEvent {
        pub event_id: KilnStr,
        pub event_type: KilnStr,
        pub occurred_at: i64,
        pub producer: KilnStr,
        pub attrs: KilnList<BenchEventAttr>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchTableColumns {
        pub f_float: [KilnList<f64>; 16],
        pub f_int: [KilnList<i64>; 4],
        pub f_str_0: KilnList<KilnStr>,
        pub f_str_1: KilnList<KilnStr>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchTableProject {
        pub f_float_0: KilnList<f64>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchSignalLeg {
        pub leg_id: i64,
        pub leg_qty: i32,
        pub leg_pad: i32,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchSignal {
        pub seq: i64,
        pub ts: i64,
        pub price_mantissa: i64,
        pub qty: i32,
        pub flags: i32,
        pub symbol: KilnStr,
        pub venue: KilnStr,
        pub legs: KilnList<BenchSignalLeg>,
    }

    #[repr(C)]
    #[derive(Clone, Copy, Default)]
    pub struct BenchRequest {
        pub request_id: i64,
        pub model: KilnStr,
        pub temperature: f32,
        pub inputs: KilnTensorDir,
    }

    // Compile-time ABI layout assertions matching build/kiln-asm/include/kiln_bench/*.h
    const _: () = {
        assert!(std::mem::size_of::<KilnTensor>() == 144);
        assert!(std::mem::size_of::<KilnTensorDir>() == 32);
        assert!(std::mem::size_of::<BenchMessage>() == 64);
        assert!(std::mem::size_of::<BenchDocMeta>() == 24);
        assert!(std::mem::size_of::<BenchDocItem>() == 32);
        assert!(std::mem::size_of::<BenchDocument>() == 64);
        assert!(std::mem::size_of::<BenchTelemetry>() == 56);
        assert!(std::mem::size_of::<BenchStrings>() == 16);
        assert!(std::mem::size_of::<BenchEventAttr>() == 32);
        assert!(std::mem::size_of::<BenchEvent>() == 72);
        assert!(std::mem::size_of::<BenchTableColumns>() == 352);
        assert!(std::mem::size_of::<BenchTableProject>() == 16);
        assert!(std::mem::size_of::<BenchSignalLeg>() == 16);
        assert!(std::mem::size_of::<BenchSignal>() == 80);
        assert!(std::mem::size_of::<BenchRequest>() == 64);
    };

    extern "C" {
        pub fn kiln_asm_version() -> *const c_char;
        pub fn kiln_asm_err_name(err: u32) -> *const c_char;

        pub fn kiln_asm_encode_bench_message(
            input: *const BenchMessage, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_message(
            src: *const u8, len: usize, out: *mut BenchMessage,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_message_batch(
            items: *const BenchMessage, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_message_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchMessage, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_document(
            input: *const BenchDocument, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_document(
            src: *const u8, len: usize, out: *mut BenchDocument,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_document_batch(
            items: *const BenchDocument, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_document_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchDocument, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_telemetry(
            input: *const BenchTelemetry, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_telemetry(
            src: *const u8, len: usize, out: *mut BenchTelemetry,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_telemetry_batch(
            items: *const BenchTelemetry, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_telemetry_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchTelemetry, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_strings(
            input: *const BenchStrings, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_strings(
            src: *const u8, len: usize, out: *mut BenchStrings,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_strings_batch(
            items: *const BenchStrings, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_strings_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchStrings, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_event(
            input: *const BenchEvent, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_event(
            src: *const u8, len: usize, out: *mut BenchEvent,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_event_batch(
            items: *const BenchEvent, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_event_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchEvent, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_table_columns(
            input: *const BenchTableColumns, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_table_columns(
            src: *const u8, len: usize, out: *mut BenchTableColumns,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_table_project(
            src: *const u8, len: usize, out: *mut BenchTableProject,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_nested_row(
            input: *const BenchDocument, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_nested_row(
            src: *const u8, len: usize, out: *mut BenchDocument,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_nested_row_batch(
            items: *const BenchDocument, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_nested_row_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchDocument, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_signal(
            input: *const BenchSignal, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_signal(
            src: *const u8, len: usize, out: *mut BenchSignal,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_encode_bench_signal_batch(
            items: *const BenchSignal, count: usize, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_signal_batch(
            src: *const u8, len: usize, out_items: *mut *mut BenchSignal, out_count: *mut usize,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_tensors(
            input: *const KilnTensorDir, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_tensors(
            src: *const u8, len: usize, out: *mut KilnTensorDir,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;

        pub fn kiln_asm_encode_bench_request(
            input: *const BenchRequest, dst: *mut u8, cap: usize,
            opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
        pub fn kiln_asm_decode_bench_request(
            src: *const u8, len: usize, out: *mut BenchRequest,
            arena: *mut KilnArena, opts: *const KilnReadOpts, res: *mut KilnResult,
        ) -> u32;
    }
}

#[cfg(has_kiln_asm)]
use ffi::*;

#[cfg(has_kiln_asm)]
const SUITE: &[&str] = &["message", "document", "telemetry", "strings", "event"];

#[cfg(has_kiln_asm)]
pub struct KilnAsmSer {
    kind: &'static str,
    batch: bool,
    wire_cap: usize,
    nx: usize,
    ny: usize,
    x0: usize,
    y0: usize,
    wx: usize,
    wy: usize,
    read_window: bool,
    arena_buf: Vec<u8>,
    enc_f64: Vec<f64>,
    enc_i64: Vec<i64>,
    enc_str: Vec<KilnStr>,
    enc_msg: Vec<BenchMessage>,
    enc_doc: Vec<BenchDocument>,
    enc_doc_items: Vec<BenchDocItem>,
    enc_tel: Vec<BenchTelemetry>,
    enc_strs: Vec<BenchStrings>,
    enc_ev: Vec<BenchEvent>,
    enc_ev_attrs: Vec<BenchEventAttr>,
    enc_sig: Vec<BenchSignal>,
    enc_sig_legs: Vec<BenchSignalLeg>,
}

// SAFETY: Scratch vectors hold transient raw pointers only during one synchronous
// serialize/deserialize call; nothing aliases across calls or threads.
#[cfg(has_kiln_asm)]
unsafe impl Send for KilnAsmSer {}

#[cfg(has_kiln_asm)]
impl Default for KilnAsmSer {
    fn default() -> Self {
        Self {
            kind: "message",
            batch: false,
            wire_cap: 4096,
            nx: 0,
            ny: 0,
            x0: 0,
            y0: 0,
            wx: 0,
            wy: 0,
            read_window: false,
            arena_buf: vec![0u8; 65536],
            enc_f64: Vec::new(),
            enc_i64: Vec::new(),
            enc_str: Vec::new(),
            enc_msg: Vec::new(),
            enc_doc: Vec::new(),
            enc_doc_items: Vec::new(),
            enc_tel: Vec::new(),
            enc_strs: Vec::new(),
            enc_ev: Vec::new(),
            enc_ev_attrs: Vec::new(),
            enc_sig: Vec::new(),
            enc_sig_legs: Vec::new(),
        }
    }
}

#[cfg(has_kiln_asm)]
#[inline]
fn kstr(s: &str) -> KilnStr {
    KilnStr {
        ptr: s.as_ptr(),
        len: s.len() as u64,
    }
}

#[cfg(has_kiln_asm)]
#[inline]
unsafe fn from_kstr(s: KilnStr) -> String {
    if s.len == 0 {
        return String::new();
    }
    let bytes = std::slice::from_raw_parts(s.ptr, s.len as usize);
    // ASM already validated RFC 3629 UTF-8 (FLAG_CHECK_UTF8 active).
    String::from_utf8_unchecked(bytes.to_vec())
}

#[cfg(has_kiln_asm)]
fn check_ok(err: u32, op: &str) -> Result<()> {
    if err == KILN_OK {
        return Ok(());
    }
    let name = unsafe {
        let p = kiln_asm_err_name(err);
        if p.is_null() {
            "UNKNOWN"
        } else {
            CStr::from_ptr(p).to_str().unwrap_or("UNKNOWN")
        }
    };
    bail!("gld-kiln-asm {op}: {name} ({err})")
}

#[cfg(has_kiln_asm)]
fn make_arena(buf: &mut [u8]) -> KilnArena {
    let base = buf.as_mut_ptr();
    KilnArena {
        base,
        cur: base,
        end: unsafe { base.add(buf.len()) },
    }
}

#[cfg(has_kiln_asm)]
fn set_tensor_2d(dtype: u16, d0: u64, d1: u64, data: *const u8, nbytes: usize) -> KilnTensor {
    let mut t = KilnTensor::default();
    t.dtype = dtype;
    t.rank = 2;
    t.shape[0] = d0;
    t.shape[1] = d1;
    t.data = data;
    t.data_len = nbytes as u64;
    t
}

#[cfg(has_kiln_asm)]
fn set_tensor_1d(dtype: u16, d0: u64, data: *const u8, nbytes: usize) -> KilnTensor {
    let mut t = KilnTensor::default();
    t.dtype = dtype;
    t.rank = 1;
    t.shape[0] = d0;
    t.data = data;
    t.data_len = nbytes as u64;
    t
}

#[cfg(has_kiln_asm)]
fn fill_prompt_tensors(p: &Prompt) -> [KilnTensor; 3] {
    let nbytes = p.input_ids.len() * 8;
    [
        set_tensor_2d(
            KILN_DTYPE_I64,
            p.batch as u64,
            p.seq as u64,
            p.input_ids.as_ptr().cast(),
            nbytes,
        ),
        set_tensor_2d(
            KILN_DTYPE_I64,
            p.batch as u64,
            p.seq as u64,
            p.attention_mask.as_ptr().cast(),
            nbytes,
        ),
        set_tensor_2d(
            KILN_DTYPE_I64,
            p.batch as u64,
            p.seq as u64,
            p.position_ids.as_ptr().cast(),
            nbytes,
        ),
    ]
}

#[cfg(has_kiln_asm)]
unsafe fn read_prompt_tensors(dir: &KilnTensorDir) -> Result<Prompt> {
    if dir.count != 3 || dir.items.is_null() {
        bail!("gld-kiln-asm: bad prompt tensor dir");
    }
    let items = std::slice::from_raw_parts(dir.items, 3);
    if items[0].dtype != KILN_DTYPE_I64 || items[0].rank != 2 {
        bail!("gld-kiln-asm: bad prompt tensor meta");
    }
    let batch = items[0].shape[0] as usize;
    let seq = items[0].shape[1] as usize;
    let n = batch * seq;
    let nbytes = n * 8;
    for t in items {
        if t.dtype != KILN_DTYPE_I64
            || t.rank != 2
            || t.shape[0] as usize != batch
            || t.shape[1] as usize != seq
            || t.data_len as usize != nbytes
        {
            bail!("gld-kiln-asm: prompt tensor shape mismatch");
        }
    }
    let mut ids = Vec::<i64>::with_capacity(n);
    let mut mask = Vec::<i64>::with_capacity(n);
    let mut pos = Vec::<i64>::with_capacity(n);
    if nbytes > 0 {
        std::ptr::copy_nonoverlapping(items[0].data, ids.as_mut_ptr().cast(), nbytes);
        std::ptr::copy_nonoverlapping(items[1].data, mask.as_mut_ptr().cast(), nbytes);
        std::ptr::copy_nonoverlapping(items[2].data, pos.as_mut_ptr().cast(), nbytes);
        ids.set_len(n);
        mask.set_len(n);
        pos.set_len(n);
    }
    Ok(Prompt {
        batch: batch as i32,
        seq: seq as i32,
        input_ids: ids,
        attention_mask: mask,
        position_ids: pos,
    })
}

#[cfg(has_kiln_asm)]
fn fill_msg(m: &Message) -> BenchMessage {
    BenchMessage {
        f_bool: u8::from(m.f_bool),
        f_int32: m.f_int32,
        f_int64: m.f_int64,
        f_float64: m.f_float64,
        f_string: kstr(&m.f_string),
        f_bool_2: u8::from(m.f_bool_2),
        f_int32_2: m.f_int32_2,
        f_string_2: kstr(&m.f_string_2),
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_msg(m: &BenchMessage) -> Message {
    Message {
        f_bool: m.f_bool != 0,
        f_int32: m.f_int32,
        f_int64: m.f_int64,
        f_float64: m.f_float64,
        f_string: from_kstr(m.f_string),
        f_bool_2: m.f_bool_2 != 0,
        f_int32_2: m.f_int32_2,
        f_string_2: from_kstr(m.f_string_2),
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_doc(d: &BenchDocument) -> Document {
    let n = d.items.count as usize;
    let slice = if n > 0 {
        std::slice::from_raw_parts(d.items.items, n)
    } else {
        &[]
    };
    let mut items = Vec::with_capacity(n);
    for it in slice {
        items.push(DocumentItem {
            sku: from_kstr(it.sku),
            qty: it.qty,
            price_minor: it.price_minor,
        });
    }
    Document {
        id: from_kstr(d.id),
        status: d.status,
        meta: DocumentMeta {
            region: from_kstr(d.meta.region),
            version: d.meta.version,
        },
        items,
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_nested(d: &BenchDocument) -> NestedRow {
    let n = d.items.count as usize;
    let slice = if n > 0 {
        std::slice::from_raw_parts(d.items.items, n)
    } else {
        &[]
    };
    let mut items = Vec::with_capacity(n);
    for it in slice {
        items.push(NestedItem {
            sku: from_kstr(it.sku),
            qty: it.qty,
            price_minor: it.price_minor,
        });
    }
    NestedRow {
        id: from_kstr(d.id),
        status: d.status,
        meta: NestedMeta {
            region: from_kstr(d.meta.region),
            version: d.meta.version,
        },
        items,
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_tel(t: &BenchTelemetry) -> Telemetry {
    let nt = t.tags.count as usize;
    let tag_slice = if nt > 0 {
        std::slice::from_raw_parts(t.tags.items, nt)
    } else {
        &[]
    };
    let mut tags = Vec::with_capacity(nt);
    for s in tag_slice {
        tags.push(from_kstr(*s));
    }
    let nv = t.values.count as usize;
    let mut values = Vec::<f64>::with_capacity(nv);
    if nv > 0 {
        std::ptr::copy_nonoverlapping(t.values.items.cast::<u8>(), values.as_mut_ptr().cast(), nv * 8);
        values.set_len(nv);
    }
    Telemetry {
        source: from_kstr(t.source),
        ts: t.ts,
        tags,
        values,
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_strs(s: &BenchStrings) -> Strings {
    let n = s.items.count as usize;
    let slice = if n > 0 {
        std::slice::from_raw_parts(s.items.items, n)
    } else {
        &[]
    };
    let mut items = Vec::with_capacity(n);
    for it in slice {
        items.push(from_kstr(*it));
    }
    Strings { items }
}

#[cfg(has_kiln_asm)]
unsafe fn read_ev(e: &BenchEvent) -> Event {
    let n = e.attrs.count as usize;
    let slice = if n > 0 {
        std::slice::from_raw_parts(e.attrs.items, n)
    } else {
        &[]
    };
    let mut attrs = Vec::with_capacity(n);
    for a in slice {
        attrs.push(EventAttr {
            key: from_kstr(a.key),
            value: from_kstr(a.value),
        });
    }
    Event {
        event_id: from_kstr(e.event_id),
        event_type: from_kstr(e.event_type),
        occurred_at: e.occurred_at,
        producer: from_kstr(e.producer),
        attrs,
    }
}

#[cfg(has_kiln_asm)]
unsafe fn read_signal(s: &BenchSignal) -> Signal {
    let n = s.legs.count as usize;
    let slice = if n > 0 {
        std::slice::from_raw_parts(s.legs.items, n)
    } else {
        &[]
    };
    let mut legs = Vec::with_capacity(n);
    for l in slice {
        legs.push(SignalLeg {
            leg_id: l.leg_id,
            leg_qty: l.leg_qty,
            leg_pad: l.leg_pad,
        });
    }
    Signal {
        seq: s.seq,
        ts: s.ts,
        price_mantissa: s.price_mantissa,
        qty: s.qty,
        flags: s.flags,
        symbol: from_kstr(s.symbol),
        venue: from_kstr(s.venue),
        legs,
    }
}

#[cfg(has_kiln_asm)]
fn as_table_row(fx: &Fixture) -> Result<&TableRow> {
    match fx {
        Fixture::Table(r) | Fixture::TableProject(r) => Ok(r),
        other => bail!("gld-kiln-asm: expected table row, got {}", other.name()),
    }
}

#[cfg(has_kiln_asm)]
const LARGE_OPTS: KilnReadOpts = KilnReadOpts {
    max_count: 1 << 28,
    max_bytes: 1 << 28,
    max_depth: 0,
    flags: 0,
};

#[cfg(has_kiln_asm)]
impl KilnAsmSer {
    fn encode_slice(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        out.clear();
        if out.capacity() < self.wire_cap {
            out.reserve(self.wire_cap);
        }
        let dst = out.as_mut_ptr();
        let cap = out.capacity();
        let mut res = KilnResult::default();
        let err = match self.kind {
            "message" => {
                if self.batch {
                    self.enc_msg.clear();
                    for fx in fixtures {
                        let Fixture::Message(m) = fx else {
                            bail!("gld-kiln-asm: expected message");
                        };
                        self.enc_msg.push(fill_msg(m));
                    }
                    unsafe {
                        kiln_asm_encode_bench_message_batch(
                            self.enc_msg.as_ptr(),
                            self.enc_msg.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    let Fixture::Message(m) = &fixtures[0] else {
                        bail!("gld-kiln-asm: expected message");
                    };
                    let bm = fill_msg(m);
                    unsafe {
                        kiln_asm_encode_bench_message(&bm, dst, cap, std::ptr::null(), &mut res)
                    }
                }
            }
            "document" => {
                self.enc_doc.clear();
                self.enc_doc_items.clear();
                for fx in fixtures {
                    let Fixture::Document(d) = fx else {
                        bail!("gld-kiln-asm: expected document");
                    };
                    for it in &d.items {
                        self.enc_doc_items.push(BenchDocItem {
                            sku: kstr(&it.sku),
                            qty: it.qty,
                            price_minor: it.price_minor,
                        });
                    }
                }
                let mut off = 0usize;
                let base = self.enc_doc_items.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::Document(d) = fx else { unreachable!() };
                    let cnt = d.items.len();
                    let ptr = if cnt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += cnt;
                    self.enc_doc.push(BenchDocument {
                        id: kstr(&d.id),
                        status: d.status,
                        meta: BenchDocMeta {
                            region: kstr(&d.meta.region),
                            version: d.meta.version,
                        },
                        items: KilnList {
                            items: ptr,
                            count: cnt as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_document_batch(
                            self.enc_doc.as_ptr(),
                            self.enc_doc.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_document(
                            &self.enc_doc[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "telemetry" => {
                self.enc_tel.clear();
                self.enc_str.clear();
                for fx in fixtures {
                    let Fixture::Telemetry(t) = fx else {
                        bail!("gld-kiln-asm: expected telemetry");
                    };
                    for tag in &t.tags {
                        self.enc_str.push(kstr(tag));
                    }
                }
                let mut off = 0usize;
                let base = self.enc_str.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::Telemetry(t) = fx else { unreachable!() };
                    let nt = t.tags.len();
                    let tptr = if nt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += nt;
                    let vptr = if !t.values.is_empty() {
                        t.values.as_ptr() as *mut f64
                    } else {
                        std::ptr::null_mut()
                    };
                    self.enc_tel.push(BenchTelemetry {
                        source: kstr(&t.source),
                        ts: t.ts,
                        tags: KilnList {
                            items: tptr,
                            count: nt as u64,
                        },
                        values: KilnList {
                            items: vptr,
                            count: t.values.len() as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_telemetry_batch(
                            self.enc_tel.as_ptr(),
                            self.enc_tel.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_telemetry(
                            &self.enc_tel[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "strings" => {
                self.enc_strs.clear();
                self.enc_str.clear();
                for fx in fixtures {
                    let Fixture::Strings(s) = fx else {
                        bail!("gld-kiln-asm: expected strings");
                    };
                    for it in &s.items {
                        self.enc_str.push(kstr(it));
                    }
                }
                let mut off = 0usize;
                let base = self.enc_str.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::Strings(s) = fx else { unreachable!() };
                    let cnt = s.items.len();
                    let ptr = if cnt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += cnt;
                    self.enc_strs.push(BenchStrings {
                        items: KilnList {
                            items: ptr,
                            count: cnt as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_strings_batch(
                            self.enc_strs.as_ptr(),
                            self.enc_strs.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_strings(
                            &self.enc_strs[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "event" => {
                self.enc_ev.clear();
                self.enc_ev_attrs.clear();
                for fx in fixtures {
                    let Fixture::Event(e) = fx else {
                        bail!("gld-kiln-asm: expected event");
                    };
                    for a in &e.attrs {
                        self.enc_ev_attrs.push(BenchEventAttr {
                            key: kstr(&a.key),
                            value: kstr(&a.value),
                        });
                    }
                }
                let mut off = 0usize;
                let base = self.enc_ev_attrs.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::Event(e) = fx else { unreachable!() };
                    let cnt = e.attrs.len();
                    let ptr = if cnt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += cnt;
                    self.enc_ev.push(BenchEvent {
                        event_id: kstr(&e.event_id),
                        event_type: kstr(&e.event_type),
                        occurred_at: e.occurred_at,
                        producer: kstr(&e.producer),
                        attrs: KilnList {
                            items: ptr,
                            count: cnt as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_event_batch(
                            self.enc_ev.as_ptr(),
                            self.enc_ev.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_event(
                            &self.enc_ev[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "table" | "table_project" => {
                let n = fixtures.len();
                self.enc_f64.resize(16 * n, 0.0);
                self.enc_i64.resize(4 * n, 0);
                self.enc_str.resize(2 * n, KilnStr::default());
                for (r, fx) in fixtures.iter().enumerate() {
                    let row = as_table_row(fx)?;
                    self.enc_f64[r] = row.f_float_0;
                    self.enc_f64[n + r] = row.f_float_1;
                    self.enc_f64[2 * n + r] = row.f_float_2;
                    self.enc_f64[3 * n + r] = row.f_float_3;
                    self.enc_f64[4 * n + r] = row.f_float_4;
                    self.enc_f64[5 * n + r] = row.f_float_5;
                    self.enc_f64[6 * n + r] = row.f_float_6;
                    self.enc_f64[7 * n + r] = row.f_float_7;
                    self.enc_f64[8 * n + r] = row.f_float_8;
                    self.enc_f64[9 * n + r] = row.f_float_9;
                    self.enc_f64[10 * n + r] = row.f_float_10;
                    self.enc_f64[11 * n + r] = row.f_float_11;
                    self.enc_f64[12 * n + r] = row.f_float_12;
                    self.enc_f64[13 * n + r] = row.f_float_13;
                    self.enc_f64[14 * n + r] = row.f_float_14;
                    self.enc_f64[15 * n + r] = row.f_float_15;
                    self.enc_i64[r] = row.f_int_0;
                    self.enc_i64[n + r] = row.f_int_1;
                    self.enc_i64[2 * n + r] = row.f_int_2;
                    self.enc_i64[3 * n + r] = row.f_int_3;
                    self.enc_str[r] = kstr(&row.f_str_0);
                    self.enc_str[n + r] = kstr(&row.f_str_1);
                }
                let mut tc = BenchTableColumns::default();
                let fbase = self.enc_f64.as_mut_ptr();
                let ibase = self.enc_i64.as_mut_ptr();
                let sbase = self.enc_str.as_mut_ptr();
                for c in 0..16 {
                    tc.f_float[c] = KilnList {
                        items: unsafe { fbase.add(c * n) },
                        count: n as u64,
                    };
                }
                for c in 0..4 {
                    tc.f_int[c] = KilnList {
                        items: unsafe { ibase.add(c * n) },
                        count: n as u64,
                    };
                }
                tc.f_str_0 = KilnList {
                    items: sbase,
                    count: n as u64,
                };
                tc.f_str_1 = KilnList {
                    items: unsafe { sbase.add(n) },
                    count: n as u64,
                };
                unsafe {
                    kiln_asm_encode_bench_table_columns(&tc, dst, cap, std::ptr::null(), &mut res)
                }
            }
            "nested_table" => {
                self.enc_doc.clear();
                self.enc_doc_items.clear();
                for fx in fixtures {
                    let Fixture::NestedTable(d) = fx else {
                        bail!("gld-kiln-asm: expected nested_table");
                    };
                    for it in &d.items {
                        self.enc_doc_items.push(BenchDocItem {
                            sku: kstr(&it.sku),
                            qty: it.qty,
                            price_minor: it.price_minor,
                        });
                    }
                }
                let mut off = 0usize;
                let base = self.enc_doc_items.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::NestedTable(d) = fx else { unreachable!() };
                    let cnt = d.items.len();
                    let ptr = if cnt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += cnt;
                    self.enc_doc.push(BenchDocument {
                        id: kstr(&d.id),
                        status: d.status,
                        meta: BenchDocMeta {
                            region: kstr(&d.meta.region),
                            version: d.meta.version,
                        },
                        items: KilnList {
                            items: ptr,
                            count: cnt as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_nested_row_batch(
                            self.enc_doc.as_ptr(),
                            self.enc_doc.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_nested_row(
                            &self.enc_doc[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "signal" => {
                self.enc_sig.clear();
                self.enc_sig_legs.clear();
                for fx in fixtures {
                    let Fixture::Signal(s) = fx else {
                        bail!("gld-kiln-asm: expected signal");
                    };
                    for l in &s.legs {
                        self.enc_sig_legs.push(BenchSignalLeg {
                            leg_id: l.leg_id,
                            leg_qty: l.leg_qty,
                            leg_pad: l.leg_pad,
                        });
                    }
                }
                let mut off = 0usize;
                let base = self.enc_sig_legs.as_mut_ptr();
                for fx in fixtures {
                    let Fixture::Signal(s) = fx else { unreachable!() };
                    let cnt = s.legs.len();
                    let ptr = if cnt > 0 {
                        unsafe { base.add(off) }
                    } else {
                        std::ptr::null_mut()
                    };
                    off += cnt;
                    self.enc_sig.push(BenchSignal {
                        seq: s.seq,
                        ts: s.ts,
                        price_mantissa: s.price_mantissa,
                        qty: s.qty,
                        flags: s.flags,
                        symbol: kstr(&s.symbol),
                        venue: kstr(&s.venue),
                        legs: KilnList {
                            items: ptr,
                            count: cnt as u64,
                        },
                    });
                }
                if self.batch {
                    unsafe {
                        kiln_asm_encode_bench_signal_batch(
                            self.enc_sig.as_ptr(),
                            self.enc_sig.len(),
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                } else {
                    unsafe {
                        kiln_asm_encode_bench_signal(
                            &self.enc_sig[0],
                            dst,
                            cap,
                            std::ptr::null(),
                            &mut res,
                        )
                    }
                }
            }
            "grid" | "grid_window" => {
                let Fixture::Grid(g) = &fixtures[0] else {
                    bail!("gld-kiln-asm: expected grid");
                };
                let mut t = set_tensor_2d(
                    KILN_DTYPE_F64,
                    g.ny as u64,
                    g.nx as u64,
                    g.values.as_ptr().cast(),
                    g.values.len() * 8,
                );
                let dir = KilnTensorDir {
                    items: &mut t,
                    count: 1,
                    block_length: 0,
                    flags: 2,
                    version: 2,
                };
                unsafe { kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &mut res) }
            }
            "tensor" | "tensor_view" => {
                let tm = match &fixtures[0] {
                    Fixture::Tensor(t) | Fixture::TensorView(t) => t,
                    _ => bail!("gld-kiln-asm: expected tensor"),
                };
                let F32Payload::Owned(vals) = &tm.values else {
                    bail!("gld-kiln-asm: expected owned tensor input");
                };
                let mut t = set_tensor_2d(
                    KILN_DTYPE_F32,
                    tm.rows as u64,
                    tm.cols as u64,
                    vals.as_ptr().cast(),
                    vals.len() * 4,
                );
                let dir = KilnTensorDir {
                    items: &mut t,
                    count: 1,
                    block_length: 0,
                    flags: 2,
                    version: 2,
                };
                unsafe { kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &mut res) }
            }
            "prompt" => {
                let Fixture::Prompt(p) = &fixtures[0] else {
                    bail!("gld-kiln-asm: expected prompt");
                };
                let mut ts = fill_prompt_tensors(p);
                let dir = KilnTensorDir {
                    items: ts.as_mut_ptr(),
                    count: 3,
                    block_length: 0,
                    flags: 2,
                    version: 2,
                };
                unsafe { kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &mut res) }
            }
            "shard" => {
                let Fixture::Shard(s) = &fixtures[0] else {
                    bail!("gld-kiln-asm: expected shard");
                };
                let mut ts = [
                    set_tensor_2d(
                        KILN_DTYPE_F32,
                        s.vocab as u64,
                        s.hidden as u64,
                        s.tok_emb.as_ptr().cast(),
                        s.tok_emb.len() * 4,
                    ),
                    set_tensor_2d(
                        KILN_DTYPE_F32,
                        s.hidden as u64,
                        s.hidden as u64,
                        s.attn.as_ptr().cast(),
                        s.attn.len() * 4,
                    ),
                    set_tensor_2d(
                        KILN_DTYPE_F32,
                        s.ffn as u64,
                        s.hidden as u64,
                        s.ffn_weight.as_ptr().cast(),
                        s.ffn_weight.len() * 4,
                    ),
                    set_tensor_1d(
                        KILN_DTYPE_F32,
                        s.hidden as u64,
                        s.norm.as_ptr().cast(),
                        s.norm.len() * 4,
                    ),
                ];
                let dir = KilnTensorDir {
                    items: ts.as_mut_ptr(),
                    count: 4,
                    block_length: 0,
                    flags: 2,
                    version: 2,
                };
                unsafe { kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &mut res) }
            }
            "request" => {
                let Fixture::Request(q) = &fixtures[0] else {
                    bail!("gld-kiln-asm: expected request");
                };
                let mut ts = fill_prompt_tensors(&q.inputs);
                let rq = BenchRequest {
                    request_id: q.request_id,
                    model: kstr(&q.model),
                    temperature: q.temperature,
                    inputs: KilnTensorDir {
                        items: ts.as_mut_ptr(),
                        count: 3,
                        block_length: 0,
                        flags: 2,
                        version: 2,
                    },
                };
                unsafe { kiln_asm_encode_bench_request(&rq, dst, cap, &LARGE_OPTS, &mut res) }
            }
            other => bail!("gld-kiln-asm: unsupported {other}"),
        };
        check_ok(err, "encode")?;
        unsafe { out.set_len(res.bytes as usize) };
        Ok(())
    }
}

#[cfg(has_kiln_asm)]
impl BenchSerializer for KilnAsmSer {
    fn name(&self) -> &'static str {
        "gld-kiln-asm"
    }

    fn version(&self) -> &'static str {
        unsafe {
            let p: *const c_char = kiln_asm_version();
            if p.is_null() {
                "0.2.0"
            } else {
                CStr::from_ptr(p).to_str().unwrap_or("0.2.0")
            }
        }
    }

    fn stream_mode(&self) -> StreamMode {
        StreamMode::Adapted
    }

    fn native_kind(&self) -> NativeKind {
        NativeKind::Direct
    }

    fn supports(&self, test_data_name: &str) -> bool {
        SUITE.contains(&test_data_name)
            || is_columnar_id(test_data_name)
            || is_array_id(test_data_name)
            || is_tensor_id(test_data_name)
    }

    fn one_cell_payload(&self) -> bool {
        self.batch || is_columnar_id(self.kind)
    }

    fn prepare(&mut self, fixture: &Fixture) -> Result<()> {
        self.prepare_many(std::slice::from_ref(fixture))
    }

    fn prepare_many(&mut self, fixtures: &[Fixture]) -> Result<()> {
        if fixtures.is_empty() {
            bail!("gld-kiln-asm: empty cell");
        }
        let kind = fixtures[0].name();
        if !self.supports(kind) {
            bail!("gld-kiln-asm: unsupported {kind}");
        }
        self.kind = kind;
        self.batch = fixtures.len() > 1;
        let n = fixtures.len();
        let wire_need: usize;
        let mut arena_need = 65536usize;
        match &fixtures[0] {
            Fixture::Message(_) => {
                wire_need = n * 256 + 1024;
                arena_need = n * 128 + 4096;
            }
            Fixture::Document(_) => {
                let items: usize = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::Document(d) => d.items.len(),
                        _ => 0,
                    })
                    .sum();
                wire_need = n * 128 + items * 64 + 1024;
                arena_need = n * 128 + items * 48 + 8192;
            }
            Fixture::Telemetry(_) => {
                let (tags, vals): (usize, usize) = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::Telemetry(t) => (t.tags.len(), t.values.len()),
                        _ => (0, 0),
                    })
                    .fold((0, 0), |a, b| (a.0 + b.0, a.1 + b.1));
                wire_need = n * 128 + tags * 48 + vals * 8 + 1024;
                arena_need = n * 128 + tags * 32 + 8192;
            }
            Fixture::Strings(_) => {
                let items: usize = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::Strings(s) => s.items.len(),
                        _ => 0,
                    })
                    .sum();
                wire_need = n * 16 + items * 48 + 1024;
                arena_need = n * 32 + items * 32 + 8192;
            }
            Fixture::Event(_) => {
                let attrs: usize = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::Event(e) => e.attrs.len(),
                        _ => 0,
                    })
                    .sum();
                wire_need = n * 192 + attrs * 96 + 1024;
                arena_need = n * 128 + attrs * 48 + 8192;
            }
            Fixture::Table(_) | Fixture::TableProject(_) => {
                wire_need = n * 260 + 4096;
                arena_need = n * 48 + 65536;
            }
            Fixture::NestedTable(_) => {
                let items: usize = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::NestedTable(d) => d.items.len(),
                        _ => 0,
                    })
                    .sum();
                wire_need = n * 128 + items * 64 + 1024;
                arena_need = n * 128 + items * 48 + 8192;
            }
            Fixture::Signal(_) => {
                let legs: usize = fixtures
                    .iter()
                    .map(|f| match f {
                        Fixture::Signal(s) => s.legs.len(),
                        _ => 0,
                    })
                    .sum();
                wire_need = n * 160 + legs * 16 + 1024;
                arena_need = n * 128 + legs * 32 + 8192;
            }
            Fixture::Grid(g) => {
                self.nx = g.nx as usize;
                self.ny = g.ny as usize;
                self.x0 = g.x0 as usize;
                self.y0 = g.y0 as usize;
                self.wx = g.wx as usize;
                self.wy = g.wy as usize;
                self.read_window = g.read_window;
                wire_need = g.values.len() * 8 + 1024;
            }
            Fixture::Tensor(t) | Fixture::TensorView(t) => {
                wire_need = t.values.len() * 4 + 1024;
            }
            Fixture::Prompt(p) => {
                wire_need = p.input_ids.len() * 24 + 2048;
            }
            Fixture::Shard(s) => {
                wire_need =
                    (s.tok_emb.len() + s.attn.len() + s.ffn_weight.len() + s.norm.len()) * 4 + 2048;
            }
            Fixture::Request(q) => {
                wire_need = q.inputs.input_ids.len() * 24 + q.model.len() + 2048;
            }
            _ => bail!("gld-kiln-asm: unsupported {kind}"),
        }
        self.wire_cap = wire_need;
        if self.arena_buf.len() < arena_need {
            self.arena_buf.resize(arena_need, 0);
        }
        Ok(())
    }

    fn serialize_into(&mut self, fixture: &Fixture, out: &mut Vec<u8>) -> Result<()> {
        match fixture {
            Fixture::Rows(rows) => self.encode_slice(rows, out),
            one => self.encode_slice(std::slice::from_ref(one), out),
        }
    }

    fn serialize_fixtures(&mut self, fixtures: &[Fixture], out: &mut Vec<u8>) -> Result<()> {
        self.encode_slice(fixtures, out)
    }

    fn deserialize_stream(&mut self, r: &mut dyn Read) -> Result<Fixture> {
        if self.kind == "tensor_view" {
            bail!("gld-kiln-asm: tensor_view borrows the bytes buffer");
        }
        let mut data = Vec::new();
        r.read_to_end(&mut data)?;
        self.deserialize_bytes(&data)
    }

    fn deserialize_bytes(&mut self, data: &[u8]) -> Result<Fixture> {
        let mut arena = make_arena(&mut self.arena_buf);
        let mut res = KilnResult::default();
        let src = data.as_ptr();
        let len = data.len();

        match self.kind {
            "message" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchMessage = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_message_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode message batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for m in slice {
                        out.push(Fixture::Message(read_msg(m)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut m = BenchMessage::default();
                    check_ok(
                        kiln_asm_decode_bench_message(
                            src, len, &mut m, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode message",
                    )?;
                    Ok(Fixture::Message(read_msg(&m)))
                }
            },
            "document" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchDocument = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_document_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode document batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for d in slice {
                        out.push(Fixture::Document(read_doc(d)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut d = BenchDocument::default();
                    check_ok(
                        kiln_asm_decode_bench_document(
                            src, len, &mut d, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode document",
                    )?;
                    Ok(Fixture::Document(read_doc(&d)))
                }
            },
            "telemetry" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchTelemetry = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_telemetry_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode telemetry batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for t in slice {
                        out.push(Fixture::Telemetry(read_tel(t)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut t = BenchTelemetry::default();
                    check_ok(
                        kiln_asm_decode_bench_telemetry(
                            src, len, &mut t, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode telemetry",
                    )?;
                    Ok(Fixture::Telemetry(read_tel(&t)))
                }
            },
            "strings" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchStrings = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_strings_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode strings batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for s in slice {
                        out.push(Fixture::Strings(read_strs(s)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut s = BenchStrings::default();
                    check_ok(
                        kiln_asm_decode_bench_strings(
                            src, len, &mut s, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode strings",
                    )?;
                    Ok(Fixture::Strings(read_strs(&s)))
                }
            },
            "event" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchEvent = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_event_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode event batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for e in slice {
                        out.push(Fixture::Event(read_ev(e)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut e = BenchEvent::default();
                    check_ok(
                        kiln_asm_decode_bench_event(
                            src, len, &mut e, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode event",
                    )?;
                    Ok(Fixture::Event(read_ev(&e)))
                }
            },
            "table" => unsafe {
                let mut tc = BenchTableColumns::default();
                check_ok(
                    kiln_asm_decode_bench_table_columns(
                        src, len, &mut tc, &mut arena, std::ptr::null(), &mut res,
                    ),
                    "decode table_columns",
                )?;
                let n = tc.f_float[0].count as usize;
                for c in 1..16 {
                    if tc.f_float[c].count as usize != n {
                        bail!("gld-kiln-asm: table float column length mismatch");
                    }
                }
                for c in 0..4 {
                    if tc.f_int[c].count as usize != n {
                        bail!("gld-kiln-asm: table int column length mismatch");
                    }
                }
                if tc.f_str_0.count as usize != n || tc.f_str_1.count as usize != n {
                    bail!("gld-kiln-asm: table string column length mismatch");
                }
                let rd_f64 = |col: usize, r: usize| -> f64 {
                    let p = tc.f_float[col].items.cast::<u8>().add(r * 8);
                    f64::from_le_bytes(std::ptr::read_unaligned(p.cast::<[u8; 8]>()))
                };
                let rd_i64 = |col: usize, r: usize| -> i64 {
                    let p = tc.f_int[col].items.cast::<u8>().add(r * 8);
                    i64::from_le_bytes(std::ptr::read_unaligned(p.cast::<[u8; 8]>()))
                };
                let s0 = std::slice::from_raw_parts(tc.f_str_0.items, n);
                let s1 = std::slice::from_raw_parts(tc.f_str_1.items, n);
                let mut rows = Vec::with_capacity(n);
                for r in 0..n {
                    rows.push(Fixture::Table(TableRow {
                        f_float_0: rd_f64(0, r),
                        f_float_1: rd_f64(1, r),
                        f_float_2: rd_f64(2, r),
                        f_float_3: rd_f64(3, r),
                        f_float_4: rd_f64(4, r),
                        f_float_5: rd_f64(5, r),
                        f_float_6: rd_f64(6, r),
                        f_float_7: rd_f64(7, r),
                        f_float_8: rd_f64(8, r),
                        f_float_9: rd_f64(9, r),
                        f_float_10: rd_f64(10, r),
                        f_float_11: rd_f64(11, r),
                        f_float_12: rd_f64(12, r),
                        f_float_13: rd_f64(13, r),
                        f_float_14: rd_f64(14, r),
                        f_float_15: rd_f64(15, r),
                        f_int_0: rd_i64(0, r),
                        f_int_1: rd_i64(1, r),
                        f_int_2: rd_i64(2, r),
                        f_int_3: rd_i64(3, r),
                        f_str_0: from_kstr(s0[r]),
                        f_str_1: from_kstr(s1[r]),
                    }));
                }
                if !self.batch && rows.len() == 1 {
                    Ok(rows.pop().unwrap())
                } else {
                    Ok(Fixture::Rows(rows))
                }
            },
            "table_project" => unsafe {
                let opts = KilnReadOpts {
                    flags: KILN_OPT_EMBEDDED,
                    ..Default::default()
                };
                let mut proj = BenchTableProject::default();
                check_ok(
                    kiln_asm_decode_bench_table_project(
                        src, len, &mut proj, &mut arena, &opts, &mut res,
                    ),
                    "decode table_project",
                )?;
                let n = proj.f_float_0.count as usize;
                let mut col = Vec::<f64>::with_capacity(n);
                if n > 0 {
                    std::ptr::copy_nonoverlapping(
                        proj.f_float_0.items.cast::<u8>(),
                        col.as_mut_ptr().cast(),
                        n * 8,
                    );
                    col.set_len(n);
                }
                Ok(Fixture::Projected(col))
            },
            "nested_table" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchDocument = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_nested_row_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode nested_table batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for d in slice {
                        out.push(Fixture::NestedTable(read_nested(d)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut d = BenchDocument::default();
                    check_ok(
                        kiln_asm_decode_bench_nested_row(
                            src, len, &mut d, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode nested_table",
                    )?;
                    Ok(Fixture::NestedTable(read_nested(&d)))
                }
            },
            "signal" => unsafe {
                if self.batch {
                    let mut ptr: *mut BenchSignal = std::ptr::null_mut();
                    let mut cnt = 0usize;
                    check_ok(
                        kiln_asm_decode_bench_signal_batch(
                            src, len, &mut ptr, &mut cnt, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode signal batch",
                    )?;
                    let slice = std::slice::from_raw_parts(ptr, cnt);
                    let mut out = Vec::with_capacity(cnt);
                    for s in slice {
                        out.push(Fixture::Signal(read_signal(s)));
                    }
                    Ok(Fixture::Rows(out))
                } else {
                    let mut s = BenchSignal::default();
                    check_ok(
                        kiln_asm_decode_bench_signal(
                            src, len, &mut s, &mut arena, std::ptr::null(), &mut res,
                        ),
                        "decode signal",
                    )?;
                    Ok(Fixture::Signal(read_signal(&s)))
                }
            },
            "grid" | "grid_window" => unsafe {
                let mut dir = KilnTensorDir::default();
                check_ok(
                    kiln_asm_decode_tensors(
                        src, len, &mut dir, &mut arena, &LARGE_OPTS, &mut res,
                    ),
                    "decode grid",
                )?;
                if dir.count != 1 || dir.items.is_null() {
                    bail!("gld-kiln-asm: invalid grid tensor dir");
                }
                let t = &*dir.items;
                if t.dtype != KILN_DTYPE_F64 || t.rank != 2 {
                    bail!("gld-kiln-asm: invalid grid tensor meta");
                }
                let ny = t.shape[0] as usize;
                let nx = t.shape[1] as usize;
                let (out_nx, out_ny, values) = if self.read_window {
                    let nread = self.wx * self.wy;
                    let mut v = Vec::<f64>::with_capacity(nread);
                    let row_bytes = self.wx * 8;
                    for r in 0..self.wy {
                        let src_off = ((self.y0 + r) * nx + self.x0) * 8;
                        std::ptr::copy_nonoverlapping(
                            t.data.add(src_off),
                            v.as_mut_ptr().add(r * self.wx).cast(),
                            row_bytes,
                        );
                    }
                    v.set_len(nread);
                    (self.wx, self.wy, v)
                } else {
                    let nread = nx * ny;
                    let mut v = Vec::<f64>::with_capacity(nread);
                    std::ptr::copy_nonoverlapping(t.data, v.as_mut_ptr().cast(), nread * 8);
                    v.set_len(nread);
                    (nx, ny, v)
                };
                Ok(Fixture::Grid(Grid {
                    nx: out_nx as i32,
                    ny: out_ny as i32,
                    values,
                    x0: 0,
                    y0: 0,
                    wx: 0,
                    wy: 0,
                    read_window: self.read_window,
                }))
            },
            "tensor" | "tensor_view" => unsafe {
                let mut dir = KilnTensorDir::default();
                check_ok(
                    kiln_asm_decode_tensors(
                        src, len, &mut dir, &mut arena, &LARGE_OPTS, &mut res,
                    ),
                    "decode tensor",
                )?;
                if dir.count != 1 || dir.items.is_null() {
                    bail!("gld-kiln-asm: invalid tensor dir");
                }
                let t = &*dir.items;
                if t.dtype != KILN_DTYPE_F32 || t.rank != 2 {
                    bail!("gld-kiln-asm: invalid tensor meta");
                }
                let rows = t.shape[0] as i32;
                let cols = t.shape[1] as i32;
                let nbytes = t.data_len as usize;
                if self.kind == "tensor_view" {
                    let b0 = data.as_ptr() as usize;
                    let b1 = b0 + data.len();
                    let p0 = t.data as usize;
                    if nbytes > 0 && (p0 < b0 || p0 > b1 || nbytes > b1 - p0) {
                        bail!("gld-kiln-asm: tensor_view pointer out of range");
                    }
                    let slice = std::slice::from_raw_parts(t.data, nbytes);
                    Ok(Fixture::TensorView(TensorMatrix::borrowed(rows, cols, slice)))
                } else {
                    let n = nbytes / 4;
                    let mut v = take_f32_buf(n);
                    if nbytes > 0 {
                        std::ptr::copy_nonoverlapping(t.data, v.as_mut_ptr().cast(), nbytes);
                        v.set_len(n);
                    }
                    Ok(Fixture::Tensor(TensorMatrix::owned(rows, cols, v)))
                }
            },
            "prompt" => unsafe {
                let mut dir = KilnTensorDir::default();
                check_ok(
                    kiln_asm_decode_tensors(
                        src, len, &mut dir, &mut arena, &LARGE_OPTS, &mut res,
                    ),
                    "decode prompt",
                )?;
                Ok(Fixture::Prompt(read_prompt_tensors(&dir)?))
            },
            "shard" => unsafe {
                let mut dir = KilnTensorDir::default();
                check_ok(
                    kiln_asm_decode_tensors(
                        src, len, &mut dir, &mut arena, &LARGE_OPTS, &mut res,
                    ),
                    "decode shard",
                )?;
                if dir.count != 4 || dir.items.is_null() {
                    bail!("gld-kiln-asm: bad shard tensor dir");
                }
                let items = std::slice::from_raw_parts(dir.items, 4);
                let copy_f32 = |t: &KilnTensor| -> Vec<f32> {
                    let nbytes = t.data_len as usize;
                    let n = nbytes / 4;
                    let mut v = take_f32_buf(n);
                    if nbytes > 0 {
                        std::ptr::copy_nonoverlapping(t.data, v.as_mut_ptr().cast(), nbytes);
                        v.set_len(n);
                    }
                    v
                };
                Ok(Fixture::Shard(Shard {
                    vocab: items[0].shape[0] as i32,
                    hidden: items[0].shape[1] as i32,
                    ffn: items[2].shape[0] as i32,
                    tok_emb: copy_f32(&items[0]),
                    attn: copy_f32(&items[1]),
                    ffn_weight: copy_f32(&items[2]),
                    norm: copy_f32(&items[3]),
                }))
            },
            "request" => unsafe {
                let mut rq = BenchRequest::default();
                check_ok(
                    kiln_asm_decode_bench_request(
                        src, len, &mut rq, &mut arena, &LARGE_OPTS, &mut res,
                    ),
                    "decode request",
                )?;
                Ok(Fixture::Request(InferenceRequest {
                    request_id: rq.request_id,
                    model: from_kstr(rq.model),
                    temperature: rq.temperature,
                    inputs: read_prompt_tensors(&rq.inputs)?,
                }))
            },
            other => bail!("gld-kiln-asm: unsupported {other}"),
        }
    }
}

#[cfg(all(test, has_kiln_asm))]
mod tests {
    use super::*;
    use crate::data::{check_cell_fidelity, make_one, TypeConfig};

    #[test]
    fn roundtrip_all_supported_datasets() {
        let cfg = TypeConfig::from_value(serde_json::json!({
            "rows": 8,
            "cols": 8,
            "batch": 2,
            "seq": 8,
            "vocab": 32,
            "hidden": 8,
            "ffn": 16,
            "shape": [8, 8],
            "window": [2, 2, 4, 4]
        }));

        let mut ser = KilnAsmSer::default();

        // Suite + columnar single & batch
        for kind in [
            "message",
            "document",
            "telemetry",
            "strings",
            "event",
            "table",
            "table_project",
            "nested_table",
            "signal",
        ] {
            for n in [1i32, 5] {
                let fixtures: Vec<Fixture> = (0..n)
                    .map(|i| make_one(kind, 42, i, &cfg).unwrap())
                    .collect();
                ser.prepare_many(&fixtures).unwrap();
                let mut buf = Vec::new();
                ser.serialize_fixtures(&fixtures, &mut buf).unwrap();
                let got = ser.deserialize_bytes(&buf).unwrap();
                check_cell_fidelity(kind, &fixtures, std::slice::from_ref(&got)).unwrap();
            }
        }

        // Array + Tensor
        for kind in [
            "grid",
            "grid_window",
            "tensor",
            "tensor_view",
            "prompt",
            "shard",
            "request",
        ] {
            let one = make_one(kind, 42, 0, &cfg).unwrap();
            ser.prepare(&one).unwrap();
            let mut buf = Vec::new();
            ser.serialize_into(&one, &mut buf).unwrap();
            let got = ser.deserialize_bytes(&buf).unwrap();
            check_cell_fidelity(kind, std::slice::from_ref(&one), std::slice::from_ref(&got))
                .unwrap();
            if kind == "tensor_view" {
                let Fixture::TensorView(tv) = &got else {
                    panic!("expected TensorView");
                };
                assert!(tv.values.is_borrowed());
                assert!(tv.values.borrowed_in(&buf));
            }
        }
    }
}
