---
title: "Zig"
---

Zig
===

Zig is in this suite because **comptime reflection** (`@typeInfo`) is a different implementation model from Java/Kotlin runtime reflection, C# source generation, or Rust derive macros. The runner times official `std.json` (typed `parseFromSlice` versus streaming `Scanner` / `parseFromTokenSource`) against an in-tree comptime byte-packed baseline and against **serde.zig**, a format-agnostic framework that uses the same `@typeInfo` walk for JSON, MessagePack, YAML, TOML, and ZON.

## Benchmark runner

- Directory: `zig/` (repository root)
- Output: `logs/zig/YYYY-MM-DD-HHMMSS.csv` (`Language=zig`, times in **nanoseconds**)
- Runner: `zig/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: `zig/src/serializers.zig`
- Zig version: **0.16.x** (`./scripts/install-host-requirements.sh zig`)

The shell script resolves the run config to JSON. The Zig binary does not spawn Python. Prepare is untimed. The harness owns a reusable output buffer per serializer. Timed I/O is serialize plus deserialize only. Schedule is SHA-256 + SplitMix64 Fisher–Yates (golden vector `C, B, A`).

## Serializers (wired)

| Name | Category | Package | Stream | Notes |
|------|----------|---------|--------|-------|
| std.json | JSON | std | text_on_stream | `Stringify.value` + `parseFromSlice` into the suite struct |
| std.json.scanner | JSON | std | text_on_stream | Same stringify; decode is `Scanner` + `parseFromTokenSource` |
| std.zon | ZON | std | text_on_stream | Official `std.zon.stringify` + `std.zon.parse.fromSliceAlloc` |
| comptime-bin | Binary | in-tree | adapted | Comptime field walk; LE ints; `u32` length + bytes for strings |
| serde.json | JSON | serde.zig 1.0.7 | adapted | One comptime API, JSON path |
| serde.msgpack | Binary | serde.zig 1.0.7 | adapted | Same API, MessagePack |
| serde.yaml | Text | serde.zig 1.0.7 | text_on_stream | Same API, YAML. **message / strings only** |
| serde.toml | Text | serde.zig 1.0.7 | text_on_stream | Same API, TOML |
| serde.zon | Text | serde.zig 1.0.7 | text_on_stream | Same API, Zig Object Notation |
| serde.xml | Text | serde.zig 1.0.7 | text_on_stream | Same API, XML. **message / strings only** |
| zig-msgpack | Binary | zigcc/zig-msgpack 0.0.14 | adapted | Official MessagePack Payload API |
| msgpack.zig | Binary | lalinsky/msgpack.zig 0.7.0 | native | Typed `encode` / `decodeFromSlice` |
| zbor | Binary | r4gus/zbor 0.21.0 | adapted | Native Zig CBOR (`stringify` / `parse`) |
| s2s | Binary | ziglibs/s2s | native | Native binary “struct to stream” |

## Mixed candidate list (what we took from both intake lists)

The two intake lists were merged. Stars are priority, not a measured rank.

| Candidate | Format | Priority | Status |
|-----------|--------|----------|--------|
| std.json (`parseFromSlice`) | JSON | ⭐⭐⭐⭐⭐ | **wired** |
| std.json (`Scanner` / streaming) | JSON | ⭐⭐⭐⭐⭐ | **wired** |
| serde.zig (JSON / MessagePack / YAML / TOML / ZON) | multi | ⭐⭐⭐⭐⭐ | **wired** (those five formats) |
| comptime-bin / raw packed streams | binary | ⭐⭐⭐⭐ | **wired** (byte-packed `@typeInfo`; literal `@bitCast` cannot encode slices) |
| std.zon | ZON | ⭐⭐⭐⭐ | **wired** (`std.zon`) |
| zig-msgpack (zigcc) | MessagePack | ⭐⭐⭐⭐⭐ | **wired** |
| zbor | CBOR | ⭐⭐⭐⭐⭐ | **wired** |
| zig-protobuf (Arwalk) | Protobuf | ⭐⭐⭐⭐⭐ | not yet — needs 0.16 codegen step |
| protobuf.zig / protobuf-zig | Protobuf | ⭐⭐⭐⭐ | not yet — alternative once Arwalk lands |
| flatbuffers-zig | FlatBuffers | ⭐⭐⭐⭐⭐ | not yet — codegen + `flatc` |
| capnproto-zig | Cap’n Proto | ⭐⭐⭐⭐ | skipped — targets Zig 0.17-dev |
| ziggy | Ziggy | ⭐⭐⭐⭐ | skipped — package `build.zig` requires Zig 0.17 / lsp_kit |
| simdjson-zig | JSON SIMD | ⭐⭐⭐ | not yet — C++ binding |
| getty + getty-json | JSON | ⭐⭐⭐ | stale vs 0.16 |
| zig-json / zjson | JSON | ⭐⭐⭐ | not yet — std + serde already cover JSON |
| zig-cbor (neurocyte) | CBOR | ⭐⭐⭐ | skipped — uses removed `@typeInfo` `decl_names` on 0.16; zbor is the CBOR row |
| msgpack.zig | MessagePack | ⭐⭐⭐ | **wired** (lalinsky/msgpack.zig; mrosbar tree is unmaintained) |
| zig-serialization / zserialize / bincode-zig | binary | ⭐⭐⭐ | **s2s** wired as the native binary stream row; bincode-zig not on 0.16 |
| zson | JSON-like | ⭐⭐⭐ | not yet |
| zig-toml / zig-yaml | TOML / YAML | ⭐⭐ | covered by serde.toml / serde.yaml |
| XML / CSV | text | ⭐⭐ | **serde.xml** wired (flat types). CSV skipped — nested fixtures are not a table |

## Not a `@bitCast` of the whole fixture

A live suite value has `[]const u8` slices. `@bitCast` of that type is not a portable encoding. `comptime-bin` is the honest idiomatic stand-in: comptime reflection writes a length-prefixed little-endian image.

[Dashboard](../dashboard/?lang=zig&data=document@n=1&mode=bytes)
