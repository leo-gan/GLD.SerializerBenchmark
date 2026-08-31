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
| cJSON, yyjson, jansson, parson, json-c | JSON | Library DOM build + print / parse via visitor ops |
| custom-binary | Binary | Suite length-prefixed V2 baseline (`bin_write_fixture` / `bin_read_fixture`) |
| flatcc, avro-c | Schema | Real flatcc builder / avro-c iface write-read wrapping V2 payload bytes |
| libbson | Binary | `bson_append_*` / `bson_iter_*` via visitor ops |
| mpack, msgpack-c | Binary | Fixed-buffer map pack + tree/object unpack via visitor ops |
| nanopb, protobuf-c, protobuf-wire | Schema | Shared in-tree **proto3 wire** for V2 (`fixture_pb_v2.h`, same field tags as `schemas/v2/protobuf/benchmark_v2.proto`). Log names stay separate for historical comparison; **not** full nanopb stream codegen, protoc-gen-c descriptors, or Google upb. |
| **protobuf** | Schema | **Google libprotobuf** `SerializeToArray` / `ParseFromArray` on generated `benchmark_v2.proto` messages |
| tinycbor, libcbor, libcbor-stream, qcbor, zcbor | Binary/schema | Native CBOR map encode via visitor ops (`libcbor` = DOM API, `libcbor-stream` = streaming `cbor_encode_*`); decode via each library's native walker (tinycbor buffer walker, libcbor `cbor_load`). Do not read `libcbor-stream` deserialize as a streaming decoder. |
| ubj | Binary | In-tree UBJSON markers around suite V2 binary payload (`bin_*`) |

Pins: [`c/third_party/VERSIONS.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/c/third_party/VERSIONS.md).

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

