//! Mixed-list third-party adapters (typed official APIs).

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const zig_msgpack = @import("zig_msgpack");
const zbor = @import("zbor");
const msgpack_l = @import("msgpack_lalinsky");
const s2s = @import("s2s");

fn withZ(allocator: std.mem.Allocator, bytes: []const u8) ![:0]u8 {
    return allocator.dupeZ(u8, bytes);
}

pub fn encodeStdZon(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    switch (fx) {
        inline else => |payload| {
            try std.zon.stringify.serialize(payload, .{ .whitespace = false }, &aw.writer);
        },
    }
    try out.appendSlice(aw.written());
}

pub fn decodeStdZon(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    const z = try withZ(allocator, bytes);
    return decodeZonSlice(allocator, type_id, z);
}

fn decodeZonSlice(allocator: std.mem.Allocator, type_id: []const u8, z: [:0]const u8) !data.Fixture {
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try std.zon.parse.fromSliceAlloc(data.Message, allocator, z, null, .{}) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try std.zon.parse.fromSliceAlloc(data.Document, allocator, z, null, .{}) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try std.zon.parse.fromSliceAlloc(data.Telemetry, allocator, z, null, .{}) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try std.zon.parse.fromSliceAlloc(data.Strings, allocator, z, null, .{}) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try std.zon.parse.fromSliceAlloc(data.Event, allocator, z, null, .{}) };
    }
    return error.UnknownTypeId;
}

pub fn encodeZbor(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    const opts = zbor.Options{ .slice_serialization_type = .TextString };
    switch (fx) {
        inline else => |payload| try zbor.stringify(payload, opts, &aw.writer),
    }
    try out.appendSlice(aw.written());
}

pub fn decodeZbor(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    const item = try zbor.DataItem.new(bytes);
    const opts = zbor.Options{ .allocator = allocator, .slice_serialization_type = .TextString };
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try zbor.parse(data.Message, item, opts) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try zbor.parse(data.Document, item, opts) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try zbor.parse(data.Telemetry, item, opts) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try zbor.parse(data.Strings, item, opts) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try zbor.parse(data.Event, item, opts) };
    }
    return error.UnknownTypeId;
}

pub fn encodeLalinsky(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    switch (fx) {
        inline else => |payload| try msgpack_l.encode(payload, &aw.writer),
    }
    try out.appendSlice(aw.written());
}

pub fn decodeLalinsky(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    if (std.mem.eql(u8, type_id, "message")) {
        const parsed = try msgpack_l.decodeFromSlice(data.Message, allocator, bytes);
        return .{ .message = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const parsed = try msgpack_l.decodeFromSlice(data.Document, allocator, bytes);
        return .{ .document = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const parsed = try msgpack_l.decodeFromSlice(data.Telemetry, allocator, bytes);
        return .{ .telemetry = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const parsed = try msgpack_l.decodeFromSlice(data.Strings, allocator, bytes);
        return .{ .strings = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const parsed = try msgpack_l.decodeFromSlice(data.Event, allocator, bytes);
        return .{ .event = parsed.value };
    }
    return error.UnknownTypeId;
}

pub fn encodeS2s(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    switch (fx) {
        inline else => |payload| try s2s.serialize(&aw.writer, @TypeOf(payload), payload),
    }
    try out.appendSlice(aw.written());
}

pub fn decodeS2s(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    var reader = std.Io.Reader.fixed(bytes);
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try s2s.deserializeAlloc(&reader, data.Message, allocator) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try s2s.deserializeAlloc(&reader, data.Document, allocator) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try s2s.deserializeAlloc(&reader, data.Telemetry, allocator) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try s2s.deserializeAlloc(&reader, data.Strings, allocator) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try s2s.deserializeAlloc(&reader, data.Event, allocator) };
    }
    return error.UnknownTypeId;
}

fn toPayload(allocator: std.mem.Allocator, value: anytype) !zig_msgpack.Payload {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .bool => return zig_msgpack.Payload.boolToPayload(value),
        .int => |info| {
            if (info.signedness == .signed) {
                return zig_msgpack.Payload.intToPayload(@intCast(value));
            }
            return zig_msgpack.Payload.uintToPayload(@intCast(value));
        },
        .float => return zig_msgpack.Payload.floatToPayload(@floatCast(value)),
        .pointer => |info| {
            if (info.size == .slice and info.child == u8) {
                return zig_msgpack.Payload.strToPayload(value, allocator);
            }
            if (info.size == .slice) {
                var arr = try zig_msgpack.Payload.arrPayload(value.len, allocator);
                for (value, 0..) |item, i| {
                    try arr.setArrElement(i, try toPayload(allocator, item));
                }
                return arr;
            }
        },
        .@"struct" => |info| {
            var map = zig_msgpack.Payload.mapPayload(allocator);
            inline for (info.fields) |field| {
                try map.mapPut(field.name, try toPayload(allocator, @field(value, field.name)));
            }
            return map;
        },
        else => {},
    }
    return error.UnsupportedPayload;
}

fn fromPayload(comptime T: type, allocator: std.mem.Allocator, p: zig_msgpack.Payload) !T {
    switch (@typeInfo(T)) {
        .bool => return p.bool,
        .int => {
            switch (p) {
                .int => |v| return @intCast(v),
                .uint => |v| return @intCast(v),
                else => return error.BadPayload,
            }
        },
        .float => return switch (p) {
            .float => |v| @floatCast(v),
            .int => |v| @floatFromInt(v),
            .uint => |v| @floatFromInt(v),
            else => error.BadPayload,
        },
        .pointer => |info| {
            if (info.size == .slice and info.child == u8) {
                return allocator.dupe(u8, p.str.value());
            }
            if (info.size == .slice) {
                const arr = p.arr;
                const out = try allocator.alloc(info.child, arr.len);
                for (arr, out) |item, *dst| {
                    dst.* = try fromPayload(info.child, allocator, item);
                }
                return out;
            }
        },
        .@"struct" => |info| {
            var out: T = undefined;
            inline for (info.fields) |field| {
                const child = (try p.mapGet(field.name)) orelse return error.MissingField;
                @field(out, field.name) = try fromPayload(field.type, allocator, child);
            }
            return out;
        },
        else => {},
    }
    return error.UnsupportedPayload;
}

pub fn encodeZigMsgpack(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var arena = std.heap.ArenaAllocator.init(out.allocator);
    defer arena.deinit();
    const payload = switch (fx) {
        inline else => |v| try toPayload(arena.allocator(), v),
    };
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    var dummy: [1]u8 = undefined;
    var reader = std.Io.Reader.fixed(dummy[0..0]);
    var packer = zig_msgpack.PackerIO.init(&reader, &aw.writer);
    try packer.write(payload);
    try out.appendSlice(aw.written());
}

pub fn decodeZigMsgpack(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    var dummy_w: [1]u8 = undefined;
    var writer = std.Io.Writer.fixed(&dummy_w);
    var reader = std.Io.Reader.fixed(bytes);
    var packer = zig_msgpack.PackerIO.init(&reader, &writer);
    const payload = try packer.read(allocator);
    defer payload.free(allocator);
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try fromPayload(data.Message, allocator, payload) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try fromPayload(data.Document, allocator, payload) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try fromPayload(data.Telemetry, allocator, payload) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try fromPayload(data.Strings, allocator, payload) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try fromPayload(data.Event, allocator, payload) };
    }
    return error.UnknownTypeId;
}
