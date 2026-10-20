//! gld-avro adapter (leo-gan/gld-avro-zig).
//!
//! Prepare parses the suite `.avsc` once and copies each fixture into a
//! `Datum` (untimed). Timed serialize is `Datum.encodeTo` into a reused
//! writer buffer. Timed deserialize is `decodeBin`.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const avro = @import("avro");

pub const version = avro.version;

const Tag = enum(u3) {
    message,
    document,
    telemetry,
    strings,
    event,

    fn of(fx: data.Fixture) error{Unsupported}!Tag {
        return switch (fx) {
            .message => .message,
            .document => .document,
            .telemetry => .telemetry,
            .strings => .strings,
            .event => .event,
            else => error.Unsupported,
        };
    }
};

const message_avsc =
    \\{"type":"record","name":"Message","fields":[
    \\{"name":"f_bool","type":"boolean"},
    \\{"name":"f_int32","type":"int"},
    \\{"name":"f_int64","type":"long"},
    \\{"name":"f_float64","type":"double"},
    \\{"name":"f_string","type":"string"},
    \\{"name":"f_bool_2","type":"boolean"},
    \\{"name":"f_int32_2","type":"int"},
    \\{"name":"f_string_2","type":"string"}]}
;

const document_avsc =
    \\{"type":"record","name":"Document","fields":[
    \\{"name":"id","type":"string"},
    \\{"name":"status","type":"int"},
    \\{"name":"meta","type":{"type":"record","name":"DocumentMeta","fields":[
    \\{"name":"region","type":"string"},{"name":"version","type":"int"}]}},
    \\{"name":"items","type":{"type":"array","items":{"type":"record","name":"DocumentItem","fields":[
    \\{"name":"sku","type":"string"},{"name":"qty","type":"int"},{"name":"price_minor","type":"long"}]}}}]}
;

const telemetry_avsc =
    \\{"type":"record","name":"Telemetry","fields":[
    \\{"name":"source","type":"string"},
    \\{"name":"ts","type":"long"},
    \\{"name":"tags","type":{"type":"array","items":"string"}},
    \\{"name":"values","type":{"type":"array","items":"double"}}]}
;

const strings_avsc =
    \\{"type":"record","name":"Strings","fields":[
    \\{"name":"items","type":{"type":"array","items":"string"}}]}
;

const event_avsc =
    \\{"type":"record","name":"Event","fields":[
    \\{"name":"event_id","type":"string"},
    \\{"name":"event_type","type":"string"},
    \\{"name":"occurred_at","type":"long"},
    \\{"name":"producer","type":"string"},
    \\{"name":"attrs","type":{"type":"array","items":{"type":"record","name":"EventAttr","fields":[
    \\{"name":"key","type":"string"},{"name":"value","type":"string"}]}}}]}
;

fn schemaText(tag: Tag) []const u8 {
    return switch (tag) {
        .message => message_avsc,
        .document => document_avsc,
        .telemetry => telemetry_avsc,
        .strings => strings_avsc,
        .event => event_avsc,
    };
}

pub const State = struct {
    gpa: std.mem.Allocator = std.heap.page_allocator,
    writer: avro.Writer = undefined,
    pools: [5]?*avro.SchemaPool = .{ null, null, null, null, null },
    datums: []avro.Datum = &.{},
    enc_i: usize = 0,
    ready: bool = false,

    fn ensure(self: *State) void {
        if (self.ready) return;
        self.gpa = std.heap.page_allocator;
        self.writer = avro.Writer.init(self.gpa);
        self.ready = true;
    }

    fn clearDatums(self: *State) void {
        for (self.datums) |*d| d.deinit();
        if (self.datums.len != 0) self.gpa.free(self.datums);
        self.datums = &.{};
    }
};

pub var state: State = .{};

pub fn supports(type_id: []const u8) bool {
    return std.mem.eql(u8, type_id, "message") or
        std.mem.eql(u8, type_id, "document") or
        std.mem.eql(u8, type_id, "telemetry") or
        std.mem.eql(u8, type_id, "strings") or
        std.mem.eql(u8, type_id, "event");
}

