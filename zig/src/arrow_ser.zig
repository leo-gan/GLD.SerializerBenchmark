//! gld-arrow adapter (leo-gan/gld-arrow-zig).
//!
//! Prepare builds one `Columnar` record batch per fixture (untimed) into a
//! reused scratch arena. Timed serialize is `encodeStream`. Timed deserialize
//! is `decodeStream` plus `rowsFromBatch`. Graph is not a single tree batch.

const std = @import("std");
const data = @import("data.zig");
const buf_mod = @import("buf.zig");
const arrow = @import("arrow");

pub const version = arrow.version;

pub const State = struct {
    gpa: std.mem.Allocator = std.heap.page_allocator,
    arena: std.heap.ArenaAllocator = undefined,
    cols: []arrow.Columnar = &.{},
    enc_i: usize = 0,
    ready: bool = false,

    fn ensure(self: *State) void {
        if (self.ready) return;
        self.gpa = std.heap.page_allocator;
        self.arena = .init(self.gpa);
        self.ready = true;
    }

    fn clearCols(self: *State) void {
        for (self.cols) |*c| c.deinit();
        if (self.cols.len != 0) self.gpa.free(self.cols);
        self.cols = &.{};
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
    self.clearCols();
    self.enc_i = 0;
    if (fixtures.len == 0) return;
    const cols = try self.gpa.alloc(arrow.Columnar, fixtures.len);
    var n: usize = 0;
    errdefer {
        for (cols[0..n]) |*c| c.deinit();
        self.gpa.free(cols);
    }
    for (fixtures) |fx| {
        _ = self.arena.reset(.retain_capacity);
        cols[n] = try build(self.arena.allocator(), fx);
        n += 1;
    }
    self.cols = cols;
}

pub fn beginEncode(ctx: *anyopaque) void {
    const self: *State = @ptrCast(@alignCast(ctx));
    self.enc_i = 0;
}

pub fn serialize(ctx: *anyopaque, _: data.Fixture, out: *buf_mod.Buf) !void {
    const self: *State = @ptrCast(@alignCast(ctx));
    if (!self.ready or self.enc_i >= self.cols.len) return error.ArrowNotPrepared;
    const col = &self.cols[self.enc_i];
    self.enc_i += 1;
    const raw = try arrow.encodeStream(self.gpa, col);
    defer self.gpa.free(raw);
    try out.appendSlice(raw);
}

pub fn deserialize(ctx: *anyopaque, allocator: std.mem.Allocator, type_id: []const u8, bytes: []const u8) !data.Fixture {
    _ = ctx;
    var col = try arrow.decodeStream(std.heap.page_allocator, bytes);
    defer col.deinit();
    if (col.batches.items.len != 1) return error.BadBatch;
    var rows = try arrow.rowsFromBatch(std.heap.page_allocator, &col, 0);
    defer rows.deinit();
    if (rows.rows.items.len != 1) return error.BadBatch;
    const row = rows.rows.items[0];
    if (std.mem.eql(u8, type_id, "message")) return .{ .message = try messageFrom(allocator, &rows, row) };
    if (std.mem.eql(u8, type_id, "document")) return .{ .document = try documentFrom(allocator, &rows, row) };
    if (std.mem.eql(u8, type_id, "telemetry")) return .{ .telemetry = try telemetryFrom(allocator, &rows, row) };
    if (std.mem.eql(u8, type_id, "strings")) return .{ .strings = try stringsFrom(allocator, &rows, row) };
    if (std.mem.eql(u8, type_id, "event")) return .{ .event = try eventFrom(allocator, &rows, row) };
    return error.UnknownTypeId;
}

fn build(aa: std.mem.Allocator, fx: data.Fixture) !arrow.Columnar {
    return switch (fx) {
        .message => |m| try buildMessage(aa, m),
        .document => |d| try buildDocument(aa, d),
        .telemetry => |t| try buildTelemetry(aa, t),
        .strings => |s| try buildStrings(aa, s),
        .event => |e| try buildEvent(aa, e),
        else => error.Unsupported,
    };
}

fn fresh() arrow.Columnar {
    return arrow.Columnar.init(std.heap.page_allocator);
}

fn prim(c: *arrow.Columnar, name: []const u8, kind: arrow.Kind, bit_width: i32, unit: u16) !usize {
    var f = arrow.Field{};
    f.name = @intCast(try c.intern(name));
    f.kind = kind;
    f.bit_width = bit_width;
    f.unit = unit;
    f.is_signed = true;
    f.nullable = false;
    return c.addField(f);
}

fn structField(c: *arrow.Columnar, name: []const u8, children: []const usize) !usize {
    var f = arrow.Field{};
    f.name = @intCast(try c.intern(name));
    f.kind = .@"struct";
    f.nullable = false;
    f.child_at = c.kids.items.len;
    f.n_child = children.len;
    const id = try c.addField(f);
    try c.kids.appendSlice(c.gpa, children);
    return id;
}

fn listField(c: *arrow.Columnar, name: []const u8, child_id: usize) !usize {
    var f = arrow.Field{};
    f.name = @intCast(try c.intern(name));
    f.kind = .list;
    f.nullable = false;
    f.child_at = c.kids.items.len;
    f.n_child = 1;
    const id = try c.addField(f);
    try c.kids.append(c.gpa, child_id);
    return id;
}

fn tops(c: *arrow.Columnar, fields: []const usize, arrays: []const usize) !void {
    for (fields) |id| try c.addTop(id);
    try c.addBatch(1, arrays, null);
}

fn bools(c: *arrow.Columnar, aa: std.mem.Allocator, field: usize, values: []const bool) !usize {
    const nbytes = (values.len + 7) / 8;
    const bits = try aa.alloc(u8, nbytes);
    @memset(bits, 0);
    for (values, 0..) |v, i| {
        if (!v) continue;
        bits[i / 8] |= @as(u8, 1) << @as(u3, @intCast(i % 8));
    }
    return c.addArray(@as(i64, @intCast(values.len)), 0, field, &.{ &.{}, bits }, &.{});
}

fn i32s(c: *arrow.Columnar, aa: std.mem.Allocator, field: usize, values: []const i32) !usize {
    const raw = try aa.alloc(u8, values.len * 4);
    for (values, 0..) |v, i| std.mem.writeInt(i32, raw[i * 4 ..][0..4], v, .little);
    return c.addArray(@as(i64, @intCast(values.len)), 0, field, &.{ &.{}, raw }, &.{});
}

fn i64s(c: *arrow.Columnar, aa: std.mem.Allocator, field: usize, values: []const i64) !usize {
    const raw = try aa.alloc(u8, values.len * 8);
    for (values, 0..) |v, i| std.mem.writeInt(i64, raw[i * 8 ..][0..8], v, .little);
    return c.addArray(@as(i64, @intCast(values.len)), 0, field, &.{ &.{}, raw }, &.{});
}

fn f64s(c: *arrow.Columnar, aa: std.mem.Allocator, field: usize, values: []const f64) !usize {
    const raw = try aa.alloc(u8, values.len * 8);
    for (values, 0..) |v, i| std.mem.writeInt(u64, raw[i * 8 ..][0..8], @bitCast(v), .little);
    return c.addArray(@as(i64, @intCast(values.len)), 0, field, &.{ &.{}, raw }, &.{});
}

fn utf8s(c: *arrow.Columnar, aa: std.mem.Allocator, field: usize, values: []const []const u8) !usize {
    const offs = try aa.alloc(u8, (values.len + 1) * 4);
    var total: usize = 0;
    std.mem.writeInt(i32, offs[0..4], 0, .little);
    for (values, 0..) |s, i| {
        total += s.len;
        if (total > std.math.maxInt(i32)) return error.Range;
        std.mem.writeInt(i32, offs[(i + 1) * 4 ..][0..4], @intCast(total), .little);
    }
    const bytes = try aa.alloc(u8, total);
    var cursor: usize = 0;
    for (values) |s| {
        @memcpy(bytes[cursor..][0..s.len], s);
        cursor += s.len;
    }
    return c.addArray(@as(i64, @intCast(values.len)), 0, field, &.{ &.{}, offs, bytes }, &.{});
}

fn listOf(c: *arrow.Columnar, field: usize, child_id: usize, n: usize) !usize {
    if (n > std.math.maxInt(i32)) return error.Range;
    var offs: [8]u8 = undefined;
    std.mem.writeInt(i32, offs[0..4], 0, .little);
    std.mem.writeInt(i32, offs[4..8], @intCast(n), .little);
    return c.addArray(1, 0, field, &.{ &.{}, &offs }, &.{child_id});
}

fn structOf(c: *arrow.Columnar, field: usize, len: i64, children: []const usize) !usize {
    return c.addArray(len, 0, field, &.{&.{}}, children);
}

fn oneBool(v: bool) [1]bool {
    return .{v};
}

fn buildMessage(aa: std.mem.Allocator, m: data.Message) !arrow.Columnar {
    var c = fresh();
    errdefer c.deinit();
    const f_bool = try prim(&c, "f_bool", .bool, 0, 0);
    const f_int32 = try prim(&c, "f_int32", .int, 32, 0);
    const f_int64 = try prim(&c, "f_int64", .int, 64, 0);
    const f_float64 = try prim(&c, "f_float64", .float, 64, 2);
    const f_string = try prim(&c, "f_string", .utf8, 0, 0);
    const f_bool_2 = try prim(&c, "f_bool_2", .bool, 0, 0);
    const f_int32_2 = try prim(&c, "f_int32_2", .int, 32, 0);
    const f_string_2 = try prim(&c, "f_string_2", .utf8, 0, 0);
    const b0 = oneBool(m.f_bool);
    const b1 = oneBool(m.f_bool_2);
    const a_bool = try bools(&c, aa, f_bool, &b0);
    const a_int32 = try i32s(&c, aa, f_int32, &.{m.f_int32});
    const a_int64 = try i64s(&c, aa, f_int64, &.{m.f_int64});
    const a_float64 = try f64s(&c, aa, f_float64, &.{m.f_float64});
    const a_string = try utf8s(&c, aa, f_string, &.{m.f_string});
    const a_bool_2 = try bools(&c, aa, f_bool_2, &b1);
    const a_int32_2 = try i32s(&c, aa, f_int32_2, &.{m.f_int32_2});
    const a_string_2 = try utf8s(&c, aa, f_string_2, &.{m.f_string_2});
    try tops(&c, &.{ f_bool, f_int32, f_int64, f_float64, f_string, f_bool_2, f_int32_2, f_string_2 }, &.{
        a_bool, a_int32, a_int64, a_float64, a_string, a_bool_2, a_int32_2, a_string_2,
    });
    return c;
}

fn buildDocument(aa: std.mem.Allocator, d: data.Document) !arrow.Columnar {
    var c = fresh();
    errdefer c.deinit();
    const id_f = try prim(&c, "id", .utf8, 0, 0);
    const status_f = try prim(&c, "status", .int, 32, 0);
    const region_f = try prim(&c, "region", .utf8, 0, 0);
    const version_f = try prim(&c, "version", .int, 32, 0);
    const meta_f = try structField(&c, "meta", &.{ region_f, version_f });
    const sku_f = try prim(&c, "sku", .utf8, 0, 0);
    const qty_f = try prim(&c, "qty", .int, 32, 0);
    const price_f = try prim(&c, "price_minor", .int, 64, 0);
    const item_f = try structField(&c, "item", &.{ sku_f, qty_f, price_f });
    const items_f = try listField(&c, "items", item_f);

    const n = d.items.len;
    const skus = try aa.alloc([]const u8, n);
    const qtys = try aa.alloc(i32, n);
    const prices = try aa.alloc(i64, n);
    for (d.items, skus, qtys, prices) |it, *sku, *qty, *price| {
        sku.* = it.sku;
        qty.* = it.qty;
        price.* = it.price_minor;
    }
    const a_id = try utf8s(&c, aa, id_f, &.{d.id});
    const a_status = try i32s(&c, aa, status_f, &.{d.status});
    const a_region = try utf8s(&c, aa, region_f, &.{d.meta.region});
    const a_version = try i32s(&c, aa, version_f, &.{d.meta.version});
    const a_meta = try structOf(&c, meta_f, 1, &.{ a_region, a_version });
    const a_sku = try utf8s(&c, aa, sku_f, skus);
    const a_qty = try i32s(&c, aa, qty_f, qtys);
    const a_price = try i64s(&c, aa, price_f, prices);
    const a_item = try structOf(&c, item_f, @as(i64, @intCast(n)), &.{ a_sku, a_qty, a_price });
    const a_items = try listOf(&c, items_f, a_item, n);
    try tops(&c, &.{ id_f, status_f, meta_f, items_f }, &.{ a_id, a_status, a_meta, a_items });
    return c;
}

fn buildTelemetry(aa: std.mem.Allocator, t: data.Telemetry) !arrow.Columnar {
    var c = fresh();
    errdefer c.deinit();
    const source_f = try prim(&c, "source", .utf8, 0, 0);
    const ts_f = try prim(&c, "ts", .int, 64, 0);
    const tag_f = try prim(&c, "tag", .utf8, 0, 0);
    const tags_f = try listField(&c, "tags", tag_f);
    const value_f = try prim(&c, "value", .float, 64, 2);
    const values_f = try listField(&c, "values", value_f);
    const a_source = try utf8s(&c, aa, source_f, &.{t.source});
    const a_ts = try i64s(&c, aa, ts_f, &.{t.ts});
    const a_tag = try utf8s(&c, aa, tag_f, t.tags);
    const a_tags = try listOf(&c, tags_f, a_tag, t.tags.len);
    const a_value = try f64s(&c, aa, value_f, t.values);
    const a_values = try listOf(&c, values_f, a_value, t.values.len);
    try tops(&c, &.{ source_f, ts_f, tags_f, values_f }, &.{ a_source, a_ts, a_tags, a_values });
    return c;
}

fn buildStrings(aa: std.mem.Allocator, s: data.Strings) !arrow.Columnar {
    var c = fresh();
    errdefer c.deinit();
    const item_f = try prim(&c, "item", .utf8, 0, 0);
    const items_f = try listField(&c, "items", item_f);
    const a_item = try utf8s(&c, aa, item_f, s.items);
    const a_items = try listOf(&c, items_f, a_item, s.items.len);
    try tops(&c, &.{items_f}, &.{a_items});
    return c;
}

fn buildEvent(aa: std.mem.Allocator, e: data.Event) !arrow.Columnar {
    var c = fresh();
    errdefer c.deinit();
    const id_f = try prim(&c, "event_id", .utf8, 0, 0);
    const type_f = try prim(&c, "event_type", .utf8, 0, 0);
    const at_f = try prim(&c, "occurred_at", .int, 64, 0);
    const prod_f = try prim(&c, "producer", .utf8, 0, 0);
    const key_f = try prim(&c, "key", .utf8, 0, 0);
    const val_f = try prim(&c, "value", .utf8, 0, 0);
    const attr_f = try structField(&c, "attr", &.{ key_f, val_f });
    const attrs_f = try listField(&c, "attrs", attr_f);
    const n = e.attrs.len;
    const keys = try aa.alloc([]const u8, n);
    const vals = try aa.alloc([]const u8, n);
    for (e.attrs, keys, vals) |a, *k, *v| {
        k.* = a.key;
        v.* = a.value;
    }
    const a_id = try utf8s(&c, aa, id_f, &.{e.event_id});
    const a_type = try utf8s(&c, aa, type_f, &.{e.event_type});
    const a_at = try i64s(&c, aa, at_f, &.{e.occurred_at});
    const a_prod = try utf8s(&c, aa, prod_f, &.{e.producer});
    const a_key = try utf8s(&c, aa, key_f, keys);
    const a_val = try utf8s(&c, aa, val_f, vals);
    const a_attr = try structOf(&c, attr_f, @as(i64, @intCast(n)), &.{ a_key, a_val });
    const a_attrs = try listOf(&c, attrs_f, a_attr, n);
    try tops(
        &c,
        &.{ id_f, type_f, at_f, prod_f, attrs_f },
        &.{ a_id, a_type, a_at, a_prod, a_attrs },
    );
    return c;
}

fn nth(rows: *const arrow.Rows, node: usize, i: usize) usize {
    return rows.child(node, i);
}

fn nchild(rows: *const arrow.Rows, node: usize) usize {
    return rows.nodes.items[node].n_child;
}

fn boolean(rows: *const arrow.Rows, node: usize) bool {
    return rows.nodes.items[node].scalar != 0;
}

fn i32Of(rows: *const arrow.Rows, node: usize) i32 {
    return @intCast(rows.nodes.items[node].scalar);
}

fn i64Of(rows: *const arrow.Rows, node: usize) i64 {
    return rows.nodes.items[node].scalar;
}

fn f64Of(rows: *const arrow.Rows, node: usize) f64 {
    return @bitCast(rows.nodes.items[node].scalar);
}

fn text(allocator: std.mem.Allocator, rows: *const arrow.Rows, node: usize) ![]u8 {
    return allocator.dupe(u8, rows.textOf(node));
}

fn messageFrom(allocator: std.mem.Allocator, rows: *const arrow.Rows, row: usize) !data.Message {
    return .{
        .f_bool = boolean(rows, nth(rows, row, 0)),
        .f_int32 = i32Of(rows, nth(rows, row, 1)),
        .f_int64 = i64Of(rows, nth(rows, row, 2)),
        .f_float64 = f64Of(rows, nth(rows, row, 3)),
        .f_string = try text(allocator, rows, nth(rows, row, 4)),
        .f_bool_2 = boolean(rows, nth(rows, row, 5)),
        .f_int32_2 = i32Of(rows, nth(rows, row, 6)),
        .f_string_2 = try text(allocator, rows, nth(rows, row, 7)),
    };
}

fn documentFrom(allocator: std.mem.Allocator, rows: *const arrow.Rows, row: usize) !data.Document {
    const meta = nth(rows, row, 2);
    const items_n = nth(rows, row, 3);
    const n = nchild(rows, items_n);
    const items = try allocator.alloc(data.DocumentItem, n);
    for (items, 0..) |*it, i| {
        const rec = nth(rows, items_n, i);
        it.* = .{
            .sku = try text(allocator, rows, nth(rows, rec, 0)),
            .qty = i32Of(rows, nth(rows, rec, 1)),
            .price_minor = i64Of(rows, nth(rows, rec, 2)),
        };
    }
    return .{
        .id = try text(allocator, rows, nth(rows, row, 0)),
        .status = i32Of(rows, nth(rows, row, 1)),
        .meta = .{
            .region = try text(allocator, rows, nth(rows, meta, 0)),
            .version = i32Of(rows, nth(rows, meta, 1)),
        },
        .items = items,
    };
}

fn telemetryFrom(allocator: std.mem.Allocator, rows: *const arrow.Rows, row: usize) !data.Telemetry {
    const tags_n = nth(rows, row, 2);
    const values_n = nth(rows, row, 3);
    const nt = nchild(rows, tags_n);
    const nv = nchild(rows, values_n);
    const tags = try allocator.alloc([]const u8, nt);
    for (tags, 0..) |*s, i| s.* = try text(allocator, rows, nth(rows, tags_n, i));
    const values = try allocator.alloc(f64, nv);
    for (values, 0..) |*v, i| v.* = f64Of(rows, nth(rows, values_n, i));
    return .{
        .source = try text(allocator, rows, nth(rows, row, 0)),
        .ts = i64Of(rows, nth(rows, row, 1)),
        .tags = tags,
        .values = values,
    };
}

fn stringsFrom(allocator: std.mem.Allocator, rows: *const arrow.Rows, row: usize) !data.Strings {
    const items_n = nth(rows, row, 0);
    const n = nchild(rows, items_n);
    const items = try allocator.alloc([]const u8, n);
    for (items, 0..) |*s, i| s.* = try text(allocator, rows, nth(rows, items_n, i));
    return .{ .items = items };
}

fn eventFrom(allocator: std.mem.Allocator, rows: *const arrow.Rows, row: usize) !data.Event {
    const attrs_n = nth(rows, row, 4);
    const n = nchild(rows, attrs_n);
    const attrs = try allocator.alloc(data.EventAttr, n);
    for (attrs, 0..) |*a, i| {
        const rec = nth(rows, attrs_n, i);
        a.* = .{
            .key = try text(allocator, rows, nth(rows, rec, 0)),
            .value = try text(allocator, rows, nth(rows, rec, 1)),
        };
    }
    return .{
        .event_id = try text(allocator, rows, nth(rows, row, 0)),
        .event_type = try text(allocator, rows, nth(rows, row, 1)),
        .occurred_at = i64Of(rows, nth(rows, row, 2)),
        .producer = try text(allocator, rows, nth(rows, row, 3)),
        .attrs = attrs,
    };
}
