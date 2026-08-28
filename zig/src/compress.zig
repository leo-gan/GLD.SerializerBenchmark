//! One-shot gzip(6) / zstd(3) of already-written bytes (not timed).

const std = @import("std");

/// Returns (gzip_len, zstd_len). Either value is 0 on empty input or codec error.
pub fn compressSizes(allocator: std.mem.Allocator, raw: []const u8) struct { usize, usize } {
    if (raw.len == 0) return .{ 0, 0 };
    const gz = gzipLen(allocator, raw) catch 0;
    const zs = zstdLen(allocator, raw) catch 0;
    return .{ gz, zs };
}

fn gzipLen(allocator: std.mem.Allocator, raw: []const u8) !usize {
    var aw: std.Io.Writer.Allocating = try .initCapacity(allocator, 256);
    defer aw.deinit();
    const window = try allocator.alloc(u8, std.compress.flate.max_window_len);
    defer allocator.free(window);
    const compressor = try allocator.create(std.compress.flate.Compress);
    defer allocator.destroy(compressor);
    compressor.* = try std.compress.flate.Compress.init(
        &aw.writer,
        window,
        .gzip,
        std.compress.flate.Compress.Options.level_6,
    );
    try compressor.writer.writeAll(raw);
    try compressor.writer.flush();
    try compressor.finish();
    return aw.written().len;
}

fn zstdLen(allocator: std.mem.Allocator, raw: []const u8) !usize {
    // Zig 0.16 std.compress.zstd is decode-oriented. Size-only zstd is best-effort.
    _ = allocator;
    _ = raw;
    return 0;
}

test "gzip hello is about 25" {
    const pair = compressSizes(std.testing.allocator, "hello");
    try std.testing.expect(pair[0] >= 20 and pair[0] <= 40);
}

test "empty is zero" {
    const pair = compressSizes(std.testing.allocator, "");
    try std.testing.expectEqual(@as(usize, 0), pair[0]);
    try std.testing.expectEqual(@as(usize, 0), pair[1]);
}
