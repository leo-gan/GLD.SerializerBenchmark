---
title: "Zig"
---

Zig
===

Zig is in this suite because **comptime reflection** (`@typeInfo`) is a different implementation model from Java/Kotlin runtime reflection, C# source generation, or Rust derive macros. The runner times official `std.json` (typed `parseFromSlice` versus streaming `Scanner` / `parseFromTokenSource`) against an in-tree comptime byte-packed baseline, against **serde.zig**, a format-agnostic framework that uses the same `@typeInfo` walk for JSON, MessagePack, YAML, TOML, and ZON, and against **schema codecs** (Protocol Buffers, FlatBuffers, Cap’n Proto) generated from the shared suite IDLs.

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
| protobuf | Schema | Arwalk/zig-protobuf 5.0.0 | adapted | Generated from `schemas/v2/protobuf/benchmark_v2.proto`. Prepare copies suite → generated message; timed path is `encode` / `decode` |
| flatbuffers | Schema | nDimensional/zig-flatbuffers 0.2.1 | adapted | Generated from `cpp/schemas/benchmark.fbs`. Timed path is `Builder.writeTable` / `decodeRoot` |
| capnproto | Schema | Cap’n Proto C++ 1.0.2 | adapted | Generated from `cpp/schemas/benchmark.capnp`. Official C++ runtime via a C ABI (same pattern as Swift). Zig 0.16 has no native plugin |

## Not a `@bitCast` of the whole fixture

A live suite value has `[]const u8` slices. `@bitCast` of that type is not a portable encoding. `comptime-bin` is the honest idiomatic stand-in: comptime reflection writes a length-prefixed little-endian image.

## Schema generation

These rows compile the **same** suite IDLs as the other languages. They do not invent Zig-only schemas.

| Row | Shared schema | Regenerate |
|-----|---------------|------------|
| protobuf | `schemas/v2/protobuf/benchmark_v2.proto` | `./zig/scripts/generate-protobuf.sh` |
| flatbuffers | `cpp/schemas/benchmark.fbs` | `./zig/scripts/generate-flatbuffers.sh` |
| capnproto | `cpp/schemas/benchmark.capnp` | `./zig/scripts/generate-capnp.sh` |

Prepare copies each suite fixture into the library’s native form (untimed). The timer measures encode and decode only. Fidelity copies back to the suite struct after decode.

`capnproto` uses the official C++ library (like Swift) because the Zig Cap’n Proto plugin requires Zig 0.17-dev. The host needs `libcapnp` / `libkj` under `~/.local` (`./scripts/install-host-requirements.sh zig`).

[Dashboard](../dashboard/?lang=zig&data=document@n=1&mode=bytes)
