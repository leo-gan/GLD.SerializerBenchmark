//! Helpers for std.json stringify / parse into suite fixtures.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

pub fn stringifyFixture(fx: data.Fixture, out: *buf_mod.Buf) !void {
    var aw: std.Io.Writer.Allocating = .init(out.allocator);
    defer aw.deinit();
    switch (fx) {
        inline else => |payload| {
            try std.json.Stringify.value(payload, .{}, &aw.writer);
        },
    }
    try out.appendSlice(aw.written());
}

pub fn parseFixture(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try std.json.parseFromSliceLeaky(data.Message, allocator, bytes, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try std.json.parseFromSliceLeaky(data.Document, allocator, bytes, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try std.json.parseFromSliceLeaky(data.Telemetry, allocator, bytes, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try std.json.parseFromSliceLeaky(data.Strings, allocator, bytes, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try std.json.parseFromSliceLeaky(data.Event, allocator, bytes, .{
            .allocate = .alloc_always,
        }) };
    }
    return error.UnknownTypeId;
}

pub fn parseFixtureScanner(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = try std.json.parseFromTokenSourceLeaky(data.Message, allocator, &scanner, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        return .{ .document = try std.json.parseFromTokenSourceLeaky(data.Document, allocator, &scanner, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        return .{ .telemetry = try std.json.parseFromTokenSourceLeaky(data.Telemetry, allocator, &scanner, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        return .{ .strings = try std.json.parseFromTokenSourceLeaky(data.Strings, allocator, &scanner, .{
            .allocate = .alloc_always,
        }) };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        return .{ .event = try std.json.parseFromTokenSourceLeaky(data.Event, allocator, &scanner, .{
            .allocate = .alloc_always,
        }) };
    }
    return error.UnknownTypeId;
}
