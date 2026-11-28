//! gld-kiln-asm: pure x86-64 Assembly Kiln Wire Format v2 codec linked via
//! shared `build/kiln-asm/libkiln_asm_bench.a` (Tier 1 zero-cost C ABI).
//!
//! Covers `suite` (`message`, `document`, `telemetry`, `strings`, `event`)
//! and `tensor` (`tensor`, `tensor_view`, `prompt`, `shard`, `request`).
//! Full RFC 3629 UTF-8 validation is always active (no `KILN_OPT_TRUSTED`).

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

pub const version: []const u8 = "0.2.0";

const KILN_OK: u32 = 0;
const KILN_DTYPE_F32: u16 = 2;
const KILN_DTYPE_I64: u16 = 14;

const KilnArena = extern struct {
    base: [*]u8,
    cur: [*]u8,
    end: [*]u8,
};

const KilnReadOpts = extern struct {
    max_count: u64 = 0,
    max_bytes: u64 = 0,
    max_depth: u32 = 0,
    flags: u32 = 0,
};

const KilnResult = extern struct {
    bytes: u64 = 0,
    hash: u64 = 0,
};

const KilnStr = extern struct {
    ptr: ?[*]const u8 = null,
    len: u64 = 0,
};

fn KilnList(comptime T: type) type {
    return extern struct {
        items: ?[*]T = null,
        count: u64 = 0,
    };
}

const KilnTensor = extern struct {
    name: ?[*]const u8 = null,
    name_len: u64 = 0,
    layout: ?[*]const u8 = null,
    layout_len: u64 = 0,
    data: ?[*]const u8 = null,
    data_len: u64 = 0,
    shape: [8]u64 = .{ 0, 0, 0, 0, 0, 0, 0, 0 },
    dtype: u16 = 0,
    rank: u8 = 0,
    _pad0: u8 = 0,
    quant_scheme: u16 = 0,
    quant_axis: u16 = 0xFFFF,
    group_size: u32 = 0,
    scale_index: u32 = 0xFFFFFFFF,
    outer_index: u32 = 0xFFFFFFFF,
    block_size: u32 = 0,
    elem_count: u64 = 0,
};

const KilnTensorDir = extern struct {
    items: ?[*]KilnTensor = null,
    count: u64 = 0,
    block_length: u64 = 0,
    flags: u32 = 2,
    version: u32 = 2,
};

const BenchMessage = extern struct {
    f_bool: u8 = 0,
    f_int32: i32 = 0,
    f_int64: i64 = 0,
    f_float64: f64 = 0,
    f_string: KilnStr = .{},
    f_bool_2: u8 = 0,
    f_int32_2: i32 = 0,
    f_string_2: KilnStr = .{},
};

const BenchDocMeta = extern struct {
    region: KilnStr = .{},
    version: i32 = 0,
};

const BenchDocItem = extern struct {
    sku: KilnStr = .{},
    qty: i32 = 0,
    price_minor: i64 = 0,
};

const BenchDocument = extern struct {
    id: KilnStr = .{},
    status: i32 = 0,
    meta: BenchDocMeta = .{},
    items: KilnList(BenchDocItem) = .{},
};

const BenchTelemetry = extern struct {
    source: KilnStr = .{},
    ts: i64 = 0,
    tags: KilnList(KilnStr) = .{},
    values: KilnList(f64) = .{},
};

const BenchStrings = extern struct {
    items: KilnList(KilnStr) = .{},
};

const BenchEventAttr = extern struct {
    key: KilnStr = .{},
    value: KilnStr = .{},
};

const BenchEvent = extern struct {
    event_id: KilnStr = .{},
    event_type: KilnStr = .{},
    occurred_at: i64 = 0,
    producer: KilnStr = .{},
    attrs: KilnList(BenchEventAttr) = .{},
};

const BenchRequest = extern struct {
    request_id: i64 = 0,
    model: KilnStr = .{},
    temperature: f32 = 0,
    inputs: KilnTensorDir = .{},
};

