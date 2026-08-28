//! Data Model v2 path: cells from a resolved JSON file + serializer registry.

const std = @import("std");
const data = @import("data.zig");
const schedule = @import("schedule.zig");
const buf_mod = @import("buf.zig");
const compress = @import("compress.zig");
const csv_mod = @import("csv.zig");
const serializers = @import("serializers.zig");

pub const Options = struct {
    repetitions: u32,
    log_path: []const u8,
    resolved_path: []const u8,
    ser_filter: []const u8,
    data_filter: []const u8,
    seed: u64,
    strategy: []const u8,
    record_run_order: bool,
};

const Cell = struct {
    type_id: []const u8,
    type_config_hash: []const u8,
    instance_count: i32,
    fixtures: []data.Fixture,
};

fn readFile(allocator: std.mem.Allocator, io: std.Io, path: []const u8) ![]u8 {
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var reader = file.reader(io, &buf);
    return reader.interface.allocRemaining(allocator, .unlimited);
}

fn loadCells(
    allocator: std.mem.Allocator,
    io: std.Io,
    resolved_path: []const u8,
    seed: u64,
    data_filter: []const u8,
) !struct { []Cell, [][]const u8 } {
    const stdout = try readFile(allocator, io, resolved_path);
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, stdout, .{});
    const obj = parsed.value.object;

    var modes = try allocator.alloc([]const u8, 0);
    if (obj.get("execution")) |ex| {
        if (ex.object.get("io_modes")) |arr| {
            modes = try allocator.alloc([]const u8, arr.array.items.len);
            for (arr.array.items, 0..) |v, i| {
                modes[i] = v.string;
            }
        }
    }
    if (modes.len == 0) {
        modes = try allocator.alloc([]const u8, 1);
        modes[0] = "bytes";
    }

    const cells_val = obj.get("cells") orelse return error.NoCells;
    var cells_list: std.ArrayList(Cell) = .empty;
    for (cells_val.array.items) |c| {
        const cobj = c.object;
        const type_id = cobj.get("type_id").?.string;
        if (data_filter.len > 0) {
            if (std.ascii.indexOfIgnoreCase(type_id, data_filter) == null) continue;
        }
        const n: i32 = @intCast(jsonInt(cobj.get("data_type_instance_count")));
        const hash = if (cobj.get("type_config_hash")) |h| h.string else "";
        var cfg = data.TypeConfig{};
        if (cobj.get("type_config")) |tc| {
            if (tc.object.get("children")) |v| cfg.children = @intCast(jsonInt(v));
            if (tc.object.get("points")) |v| cfg.points = @intCast(jsonInt(v));
            if (tc.object.get("count")) |v| cfg.count = @intCast(jsonInt(v));
            if (tc.object.get("attr_count")) |v| cfg.attr_count = @intCast(jsonInt(v));
        }
        const fixtures = try data.instances(allocator, type_id, seed, @max(n, 1), cfg);
        try cells_list.append(allocator, .{
            .type_id = type_id,
            .type_config_hash = hash,
            .instance_count = @max(n, 1),
            .fixtures = fixtures,
        });
    }
    return .{ try cells_list.toOwnedSlice(allocator), modes };
}

fn jsonInt(v: ?std.json.Value) i64 {
    const val = v orelse return 1;
    return switch (val) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        .number_string => |s| std.fmt.parseInt(i64, s, 10) catch 1,
        else => 1,
    };
}

fn serializeCell(
    ser: serializers.Serializer,
    fixtures: []const data.Fixture,
    out: *buf_mod.Buf,
    scratch: *buf_mod.Buf,
) !void {
    if (fixtures.len == 1) {
        try ser.serialize(fixtures[0], out);
        return;
    }
    try out.appendInt(u32, @intCast(fixtures.len));
    for (fixtures) |fx| {
        scratch.clear();
        try ser.serialize(fx, scratch);
        try out.appendInt(u32, @intCast(scratch.len));
        try out.appendSlice(scratch.items());
    }
}

