---
title: "Zig"
---

# Zig

Zig serialization centers on compile-time reflection (`@typeInfo`), which specializes field traversals during compilation without runtime reflection or procedural macros. The runner evaluates standard-library `std.json` and `std.zon`, format-agnostic `serde.zig`, specialized typed JSON/MessagePack/CBOR libraries (`json.zig`, `jsonz`, `msgpack.zig`, `zbor`), an in-tree comptime binary control (`comptime-bin`), and IDL codecs (`protobuf`, `flatbuffers`, `capnproto`, `gld-avro`, `gld-arrow`, `gld-kiln`).

## Runtime & Environment

Zig compiles ahead of time to native machine code with explicit allocator passing and no garbage collector. Because Zig changes across minor versions, the runner strictly pins **Zig 0.16.x**. The shell wrapper resolves run configs to JSON beforehand so the Zig binary never spawns Python; the runner owns a reusable output buffer per serializer (`std.Io.Writer`), preventing throwaway slice allocations on text codecs. Language semantics follow the [Zig 0.16.0 Language Reference](https://ziglang.org/documentation/0.16.0/).

| Property | Configuration |
|---|---|
| Language / spec | Zig 0.16.x ([Zig 0.16.0 Language Reference](https://ziglang.org/documentation/0.16.0/)) |
| Build & toolchain | `zig build` (ReleaseFast); Zig 0.15 or 0.17 will not build this tree; `libcapnp` / `libkj` under `~/.local` for Cap'n Proto |
| Memory model | Explicit allocators (per-trial arena + reused output buffers); no garbage collector |
| Runner & logs | `zig/scripts/run-benchmarks.sh` → `logs/zig/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`zig/src/serializers.zig`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/zig/src/serializers.zig) |
| Data sets | `suite`, `tensor` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [capnproto](https://github.com/capnproto/capnproto) | `capnp` | `suite` | `adapted` | Official Cap'n Proto C++ 1.0.2 runtime via C ABI (`cpp/schemas/benchmark.capnp`) |
| [comptime-bin](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/zig/src/packed_bin.zig) | `custom` | `suite` | `adapted` | In-tree comptime `@typeInfo` little-endian length-prefixed baseline (not `@bitCast`) |
| [flatbuffers](https://github.com/nDimensional/zig-flatbuffers) | `flatbuffers` | `suite` | `adapted` | `nDimensional/zig-flatbuffers` 0.2.1 `Builder.writeTable` / `decodeRoot` (`cpp/schemas/benchmark.fbs`) |
| [gld-arrow](https://github.com/leo-gan/gld-arrow-zig) | `arrow` | `suite` | `adapted` | `leo-gan/gld-arrow-zig` 0.2.0 Arrow IPC stream; `rowsFromBatch` on decode |
| [gld-avro](https://github.com/leo-gan/gld-avro-zig) | `avro` | `suite` | `adapted` | `leo-gan/gld-avro-zig` 0.2.0 `parseAvsc` in `prepare`; timed `Datum.encodeTo` / `decodeBin` |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-zig) | `kiln` | `suite`, `tensor` | `adapted` | `leo-gan/gld-kiln-zig` 0.2.0 positional `encodeReuse` / `decode`; `tensor_view` borrows payload |
| [json.zig](https://github.com/lalinsky/json.zig) | `json` | `suite` | `native` | `lalinsky/json.zig` 0.2.0 comptime-typed encode into reused buffer / `decodeFromSliceLeaky` into cell arena |
| [jsonz](https://github.com/KercyDing/jsonz) | `json` | `suite` | `text_on_stream` | `KercyDing/jsonz` 0.9.2 `typed.toWriter` into reused buffer / owning `typed.parse` |
| [msgpack.zig](https://github.com/lalinsky/msgpack.zig) | `msgpack` | `suite` | `native` | `lalinsky/msgpack.zig` 0.10.0 typed `encode` into reused buffer / `decodeFromSlice` |
| [protobuf](https://github.com/Arwalk/zig-protobuf) | `protobuf` | `suite` | `adapted` | `Arwalk/zig-protobuf` 5.0.0 generated from `benchmark_v2.proto`; conversion untimed in `prepare` |
| [s2s](https://github.com/ziglibs/s2s) | `custom` | `suite` | `native` | `ziglibs/s2s` native Zig struct-to-stream binary |
| [serde.json](https://github.com/OrlovEvgeny/serde.zig) | `json` | `suite` | `text_on_stream` | `serde.zig` comptime `toWriter` / `fromSlice` (owning strings) |
| [serde.json.borrowed](https://github.com/OrlovEvgeny/serde.zig) | `json` | `suite` | `text_on_stream` | Same `toWriter`; decode uses `fromSliceBorrowed` (strict zero-copy views; rejects escapes) |
| [serde.msgpack](https://github.com/OrlovEvgeny/serde.zig) | `msgpack` | `suite` | `text_on_stream` | `serde.zig` MessagePack backend |
| [serde.toml](https://github.com/OrlovEvgeny/serde.zig) | `toml` | `suite` | `text_on_stream` | `serde.zig` TOML backend |
| [serde.xml](https://github.com/OrlovEvgeny/serde.zig) | `custom` | `suite` | `text_on_stream` | `serde.zig` XML backend (`message` and `strings` only) |
| [serde.yaml](https://github.com/OrlovEvgeny/serde.zig) | `yaml` | `suite` | `text_on_stream` | `serde.zig` YAML backend (skips `document` and `event`; see caveats) |
| [serde.zon](https://github.com/OrlovEvgeny/serde.zig) | `zon` | `suite` | `text_on_stream` | `serde.zig` Zig Object Notation backend |
| [std.json](https://github.com/ziglang/zig) | `json` | `suite` | `text_on_stream` | Stdlib `Stringify.value` + `parseFromSlice` (`.alloc_always`) |
| [std.json.borrowed](https://github.com/ziglang/zig) | `json` | `suite` | `text_on_stream` | Same `Stringify.value`; decode uses `parseFromSliceLeaky` (`.alloc_if_needed`) |
| [std.json.scanner](https://github.com/ziglang/zig) | `json` | `suite` | `text_on_stream` | Same `Stringify.value`; decode uses `std.json.Scanner` + `parseFromTokenSource` |
| [std.zon](https://github.com/ziglang/zig) | `zon` | `suite` | `text_on_stream` | Stdlib `std.zon.stringify` + `std.zon.parse.fromSliceAlloc` |
| [zbor](https://codeberg.org/r4gus/zbor) | `cbor` | `suite` | `adapted` | `r4gus/zbor` 0.21.3 native CBOR `stringify` / `parse` |
| [zig-msgpack](https://github.com/zigcc/zig-msgpack) | `msgpack` | `suite` | `adapted` | `zigcc/zig-msgpack` 0.0.18 `Payload` API |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[capnproto](https://github.com/capnproto/capnproto)** — Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.
    - **[comptime-bin](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/zig/src/packed_bin.zig)** — comptime-bin is the suite's in-tree Zig baseline: a comptime `@typeInfo` walk that writes little-endian, length-prefixed fields. It exists because `@bitCast` of a live struct value is not a valid encoding (slices are pointers).
    - **[flatbuffers](https://github.com/nDimensional/zig-flatbuffers)** — nDimensional/zig-flatbuffers generates Zig from FlatBuffers schemas. FlatBuffers exists so readers can use data without unpacking. This is the Zig codegen this suite times.
    - **[gld-arrow](https://github.com/leo-gan/gld-arrow-zig)** — gld-arrow-zig (leo-gan) is a pure-Zig Apache Arrow IPC stream codec supporting the five suite data types, decoding back via `rowsFromBatch`.
    - **[gld-avro](https://github.com/leo-gan/gld-avro-zig)** — gld-avro-zig (leo-gan) is a pure-Zig Apache Avro binary codec that parses `.avsc` schemas once in `prepare` and times `Datum.encodeTo` and `decodeBin`.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-zig)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[json.zig](https://github.com/lalinsky/json.zig)** — lalinsky/json.zig is a typed JSON library for Zig: the encoder and decoder are comptime-specialized into the Zig type, so there is no DOM and no runtime schema. It exists to make JSON cheap for APIs with a fixed schema, and it reads and writes std.Io readers and writers, so a value larger than the buffer still decodes.
    - **[jsonz](https://github.com/KercyDing/jsonz)** — jsonz is a native Zig JSON library with typed and DOM APIs. This row uses typed.toWriter into the reused output buffer and typed.parse into suite structs. Strings are copied; its pool and fallback allocations remain in the trial arena until fidelity checking. Allocation is timed; arena cleanup is outside decode timing.
    - **[msgpack.zig](https://github.com/lalinsky/msgpack.zig)** — lalinsky/msgpack.zig is another MessagePack library for Zig with a typed encode/decode API. It exists as a native Zig implementation of the same MessagePack spec.
    - **[protobuf](https://github.com/Arwalk/zig-protobuf)** — Arwalk/zig-protobuf generates Zig from `.proto` files. Protocol Buffers exist as a language-neutral IDL. This package is the Zig implementation this suite uses.
    - **[s2s](https://github.com/ziglibs/s2s)** — s2s (struct to stream) is a Zig-only binary encoder that writes structs to a stream. It was created as a simple native binary path, not a public interchange standard.
    - **[serde.json](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.json.borrowed](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.msgpack](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.toml](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.xml](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.yaml](https://github.com/OrlovEvgeny/serde.zig)**, **[serde.zon](https://github.com/OrlovEvgeny/serde.zig)** — serde.zig is a format-agnostic serialization framework for Zig that walks types with `@typeInfo` at comptime. The problem was writing a new field walk per format. One API covers JSON, MessagePack, YAML, TOML, ZON, and XML.
        - `serde.json`: This row is the JSON backend of serde.zig.
        - `serde.json.borrowed`: Uses borrowed string views (`fromSliceBorrowed`) on decode instead of copying unescaped strings; encode uses the same comptime `toWriter` path as `serde.json`.
        - `serde.msgpack`: This row is the MessagePack backend of serde.zig.
        - `serde.toml`: This row is the TOML backend of serde.zig.
        - `serde.xml`: This row is the XML backend of serde.zig (message / strings only).
        - `serde.yaml`: This row is the YAML backend of serde.zig (message / strings only).
        - `serde.zon`: This row is the ZON backend of serde.zig.
    - **[std.json](https://github.com/ziglang/zig)**, **[std.json.scanner](https://github.com/ziglang/zig)** — Zig's `std.json` is the standard-library JSON codec. It exists so Zig programs can speak JSON without a package. This suite times typed `parseFromSlice` and, separately, the Scanner path.
        - `std.json.scanner`: Decode is `Scanner` + `parseFromTokenSource`; stringify is the same as `std.json`.
    - **[std.json.borrowed](https://github.com/ziglang/zig)** — Uses `parseFromSliceLeaky` with `.allocate = .alloc_if_needed` so unescaped strings are decoded as borrowed slices into the input buffer rather than copied; encode matches `std.json`.
    - **[std.zon](https://github.com/ziglang/zig)** — ZON (Zig Object Notation) is Zig's own data notation, in the standard library. It exists as a Zig-native text format for config and data. This row times official stringify/parse.
    - **[zbor](https://codeberg.org/r4gus/zbor)** — zbor is a native Zig CBOR library. CBOR is the IETF binary JSON-like format. zbor implements stringify/parse for Zig types.
    - **[zig-msgpack](https://github.com/zigcc/zig-msgpack)** — zigcc/zig-msgpack is a MessagePack implementation for Zig. MessagePack exists as compact binary JSON. This package exposes a Payload encode/decode API.

## Measurement Caveats

- **Why `comptime-bin` is not `@bitCast`:** Suite structs contain `[]const u8` slices (pointer + length pairs), so a raw `@bitCast` would serialize process addresses rather than bytes. `comptime-bin` performs a comptime `@typeInfo` field walk writing little-endian values and `u32` length-prefixed slices.
- **Borrowed JSON string semantics:** `std.json.borrowed` (`alloc_if_needed`) allocates when a string contains escape sequences, whereas `serde.json.borrowed` (`fromSliceBorrowed`) strictly requires unescaped slices and rejects escaped inputs. Both are comparable on this suite's unescaped generated payloads, but differ on general JSON.
- **`serde.yaml` skipped shapes:** `serde.zig` drops fields of structs nested inside lists when decoding YAML, so `serde.yaml` skips `document` and `event` (pinned by unit tests in `zig/src/serde_ser.zig`).
- **Shared IDL codegen & Cap'n Proto C++ bridge:** `protobuf` (`./zig/scripts/generate-protobuf.sh`), `flatbuffers` (`./zig/scripts/generate-flatbuffers.sh`), and `capnproto` (`./zig/scripts/generate-capnp.sh`) compile the repository's shared schemas (`schemas/v2/protobuf/benchmark_v2.proto`, `cpp/schemas/benchmark.fbs`, `cpp/schemas/benchmark.capnp`). Because Zig 0.16 lacks a native Cap'n Proto plugin, `capnproto` links the official C++ library via a C ABI (requiring `libcapnp` / `libkj` under `~/.local`).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Zig)](../dashboard/index.html?lang=zig&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Zig)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Zig: `std.json` vs. `serde.json`](../analysis/call-sites/zig-std-json-vs-serde-json.md)
- **Build & run guide:** [`zig/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/zig/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
