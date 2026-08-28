# Zig: why two JSON rows can disagree

## Why this article exists

Zig’s interesting property in this suite is **comptime reflection**. `std.json.parseFromSlice` and **serde.zig** both walk `@typeInfo` at compile time. They are not Java-style runtime reflection and they are not Rust derive macros. They are still two libraries, two call sites, and two decode strategies.

This page opens the two timed JSON wrappers on the suite **document** fixture (one shop order). After you have a published Zig Dashboard slice, quote those numbers here. Until then, treat the table as a **call-site map**, not a ranking.

[Open this slice on the Dashboard](../../dashboard/?lang=zig&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=std.json&ser=std.json&ser=serde.json#compare)
· [Claims (L1)](../../analysis/CLAIMS_AND_REPLICATION/)
· [Zig overview](../../zig/)

## The two timed call sites

**std.json** (`zig/src/json_util.zig`) uses the official standard library:

```zig
try std.json.Stringify.value(payload, .{}, &aw.writer);
const parsed = try std.json.parseFromSlice(Document, allocator, bytes, .{
    .allocate = .alloc_always,
});
```

**serde.json** (`zig/src/serde_ser.zig`) uses the same suite `Document` struct and serde.zig’s comptime API:

```zig
const bytes = try serde.json.toSlice(allocator, payload);
const value = try serde.json.fromSlice(Document, allocator, bytes);
```

Both rows write named JSON fields. Stream mode for `std.json` is `text_on_stream` (text written through a writer). `serde.json` is `adapted` in this first wave (slice in, slice out).

A third row, `std.json.scanner`, keeps the same stringify path and decodes with `std.json.Scanner` + `parseFromTokenSource`. That is the official streaming parser from the first intake list.

## What to look at on the Dashboard

1. **Size.** If both write the same field names and values, sizes should be close. A large gap means a different JSON shape (pretty print, extra wrapper, different float formatting).
2. **Encode time.** `Stringify.value` versus `serde.json.toSlice`.
3. **Decode time.** Typed `parseFromSlice` versus serde’s `fromSlice`.
4. **`std.json.scanner`.** Same bytes as `std.json`, different decode API. A gap here is the scanner versus the slice parser, not a different format.

## What this does not claim

It does not claim that comptime is faster than runtime reflection in another language. Cross-language times are not one contest. It does not crown serde.zig or `std.json` as “the Zig JSON library.” Read the similar / close sets on the Dashboard for this sample.

## Self-check

1. Why can two comptime JSON libraries write the same document and still have different times?
2. Which row is the official standard library, and which is a third-party framework?
3. Why is a literal `@bitCast` of `Document` not a fair “raw binary” row?
