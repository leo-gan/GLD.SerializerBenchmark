# Serialization categories

This page introduces the families this suite uses when grouping serializers, a short decision sketch, and **examples from the suite** by family. Columnar is defined here. Its serializer rows are added by later language PRs.

Theory pages cover product trade-offs in more depth. Language **Overview** pages list every registered library name and caveats.

| If you need… | Go here |
|--------------|---------|
| Conceptual trade-offs (product / theory) | [Theory — engineering](../theory/101/engineer_perspective.md) · [101 home](../theory/101/index.md) |
| Full registered names and caveats | Language **Overview** pages |
| Timings and plots | [Dashboard](../dashboard/) |

---

## Learning goals

By the end of this page you should be able to:

1. Name the families and one real example of each registered family.
2. Decide which family fits a simple product question (public API, schema contract, same-process cache, columnar scan, …).
3. State the comparison rule: **same language + same family + same data type** before crowning a winner.

**Rule of thumb:** compare serializers **within the same paradigm** and **within one language**. Cross-language and cross-paradigm “winners” are not interchangeable. Columnar numbers on `table` are a different question from JSON numbers on `message`.

Registered counts live on each language Overview page. This page does not repeat them.

---

## The families

These rows are orientation only—not a leaderboard. Real speed and size depend on implementation and payload.

| Family | Schema on the wire | Human-readable | Typical size | Typical speed | Cross-language | Often used for |
|--------|--------------------|----------------|--------------|---------------|----------------|----------------|
| **JSON** (text) | Optional / external | Yes | Larger | Medium | Universal | Public APIs, configs |
| **Schemaless binary** | Type tags / field names often present | No | Smaller than JSON | Often faster than text JSON | Wide / growing | Internal services, caches |
| **Schema-driven** | Numbers / layout from schema or IDL | No | Often smallest | Often fastest deserialize | Where codegen exists | Stable contracts, streams |
| **Language-native** | Runtime type metadata | No | Medium | Varies | Usually one runtime | Same-stack caches / graphs |
| **Columnar** | Table schema, often a footer or IPC schema | No | Depends on encoding and compression | Scan of few columns over many rows | Where the library can write the format | Lakes, notebooks, feature batches |

