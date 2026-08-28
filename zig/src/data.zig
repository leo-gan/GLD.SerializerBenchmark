//! Suite v2 fixtures. Deterministic within Zig; not bit-identical across languages.
//!
//! RNG: xorshift64 seeded from mixSeed(suite_seed, type_id, instance_index).
//! mixSeed is FNV-1a-ish with the golden-ratio avalanche (same idea as Rust).

const std = @import("std");

pub const BASE_TS_MS: i64 = 1_704_067_200_000;

pub const Message = struct {
    f_bool: bool,
    f_int32: i32,
    f_int64: i64,
    f_float64: f64,
    f_string: []const u8,
    f_bool_2: bool,
    f_int32_2: i32,
    f_string_2: []const u8,
};

pub const DocumentMeta = struct {
    region: []const u8,
    version: i32,
};

pub const DocumentItem = struct {
    sku: []const u8,
    qty: i32,
    price_minor: i64,
};

pub const Document = struct {
    id: []const u8,
    status: i32,
    meta: DocumentMeta,
    items: []DocumentItem,
};

pub const Telemetry = struct {
    source: []const u8,
    ts: i64,
    tags: [][]const u8,
    values: []f64,
};

pub const Strings = struct {
    items: [][]const u8,
};

pub const EventAttr = struct {
    key: []const u8,
    value: []const u8,
};

pub const Event = struct {
    event_id: []const u8,
    event_type: []const u8,
    occurred_at: i64,
    producer: []const u8,
    attrs: []EventAttr,
};

pub const TypeConfig = struct {
    children: i32 = 8,
    points: i32 = 32,
    count: i32 = 32,
    attr_count: i32 = 4,
};

pub const Fixture = union(enum) {
    message: Message,
    document: Document,
    telemetry: Telemetry,
    strings: Strings,
    event: Event,

    pub fn typeId(self: Fixture) []const u8 {
        return switch (self) {
            .message => "message",
            .document => "document",
            .telemetry => "telemetry",
            .strings => "strings",
            .event => "event",
        };
    }
};

pub fn mixSeed(seed: u64, type_id: []const u8, idx: i32) u64 {
    var h = seed;
    for (type_id) |byte| {
        h = (h ^ @as(u64, byte)) *% 0x0100_0000_01B3;
    }
    h ^= @as(u64, @intCast(idx)) *% 0x9E37_79B9_7F4A_7C15;
    return if (h == 0) 1 else h;
}

pub const Rng = struct {
    state: u64,

    pub fn init(mixed: u64) Rng {
        return .{ .state = if (mixed == 0) 1 else mixed };
    }

    pub fn nextU64(self: *Rng) u64 {
        var x = self.state;
        x ^= x << 13;
        x ^= x >> 7;
        x ^= x << 17;
        self.state = x;
        return x;
    }

    pub fn nextInt(self: *Rng, lo: i32, hi: i32) i32 {
        if (hi <= lo) return lo;
        const span: u64 = @intCast(hi - lo + 1);
        return lo + @as(i32, @intCast(self.nextU64() % span));
    }

    pub fn nextBool(self: *Rng) bool {
        return (self.nextU64() & 1) == 1;
    }

    pub fn nextF64(self: *Rng) f64 {
        const bits = self.nextU64() >> 11;
        return @as(f64, @floatFromInt(bits)) / @as(f64, @floatFromInt(@as(u64, 1) << 53));
    }

    pub fn word(self: *Rng, allocator: std.mem.Allocator, min_l: i32, max_l: i32) ![]u8 {
        const n: usize = @intCast(self.nextInt(min_l, max_l));
        const buf = try allocator.alloc(u8, n);
        for (buf) |*ch| {
            ch.* = 'a' + @as(u8, @intCast(self.nextU64() % 26));
        }
        return buf;
    }
};

pub fn makeOne(
    allocator: std.mem.Allocator,
    type_id: []const u8,
    seed: u64,
    instance_index: i32,
    cfg: TypeConfig,
) !Fixture {
    var rng = Rng.init(mixSeed(seed, type_id, instance_index));
    if (std.mem.eql(u8, type_id, "message")) {
        return .{ .message = .{
            .f_bool = rng.nextBool(),
            .f_int32 = rng.nextInt(0, 1_000_000),
            .f_int64 = @intCast(rng.nextInt(0, 1_000_000)),
            .f_float64 = rng.nextF64() * 1000.0,
            .f_string = try rng.word(allocator, 3, 16),
            .f_bool_2 = rng.nextBool(),
            .f_int32_2 = rng.nextInt(0, 1_000_000),
            .f_string_2 = try rng.word(allocator, 3, 16),
        } };
    }
    if (std.mem.eql(u8, type_id, "document")) {
        const n: usize = @intCast(@max(cfg.children, 0));
        const items = try allocator.alloc(DocumentItem, n);
        for (items) |*it| {
            it.* = .{
                .sku = try rng.word(allocator, 3, 12),
                .qty = rng.nextInt(1, 100),
                .price_minor = @intCast(rng.nextInt(0, 100_000)),
            };
        }
        return .{ .document = .{
            .id = try rng.word(allocator, 8, 12),
            .status = rng.nextInt(0, 5),
            .meta = .{
                .region = try rng.word(allocator, 2, 4),
                .version = rng.nextInt(1, 10),
            },
            .items = items,
        } };
    }
    if (std.mem.eql(u8, type_id, "telemetry")) {
        const tags = try allocator.alloc([]const u8, 2);
        tags[0] = try rng.word(allocator, 3, 10);
        tags[1] = try rng.word(allocator, 3, 10);
        const n: usize = @intCast(@max(cfg.points, 0));
        const values = try allocator.alloc(f64, n);
        for (values) |*v| v.* = rng.nextF64() * 100.0;
        return .{ .telemetry = .{
            .source = try rng.word(allocator, 3, 10),
            .ts = BASE_TS_MS + @as(i64, rng.nextInt(0, 86_400_000)),
            .tags = tags,
            .values = values,
        } };
    }
    if (std.mem.eql(u8, type_id, "strings")) {
        const n: usize = @intCast(@max(cfg.count, 0));
        const items = try allocator.alloc([]const u8, n);
        for (items) |*it| it.* = try rng.word(allocator, 3, 16);
        return .{ .strings = .{ .items = items } };
    }
    if (std.mem.eql(u8, type_id, "event")) {
        const n: usize = @intCast(@max(cfg.attr_count, 0));
        const attrs = try allocator.alloc(EventAttr, n);
        for (attrs) |*a| {
            a.* = .{
                .key = try rng.word(allocator, 3, 12),
                .value = try rng.word(allocator, 3, 12),
            };
        }
        return .{ .event = .{
            .event_id = try rng.word(allocator, 8, 12),
            .event_type = try rng.word(allocator, 3, 12),
            .occurred_at = BASE_TS_MS + @as(i64, rng.nextInt(0, 86_400_000)),
            .producer = try rng.word(allocator, 3, 12),
            .attrs = attrs,
        } };
    }
    return error.UnknownTypeId;
}

