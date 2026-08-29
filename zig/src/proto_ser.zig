//! Protocol Buffers adapter (Arwalk/zig-protobuf).
//!
//! Generated types come from the shared suite schema
//! `schemas/v2/protobuf/benchmark_v2.proto` (same file Go/PHP/Rust/Python
//! compile). Prepare copies suite fixtures into those messages (untimed).
//! Timed serialize/deserialize call only `encode` / `decode`.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const pb = @import("gen/benchmark/v2.pb.zig");

pub const version = "5.0.0";

const Prepared = union(enum) {
    none,
    message: []pb.Message,
    document: []pb.Document,
    telemetry: []pb.Telemetry,
    strings: []pb.Strings,
    event: []pb.Event,
};

pub const State = struct {
    arena: std.heap.ArenaAllocator = undefined,
    encode_arena: std.heap.ArenaAllocator = undefined,
    prepared: Prepared = .none,
    enc_i: usize = 0,
    ready: bool = false,

    fn ensure(self: *State) void {
        if (self.ready) return;
        // Process-lifetime child: test arenas die between cases; the runner
        // GPA is also not guaranteed to outlive a later prepare.
        self.arena = .init(std.heap.page_allocator);
        self.encode_arena = .init(std.heap.page_allocator);
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
            const out = try aa.alloc(pb.Message, fixtures.len);
            for (fixtures, out) |fx, *slot| {
                slot.* = messageToPb(fx.message);
            }
            break :blk .{ .message = out };
        },
        .document => blk: {
            const out = try aa.alloc(pb.Document, fixtures.len);
            for (fixtures, out) |fx, *slot| {
                slot.* = try documentToPb(aa, fx.document);
            }
            break :blk .{ .document = out };
        },
        .telemetry => blk: {
            const out = try aa.alloc(pb.Telemetry, fixtures.len);
            for (fixtures, out) |fx, *slot| {
                slot.* = try telemetryToPb(aa, fx.telemetry);
            }
            break :blk .{ .telemetry = out };
        },
        .strings => blk: {
            const out = try aa.alloc(pb.Strings, fixtures.len);
            for (fixtures, out) |fx, *slot| {
                slot.* = try stringsToPb(aa, fx.strings);
            }
            break :blk .{ .strings = out };
        },
        .event => blk: {
            const out = try aa.alloc(pb.Event, fixtures.len);
            for (fixtures, out) |fx, *slot| {
                slot.* = try eventToPb(aa, fx.event);
            }
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
    _ = self.encode_arena.reset(.retain_capacity);
    const ea = self.encode_arena.allocator();
    switch (self.prepared) {
        .none => return error.ProtobufNotPrepared,
        .message => |v| try encodeMsg(ea, v[i], out),
        .document => |v| try encodeMsg(ea, v[i], out),
        .telemetry => |v| try encodeMsg(ea, v[i], out),
        .strings => |v| try encodeMsg(ea, v[i], out),
        .event => |v| try encodeMsg(ea, v[i], out),
    }
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    _ = ctx;
    var reader = std.Io.Reader.fixed(bytes);
    if (std.mem.eql(u8, type_id, "message")) {
        const msg = try pb.Message.decode(&reader, allocator);
        return .{ .message = messageFromPb(msg) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const msg = try pb.Document.decode(&reader, allocator);
        return .{ .document = try documentFromPb(allocator, msg) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const msg = try pb.Telemetry.decode(&reader, allocator);
        return .{ .telemetry = try telemetryFromPb(allocator, msg) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const msg = try pb.Strings.decode(&reader, allocator);
        return .{ .strings = try stringsFromPb(allocator, msg) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const msg = try pb.Event.decode(&reader, allocator);
        return .{ .event = try eventFromPb(allocator, msg) };
    }
    return error.UnknownTypeId;
}

fn encodeMsg(allocator: std.mem.Allocator, msg: anytype, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(allocator);
    defer aw.deinit();
    try msg.encode(&aw.writer, allocator);
    try out.appendSlice(aw.written());
}

fn messageToPb(m: data.Message) pb.Message {
    return .{
        .f_bool = m.f_bool,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = m.f_string,
        .f_bool_2 = m.f_bool_2,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = m.f_string_2,
    };
}

fn messageFromPb(m: pb.Message) data.Message {
    return .{
        .f_bool = m.f_bool,
        .f_int32 = m.f_int32,
        .f_int64 = m.f_int64,
        .f_float64 = m.f_float64,
        .f_string = m.f_string,
        .f_bool_2 = m.f_bool_2,
        .f_int32_2 = m.f_int32_2,
        .f_string_2 = m.f_string_2,
    };
}

fn documentToPb(allocator: std.mem.Allocator, d: data.Document) !pb.Document {
    var items: std.ArrayList(pb.DocumentItem) = .empty;
    try items.ensureTotalCapacity(allocator, d.items.len);
    for (d.items) |it| {
        items.appendAssumeCapacity(.{
            .sku = it.sku,
            .qty = it.qty,
            .price_minor = it.price_minor,
        });
    }
    return .{
        .id = d.id,
        .status = d.status,
        .meta = .{ .region = d.meta.region, .version = d.meta.version },
        .items = items,
    };
}

fn documentFromPb(allocator: std.mem.Allocator, d: pb.Document) !data.Document {
    const meta = d.meta orelse pb.DocumentMeta{};
    const items = try allocator.alloc(data.DocumentItem, d.items.items.len);
    for (d.items.items, items) |it, *dst| {
        dst.* = .{
            .sku = it.sku,
            .qty = it.qty,
            .price_minor = it.price_minor,
        };
    }
    return .{
        .id = d.id,
        .status = d.status,
        .meta = .{ .region = meta.region, .version = meta.version },
        .items = items,
    };
}

fn telemetryToPb(allocator: std.mem.Allocator, t: data.Telemetry) !pb.Telemetry {
    var tags: std.ArrayList([]const u8) = .empty;
    try tags.ensureTotalCapacity(allocator, t.tags.len);
    for (t.tags) |tag| tags.appendAssumeCapacity(tag);
    var values: std.ArrayList(f64) = .empty;
    try values.ensureTotalCapacity(allocator, t.values.len);
    for (t.values) |v| values.appendAssumeCapacity(v);
    return .{
        .source = t.source,
        .ts = t.ts,
        .tags = tags,
        .values = values,
    };
}

fn telemetryFromPb(allocator: std.mem.Allocator, t: pb.Telemetry) !data.Telemetry {
    const tags = try allocator.alloc([]const u8, t.tags.items.len);
    @memcpy(tags, t.tags.items);
    const values = try allocator.alloc(f64, t.values.items.len);
    @memcpy(values, t.values.items);
    return .{
        .source = t.source,
        .ts = t.ts,
        .tags = tags,
        .values = values,
    };
}

fn stringsToPb(allocator: std.mem.Allocator, s: data.Strings) !pb.Strings {
    var items: std.ArrayList([]const u8) = .empty;
    try items.ensureTotalCapacity(allocator, s.items.len);
    for (s.items) |it| items.appendAssumeCapacity(it);
    return .{ .items = items };
}

fn stringsFromPb(allocator: std.mem.Allocator, s: pb.Strings) !data.Strings {
    const items = try allocator.alloc([]const u8, s.items.items.len);
    @memcpy(items, s.items.items);
    return .{ .items = items };
}

fn eventToPb(allocator: std.mem.Allocator, e: data.Event) !pb.Event {
    var attrs: std.ArrayList(pb.EventAttr) = .empty;
    try attrs.ensureTotalCapacity(allocator, e.attrs.len);
    for (e.attrs) |a| {
        attrs.appendAssumeCapacity(.{ .key = a.key, .value = a.value });
    }
    return .{
        .event_id = e.event_id,
        .event_type = e.event_type,
        .occurred_at = e.occurred_at,
        .producer = e.producer,
        .attrs = attrs,
    };
}

fn eventFromPb(allocator: std.mem.Allocator, e: pb.Event) !data.Event {
    const attrs = try allocator.alloc(data.EventAttr, e.attrs.items.len);
    for (e.attrs.items, attrs) |a, *dst| {
        dst.* = .{ .key = a.key, .value = a.value };
    }
    return .{
        .event_id = e.event_id,
        .event_type = e.event_type,
        .occurred_at = e.occurred_at,
        .producer = e.producer,
        .attrs = attrs,
    };
}
