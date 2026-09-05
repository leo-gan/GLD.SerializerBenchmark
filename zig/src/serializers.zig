//! Serializer trait, registry, and first-wave implementations.
//!
//! Registry of wired serializers (see docs/zig/index.md).

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const json_util = @import("json_util.zig");
const packed_bin = @import("packed_bin.zig");
const serde_ser = @import("serde_ser.zig");
const extra = @import("extra.zig");
const proto_ser = @import("proto_ser.zig");
const fb_ser = @import("fb_ser.zig");
const capnp_ser = @import("capnp_ser.zig");

pub const StreamMode = enum {
    native,
    adapted,
    text_on_stream,

    pub fn label(self: StreamMode) []const u8 {
        return switch (self) {
            .native => "native",
            .adapted => "adapted",
            .text_on_stream => "text_on_stream",
        };
    }
};

pub const NativeKind = enum {
    comptime_map,
    message,
    direct,
    value_tree,

    pub fn label(self: NativeKind) []const u8 {
        return switch (self) {
            .comptime_map => "comptime",
            .message => "message",
            .direct => "direct",
            .value_tree => "value",
        };
    }
};

pub const Serializer = struct {
    name: []const u8,
    version: []const u8,
    stream_mode: StreamMode,
    native_kind: NativeKind,
    ctx: *anyopaque,
    vtable: *const VTable,

    pub const VTable = struct {
        prepare: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, fixtures: []const data.Fixture) anyerror!void,
        begin_encode: *const fn (ctx: *anyopaque) void = Dummy.beginEncode,
        serialize: *const fn (ctx: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) anyerror!void,
        deserialize: *const fn (ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) anyerror!data.Fixture,
        supports: *const fn (type_id: []const u8) bool = supportAll,
    };

    pub fn supports(self: Serializer, type_id: []const u8) bool {
        return self.vtable.supports(type_id);
    }

    pub fn prepare(self: Serializer, allocator: std.mem.Allocator, fixtures: []const data.Fixture) !void {
        return self.vtable.prepare(self.ctx, allocator, fixtures);
    }

    pub fn beginEncode(self: Serializer) void {
        self.vtable.begin_encode(self.ctx);
    }

    pub fn serialize(self: Serializer, fx: data.Fixture, out: *buf_mod.Buf) !void {
        return self.vtable.serialize(self.ctx, fx, out);
    }

    pub fn deserialize(self: Serializer, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
        return self.vtable.deserialize(self.ctx, allocator, type_id, bytes);
    }
};

const Dummy = struct {
    fn prepare(_: *anyopaque, _: std.mem.Allocator, _: []const data.Fixture) !void {}
    fn beginEncode(_: *anyopaque) void {}
};

fn supportAll(_: []const u8) bool {
    return true;
}

fn yamlSupports(type_id: []const u8) bool {
    // serde.zig 1.0.7 YAML list-of-struct indentation fails to round-trip
    // nested suite types (document items, event attrs).
    return std.mem.eql(u8, type_id, "message") or std.mem.eql(u8, type_id, "strings");
}

fn xmlSupports(type_id: []const u8) bool {
    // serde.xml 1.0.7 MalformedXml on nested document items.
    return std.mem.eql(u8, type_id, "message") or std.mem.eql(u8, type_id, "strings");
}

const json_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = jsonSerialize,
    .deserialize = jsonDeserialize,
};

fn jsonSerialize(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try json_util.stringifyFixture(fx, out);
}

fn jsonDeserialize(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return json_util.parseFixture(allocator, type_id, bytes);
}

const scanner_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = jsonSerialize,
    .deserialize = scannerDeserialize,
};

fn scannerDeserialize(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return json_util.parseFixtureScanner(allocator, type_id, bytes);
}

const packed_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = packedSerialize,
    .deserialize = packedDeserialize,
};

fn packedSerialize(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try packed_bin.encodeFixture(fx, out);
}

fn packedDeserialize(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return packed_bin.decodeFixture(allocator, type_id, bytes);
}

var json_state: u8 = 0;
var scanner_state: u8 = 0;
var packed_state: u8 = 0;
var serde_json_state: u8 = 0;
var serde_msgpack_state: u8 = 0;
var serde_yaml_state: u8 = 0;
var serde_toml_state: u8 = 0;
var serde_zon_state: u8 = 0;
var serde_xml_state: u8 = 0;
var std_zon_state: u8 = 0;
var zig_msgpack_state: u8 = 0;
var zbor_state: u8 = 0;
var msgpack_l_state: u8 = 0;
var s2s_state: u8 = 0;

