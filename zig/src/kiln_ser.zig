//! gld-kiln adapter (leo-gan/gld-kiln-zig).
//!
//! Prepare parses each schema once. Suite fixtures are copied into kiln
//! values (untimed); timed serialize is `encodeReuse` into a reused writer
//! and timed deserialize is `decode`. Tensor values are large, so the timed
//! path writes the same positional layout through that reused writer and does
//! not rebuild the schema. `tensor` decode owns the float list. `tensor_view`
//! decode borrows the f32 payload bytes. One instance is the struct. A batch
//! is one list of that struct. Graph is not a suite type. N is 1 for tensors.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const kiln = @import("kiln");

pub const version = kiln.version;

const Tag = enum {
    message,
    document,
    telemetry,
    strings,
    event,
    tensor,
    prompt,
    shard,
    request,

    fn of(fx: data.Fixture) Tag {
        return switch (fx) {
            .message => .message,
            .document => .document,
            .telemetry => .telemetry,
            .strings => .strings,
            .event => .event,
            .tensor, .tensor_view => .tensor,
            .prompt => .prompt,
            .shard => .shard,
            .request => .request,
        };
    }

    fn direct(self: Tag) bool {
        return switch (self) {
            .tensor, .prompt, .shard, .request => true,
            else => false,
        };
    }
};

const tag_count = @typeInfo(Tag).@"enum".fields.len;

const message_text = "struct{f_bool:bool,f_int32:i32,f_int64:i64,f_float64:f64,f_string:str,f_bool_2:bool,f_int32_2:i32,f_string_2:str}";
const document_text = "struct{id:str,status:i32,meta:struct{region:str,version:i32},items:list<struct{sku:str,qty:i32,price_minor:i64}>}";
const telemetry_text = "struct{source:str,ts:i64,tags:list<str>,values:list<f64>}";
const strings_text = "struct{items:list<str>}";
const event_text = "struct{event_id:str,event_type:str,occurred_at:i64,producer:str,attrs:list<struct{key:str,value:str}>}";
const tensor_text = "struct{rows:i32,cols:i32,values:list<f32>}";
const prompt_text = "struct{batch:i32,seq:i32,input_ids:list<i64>,attention_mask:list<i64>,position_ids:list<i64>}";
const shard_text = "struct{vocab:i32,hidden:i32,ffn:i32,tok_emb:list<f32>,attn:list<f32>,ffn_weight:list<f32>,norm:list<f32>}";
const request_text = "struct{request_id:i64,model:str,temperature:f32,inputs:" ++ prompt_text ++ "}";

fn schemaText(tag: Tag) []const u8 {
    return switch (tag) {
        .message => message_text,
        .document => document_text,
        .telemetry => telemetry_text,
        .strings => strings_text,
        .event => event_text,
        .tensor => tensor_text,
        .prompt => prompt_text,
        .shard => shard_text,
        .request => request_text,
    };
}

fn listText(tag: Tag) ?[]const u8 {
    return switch (tag) {
        .message => "list<" ++ message_text ++ ">",
        .document => "list<" ++ document_text ++ ">",
        .telemetry => "list<" ++ telemetry_text ++ ">",
        .strings => "list<" ++ strings_text ++ ">",
        .event => "list<" ++ event_text ++ ">",
        .tensor, .prompt, .shard, .request => null,
    };
}

pub const State = struct {
    gpa: std.mem.Allocator = std.heap.page_allocator,
    arena: std.heap.ArenaAllocator = undefined,
    writer: kiln.Writer = .{},
    schemas: [tag_count]?*const kiln.Schema = .{null} ** tag_count,
    list_schemas: [tag_count]?*const kiln.Schema = .{null} ** tag_count,
    root: kiln.Value = .none,
    fixtures: []const data.Fixture = &.{},
    tag: Tag = .message,
    active: ?*const kiln.Schema = null,
    enc_i: usize = 0,
    batch: bool = false,
    direct: bool = false,
    has_root: bool = false,
    ready: bool = false,

    fn ensure(self: *State) void {
        if (self.ready) return;
        self.gpa = std.heap.page_allocator;
        self.arena = .init(self.gpa);
        self.writer = .{};
        self.ready = true;
    }

    fn clearRoot(self: *State) void {
        if (!self.has_root) return;
        self.root.deinit(self.gpa);
        self.root = .none;
        self.has_root = false;
        self.active = null;
    }
};

pub var state: State = .{};

pub fn supports(type_id: []const u8) bool {
    return tagFromId(type_id) != null;
}

