---
title: "C"
---

# C

C serialization is decentralized: each library defines its own memory and object model—DOM trees, streaming encoders, or generated C structs—with manual allocation and no shared runtime reflection.

## Runtime & Environment

The C runner compiles C11 source code to a native binary via CMake in the Release configuration (`gcc` or `clang`). Memory is managed explicitly by each library or by runner-owned buffers, with no virtual machine, JIT warmup, or garbage-collection pauses. Compiler selection and optimization flags (`-O`) dominate absolute throughput; Debug builds are not comparable to published Dashboard numbers. The language is specified by ISO/IEC 9899 (C11 draft [N1570](https://www.open-std.org/jtc1/sc22/wg14/www/docs/n1570.pdf); reference at [cppreference](https://en.cppreference.com/w/c)).

| Property | Configuration |
|---|---|
| Language / spec | ISO/IEC 9899 (C11); C++17 used only for Google `libprotobuf` |
| Build & toolchain | CMake Release (`gcc` / `clang`); static deps via `c/scripts/fetch-and-build-deps.sh`; Google protobuf sysroot via `cpp/scripts/setup-protobuf-sysroot.sh` |
| Memory model | Manual allocation; no garbage collector |
| Runner & logs | `c/scripts/run-benchmarks.sh` → `logs/c/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`c/src/register_serializers.c`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/register_serializers.c) |
| Data sets | `suite`, `array`, `tensor` |

## Registered Serializers

Map-oriented codecs (`JSON`, `MessagePack`, `CBOR`, `BSON`, `Ion`) share a single visitor in [`c/src/v2_codec.c`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/v2_codec.c) so adapters implement only library primitives rather than hard-coding domain graphs. A serializer registers only when CMake links its library (`serializer: … REAL`).

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [avro-c](https://github.com/apache/avro) | `avro` | `suite` | `adapted` | `avro-c` iface write/read wrapping V2 payload bytes |
| [cJSON](https://github.com/DaveGamble/cJSON) | `json` | `suite` | `adapted` | Single-file DOM build, print, and parse via visitor ops |
| [custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_custom_binary.c) | `custom` | `suite` | `adapted` | In-tree length-prefixed little-endian baseline (`bin_write_fixture` / `bin_read_fixture`) |
| [flatcc](https://github.com/dvidelabs/flatcc) | `flatbuffers` | `suite` | `adapted` | `flatcc` builder/reader wrapping V2 payload bytes |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-c) | `kiln` | `suite`, `tensor` | `adapted` | Positional `kiln_encode_buf` / `kiln_decode` on suite structs; `tensor_view` borrows payload |
| [hdf5](https://www.hdfgroup.org/solutions/hdf5/) | `hdf5` | `array` | `adapted` | Official `libhdf5` core virtual file driver; hyperslab read for `grid_window` |
| [ion-c](https://github.com/amazon-ion/ion-c) | `ion` | `suite` | `native` | Official Ion binary `ion_writer_*` / `ion_reader_*` via visitor ops; native `FILE*` stream |
| [jansson](https://github.com/akheron/jansson) | `json` | `suite` | `adapted` | Reference-counted DOM build, dump, and parse via visitor ops |
| [json-c](https://github.com/json-c/json-c) | `json` | `suite` | `adapted` | `json-c` DOM build, print, and parse via visitor ops |
| [libbson](https://github.com/mongodb/mongo-c-driver) | `bson` | `suite` | `adapted` | `bson_append_*` / `bson_iter_*` via visitor ops |
| [libcbor](https://github.com/PJK/libcbor) | `cbor` | `suite` | `adapted` | DOM build + `cbor_load` decode via visitor ops |
| [libcbor-stream](https://github.com/PJK/libcbor) | `cbor` | `suite` | `adapted` | Streaming `cbor_encode_*` encode; decode still uses DOM `cbor_load` |
| [libyaml](https://github.com/yaml/libyaml) | `yaml` | `suite` | `adapted` | Official YAML 1.1 `yaml_emitter_*` / `yaml_parser_*` |
| [mpack](https://github.com/ludocode/mpack) | `msgpack` | `suite` | `adapted` | Fixed-buffer pack and tree unpack via visitor ops |
| [msgpack-c](https://github.com/msgpack/msgpack-c) | `msgpack` | `suite` | `adapted` | Official C `msgpack_pack_*` and object unpack via visitor ops |
| [nanopb](https://github.com/nanopb/nanopb) | `protobuf` | `suite` | `adapted` | Shared in-tree proto3 wire helper (`fixture_pb_v2.h`), not full `nanopb` stream codegen |
| [parson](https://github.com/kgabis/parson) | `json` | `suite` | `adapted` | Single-file DOM build, print, and parse via visitor ops |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite` | `adapted` | Official Google `libprotobuf` `SerializeToArray` / `ParseFromArray` on `benchmark_v2.proto` |
| [protobuf-c](https://github.com/protobuf-c/protobuf-c) | `protobuf` | `suite` | `adapted` | Shared in-tree proto3 wire helper (`fixture_pb_v2.h`), not `protoc-gen-c` descriptors |
| [protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_upb.c) | `protobuf` | `suite` | `adapted` | Shared in-tree proto3 tag reader/writer baseline (`fixture_pb_v2.h`) |
| [qcbor](https://github.com/laurencelundblade/QCBOR) | `cbor` | `suite` | `adapted` | Bounded CBOR buffer encode and native walker decode via visitor ops |
| [tinycbor](https://github.com/intel/tinycbor) | `cbor` | `suite` | `adapted` | Buffer encode and native walker decode via visitor ops |
| [ubj](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_ubj.c) | `ubjson` | `suite` | `adapted` | In-tree UBJSON `{kind, payload}` envelope around `custom-binary` |
| [yyjson](https://github.com/ibireme/yyjson) | `json` | `suite` | `native` | Fast ANSI C DOM build/parse via visitor ops; native `FILE*` stream callbacks |
| [zcbor](https://github.com/NordicSemiconductor/zcbor) | `cbor` | `suite` | `adapted` | Native CBOR buffer encode/decode via visitor ops |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[avro-c](https://github.com/apache/avro)** — Apache Avro was created for Hadoop-era data: a compact binary encoding with the schema stored out of band so field names are not repeated. avro-c is the official C implementation of that encoding.
    - **[cJSON](https://github.com/DaveGamble/cJSON)** — cJSON was written as an ultralightweight JSON parser in ANSI C for embedded and application code that could not afford a heavy toolkit. The problem was that existing C JSON stacks pulled large dependencies or a C++ runtime. cJSON solves that with a single-file DOM: parse to a tree of `cJSON` nodes, mutate, and print.
    - **[custom-binary](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_custom_binary.c)** — This is the suite's length-prefixed V2 baseline, not a published format. It exists so every language has a simple binary control point: write fields with explicit lengths, read them back, no schema compiler.
    - **[flatcc](https://github.com/dvidelabs/flatcc)** — flatcc is the maintained C implementation of FlatBuffers. FlatBuffers was created at Google so games and other clients could read serialized data without a parsing/unpacking step. flatcc solves the C side with a schema compiler and a C builder/reader.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-c)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[hdf5](https://www.hdfgroup.org/solutions/hdf5/)** — The HDF5 C API is the baseline the other bindings call. This row times one contiguous float64 dataset named grid on the core virtual file driver. The byte size is the flushed file image. grid_window reads an interior hyperslab. The row does not time the five suite types.
    - **[ion-c](https://github.com/amazon-ion/ion-c)** — Amazon Ion was created at Amazon as a rich, self-describing superset of JSON (text and binary) for internal services. The problem was JSON's limited types. ion-c is the official C implementation. This row times the binary writer and reader on the suite visitor, including a native FILE* stream.
    - **[jansson](https://github.com/akheron/jansson)** — Jansson was created to give C a complete, documented JSON library with a stable API — encode, decode, and manipulate values — not just a minimal parser. The problem was that many C JSON snippets were incomplete or awkward to embed. Jansson solves it with a reference-counted value type and an API aimed at RFC 8259.
    - **[json-c](https://github.com/json-c/json-c)** — json-c is a long-running C implementation of JSON intended to be the practical library for Unix/C programs. The problem was the lack of a maintained, RFC-oriented JSON C library for system software. It solves that with a C API that aims at RFC 8259.
    - **[libbson](https://github.com/mongodb/mongo-c-driver)** — libbson is MongoDB's C library for building and iterating BSON documents. BSON exists so MongoDB can store JSON-like documents with a binary, traversable layout. libbson solves that with `bson_append_*` / `bson_iter_*`.
    - **[libcbor](https://github.com/PJK/libcbor)**, **[libcbor-stream](https://github.com/PJK/libcbor)** — libcbor is a CBOR protocol implementation for C targeting RFC 7049 and RFC 8949. The problem was the need for a full-featured C CBOR DOM and streaming encoder. It solves that with `cbor_load` for documents and `cbor_encode_*` for streaming.
        - `libcbor-stream`: This row times libcbor's streaming `cbor_encode_*` API, not the DOM `cbor_load` decoder.
    - **[libyaml](https://github.com/yaml/libyaml)** — libyaml is the official C library for YAML 1.1, written so other languages (PyYAML, Yams, ext-yaml) can share one parser/emitter. YAML exists as a human-friendly config language. This row times the C library directly.
    - **[mpack](https://github.com/ludocode/mpack)** — MPack is a C encoder/decoder for MessagePack, aimed at correctness and a clean buffer/stream API. The problem was that C MessagePack options were either incomplete or awkward to embed. MPack solves it with a documented pack/unpack implementation of the MessagePack spec.
    - **[msgpack-c](https://github.com/msgpack/msgpack-c)** — msgpack-c is the official C/C++ implementation of MessagePack. MessagePack was created to be as small and fast as a binary format while staying as simple as JSON. The C library solves that with pack/unpack APIs (and a separate C++ API in the same repository).
    - **[nanopb](https://github.com/nanopb/nanopb)** — nanopb was written so Protocol Buffers could run on microcontrollers. The problem was that Google's C++ protobuf runtime is far too large for tiny devices. nanopb solves it with a small C implementation and a generator aimed at static allocation.
    - **[parson](https://github.com/kgabis/parson)** — Parson was written as a small, single-file JSON library in C that is easy to drop into a project. The problem was boilerplate-heavy C JSON stacks. Parson solves it with a compact DOM around json.org JSON.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[protobuf-c](https://github.com/protobuf-c/protobuf-c)** — protobuf-c provides C bindings for Google Protocol Buffers. The problem was that official protobuf was C++-first. protobuf-c solves it with `protoc-gen-c` and a C runtime for the same wire format.
    - **[protobuf-wire](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_upb.c)** — This row is the suite's in-tree proto3 tag reader/writer. It exists to measure the published Protocol Buffers encoding itself, without a particular vendor runtime. Field numbers match `schemas/v2/protobuf/benchmark_v2.proto`.
    - **[qcbor](https://github.com/laurencelundblade/QCBOR)** — QCBOR was written as a comprehensive, safety-oriented CBOR implementation for professional and embedded use (RFC 8949). The problem was that CBOR stacks were either incomplete or hard to audit. QCBOR solves it with a carefully bounded C encoder/decoder.
    - **[tinycbor](https://github.com/intel/tinycbor)** — Intel TinyCBOR was written so constrained and systems software could speak IETF CBOR (RFC 7049 / 8949). The problem was that CBOR needed a small, well-specified C encoder/decoder. TinyCBOR solves it with a buffer-oriented C API.
    - **[ubj](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/src/serializers/ser_ubj.c)** — This row is the suite's in-tree UBJSON marker codec around the V2 binary payload. UBJSON was created as a binary cousin of JSON with explicit types. The harness implements the markers so C has a UBJSON size/speed point without a third-party dependency.
    - **[yyjson](https://github.com/ibireme/yyjson)** — yyjson was written for high-performance JSON in ANSI C: fast parse and print without giving up a usable DOM. The problem was that lightweight C parsers were slow, and fast parsers were often C++ or SAX-only. yyjson solves that with a compact C implementation and mutable/immutable document APIs.
    - **[zcbor](https://github.com/NordicSemiconductor/zcbor)** — Nordic zcbor was created to generate C from CDDL and to encode/decode CBOR on constrained devices. The problem was writing CBOR by hand against a schema. zcbor solves it with a CBOR codec plus a CDDL code generator.

## Measurement Caveats

- **Stream honesty:** Stream mode uses an in-memory `FILE*` (`fmemopen`). Only `ion-c` and `yyjson` bind library `FILE*` callbacks (`StreamMode=native`); all other stream rows copy an already-encoded buffer (`StreamMode=adapted`).
- **Protobuf family scope:** `protobuf` times official Google `libprotobuf` generated from `schemas/v2/protobuf/benchmark_v2.proto`. By contrast, `nanopb`, `protobuf-c`, and `protobuf-wire` currently share the in-tree `fixture_pb_v2.h` wire encoder/decoder; do not interpret them as full generated-code benchmarks of those upstream runtimes (see [4.5 C: protobuf-c](../theory/401/protobuf-c-protobuf-c.md) and [4.6 C: nanopb vs. protobuf-c](../theory/401/protobuf-c-nanopb-compare.md) for the library internals).
- **Payload-wrapped rows:** `ubj`, `flatcc`, and `avro-c` wrap the V2 binary payload inside a small envelope rather than generating full multi-type schemas.
- **Decoder caveat on `libcbor-stream`:** Only encode uses the streaming `cbor_encode_*` API; decode still calls DOM `cbor_load`.
- **Symbol prefixing:** `parson` and `tinycbor` are linked with prefixed symbols so they coexist with `jansson` and `libcbor` in one binary.
- **Separation from C++:** C and C++ runners use distinct object models and build toolchains; see [C vs. C++ separation](../cpp/index.md#c-vs-c-clear-separation).

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (C)](../dashboard/index.html?lang=c&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (C)](../dashboard/index.html#compliance)
- **Source-level analyses:** [C: `custom-binary` vs. `ubj`](../analysis/call-sites/c-custom-binary-vs-ubj.md) · [4.5 C: `protobuf-c`](../theory/401/protobuf-c-protobuf-c.md) · [4.6 C: `nanopb` vs. `protobuf-c`](../theory/401/protobuf-c-nanopb-compare.md)
- **Build & run guide:** [`c/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
