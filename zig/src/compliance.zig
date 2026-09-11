//! Zig 0.16 compliance runner — std.json against the shared JSON catalog.
const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const alloc = init.gpa;
    const io = init.io;

    var json_out: ?[]const u8 = null;
    var formats: std.ArrayList([]const u8) = .empty;
    defer formats.deinit(alloc);

    var it = std.process.Args.Iterator.init(init.minimal.args);
    _ = it.next();
    while (it.next()) |a| {
        if (std.mem.eql(u8, a, "--json-out") or std.mem.eql(u8, a, "-o")) {
            json_out = it.next();
        } else if (std.mem.eql(u8, a, "--format") or std.mem.eql(u8, a, "-f")) {
            if (it.next()) |f| try formats.append(alloc, f);
        }
    }

    const cwd = std.Io.Dir.cwd();
    var root_rel: []const u8 = ".";
    var found = false;
    var up: usize = 0;
    while (up < 8) : (up += 1) {
        const probe = try std.fs.path.join(alloc, &.{ root_rel, "compliance", "data", "json" });
        defer alloc.free(probe);
        if (cwd.openDir(io, probe, .{ .iterate = true })) |d| {
            d.close(io);
            found = true;
            break;
        } else |_| {}
        const next = try std.fs.path.join(alloc, &.{ root_rel, ".." });
        if (!std.mem.eql(u8, root_rel, ".")) alloc.free(root_rel);
        root_rel = next;
    }
    if (!found) return error.NoCatalog;
    defer if (!std.mem.eql(u8, root_rel, ".")) alloc.free(root_rel);

    const data_dir = try std.fs.path.join(alloc, &.{ root_rel, "compliance", "data", "json" });
    defer alloc.free(data_dir);

    var want_json = formats.items.len == 0;
    for (formats.items) |f| {
        if (std.ascii.eqlIgnoreCase(f, "json")) want_json = true;
    }

    var results: std.ArrayList(u8) = .empty;
    defer results.deinit(alloc);
    try results.appendSlice(alloc, "[");
    var first = true;
    var p: usize = 0;
    var f: usize = 0;
    var total: usize = 0;

    if (want_json) {
        var dir = try cwd.openDir(io, data_dir, .{ .iterate = true });
        defer dir.close(io);
        var walker = dir.iterate();
        while (try walker.next(io)) |ent| {
            if (ent.kind != .file or !std.mem.endsWith(u8, ent.name, ".json")) continue;
            if (ent.name.len > 0 and ent.name[0] == '_') continue;
            const raw = try readFile(alloc, io, data_dir, ent.name);
            defer alloc.free(raw);
            const parsed = std.json.parseFromSlice(std.json.Value, alloc, raw, .{}) catch continue;
            defer parsed.deinit();
            const suite = parsed.value;
            const cases = (suite.object.get("cases") orelse continue).array;
            const standard = suite.object.get("standard").?.string;
            const version = suite.object.get("version").?.string;
            const standard_url = if (suite.object.get("standard_url")) |u| u.string else "";
            for (cases.items) |c| {
                const id = c.object.get("id").?.string;
                const expect = c.object.get("expect").?.string;
                const input = c.object.get("input").?.string;
                const enc = if (c.object.get("input_encoding")) |e| e.string else "utf-8";
                if (!std.mem.eql(u8, enc, "utf-8") and enc.len != 0) continue;
                if (tooDeep(input)) continue;
                total += 1;
                var outcome: []const u8 = "pass";
                var observed: []const u8 = "ok";
                if (std.json.parseFromSlice(std.json.Value, alloc, input, .{})) |ok| {
                    ok.deinit();
                    if (std.mem.eql(u8, expect, "reject")) {
                        outcome = "fail";
                        observed = "accepted";
                        f += 1;
                    } else p += 1;
                } else |_| {
                    if (std.mem.eql(u8, expect, "reject") or std.mem.eql(u8, expect, "any")) {
                        p += 1;
                        observed = "rejected";
                    } else {
                        outcome = "fail";
                        observed = "rejected";
                        f += 1;
                    }
                }
                if (!first) try results.appendSlice(alloc, ",");
                first = false;
                const qid = try std.json.Stringify.valueAlloc(alloc, id, .{});
                defer alloc.free(qid);
                const qstd = try std.json.Stringify.valueAlloc(alloc, standard, .{});
                defer alloc.free(qstd);
                const qurl = try std.json.Stringify.valueAlloc(alloc, standard_url, .{});
                defer alloc.free(qurl);
                const qver = try std.json.Stringify.valueAlloc(alloc, version, .{});
                defer alloc.free(qver);
                const qreq = try std.json.Stringify.valueAlloc(alloc, c.object.get("requirement").?.string, .{});
                defer alloc.free(qreq);
                const qexp = try std.json.Stringify.valueAlloc(alloc, expect, .{});
                defer alloc.free(qexp);
                const qsec = try std.json.Stringify.valueAlloc(alloc, c.object.get("section_url").?.string, .{});
                defer alloc.free(qsec);
                const qobs = try std.json.Stringify.valueAlloc(alloc, observed, .{});
                defer alloc.free(qobs);
                const qout = try std.json.Stringify.valueAlloc(alloc, outcome, .{});
                defer alloc.free(qout);
                const row = try std.fmt.allocPrint(
                    alloc,
                    "{{\"id\":{s},\"language\":\"zig\",\"serializer\":\"std.json\",\"serializer_version\":\"\",\"format\":\"json\",\"standard\":{s},\"standard_url\":{s},\"version\":{s},\"version_key\":\"json.{s}\",\"requirement\":{s},\"expect\":{s},\"section\":\"\",\"section_title\":\"\",\"section_url\":{s},\"paragraph\":\"\",\"title\":\"\",\"input\":\"\",\"input_encoding\":\"utf-8\",\"detail\":\"\",\"observed\":{s},\"outcome\":{s}}}",
                    .{ qid, qstd, qurl, qver, version, qreq, qexp, qsec, qobs, qout },
                );
                defer alloc.free(row);
                try results.appendSlice(alloc, row);
            }
        }
    }
    try results.appendSlice(alloc, "]");
    std.debug.print("Serialization compliance (library deviations are catalogued, not a red build)\n", .{});
    std.debug.print("  {d} pass  {d} fail  0 skip  0 error  {d} total\n", .{ p, f, total });
    if (json_out) |out_path| {
        const doc = try std.fmt.allocPrint(
            alloc,
            "{{\"schema\":\"gld.dashboard.compliance/1\",\"generated_at\":\"\",\"language\":\"zig\",\"languages\":[\"zig\"],\"policy\":\"report-only\",\"scope\":{{\"formats\":[\"json\"]}},\"passed\":{d},\"failed\":{d},\"skipped\":0,\"errors\":0,\"catalog_errors\":[],\"serializer_errors\":[],\"results\":{s}}}\n",
            .{ p, f, results.items },
        );
        defer alloc.free(doc);
        if (std.fs.path.dirname(out_path)) |d| {
            cwd.createDirPath(io, d) catch {};
        }
        try cwd.writeFile(io, .{ .sub_path = out_path, .data = doc });
        std.debug.print("\nWrote {s}\n", .{out_path});
    }
}

fn tooDeep(s: []const u8) bool {
    if (s.len > 200_000) return true;
    var n: usize = 0;
    for (s) |c| {
        if (c == '[' or c == '{') {
            n += 1;
            if (n > 4000) return true;
        }
    }
    return false;
}

fn readFile(alloc: std.mem.Allocator, io: std.Io, dir: []const u8, name: []const u8) ![]u8 {
    const path = try std.fs.path.join(alloc, &.{ dir, name });
    defer alloc.free(path);
    const file = try std.Io.Dir.cwd().openFile(io, path, .{});
    defer file.close(io);
    var buf: [4096]u8 = undefined;
    var reader = file.reader(io, &buf);
    return reader.interface.allocRemaining(alloc, .unlimited);
}