pub fn prepare(ctx: *anyopaque, _: std.mem.Allocator, fixtures: []const data.Fixture) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    self.clearRoot();
    self.enc_i = 0;
    self.batch = false;
    self.direct = false;
    self.fixtures = &.{};
    if (fixtures.len == 0) return;
    const tag = Tag.of(fixtures[0]);
    for (fixtures) |fx| {
        if (Tag.of(fx) != tag) return error.MixedFixtures;
    }
    if (tag.direct()) {
        if (fixtures.len != 1) return error.KilnNotPrepared;
        try bindDirect(self, tag);
        self.tag = tag;
        self.direct = true;
        self.fixtures = fixtures;
        return;
    }
    const batch = fixtures.len > 1;
    const schema = try schemaFor(self, tag, batch);
    var root = if (batch)
        try buildList(self.gpa, fixtures)
    else
        try buildOne(self.gpa, fixtures[0]);
    errdefer root.deinit(self.gpa);
    self.tag = tag;
    self.batch = batch;
    self.active = schema;
    self.root = root;
    self.has_root = true;
}

pub fn beginEncode(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.enc_i = 0;
}

pub fn serialize(ctx: *anyopaque, _: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (self.direct) {
        if (!self.ready or self.active == null or self.fixtures.len != 1 or self.enc_i != 0) return error.KilnNotPrepared;
        self.enc_i += 1;
        const raw = try writeDirect(self, self.fixtures[0]);
        try out.appendSlice(raw);
        return;
    }
    if (!self.ready or !self.has_root or self.batch or self.active == null) return error.KilnNotPrepared;
    if (self.enc_i != 0) return error.KilnNotPrepared;
    self.enc_i += 1;
    const raw = try kiln.encodeReuse(&self.writer, self.gpa, self.active.?, self.root);
    try out.appendSlice(raw);
}

/// One list of the prepared structs. The runner calls this when N>1.
pub fn encodeBatch(ctx: *anyopaque, fixtures: []const data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (!self.ready or !self.has_root or !self.batch or self.active == null) return error.KilnNotPrepared;
    const n: usize = switch (self.root) {
        .list => |items| items.len,
        else => return error.KilnNotPrepared,
    };
    if (fixtures.len != n) return error.KilnNotPrepared;
    const raw = try kiln.encodeReuse(&self.writer, self.gpa, self.active.?, self.root);
    try out.appendSlice(raw);
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    const tag = tagFromId(type_id) orelse return error.UnknownTypeId;
    if (tag.direct()) {
        // Schema was parsed in prepare. Reading does not rebuild it.
        return readDirect(allocator, tag, std.mem.eql(u8, type_id, "tensor_view"), bytes);
    }
    const schema = try schemaFor(self, tag, false);
    var value = try kiln.decode(self.gpa, schema, bytes, .{});
    defer value.deinit(self.gpa);
    return fixtureFrom(allocator, tag, value);
}

pub fn decodeBatch(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) ![]data.Fixture {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.ensure();
    const tag = tagFromId(type_id) orelse return error.UnknownTypeId;
    const schema = try schemaFor(self, tag, true);
    var value = try kiln.decode(self.gpa, schema, bytes, .{});
    defer value.deinit(self.gpa);
    const items = switch (value) {
        .list => |xs| xs,
        else => return error.KilnType,
    };
    const out = try allocator.alloc(data.Fixture, items.len);
    for (items, out) |item, *slot| slot.* = try fixtureFrom(allocator, tag, item);
    return out;
}

fn schemaFor(self: *State, tag: Tag, batch: bool) !*const kiln.Schema {
    const i = @intFromEnum(tag);
    if (batch) {
        if (self.list_schemas[i]) |s| return s;
        const text = listText(tag) orelse return error.KilnNotPrepared;
        const s = try kiln.parseTypeText(self.arena.allocator(), text);
        self.list_schemas[i] = s;
        return s;
    }
    if (self.schemas[i]) |s| return s;
    const s = try kiln.parseTypeText(self.arena.allocator(), schemaText(tag));
    self.schemas[i] = s;
    return s;
}

fn tagFromId(type_id: []const u8) ?Tag {
    if (std.mem.eql(u8, type_id, "message")) return .message;
    if (std.mem.eql(u8, type_id, "document")) return .document;
    if (std.mem.eql(u8, type_id, "telemetry")) return .telemetry;
    if (std.mem.eql(u8, type_id, "strings")) return .strings;
    if (std.mem.eql(u8, type_id, "event")) return .event;
    if (std.mem.eql(u8, type_id, "tensor") or std.mem.eql(u8, type_id, "tensor_view")) return .tensor;
    if (std.mem.eql(u8, type_id, "prompt")) return .prompt;
    if (std.mem.eql(u8, type_id, "shard")) return .shard;
    if (std.mem.eql(u8, type_id, "request")) return .request;
    return null;
}

fn buildList(gpa: std.mem.Allocator, fixtures: []const data.Fixture) !kiln.Value {
    const items = try gpa.alloc(kiln.Value, fixtures.len);
    var n: usize = 0;
    errdefer {
        for (items[0..n]) |*it| it.deinit(gpa);
        gpa.free(items);
    }
    for (fixtures) |fx| {
        items[n] = try buildOne(gpa, fx);
        n += 1;
    }
    return .{ .list = items };
}