comptime {
    if (@sizeOf(KilnTensor) != 144) @compileError("KilnTensor size mismatch");
    if (@sizeOf(KilnTensorDir) != 32) @compileError("KilnTensorDir size mismatch");
    if (@sizeOf(BenchMessage) != 64 or @offsetOf(BenchMessage, "f_string_2") != 48) @compileError("BenchMessage layout mismatch");
    if (@sizeOf(BenchDocMeta) != 24 or @offsetOf(BenchDocMeta, "version") != 16) @compileError("BenchDocMeta layout mismatch");
    if (@sizeOf(BenchDocItem) != 32 or @offsetOf(BenchDocItem, "price_minor") != 24) @compileError("BenchDocItem layout mismatch");
    if (@sizeOf(BenchDocument) != 64 or @offsetOf(BenchDocument, "items") != 48) @compileError("BenchDocument layout mismatch");
    if (@sizeOf(BenchTelemetry) != 56 or @offsetOf(BenchTelemetry, "values") != 40) @compileError("BenchTelemetry layout mismatch");
    if (@sizeOf(BenchStrings) != 16) @compileError("BenchStrings size mismatch");
    if (@sizeOf(BenchEventAttr) != 32) @compileError("BenchEventAttr size mismatch");
    if (@sizeOf(BenchEvent) != 72 or @offsetOf(BenchEvent, "attrs") != 56) @compileError("BenchEvent layout mismatch");
    if (@sizeOf(BenchRequest) != 64 or @offsetOf(BenchRequest, "inputs") != 32) @compileError("BenchRequest layout mismatch");
}

