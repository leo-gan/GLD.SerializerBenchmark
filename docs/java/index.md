---
title: "Java"
---

# Java

Java serialization spans mature JSON mappers (`Jackson`, `Gson`, `Fastjson2`, `DSL-JSON`, `Moshi`, `jsoniter`), high-throughput JVM object-graph binaries (`Kryo`, `Apache Fory`, `Protostuff`, `Hessian2`, `java.io`), portable binary standards (`MessagePack`, `CBOR`, `Smile`, `Ion`, `BSON`, `Kiln`), IDL runtimes (`Protocol Buffers`, `Avro`, `FlatBuffers`, `Cap'n Proto`, `SBE`), and Apache columnar engines (`Arrow IPC`, `Parquet`, `ORC`).

## Runtime & Environment

The Java runner compiles to Java 21 bytecode (`maven.compiler.release=21`) and executes on the HotSpot JVM, which interprets cold bytecode before JIT-compiling hot paths into native machine code and managing heap memory with a tracing garbage collector. Early repetitions reflect JIT compilation overhead (repetition 0 is excluded by analysis), while steady-state latency depends heavily on object allocation rates and mapper/buffer reuse (see [Latency tails and GC](../theory/301/latency-tails-and-gc.md)). The language and VM are specified by the [Java Language Specification (SE 21)](https://docs.oracle.com/javase/specs/jls/se21/html/index.html) and the [Java Virtual Machine Specification (SE 21)](https://docs.oracle.com/javase/specs/jvms/se21/html/index.html).

| Property | Configuration |
|---|---|
| Language / spec | Java SE 21 (JLS 21 / JVMS 21) |
| Build & toolchain | JDK 21+ (Temurin 21 via install script) and Maven 3.9+ (`mvn package`) |
| Memory model | HotSpot JVM generational tracing garbage collector |
| Runner & logs | `java/scripts/run-benchmarks.sh` → `logs/java/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`java/src/main/java/benchmark/serializers/Registry.java`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/java/src/main/java/benchmark/serializers/Registry.java) |
| Data sets | `suite`, `columnar`, `tensor` |

## Registered Serializers

Shared domain classes under `benchmark.model.v2` expose public fields for reflection-based codecs; schemas, mappers, buffers, and Fory type registrations are prepared outside the timed loop.

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arrow-ipc](https://arrow.apache.org/docs/java/) | `arrow` | `columnar` | `adapted` | `arrow-vector` `ArrowStreamWriter`; batch built in `serializeBytes`; `table_project` loads `f_float_0` only |
| [avro](https://github.com/apache/avro) | `avro` | `suite`, `columnar` | `native` | Official `ReflectDatumWriter` / `ReflectDatumReader` with reused encoder and cached schema |
| [bson](https://github.com/mongodb/mongo-java-driver) | `bson` | `suite` | `adapted` | `org.mongodb:bson` `DocumentCodec`; domain→`Document` in untimed `prepare` |
| [capnproto](https://github.com/capnproto/capnproto-java) | `capnp` | `suite` | `adapted` | `capnproto-java` message builder/reader |
| [dsl-json](https://github.com/ngs-doo/dsl-json) | `json` | `suite` | `native` | Runtime `DslJson` with reused `JsonWriter` buffer |
| [fastjson2](https://github.com/alibaba/fastjson2) | `json` | `suite` | `adapted` | `FieldBased` API (`toJSONBytes` / `parseObject`) |
| [flatbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite`, `columnar` | `adapted` | `FlatBufferBuilder` on generated suite tables; columnar tables built in Java |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | Apache Fory binary (`fory-core`), types registered before timing |
| [fory-json](https://fory.apache.org/docs/json/getting-started) | `json` | `suite` (optional) | `adapted` | Apache Fory JSON (`org.apache.fory:fory-json`) `ForyJson.toJsonBytes` / `fromJson` |
| [gld-kiln](https://github.com/leo-gan/gld-kiln-java) | `kiln` | `suite`, `tensor` | `adapted` | `gld-kiln-java` 0.2.0 `Kiln.encodeTo` / `decode` into reused buffer; `tensor_view` borrows payload |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar`, `tensor` | `adapted` | Pure x86-64 Assembly Kiln Wire Format v2 (shared JNI `libkiln_asm_jni.so`); `KILN_OPT_EMBEDDED` `table_project`, zero-copy `tensor_view` |
| [gson](https://github.com/google/gson) | `json` | `suite` | `native` | `Gson` with `disableHtmlEscaping`; `JsonWriter` / `JsonReader` on stream |
| [hessian](https://github.com/ebourg/hessian) | `custom` | `suite` | `native` | `Hessian2` `writeObject` / `readObject` |
| [ion](https://github.com/amazon-ion/ion-java) | `ion` | `suite` | `native` | `jackson-dataformat-ion` `IonObjectMapper` (Amazon Ion binary) |
| [jackson](https://github.com/FasterXML/jackson-databind) | `json` | `suite`, `columnar` | `native` | Reused `ObjectMapper` / `ObjectWriter` / `ObjectReader` (compact output) |
| [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary) | `cbor` | `suite` | `native` | `jackson-dataformat-cbor` `CBORMapper` |
| [jackson-smile](https://github.com/FasterXML/jackson-dataformats-binary) | `smile` | `suite` | `native` | `jackson-dataformat-smile` `SmileMapper` |
| [jackson-yaml](https://github.com/FasterXML/jackson-dataformats-text) | `yaml` | `suite` | `native` | `jackson-dataformat-yaml` `YAMLFactory` |
| [java-serialization](https://github.com/openjdk/jdk) | `custom` | `suite` | `native` | JDK `ObjectOutputStream` / `ObjectInputStream` (JVM baseline; unsafe on untrusted bytes) |
| [json-io](https://github.com/jdereg/json-io) | `toon` | `suite` | `adapted` | `toToon` / `fromToon` (`strictToon` on); `toDomain` untimed; size in UTF-8 bytes |
| [jsoniter](https://github.com/json-iterator/java) | `json` | `suite` | `adapted` | `DYNAMIC` codegen mode with `javassist` (`JsonStream` / `JsonIterator`) |
| [jtoon](https://github.com/toon-format/toon-java) | `toon` | `suite` | `adapted` | Official Java TOON codec; decode returns JSON tree (`toDomain` untimed); size in UTF-8 bytes |
| [kryo](https://github.com/EsotericSoftware/kryo) | `custom` | `suite` | `native` | `writeClassAndObject` / `readClassAndObject` with reused `Kryo`, `Output`, and `Input` |
| [moshi](https://github.com/square/moshi) | `json` | `suite` | `native` | Square `JsonAdapter` over Okio `Buffer` |
| [msgpack](https://github.com/msgpack/msgpack-java) | `msgpack` | `suite` | `native` | Official `jackson-dataformat-msgpack` `MessagePackMapper` |
| [orc](https://orc.apache.org/specification/ORCv1/) | `orc` | `columnar` | `adapted` | `orc-core` 2.3.1 (`nohive`), default ZSTD compression, `blockPadding(false)`; `table_project` projects `f_float_0` |
| [orc-uncompressed](https://orc.apache.org/specification/ORCv1/) | `orc` | `columnar` | `adapted` | Same `orc-core` writer with `CompressionKind.NONE` and `blockPadding(false)` |
| [parquet](https://parquet.apache.org/docs/file-format/) | `parquet` | `columnar` | `adapted` | `parquet-avro` 1.18.1 `AvroParquetWriter` with explicit Snappy; `table_project` projects `f_float_0` |
| [parquet-uncompressed](https://parquet.apache.org/docs/file-format/) | `parquet` | `columnar` | `adapted` | Same `AvroParquetWriter` with `CompressionCodecName.UNCOMPRESSED` |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite`, `columnar` | `native` | Official `protobuf-java` `MessageLite`; see call-site note for boundary rule |
| [protostuff](https://github.com/protostuff/protostuff) | `custom` | `suite` | `native` | `protostuff-runtime` `RuntimeSchema` with reused `LinkedBuffer` |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | `sbe` | `columnar` | `adapted` | `sbe-tool` 1.40.2 + Agrona flyweight filled in `serializeBytes`; `nested_table` unsupported |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arrow-ipc](https://arrow.apache.org/docs/java/)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This row times arrow-vector 19.0.0 ArrowStreamWriter inside the bytes API, not the Arrow file format and not arrow-dataset. The schema is built in prepare. Row-to-column conversion stays inside serializeBytes. table_project loads f_float_0 only. No compliance decoder.
    - **[avro](https://github.com/apache/avro)** — Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.
    - **[bson](https://github.com/mongodb/mongo-java-driver)** — BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.
    - **[capnproto](https://github.com/capnproto/capnproto-java)** — Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.
    - **[dsl-json](https://github.com/ngs-doo/dsl-json)** — dsl-json was written for very high-performance JSON on the JVM with compile-time binding. The problem was reflection mappers allocating too much. It reuses a JsonWriter buffer on the hot path.
    - **[fastjson2](https://github.com/alibaba/fastjson2)** — fastjson2 is Alibaba's rewrite of fastjson for high-performance JSON on the JVM. The problem was JSON cost in large Java services (and security issues in fastjson 1.x). fastjson2 solves it with a new FieldBased API.
    - **[flatbuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol.
    - **[fory-json](https://fory.apache.org/docs/json/getting-started)** — Apache Fory JSON is the JSON module (org.apache.fory:fory-json), separate from the binary fory row. This row times ForyJson.toJsonBytes and fromJson on the suite types. The stream path writes the same UTF-8 document.
    - **[gld-kiln](https://github.com/leo-gan/gld-kiln-java)** — gld-kiln (leo-gan) is a positional little-endian codec. The timed path reuses one writer. There are no field tags on the wire. This row times encode and decode of the suite structs. On the tensor data set this row runs every type. tensor_view borrows the float32 payload and does not copy the matrix.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) bound via shared `libkiln_asm_jni.so` (statically linking `libkiln_asm_bench.a`). Covers `suite`, `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`), and `tensor` (KLNT v2 with zero-copy `tensor_view`).
    - **[gson](https://github.com/google/gson)** — Gson was created at Google to convert Java objects to JSON and back with a simple API. The problem was boilerplate-heavy Java JSON. Gson solves it with reflection over POJOs and a JsonWriter/Reader stream API.
    - **[hessian](https://github.com/ebourg/hessian)** — Hessian is Caucho's compact binary web-service protocol from the Dubbo/Caucho era. The problem was SOAP/XML RPC overhead. Hessian2 write/readObject is the binary that this row times.
    - **[ion](https://github.com/amazon-ion/ion-java)** — Amazon Ion was created as a rich, self-describing superset of JSON (text and binary) for Amazon services. Official Ion libraries and Jackson Ion modules implement that model.
    - **[jackson](https://github.com/FasterXML/jackson-databind)**, **[jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary)**, **[jackson-smile](https://github.com/FasterXML/jackson-dataformats-binary)**, **[jackson-yaml](https://github.com/FasterXML/jackson-dataformats-text)** — Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack).
        - `jackson-cbor`: This row times Jackson's CBOR mapper.
        - `jackson-smile`: This row times Jackson's Smile (binary JSON) mapper.
        - `jackson-yaml`: This row times Jackson's YAML mapper.
    - **[java-serialization](https://github.com/openjdk/jdk)** — Java Object Serialization (`ObjectOutputStream`) is the language's built-in graph serializer. It exists so the JVM can persist and RMI Java objects. It is not a portable wire format.
    - **[json-io](https://github.com/jdereg/json-io)** — json-io writes TOON with toToon and reads it with fromToon. This row turns strictToon on. The untimed toDomain step turns the decoded tree into the suite type. The Size column is the UTF-8 byte length.
    - **[jsoniter](https://github.com/json-iterator/java)** — jsoniter for Java was created as a high-performance JSON library with an optional codegen path. The problem was Jackson/Gson overhead. This suite uses DYNAMIC mode plus javassist.
    - **[jtoon](https://github.com/toon-format/toon-java)** — jtoon is the official Java codec for TOON. JToon.encode writes the text. JToon.decode returns a JSON tree, and the untimed toDomain step turns that tree into the suite type. The Size column is the UTF-8 byte length.
    - **[kryo](https://github.com/EsotericSoftware/kryo)** — Kryo was written as a fast binary serializer for JVM object graphs (games, caches, RPC). The problem was Java serialization being slow and verbose. Kryo solves it with a compact binary and reusable Output/Input.
    - **[moshi](https://github.com/square/moshi)** — Moshi was created at Square as a modern JSON library for Java and Android, successor-minded to Gson. The problem was Gson's older model on Android. Moshi solves it with JsonAdapter, codegen or reflection, and Okio.
    - **[msgpack](https://github.com/msgpack/msgpack-java)** — msgpack-java is the official MessagePack library for the JVM. MessagePack exists as compact binary JSON. This suite times the Jackson MessagePack mapper on that stack.
    - **[orc](https://orc.apache.org/specification/ORCv1/)** — Apache ORC was created as a columnar file with stripe indexes for scans. This row times orc-core 2.3.1 (classifier nohive). OrcConf.COMPRESS defaults to ZSTD, so orc does not call compress(). orc-uncompressed sets CompressionKind.NONE. Both rows set blockPadding(false) so a small file is not padded toward the 256MB HDFS block. table_project includes f_float_0 only. No compliance decoder.
    - **[orc-uncompressed](https://orc.apache.org/specification/ORCv1/)** — This is the same orc-core writer as orc, with CompressionKind.NONE and blockPadding(false). The name is the override. No compliance decoder.
    - **[parquet](https://parquet.apache.org/docs/file-format/)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This row times parquet-avro 1.18.1 AvroParquetWriter. parquet-java's default codec is UNCOMPRESSED, so this row sets CompressionCodecName.SNAPPY. table_project sets AvroReadSupport requested projection to f_float_0. No compliance decoder.
    - **[parquet-uncompressed](https://parquet.apache.org/docs/file-format/)** — This is the same parquet-avro writer as parquet, with CompressionCodecName.UNCOMPRESSED. The name is the override. No compliance decoder.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
    - **[protostuff](https://github.com/protostuff/protostuff)** — protostuff was created to serialize Java objects with protobuf-like efficiency without writing `.proto` files. The problem was protobuf's IDL tax for internal graphs. Runtime schemas and LinkedBuffer reuse are the solution this row times.
    - **[sbe](https://github.com/aeron-io/simple-binary-encoding)** — SBE (Simple Binary Encoding) was created for word-aligned financial messages: a fixed block, then repeating groups, then variable-length data. The problem was tag/length codecs that touch every field on the hot path. This row fills the sbe-tool 1.40.2 Java flyweight inside serializeBytes. Agrona is the runtime. The generator jar is sbe-all, copied from Maven at build time. It encodes table, table_project, and signal. nested_table is not an SBE body. The signal wire order is fixed fields, then the legs group, then symbol and venue. No compliance decoder.

## Measurement Caveats

- **JVM-only wire formats:** `java-serialization`, `kryo`, `fory`, `hessian`, and `protostuff` serialize JVM object graphs and are not portable cross-language wire standards.
- **Columnar and SBE rules:** `arrow-ipc`, `parquet*`, `orc*`, and `sbe` support only the `columnar` data set (`sbe` omits `nested_table`), build columnar/flyweight layouts inside timed `serializeBytes` ([Timing contract rule 8](../analysis/TIMING_HONESTY.md)), and expose adapted stream paths only. Both ORC rows set `blockPadding(false)` to avoid 256 MiB HDFS block padding and use `nohive` artifacts (`orc-core` + `orc-format` 1.1.1) so shaded protobuf does not conflict with `com.google.protobuf`. `parquet-java` 1.18.1 defaults to `UNCOMPRESSED`, so `parquet` explicitly sets `SNAPPY`; ORC 2.3.1 defaults to `ZSTD`.
- **Floating-point rounding:** Some JSON libraries (such as `jsoniter`) shorten decimal digits; fidelity checks apply numeric tolerance rather than string equality.
- **Separation from Kotlin:** Although Java and Kotlin execute on HotSpot JVM 21, they use separate domain models, build pipelines (Maven vs. Gradle), and adapters and must not be merged into one ranking.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Java)](../dashboard/index.html?lang=java&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Java)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Java: `Protostuff` vs. `protobuf-java`](../analysis/call-sites/java-protostuff-vs-protobuf.md)
- **Build & run guide:** [`java/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/java/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