fn buildOne(gpa: std.mem.Allocator, fx: data.Fixture) !kiln.Value {
    return switch (fx) {
        .message => |m| try buildMessage(gpa, m),
        .document => |d| try buildDocument(gpa, d),
        .telemetry => |t| try buildTelemetry(gpa, t),
        .strings => |s| try buildStrings(gpa, s),
        .event => |e| try buildEvent(gpa, e),
        else => error.KilnType,
    };
}

fn buildMessage(gpa: std.mem.Allocator, m: data.Message) !kiln.Value {
    const fields = try gpa.alloc(kiln.FieldValue, 8);
    fields[0] = .{ .name = "f_bool", .value = .{ .boolean = m.f_bool } };
    fields[1] = .{ .name = "f_int32", .value = .{ .int = m.f_int32 } };
    fields[2] = .{ .name = "f_int64", .value = .{ .int = m.f_int64 } };
    fields[3] = .{ .name = "f_float64", .value = .{ .f64 = m.f_float64 } };
    fields[4] = .{ .name = "f_string", .value = .{ .str = m.f_string } };
    fields[5] = .{ .name = "f_bool_2", .value = .{ .boolean = m.f_bool_2 } };
    fields[6] = .{ .name = "f_int32_2", .value = .{ .int = m.f_int32_2 } };
    fields[7] = .{ .name = "f_string_2", .value = .{ .str = m.f_string_2 } };
    return .{ .structure = fields };
}

fn buildDocument(gpa: std.mem.Allocator, doc: data.Document) !kiln.Value {
    const meta = try gpa.alloc(kiln.FieldValue, 2);
    errdefer gpa.free(meta);
    meta[0] = .{ .name = "region", .value = .{ .str = doc.meta.region } };
    meta[1] = .{ .name = "version", .value = .{ .int = doc.meta.version } };

    const item_vals = try gpa.alloc(kiln.Value, doc.items.len);
    errdefer gpa.free(item_vals);
    var n: usize = 0;
    errdefer for (item_vals[0..n]) |*it| it.deinit(gpa);
    for (doc.items) |it| {
        const rec = try gpa.alloc(kiln.FieldValue, 3);
        rec[0] = .{ .name = "sku", .value = .{ .str = it.sku } };
        rec[1] = .{ .name = "qty", .value = .{ .int = it.qty } };
        rec[2] = .{ .name = "price_minor", .value = .{ .int = it.price_minor } };
        item_vals[n] = .{ .structure = rec };
        n += 1;
    }

    const fields = try gpa.alloc(kiln.FieldValue, 4);
    fields[0] = .{ .name = "id", .value = .{ .str = doc.id } };
    fields[1] = .{ .name = "status", .value = .{ .int = doc.status } };
    fields[2] = .{ .name = "meta", .value = .{ .structure = meta } };
    fields[3] = .{ .name = "items", .value = .{ .list = item_vals } };
    return .{ .structure = fields };
}

fn buildTelemetry(gpa: std.mem.Allocator, t: data.Telemetry) !kiln.Value {
    const tags = try gpa.alloc(kiln.Value, t.tags.len);
    errdefer gpa.free(tags);
    for (t.tags, tags) |s, *slot| slot.* = .{ .str = s };

    const values = try gpa.alloc(kiln.Value, t.values.len);
    errdefer gpa.free(values);
    for (t.values, values) |n, *slot| slot.* = .{ .f64 = n };

    const fields = try gpa.alloc(kiln.FieldValue, 4);
    fields[0] = .{ .name = "source", .value = .{ .str = t.source } };
    fields[1] = .{ .name = "ts", .value = .{ .int = t.ts } };
    fields[2] = .{ .name = "tags", .value = .{ .list = tags } };
    fields[3] = .{ .name = "values", .value = .{ .list = values } };
    return .{ .structure = fields };
}

fn buildStrings(gpa: std.mem.Allocator, s: data.Strings) !kiln.Value {
    const items = try gpa.alloc(kiln.Value, s.items.len);
    errdefer gpa.free(items);
    for (s.items, items) |text, *slot| slot.* = .{ .str = text };

    const fields = try gpa.alloc(kiln.FieldValue, 1);
    fields[0] = .{ .name = "items", .value = .{ .list = items } };
    return .{ .structure = fields };
}