pub fn prepare(ctx: *anyopaque, _: std.mem.Allocator, fixtures: []const data.Fixture) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    self.clearDatums();
    self.enc_i = 0;
    if (fixtures.len == 0) return;
    const tag = try Tag.of(fixtures[0]);
    const pool = try poolFor(self, tag);
    const datums = try self.gpa.alloc(avro.Datum, fixtures.len);
    var n: usize = 0;
    errdefer {
        for (datums[0..n]) |*d| d.deinit();
        self.gpa.free(datums);
    }
    for (fixtures) |fx| {
        if (try Tag.of(fx) != tag) return error.MixedFixtures;
        datums[n] = try buildDatum(pool, self.gpa, fx);
        n += 1;
    }
    self.datums = datums;
}

pub fn beginEncode(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.enc_i = 0;
}

pub fn serialize(ctx: *anyopaque, _: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (!self.ready or self.enc_i >= self.datums.len) return error.AvroNotPrepared;
    const datum = &self.datums[self.enc_i];
    self.enc_i += 1;
    self.writer.len = 0;
    try datum.encodeTo(&self.writer);
    try out.appendSlice(self.writer.slice());
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    const tag = tagFromId(type_id) orelse return error.UnknownTypeId;
    const pool = try poolFor(self, tag);
    // Page allocator, not the trial arena: the pool keeps one decode slab.
    var datum = try avro.decodeBin(self.gpa, pool, pool.root, bytes);
    defer datum.deinit();
    return switch (tag) {
        .message => .{ .message = try messageFrom(allocator, &datum) },
        .document => .{ .document = try documentFrom(allocator, &datum) },
        .telemetry => .{ .telemetry = try telemetryFrom(allocator, &datum) },
        .strings => .{ .strings = try stringsFrom(allocator, &datum) },
        .event => .{ .event = try eventFrom(allocator, &datum) },
    };
}

fn poolFor(self: *State, tag: Tag) !*avro.SchemaPool {
    const i = @intFromEnum(tag);
    if (self.pools[i]) |p| return p;
    const p = try self.gpa.create(avro.SchemaPool);
    errdefer self.gpa.destroy(p);
    p.* = try avro.parseAvsc(self.gpa, schemaText(tag));
    self.pools[i] = p;
    return p;
}

fn tagFromId(type_id: []const u8) ?Tag {
    if (std.mem.eql(u8, type_id, "message")) return .message;
    if (std.mem.eql(u8, type_id, "document")) return .document;
    if (std.mem.eql(u8, type_id, "telemetry")) return .telemetry;
    if (std.mem.eql(u8, type_id, "strings")) return .strings;
    if (std.mem.eql(u8, type_id, "event")) return .event;
    return null;
}

fn fld(pool: *const avro.SchemaPool, rec: u32, i: usize) u32 {
    return pool.nodes.items[rec].fields[i].type_id;
}

fn buildDatum(pool: *avro.SchemaPool, gpa: std.mem.Allocator, fx: data.Fixture) !avro.Datum {
    return switch (fx) {
        .message => |m| try buildMessage(pool, gpa, m),
        .document => |d| try buildDocument(pool, gpa, d),
        .telemetry => |t| try buildTelemetry(pool, gpa, t),
        .strings => |s| try buildStrings(pool, gpa, s),
        .event => |e| try buildEvent(pool, gpa, e),
        else => error.Unsupported,
    };
}

fn buildMessage(pool: *avro.SchemaPool, gpa: std.mem.Allocator, m: data.Message) !avro.Datum {
    var d = avro.Datum.init(gpa, pool);
    errdefer d.deinit();
    const root = pool.root;
    const f = pool.nodes.items[root].fields;
    d.root = try d.putRecord(root, &.{
        try d.putBool(f[0].type_id, m.f_bool),
        try d.putInt(f[1].type_id, m.f_int32),
        try d.putLong(f[2].type_id, m.f_int64),
        try d.putDouble(f[3].type_id, m.f_float64),
        try d.putString(f[4].type_id, m.f_string),
        try d.putBool(f[5].type_id, m.f_bool_2),
        try d.putInt(f[6].type_id, m.f_int32_2),
        try d.putString(f[7].type_id, m.f_string_2),
    });
    d.root_schema = root;
    return d;
}