const serde_json_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeJsonSer,
    .deserialize = serdeJsonDe,
};
const serde_msgpack_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeMsgpackSer,
    .deserialize = serdeMsgpackDe,
};
const serde_yaml_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeYamlSer,
    .deserialize = serdeYamlDe,
    .supports = yamlSupports,
};
const serde_toml_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeTomlSer,
    .deserialize = serdeTomlDe,
};
const serde_zon_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeZonSer,
    .deserialize = serdeZonDe,
};

fn serdeJsonSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.json, fx, out);
}
fn serdeJsonDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.json, allocator, type_id, bytes);
}
fn serdeMsgpackSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.msgpack, fx, out);
}
fn serdeMsgpackDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.msgpack, allocator, type_id, bytes);
}
fn serdeYamlSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.yaml, fx, out);
}
fn serdeYamlDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.yaml, allocator, type_id, bytes);
}
fn serdeTomlSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.toml, fx, out);
}
fn serdeTomlDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.toml, allocator, type_id, bytes);
}
fn serdeZonSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.zon, fx, out);
}
fn serdeZonDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.zon, allocator, type_id, bytes);
}
fn serdeXmlSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try serde_ser.encode(.xml, fx, out);
}
fn serdeXmlDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return serde_ser.decode(.xml, allocator, type_id, bytes);
}

const serde_xml_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = serdeXmlSer,
    .deserialize = serdeXmlDe,
    .supports = xmlSupports,
};
const std_zon_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = extraStdZonSer,
    .deserialize = extraStdZonDe,
};
const zig_msgpack_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = extraZigMsgpackSer,
    .deserialize = extraZigMsgpackDe,
};
const zbor_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = extraZborSer,
    .deserialize = extraZborDe,
};
const msgpack_l_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = extraLalinskySer,
    .deserialize = extraLalinskyDe,
};
const s2s_vtable = Serializer.VTable{
    .prepare = Dummy.prepare,
    .serialize = extraS2sSer,
    .deserialize = extraS2sDe,
};
fn extraStdZonSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try extra.encodeStdZon(fx, out);
}
fn extraStdZonDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return extra.decodeStdZon(allocator, type_id, bytes);
}
fn extraZigMsgpackSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try extra.encodeZigMsgpack(fx, out);
}
fn extraZigMsgpackDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return extra.decodeZigMsgpack(allocator, type_id, bytes);
}
fn extraZborSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try extra.encodeZbor(fx, out);
}
fn extraZborDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return extra.decodeZbor(allocator, type_id, bytes);
}
fn extraLalinskySer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try extra.encodeLalinsky(fx, out);
}
fn extraLalinskyDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return extra.decodeLalinsky(allocator, type_id, bytes);
}
fn extraS2sSer(_: *anyopaque, fx: data.Fixture, out: *buf_mod.Buf) !void {
    try extra.encodeS2s(fx, out);
}
fn extraS2sDe(_: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    return extra.decodeS2s(allocator, type_id, bytes);
}

const protobuf_vtable = Serializer.VTable{
    .prepare = proto_ser.prepare,
    .begin_encode = proto_ser.beginEncode,
    .serialize = proto_ser.serialize,
    .deserialize = proto_ser.deserialize,
};
const flatbuffers_vtable = Serializer.VTable{
    .prepare = fb_ser.prepare,
    .begin_encode = fb_ser.beginEncode,
    .serialize = fb_ser.serialize,
    .deserialize = fb_ser.deserialize,
};
const capnproto_vtable = Serializer.VTable{
    .prepare = capnp_ser.prepare,
    .begin_encode = capnp_ser.beginEncode,
    .serialize = capnp_ser.serialize,
    .deserialize = capnp_ser.deserialize,
};

