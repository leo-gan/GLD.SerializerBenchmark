//! B-1 deterministic block_shuffle schedule (must match analysis golden vector).
//!
//! key = "{base_seed}|{type_id}|{instance_count}|{type_config_hash}|{mode}|{rep}"
//! mode: string/buffer → bytes; Stream → stream; lowercase
//! u64 = first 8 bytes SHA-256(key) little-endian
//! SplitMix64(u64); Fisher-Yates: for i=n-1..1: j = next_u64() % (i+1); swap
//! Golden: names A,B,C seed 42 type message n=1 hash abc mode bytes rep 0 → C,B,A
//! seed value must be 15992650003647724414

const std = @import("std");

pub fn normalizeMode(mode: []const u8) []const u8 {
    if (std.ascii.eqlIgnoreCase(mode, "string") or std.ascii.eqlIgnoreCase(mode, "buffer")) {
        return "bytes";
    }
    if (std.ascii.eqlIgnoreCase(mode, "stream")) {
        return "stream";
    }
    if (std.ascii.eqlIgnoreCase(mode, "bytes")) {
        return "bytes";
    }
    return mode;
}

pub fn deriveScheduleSeed(
    base_seed: u64,
    type_id: []const u8,
    instance_count: i32,
    type_config_hash: []const u8,
    mode: []const u8,
    rep: u32,
) u64 {
    var buf: [256]u8 = undefined;
    const key = std.fmt.bufPrint(&buf, "{d}|{s}|{d}|{s}|{s}|{d}", .{
        base_seed,
        type_id,
        instance_count,
        type_config_hash,
        normalizeMode(mode),
        rep,
    }) catch unreachable;
    var digest: [32]u8 = undefined;
    std.crypto.hash.sha2.Sha256.hash(key, &digest, .{});
    return std.mem.readInt(u64, digest[0..8], .little);
}

const SplitMix64 = struct {
    state: u64,
    fn next(self: *SplitMix64) u64 {
        self.state +%= 0x9E3779B97F4A7C15;
        var z = self.state;
        z = (z ^ (z >> 30)) *% 0xBF58476D1CE4E5B9;
        z = (z ^ (z >> 27)) *% 0x94D049BB133111EB;
        return z ^ (z >> 31);
    }
};

pub fn fisherYates(items: []usize, seed: u64) void {
    if (items.len < 2) return;
    var rng = SplitMix64{ .state = seed };
    var i = items.len;
    while (i > 1) {
        i -= 1;
        const j: usize = @intCast(rng.next() % (i + 1));
        const tmp = items[i];
        items[i] = items[j];
        items[j] = tmp;
    }
}

pub fn resolveStrategy() []const u8 {
    const env = std.process.getEnvVarOwned(std.heap.page_allocator, "BENCHMARK_SCHEDULE") catch return "block_shuffle";
    defer std.heap.page_allocator.free(env);
    if (std.ascii.eqlIgnoreCase(env, "none")) return "none";
    return "block_shuffle";
}

pub fn resolveRecordRunOrder() bool {
    const env = std.process.getEnvVarOwned(std.heap.page_allocator, "BENCHMARK_RECORD_RUN_ORDER") catch return true;
    defer std.heap.page_allocator.free(env);
    if (std.ascii.eqlIgnoreCase(env, "0") or
        std.ascii.eqlIgnoreCase(env, "false") or
        std.ascii.eqlIgnoreCase(env, "no"))
    {
        return false;
    }
    return true;
}

test "golden seed and permutation" {
    const seed = deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
    try std.testing.expectEqual(@as(u64, 15992650003647724414), seed);
    var names = [_]usize{ 0, 1, 2 }; // A B C
    fisherYates(&names, seed);
    try std.testing.expectEqualSlices(usize, &.{ 2, 1, 0 }, &names); // C B A
}

test "mode aliases same seed" {
    const a = deriveScheduleSeed(42, "message", 1, "abc", "bytes", 0);
    const b = deriveScheduleSeed(42, "message", 1, "abc", "string", 0);
    const c = deriveScheduleSeed(42, "message", 1, "abc", "buffer", 0);
    try std.testing.expectEqual(a, b);
    try std.testing.expectEqual(a, c);
}
