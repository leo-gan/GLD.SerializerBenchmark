//! Suite and tensor fixtures. Deterministic within Zig; not bit-identical across languages.
//!
//! RNG: xorshift64 seeded from mixSeed(suite_seed, type_id, instance_index).
//! mixSeed is FNV-1a-ish with the golden-ratio avalanche (same idea as Rust).
//! tensor_view mixes the seed with "tensor", not "tensor_view".

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

pub const Tensor = struct {
    rows: i32,
    cols: i32,
    values: []f32,
};

/// Generator fills `values`. A borrowed decode sets `payload` to the encoded
/// f32 bytes and leaves `values` empty. Fidelity accepts either side.
pub const TensorView = struct {
    rows: i32,
    cols: i32,
    values: []f32,
    payload: []const u8 = &.{},
};

pub const Prompt = struct {
    batch: i32,
    seq: i32,
    input_ids: []i64,
    attention_mask: []i64,
    position_ids: []i64,
};

pub const Shard = struct {
    vocab: i32,
    hidden: i32,
    ffn: i32,
    tok_emb: []f32,
    attn: []f32,
    ffn_weight: []f32,
    norm: []f32,
};

pub const Request = struct {
    request_id: i64,
    model: []const u8,
    temperature: f32,
    inputs: Prompt,
};

pub const TypeConfig = struct {
    children: i32 = 8,
    points: i32 = 32,
    count: i32 = 32,
    attr_count: i32 = 4,
    rows: i32 = 1024,
    cols: i32 = 1024,
    batch: i32 = 4,
    seq: i32 = 256,
    vocab: i32 = 32000,
    hidden: i32 = 256,
    ffn: i32 = 512,
    string_min: i32 = 3,
    string_max: i32 = 16,
};

