//! Idiomatic Zig comptime byte-packed serializer.
//!
//! Walks `@typeInfo` at comptime: bool as u8, ints/floats little-endian,
//! `[]const u8` as u32 LE length + bytes, slices as u32 LE count + items,
//! structs field-by-field. This is the suite stand-in for "raw @bitCast packed
//! struct streams": a live fixture has slices, so a literal `@bitCast` of the
//! whole value is not a defined encoding.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

pub fn encodeFixture(fx: data.Fixture, out: *buf_mod.Buf) !void {
    switch (fx) {
        inline else => |payload| try encodeAny(payload, out),
    }
}

pub fn decodeFixture(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    var cur: usize = 0;
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try decodeAny(data.Message, allocator, bytes, &cur) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try decodeAny(data.Document, allocator, bytes, &cur) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try decodeAny(data.Telemetry, allocator, bytes, &cur) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try decodeAny(data.Strings, allocator, bytes, &cur) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try decodeAny(data.Event, allocator, bytes, &cur) };
    }
    return error.UnknownTypeId;
}

fn encodeAny(value: anytype, out: *buf_mod.Buf) !void {
    const T = @TypeOf(value);
    switch (@typeInfo(T)) {
        .bool => try out.appendByte(if (value) 1 else 0),
        .int => |info| {
            const Unsigned = std.meta.Int(.unsigned, info.bits);
            try out.appendInt(Unsigned, @bitCast(value));
        },
        .float => |info| {
            const Unsigned = std.meta.Int(.unsigned, info.bits);
            try out.appendInt(Unsigned, @bitCast(value));
        },
        .pointer => |info| {
            if (info.size == .slice) {
                if (info.child == u8) {
                    try out.appendInt(u32, @intCast(value.len));
                    try out.appendSlice(value);
                } else {
                    try out.appendInt(u32, @intCast(value.len));
                    for (value) |item| try encodeAny(item, out);
                }
            } else {
                @compileError("unsupported pointer in comptime-bin");
            }
        },
        .array => {
            try out.appendInt(u32, @intCast(value.len));
            for (value) |item| try encodeAny(item, out);
        },
        .@"struct" => |info| {
            inline for (info.fields) |field| {
                try encodeAny(@field(value, field.name), out);
            }
        },
        else => @compileError("unsupported type in comptime-bin: " ++ @typeName(T)),
    }
}

fn decodeAny(comptime T: type, allocator: std.mem.Allocator, bytes: []const u8, cur: *usize) !T {
    switch (@typeInfo(T)) {
        .bool => {
            if (cur.* >= bytes.len) return error.Truncated;
            const b = bytes[cur.*];
            cur.* += 1;
            return b != 0;
        },
        .int => |info| {
            const Unsigned = std.meta.Int(.unsigned, info.bits);
            const n = @sizeOf(Unsigned);
            if (cur.* + n > bytes.len) return error.Truncated;
            const raw = std.mem.readInt(Unsigned, bytes[cur.*..][0..n], .little);
            cur.* += n;
            return @bitCast(raw);
        },
        .float => |info| {
            const Unsigned = std.meta.Int(.unsigned, info.bits);
            const n = @sizeOf(Unsigned);
            if (cur.* + n > bytes.len) return error.Truncated;
            const raw = std.mem.readInt(Unsigned, bytes[cur.*..][0..n], .little);
            cur.* += n;
            return @bitCast(raw);
        },
        .pointer => |info| {
            if (info.size != .slice) return error.Unsupported;
            if (cur.* + 4 > bytes.len) return error.Truncated;
            const len = std.mem.readInt(u32, bytes[cur.*..][0..4], .little);
            cur.* += 4;
            if (info.child == u8) {
                if (cur.* + len > bytes.len) return error.Truncated;
                const slice = try allocator.dupe(u8, bytes[cur.* .. cur.* + len]);
                cur.* += len;
                return slice;
            } else {
                const arr = try allocator.alloc(info.child, len);
                for (arr) |*item| {
                    item.* = try decodeAny(info.child, allocator, bytes, cur);
                }
                return arr;
            }
        },
        .@"struct" => |info| {
            var out: T = undefined;
            inline for (info.fields) |field| {
                @field(out, field.name) = try decodeAny(field.type, allocator, bytes, cur);
            }
            return out;
        },
        else => @compileError("unsupported type in comptime-bin: " ++ @typeName(T)),
    }
}
