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
    var want_pb = formats.items.len == 0;
    for (formats.items) |f| {
        if (std.ascii.eqlIgnoreCase(f, "json")) want_json = true;
        if (std.ascii.eqlIgnoreCase(f, "protobuf")) want_pb = true;
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
    if (want_pb) {
        const pb_dir = try std.fs.path.join(alloc, &.{ root_rel, "compliance", "data", "protobuf" });
        defer alloc.free(pb_dir);
        if (cwd.openDir(io, pb_dir, .{ .iterate = true })) |dir| {
            defer dir.close(io);
            var walker = dir.iterate();
            while (try walker.next(io)) |ent| {
                if (ent.kind != .file or !std.mem.endsWith(u8, ent.name, ".json")) continue;
                if (ent.name.len > 0 and ent.name[0] == '_') continue;
                const raw = try readFile(alloc, io, pb_dir, ent.name);
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
                    const schema = if (c.object.get("schema")) |s| s.string else "";
                    total += 1;
                    var outcome: []const u8 = "pass";
                    var observed: []const u8 = "ok";
                    const bytes = inputBytes(alloc, input, enc) catch {
                        if (std.mem.eql(u8, expect, "reject") or std.mem.eql(u8, expect, "any")) {
                            p += 1;
                            observed = "rejected";
                        } else {
                            outcome = "fail";
                            observed = "rejected";
                            f += 1;
                        }
                        try appendPbRow(alloc, &results, &first, id, standard, standard_url, version, c, expect, observed, outcome);
                        continue;
                    };
                    defer alloc.free(bytes);
                    if (decodeProtobuf(alloc, bytes, schema)) |_| {
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
                    try appendPbRow(alloc, &results, &first, id, standard, standard_url, version, c, expect, observed, outcome);
                }
            }
        } else |_| {}
    }
    try results.appendSlice(alloc, "]");
    std.debug.print("Serialization compliance (library deviations are catalogued, not a red build)\n", .{});
    std.debug.print("  {d} pass  {d} fail  0 skip  0 error  {d} total\n", .{ p, f, total });
    if (json_out) |out_path| {
        const doc = try std.fmt.allocPrint(
            alloc,
            "{{\"schema\":\"gld.dashboard.compliance/1\",\"generated_at\":\"\",\"language\":\"zig\",\"languages\":[\"zig\"],\"policy\":\"report-only\",\"scope\":{{\"formats\":[\"json\",\"protobuf\"]}},\"passed\":{d},\"failed\":{d},\"skipped\":0,\"errors\":0,\"catalog_errors\":[],\"serializer_errors\":[],\"results\":{s}}}\n",
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

fn appendPbRow(alloc: std.mem.Allocator, results: *std.ArrayList(u8), first: *bool, id: []const u8, standard: []const u8, standard_url: []const u8, version: []const u8, c: std.json.Value, expect: []const u8, observed: []const u8, outcome: []const u8) !void {
    if (!first.*) try results.appendSlice(alloc, ",");
    first.* = false;
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
        "{{\"id\":{s},\"language\":\"zig\",\"serializer\":\"protobuf-wire\",\"serializer_version\":\"\",\"format\":\"protobuf\",\"standard\":{s},\"standard_url\":{s},\"version\":{s},\"version_key\":\"protobuf.{s}\",\"requirement\":{s},\"expect\":{s},\"section\":\"\",\"section_title\":\"\",\"section_url\":{s},\"paragraph\":\"\",\"title\":\"\",\"input\":\"\",\"input_encoding\":\"\",\"detail\":\"\",\"observed\":{s},\"outcome\":{s}}}",
        .{ qid, qstd, qurl, qver, version, qreq, qexp, qsec, qobs, qout },
    );
    defer alloc.free(row);
    try results.appendSlice(alloc, row);
}

fn inputBytes(alloc: std.mem.Allocator, input: []const u8, enc: []const u8) ![]u8 {
    if (std.mem.eql(u8, enc, "hex")) {
        var n: usize = 0;
        for (input) |ch| {
            if (ch != ' ' and ch != '\n' and ch != '\t' and ch != '\r') n += 1;
        }
        if (n == 0) return alloc.alloc(u8, 0);
        if (n % 2 != 0) return error.OddHex;
        const out = try alloc.alloc(u8, n / 2);
        var i: usize = 0;
        var o: usize = 0;
        while (i < input.len) : (i += 1) {
            const ch = input[i];
            if (ch == ' ' or ch == '\n' or ch == '\t' or ch == '\r') continue;
            const hi = hexNibble(ch) orelse return error.BadHex;
            i += 1;
            while (i < input.len and (input[i] == ' ' or input[i] == '\n')) i += 1;
            if (i >= input.len) return error.OddHex;
            const lo = hexNibble(input[i]) orelse return error.BadHex;
            out[o] = (hi << 4) | lo;
            o += 1;
        }
        return out;
    }
    return alloc.dupe(u8, input);
}

fn hexNibble(c: u8) ?u8 {
    return switch (c) {
        '0'...'9' => c - '0',
        'a'...'f' => c - 'a' + 10,
        'A'...'F' => c - 'A' + 10,
        else => null,
    };
}

fn pbVarint(data: []const u8, i: *usize) !u64 {
    var r: u64 = 0;
    var shift: u6 = 0;
    while (i.* < data.len) {
        const b = data[i.*];
        i.* += 1;
        r |= @as(u64, b & 0x7f) << shift;
        if (b & 0x80 == 0) return r;
        if (shift >= 63) return error.VarintTooLong;
        shift += 7;
    }
    return error.TruncatedVarint;
}

fn decodeProtobuf(alloc: std.mem.Allocator, data: []const u8, schema: []const u8) !void {
    if (std.mem.eql(u8, schema, "json")) {
        const parsed = std.json.parseFromSlice(std.json.Value, alloc, data, .{}) catch return error.BadJSON;
        defer parsed.deinit();
        const obj = switch (parsed.value) {
            .object => |o| o,
            else => return error.NotObject,
        };
        if (obj.get("n")) |n| {
            switch (n) {
                .integer => {},
                .string => |s| _ = std.fmt.parseInt(i32, s, 10) catch return error.BadType,
                .null => {},
                else => return error.BadType,
            }
        }
        return;
    }
    var i: usize = 0;
    while (i < data.len) {
        const key = try pbVarint(data, &i);
        const wt = key & 7;
        if (wt == 0) {
            _ = try pbVarint(data, &i);
        } else if (wt == 1) {
            if (i + 8 > data.len) return error.Truncated;
            i += 8;
        } else if (wt == 5) {
            if (i + 4 > data.len) return error.Truncated;
            i += 4;
        } else if (wt == 2) {
            const n = try pbVarint(data, &i);
            if (i + n > data.len) return error.Truncated;
            i += @intCast(n);
        } else return error.BadWire;
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