pub const Fixture = union(enum) {
    message: Message,
    document: Document,
    telemetry: Telemetry,
    strings: Strings,
    event: Event,
    tensor: Tensor,
    tensor_view: TensorView,
    prompt: Prompt,
    shard: Shard,
    request: Request,

    pub fn typeId(self: Fixture) []const u8 {
        return switch (self) {
            .message => "message",
            .document => "document",
            .telemetry => "telemetry",
            .strings => "strings",
            .event => "event",
            .tensor => "tensor",
            .tensor_view => "tensor_view",
            .prompt => "prompt",
            .shard => "shard",
            .request => "request",
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

    /// `nextF64` narrowed to float32. Not a second generator.
    pub fn nextF32(self: *Rng) f32 {
        return @floatCast(self.nextF64());
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
    // tensor_view is the same matrix as tensor, including the RNG stream.
    const seed_id = if (std.mem.eql(u8, type_id, "tensor_view")) "tensor" else type_id;
    var rng = Rng.init(mixSeed(seed, seed_id, instance_index));
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
    if (std.mem.eql(u8, type_id, "tensor")) {
        return .{ .tensor = try makeTensor(allocator, &rng, cfg) };
    }
    if (std.mem.eql(u8, type_id, "tensor_view")) {
        const tensor = try makeTensor(allocator, &rng, cfg);
        return .{ .tensor_view = .{
            .rows = tensor.rows,
            .cols = tensor.cols,
            .values = tensor.values,
        } };
    }
    if (std.mem.eql(u8, type_id, "prompt")) {
        return .{ .prompt = try makePrompt(allocator, &rng, cfg) };
    }
    if (std.mem.eql(u8, type_id, "shard")) {
        return .{ .shard = try makeShard(allocator, &rng, cfg) };
    }
    if (std.mem.eql(u8, type_id, "request")) {
        return .{ .request = try makeRequest(allocator, &rng, cfg) };
    }
    return error.UnknownTypeId;
}

fn makeTensor(allocator: std.mem.Allocator, rng: *Rng, cfg: TypeConfig) !Tensor {
    if (cfg.rows < 1 or cfg.cols < 1) return error.InvalidShape;
    const n = @as(usize, @intCast(cfg.rows)) * @as(usize, @intCast(cfg.cols));
    if (n < 2) return error.InvalidShape;
    return .{
        .rows = cfg.rows,
        .cols = cfg.cols,
        .values = try f32Fill(allocator, rng, n, true),
    };
}

fn makePrompt(allocator: std.mem.Allocator, rng: *Rng, cfg: TypeConfig) !Prompt {
    if (cfg.batch < 1 or cfg.seq < 1 or cfg.vocab < 2) return error.InvalidShape;
    const batch: usize = @intCast(cfg.batch);
    const seq: usize = @intCast(cfg.seq);
    const n = batch * seq;
    const input_ids = try allocator.alloc(i64, n);
    const attention_mask = try allocator.alloc(i64, n);
    const position_ids = try allocator.alloc(i64, n);
    var row: usize = 0;
    while (row < batch) : (row += 1) {
        var lo = @divTrunc(cfg.seq, 2);
        if (lo < 1) lo = 1;
        const content = rng.nextInt(lo, cfg.seq);
        var col: i32 = 0;
        while (col < cfg.seq) : (col += 1) {
            const i = row * seq + @as(usize, @intCast(col));
            if (col < content) {
                input_ids[i] = rng.nextInt(1, cfg.vocab - 1);
                attention_mask[i] = 1;
            } else {
                input_ids[i] = 0;
                attention_mask[i] = 0;
            }
            position_ids[i] = col;
        }
    }
    return .{
        .batch = cfg.batch,
        .seq = cfg.seq,
        .input_ids = input_ids,
        .attention_mask = attention_mask,
        .position_ids = position_ids,
    };
}

fn makeShard(allocator: std.mem.Allocator, rng: *Rng, cfg: TypeConfig) !Shard {
    if (cfg.vocab < 1 or cfg.hidden < 1 or cfg.ffn < 1) return error.InvalidShape;
    const vocab: usize = @intCast(cfg.vocab);
    const hidden: usize = @intCast(cfg.hidden);
    const ffn: usize = @intCast(cfg.ffn);
    return .{
        .vocab = cfg.vocab,
        .hidden = cfg.hidden,
        .ffn = cfg.ffn,
        .tok_emb = try f32Fill(allocator, rng, vocab * hidden, false),
        .attn = try f32Fill(allocator, rng, hidden * hidden, false),
        .ffn_weight = try f32Fill(allocator, rng, ffn * hidden, false),
        .norm = try f32Fill(allocator, rng, hidden, false),
    };
}

fn makeRequest(allocator: std.mem.Allocator, rng: *Rng, cfg: TypeConfig) !Request {
    if (cfg.string_min < 0 or cfg.string_max < cfg.string_min) return error.InvalidShape;
    return .{
        .request_id = rng.nextInt(1, 1_000_000_000),
        .model = try rng.word(allocator, cfg.string_min, cfg.string_max),
        .temperature = @floatCast(rng.nextF64() * 2.0),
        .inputs = try makePrompt(allocator, rng, cfg),
    };
}

fn f32Fill(allocator: std.mem.Allocator, rng: *Rng, count: usize, pin: bool) ![]f32 {
    const values = try allocator.alloc(f32, count);
    for (values) |*slot| slot.* = rng.nextF32();
    if (pin and count >= 2) {
        values[0] = @bitCast(@as(u32, 0x80000000));
        values[1] = @bitCast(@as(u32, 0x7fc00000));
    }
    return values;
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
        .tensor => |x| switch (b) {
            .tensor => |y| tensorEq(x, y),
            else => false,
        },
        .tensor_view => |x| switch (b) {
            .tensor_view => |y| tensorViewEq(x, y),
            else => false,
        },
        .prompt => |x| switch (b) {
            .prompt => |y| promptEq(x, y),
            else => false,
        },
        .shard => |x| switch (b) {
            .shard => |y| shardEq(x, y),
            else => false,
        },
        .request => |x| switch (b) {
            .request => |y| requestEq(x, y),
            else => false,
        },
    };
}

fn sameF32s(a: []const f32, b: []const f32) bool {
    if (a.len != b.len) return false;
    for (a, b) |x, y| {
        if (@as(u32, @bitCast(x)) != @as(u32, @bitCast(y))) return false;
    }
    return true;
}

fn payloadEq(values: []const f32, payload: []const u8) bool {
    const need = std.math.mul(usize, values.len, 4) catch return false;
    if (payload.len != need) return false;
    var i: usize = 0;
    while (i < values.len) : (i += 1) {
        const bits = std.mem.readInt(u32, payload[i * 4 ..][0..4], .little);
        if (bits != @as(u32, @bitCast(values[i]))) return false;
    }
    return true;
}

fn tensorEq(x: Tensor, y: Tensor) bool {
    return x.rows == y.rows and x.cols == y.cols and sameF32s(x.values, y.values);
}

fn tensorViewEq(x: TensorView, y: TensorView) bool {
    if (x.rows != y.rows or x.cols != y.cols) return false;
    if (x.payload.len != 0 and y.payload.len != 0) return std.mem.eql(u8, x.payload, y.payload);
    if (x.payload.len != 0) return payloadEq(y.values, x.payload);
    if (y.payload.len != 0) return payloadEq(x.values, y.payload);
    return sameF32s(x.values, y.values);
}

fn promptEq(x: Prompt, y: Prompt) bool {
    if (x.batch != y.batch or x.seq != y.seq) return false;
    return std.mem.eql(i64, x.input_ids, y.input_ids) and
        std.mem.eql(i64, x.attention_mask, y.attention_mask) and
        std.mem.eql(i64, x.position_ids, y.position_ids);
}

fn shardEq(x: Shard, y: Shard) bool {
    if (x.vocab != y.vocab or x.hidden != y.hidden or x.ffn != y.ffn) return false;
    return sameF32s(x.tok_emb, y.tok_emb) and
        sameF32s(x.attn, y.attn) and
        sameF32s(x.ffn_weight, y.ffn_weight) and
        sameF32s(x.norm, y.norm);
}

fn requestEq(x: Request, y: Request) bool {
    if (x.request_id != y.request_id or !std.mem.eql(u8, x.model, y.model)) return false;
    if (@as(u32, @bitCast(x.temperature)) != @as(u32, @bitCast(y.temperature))) return false;
    return promptEq(x.inputs, y.inputs);
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

test "tensor_view reuses the tensor seed and pins float32 bits" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const cfg = TypeConfig{ .rows = 4, .cols = 4 };
    const tensor = (try makeOne(arena.allocator(), "tensor", 7, 2, cfg)).tensor;
    const view = (try makeOne(arena.allocator(), "tensor_view", 7, 2, cfg)).tensor_view;
    try std.testing.expectEqual(tensor.rows, view.rows);
    try std.testing.expectEqual(tensor.cols, view.cols);
    try std.testing.expect(sameF32s(tensor.values, view.values));
    try std.testing.expectEqual(@as(u32, 0x80000000), @as(u32, @bitCast(tensor.values[0])));
    try std.testing.expectEqual(@as(u32, 0x7fc00000), @as(u32, @bitCast(tensor.values[1])));
    const other = (try makeOne(arena.allocator(), "tensor", 8, 2, cfg)).tensor;
    try std.testing.expect(!sameF32s(tensor.values, other.values));
}

test "prompt positions are the column index and do not draw" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const cfg = TypeConfig{ .batch = 2, .seq = 5, .vocab = 20 };
    const prompt = (try makeOne(arena.allocator(), "prompt", 3, 0, cfg)).prompt;
    try std.testing.expectEqual(@as(usize, 10), prompt.input_ids.len);
    for (prompt.position_ids, 0..) |pos, i| {
        try std.testing.expectEqual(@as(i64, @intCast(i % 5)), pos);
    }
    for (prompt.input_ids, prompt.attention_mask) |id, mask| {
        if (mask == 0) {
            try std.testing.expectEqual(@as(i64, 0), id);
        } else {
            try std.testing.expectEqual(@as(i64, 1), mask);
            try std.testing.expect(id >= 1 and id < cfg.vocab);
        }
    }
}