pub fn allSerializers() [17]Serializer {
    return .{
        .{
            .name = "std.json",
            .version = builtinZigVersion(),
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&json_state),
            .vtable = &json_vtable,
        },
        .{
            .name = "std.json.scanner",
            .version = builtinZigVersion(),
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&scanner_state),
            .vtable = &scanner_vtable,
        },
        .{
            .name = "comptime-bin",
            .version = "in-tree",
            .stream_mode = .adapted,
            .native_kind = .direct,
            .ctx = @ptrCast(&packed_state),
            .vtable = &packed_vtable,
        },
        .{
            .name = "serde.json",
            .version = "1.0.7",
            .stream_mode = .adapted,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_json_state),
            .vtable = &serde_json_vtable,
        },
        .{
            .name = "serde.msgpack",
            .version = "1.0.7",
            .stream_mode = .adapted,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_msgpack_state),
            .vtable = &serde_msgpack_vtable,
        },
        .{
            .name = "serde.yaml",
            .version = "1.0.7",
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_yaml_state),
            .vtable = &serde_yaml_vtable,
        },
        .{
            .name = "serde.toml",
            .version = "1.0.7",
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_toml_state),
            .vtable = &serde_toml_vtable,
        },
        .{
            .name = "serde.zon",
            .version = "1.0.7",
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_zon_state),
            .vtable = &serde_zon_vtable,
        },
        .{
            .name = "serde.xml",
            .version = "1.0.7",
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&serde_xml_state),
            .vtable = &serde_xml_vtable,
        },
        .{
            .name = "std.zon",
            .version = builtinZigVersion(),
            .stream_mode = .text_on_stream,
            .native_kind = .comptime_map,
            .ctx = @ptrCast(&std_zon_state),
            .vtable = &std_zon_vtable,
        },
        .{
            .name = "zig-msgpack",
            .version = "0.0.14",
            .stream_mode = .adapted,
            .native_kind = .value_tree,
            .ctx = @ptrCast(&zig_msgpack_state),
            .vtable = &zig_msgpack_vtable,
        },
        .{
            .name = "zbor",
            .version = "0.21.0",
            .stream_mode = .adapted,
            .native_kind = .direct,
            .ctx = @ptrCast(&zbor_state),
            .vtable = &zbor_vtable,
        },
        .{
            .name = "msgpack.zig",
            .version = "0.9.0",
            .stream_mode = .native,
            .native_kind = .direct,
            .ctx = @ptrCast(&msgpack_l_state),
            .vtable = &msgpack_l_vtable,
        },
        .{
            .name = "s2s",
            .version = "0.0.1",
            .stream_mode = .native,
            .native_kind = .direct,
            .ctx = @ptrCast(&s2s_state),
            .vtable = &s2s_vtable,
        },
        .{
            .name = "protobuf",
            .version = proto_ser.version,
            .stream_mode = .adapted,
            .native_kind = .message,
            .ctx = @ptrCast(&proto_ser.state),
            .vtable = &protobuf_vtable,
        },
        .{
            .name = "flatbuffers",
            .version = fb_ser.version,
            .stream_mode = .adapted,
            .native_kind = .message,
            .ctx = @ptrCast(&fb_ser.state),
            .vtable = &flatbuffers_vtable,
        },
        .{
            .name = "capnproto",
            .version = capnp_ser.version,
            .stream_mode = .adapted,
            .native_kind = .message,
            .ctx = @ptrCast(&capnp_ser.state),
            .vtable = &capnproto_vtable,
        },
    };
}

fn builtinZigVersion() []const u8 {
    return @import("builtin").zig_version_string;
}

fn named(all: []const Serializer, name: []const u8) ?Serializer {
    for (all) |s| {
        if (std.mem.eql(u8, s.name, name)) return s;
    }
    return null;
}

pub fn select(filter: []const u8, out: []Serializer) usize {
    const all = allSerializers();
    var n: usize = 0;
    for (all) |s| {
        if (filter.len > 0) {
            if (std.ascii.indexOfIgnoreCase(s.name, filter) == null) continue;
        }
        if (n < out.len) {
            out[n] = s;
            n += 1;
        }
    }
    return n;
}

test "std.json document round-trip" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fx = try data.makeOne(arena.allocator(), "document", 42, 0, .{});
    var out = try buf_mod.Buf.initCapacity(arena.allocator(), 1024);
    const sers = allSerializers();
    try sers[0].prepare(arena.allocator(), &.{fx});
    try sers[0].serialize(fx, &out);
    try std.testing.expect(out.len > 10);
    const back = try sers[0].deserialize(arena.allocator(), "document", out.items());
    try std.testing.expect(data.fidelity(fx, back));
}

test "std.json.scanner message round-trip" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fx = try data.makeOne(arena.allocator(), "message", 42, 0, .{});
    var out = try buf_mod.Buf.initCapacity(arena.allocator(), 512);
    const sers = allSerializers();
    try sers[1].prepare(arena.allocator(), &.{fx});
    try sers[1].serialize(fx, &out);
    const back = try sers[1].deserialize(arena.allocator(), "message", out.items());
    try std.testing.expect(data.fidelity(fx, back));
}

test "comptime-bin all v2 types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const sers = allSerializers();
    const packed_ser = sers[2];
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    for (kinds) |tid| {
        const fx = try data.makeOne(arena.allocator(), tid, 7, 0, .{});
        var out = try buf_mod.Buf.initCapacity(arena.allocator(), 2048);
        try packed_ser.prepare(arena.allocator(), &.{fx});
        try packed_ser.serialize(fx, &out);
        try std.testing.expect(out.len > 0);
        const back = try packed_ser.deserialize(arena.allocator(), tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));
    }
}