fn deserializeCell(
    ser: serializers.Serializer,
    allocator: std.mem.Allocator,
    type_id: []const u8,
    bytes: []const u8,
    expected_n: usize,
) ![]data.Fixture {
    if (expected_n == 1) {
        const one = try ser.deserialize(allocator, type_id, bytes);
        const out = try allocator.alloc(data.Fixture, 1);
        out[0] = one;
        return out;
    }
    if (bytes.len < 4) return error.BatchTooShort;
    const n = std.mem.readInt(u32, bytes[0..4], .little);
    if (n != expected_n) return error.BatchCountMismatch;
    var o: usize = 4;
    const out = try allocator.alloc(data.Fixture, n);
    for (out) |*slot| {
        if (o + 4 > bytes.len) return error.TruncatedBatch;
        const item_len = std.mem.readInt(u32, bytes[o .. o + 4][0..4], .little);
        o += 4;
        if (o + item_len > bytes.len) return error.TruncatedBatch;
        slot.* = try ser.deserialize(allocator, type_id, bytes[o .. o + item_len]);
        o += item_len;
    }
    return out;
}

fn checkBatch(expected: []const data.Fixture, got: []const data.Fixture) !void {
    if (expected.len != got.len) return error.FidelityLen;
    for (expected, got) |a, b| {
        if (!data.fidelity(a, b)) return error.Fidelity;
    }
}

fn blackBox(value: anytype) @TypeOf(value) {
    std.mem.doNotOptimizeAway(&value);
    return value;
}

fn measureTrial(
    io: std.Io,
    ser: serializers.Serializer,
    cell: Cell,
    out: *buf_mod.Buf,
    scratch: *buf_mod.Buf,
    arena: std.mem.Allocator,
) !struct { u64, u64, usize } {
    out.clear();
    scratch.clear();
    const t0 = std.Io.Timestamp.now(io, .awake);
    try serializeCell(ser, cell.fixtures, out, scratch);
    const t1 = std.Io.Timestamp.now(io, .awake);
    _ = blackBox(out.len);
    const got = try deserializeCell(ser, arena, cell.type_id, out.items(), cell.fixtures.len);
    const t2 = std.Io.Timestamp.now(io, .awake);
    _ = blackBox(got.len);
    try checkBatch(cell.fixtures, got);
    const ser_ns: u64 = @intCast(@max(t1.toNanoseconds() - t0.toNanoseconds(), 0));
    const deser_ns: u64 = @intCast(@max(t2.toNanoseconds() - t1.toNanoseconds(), 0));
    return .{ ser_ns, deser_ns, out.len };
}

fn indexOf(ready: []const usize, n: usize, ser_idx: usize) ?usize {
    var i: usize = 0;
    while (i < n) : (i += 1) {
        if (ready[i] == ser_idx) return i;
    }
    return null;
}