fn buildDocument(pool: *avro.SchemaPool, gpa: std.mem.Allocator, doc: data.Document) !avro.Datum {
    var d = avro.Datum.init(gpa, pool);
    errdefer d.deinit();
    const root = pool.root;
    const meta_id = fld(pool, root, 2);
    const meta_f = pool.nodes.items[meta_id].fields;
    const meta = try d.putRecord(meta_id, &.{
        try d.putString(meta_f[0].type_id, doc.meta.region),
        try d.putInt(meta_f[1].type_id, doc.meta.version),
    });
    const items = try putDocumentItems(&d, pool, doc.items);
    d.root = try d.putRecord(root, &.{
        try d.putString(fld(pool, root, 0), doc.id),
        try d.putInt(fld(pool, root, 1), doc.status),
        meta,
        items,
    });
    d.root_schema = root;
    return d;
}

fn putDocumentItems(d: *avro.Datum, pool: *avro.SchemaPool, items: []const data.DocumentItem) !u32 {
    const array_id = fld(pool, pool.root, 3);
    const item_id = pool.nodes.items[array_id].item_id;
    const f = pool.nodes.items[item_id].fields;
    var ids: std.ArrayList(u32) = .empty;
    defer ids.deinit(d.gpa);
    try ids.ensureTotalCapacity(d.gpa, items.len);
    for (items) |it| {
        ids.appendAssumeCapacity(try d.putRecord(item_id, &.{
            try d.putString(f[0].type_id, it.sku),
            try d.putInt(f[1].type_id, it.qty),
            try d.putLong(f[2].type_id, it.price_minor),
        }));
    }
    return d.putArray(array_id, ids.items);
}

fn buildTelemetry(pool: *avro.SchemaPool, gpa: std.mem.Allocator, t: data.Telemetry) !avro.Datum {
    var d = avro.Datum.init(gpa, pool);
    errdefer d.deinit();
    const root = pool.root;
    const tags = try putStrings(&d, fld(pool, root, 2), t.tags);
    const values = try putDoubles(&d, fld(pool, root, 3), t.values);
    d.root = try d.putRecord(root, &.{
        try d.putString(fld(pool, root, 0), t.source),
        try d.putLong(fld(pool, root, 1), t.ts),
        tags,
        values,
    });
    d.root_schema = root;
    return d;
}

fn buildStrings(pool: *avro.SchemaPool, gpa: std.mem.Allocator, s: data.Strings) !avro.Datum {
    var d = avro.Datum.init(gpa, pool);
    errdefer d.deinit();
    const root = pool.root;
    const items = try putStrings(&d, fld(pool, root, 0), s.items);
    d.root = try d.putRecord(root, &.{items});
    d.root_schema = root;
    return d;
}

fn buildEvent(pool: *avro.SchemaPool, gpa: std.mem.Allocator, e: data.Event) !avro.Datum {
    var d = avro.Datum.init(gpa, pool);
    errdefer d.deinit();
    const root = pool.root;
    const attrs = try putAttrs(&d, pool, e.attrs);
    d.root = try d.putRecord(root, &.{
        try d.putString(fld(pool, root, 0), e.event_id),
        try d.putString(fld(pool, root, 1), e.event_type),
        try d.putLong(fld(pool, root, 2), e.occurred_at),
        try d.putString(fld(pool, root, 3), e.producer),
        attrs,
    });
    d.root_schema = root;
    return d;
}

fn putStrings(d: *avro.Datum, array_id: u32, values: []const []const u8) !u32 {
    const item_id = d.pool.nodes.items[array_id].item_id;
    var ids: std.ArrayList(u32) = .empty;
    defer ids.deinit(d.gpa);
    try ids.ensureTotalCapacity(d.gpa, values.len);
    for (values) |s| ids.appendAssumeCapacity(try d.putString(item_id, s));
    return d.putArray(array_id, ids.items);
}

fn putDoubles(d: *avro.Datum, array_id: u32, values: []const f64) !u32 {
    const item_id = d.pool.nodes.items[array_id].item_id;
    var ids: std.ArrayList(u32) = .empty;
    defer ids.deinit(d.gpa);
    try ids.ensureTotalCapacity(d.gpa, values.len);
    for (values) |v| ids.appendAssumeCapacity(try d.putDouble(item_id, v));
    return d.putArray(array_id, ids.items);
}