pub fn instances(
    allocator: std.mem.Allocator,
    type_id: []const u8,
    seed: u64,
    n: i32,
    cfg: TypeConfig,
) ![]Fixture {
    const count: usize = @intCast(@max(n, 1));
    const out = try allocator.alloc(Fixture, count);
    for (out, 0..) |*fx, i| {
        fx.* = try makeOne(allocator, type_id, seed, @intCast(i), cfg);
    }
    return out;
}

fn nearlyEq(a: f64, b: f64) bool {
    const scale = @max(1.0, @max(@abs(a), @abs(b)));
    return @abs(a - b) <= 1e-6 * scale;
}

pub fn fidelity(a: Fixture, b: Fixture) bool {
    return switch (a) {
        .message => |x| switch (b) {
            .message => |y| x.f_bool == y.f_bool and
                x.f_int32 == y.f_int32 and
                x.f_int64 == y.f_int64 and
                nearlyEq(x.f_float64, y.f_float64) and
                std.mem.eql(u8, x.f_string, y.f_string) and
                x.f_bool_2 == y.f_bool_2 and
                x.f_int32_2 == y.f_int32_2 and
                std.mem.eql(u8, x.f_string_2, y.f_string_2),
            else => false,
        },
        .document => |x| switch (b) {
            .document => |y| documentEq(x, y),
            else => false,
        },
        .telemetry => |x| switch (b) {
            .telemetry => |y| telemetryEq(x, y),
            else => false,
        },
        .strings => |x| switch (b) {
            .strings => |y| stringsEq(x, y),
            else => false,
        },
        .event => |x| switch (b) {
            .event => |y| eventEq(x, y),
            else => false,
        },
    };
}

fn documentEq(x: Document, y: Document) bool {
    if (!std.mem.eql(u8, x.id, y.id)) return false;
    if (x.status != y.status) return false;
    if (!std.mem.eql(u8, x.meta.region, y.meta.region)) return false;
    if (x.meta.version != y.meta.version) return false;
    if (x.items.len != y.items.len) return false;
    for (x.items, y.items) |a, b| {
        if (!std.mem.eql(u8, a.sku, b.sku)) return false;
        if (a.qty != b.qty) return false;
        if (a.price_minor != b.price_minor) return false;
    }
    return true;
}

fn telemetryEq(x: Telemetry, y: Telemetry) bool {
    if (!std.mem.eql(u8, x.source, y.source)) return false;
    if (x.ts != y.ts) return false;
    if (x.tags.len != y.tags.len) return false;
    for (x.tags, y.tags) |a, b| {
        if (!std.mem.eql(u8, a, b)) return false;
    }
    if (x.values.len != y.values.len) return false;
    for (x.values, y.values) |a, b| {
        if (!nearlyEq(a, b)) return false;
    }
    return true;
}

fn stringsEq(x: Strings, y: Strings) bool {
    if (x.items.len != y.items.len) return false;
    for (x.items, y.items) |a, b| {
        if (!std.mem.eql(u8, a, b)) return false;
    }
    return true;
}

fn eventEq(x: Event, y: Event) bool {
    if (!std.mem.eql(u8, x.event_id, y.event_id)) return false;
    if (!std.mem.eql(u8, x.event_type, y.event_type)) return false;
    if (x.occurred_at != y.occurred_at) return false;
    if (!std.mem.eql(u8, x.producer, y.producer)) return false;
    if (x.attrs.len != y.attrs.len) return false;
    for (x.attrs, y.attrs) |a, b| {
        if (!std.mem.eql(u8, a.key, b.key)) return false;
        if (!std.mem.eql(u8, a.value, b.value)) return false;
    }
    return true;
}

test "document seed is deterministic" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = try makeOne(arena.allocator(), "document", 42, 0, .{});
    const b = try makeOne(arena.allocator(), "document", 42, 0, .{});
    try std.testing.expect(fidelity(a, b));
}

test "instance index changes the value" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const a = try makeOne(arena.allocator(), "document", 42, 0, .{});
    const c = try makeOne(arena.allocator(), "document", 42, 1, .{});
    try std.testing.expect(!fidelity(a, c));
}

test "instances length" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const batch = try instances(arena.allocator(), "message", 42, 3, .{});
    try std.testing.expectEqual(@as(usize, 3), batch.len);
}
