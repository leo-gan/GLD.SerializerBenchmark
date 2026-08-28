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
        const parsed = try std.json.parseFromSlice(data.Message, allocator, bytes, .{
            .allocate = .alloc_always,
        });
        return .{ .message = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const parsed = try std.json.parseFromSlice(data.Document, allocator, bytes, .{
            .allocate = .alloc_always,
        });
        return .{ .document = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const parsed = try std.json.parseFromSlice(data.Telemetry, allocator, bytes, .{
            .allocate = .alloc_always,
        });
        return .{ .telemetry = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const parsed = try std.json.parseFromSlice(data.Strings, allocator, bytes, .{
            .allocate = .alloc_always,
        });
        return .{ .strings = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const parsed = try std.json.parseFromSlice(data.Event, allocator, bytes, .{
            .allocate = .alloc_always,
        });
        return .{ .event = parsed.value };
    }
    return error.UnknownTypeId;
}

pub fn parseFixtureScanner(allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    var scanner = std.json.Scanner.initCompleteInput(allocator, bytes);
    defer scanner.deinit();
    if (std.mem.eql(u8, type_id, "message")) {
        const parsed = try std.json.parseFromTokenSource(data.Message, allocator, &scanner, .{
            .allocate = .alloc_always,
        });
        return .{ .message = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const parsed = try std.json.parseFromTokenSource(data.Document, allocator, &scanner, .{
            .allocate = .alloc_always,
        });
        return .{ .document = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const parsed = try std.json.parseFromTokenSource(data.Telemetry, allocator, &scanner, .{
            .allocate = .alloc_always,
        });
        return .{ .telemetry = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const parsed = try std.json.parseFromTokenSource(data.Strings, allocator, &scanner, .{
            .allocate = .alloc_always,
        });
        return .{ .strings = parsed.value };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const parsed = try std.json.parseFromTokenSource(data.Event, allocator, &scanner, .{
            .allocate = .alloc_always,
        });
        return .{ .event = parsed.value };
    }
    return error.UnknownTypeId;
}
