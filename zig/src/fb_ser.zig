//! FlatBuffers adapter (nDimensional/zig-flatbuffers).
//!
//! Generated types come from the shared suite schema `cpp/schemas/benchmark.fbs`
//! (same file C++, Swift, Kotlin, and Python compile). Prepare stores the
//! suite fixtures. Timed serialize is `Builder.writeTable` / `writeRoot`.
//! Timed deserialize is `decodeRoot` (zero-copy view) plus a domain copy.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const flatbuffers = @import("flatbuffers");
const gen = @import("gen/flatbuffers/benchmark.zig");

const v2 = gen.benchmark.v2;

pub const version = "0.2.1";

pub const State = struct {
    builder: ?flatbuffers.Builder = null,
    encode_arena: std.heap.ArenaAllocator = undefined,
    fixtures: []const data.Fixture = &.{},
    enc_i: usize = 0,
    ready: bool = false,

    fn ensure(self: *State) !void {
        if (self.ready) return;
        self.encode_arena = .init(std.heap.page_allocator);
        self.builder = try flatbuffers.Builder.init(std.heap.page_allocator);
        self.ready = true;
    }

    fn resetBuilder(self: *State) void {
        const b = &(self.builder orelse return);
        if (b.blocks.items.len > 1) {
            for (b.blocks.items[1..]) |block| b.allocator.free(block);
            b.blocks.shrinkRetainingCapacity(1);
        }
        b.offset = 0;
        b.vtable.clearRetainingCapacity();
        b.field_refs.clearRetainingCapacity();
        b.vector_refs.clearRetainingCapacity();
        b.struct_buffer.clearRetainingCapacity();
    }
};

pub var state: State = .{};

pub fn prepare(ctx: *anyopaque, _: std.mem.Allocator, fixtures: []const data.Fixture) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    try self.ensure();
    self.fixtures = fixtures;
    self.enc_i = 0;
}

pub fn beginEncode(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.enc_i = 0;
}

