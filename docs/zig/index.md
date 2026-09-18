---
title: "Zig"
---

Zig
===

Zig is in this suite because **comptime reflection** (`@typeInfo`) is a different implementation model from Java/Kotlin runtime reflection, C# source generation, or Rust derive macros. The runner times official `std.json` (typed `parseFromSlice` versus streaming `Scanner` / `parseFromTokenSource`) against an in-tree comptime byte-packed baseline, against **serde.zig**, a format-agnostic framework that uses the same `@typeInfo` walk for JSON, MessagePack, YAML, TOML, and ZON, against typed third-party codecs that specialize the whole encoder into the destination type (**json.zig**, **msgpack.zig**), and against **schema codecs** (Protocol Buffers, FlatBuffers, Cap’n Proto) generated from the shared suite IDLs.

## Runtime

### What it is

Zig compiles to **native machine code**. There is no hidden virtual machine and no garbage collector. Allocation is explicit: the benchmark runner passes allocators in. **Comptime** means the compiler can run Zig code while it builds. `@typeInfo` walks a struct at compile time instead of using Java-style reflection at run time.

| | This suite |
|---|---|
| Compiler | Zig **0.16.x**. Version 0.15 or 0.17 will not build this tree. |
| Prepare | `./scripts/install-host-requirements.sh zig` installs into `~/.local/zig` |
| Run | `zig/scripts/run-benchmarks.sh` (`zig build`) |
| Memory | Explicit allocators. No garbage collector. |

### What this suite runs

Zig still changes in breaking ways between minor versions, so the host script installs 0.16.x and the checker rejects any other series. The Zig binary does not start Python. Cap’n Proto uses the official C++ library, because Zig 0.16 has no native Cap’n Proto plugin.

### What changes the numbers

Building without optimizations is the error that changes the numbers the most, because an unoptimized Zig binary is far slower than a release build. Codecs that use comptime, such as `std.json`, serde.zig, and `comptime-bin`, generate the field walk while the program compiles.

