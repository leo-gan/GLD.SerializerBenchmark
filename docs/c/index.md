---
title: "C"
---

C
===

C serialization is fragmented: each library owns its own object model (DOM trees, streams, generated structs).

## Runtime

### What it is

C has **no virtual machine**. `gcc` or `clang` compiles C11 to a native binary. Memory is **manual**: each library allocates and frees, or the benchmark runner does. There is no just-in-time compiler to warm up, and no garbage collector to pause the process. A C microsecond is therefore not the same kind of number as a C# or Python microsecond.

| | This suite |
|---|---|
| Language | **C11** through CMake. C++17 is used only for Google libprotobuf. |
| Build | CMake in the **Release** configuration |
| Prepare | `cmake`, `curl`, and `c/scripts/fetch-and-build-deps.sh` |
| Run | `c/scripts/run-benchmarks.sh` |
| Memory | Manual allocation. No garbage collector. |

### What this suite runs

Third-party libraries are downloaded and built as static dependencies the first time you run the tree. Official Google protobuf uses the shared C++ sysroot created by `cpp/scripts/setup-protobuf-sysroot.sh`. A serializer is registered only when CMake actually linked it. The configure log prints `serializer: … REAL` for those rows.

### What changes the numbers

The choice of compiler and its optimization flags (`-O`) changes the numbers more than almost anything else. A CMake **Debug** build is not comparable to the Dashboard. Each library has its own object model: a DOM tree, a stream, or a generated struct. The suite visitor in `v2_codec.c` walks the fields so wrappers do not hard-code the V2 graph.

### Suite-specific gotchas

Stream mode is **adapted** for every row. The timed path writes or reads a full buffer through `fmemopen`, which is an in-memory `FILE*`. It is not each library’s own incremental stream API.