fn buildEvent(gpa: std.mem.Allocator, e: data.Event) !kiln.Value {
    const attrs = try gpa.alloc(kiln.Value, e.attrs.len);
    errdefer gpa.free(attrs);
    var n: usize = 0;
    errdefer for (attrs[0..n]) |*it| it.deinit(gpa);
    for (e.attrs) |a| {
        const rec = try gpa.alloc(kiln.FieldValue, 2);
        rec[0] = .{ .name = "key", .value = .{ .str = a.key } };
        rec[1] = .{ .name = "value", .value = .{ .str = a.value } };
        attrs[n] = .{ .structure = rec };
        n += 1;
    }

    const fields = try gpa.alloc(kiln.FieldValue, 5);
    fields[0] = .{ .name = "event_id", .value = .{ .str = e.event_id } };
    fields[1] = .{ .name = "event_type", .value = .{ .str = e.event_type } };
    fields[2] = .{ .name = "occurred_at", .value = .{ .int = e.occurred_at } };
    fields[3] = .{ .name = "producer", .value = .{ .str = e.producer } };
    fields[4] = .{ .name = "attrs", .value = .{ .list = attrs } };
    return .{ .structure = fields };
}

fn fixtureFrom(allocator: std.mem.Allocator, tag: Tag, value: kiln.Value) !data.Fixture {
    const fields = try asStruct(value);
    return switch (tag) {
        .message => .{ .message = try messageFrom(allocator, fields) },
        .document => .{ .document = try documentFrom(allocator, fields) },
        .telemetry => .{ .telemetry = try telemetryFrom(allocator, fields) },
        .strings => .{ .strings = try stringsFrom(allocator, fields) },
        .event => .{ .event = try eventFrom(allocator, fields) },
        else => error.KilnType,
    };
}

fn messageFrom(allocator: std.mem.Allocator, f: []const kiln.FieldValue) !data.Message {
    if (f.len != 8) return error.KilnType;
    return .{
        .f_bool = try asBool(f[0].value),
        .f_int32 = try asI32(f[1].value),
        .f_int64 = try asI64(f[2].value),
        .f_float64 = try asF64(f[3].value),
        .f_string = try dupe(allocator, try asStr(f[4].value)),
        .f_bool_2 = try asBool(f[5].value),
        .f_int32_2 = try asI32(f[6].value),
        .f_string_2 = try dupe(allocator, try asStr(f[7].value)),
    };
}

fn documentFrom(allocator: std.mem.Allocator, f: []const kiln.FieldValue) !data.Document {
    if (f.len != 4) return error.KilnType;
    const meta = try asStruct(f[2].value);
    if (meta.len != 2) return error.KilnType;
    const item_vals = try asList(f[3].value);
    const items = try allocator.alloc(data.DocumentItem, item_vals.len);
    for (item_vals, items) |iv, *it| {
        const rec = try asStruct(iv);
        if (rec.len != 3) return error.KilnType;
        it.* = .{
            .sku = try dupe(allocator, try asStr(rec[0].value)),
            .qty = try asI32(rec[1].value),
            .price_minor = try asI64(rec[2].value),
        };
    }
    return .{
        .id = try dupe(allocator, try asStr(f[0].value)),
        .status = try asI32(f[1].value),
        .meta = .{
            .region = try dupe(allocator, try asStr(meta[0].value)),
            .version = try asI32(meta[1].value),
        },
        .items = items,
    };
}

fn telemetryFrom(allocator: std.mem.Allocator, f: []const kiln.FieldValue) !data.Telemetry {
    if (f.len != 4) return error.KilnType;
    const tag_vals = try asList(f[2].value);
    const value_vals = try asList(f[3].value);
    const tags = try allocator.alloc([]const u8, tag_vals.len);
    for (tag_vals, tags) |v, *s| s.* = try dupe(allocator, try asStr(v));
    const values = try allocator.alloc(f64, value_vals.len);
    for (value_vals, values) |v, *n| n.* = try asF64(v);
    return .{
        .source = try dupe(allocator, try asStr(f[0].value)),
        .ts = try asI64(f[1].value),
        .tags = tags,
        .values = values,
    };
}

fn stringsFrom(allocator: std.mem.Allocator, f: []const kiln.FieldValue) !data.Strings {
    if (f.len != 1) return error.KilnType;
    const vals = try asList(f[0].value);
    const items = try allocator.alloc([]const u8, vals.len);
    for (vals, items) |v, *s| s.* = try dupe(allocator, try asStr(v));
    return .{ .items = items };
}

fn eventFrom(allocator: std.mem.Allocator, f: []const kiln.FieldValue) !data.Event {
    if (f.len != 5) return error.KilnType;
    const attr_vals = try asList(f[4].value);
    const attrs = try allocator.alloc(data.EventAttr, attr_vals.len);
    for (attr_vals, attrs) |v, *a| {
        const rec = try asStruct(v);
        if (rec.len != 2) return error.KilnType;
        a.* = .{
            .key = try dupe(allocator, try asStr(rec[0].value)),
            .value = try dupe(allocator, try asStr(rec[1].value)),
        };
    }
    return .{
        .event_id = try dupe(allocator, try asStr(f[0].value)),
        .event_type = try dupe(allocator, try asStr(f[1].value)),
        .occurred_at = try asI64(f[2].value),
        .producer = try dupe(allocator, try asStr(f[3].value)),
        .attrs = attrs,
    };
}

