//! Zig serializer benchmark runner (Data Model v2 only).

const std = @import("std");
const runner = @import("runner.zig");

pub const data = @import("data.zig");
pub const schedule = @import("schedule.zig");
pub const serializers = @import("serializers.zig");
pub const packed_bin = @import("packed_bin.zig");
pub const json_util = @import("json_util.zig");
pub const compress = @import("compress.zig");
pub const serde_ser = @import("serde_ser.zig");
pub const extra = @import("extra.zig");

/// Args (from run-benchmarks.sh):
///   REPS LOG_PATH RESOLVED_JSON [serFilter] [dataFilter] [seed] [schedule]
pub fn main(init: std.process.Init) !void {
    const allocator = init.gpa;
    const io = init.io;

    var it = std.process.Args.Iterator.init(init.minimal.args);
    _ = it.next(); // program
    const reps_s = it.next() orelse "10";
    const log_path = it.next() orelse return error.MissingLogPath;
    const resolved_path = it.next() orelse return error.MissingResolvedJson;
    const ser_filter = it.next() orelse "";
    const data_filter = it.next() orelse "";
    const seed_s = it.next() orelse "42";
    const strategy = it.next() orelse "block_shuffle";

    const repetitions = std.fmt.parseInt(u32, reps_s, 10) catch 10;
    const seed = std.fmt.parseInt(u64, seed_s, 10) catch 42;

    if (std.fs.path.dirname(log_path)) |dir| {
        std.Io.Dir.cwd().createDirPath(io, dir) catch {};
    }

    try runner.run(allocator, io, .{
        .repetitions = repetitions,
        .log_path = log_path,
        .resolved_path = resolved_path,
        .ser_filter = ser_filter,
        .data_filter = data_filter,
        .seed = seed,
        .strategy = strategy,
        .record_run_order = true,
    });
}

test {
    _ = data;
    _ = schedule;
    _ = serializers;
    _ = compress;
    _ = serde_ser;
    _ = extra;
}
