# Zig: `std.json` vs. `serde.json`

This note inspects Zig's standard-library JSON (`std.json`) and `serde.zig` (`serde.json`) adapters—along with their `.borrowed` and `.scanner` variants—on the `document` ($n = 1$, `bytes` mode) payload. Both specialize struct traversals at compile time via `@typeInfo` and write identical **448-byte** compact JSON into the runner's reused output buffer (`text_on_stream`).

[Dashboard comparison (L1)](../../dashboard/index.html?lang=zig&standard=json&data=document@n=1&mode=bytes&metric=ops&policy=iqr_1.5&baseline=std.json&ser=std.json&ser=serde.json#compare) · [Zig overview](../../zig/index.md) · [Timing contract](../TIMING_HONESTY.md)

## Structural and Wire-Size Summary

| Property | `std.json` | `std.json.borrowed` | `serde.json` | `serde.json.borrowed` |
|---|---|---|---|---|
| Standard | `json` | `json` | `json` | `json` |
| Encoded size (`document`, $n = 1$) | **448 B** | **448 B** | **448 B** | **448 B** |
| Reflection model | Comptime `@typeInfo` | Comptime `@typeInfo` | Comptime `@typeInfo` | Comptime `@typeInfo` |
| Encode buffer | Reused `std.Io.Writer` | Same | Reused `std.Io.Writer` | Same |
| Decode string allocation | `.alloc_always` (copies strings) | `.alloc_if_needed` (borrows unescaped; allocates if escaped) | Owning copy (`fromSlice`) | Strict slice view (`fromSliceBorrowed`; rejects escapes) |

*(A fifth row, `std.json.scanner`, shares `std.json` encode and decodes through `std.json.Scanner` + `parseFromTokenSource`.)*

## Timed Call Sites

**`std.json`** (`zig/src/json_util.zig`) writes through the runner-owned writer and parses with owning allocation:

```zig
try std.json.Stringify.value(payload, .{}, &aw.writer);
const parsed = try std.json.parseFromSlice(Document, allocator, bytes, .{
    .allocate = .alloc_always,
});
```

**`serde.json`** (`zig/src/serde_ser.zig`) walks the same `Document` struct with `serde.zig`'s comptime writer/parser (`toWriter` avoids the intermediate `Allocating` copy inside `toSlice`):

```zig
try serde.json.toWriter(&aw.writer, payload);
const value = try serde.json.fromSlice(Document, allocator, bytes);
```

## Mechanistic Analysis and Scope Limits

1. **Equal-size comptime comparison (448 B):** Because every row emits identical compact JSON into the same reused runner buffer, differences in encode and decode latency stem purely from each library's comptime-generated state machine, token scanner, and allocator traffic.
2. **Isolating string-copy cost:** Comparing `std.json` vs. `std.json.borrowed`—and `serde.json` vs. `serde.json.borrowed`—measures the exact cost of heap-allocating and copying UTF-8 strings on identical bytes twice across two independent libraries.
3. **Borrowed-decode semantic boundary:** `std.json.borrowed` (`.alloc_if_needed`) safely falls back to allocation when a JSON string contains escape sequences (`\"`, `\uXXXX`), whereas `serde.json.borrowed` (`fromSliceBorrowed`) strictly forbids escaped strings and returns an error. The two `.borrowed` rows are comparable on this suite's unescaped generated payloads, but are not drop-in equivalents on arbitrary external JSON.