fn dupe(allocator: std.mem.Allocator, s: []const u8) ![]u8 {
    return allocator.dupe(u8, s);
}

fn asStruct(v: kiln.Value) ![]const kiln.FieldValue {
    return switch (v) {
        .structure => |fields| fields,
        else => error.KilnType,
    };
}

fn asList(v: kiln.Value) ![]const kiln.Value {
    return switch (v) {
        .list => |items| items,
        else => error.KilnType,
    };
}

fn asBool(v: kiln.Value) !bool {
    return switch (v) {
        .boolean => |b| b,
        else => error.KilnType,
    };
}

fn asI32(v: kiln.Value) !i32 {
    const n = switch (v) {
        .int => |i| i,
        else => return error.KilnType,
    };
    return std.math.cast(i32, n) orelse error.KilnType;
}

fn asI64(v: kiln.Value) !i64 {
    return switch (v) {
        .int => |i| i,
        else => error.KilnType,
    };
}

fn asF64(v: kiln.Value) !f64 {
    return switch (v) {
        .f64 => |n| n,
        else => error.KilnType,
    };
}

fn asStr(v: kiln.Value) ![]const u8 {
    return switch (v) {
        .str => |s| s,
        else => error.KilnType,
    };
}

fn bindDirect(self: *State, tag: Tag) !void {
    const schema = try schemaFor(self, tag, false);
    switch (tag) {
        .tensor => {
            try expectNames(schema, &.{ "rows", "cols", "values" });
            try expectKind(schema.fields[0].schema, .i32);
            try expectKind(schema.fields[1].schema, .i32);
            try expectList(schema.fields[2].schema, .f32);
        },
        .prompt => try expectPrompt(schema),
        .shard => {
            try expectNames(schema, &.{ "vocab", "hidden", "ffn", "tok_emb", "attn", "ffn_weight", "norm" });
            try expectKind(schema.fields[0].schema, .i32);
            try expectKind(schema.fields[1].schema, .i32);
            try expectKind(schema.fields[2].schema, .i32);
            try expectList(schema.fields[3].schema, .f32);
            try expectList(schema.fields[4].schema, .f32);
            try expectList(schema.fields[5].schema, .f32);
            try expectList(schema.fields[6].schema, .f32);
        },
        .request => {
            try expectNames(schema, &.{ "request_id", "model", "temperature", "inputs" });
            try expectKind(schema.fields[0].schema, .i64);
            try expectKind(schema.fields[1].schema, .str);
            try expectKind(schema.fields[2].schema, .f32);
            try expectPrompt(schema.fields[3].schema);
        },
        else => return error.KilnType,
    }
    self.active = schema;
}

fn expectNames(schema: *const kiln.Schema, names: []const []const u8) !void {
    if (schema.kind != .structure or schema.fields.len != names.len) return error.KilnSchema;
    for (names, schema.fields) |name, field| {
        if (!std.mem.eql(u8, field.name, name)) return error.KilnSchema;
    }
}

fn expectKind(schema: *const kiln.Schema, kind: kiln.Kind) !void {
    if (schema.kind != kind) return error.KilnSchema;
}

fn expectList(schema: *const kiln.Schema, kind: kiln.Kind) !void {
    if (schema.kind != .list) return error.KilnSchema;
    const child = schema.child orelse return error.KilnSchema;
    if (child.kind != kind) return error.KilnSchema;
}

fn expectPrompt(schema: *const kiln.Schema) !void {
    try expectNames(schema, &.{ "batch", "seq", "input_ids", "attention_mask", "position_ids" });
    try expectKind(schema.fields[0].schema, .i32);
    try expectKind(schema.fields[1].schema, .i32);
    try expectList(schema.fields[2].schema, .i64);
    try expectList(schema.fields[3].schema, .i64);
    try expectList(schema.fields[4].schema, .i64);
}

fn resetWriter(self: *State) *kiln.Writer {
    const cap = self.writer.cap;
    self.writer.reset();
    self.writer.cap = cap;
    return &self.writer;
}

fn writeDirect(self: *State, fx: data.Fixture) ![]const u8 {
    const w = resetWriter(self);
    switch (fx) {
        .tensor => |t| try writeTensor(w, self.gpa, t),
        .tensor_view => |t| try writeTensor(w, self.gpa, .{ .rows = t.rows, .cols = t.cols, .values = t.values }),
        .prompt => |p| try writePrompt(w, self.gpa, p),
        .shard => |s| try writeShard(w, self.gpa, s),
        .request => |r| try writeRequest(w, self.gpa, r),
        else => return error.KilnType,
    }
    return w.slice();
}

fn writeTensor(w: *kiln.Writer, gpa: std.mem.Allocator, t: data.Tensor) !void {
    try w.int(gpa, i32, t.rows);
    try w.int(gpa, i32, t.cols);
    try writeF32List(w, gpa, t.values);
}