Some benchmark-runner entries (C# **XML** / **YAML** / **CSV**, and similar) sit outside a pure four-box split. Treat them as adjacent text or specialized formats and use the language Overview category column.

---

## Decision sketch

Work through these questions in order:

1. **Do people need to read or edit the payload?**
   - **Yes** → JSON family (or other text formats where registered).
   - **No** → continue.
2. **Do you need a shared schema / IDL and evolution rules?**
   - **Yes** → Schema-driven.
   - **No** → continue.
3. **Single language / runtime, complex graphs, and fully trusted data?**
   - **Yes** → Language-native (only inside a hard trust boundary).
   - **No** → Schemaless binary.

Product-oriented guidance: [engineering perspective](../theory/101/engineer_perspective.md).

---

## Family notes (suite-focused)

Examples use **log `SerializerName` values** from language overviews (not always the same as package names on PyPI or crates.io).

### JSON (text)

- **Prefer when:** public APIs, human-edited config, multi-vendor clients without an interface description language (IDL).
- **Trade-offs:** readable; larger payloads; performance varies sharply by implementation.
- **Examples in suite:**
  - **C#:** `Json.Net`, `Json.Net (Helper)`, `System.Text.Json`, `ShapeShift.Json`, `SpanJson`, `Utf8Json`, `NetJSON`, `ServiceStack Json`, …
  - **Python:** `json`, `orjson`, `msgspec`, `rapidjson`, `pydantic`, `mashumaro`, `serpyco-rs`
  - **Rust:** `serde_json`, `simd-json`, `sonic-rs`
  - **C:** `cJSON`, `yyjson`, `jansson`, `parson`, `json-c`
  - **JavaScript:** `JSON.stringify`, `fast-json-stringify`, `simdjson` (optional native)
  - **Go:** `encoding/json`, `encoding/json/v2`, `sonic`, `goccy/go-json`, `jsoniter`, `segmentio/encoding/json`, `ugorji/json`
  - **Go (adjacent text):** `goccy/go-yaml`, `pelletier/go-toml` (human-readable documents; not JSON wire)
  - **Java:** `jackson`, `gson`, `fastjson2`, `dsl-json`, `moshi`, `jsoniter`
  - **C++:** `nlohmann_json`, `rapidjson`, `simdjson`, `arduinojson`, `yyjson`, `glaze`

### Schemaless binary

- **Prefer when:** internal services, caches and queues, JSON-like flexibility without text parse cost.
- **Trade-offs:** not human-readable; evolution is ad hoc unless you add conventions.
- **Examples in suite:**
  - **Python:** `msgpack`, `msgspec-msgpack`, `cbor2`, `amazon-ion`
  - **Rust:** `rmp-serde`, `ciborium`, `minicbor`, `bson`, `bincode`, `postcard`, `bitcode`, `nanoserde`, `speedy`, `flexbuffers`, `ion-rs`
  - **C:** `mpack`, `msgpack-c`, `tinycbor`, `libcbor`, `libcbor-stream`, `qcbor`, `ubj`, `libbson`, `custom-binary`, `ion-c`
  - **JavaScript:** `msgpackr`, `@msgpack/msgpack`, `json-pack-msgpack`, `cbor-x`, `cbor`, `bson`, `bser`, `sia`, `ion-js`
  - **Go:** `vmihailenco/msgpack`, `shamaton/msgpack`, `ugorji/msgpack`, `fxamacker/cbor`, `ugorji/cbor`, `kelindar/binary`, `mongo-bson`, `ion-go`
  - **Java:** `kryo`, `fory`, `protostuff`, `hessian`, `msgpack`, `jackson-cbor`, `jackson-smile`, `ion`, `bson`
  - **C++:** `msgpack`, `nlohmann_*`, `cereal`, `bitsery`, `zpp_bits`, `yas`, `cista`, `boost_serialization`, `jsoncons_*`, `custom_binary`
  - **C#:** many binary graph/type serializers (`Ceras`, `Hyperion`, `BinaryPack`, `MemoryPack`, `Amazon.IonDotnet`, …)—portability and trust model vary; see the [C# overview](../c-sharp/index.md). **MessagePack-CSharp is registered** (`ContractlessStandardResolver`).

### Schema-driven

- **Prefer when:** stable contracts, evolution rules, multi-platform code generation, high-throughput streams.
- **Trade-offs:** schema and tooling cost.

| Concern | Protobuf-like | Avro-like | FlatBuffers-like |
|---------|---------------|-----------|------------------|
| Schema location | Separate IDL | Often with data / registry | Separate IDL |
| Code generation | Common | Optional / dynamic | Common |
| Zero-copy access | Usually no | Usually no | Design goal |
| Typical niche | Microservices | Data platforms | Games / realtime, and word-aligned records such as SBE |

- **Examples in suite:**
  - **C#:** `ProtoBuf` (protobuf-net), `Google.Protobuf`, `Apache.Avro`, `LightProto`, `MS Bond Fast` / `Compact`, `FlatSharp`, `ZeroFormatter`, `MemoryPack` (model/generator path)
  - **Python:** `protobuf`, `avro` (fastavro), `flatbuffers`
  - **Rust:** `prost` (shared `.proto`), `serde_avro_fast` (Avro; not official `apache-avro` — see inventory), `sbe`, `rkyv` (timed deserialize **materializes** owned values), `flexbuffers` (`flexbuffers` and `rkyv` are not the columnar zero-copy peer)
  - **C:** `protobuf` (Google libprotobuf), `nanopb`, `protobuf-c`, `protobuf-wire` (in-tree), `flatcc`, `avro-c`, `zcbor`
  - **JavaScript:** `avsc`, `protobufjs`, `protobuf-es`, `google-protobuf`, `flatbuffers`, `flexbuffers`, `bebop`
  - **Go:** `protobuf`, `hamba/avro`, `linkedin/goavro`, `sbe`
  - **Java:** `protobuf`, `avro`, `sbe`
  - **C++:** `protobuf` (libprotobuf), `protobuf-wire` (in-tree), `avro`/`avro_c`, `thrift`, `capnproto`, `flatbuffers`, `flexbuffers`, `sbe`
  - **Zig:** `protobuf` (Arwalk/zig-protobuf from the shared `.proto`), `flatbuffers` (nDimensional/zig-flatbuffers from the shared `.fbs`), `capnproto` (official C++ runtime from the shared `.capnp`)

SBE (Simple Binary Encoding) sits in this family, next to FlatBuffers-like codecs: the body is word-aligned, and variable-length data is only at the end of a message or repeating group. C++ and Rust register `sbe` (sbe-tool 1.40.2 flyweights) for `signal`, `table`, and `table_project`. The wide `table` row is a legal SBE body because its strings are variable data at the end. `nested_table` is not. The signal wire order is fixed fields, then the `legs` group, then `symbol` and `venue`. 

### Columnar

- **Prefer when:** the unit of work is many rows and a few columns. Arrow IPC is the in-memory interchange. Parquet and ORC are the on-disk columnar files.
- **Trade-offs:** a one-row batch pays header and alignment cost. A full materialization back into row objects hides the scan benefit. Compare `table_project` deserialize when the question is “read one column.”
- **Suite types:** `table`, `table_project`, `nested_table`. Run config: `config/library/columnar.yaml`. The allow-list is the new rows plus a few existing peers. Other serializers stay on the five publication types.
- **Examples in suite:**
  - **Python:** `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed` (`pyarrow`). `parquet` uses pyarrow's default page compression (Snappy). `parquet-uncompressed` sets `compression="NONE"`. `orc` calls `pyarrow.orc.write_table` with no compression argument, which is uncompressed on pyarrow 25. `orc-uncompressed` passes that same uncompressed codec so the name still exists.
  - **Go:** `arrow-ipc`, `parquet`, `parquet-uncompressed` (`arrow-go` 18.8.0). arrow-go's writer default is uncompressed, so `parquet` sets Snappy and `parquet-uncompressed` leaves compression off. IPC `table_project` reads the `f_float_0` value buffer; that reader has no included-fields option. No ORC.
  - **JavaScript:** `arrow-ipc` (`apache-arrow` 21.2.0), `parquet`, `parquet-uncompressed` (`hyparquet-writer` 0.16.10, reader `hyparquet` 1.31.2). `parquet` is Snappy. `parquet-uncompressed` sets codec `UNCOMPRESSED`. `nested_table` round-tripped, which is why Parquet is registered. No SBE and no ORC.
  - **C++:** `arrow-ipc`, `parquet`, `parquet-uncompressed`, `orc`, `orc-uncompressed` (Arrow C++ 25.0.1, only when `ARROW_ROOT` is set). Writer defaults on this build are UNCOMPRESSED, so `parquet` sets Snappy and `orc` sets `Compression::GZIP` (the adapter stores that as ORC ZLIB). The uncompressed twins set the codec off. IPC `table_project` uses `included_fields`.
  - **Rust:** `arrow-ipc`, `parquet`, `parquet-uncompressed` (arrow-rs 60.0.0). `DEFAULT_COMPRESSION` is UNCOMPRESSED, so `parquet` sets Snappy. No ORC.
  - **C#:** `arrow-ipc` (Apache.Arrow 23.0.0; the net10.0 project consumes the net8.0 asset), `parquet`, `parquet-uncompressed` (Parquet.Net 6.1.0, Snappy vs `CompressionMethod.None`). The timed path is the existing string path (Base64). No ORC. No SBE.
  - **Java:** `arrow-ipc` (arrow-vector 19.0.0), `parquet`, `parquet-uncompressed` (parquet-avro 1.18.1). parquet-java defaults to UNCOMPRESSED, so `parquet` sets Snappy. `orc` is orc-core 2.3.1 `nohive`, whose default is ZSTD; `orc-uncompressed` sets `CompressionKind.NONE`. Both ORC rows set `blockPadding(false)`.
  - **Kotlin:** the same jars as Java: `arrow-ipc` (arrow-vector 19.0.0), `parquet`, `parquet-uncompressed` (parquet-avro 1.18.1, Snappy versus UNCOMPRESSED), `orc`, `orc-uncompressed` (orc-core 2.3.1 `nohive` plus orc-format 1.1.1 `nohive`, ZSTD versus `CompressionKind.NONE`, `blockPadding(false)`).

### Language-native

- **Prefer when:** single-runtime caches and rich graphs inside a **hard trust boundary**.
- **Trade-offs:** poor portability; **unsafe** on untrusted input where formats can execute code.
- **Examples in suite:**
  - **Python:** `pickle`, `cloudpickle`, `dill`
  - **JavaScript:** `v8-serializer`, `devalue`
  - **Go:** `encoding/gob`
  - **Java:** `java-serialization`
  - **C#:** legacy / graph-oriented binaries (for example `MS Binary`)—see Overview
  - **Rust / C:** no pickle-equivalent native graph codec; use language-native stacks only where listed above

---

## Reading results fairly

- Default comparison: **same language + same family + same data type + same mode**.
- Schema-driven formats often lead on size and throughput *within a language*—that is not a universal ranking.
- **C** uses real library APIs when dependencies are built (`fetch-and-build-deps.sh`); read the [C Overview](../c/index.md) for visitor domain shape, `protobuf-wire` (in-tree, not Google upb), and payload-wrapped rows (`ubj`, flatcc, avro-c).
- Metrics live on the [Dashboard](../dashboard/), not on this page.

## Further reading

- [JSON](https://www.json.org/) · [MessagePack](https://msgpack.org/) · [CBOR RFC 8949](https://www.rfc-editor.org/rfc/rfc8949.html)
- [Protocol Buffers](https://protobuf.dev/) · [Apache Avro](https://avro.apache.org/) · [FlatBuffers](https://flatbuffers.dev/) · [SBE](https://github.com/aeron-io/simple-binary-encoding)
- [Apache Arrow](https://arrow.apache.org/) · [Apache Parquet](https://parquet.apache.org/) · [Apache ORC](https://orc.apache.org/)
- [Theory 101](../theory/101/index.md)
