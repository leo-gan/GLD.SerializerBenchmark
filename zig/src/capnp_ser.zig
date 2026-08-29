//! Cap’n Proto adapter via the official C++ runtime.
//!
//! Generated C++ types come from the shared suite schema
//! `cpp/schemas/benchmark.capnp` (same file C++, Swift, and Kotlin compile).
//! There is no Zig 0.16 codegen plugin; this matches Swift’s CapnpBridge:
//! prepare fills C structs (untimed); timed path is `capnp_encode_*` /
//! `capnp_decode_*` on the official `MallocMessageBuilder` / `FlatArrayMessageReader`.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

const c = @cImport({
    @cInclude("capnp_bridge.h");
});

pub const version = "1.0.2";

const Prepared = union(enum) {
    none,
    message: []c.CapnpCMessage,
    document: []c.CapnpCDocument,
    telemetry: []c.CapnpCTelemetry,
    strings: []c.CapnpCStrings,
    event: []c.CapnpCEvent,
};

pub const State = struct {
    arena: std.heap.ArenaAllocator = undefined,
    prepared: Prepared = .none,
    enc_i: usize = 0,
    ready: bool = false,

    fn ensure(self: *State) void {
        if (self.ready) return;
        self.arena = .init(std.heap.page_allocator);
        self.ready = true;
    }
};

pub var state: State = .{};

pub fn prepare(ctx: *anyopaque, _: std.mem.Allocator, fixtures: []const data.Fixture) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    _ = self.arena.reset(.retain_capacity);
    self.enc_i = 0;
    const aa = self.arena.allocator();
    if (fixtures.len == 0) {
        self.prepared = .none;
        return;
    }
    self.prepared = switch (fixtures[0]) {
        .message => blk: {
            const out = try aa.alloc(c.CapnpCMessage, fixtures.len);
            for (fixtures, out) |fx, *slot| slot.* = try messageToC(aa, fx.message);
            break :blk .{ .message = out };
        },
        .document => blk: {
            const out = try aa.alloc(c.CapnpCDocument, fixtures.len);
            for (fixtures, out) |fx, *slot| slot.* = try documentToC(aa, fx.document);
            break :blk .{ .document = out };
        },
        .telemetry => blk: {
            const out = try aa.alloc(c.CapnpCTelemetry, fixtures.len);
            for (fixtures, out) |fx, *slot| slot.* = try telemetryToC(aa, fx.telemetry);
            break :blk .{ .telemetry = out };
        },
        .strings => blk: {
            const out = try aa.alloc(c.CapnpCStrings, fixtures.len);
            for (fixtures, out) |fx, *slot| slot.* = try stringsToC(aa, fx.strings);
            break :blk .{ .strings = out };
        },
        .event => blk: {
            const out = try aa.alloc(c.CapnpCEvent, fixtures.len);
            for (fixtures, out) |fx, *slot| slot.* = try eventToC(aa, fx.event);
            break :blk .{ .event = out };
        },
    };
}

pub fn beginEncode(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.enc_i = 0;
}