fn writePrompt(w: *kiln.Writer, gpa: std.mem.Allocator, p: data.Prompt) !void {
    try w.int(gpa, i32, p.batch);
    try w.int(gpa, i32, p.seq);
    try writeI64List(w, gpa, p.input_ids);
    try writeI64List(w, gpa, p.attention_mask);
    try writeI64List(w, gpa, p.position_ids);
}

fn writeShard(w: *kiln.Writer, gpa: std.mem.Allocator, s: data.Shard) !void {
    try w.int(gpa, i32, s.vocab);
    try w.int(gpa, i32, s.hidden);
    try w.int(gpa, i32, s.ffn);
    try writeF32List(w, gpa, s.tok_emb);
    try writeF32List(w, gpa, s.attn);
    try writeF32List(w, gpa, s.ffn_weight);
    try writeF32List(w, gpa, s.norm);
}

fn writeRequest(w: *kiln.Writer, gpa: std.mem.Allocator, r: data.Request) !void {
    try w.int(gpa, i64, r.request_id);
    try w.str(gpa, r.model);
    try w.float32(gpa, r.temperature);
    try writePrompt(w, gpa, r.inputs);
}

fn writeF32List(w: *kiln.Writer, gpa: std.mem.Allocator, values: []const f32) !void {
    if (values.len > w.cap) return error.LIMIT;
    const count = std.math.cast(u32, values.len) orelse return error.LIMIT;
    try w.int(gpa, u32, count);
    try w.float32s(gpa, values);
}

fn writeI64List(w: *kiln.Writer, gpa: std.mem.Allocator, values: []const i64) !void {
    if (values.len > w.cap) return error.LIMIT;
    const count = std.math.cast(u32, values.len) orelse return error.LIMIT;
    try w.int(gpa, u32, count);
    try w.pod(gpa, i64, values);
}

fn readDirect(allocator: std.mem.Allocator, tag: Tag, view: bool, bytes: []const u8) !data.Fixture {
    var reader = kiln.Reader.init(bytes, .{});
    const fx: data.Fixture = switch (tag) {
        .tensor => if (view)
            .{ .tensor_view = try readTensorView(&reader) }
        else
            .{ .tensor = try readTensor(allocator, &reader) },
        .prompt => .{ .prompt = try readPrompt(allocator, &reader) },
        .shard => .{ .shard = try readShard(allocator, &reader) },
        .request => .{ .request = try readRequest(allocator, &reader) },
        else => return error.KilnType,
    };
    try reader.finish();
    return fx;
}

fn readTensor(allocator: std.mem.Allocator, r: *kiln.Reader) !data.Tensor {
    return .{
        .rows = try r.int(i32),
        .cols = try r.int(i32),
        .values = try readF32List(allocator, r),
    };
}

/// Payload aliases `r.buf`. Callers must not copy it.
fn readTensorView(r: *kiln.Reader) !data.TensorView {
    return .{
        .rows = try r.int(i32),
        .cols = try r.int(i32),
        .values = &.{},
        .payload = try takeF32Payload(r),
    };
}

fn readPrompt(allocator: std.mem.Allocator, r: *kiln.Reader) !data.Prompt {
    return .{
        .batch = try r.int(i32),
        .seq = try r.int(i32),
        .input_ids = try readI64List(allocator, r),
        .attention_mask = try readI64List(allocator, r),
        .position_ids = try readI64List(allocator, r),
    };
}

fn readShard(allocator: std.mem.Allocator, r: *kiln.Reader) !data.Shard {
    return .{
        .vocab = try r.int(i32),
        .hidden = try r.int(i32),
        .ffn = try r.int(i32),
        .tok_emb = try readF32List(allocator, r),
        .attn = try readF32List(allocator, r),
        .ffn_weight = try readF32List(allocator, r),
        .norm = try readF32List(allocator, r),
    };
}

fn readRequest(allocator: std.mem.Allocator, r: *kiln.Reader) !data.Request {
    return .{
        .request_id = try r.int(i64),
        .model = try dupe(allocator, try r.str()),
        .temperature = try r.float32(),
        .inputs = try readPrompt(allocator, r),
    };
}

fn readF32List(allocator: std.mem.Allocator, r: *kiln.Reader) ![]f32 {
    const n = try r.listHeader(4);
    const out = try allocator.alloc(f32, n);
    errdefer allocator.free(out);
    try r.float32s(out);
    return out;
}

fn readI64List(allocator: std.mem.Allocator, r: *kiln.Reader) ![]i64 {
    const n = try r.listHeader(8);
    const out = try allocator.alloc(i64, n);
    errdefer allocator.free(out);
    try r.pod(i64, out);
    return out;
}

fn takeF32Payload(r: *kiln.Reader) ![]const u8 {
    const n = try r.listHeader(4);
    const nbytes = std.math.mul(usize, @as(usize, n), 4) catch return error.LIMIT;
    if (nbytes > r.buf.len - r.i) return error.EOF;
    const start = r.i;
    r.i += nbytes;
    return r.buf[start..r.i];
}