fn putAttrs(d: *avro.Datum, pool: *avro.SchemaPool, attrs: []const data.EventAttr) !u32 {
    const array_id = fld(pool, pool.root, 4);
    const item_id = pool.nodes.items[array_id].item_id;
    const f = pool.nodes.items[item_id].fields;
    var ids: std.ArrayList(u32) = .empty;
    defer ids.deinit(d.gpa);
    try ids.ensureTotalCapacity(d.gpa, attrs.len);
    for (attrs) |a| {
        ids.appendAssumeCapacity(try d.putRecord(item_id, &.{
            try d.putString(f[0].type_id, a.key),
            try d.putString(f[1].type_id, a.value),
        }));
    }
    return d.putArray(array_id, ids.items);
}

fn messageFrom(allocator: std.mem.Allocator, d: *const avro.Datum) !data.Message {
    const root = d.root;
    return .{
        .f_bool = try d.asBool(try d.recordAt(root, 0)),
        .f_int32 = try d.asInt(try d.recordAt(root, 1)),
        .f_int64 = try d.asLong(try d.recordAt(root, 2)),
        .f_float64 = try d.asDouble(try d.recordAt(root, 3)),
        .f_string = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 4))),
        .f_bool_2 = try d.asBool(try d.recordAt(root, 5)),
        .f_int32_2 = try d.asInt(try d.recordAt(root, 6)),
        .f_string_2 = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 7))),
    };
}

fn documentFrom(allocator: std.mem.Allocator, d: *const avro.Datum) !data.Document {
    const root = d.root;
    const meta = try d.recordAt(root, 2);
    const arr = try d.recordAt(root, 3);
    const n = try d.arrayLen(arr);
    const items = try allocator.alloc(data.DocumentItem, n);
    for (items, 0..) |*it, i| {
        const rec = try d.arrayAt(arr, i);
        it.* = .{
            .sku = try allocator.dupe(u8, try d.asString(try d.recordAt(rec, 0))),
            .qty = try d.asInt(try d.recordAt(rec, 1)),
            .price_minor = try d.asLong(try d.recordAt(rec, 2)),
        };
    }
    return .{
        .id = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 0))),
        .status = try d.asInt(try d.recordAt(root, 1)),
        .meta = .{
            .region = try allocator.dupe(u8, try d.asString(try d.recordAt(meta, 0))),
            .version = try d.asInt(try d.recordAt(meta, 1)),
        },
        .items = items,
    };
}

fn telemetryFrom(allocator: std.mem.Allocator, d: *const avro.Datum) !data.Telemetry {
    const root = d.root;
    const tags_id = try d.recordAt(root, 2);
    const values_id = try d.recordAt(root, 3);
    const nt = try d.arrayLen(tags_id);
    const nv = try d.arrayLen(values_id);
    const tags = try allocator.alloc([]const u8, nt);
    for (tags, 0..) |*s, i| {
        s.* = try allocator.dupe(u8, try d.asString(try d.arrayAt(tags_id, i)));
    }
    const values = try allocator.alloc(f64, nv);
    for (values, 0..) |*v, i| v.* = try d.asDouble(try d.arrayAt(values_id, i));
    return .{
        .source = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 0))),
        .ts = try d.asLong(try d.recordAt(root, 1)),
        .tags = tags,
        .values = values,
    };
}

fn stringsFrom(allocator: std.mem.Allocator, d: *const avro.Datum) !data.Strings {
    const arr = try d.recordAt(d.root, 0);
    const n = try d.arrayLen(arr);
    const items = try allocator.alloc([]const u8, n);
    for (items, 0..) |*s, i| {
        s.* = try allocator.dupe(u8, try d.asString(try d.arrayAt(arr, i)));
    }
    return .{ .items = items };
}

fn eventFrom(allocator: std.mem.Allocator, d: *const avro.Datum) !data.Event {
    const root = d.root;
    const arr = try d.recordAt(root, 4);
    const n = try d.arrayLen(arr);
    const attrs = try allocator.alloc(data.EventAttr, n);
    for (attrs, 0..) |*a, i| {
        const rec = try d.arrayAt(arr, i);
        a.* = .{
            .key = try allocator.dupe(u8, try d.asString(try d.recordAt(rec, 0))),
            .value = try allocator.dupe(u8, try d.asString(try d.recordAt(rec, 1))),
        };
    }
    return .{
        .event_id = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 0))),
        .event_type = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 1))),
        .occurred_at = try d.asLong(try d.recordAt(root, 2)),
        .producer = try allocator.dupe(u8, try d.asString(try d.recordAt(root, 3))),
        .attrs = attrs,
    };
}