pub fn serialize(ctx: *anyopaque, _: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    const i = self.enc_i;
    self.enc_i += 1;
    var n: usize = 0;
    const ptr: ?*anyopaque = switch (self.prepared) {
        .none => return error.CapnpNotPrepared,
        .message => |v| c.capnp_encode_message(&v[i], &n),
        .document => |v| c.capnp_encode_document(&v[i], &n),
        .telemetry => |v| c.capnp_encode_telemetry(&v[i], &n),
        .strings => |v| c.capnp_encode_strings(&v[i], &n),
        .event => |v| c.capnp_encode_event(&v[i], &n),
    };
    const buf = ptr orelse return error.CapnpEncode;
    defer c.capnp_free(buf);
    try out.appendSlice(@as([*]const u8, @ptrCast(buf))[0..n]);
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    _ = ctx;
    const aligned = try alignWords(allocator, bytes);
    if (std.mem.eql(u8, type_id, "message")) {
        var raw: c.CapnpCMessage = undefined;
        if (c.capnp_decode_message(aligned.ptr, aligned.len, &raw) != 0) return error.CapnpDecode;
        defer c.capnp_free_message(&raw);
        return .{ .message = try messageFromC(allocator, raw) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        var raw: c.CapnpCDocument = undefined;
        if (c.capnp_decode_document(aligned.ptr, aligned.len, &raw) != 0) return error.CapnpDecode;
        defer c.capnp_free_document(&raw);
        return .{ .document = try documentFromC(allocator, raw) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        var raw: c.CapnpCTelemetry = undefined;
        if (c.capnp_decode_telemetry(aligned.ptr, aligned.len, &raw) != 0) return error.CapnpDecode;
        defer c.capnp_free_telemetry(&raw);
        return .{ .telemetry = try telemetryFromC(allocator, raw) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        var raw: c.CapnpCStrings = undefined;
        if (c.capnp_decode_strings(aligned.ptr, aligned.len, &raw) != 0) return error.CapnpDecode;
        defer c.capnp_free_strings(&raw);
        return .{ .strings = try stringsFromC(allocator, raw) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        var raw: c.CapnpCEvent = undefined;
        if (c.capnp_decode_event(aligned.ptr, aligned.len, &raw) != 0) return error.CapnpDecode;
        defer c.capnp_free_event(&raw);
        return .{ .event = try eventFromC(allocator, raw) };
    }
    return error.UnknownTypeId;
}

fn alignWords(allocator: std.mem.Allocator, bytes: []const u8) ![]align(8) u8 {
    const n = std.mem.alignForward(usize, bytes.len, 8);
    const out = try allocator.alignedAlloc(u8, .@"8", n);
    @memcpy(out[0..bytes.len], bytes);
    if (n > bytes.len) @memset(out[bytes.len..], 0);
    return out;
}

fn cstr(allocator: std.mem.Allocator, s: []const u8) ![*:0]const u8 {
    return (try allocator.dupeZ(u8, s)).ptr;
}

fn zslice(allocator: std.mem.Allocator, p: ?[*:0]const u8) ![]const u8 {
    const s = std.mem.span(p orelse return "");
    return allocator.dupe(u8, s);
}

fn messageToC(allocator: std.mem.Allocator, m: data.Message) !c.CapnpCMessage {
    return .{
        .f_bool = m.f_bool,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = try cstr(allocator, m.f_string),
        .f_bool_2 = m.f_bool_2,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = try cstr(allocator, m.f_string_2),
    };
}

fn documentToC(allocator: std.mem.Allocator, d: data.Document) !c.CapnpCDocument {
    const items = try allocator.alloc(c.CapnpCDocumentItem, d.items.len);
    for (d.items, items) |it, *slot| {
        slot.* = .{
            .sku = try cstr(allocator, it.sku),
            .qty = it.qty,
            .price_minor = it.price_minor,
        };
    }
    return .{
        .id = try cstr(allocator, d.id),
        .status = d.status,
        .meta = .{
            .region = try cstr(allocator, d.meta.region),
            .version = d.meta.version,
        },
        .items = items.ptr,
        .items_count = items.len,
    };
}

fn telemetryToC(allocator: std.mem.Allocator, t: data.Telemetry) !c.CapnpCTelemetry {
    const tags = try allocator.alloc([*c]const u8, t.tags.len);
    for (t.tags, tags) |tag, *slot| slot.* = try cstr(allocator, tag);
    const values = try allocator.dupe(f64, t.values);
    return .{
        .source = try cstr(allocator, t.source),
        .ts = t.ts,
        .tags = tags.ptr,
        .tags_count = tags.len,
        .values = values.ptr,
        .values_count = values.len,
    };
}

fn stringsToC(allocator: std.mem.Allocator, s: data.Strings) !c.CapnpCStrings {
    const items = try allocator.alloc([*c]const u8, s.items.len);
    for (s.items, items) |it, *slot| slot.* = try cstr(allocator, it);
    return .{
        .items = items.ptr,
        .items_count = items.len,
    };
}

fn eventToC(allocator: std.mem.Allocator, e: data.Event) !c.CapnpCEvent {
    const attrs = try allocator.alloc(c.CapnpCEventAttr, e.attrs.len);
    for (e.attrs, attrs) |a, *slot| {
        slot.* = .{
            .key = try cstr(allocator, a.key),
            .value = try cstr(allocator, a.value),
        };
    }
    return .{
        .event_id = try cstr(allocator, e.event_id),
        .event_type = try cstr(allocator, e.event_type),
        .occurred_at = e.occurred_at,
        .producer = try cstr(allocator, e.producer),
        .attrs = attrs.ptr,
        .attrs_count = attrs.len,
    };
}

fn messageFromC(allocator: std.mem.Allocator, m: c.CapnpCMessage) !data.Message {
    return .{
        .f_bool = m.f_bool,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = try zslice(allocator, m.f_string),
        .f_bool_2 = m.f_bool_2,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = try zslice(allocator, m.f_string_2),
    };
}

fn documentFromC(allocator: std.mem.Allocator, d: c.CapnpCDocument) !data.Document {
    const items = try allocator.alloc(data.DocumentItem, d.items_count);
    var i: usize = 0;
    while (i < d.items_count) : (i += 1) {
        const it = d.items[i];
        items[i] = .{
            .sku = try zslice(allocator, it.sku),
            .qty = it.qty,
            .price_minor = it.price_minor,
        };
    }
    return .{
        .id = try zslice(allocator, d.id),
        .status = d.status,
        .meta = .{
            .region = try zslice(allocator, d.meta.region),
            .version = d.meta.version,
        },
        .items = items,
    };
}

fn telemetryFromC(allocator: std.mem.Allocator, t: c.CapnpCTelemetry) !data.Telemetry {
    const tags = try allocator.alloc([]const u8, t.tags_count);
    var i: usize = 0;
    while (i < t.tags_count) : (i += 1) tags[i] = try zslice(allocator, t.tags[i]);
    const values = try allocator.alloc(f64, t.values_count);
    if (t.values_count > 0) @memcpy(values, t.values[0..t.values_count]);
    return .{
        .source = try zslice(allocator, t.source),
        .ts = t.ts,
        .tags = tags,
        .values = values,
    };
}

fn stringsFromC(allocator: std.mem.Allocator, s: c.CapnpCStrings) !data.Strings {
    const items = try allocator.alloc([]const u8, s.items_count);
    var i: usize = 0;
    while (i < s.items_count) : (i += 1) items[i] = try zslice(allocator, s.items[i]);
    return .{ .items = items };
}

fn eventFromC(allocator: std.mem.Allocator, e: c.CapnpCEvent) !data.Event {
    const attrs = try allocator.alloc(data.EventAttr, e.attrs_count);
    var i: usize = 0;
    while (i < e.attrs_count) : (i += 1) {
        attrs[i] = .{
            .key = try zslice(allocator, e.attrs[i].key),
            .value = try zslice(allocator, e.attrs[i].value),
        };
    }
    return .{
        .event_id = try zslice(allocator, e.event_id),
        .event_type = try zslice(allocator, e.event_type),
        .occurred_at = e.occurred_at,
        .producer = try zslice(allocator, e.producer),
        .attrs = attrs,
    };
}
