# Language Call-Site Notes

These reference notes open the actual timed `serialize` and `deserialize` call sites in this repository on the `document` ($n = 1$, `bytes` mode) payload, one language at a time, to explain *why* two registered serializers differ in latency or wire size under the [Timing honesty](../TIMING_HONESTY.md) contract.

For conceptual codec architecture and the five canonical comparative course labs (`msgspec-msgpack` vs. `orjson`, `Speedy` vs. `Bincode`, `rkyv` vs. `Speedy`, three JavaScript Protocol Buffers libraries, and the C++ `simdjson` wrapper), see **[Serialization 401: Part B](../../theory/401/index.md#part-b-comparative-codec-case-studies)**. Authoritative live measurements belong to the [Dashboard](../../dashboard/index.html).

---

## Per-Language Call-Site Catalog

| Language | Comparison Note | Standard(s) | Primary Mechanism Examined |
|---|---|---|---|
| **C** | [custom-binary vs. ubj](c-custom-binary-vs-ubj.md) | No public spec & UBJSON | Same packed record plus 37-byte UBJSON envelope and copy |
| **C#** | [BinaryPack vs. Bond Fast](csharp-binarypack-vs-bond.md) | No public spec & Bond | Positional IL stores vs. per-field type-and-ID prefixes |
| **C++** | [Bitsery vs. YAS](cpp-bitsery-vs-yas.md) | No public spec | 1-byte varint lengths & reused buffer vs. 8-byte lengths & stream buffer |
| **Fortran** | [json-fortran vs. rojff](fortran-json-fortran-vs-rojff.md) | JSON | Two pure-Fortran JSON writers and 64-bit integer formatting |
| **Go** | [kelindar/binary vs. hamba/avro](go-kelindar-vs-avro.md) | No public spec & Avro | Two cached positional plans; Avro schema walk vs. struct scan |
| **Java** | [Protostuff vs. protobuf-java](java-protostuff-vs-protobuf.md) | No public spec & Protocol Buffers | Identical 155-byte output: POJO merge vs. generated `parseFrom` |
| **JavaScript** | [JSON.stringify vs. google-protobuf](javascript-json-vs-protobuf.md) | JSON & Protocol Buffers | V8 native C++ JSON path vs. userland JS Protobuf reader/writer loops |
| **Kotlin** | [FlatBuffers vs. protobuf](kotlin-flatbuffers-vs-protobuf.md) | FlatBuffers & Protocol Buffers | Vtable offset loads vs. compact tag-stream decoding |
| **Kotlin** | [kotlinx-json vs. Moshi](kotlin-kotlinx-json-vs-moshi.md) | JSON | Identical 440-byte JSON: multi-format plugin vs. generated Moshi adapter |
| **Kotlin** | [Protostuff vs. protobuf](kotlin-protostuff-vs-protobuf.md) | No public spec & Protocol Buffers | Same 155-byte comparison in Kotlin; why `protobuf-kotlin` tracks `protobuf-java` |
| **Mojo** | [EmberJson vs. mojo-avro](mojo-emberjson-vs-avro.md) | JSON & Avro | Named JSON text vs. schema-ordered Avro binary datum |
| **PHP** | [JSON vs. google/protobuf](php-json-vs-protobuf.md) | JSON & Protocol Buffers | Interpreter C JSON engine vs. official userland PHP Protobuf runtime |
| **Python** | [msgspec JSON vs. MessagePack](python-msgspec-json-vs-msgpack.md) | JSON & MessagePack | Holding the library constant (`msgspec.Struct`) to isolate wire syntax |
| **Python** | [orjson vs. stdlib json](python-orjson-vs-json.md) | JSON | Holding identical 448-byte JSON constant to isolate Rust vs. stdlib `str` encoding |
| **Rust** | [Speedy vs. Postcard](rust-speedy-vs-postcard.md) | No public spec | Staying on `Serde` with compact varints (`Postcard`) vs. direct fixed-width (`Speedy`) |
| **Swift** | [FlatBuffers vs. SwiftProtobuf](swift-flatbuffers-vs-protobuf.md) | FlatBuffers & Protocol Buffers | Vtable buffer layout (440 B) vs. tag stream (155 B) under domain materialization |
| **Zig** | [std.json vs. serde.json](zig-std-json-vs-serde-json.md) | JSON | Two comptime `@typeInfo` JSON libraries and borrowed-string semantics |

---

## Canonical Course Labs in Serialization 401

Five foundational comparisons live inside the [Serialization 401](../../theory/401/index.md) curriculum because each isolates a general codec-engineering principle:

- [4.8 Python: `msgspec-msgpack` vs. `orjson`](../../theory/401/python-msgspec-vs-orjson.md) — positional typed struct slots vs. dynamic dictionaries
- [4.9 Rust: `Speedy` vs. `Bincode`](../../theory/401/rust-speedy-vs-bincode.md) — compile-time fixed-width codegen vs. `Serde` visitor + varints
- [4.10 Rust: `rkyv` vs. `Speedy`](../../theory/401/rust-rkyv-vs-speedy.md) — zero-copy archive layout timed via owned materialization
- [4.11 JavaScript: three Protocol Buffers libraries](../../theory/401/javascript-three-protobufs.md) — pure implementation variance on identical 155-byte output
- [4.12 C++: the `simdjson` wrapper](../../theory/401/cpp-simdjson-wrapper.md) — auditing parse-only and `native_kind: dom` adapters