`nanopb`, `protobuf-c`, and `protobuf-wire` currently time a shared in-tree proto3 helper. They are not full code-generated stacks for those libraries. See [caveats](#caveats).

C rows and C++ rows are not the same runtime. See [C vs C++](../cpp/index.md#c-vs-c-clear-separation).

### Where to go next

The steps to install the toolchain and run the benchmark are in [`c/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/README.md). The language reference is [C on cppreference](https://en.cppreference.com/w/c).

## Benchmark runner

- `c/` (repository root)
- Logs: `logs/c/YYYY-MM-DD-HHMMSS.csv`
- Build: CMake, C11 (+ C++17 for Google libprotobuf)
- Deps: `c/scripts/fetch-and-build-deps.sh`; Google protobuf: `cpp/scripts/setup-protobuf-sysroot.sh`
- Registration: [`c/src/register_serializers.c`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/register_serializers.c)
- **Domain shape:** map-style codecs use a single visitor in [`c/src/v2_codec.c`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/v2_codec.c) (`v2_write_fixture` / `v2_read_fixture`). Wrappers implement library ops only—they do not hard-code V2 field graphs.

## Serializers

| Name | Category | Timed path (what the row measures) |
|------|----------|-------------------------------------|
| [cJSON](https://github.com/DaveGamble/cJSON), [yyjson](https://github.com/ibireme/yyjson), [jansson](https://github.com/akheron/jansson), [parson](https://github.com/kgabis/parson), [json-c](https://github.com/json-c/json-c) | JSON | Library DOM build + print / parse via visitor ops |
| [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_custom_binary.c) | Binary | Suite length-prefixed V2 baseline (`bin_write_fixture` / `bin_read_fixture`) |
| [flatcc](https://github.com/dvidelabs/flatcc), [avro-c](https://github.com/apache/avro) | Schema | Real flatcc builder / avro-c iface write-read wrapping V2 payload bytes |
| [libbson](https://github.com/mongodb/mongo-c-driver) | Binary | `bson_append_*` / `bson_iter_*` via visitor ops |
| [mpack](https://github.com/ludocode/mpack), [msgpack-c](https://github.com/msgpack/msgpack-c) | Binary | Fixed-buffer map pack + tree/object unpack via visitor ops |
| [nanopb](https://github.com/nanopb/nanopb), [protobuf-c](https://github.com/protobuf-c/protobuf-c), [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_upb.c) | Schema | Shared in-tree **proto3 wire** for V2 (`fixture_pb_v2.h`, same field tags as `schemas/v2/protobuf/benchmark_v2.proto`). Log names stay separate for historical comparison; **not** full nanopb stream codegen, protoc-gen-c descriptors, or Google upb. |
| [**protobuf**](https://github.com/protocolbuffers/protobuf) | Schema | **Google libprotobuf** `SerializeToArray` / `ParseFromArray` on generated `benchmark_v2.proto` messages |
| [tinycbor](https://github.com/intel/tinycbor), [libcbor](https://github.com/PJK/libcbor), [libcbor-stream](https://github.com/PJK/libcbor), [qcbor](https://github.com/laurencelundblade/QCBOR), [zcbor](https://github.com/NordicSemiconductor/zcbor) | Binary/schema | Native CBOR map encode via visitor ops (`libcbor` = DOM API, `libcbor-stream` = streaming `cbor_encode_*`); decode via each library's native walker (tinycbor buffer walker, libcbor `cbor_load`). Do not read `libcbor-stream` deserialize as a streaming decoder. |
| [ubj](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_ubj.c) | Binary | In-tree UBJSON markers around suite V2 binary payload (`bin_*`) |
| [libyaml](https://github.com/yaml/libyaml) | Text | Official C YAML 1.1 emitter/parser (`yaml_emitter_*` / `yaml_parser_*`) |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [cJSON](https://github.com/DaveGamble/cJSON) · `1.7.19`

cJSON was written as an ultralightweight JSON parser in ANSI C for embedded and application code that could not afford a heavy toolkit. The problem was that existing C JSON stacks pulled large dependencies or a C++ runtime. cJSON solves that with a single-file DOM: parse to a tree of `cJSON` nodes, mutate, and print.

#### [yyjson](https://github.com/ibireme/yyjson) · `0.10.0`

yyjson was written for high-performance JSON in ANSI C: fast parse and print without giving up a usable DOM. The problem was that lightweight C parsers were slow, and fast parsers were often C++ or SAX-only. yyjson solves that with a compact C implementation and mutable/immutable document APIs.

#### [jansson](https://github.com/akheron/jansson) · `2.15.1`

Jansson was created to give C a complete, documented JSON library with a stable API — encode, decode, and manipulate values — not just a minimal parser. The problem was that many C JSON snippets were incomplete or awkward to embed. Jansson solves it with a reference-counted value type and an API aimed at RFC 8259.

#### [parson](https://github.com/kgabis/parson) · `1.5.3`

Parson was written as a small, single-file JSON library in C that is easy to drop into a project. The problem was boilerplate-heavy C JSON stacks. Parson solves it with a compact DOM around json.org JSON.

#### [json-c](https://github.com/json-c/json-c) · `0.15`

json-c is a long-running C implementation of JSON intended to be the practical library for Unix/C programs. The problem was the lack of a maintained, RFC-oriented JSON C library for system software. It solves that with a C API that aims at RFC 8259.

#### [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_custom_binary.c) · `v2-1.0`

This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.

#### [flatcc](https://github.com/dvidelabs/flatcc) · `0.6.3`

flatcc is the maintained C implementation of FlatBuffers. FlatBuffers was created at Google so games and other clients could read serialized data without a parsing/unpacking step. flatcc solves the C side with a schema compiler and a C builder/reader.

#### [avro-c](https://github.com/apache/avro) · `1.11.3`

Apache Avro was created for Hadoop-era data: a compact binary encoding with the schema stored out of band so field names are not repeated. avro-c is the official C implementation of that encoding.

#### [libbson](https://github.com/mongodb/mongo-c-driver) · `1.27.5`

libbson is MongoDB's C library for building and iterating BSON documents. BSON exists so MongoDB can store JSON-like documents with a binary, traversable layout. libbson solves that with `bson_append_*` / `bson_iter_*`.

#### [mpack](https://github.com/ludocode/mpack) · `1.1.1`

MPack is a C encoder/decoder for MessagePack, aimed at correctness and a clean buffer/stream API. The problem was that C MessagePack options were either incomplete or awkward to embed. MPack solves it with a documented pack/unpack implementation of the MessagePack spec.

#### [msgpack-c](https://github.com/msgpack/msgpack-c) · `6.0.1`

msgpack-c is the official C/C++ implementation of MessagePack. MessagePack was created to be as small and fast as a binary format while staying as simple as JSON. The C library solves that with pack/unpack APIs (and a separate C++ API in the same repository).

#### [nanopb](https://github.com/nanopb/nanopb) · `0.4.9.2`

nanopb was written so Protocol Buffers could run on microcontrollers. The problem was that Google's C++ protobuf runtime is far too large for tiny devices. nanopb solves it with a small C implementation and a generator aimed at static allocation.

#### [protobuf-c](https://github.com/protobuf-c/protobuf-c) · `1.5.2`

protobuf-c provides C bindings for Google Protocol Buffers. The problem was that official protobuf was C++-first. protobuf-c solves it with `protoc-gen-c` and a C runtime for the same wire format.

#### [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_upb.c) · `wire-v2`

This row is the suite's in-tree proto3 tag reader/writer. It exists to measure the published Protocol Buffers encoding itself, without a particular vendor runtime. Field numbers match `schemas/v2/protobuf/benchmark_v2.proto`.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `3.12.4`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [tinycbor](https://github.com/intel/tinycbor) · `0.6.0`

Intel TinyCBOR was written so constrained and systems software could speak IETF CBOR (RFC 7049 / 8949). The problem was that CBOR needed a small, well-specified C encoder/decoder. TinyCBOR solves it with a buffer-oriented C API.

#### [libcbor](https://github.com/PJK/libcbor) · `0.11.0`

libcbor is a CBOR protocol implementation for C targeting RFC 7049 and RFC 8949. The problem was the need for a full-featured C CBOR DOM and streaming encoder. It solves that with `cbor_load` for documents and `cbor_encode_*` for streaming.

#### [libcbor-stream](https://github.com/PJK/libcbor) · `0.11.0`

libcbor is a CBOR protocol implementation for C targeting RFC 7049 and RFC 8949. The problem was the need for a full-featured C CBOR DOM and streaming encoder. It solves that with `cbor_load` for documents and `cbor_encode_*` for streaming. This row times libcbor's streaming `cbor_encode_*` API, not the DOM `cbor_load` decoder.

#### [qcbor](https://github.com/laurencelundblade/QCBOR) · `1.6.1`

QCBOR was written as a comprehensive, safety-oriented CBOR implementation for professional and embedded use (RFC 8949). The problem was that CBOR stacks were either incomplete or hard to audit. QCBOR solves it with a carefully bounded C encoder/decoder.

#### [zcbor](https://github.com/NordicSemiconductor/zcbor) · `0.9`

Nordic zcbor was created to generate C from CDDL and to encode/decode CBOR on constrained devices. The problem was writing CBOR by hand against a schema. zcbor solves it with a CBOR codec plus a CDDL code generator.

#### [ubj](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/ser_ubj.c) · `1.0-min`

This row is the suite's in-tree UBJSON marker codec around the V2 binary payload. UBJSON was created as a binary cousin of JSON with explicit types. The harness implements the markers so C has a UBJSON size/speed point without a third-party dependency.

#### [libyaml](https://github.com/yaml/libyaml) · `0.2.5`

libyaml is the official C library for YAML 1.1, written so other languages (PyYAML, Yams, ext-yaml) can share one parser/emitter. YAML exists as a human-friendly config language. This row times the C library directly.

### Caveats

- **Visitor (map codecs):** JSON / MessagePack / CBOR / BSON serializers only implement library primitives; field layout lives in `v2_codec.c`.
- **Protobuf family honesty:** the official **Google** row is `protobuf` (libprotobuf + sysroot). `nanopb` / `protobuf-c` / `protobuf-wire` currently time the shared `fixture_pb_v2` wire codec (domain encode/decode), not each library’s full generated-message stack. Do not read those three as “full library codegen benchmarks.”
- **Payload-wrapped:** `ubj`, `flatcc`, and `avro-c` keep kind + binary payload (or builder vector) without full multi-type schema codegen.
- **Symbol prefixing:** `parson` and `tinycbor` are linked with renamed symbols so they co-exist with `jansson` and `libcbor`.
- A serializer is registered only when its library is linked (CMake configure log `serializer: … REAL`).

### Stream honesty

Stream mode uses an in-memory `FILE*` (`fmemopen`) wrapper around full encode/decode buffers — **`StreamMode=adapted`** for every stream row. It is not a per-library incremental stream API. See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=c&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

