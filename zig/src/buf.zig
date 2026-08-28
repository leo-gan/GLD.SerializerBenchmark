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
