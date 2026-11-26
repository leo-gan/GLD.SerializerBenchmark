# Language Call-Site Notes

These technical reference notes inspect the timed `serialize` and `deserialize` call sites of paired adapters on the `document` ($n = 1$, `bytes` mode) payload, one language at a time. Each note records **invariant structural facts**—exact wire sizes, timed boundary definitions, buffer and allocation patterns, and code paths audited under the [Timing contract](../TIMING_HONESTY.md)—while linking directly to the live pre-filtered [Dashboard](../../dashboard/index.html) Compare slice for current L1 timings.

For the five canonical conceptual codec labs with exercises and primary references (`msgspec-msgpack` vs. `orjson`, `Speedy` vs. `Bincode`, `rkyv` vs. `Speedy`, three JavaScript Protocol Buffers libraries, and the C++ `simdjson` wrapper), see **[Serialization 401: Part B](../../theory/401/index.md#part-b-comparative-codec-case-studies)**.

## Per-Language Call-Site Catalog

| Language | Call-Site Note | Standard(s) | Primary Mechanism Isolated |
|---|---|---|---|
| **C** | [`custom-binary` vs. `ubj`](c-custom-binary-vs-ubj.md) | `custom` & `ubjson` | Identical 196 B packed record plus 37 B UBJSON envelope and extra copy |
| **C#** | [`BinaryPack` vs. `MS Bond Fast`](csharp-binarypack-vs-bond.md) | `custom` & `bond` | Positional IL stores (224 B) vs. per-field type-and-ID prefixes (282 B) |
| **C++** | [`Bitsery` vs. `YAS`](cpp-bitsery-vs-yas.md) | `custom` | 1-byte varint lengths & reused buffer (190 B) vs. 8-byte lengths, 7 B header & fresh stream (274 B) |
| **Fortran** | [`json-fortran` vs. `rojff`](fortran-json-fortran-vs-rojff.md) | `json` | Identical 473 B compact JSON; `json_core` (`int64`) vs. `rojff` (`int32` default) |
| **Go** | [`kelindar/binary` vs. `hamba/avro`](go-kelindar-vs-avro.md) | `custom` & `avro` | Two cached positional zigzag-varint plans (113 B vs. 116 B): struct codec vs. schema-keyed encoder |
| **Java** | [`Protostuff` vs. `protobuf-java`](java-protostuff-vs-protobuf.md) | `custom` & `protobuf` | Identical 155 B output: direct POJO `RuntimeSchema` vs. generated message copy |
| **JavaScript** | [`JSON.stringify` vs. `google-protobuf`](javascript-json-vs-protobuf.md) | `json` & `protobuf` | V8 native C++ JSON (448 B) vs. userland JS Protobuf reader/writer loops (155 B) |
| **Kotlin** | [`FlatBuffers` vs. `protobuf`](kotlin-flatbuffers-vs-protobuf.md) | `flatbuffers` & `protobuf` | Vtable offset loads (416 B) vs. compact tag-stream decode (155 B) |
| **Kotlin** | [`kotlinx-json` vs. `Moshi`](kotlin-kotlinx-json-vs-moshi.md) | `json` | Identical 440 B JSON: multi-format `KSerializer` vs. KSP-generated `JsonAdapter` |
| **Kotlin** | [`Protostuff` vs. `protobuf`](kotlin-protostuff-vs-protobuf.md) | `custom` & `protobuf` | Identical 155 B output in Kotlin; why `protobuf-kotlin` tracks `protobuf-java` |
| **Mojo** | [`EmberJson` vs. `mojo-avro`](mojo-emberjson-vs-avro.md) | `json` & `avro` | Reflection named JSON text (448 B) vs. schema-ordered Avro binary datum (114 B) |
| **PHP** | [`json` vs. `google/protobuf`](php-json-vs-protobuf.md) | `json` & `protobuf` | Built-in C `ext-json` engine (454 B) vs. userland PHP Protobuf runtime (160 B) |
| **Python** | [`msgspec` JSON vs. MessagePack](python-msgspec-json-vs-msgpack.md) | `json` & `msgpack` | Holding the C library and `array_like` Struct constant (192 B vs. 129 B) |
| **Python** | [`orjson` vs. stdlib `json`](python-orjson-vs-json.md) | `json` | Identical 448 B JSON: direct Rust UTF-8 vs. CPython `str` round trip and uncached `JSONEncoder` |
| **Rust** | [`Speedy` vs. `Postcard`](rust-speedy-vs-postcard.md) | `custom` | Fixed-width direct traits (214 B) vs. `serde` + compact varints (114 B) |
| **Swift** | [`FlatBuffers` vs. `SwiftProtobuf`](swift-flatbuffers-vs-protobuf.md) | `flatbuffers` & `protobuf` | Vtable layout with `FixtureRoot` (440 B) vs. tag stream (155 B) under domain materialization |
| **Zig** | [`std.json` vs. `serde.json`](zig-std-json-vs-serde-json.md) | `json` | Identical 448 B JSON across two comptime `@typeInfo` codecs and borrowed-string decode modes |

## Canonical Course Labs in Serialization 401

- [4.8 Python: `msgspec-msgpack` vs. `orjson`](../../theory/401/python-msgspec-vs-orjson.md) — positional typed slots vs. dynamic dictionaries
- [4.9 Rust: `Speedy` vs. `Bincode`](../../theory/401/rust-speedy-vs-bincode.md) — compile-time fixed-width codegen vs. `Serde` visitor + varints
- [4.10 Rust: `rkyv` vs. `Speedy`](../../theory/401/rust-rkyv-vs-speedy.md) — zero-copy archive layout timed via owned materialization
- [4.11 JavaScript: three Protocol Buffers libraries](../../theory/401/javascript-three-protobufs.md) — pure implementation variance on identical 155-byte output
- [4.12 C++: the `simdjson` wrapper](../../theory/401/cpp-simdjson-wrapper.md) — auditing parse-only and DOM adapters