pub fn serialize(ctx: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (self.enc_i < self.fixtures.len) {
        // Prefer the prepared fixture so N>1 stays aligned with prepare.
        _ = self.fixtures[self.enc_i];
    }
    self.enc_i += 1;
    try self.ensure();
    self.resetBuilder();
    _ = self.encode_arena.reset(.retain_capacity);
    var builder = &(self.builder orelse return error.FlatBuffersNotPrepared);
    const aa = self.encode_arena.allocator();
    switch (fx) {
        .message => |m| {
            const ref = try writeMessage(builder, m);
            try builder.writeRoot(v2.Message, ref);
        },
        .document => |d| {
            const ref = try writeDocument(builder, aa, d);
            try builder.writeRoot(v2.Document, ref);
        },
        .telemetry => |t| {
            const ref = try writeTelemetry(builder, t);
            try builder.writeRoot(v2.Telemetry, ref);
        },
        .strings => |s| {
            const ref = try writeStrings(builder, s);
            try builder.writeRoot(v2.Strings, ref);
        },
        .event => |e| {
            const ref = try writeEvent(builder, aa, e);
            try builder.writeRoot(v2.Event, ref);
        },
    }
    var aw: std.Io.Writer.Allocating = .init(aa);
    try builder.write(&aw.writer);
    try out.appendSlice(aw.written());
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    _ = ctx;
    const aligned = try allocator.alignedAlloc(u8, .@"8", bytes.len);
    @memcpy(aligned, bytes);
    if (std.mem.eql(u8, type_id, "message")) {
        const root = try flatbuffers.decodeRoot(v2.Message, aligned);
        return .{ .message = messageFromFb(root) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const root = try flatbuffers.decodeRoot(v2.Document, aligned);
        return .{ .document = try documentFromFb(allocator, root) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const root = try flatbuffers.decodeRoot(v2.Telemetry, aligned);
        return .{ .telemetry = try telemetryFromFb(allocator, root) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const root = try flatbuffers.decodeRoot(v2.Strings, aligned);
        return .{ .strings = try stringsFromFb(allocator, root) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const root = try flatbuffers.decodeRoot(v2.Event, aligned);
        return .{ .event = try eventFromFb(allocator, root) };
    }
    return error.UnknownTypeId;
}

fn writeMessage(builder: *flatbuffers.Builder, m: data.Message) !v2.Message {
    return builder.writeTable(v2.Message, .{
        .f_bool = m.f_bool,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = m.f_string,
        .f_bool_2 = m.f_bool_2,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = m.f_string_2,
    });
}

fn writeDocument(builder: *flatbuffers.Builder, allocator: std.mem.Allocator, d: data.Document) !v2.Document {
    const meta = try builder.writeTable(v2.DocumentMeta, .{
        .region = d.meta.region,
        .version = d.meta.version,
    });
    const items = try allocator.alloc(v2.DocumentItem, d.items.len);
    for (d.items, items) |it, *slot| {
        slot.* = try builder.writeTable(v2.DocumentItem, .{
            .sku = it.sku,
            .qty = it.qty,
            .price_minor = it.price_minor,
        });
    }
    return builder.writeTable(v2.Document, .{
        .id = d.id,
        .status = d.status,
        .meta = meta,
        .items = items,
    });
}

fn writeTelemetry(builder: *flatbuffers.Builder, t: data.Telemetry) !v2.Telemetry {
    return builder.writeTable(v2.Telemetry, .{
        .source = t.source,
        .ts = t.ts,
        .tags = t.tags,
        .values = t.values,
    });
}

fn writeStrings(builder: *flatbuffers.Builder, s: data.Strings) !v2.Strings {
    return builder.writeTable(v2.Strings, .{
        .items = s.items,
    });
}

fn writeEvent(builder: *flatbuffers.Builder, allocator: std.mem.Allocator, e: data.Event) !v2.Event {
    const attrs = try allocator.alloc(v2.EventAttr, e.attrs.len);
    for (e.attrs, attrs) |a, *slot| {
        slot.* = try builder.writeTable(v2.EventAttr, .{
            .key = a.key,
            .value = a.value,
        });
    }
    return builder.writeTable(v2.Event, .{
        .event_id = e.event_id,
        .event_type = e.event_type,
        .occurred_at = e.occurred_at,
        .producer = e.producer,
        .attrs = attrs,
    });
}

fn optStr(s: ?[]const u8) []const u8 {
    return s orelse "";
}

fn messageFromFb(m: v2.Message) data.Message {
    return .{
        .f_bool = m.f_bool(),
        .f_int32 = m.f_int32(),
        .f_int64 = m.f_int64(),
        .f_float64 = m.f_float64(),
        .f_string = optStr(m.f_string()),
        .f_bool_2 = m.f_bool_2(),
        .f_int32_2 = m.f_int32_2(),
        .f_string_2 = optStr(m.f_string_2()),
    };
}

fn documentFromFb(allocator: std.mem.Allocator, d: v2.Document) !data.Document {
    const meta = d.meta();
    var items: []data.DocumentItem = &.{};
    if (d.items()) |vec| {
        items = try allocator.alloc(data.DocumentItem, vec.len());
        var i: usize = 0;
        while (i < vec.len()) : (i += 1) {
            const it = vec.get(i);
            items[i] = .{
                .sku = optStr(it.sku()),
                .qty = it.qty(),
                .price_minor = it.price_minor(),
            };
        }
    }
    return .{
        .id = optStr(d.id()),
        .status = d.status(),
        .meta = .{
            .region = if (meta) |m| optStr(m.region()) else "",
            .version = if (meta) |m| m.version() else 0,
        },
        .items = items,
    };
}

fn telemetryFromFb(allocator: std.mem.Allocator, t: v2.Telemetry) !data.Telemetry {
    var tags: [][]const u8 = &.{};
    if (t.tags()) |vec| {
        tags = try allocator.alloc([]const u8, vec.len());
        var i: usize = 0;
        while (i < vec.len()) : (i += 1) tags[i] = vec.get(i);
    }
    var values: []f64 = &.{};
    if (t.values()) |vec| {
        values = try allocator.alloc(f64, vec.len());
        var i: usize = 0;
        while (i < vec.len()) : (i += 1) values[i] = vec.get(i);
    }
    return .{
        .source = optStr(t.source()),
        .ts = t.ts(),
        .tags = tags,
        .values = values,
    };
}

fn stringsFromFb(allocator: std.mem.Allocator, s: v2.Strings) !data.Strings {
    var items: [][]const u8 = &.{};
    if (s.items()) |vec| {
        items = try allocator.alloc([]const u8, vec.len());
        var i: usize = 0;
        while (i < vec.len()) : (i += 1) items[i] = vec.get(i);
    }
    return .{ .items = items };
}

fn eventFromFb(allocator: std.mem.Allocator, e: v2.Event) !data.Event {
    var attrs: []data.EventAttr = &.{};
    if (e.attrs()) |vec| {
        attrs = try allocator.alloc(data.EventAttr, vec.len());
        var i: usize = 0;
        while (i < vec.len()) : (i += 1) {
            const a = vec.get(i);
            attrs[i] = .{
                .key = optStr(a.key()),
                .value = optStr(a.value()),
            };
        }
    }
    return .{
        .event_id = optStr(e.event_id()),
        .event_type = optStr(e.event_type()),
        .occurred_at = e.occurred_at(),
        .producer = optStr(e.producer()),
        .attrs = attrs,
    };
}