pub fn run(allocator: std.mem.Allocator, io: std.Io, opt: Options) !void {
    const loaded = try loadCells(allocator, io, opt.resolved_path, opt.seed, opt.data_filter);
    const cells = loaded[0];
    const modes = loaded[1];

    var ser_buf: [32]serializers.Serializer = undefined;
    const nser = serializers.select(opt.ser_filter, &ser_buf);
    const sers = ser_buf[0..nser];

    var logger = try csv_mod.Csv.create(io, opt.log_path);
    defer logger.deinit();

    var err_path_buf: [512]u8 = undefined;
    const err_path = if (std.mem.endsWith(u8, opt.log_path, ".csv"))
        try std.fmt.bufPrint(&err_path_buf, "{s}.errors.csv", .{opt.log_path[0 .. opt.log_path.len - 4]})
    else
        try std.fmt.bufPrint(&err_path_buf, "{s}.errors.csv", .{opt.log_path});
    var errors = csv_mod.Errors.init(io, err_path);
    defer errors.deinit();

    std.debug.print(
        "[PROGRESS] Zig Data Model v2: {d} serializers, {d} cells, {d} reps, schedule={s} seed={d}\n",
        .{ sers.len, cells.len, opt.repetitions, opt.strategy, opt.seed },
    );

    var run_order: i32 = 0;
    for (cells) |cell| {
        std.debug.print("[PROGRESS] Cell {s} N={d}\n", .{ cell.type_id, cell.instance_count });

        var ready: [32]usize = undefined;
        var nready: usize = 0;
        for (sers, 0..) |ser, i| {
            if (!ser.supports(cell.type_id)) continue;
            ser.prepare(cell.fixtures) catch |e| {
                std.debug.print("[ERROR] prepare {s} / {s}: {s}\n", .{ ser.name, cell.type_id, @errorName(e) });
                errors.write(cell.type_id, ser.name, "prepare", 0, @errorName(e));
                continue;
            };
            ready[nready] = i;
            nready += 1;
        }

        var ser_bufs: [32]buf_mod.Buf = undefined;
        var scratch_bufs: [32]buf_mod.Buf = undefined;
        var i: usize = 0;
        while (i < nready) : (i += 1) {
            ser_bufs[i] = try buf_mod.Buf.initCapacity(allocator, 64 * 1024);
            scratch_bufs[i] = try buf_mod.Buf.initCapacity(allocator, 4096);
        }

        var gz: [32]usize = .{0} ** 32;
        var zs: [32]usize = .{0} ** 32;
        i = 0;
        while (i < nready) : (i += 1) {
            ser_bufs[i].clear();
            scratch_bufs[i].clear();
            serializeCell(sers[ready[i]], cell.fixtures, &ser_bufs[i], &scratch_bufs[i]) catch continue;
            const pair = compress.compressSizes(allocator, ser_bufs[i].items());
            gz[i] = pair[0];
            zs[i] = pair[1];
        }

        for (modes) |mode| {
            var rep: u32 = 0;
            while (rep < opt.repetitions) : (rep += 1) {
                var order: [32]usize = undefined;
                @memcpy(order[0..nready], ready[0..nready]);
                if (!std.mem.eql(u8, opt.strategy, "none")) {
                    const s = schedule.deriveScheduleSeed(
                        opt.seed,
                        cell.type_id,
                        cell.instance_count,
                        cell.type_config_hash,
                        mode,
                        rep,
                    );
                    schedule.fisherYates(order[0..nready], s);
                }
                var pos: i32 = 0;
                for (order[0..nready]) |si| {
                    pos += 1;
                    run_order += 1;
                    const bi = indexOf(&ready, nready, si) orelse 0;
                    var trial_arena = std.heap.ArenaAllocator.init(allocator);
                    defer trial_arena.deinit();
                    const measured = measureTrial(
                        io,
                        sers[si],
                        cell,
                        &ser_bufs[bi],
                        &scratch_bufs[bi],
                        trial_arena.allocator(),
                    );
                    if (measured) |m| {
                        const stream_label = if (std.mem.eql(u8, mode, "stream") and cell.fixtures.len > 1)
                            "adapted"
                        else
                            sers[si].stream_mode.label();
                        logger.writeRow(
                            mode,
                            cell.type_id,
                            opt.repetitions,
                            rep,
                            sers[si].name,
                            sers[si].version,
                            m[0],
                            m[1],
                            m[2],
                            1.0,
                            sers[si].native_kind.label(),
                            stream_label,
                            cell.instance_count,
                            cell.type_config_hash,
                            if (opt.record_run_order) run_order else null,
                            if (opt.record_run_order) pos else null,
                            gz[bi],
                            zs[bi],
                        ) catch {};
                    } else |e| {
                        std.debug.print("[ERROR] {s} / {s} / {s}: {s}\n", .{
                            sers[si].name, cell.type_id, mode, @errorName(e),
                        });
                        errors.write(cell.type_id, sers[si].name, mode, rep, @errorName(e));
                    }
                }
            }
        }
    }
    std.debug.print("[PROGRESS] Complete. Results: {s}\n", .{opt.log_path});
}