extern "c" fn kiln_asm_encode_bench_message(in: *const BenchMessage, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_message(src: [*]const u8, len: usize, out: *BenchMessage, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_encode_bench_message_batch(items: [*]const BenchMessage, count: usize, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_message_batch(src: [*]const u8, len: usize, out_items: *?[*]BenchMessage, out_count: *usize, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_bench_document(in: *const BenchDocument, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_document(src: [*]const u8, len: usize, out: *BenchDocument, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_encode_bench_document_batch(items: [*]const BenchDocument, count: usize, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_document_batch(src: [*]const u8, len: usize, out_items: *?[*]BenchDocument, out_count: *usize, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_bench_telemetry(in: *const BenchTelemetry, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_telemetry(src: [*]const u8, len: usize, out: *BenchTelemetry, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_encode_bench_telemetry_batch(items: [*]const BenchTelemetry, count: usize, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_telemetry_batch(src: [*]const u8, len: usize, out_items: *?[*]BenchTelemetry, out_count: *usize, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_bench_strings(in: *const BenchStrings, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_strings(src: [*]const u8, len: usize, out: *BenchStrings, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_encode_bench_strings_batch(items: [*]const BenchStrings, count: usize, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_strings_batch(src: [*]const u8, len: usize, out_items: *?[*]BenchStrings, out_count: *usize, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_bench_event(in: *const BenchEvent, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_event(src: [*]const u8, len: usize, out: *BenchEvent, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_encode_bench_event_batch(items: [*]const BenchEvent, count: usize, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_event_batch(src: [*]const u8, len: usize, out_items: *?[*]BenchEvent, out_count: *usize, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_bench_request(in: *const BenchRequest, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_bench_request(src: [*]const u8, len: usize, out: *BenchRequest, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

extern "c" fn kiln_asm_encode_tensors(in: *const KilnTensorDir, dst: [*]u8, cap: usize, opts: ?*const KilnReadOpts, res: *KilnResult) u32;
extern "c" fn kiln_asm_decode_tensors(src: [*]const u8, len: usize, out: *KilnTensorDir, arena: *KilnArena, opts: ?*const KilnReadOpts, res: *KilnResult) u32;

const LARGE_OPTS = KilnReadOpts{
    .max_count = 1 << 28,
    .max_bytes = 1 << 28,
    .max_depth = 0,
    .flags = 0,
};

fn kstr(s: []const u8) KilnStr {
    return .{
        .ptr = if (s.len > 0) s.ptr else null,
        .len = s.len,
    };
}

fn fromKstr(alloc: std.mem.Allocator, s: KilnStr) ![]const u8 {
    const n: usize = @intCast(s.len);
    if (n == 0) return "";
    const p = s.ptr orelse return error.KilnNullStr;
    return try alloc.dupe(u8, p[0..n]);
}

fn setTensor1D(dtype: u16, d0: u64, ptr: [*]const u8, nbytes: usize) KilnTensor {
    var t = KilnTensor{};
    t.dtype = dtype;
    t.rank = 1;
    t.shape[0] = d0;
    t.data = if (nbytes > 0) ptr else null;
    t.data_len = nbytes;
    t.elem_count = d0;
    return t;
}

fn setTensor2D(dtype: u16, d0: u64, d1: u64, ptr: [*]const u8, nbytes: usize) KilnTensor {
    var t = KilnTensor{};
    t.dtype = dtype;
    t.rank = 2;
    t.shape[0] = d0;
    t.shape[1] = d1;
    t.data = if (nbytes > 0) ptr else null;
    t.data_len = nbytes;
    t.elem_count = d0 * d1;
    return t;
}

fn fillPromptTensors(p: data.Prompt) [3]KilnTensor {
    const b: u64 = @intCast(p.batch);
    const s: u64 = @intCast(p.seq);
    return .{
        setTensor2D(KILN_DTYPE_I64, b, s, std.mem.sliceAsBytes(p.input_ids).ptr, p.input_ids.len * 8),
        setTensor2D(KILN_DTYPE_I64, b, s, std.mem.sliceAsBytes(p.attention_mask).ptr, p.attention_mask.len * 8),
        setTensor2D(KILN_DTYPE_I64, b, s, std.mem.sliceAsBytes(p.position_ids).ptr, p.position_ids.len * 8),
    };
}

fn readPromptTensors(alloc: std.mem.Allocator, dir: *const KilnTensorDir) !data.Prompt {
    if (dir.count != 3) return error.KilnBadPrompt;
    const items = dir.items orelse return error.KilnBadPrompt;
    const t0 = items[0];
    const t1 = items[1];
    const t2 = items[2];
    if (t0.dtype != KILN_DTYPE_I64 or t0.rank != 2) return error.KilnBadPrompt;
    const batch: i32 = @intCast(t0.shape[0]);
    const seq: i32 = @intCast(t0.shape[1]);
    const n: usize = @intCast(t0.elem_count);

    const a = try alloc.alloc(i64, n);
    const b = try alloc.alloc(i64, n);
    const c = try alloc.alloc(i64, n);
    if (n > 0) {
        @memcpy(std.mem.sliceAsBytes(a), t0.data.?[0 .. n * 8]);
        @memcpy(std.mem.sliceAsBytes(b), t1.data.?[0 .. n * 8]);
        @memcpy(std.mem.sliceAsBytes(c), t2.data.?[0 .. n * 8]);
    }
    return .{
        .batch = batch,
        .seq = seq,
        .input_ids = a,
        .attention_mask = b,
        .position_ids = c,
    };
}

pub const State = struct {
    gpa: std.mem.Allocator = std.heap.page_allocator,
    arena_buf: []u8 = &.{},
    wire_cap: usize = 4096,
    enc_msg: std.ArrayList(BenchMessage) = .empty,
    enc_doc: std.ArrayList(BenchDocument) = .empty,
    enc_doc_items: std.ArrayList(BenchDocItem) = .empty,
    enc_tel: std.ArrayList(BenchTelemetry) = .empty,
    enc_str_items: std.ArrayList(KilnStr) = .empty,
    enc_strs: std.ArrayList(BenchStrings) = .empty,
    enc_ev: std.ArrayList(BenchEvent) = .empty,
    enc_ev_attrs: std.ArrayList(BenchEventAttr) = .empty,

    fn ensureArena(self: *State, need: usize) !void {
        if (self.arena_buf.len >= need) return;
        const next = @max(need, 65536);
        if (self.arena_buf.len > 0) {
            self.arena_buf = try self.gpa.realloc(self.arena_buf, next);
        } else {
            self.arena_buf = try self.gpa.alloc(u8, next);
        }
    }

    fn makeArena(self: *State) KilnArena {
        return .{
            .base = self.arena_buf.ptr,
            .cur = self.arena_buf.ptr,
            .end = self.arena_buf.ptr + self.arena_buf.len,
        };
    }
};

pub var state: State = .{};

pub fn supports(type_id: []const u8) bool {
    return std.mem.eql(u8, type_id, "message") or
        std.mem.eql(u8, type_id, "document") or
        std.mem.eql(u8, type_id, "telemetry") or
        std.mem.eql(u8, type_id, "strings") or
        std.mem.eql(u8, type_id, "event") or
        std.mem.eql(u8, type_id, "tensor") or
        std.mem.eql(u8, type_id, "tensor_view") or
        std.mem.eql(u8, type_id, "prompt") or
        std.mem.eql(u8, type_id, "shard") or
        std.mem.eql(u8, type_id, "request");
}

pub fn prepare(ctx: *anyopaque, _: std.mem.Allocator, fixtures: []const data.Fixture) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (fixtures.len == 0) return;
    const n = fixtures.len;
    var wire_need: usize = 4096;
    var arena_need: usize = 65536;
    switch (fixtures[0]) {
        .message => {
            wire_need = n * 256 + 1024;
            arena_need = n * 128 + 4096;
        },
        .document => {
            var items: usize = 0;
            for (fixtures) |fx| items += fx.document.items.len;
            wire_need = n * 128 + items * 64 + 1024;
            arena_need = n * 128 + items * 48 + 8192;
        },
        .telemetry => {
            var tags: usize = 0;
            var vals: usize = 0;
            for (fixtures) |fx| {
                tags += fx.telemetry.tags.len;
                vals += fx.telemetry.values.len;
            }
            wire_need = n * 128 + tags * 48 + vals * 8 + 1024;
            arena_need = n * 128 + tags * 32 + 8192;
        },
        .strings => {
            var items: usize = 0;
            for (fixtures) |fx| items += fx.strings.items.len;
            wire_need = n * 16 + items * 48 + 1024;
            arena_need = n * 32 + items * 32 + 8192;
        },
        .event => {
            var attrs: usize = 0;
            for (fixtures) |fx| attrs += fx.event.attrs.len;
            wire_need = n * 192 + attrs * 96 + 1024;
            arena_need = n * 128 + attrs * 48 + 8192;
        },
        .tensor => |t| {
            wire_need = t.values.len * 4 + 1024;
        },
        .tensor_view => |t| {
            wire_need = t.values.len * 4 + 1024;
        },
        .prompt => |p| {
            wire_need = p.input_ids.len * 24 + 2048;
        },
        .shard => |s| {
            wire_need = (s.tok_emb.len + s.attn.len + s.ffn_weight.len + s.norm.len) * 4 + 2048;
        },
        .request => |q| {
            wire_need = q.inputs.input_ids.len * 24 + q.model.len + 2048;
        },
    }
    self.wire_cap = wire_need;
    try self.ensureArena(arena_need);
}

pub fn beginEncode(_: *anyopaque) void {}

fn fillMsg(m: data.Message) BenchMessage {
    return .{
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = kstr(m.f_string),
        .f_string_2 = kstr(m.f_string_2),
        .f_int32 = m.f_int32,
        .f_int32_2 = m.f_int32_2,
        .f_bool = if (m.f_bool) 1 else 0,
        .f_bool_2 = if (m.f_bool_2) 1 else 0,
    };
}

fn readMsg(alloc: std.mem.Allocator, m: *const BenchMessage) !data.Message {
    return .{
        .f_bool = m.f_bool != 0,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = try fromKstr(alloc, m.f_string),
        .f_bool_2 = m.f_bool_2 != 0,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = try fromKstr(alloc, m.f_string_2),
    };
}

fn readDoc(alloc: std.mem.Allocator, d: *const BenchDocument) !data.Document {
    const n: usize = @intCast(d.items.count);
    const items = try alloc.alloc(data.DocumentItem, n);
    if (n > 0) {
        const src = d.items.items orelse return error.KilnNullItems;
        for (0..n) |i| {
            items[i] = .{
                .sku = try fromKstr(alloc, src[i].sku),
                .qty = src[i].qty,
                .price_minor = src[i].price_minor,
            };
        }
    }
    return .{
        .id = try fromKstr(alloc, d.id),
        .status = d.status,
        .meta = .{
            .region = try fromKstr(alloc, d.meta.region),
            .version = d.meta.version,
        },
        .items = items,
    };
}

fn readTel(alloc: std.mem.Allocator, t: *const BenchTelemetry) !data.Telemetry {
    const nt: usize = @intCast(t.tags.count);
    const tags = try alloc.alloc([]const u8, nt);
    if (nt > 0) {
        const src = t.tags.items orelse return error.KilnNullItems;
        for (0..nt) |i| tags[i] = try fromKstr(alloc, src[i]);
    }
    const nv: usize = @intCast(t.values.count);
    const vals = try alloc.alloc(f64, nv);
    if (nv > 0) {
        // POD list decode returns a 4-byte-aligned pointer into the wire buffer.
        const raw: [*]const u8 = @ptrCast(t.values.items orelse return error.KilnNullItems);
        @memcpy(std.mem.sliceAsBytes(vals), raw[0 .. nv * 8]);
    }
    return .{
        .source = try fromKstr(alloc, t.source),
        .ts = t.ts,
        .tags = tags,
        .values = vals,
    };
}

fn readStrs(alloc: std.mem.Allocator, s: *const BenchStrings) !data.Strings {
    const n: usize = @intCast(s.items.count);
    const items = try alloc.alloc([]const u8, n);
    if (n > 0) {
        const src = s.items.items orelse return error.KilnNullItems;
        for (0..n) |i| items[i] = try fromKstr(alloc, src[i]);
    }
    return .{ .items = items };
}

fn readEv(alloc: std.mem.Allocator, e: *const BenchEvent) !data.Event {
    const n: usize = @intCast(e.attrs.count);
    const attrs = try alloc.alloc(data.EventAttr, n);
    if (n > 0) {
        const src = e.attrs.items orelse return error.KilnNullItems;
        for (0..n) |i| {
            attrs[i] = .{
                .key = try fromKstr(alloc, src[i].key),
                .value = try fromKstr(alloc, src[i].value),
            };
        }
    }
    return .{
        .event_id = try fromKstr(alloc, e.event_id),
        .event_type = try fromKstr(alloc, e.event_type),
        .occurred_at = e.occurred_at,
        .producer = try fromKstr(alloc, e.producer),
        .attrs = attrs,
    };
}

fn encodeSlice(self: *State, fixtures: []const data.Fixture, batch: bool, out: *buf_mod.Buf) !void {
    out.clear();
    try out.ensure(self.wire_cap);
    const dst = out.data.ptr;
    const cap = out.data.len;
    var res = KilnResult{};
    var err: u32 = KILN_OK;

    switch (fixtures[0]) {
        .message => {
            if (batch) {
                self.enc_msg.clearRetainingCapacity();
                try self.enc_msg.ensureTotalCapacity(self.gpa, fixtures.len);
                for (fixtures) |fx| self.enc_msg.appendAssumeCapacity(fillMsg(fx.message));
                err = kiln_asm_encode_bench_message_batch(self.enc_msg.items.ptr, self.enc_msg.items.len, dst, cap, null, &res);
            } else {
                const bm = fillMsg(fixtures[0].message);
                err = kiln_asm_encode_bench_message(&bm, dst, cap, null, &res);
            }
        },
        .document => {
            self.enc_doc.clearRetainingCapacity();
            self.enc_doc_items.clearRetainingCapacity();
            var total_items: usize = 0;
            for (fixtures) |fx| total_items += fx.document.items.len;
            try self.enc_doc_items.ensureTotalCapacity(self.gpa, total_items);
            try self.enc_doc.ensureTotalCapacity(self.gpa, fixtures.len);
            for (fixtures) |fx| {
                for (fx.document.items) |it| {
                    self.enc_doc_items.appendAssumeCapacity(.{
                        .sku = kstr(it.sku),
                        .qty = it.qty,
                        .price_minor = it.price_minor,
                    });
                }
            }
            var off: usize = 0;
            for (fixtures) |fx| {
                const d = fx.document;
                const cnt = d.items.len;
                const ptr: ?[*]BenchDocItem = if (cnt > 0) self.enc_doc_items.items.ptr + off else null;
                off += cnt;
                self.enc_doc.appendAssumeCapacity(.{
                    .id = kstr(d.id),
                    .status = d.status,
                    .meta = .{ .region = kstr(d.meta.region), .version = d.meta.version },
                    .items = .{ .items = ptr, .count = cnt },
                });
            }
            err = if (batch)
                kiln_asm_encode_bench_document_batch(self.enc_doc.items.ptr, self.enc_doc.items.len, dst, cap, null, &res)
            else
                kiln_asm_encode_bench_document(&self.enc_doc.items[0], dst, cap, null, &res);
        },
        .telemetry => {
            self.enc_tel.clearRetainingCapacity();
            self.enc_str_items.clearRetainingCapacity();
            var total_tags: usize = 0;
            for (fixtures) |fx| total_tags += fx.telemetry.tags.len;
            try self.enc_str_items.ensureTotalCapacity(self.gpa, total_tags);
            try self.enc_tel.ensureTotalCapacity(self.gpa, fixtures.len);
            for (fixtures) |fx| {
                for (fx.telemetry.tags) |tag| self.enc_str_items.appendAssumeCapacity(kstr(tag));
            }
            var off: usize = 0;
            for (fixtures) |fx| {
                const t = fx.telemetry;
                const nt = t.tags.len;
                const tptr: ?[*]KilnStr = if (nt > 0) self.enc_str_items.items.ptr + off else null;
                off += nt;
                const vptr: ?[*]f64 = if (t.values.len > 0) t.values.ptr else null;
                self.enc_tel.appendAssumeCapacity(.{
                    .source = kstr(t.source),
                    .ts = t.ts,
                    .tags = .{ .items = tptr, .count = nt },
                    .values = .{ .items = vptr, .count = t.values.len },
                });
            }
            err = if (batch)
                kiln_asm_encode_bench_telemetry_batch(self.enc_tel.items.ptr, self.enc_tel.items.len, dst, cap, null, &res)
            else
                kiln_asm_encode_bench_telemetry(&self.enc_tel.items[0], dst, cap, null, &res);
        },
        .strings => {
            self.enc_strs.clearRetainingCapacity();
            self.enc_str_items.clearRetainingCapacity();
            var total_items: usize = 0;
            for (fixtures) |fx| total_items += fx.strings.items.len;
            try self.enc_str_items.ensureTotalCapacity(self.gpa, total_items);
            try self.enc_strs.ensureTotalCapacity(self.gpa, fixtures.len);
            for (fixtures) |fx| {
                for (fx.strings.items) |it| self.enc_str_items.appendAssumeCapacity(kstr(it));
            }
            var off: usize = 0;
            for (fixtures) |fx| {
                const cnt = fx.strings.items.len;
                const ptr: ?[*]KilnStr = if (cnt > 0) self.enc_str_items.items.ptr + off else null;
                off += cnt;
                self.enc_strs.appendAssumeCapacity(.{ .items = .{ .items = ptr, .count = cnt } });
            }
            err = if (batch)
                kiln_asm_encode_bench_strings_batch(self.enc_strs.items.ptr, self.enc_strs.items.len, dst, cap, null, &res)
            else
                kiln_asm_encode_bench_strings(&self.enc_strs.items[0], dst, cap, null, &res);
        },
        .event => {
            self.enc_ev.clearRetainingCapacity();
            self.enc_ev_attrs.clearRetainingCapacity();
            var total_attrs: usize = 0;
            for (fixtures) |fx| total_attrs += fx.event.attrs.len;
            try self.enc_ev_attrs.ensureTotalCapacity(self.gpa, total_attrs);
            try self.enc_ev.ensureTotalCapacity(self.gpa, fixtures.len);
            for (fixtures) |fx| {
                for (fx.event.attrs) |a| {
                    self.enc_ev_attrs.appendAssumeCapacity(.{ .key = kstr(a.key), .value = kstr(a.value) });
                }
            }
            var off: usize = 0;
            for (fixtures) |fx| {
                const e = fx.event;
                const cnt = e.attrs.len;
                const ptr: ?[*]BenchEventAttr = if (cnt > 0) self.enc_ev_attrs.items.ptr + off else null;
                off += cnt;
                self.enc_ev.appendAssumeCapacity(.{
                    .event_id = kstr(e.event_id),
                    .event_type = kstr(e.event_type),
                    .occurred_at = e.occurred_at,
                    .producer = kstr(e.producer),
                    .attrs = .{ .items = ptr, .count = cnt },
                });
            }
            err = if (batch)
                kiln_asm_encode_bench_event_batch(self.enc_ev.items.ptr, self.enc_ev.items.len, dst, cap, null, &res)
            else
                kiln_asm_encode_bench_event(&self.enc_ev.items[0], dst, cap, null, &res);
        },
        .tensor => |t| {
            var kt = setTensor2D(KILN_DTYPE_F32, @intCast(t.rows), @intCast(t.cols), std.mem.sliceAsBytes(t.values).ptr, t.values.len * 4);
            var dir = KilnTensorDir{ .items = (&kt)[0..1].ptr, .count = 1 };
            err = kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &res);
        },
        .tensor_view => |t| {
            var kt = setTensor2D(KILN_DTYPE_F32, @intCast(t.rows), @intCast(t.cols), std.mem.sliceAsBytes(t.values).ptr, t.values.len * 4);
            var dir = KilnTensorDir{ .items = (&kt)[0..1].ptr, .count = 1 };
            err = kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &res);
        },
        .prompt => |p| {
            var ts = fillPromptTensors(p);
            var dir = KilnTensorDir{ .items = &ts, .count = 3 };
            err = kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &res);
        },
        .shard => |s| {
            var ts = [4]KilnTensor{
                setTensor2D(KILN_DTYPE_F32, @intCast(s.vocab), @intCast(s.hidden), std.mem.sliceAsBytes(s.tok_emb).ptr, s.tok_emb.len * 4),
                setTensor2D(KILN_DTYPE_F32, @intCast(s.hidden), @intCast(s.hidden), std.mem.sliceAsBytes(s.attn).ptr, s.attn.len * 4),
                setTensor2D(KILN_DTYPE_F32, @intCast(s.ffn), @intCast(s.hidden), std.mem.sliceAsBytes(s.ffn_weight).ptr, s.ffn_weight.len * 4),
                setTensor1D(KILN_DTYPE_F32, @intCast(s.hidden), std.mem.sliceAsBytes(s.norm).ptr, s.norm.len * 4),
            };
            var dir = KilnTensorDir{ .items = &ts, .count = 4 };
            err = kiln_asm_encode_tensors(&dir, dst, cap, &LARGE_OPTS, &res);
        },
        .request => |q| {
            var ts = fillPromptTensors(q.inputs);
            const rq = BenchRequest{
                .request_id = q.request_id,
                .model = kstr(q.model),
                .temperature = q.temperature,
                .inputs = .{ .items = &ts, .count = 3 },
            };
            err = kiln_asm_encode_bench_request(&rq, dst, cap, &LARGE_OPTS, &res);
        },
    }
    if (err != KILN_OK) return error.KilnAsmEncode;
    out.len = @intCast(res.bytes);
}

pub fn serialize(ctx: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    const single = [1]data.Fixture{fx};
    try encodeSlice(self, &single, false, out);
}

pub fn encodeBatch(ctx: *anyopaque, fixtures: []const data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    try encodeSlice(self, fixtures, true, out);
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    const self: *State = @ptrCast(@alignCast(ctx));
    try self.ensureArena(65536);
    var arena = self.makeArena();
    var res = KilnResult{};

    if (std.mem.eql(u8, type_id, "message")) {
        var m = BenchMessage{};
        if (kiln_asm_decode_bench_message(bytes.ptr, bytes.len, &m, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .message = try readMsg(allocator, &m) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        var d = BenchDocument{};
        if (kiln_asm_decode_bench_document(bytes.ptr, bytes.len, &d, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .document = try readDoc(allocator, &d) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        var t = BenchTelemetry{};
        if (kiln_asm_decode_bench_telemetry(bytes.ptr, bytes.len, &t, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .telemetry = try readTel(allocator, &t) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        var s = BenchStrings{};
        if (kiln_asm_decode_bench_strings(bytes.ptr, bytes.len, &s, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .strings = try readStrs(allocator, &s) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        var e = BenchEvent{};
        if (kiln_asm_decode_bench_event(bytes.ptr, bytes.len, &e, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .event = try readEv(allocator, &e) };
    }
    if (std.mem.eql(u8, type_id, "tensor") or std.mem.eql(u8, type_id, "tensor_view")) {
        var dir = KilnTensorDir{};
        if (kiln_asm_decode_tensors(bytes.ptr, bytes.len, &dir, &arena, &LARGE_OPTS, &res) != KILN_OK) return error.KilnAsmDecode;
        if (dir.count != 1) return error.KilnBadTensor;
        const kt = (dir.items orelse return error.KilnBadTensor)[0];
        if (kt.dtype != KILN_DTYPE_F32 or kt.rank != 2) return error.KilnBadTensor;
        const rows: i32 = @intCast(kt.shape[0]);
        const cols: i32 = @intCast(kt.shape[1]);
        const nbytes: usize = @intCast(kt.data_len);
        if (std.mem.eql(u8, type_id, "tensor_view")) {
            const payload: []const u8 = if (nbytes > 0) blk: {
                const p = kt.data orelse return error.KilnBadTensor;
                const b0 = @intFromPtr(bytes.ptr);
                const b1 = b0 + bytes.len;
                const p0 = @intFromPtr(p);
                if (p0 < b0 or p0 > b1 or nbytes > b1 - p0) return error.KilnViewOutOfRange;
                break :blk p[0..nbytes];
            } else &.{};
            return .{ .tensor_view = .{ .rows = rows, .cols = cols, .values = &.{}, .payload = payload } };
        }
        const n = nbytes / 4;
        const vals = try allocator.alloc(f32, n);
        if (nbytes > 0) @memcpy(std.mem.sliceAsBytes(vals), kt.data.?[0..nbytes]);
        return .{ .tensor = .{ .rows = rows, .cols = cols, .values = vals } };
    }
    if (std.mem.eql(u8, type_id, "prompt")) {
        var dir = KilnTensorDir{};
        if (kiln_asm_decode_tensors(bytes.ptr, bytes.len, &dir, &arena, &LARGE_OPTS, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .prompt = try readPromptTensors(allocator, &dir) };
    }
    if (std.mem.eql(u8, type_id, "shard")) {
        var dir = KilnTensorDir{};
        if (kiln_asm_decode_tensors(bytes.ptr, bytes.len, &dir, &arena, &LARGE_OPTS, &res) != KILN_OK) return error.KilnAsmDecode;
        if (dir.count != 4) return error.KilnBadShard;
        const items = dir.items orelse return error.KilnBadShard;
        const copyF32 = struct {
            fn f(a: std.mem.Allocator, t: KilnTensor) ![]f32 {
                const nb: usize = @intCast(t.data_len);
                const v = try a.alloc(f32, nb / 4);
                if (nb > 0) @memcpy(std.mem.sliceAsBytes(v), t.data.?[0..nb]);
                return v;
            }
        }.f;
        return .{ .shard = .{
            .vocab = @intCast(items[0].shape[0]),
            .hidden = @intCast(items[0].shape[1]),
            .ffn = @intCast(items[2].shape[0]),
            .tok_emb = try copyF32(allocator, items[0]),
            .attn = try copyF32(allocator, items[1]),
            .ffn_weight = try copyF32(allocator, items[2]),
            .norm = try copyF32(allocator, items[3]),
        } };
    }
    if (std.mem.eql(u8, type_id, "request")) {
        var rq = BenchRequest{};
        if (kiln_asm_decode_bench_request(bytes.ptr, bytes.len, &rq, &arena, &LARGE_OPTS, &res) != KILN_OK) return error.KilnAsmDecode;
        return .{ .request = .{
            .request_id = rq.request_id,
            .model = try fromKstr(allocator, rq.model),
            .temperature = rq.temperature,
            .inputs = try readPromptTensors(allocator, &rq.inputs),
        } };
    }
    return error.UnknownTypeId;
}

pub fn decodeBatch(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) ![]data.Fixture {
    const self: *State = @ptrCast(@alignCast(ctx));
    try self.ensureArena(65536);
    var arena = self.makeArena();
    var res = KilnResult{};

    if (std.mem.eql(u8, type_id, "message")) {
        var ptr: ?[*]BenchMessage = null;
        var cnt: usize = 0;
        if (kiln_asm_decode_bench_message_batch(bytes.ptr, bytes.len, &ptr, &cnt, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        const out = try allocator.alloc(data.Fixture, cnt);
        if (cnt > 0) for (0..cnt) |i| {
            out[i] = .{ .message = try readMsg(allocator, &ptr.?[i]) };
        };
        return out;
    }
    if (std.mem.eql(u8, type_id, "document")) {
        var ptr: ?[*]BenchDocument = null;
        var cnt: usize = 0;
        if (kiln_asm_decode_bench_document_batch(bytes.ptr, bytes.len, &ptr, &cnt, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        const out = try allocator.alloc(data.Fixture, cnt);
        if (cnt > 0) for (0..cnt) |i| {
            out[i] = .{ .document = try readDoc(allocator, &ptr.?[i]) };
        };
        return out;
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        var ptr: ?[*]BenchTelemetry = null;
        var cnt: usize = 0;
        if (kiln_asm_decode_bench_telemetry_batch(bytes.ptr, bytes.len, &ptr, &cnt, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        const out = try allocator.alloc(data.Fixture, cnt);
        if (cnt > 0) for (0..cnt) |i| {
            out[i] = .{ .telemetry = try readTel(allocator, &ptr.?[i]) };
        };
        return out;
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        var ptr: ?[*]BenchStrings = null;
        var cnt: usize = 0;
        if (kiln_asm_decode_bench_strings_batch(bytes.ptr, bytes.len, &ptr, &cnt, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        const out = try allocator.alloc(data.Fixture, cnt);
        if (cnt > 0) for (0..cnt) |i| {
            out[i] = .{ .strings = try readStrs(allocator, &ptr.?[i]) };
        };
        return out;
    }
    if (std.mem.eql(u8, type_id, "event")) {
        var ptr: ?[*]BenchEvent = null;
        var cnt: usize = 0;
        if (kiln_asm_decode_bench_event_batch(bytes.ptr, bytes.len, &ptr, &cnt, &arena, null, &res) != KILN_OK) return error.KilnAsmDecode;
        const out = try allocator.alloc(data.Fixture, cnt);
        if (cnt > 0) for (0..cnt) |i| {
            out[i] = .{ .event = try readEv(allocator, &ptr.?[i]) };
        };
        return out;
    }
    return error.UnknownTypeId;
}

test "gld-kiln-asm roundtrip suite and tensor sets" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const alloc = arena.allocator();
    const cfg = data.TypeConfig{ .rows = 8, .cols = 8, .batch = 2, .seq = 8, .vocab = 32, .hidden = 8, .ffn = 16 };

    const suite_kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    for (suite_kinds) |tid| {
        const fx = try data.makeOne(alloc, tid, 42, 0, cfg);
        var out = try buf_mod.Buf.initCapacity(alloc, 4096);
        try prepare(@ptrCast(&state), alloc, &.{fx});
        try serialize(@ptrCast(&state), fx, &out);
        const back = try deserialize(@ptrCast(&state), alloc, tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));

        const batch = try data.instances(alloc, tid, 42, 5, cfg);
        try prepare(@ptrCast(&state), alloc, batch);
        try encodeBatch(@ptrCast(&state), batch, &out);
        const got_batch = try decodeBatch(@ptrCast(&state), alloc, tid, out.items());
        try std.testing.expectEqual(batch.len, got_batch.len);
        for (batch, got_batch) |a, b| try std.testing.expect(data.fidelity(a, b));
    }

    const tensor_kinds = [_][]const u8{ "tensor", "tensor_view", "prompt", "shard", "request" };
    for (tensor_kinds) |tid| {
        const fx = try data.makeOne(alloc, tid, 42, 0, cfg);
        var out = try buf_mod.Buf.initCapacity(alloc, 4096);
        try prepare(@ptrCast(&state), alloc, &.{fx});
        try serialize(@ptrCast(&state), fx, &out);
        const back = try deserialize(@ptrCast(&state), alloc, tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));
        if (std.mem.eql(u8, tid, "tensor_view")) {
            const tv = back.tensor_view;
            try std.testing.expectEqual(@as(usize, 0), tv.values.len);
            try std.testing.expect(tv.payload.len > 0);
            const b0 = @intFromPtr(out.items().ptr);
            const b1 = b0 + out.items().len;
            const p0 = @intFromPtr(tv.payload.ptr);
            try std.testing.expect(p0 >= b0 and p0 + tv.payload.len <= b1);
        }
    }
}