test "gld-kiln round-trips suite structs and a batch list" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    try std.testing.expect(!supports("graph"));
    try std.testing.expectEqualStrings("0.2.0", version);
    const kinds = [_][]const u8{ "message", "document", "telemetry", "strings", "event" };
    for (kinds) |tid| {
        const fx = try data.makeOne(aa, tid, 42, 0, .{});
        var out = try buf_mod.Buf.initCapacity(aa, 8192);
        try prepare(@ptrCast(&state), aa, &.{fx});
        beginEncode(@ptrCast(&state));
        try serialize(@ptrCast(&state), fx, &out);
        try std.testing.expect(out.len > 0);
        const back = try deserialize(@ptrCast(&state), aa, tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));
    }
    const batch = try data.instances(aa, "document", 9, 3, .{});
    var batched = try buf_mod.Buf.initCapacity(aa, 65536);
    try prepare(@ptrCast(&state), aa, batch);
    try encodeBatch(@ptrCast(&state), batch, &batched);
    try std.testing.expect(batched.len >= 4);
    try std.testing.expectEqual(@as(u32, 3), std.mem.readInt(u32, batched.items()[0..4], .little));
    const back = try decodeBatch(@ptrCast(&state), aa, "document", batched.items());
    try std.testing.expectEqual(batch.len, back.len);
    for (batch, back) |want, got| try std.testing.expect(data.fidelity(want, got));
}

const tiny_cfg = data.TypeConfig{
    .rows = 2,
    .cols = 2,
    .batch = 2,
    .seq = 4,
    .vocab = 50,
    .hidden = 3,
    .ffn = 5,
    .string_min = 3,
    .string_max = 8,
};

test "gld-kiln tensor wire matches schema encode and tensor_view borrows" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const aa = arena.allocator();
    var local: State = .{};
    defer if (local.ready) {
        local.clearRoot();
        local.writer.deinit(local.gpa);
        local.arena.deinit();
    };

    try std.testing.expect(supports("tensor"));
    try std.testing.expect(supports("tensor_view"));
    try std.testing.expect(supports("prompt"));
    try std.testing.expect(supports("shard"));
    try std.testing.expect(supports("request"));

    const kinds = [_][]const u8{ "tensor", "tensor_view", "prompt", "shard", "request" };
    for (kinds) |tid| {
        const fx = try data.makeOne(aa, tid, 11, 0, tiny_cfg);
        var out = try buf_mod.Buf.initCapacity(std.testing.allocator, 256);
        defer out.deinit();
        try prepare(@ptrCast(&local), aa, &.{fx});
        beginEncode(@ptrCast(&local));
        try serialize(@ptrCast(&local), fx, &out);
        const text = switch (Tag.of(fx)) {
            .tensor => tensor_text,
            .prompt => prompt_text,
            .shard => shard_text,
            .request => request_text,
            else => unreachable,
        };
        const value = try valueFor(aa, fx);
        try expectKilnBytes(aa, text, value, out.items());
        const back = try deserialize(@ptrCast(&local), aa, tid, out.items());
        try std.testing.expect(data.fidelity(fx, back));
        if (std.mem.eql(u8, tid, "tensor")) {
            const owned = back.tensor.values;
            try std.testing.expect(!aliases(owned.ptr, owned.len * 4, out.items()));
        }
        if (std.mem.eql(u8, tid, "tensor_view")) {
            const payload = back.tensor_view.payload;
            try std.testing.expect(aliases(payload.ptr, payload.len, out.items()));
            try std.testing.expectEqual(@as(usize, 0), back.tensor_view.values.len);
            try std.testing.expectEqual(@as(u32, 0x80000000), std.mem.readInt(u32, payload[0..4], .little));
            try std.testing.expectEqual(@as(u32, 0x7fc00000), std.mem.readInt(u32, payload[4..8], .little));
        }
    }

    const matrix = try data.makeOne(aa, "tensor", 4, 0, .{});
    var wide = try buf_mod.Buf.initCapacity(std.testing.allocator, 64);
    defer wide.deinit();
    try prepare(@ptrCast(&local), aa, &.{matrix});
    beginEncode(@ptrCast(&local));
    try serialize(@ptrCast(&local), matrix, &wide);
    try std.testing.expectEqual(@as(usize, 4_194_316), wide.len);
    const raw = wide.items();
    try std.testing.expectEqual(@as(i32, 1024), std.mem.readInt(i32, raw[0..4], .little));
    try std.testing.expectEqual(@as(i32, 1024), std.mem.readInt(i32, raw[4..8], .little));
    try std.testing.expectEqual(@as(u32, 1_048_576), std.mem.readInt(u32, raw[8..12], .little));
    try std.testing.expectEqual(@as(u32, 0x80000000), std.mem.readInt(u32, raw[12..16], .little));
    try std.testing.expectEqual(@as(u32, 0x7fc00000), std.mem.readInt(u32, raw[16..20], .little));
    const owned = try deserialize(@ptrCast(&local), aa, "tensor", raw);
    try std.testing.expect(data.fidelity(matrix, owned));
    const viewed = try deserialize(@ptrCast(&local), aa, "tensor_view", raw);
    try std.testing.expect(data.fidelity(try data.makeOne(aa, "tensor_view", 4, 0, .{}), viewed));
    try std.testing.expect(aliases(viewed.tensor_view.payload.ptr, viewed.tensor_view.payload.len, raw));
}

