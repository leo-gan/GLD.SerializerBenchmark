//! serde.zig format adapters. One API, comptime `@typeInfo` dispatch.

const std = @import("std");
const serde = @import("serde");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

pub const Format = enum { json, msgpack, yaml, toml, zon, xml, csv };

pub fn encode(comptime fmt: Format, fx: data.Fixture, out: *buf_mod.Buf) !void {
    switch (fx) {
        inline else => |payload| {
            const bytes = try toSlice(fmt, out.allocator, payload);
            defer out.allocator.free(bytes);
            try out.appendSlice(bytes);
        },
    }
}

pub fn decode(comptime fmt: Format, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try fromSlice(fmt, data.Message, allocator, bytes) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try fromSlice(fmt, data.Document, allocator, bytes) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try fromSlice(fmt, data.Telemetry, allocator, bytes) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try fromSlice(fmt, data.Strings, allocator, bytes) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try fromSlice(fmt, data.Event, allocator, bytes) };
    }
    return error.UnknownTypeId;
}

fn toSlice(comptime fmt: Format, allocator: std.mem.Allocator, value: anytype) ![]u8 {
    return switch (fmt) {
        .json => serde.json.toSlice(allocator, value),
        .msgpack => serde.msgpack.toSlice(allocator, value),
        .yaml => serde.yaml.toSlice(allocator, value),
        .toml => serde.toml.toSlice(allocator, value),
        .zon => serde.zon.toSlice(allocator, value),
        .xml => serde.xml.toSlice(allocator, value),
        .csv => serde.csv.toSlice(allocator, value),
    };
}

fn fromSlice(comptime fmt: Format, comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    return switch (fmt) {
        .json => serde.json.fromSlice(T, allocator, bytes),
        .msgpack => serde.msgpack.fromSlice(T, allocator, bytes),
        .yaml => serde.yaml.fromSlice(T, allocator, bytes),
        .toml => serde.toml.fromSlice(T, allocator, bytes),
        .zon => serde.zon.fromSlice(T, allocator, bytes),
        .xml => serde.xml.fromSlice(T, allocator, bytes),
        .csv => serde.csv.fromSlice(T, allocator, bytes),
    };
}