A `@bitCast` of a live suite value is not a valid encoding. Slices inside that value are pointers, not payload bytes. See [Not a `@bitCast`](#not-a-bitcast-of-the-whole-fixture).

### Suite-specific gotchas

The `capnproto` row needs `libcapnp` and `libkj` under `~/.local`.

`serde.yaml` skips **document** and **event**: serde.zig 1.2.2 loses the fields of a struct nested in a list, so those cells would be a timing for a decode that did not restore the value. `zig/src/serde_ser.zig` has the round-trip test that pins exactly which shapes fail and with which error.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`zig/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/zig/README.md). The language overview is [Zig overview](https://ziglang.org/learn/overview/).

## Benchmark runner

- Directory: `zig/` (repository root)
- Output: `logs/zig/YYYY-MM-DD-HHMMSS.csv` (`Language=zig`, times in **nanoseconds**)
- Runner: `zig/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: `zig/src/serializers.zig`

The shell script resolves the run config to JSON. The Zig binary does not spawn Python. Prepare is untimed. The harness owns a reusable output buffer per serializer, and every text codec writes into it through `std.Io.Writer`, so no row pays for a throwaway slice the runner then copies and frees. Timed I/O is serialize plus deserialize only. Schedule is SHA-256 + SplitMix64 Fisher–Yates (golden vector `C, B, A`).

## Serializers (wired)

| Name | Category | Package | Stream | Notes |
|------|----------|---------|--------|-------|
| [std.json](https://github.com/ziglang/zig) | JSON | std | text_on_stream | `Stringify.value` + `parseFromSlice` into the suite struct |
| [std.json.borrowed](https://github.com/ziglang/zig) | JSON | std | text_on_stream | Same stringify; decode is `parseFromSliceLeaky` with `alloc_if_needed` |
| [std.json.scanner](https://github.com/ziglang/zig) | JSON | std | text_on_stream | Same stringify; decode is `Scanner` + `parseFromTokenSource` |
| [std.zon](https://github.com/ziglang/zig) | ZON | std | text_on_stream | Official `std.zon.stringify` + `std.zon.parse.fromSliceAlloc` |
| [comptime-bin](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/zig/index.md) | Binary | in-tree | adapted | Comptime field walk; LE ints; `u32` length + bytes for strings |
| [serde.json](https://github.com/OrlovEvgeny/serde.zig) | JSON | serde.zig 1.2.2 | text_on_stream | One comptime API, JSON path |
| [serde.json.borrowed](https://github.com/OrlovEvgeny/serde.zig) | JSON | serde.zig 1.2.2 | text_on_stream | Same encode; decode is `fromSliceBorrowed` |
| [serde.msgpack](https://github.com/OrlovEvgeny/serde.zig) | Binary | serde.zig 1.2.2 | text_on_stream | Same API, MessagePack |
| [serde.yaml](https://github.com/OrlovEvgeny/serde.zig) | Text | serde.zig 1.2.2 | text_on_stream | Same API, YAML. **no document / event** |
| [serde.toml](https://github.com/OrlovEvgeny/serde.zig) | Text | serde.zig 1.2.2 | text_on_stream | Same API, TOML |
| [serde.zon](https://github.com/OrlovEvgeny/serde.zig) | Text | serde.zig 1.2.2 | text_on_stream | Same API, Zig Object Notation |
| [serde.xml](https://github.com/OrlovEvgeny/serde.zig) | Text | serde.zig 1.2.2 | text_on_stream | Same API, XML |
| [zig-msgpack](https://github.com/zigcc/zig-msgpack) | Binary | zigcc/zig-msgpack 0.0.18 | adapted | Official MessagePack Payload API |
| [msgpack.zig](https://github.com/lalinsky/msgpack.zig) | Binary | lalinsky/msgpack.zig 0.9.0 | native | Typed `encode` / `decodeFromSlice` |
| [json.zig](https://github.com/lalinsky/json.zig) | JSON | lalinsky/json.zig 0.1.0 | native | Typed `encode` / `decodeFromSliceLeaky` into the cell arena |
| [zbor](https://codeberg.org/r4gus/zbor) | Binary | r4gus/zbor 0.21.3 | adapted | Native Zig CBOR (`stringify` / `parse`) |
| [s2s](https://github.com/ziglibs/s2s) | Binary | ziglibs/s2s | native | Native binary “struct to stream” |
| [protobuf](https://github.com/Arwalk/zig-protobuf) | Schema | Arwalk/zig-protobuf 5.0.0 | adapted | Generated from `schemas/v2/protobuf/benchmark_v2.proto`. Prepare copies suite → generated message; timed path is `encode` / `decode` |
| [flatbuffers](https://github.com/nDimensional/zig-flatbuffers) | Schema | nDimensional/zig-flatbuffers 0.2.1 | adapted | Generated from `cpp/schemas/benchmark.fbs`. Timed path is `Builder.writeTable` / `decodeRoot` |
| [capnproto](https://github.com/capnproto/capnproto) | Schema | Cap’n Proto C++ 1.0.2 | adapted | Generated from `cpp/schemas/benchmark.capnp`. Official C++ runtime via a C ABI (same pattern as Swift). Zig 0.16 has no native plugin |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [std.json](https://github.com/ziglang/zig) · `0.16.0`

Zig's `std.json` is the standard-library JSON codec. It exists so Zig programs can speak JSON without a package. This suite times typed `parseFromSlice` and, separately, the Scanner path.

#### [std.json.scanner](https://github.com/ziglang/zig) · `0.16.0`

Zig's `std.json` is the standard-library JSON codec. It exists so Zig programs can speak JSON without a package. This suite times typed `parseFromSlice` and, separately, the Scanner path. Decode is `Scanner` + `parseFromTokenSource`; stringify is the same as `std.json`.

#### [std.zon](https://github.com/ziglang/zig) · `0.16.0`

ZON (Zig Object Notation) is Zig's own data notation, in the standard library. It exists as a Zig-native text format for config and data. This row times official stringify/parse.

#### [comptime-bin](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/docs/zig/index.md) · `in-tree`

comptime-bin is the suite's in-tree Zig baseline: a comptime `@typeInfo` walk that writes little-endian, length-prefixed fields. It exists because `@bitCast` of a live fixture is not a valid encoding (slices are pointers).

#### [serde.json](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the JSON backend of serde.zig.

#### [serde.json.borrowed](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

The same encode as `serde.json`; the decode is `fromSliceBorrowed`, which returns strings that point into the input instead of copying them. serde.zig's borrowed API is strictly a view: it rejects a string carrying any escape rather than allocating to unescape it, so this row is only comparable on inputs whose strings are literal. `std.json.borrowed` is the stdlib counterpart (`alloc_if_needed`), which does allocate for an escaped string; the fixtures in this suite are unescaped, so both rows decode the same bytes.

#### [serde.msgpack](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the MessagePack backend of serde.zig.

#### [serde.yaml](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the YAML backend of serde.zig (no document / event).

#### [serde.toml](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the TOML backend of serde.zig.

#### [serde.zon](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the ZON backend of serde.zig.

#### [serde.xml](https://github.com/OrlovEvgeny/serde.zig) · `1.2.2`

serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML. This row is the XML backend of serde.zig.

#### [zig-msgpack](https://github.com/zigcc/zig-msgpack) · `0.0.18`

zigcc/zig-msgpack is a MessagePack implementation for Zig. MessagePack exists as compact binary JSON. This package exposes a Payload encode/decode API.

#### [msgpack.zig](https://github.com/lalinsky/msgpack.zig) · `0.9.0`

lalinsky/msgpack.zig is another MessagePack library for Zig with a typed encode/decode API. It exists as a native Zig implementation of the same MessagePack spec.

#### [json.zig](https://github.com/lalinsky/json.zig)

lalinsky/json.zig is a typed JSON library for Zig: the encoder and decoder are comptime-specialized into the Zig type, so there is no DOM and no runtime schema. It exists to make JSON cheap for APIs with a fixed schema, and it reads and writes std.Io readers and writers, so a value larger than the buffer still decodes.

#### [zbor](https://codeberg.org/r4gus/zbor) · `0.21.3`

zbor is a native Zig CBOR library. CBOR is the IETF binary JSON-like format. zbor implements stringify/parse for Zig types.

#### [s2s](https://github.com/ziglibs/s2s) · `0.0.1`

s2s (struct to stream) is a Zig-only binary encoder that writes structs to a stream. It was created as a simple native binary path, not a public interchange standard.

#### [protobuf](https://github.com/Arwalk/zig-protobuf) · `5.0.0`

Arwalk/zig-protobuf generates Zig from `.proto` files. Protocol Buffers exist as a language-neutral IDL. This package is the Zig implementation this suite uses.

#### [flatbuffers](https://github.com/nDimensional/zig-flatbuffers) · `0.2.1`

nDimensional/zig-flatbuffers generates Zig from FlatBuffers schemas. FlatBuffers exists so readers can use data without unpacking. This is the Zig codegen this suite times.

#### [capnproto](https://github.com/capnproto/capnproto) · `1.0.2`

Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.

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