test "serde.json document round-trip" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fx = try data.makeOne(arena.allocator(), "document", 42, 0, .{});
    var out = try buf_mod.Buf.initCapacity(arena.allocator(), 2048);
    const sers = allSerializers();
    try sers[3].prepare(arena.allocator(), &.{fx});
    try sers[3].serialize(fx, &out);
    try std.testing.expect(out.len > 10);
    const back = try sers[3].deserialize(arena.allocator(), "document", out.items());
    try std.testing.expect(data.fidelity(fx, back));
}

test "all supporting serializers round-trip document" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fx = try data.makeOne(arena.allocator(), "document", 42, 0, .{});
    const sers = allSerializers();
    for (sers) |s| {
        if (!s.supports("document")) continue;
        var out = try buf_mod.Buf.initCapacity(arena.allocator(), 8192);
        s.prepare(arena.allocator(), &.{fx}) catch |e| {
            std.debug.print("prepare fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        s.beginEncode();
        s.serialize(fx, &out) catch |e| {
            std.debug.print("ser fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        try std.testing.expect(out.len > 0);
        const back = s.deserialize(arena.allocator(), "document", out.items()) catch |e| {
            std.debug.print("de fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        try std.testing.expect(data.fidelity(fx, back));
    }
}

test "all serializers round-trip message" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const fx = try data.makeOne(arena.allocator(), "message", 42, 0, .{});
    const sers = allSerializers();
    for (sers) |s| {
        if (!s.supports("message")) continue;
        var out = try buf_mod.Buf.initCapacity(arena.allocator(), 4096);
        s.prepare(arena.allocator(), &.{fx}) catch |e| {
            std.debug.print("prepare fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        s.beginEncode();
        s.serialize(fx, &out) catch |e| {
            std.debug.print("ser fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        try std.testing.expect(out.len > 0);
        const back = s.deserialize(arena.allocator(), "message", out.items()) catch |e| {
            std.debug.print("de fail {s}: {s}\n", .{ s.name, @errorName(e) });
            return e;
        };
        try std.testing.expect(data.fidelity(fx, back));
    }
}

test "schema serializers all v2 types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const sers = allSerializers();
    const names = [_][]const u8{ "protobuf", "flatbuffers", "capnproto" };
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    for (names) |name| {
        const ser = named(&sers, name) orelse return error.MissingSchemaSerializer;
        for (kinds) |tid| {
            const fx = try data.makeOne(arena.allocator(), tid, 7, 0, .{});
            var out = try buf_mod.Buf.initCapacity(arena.allocator(), 2048);
            try ser.prepare(arena.allocator(), &.{fx});
            ser.beginEncode();
            try ser.serialize(fx, &out);
            try std.testing.expect(out.len > 0);
            const back = try ser.deserialize(arena.allocator(), tid, out.items());
            try std.testing.expect(data.fidelity(fx, back));
        }
    }
}

test "protobuf all v2 types" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const sers = allSerializers();
    const pb_ser = named(&sers, "protobuf") orelse return error.MissingProtobuf;
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    for (kinds) |tid| {
        const fx = try data.makeOne(arena.allocator(), tid, 7, 0, .{});
        var out = try buf_mod.Buf.initCapacity(arena.allocator(), 2048);
        try pb_ser.prepare(arena.allocator(), &.{fx});
        pb_ser.beginEncode();
        try pb_ser.serialize(fx, &out);
        try std.testing.expect(out.len > 0);
        const back = try pb_ser.deserialize(arena.allocator(), tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));
    }
}

test "registry includes std.json" {
    var tmp: [24]Serializer = undefined;
    const n = select("", &tmp);
    try std.testing.expect(n >= 17);
    var found_pb = false;
    var found_fb = false;
    var found_capnp = false;
    for (tmp[0..n]) |s| {
        if (std.mem.eql(u8, s.name, "protobuf")) found_pb = true;
        if (std.mem.eql(u8, s.name, "flatbuffers")) found_fb = true;
        if (std.mem.eql(u8, s.name, "capnproto")) found_capnp = true;
    }
    try std.testing.expect(found_pb);
    try std.testing.expect(found_fb);
    try std.testing.expect(found_capnp);
    var found = false;
    for (tmp[0..n]) |s| {
        if (std.mem.eql(u8, s.name, "std.json")) found = true;
    }
    try std.testing.expect(found);
}


