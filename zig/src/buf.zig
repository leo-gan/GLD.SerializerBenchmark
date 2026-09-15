//! Runner-owned growable byte buffer. Capacity is reused across repetitions.

const std = @import("std");

pub const Buf = struct {
    allocator: std.mem.Allocator,
    data: []u8,
    len: usize,

    pub fn initCapacity(allocator: std.mem.Allocator, cap: usize) !Buf {
        return .{
            .allocator = allocator,
            .data = try allocator.alloc(u8, cap),
            .len = 0,
        };
    }

    pub fn deinit(self: *Buf) void {
        self.allocator.free(self.data);
        self.* = undefined;
    }

    pub fn clear(self: *Buf) void {
        self.len = 0;
    }

    pub fn items(self: *const Buf) []const u8 {
        return self.data[0..self.len];
    }

    /// Lend the allocation to a growable writer without copying or shrinking,
    /// so a library that writes to `std.Io.Writer` fills this buffer directly
    /// instead of allocating a slice the runner then copies and frees.
    /// Pair with `restoreWriter` in a defer, including on the error path.
    /// Do not touch this Buf until the writer has been restored.
    pub fn takeWriter(self: *Buf) std.Io.Writer.Allocating {
        var writer: std.Io.Writer.Allocating = .initOwnedSlice(self.allocator, self.data);
        writer.writer.end = self.len;
        self.data = &.{};
        self.len = 0;
        return writer;
    }

    /// Take the (possibly grown) allocation back. Always runs, so a failed
    /// serialization still leaves the capacity with the Buf.
    pub fn restoreWriter(self: *Buf, writer: *std.Io.Writer.Allocating) void {
        std.debug.assert(self.data.len == 0 and self.len == 0);
        var list = writer.toArrayList();
        self.data = list.allocatedSlice();
        self.len = list.items.len;
    }

    pub fn ensure(self: *Buf, need: usize) !void {
        if (need <= self.data.len) return;
        var cap = if (self.data.len == 0) 64 else self.data.len;
        while (cap < need) {
            cap *|= 2;
        }
        self.data = try self.allocator.realloc(self.data, cap);
    }

    pub fn appendSlice(self: *Buf, s: []const u8) !void {
        try self.ensure(self.len + s.len);
        @memcpy(self.data[self.len..][0..s.len], s);
        self.len += s.len;
    }

    pub fn appendByte(self: *Buf, b: u8) !void {
        try self.ensure(self.len + 1);
        self.data[self.len] = b;
        self.len += 1;
    }

    pub fn appendInt(self: *Buf, comptime T: type, v: T) !void {
        var tmp: [@sizeOf(T)]u8 = undefined;
        std.mem.writeInt(T, &tmp, v, .little);
        try self.appendSlice(&tmp);
    }

    /// Reset length to 0 but keep the allocation (warmup amortizes growth).
    pub fn resetForReuse(self: *Buf) void {
        self.len = 0;
    }
};

test "lent writer appends, grows, and keeps the allocation" {
    var out = try Buf.initCapacity(std.testing.allocator, 1);
    defer out.deinit();
    try out.appendByte('!');
    {
        var writer = out.takeWriter();
        defer out.restoreWriter(&writer);
        try writer.writer.writeAll("hello");
    }
    try std.testing.expectEqualStrings("!hello", out.items());
    const allocation = out.data.ptr;
    const capacity = out.data.len;
    out.clear();
    {
        var writer = out.takeWriter();
        defer out.restoreWriter(&writer);
        try writer.writer.writeAll("ok");
    }
    try std.testing.expectEqualStrings("ok", out.items());
    try std.testing.expectEqual(allocation, out.data.ptr);
    try std.testing.expectEqual(capacity, out.data.len);
}

test "lent writer failing to grow leaves the buffer owned and reusable" {
    var failing = std.testing.FailingAllocator.init(std.testing.allocator, .{
        .fail_index = 1,
        .resize_fail_index = 0,
    });
    var out = try Buf.initCapacity(failing.allocator(), 1);
    defer out.deinit();
    try out.appendByte('!');
    {
        var writer = out.takeWriter();
        defer out.restoreWriter(&writer);
        try std.testing.expectError(error.WriteFailed, writer.writer.writeAll("must grow"));
    }
    try std.testing.expectEqualStrings("!", out.items());
    out.clear();
    try out.appendByte('?');
    try std.testing.expectEqualStrings("?", out.items());
}
