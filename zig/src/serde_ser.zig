//! serde.zig format adapters. One API, comptime `@typeInfo` dispatch.

const std = @import("std");
const serde = @import("serde");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");

pub const Format = enum { json, json_borrowed, msgpack, yaml, toml, zon, xml, csv };

/// serde's own `toSlice` is `toWriter` into an `Allocating` writer, so writing
/// straight into the runner's reusable buffer is the same code path minus a
/// per-call allocation, copy and free.
pub fn encode(comptime fmt: Format, fx: data.Fixture, out: *buf_mod.Buf) !void {
    var writer = out.takeWriter();
    defer out.restoreWriter(&writer);
    switch (fx) {
        inline else => |payload| try toWriter(fmt, out.allocator, &writer.writer, payload),
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

fn toWriter(comptime fmt: Format, allocator: std.mem.Allocator, writer: *std.Io.Writer, value: anytype) !void {
    return switch (fmt) {
        .json, .json_borrowed => serde.json.toWriter(writer, value),
        .msgpack => serde.msgpack.toWriter(allocator, writer, value),
        .yaml => serde.yaml.toWriter(writer, value),
        .toml => serde.toml.toWriter(allocator, writer, value),
        .zon => serde.zon.toWriter(writer, value),
        .xml => serde.xml.toWriter(writer, value),
        .csv => serde.csv.toWriter(writer, value),
    };
}

fn fromSlice(comptime fmt: Format, comptime T: type, allocator: std.mem.Allocator, bytes: []const u8) !T {
    return switch (fmt) {
        .json => serde.json.fromSlice(T, allocator, bytes),
        .json_borrowed => serde.json.fromSliceBorrowed(T, allocator, bytes),
        .msgpack => serde.msgpack.fromSlice(T, allocator, bytes),
        .yaml => serde.yaml.fromSlice(T, allocator, bytes),
        .toml => serde.toml.fromSlice(T, allocator, bytes),
        .zon => serde.zon.fromSlice(T, allocator, bytes),
        .xml => serde.xml.fromSlice(T, allocator, bytes),
        .csv => serde.csv.fromSlice(T, allocator, bytes),
    };
}

test "writer output matches toSlice and reuses the buffer allocation" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    inline for (.{ Format.json, Format.msgpack, Format.yaml, Format.toml, Format.zon, Format.xml }) |fmt| {
        var out = try buf_mod.Buf.initCapacity(std.testing.allocator, 1);
        defer out.deinit();
        for ([_]i32{ 1, 128, 2, 0 }) |size| {
            const fx = try data.makeOne(arena.allocator(), "document", 7, size, .{ .children = size });
            const reference = try @field(serde, @tagName(fmt)).toSlice(std.testing.allocator, fx.document);
            defer std.testing.allocator.free(reference);
            out.clear();
            try out.appendSlice("prefix");
            try encode(fmt, fx, &out);
            try std.testing.expectEqualStrings("prefix", out.items()[0..6]);
            try std.testing.expectEqualSlices(u8, reference, out.items()[6..]);
            const capacity = out.data.len;
            const allocation = out.data.ptr;
            out.clear();
            try encode(fmt, fx, &out);
            try std.testing.expectEqualSlices(u8, reference, out.items());
            try std.testing.expectEqual(capacity, out.data.len);
            try std.testing.expectEqual(allocation, out.data.ptr);
        }
    }
}

test "every format round-trips the fixtures it claims to support" {
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    inline for (.{ Format.json, Format.msgpack, Format.yaml, Format.toml, Format.zon, Format.xml }) |fmt| {
        for (kinds) |kind| {
            for ([_]i32{ 0, 1, 32 }) |size| {
                var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
                defer arena.deinit();
                const fx = try data.makeOne(arena.allocator(), kind, 42, 0, .{
                    .children = size,
                    .points = size,
                    .count = size,
                    .attr_count = size,
                });
                var out = try buf_mod.Buf.initCapacity(std.testing.allocator, 1);
                defer out.deinit();
                try encode(fmt, fx, &out);
                const decoded = decode(fmt, arena.allocator(), kind, out.items());
                // Shapes serde 1.2.1 cannot round-trip stay visible as errors.
                // Never substitute a default or drop a field to get a timing.
                const nested = fx == .document or fx == .event;
                if (fmt == .yaml and (nested or (size == 0 and fx != .message))) {
                    try std.testing.expectError(if (size == 0) error.WrongType else error.MissingField, decoded);
                } else if (fmt == .toml and size == 0 and nested) {
                    try std.testing.expectError(error.MissingField, decoded);
                } else {
                    try std.testing.expect(data.fidelity(fx, try decoded));
                }
            }
        }
    }
}

test "owned and borrowed JSON rows agree on every fixture" {
    const json_util = @import("json_util.zig");
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    var out = try buf_mod.Buf.initCapacity(std.testing.allocator, 1);
    defer out.deinit();
    for (kinds) |kind| {
        for (0..3) |index| {
            var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
            defer arena.deinit();
            const fx = try data.makeOne(arena.allocator(), kind, 42, @intCast(index), .{});
            inline for (.{ false, true }) |standard| {
                out.clear();
                if (standard) try json_util.stringifyFixture(fx, &out) else try encode(.json, fx, &out);
                // Read each writer's bytes with both libraries and both ownership modes.
                const serde_owned = try decode(.json, arena.allocator(), kind, out.items());
                const serde_borrowed = try decode(.json_borrowed, arena.allocator(), kind, out.items());
                const std_owned = try json_util.parseFixture(arena.allocator(), kind, out.items());
                const std_borrowed = try json_util.parseFixtureBorrowed(arena.allocator(), kind, out.items());
                inline for (.{ serde_owned, serde_borrowed, std_owned, std_borrowed }) |back| {
                    try std.testing.expect(data.fidelity(fx, back));
                }
                try expectStringOwnership(serde_owned, out.items(), false);
                try expectStringOwnership(std_owned, out.items(), false);
                try expectStringOwnership(serde_borrowed, out.items(), true);
                try expectStringOwnership(std_borrowed, out.items(), true);
                // Owned results must survive the input buffer being overwritten.
                @memset(out.data[0..out.len], 0);
                try std.testing.expect(data.fidelity(fx, serde_owned));
                try std.testing.expect(data.fidelity(fx, std_owned));
            }
        }
    }
}

fn expectStringOwnership(value: anytype, input: []const u8, borrowed: bool) !void {
    switch (@typeInfo(@TypeOf(value))) {
        .@"union" => switch (value) {
            inline else => |payload| try expectStringOwnership(payload, input, borrowed),
        },
        .@"struct" => |info| inline for (info.fields) |field| {
            try expectStringOwnership(@field(value, field.name), input, borrowed);
        },
        .pointer => |info| {
            if (info.size != .slice) return;
            if (info.child != u8) {
                for (value) |item| try expectStringOwnership(item, input, borrowed);
                return;
            }
            if (value.len == 0) return;
            const start = @intFromPtr(value.ptr);
            const input_start = @intFromPtr(input.ptr);
            const aliases = start >= input_start and start + value.len <= input_start + input.len;
            try std.testing.expectEqual(borrowed, aliases);
        },
        else => {},
    }
}

test "the borrowed JSON row is a view, not a fallback" {
    const json_util = @import("json_util.zig");
    const fx: data.Fixture = .{ .message = .{
        .f_bool = true,
        .f_int32 = std.math.minInt(i32),
        .f_int64 = std.math.maxInt(i64),
        .f_float64 = -123.125,
        .f_string = "日本語",
        .f_bool_2 = false,
        .f_int32_2 = std.math.maxInt(i32),
        .f_string_2 = "quote\" slash\\ newline\n tab\t nul\x00",
    } };
    var out = try buf_mod.Buf.initCapacity(std.testing.allocator, 1);
    defer out.deinit();
    inline for (.{ false, true }) |standard| {
        out.clear();
        if (standard) try json_util.stringifyFixture(fx, &out) else try encode(.json, fx, &out);
        var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
        defer arena.deinit();
        // serde's borrowed API is strictly a view and rejects escaped strings,
        // while std.json's alloc_if_needed allocates to unescape. The timed
        // adapter must not paper over that with a fallback.
        try std.testing.expectError(error.InvalidEscape, decode(.json_borrowed, arena.allocator(), "message", out.items()));
        const serde_back = try decode(.json, arena.allocator(), "message", out.items());
        const std_back = try json_util.parseFixtureBorrowed(arena.allocator(), "message", out.items());
        try std.testing.expect(data.fidelity(fx, serde_back));
        try std.testing.expect(data.fidelity(fx, std_back));
        try expectStringOwnership(serde_back, out.items(), false);
        try expectStringOwnership(std_back.message.f_string, out.items(), true);
        try expectStringOwnership(std_back.message.f_string_2, out.items(), false);
    }
}