fn aliases(ptr: anytype, len: usize, buf: []const u8) bool {
    if (len == 0) return false;
    const start = @intFromPtr(ptr);
    const buf_start = @intFromPtr(buf.ptr);
    return start >= buf_start and start + len <= buf_start + buf.len;
}

fn expectKilnBytes(aa: std.mem.Allocator, text: []const u8, value: kiln.Value, got: []const u8) !void {
    const schema = try kiln.parseTypeText(aa, text);
    const encoded = try kiln.encode(std.testing.allocator, schema, value, .{});
    defer std.testing.allocator.free(encoded);
    try std.testing.expectEqualSlices(u8, encoded, got);
}

fn valueFor(aa: std.mem.Allocator, fx: data.Fixture) !kiln.Value {
    return switch (fx) {
        .tensor => |t| try tensorValue(aa, t),
        .tensor_view => |t| try tensorValue(aa, .{ .rows = t.rows, .cols = t.cols, .values = t.values }),
        .prompt => |p| try promptValue(aa, p),
        .shard => |s| try shardValue(aa, s),
        .request => |r| try requestValue(aa, r),
        else => error.KilnType,
    };
}

fn f32Values(aa: std.mem.Allocator, xs: []const f32) ![]kiln.Value {
    const items = try aa.alloc(kiln.Value, xs.len);
    for (xs, items) |n, *slot| slot.* = .{ .f32 = n };
    return items;
}

fn i64Values(aa: std.mem.Allocator, xs: []const i64) ![]kiln.Value {
    const items = try aa.alloc(kiln.Value, xs.len);
    for (xs, items) |n, *slot| slot.* = .{ .int = n };
    return items;
}

fn tensorValue(aa: std.mem.Allocator, t: data.Tensor) !kiln.Value {
    const fields = try aa.alloc(kiln.FieldValue, 3);
    fields[0] = .{ .name = "rows", .value = .{ .int = t.rows } };
    fields[1] = .{ .name = "cols", .value = .{ .int = t.cols } };
    fields[2] = .{ .name = "values", .value = .{ .list = try f32Values(aa, t.values) } };
    return .{ .structure = fields };
}

fn promptValue(aa: std.mem.Allocator, p: data.Prompt) !kiln.Value {
    const fields = try aa.alloc(kiln.FieldValue, 5);
    fields[0] = .{ .name = "batch", .value = .{ .int = p.batch } };
    fields[1] = .{ .name = "seq", .value = .{ .int = p.seq } };
    fields[2] = .{ .name = "input_ids", .value = .{ .list = try i64Values(aa, p.input_ids) } };
    fields[3] = .{ .name = "attention_mask", .value = .{ .list = try i64Values(aa, p.attention_mask) } };
    fields[4] = .{ .name = "position_ids", .value = .{ .list = try i64Values(aa, p.position_ids) } };
    return .{ .structure = fields };
}

fn shardValue(aa: std.mem.Allocator, s: data.Shard) !kiln.Value {
    const fields = try aa.alloc(kiln.FieldValue, 7);
    fields[0] = .{ .name = "vocab", .value = .{ .int = s.vocab } };
    fields[1] = .{ .name = "hidden", .value = .{ .int = s.hidden } };
    fields[2] = .{ .name = "ffn", .value = .{ .int = s.ffn } };
    fields[3] = .{ .name = "tok_emb", .value = .{ .list = try f32Values(aa, s.tok_emb) } };
    fields[4] = .{ .name = "attn", .value = .{ .list = try f32Values(aa, s.attn) } };
    fields[5] = .{ .name = "ffn_weight", .value = .{ .list = try f32Values(aa, s.ffn_weight) } };
    fields[6] = .{ .name = "norm", .value = .{ .list = try f32Values(aa, s.norm) } };
    return .{ .structure = fields };
}

fn requestValue(aa: std.mem.Allocator, r: data.Request) !kiln.Value {
    const fields = try aa.alloc(kiln.FieldValue, 4);
    fields[0] = .{ .name = "request_id", .value = .{ .int = r.request_id } };
    fields[1] = .{ .name = "model", .value = .{ .str = r.model } };
    fields[2] = .{ .name = "temperature", .value = .{ .f32 = r.temperature } };
    fields[3] = .{ .name = "inputs", .value = try promptValue(aa, r.inputs) };
    return .{ .structure = fields };
}
