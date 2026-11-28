---
title: "Kotlin"
---

# Kotlin

Kotlin serialization on the JVM spans the compiler-plugin `kotlinx.serialization` ecosystem (`JSON`, `CBOR`, `ProtoBuf`, `Properties`, `HOCON`, `kaml`, `kbson`, `avro4k`, `obor`, `tomlkt`, `ktoon`), JVM JSON/binary libraries (`Jackson`, `Moshi` codegen vs. reflection, `Gson`, `Kryo`, `Apache Fory`, `Protostuff`), IDL runtimes (`protobuf-java`, `protobuf-kotlin`, `FlatBuffers`, `Cap'n Proto`, `Avro`, `Thrift`, `SBE`), and Apache columnar engines.

## Runtime & Environment

This runner targets **Kotlin/JVM** (not Kotlin/Native or Kotlin/JS), compiling Kotlin 2.3.20 into Java 21 bytecode executed on HotSpot with JIT compilation and generational garbage collection. Domain models in `benchmark.model.v2` are `@Serializable` data classes annotated with `@JvmField` so JVM reflection codecs (`Jackson`, `Kryo`, `Moshi`) access fields directly without synthetic getter overhead. Compile-time plugin/KSP generation (`kotlinx.serialization`, `moshi-codegen`) eliminates reflection dispatch compared to runtime-reflection peers (`moshi-reflect`). Language and bytecode semantics are specified by the [Kotlin Language Specification](https://kotlinlang.org/spec/) and the [JVM Specification (SE 21)](https://docs.oracle.com/javase/specs/jvms/se21/html/index.html).

| Property | Configuration |
|---|---|
| Language / spec | Kotlin 2.3.20 on JVM 21 (`jvmToolchain(21)`) |
| Build & toolchain | JDK 21+ (Temurin 21) and checked-in Gradle wrapper (`./gradlew shadowJar`) |
| Memory model | HotSpot JVM generational tracing garbage collector |
| Runner & logs | `kotlin/scripts/run-benchmarks.sh` → `logs/kotlin/YYYY-MM-DD-HHMMSS.csv` (nanoseconds) |
| Registration | [`kotlin/src/main/kotlin/benchmark/serializers/Registry.kt`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/src/main/kotlin/benchmark/serializers/Registry.kt) |
| Data sets | `suite`, `columnar` |

## Registered Serializers

| Serializer | Standard | Data sets | Stream I/O | Timed call path & notes |
|---|---|---|---|---|
| [arrow-ipc](https://arrow.apache.org/docs/java/) | `arrow` | `columnar` | `adapted` | `arrow-vector` `ArrowStreamWriter`; batch built in `serializeBytes`; `table_project` loads `f_float_0` only |
| [avro](https://github.com/apache/avro) | `avro` | `suite`, `columnar` | `native` | Official Apache Avro `ReflectDatum*` with cached schema and encoder reuse |
| [avro4k](https://github.com/avro-kotlin/avro4k) | `avro` | `suite` | `adapted` | `kotlinx.serialization` Avro `encodeToByteArray` |
| [capnproto](https://github.com/capnproto/capnproto-java) | `capnp` | `suite` | `adapted` | `capnproto-java` `Serialize.write` / `read` on generated schema |
| [flatbuffers](https://github.com/google/flatbuffers) | `flatbuffers` | `suite`, `columnar` | `adapted` | Reused `FlatBufferBuilder` on generated tables |
| [fory](https://github.com/apache/fory) | `custom` | `suite` | `adapted` | `fory-kotlin` native mode on pre-registered data classes |
| [gld-ion](https://github.com/leo-gan/gld-ion-kotlin) | `ion` | `suite` | `adapted` | Vendored pure-Kotlin Ion 1.0 binary `ion.encode` / `decode` |
| [gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm) | `kiln` | `suite`, `columnar` | `adapted` | Pure x86-64 Assembly Kiln v2 codec via shared JNI bridge (`libkiln_asm_jni.so`); `TableColumns` + `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project` |
| [gson](https://github.com/google/gson) | `json` | `suite` | `native` | `Gson` (`disableHtmlEscaping`); `JsonWriter` / `JsonReader` on stream |
| [jackson](https://github.com/FasterXML/jackson-module-kotlin) | `json` | `suite` | `native` | `jackson-module-kotlin` reused `ObjectMapper` / `ObjectWriter` |
| [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary) | `cbor` | `suite` | `native` | `jackson-dataformat-cbor` + Kotlin module |
| [kaml](https://github.com/charleskorn/kaml) | `yaml` | `suite` | `adapted` | `kotlinx.serialization` YAML (`encodeToString`) |
| [kbson](https://github.com/jershell/kbson) | `bson` | `suite` | `adapted` | `kotlinx.serialization` BSON (`dump` / `load`); `{ batch = [...] }` for $N > 1$ |
| [kotlinx-cbor](https://github.com/Kotlin/kotlinx.serialization) | `cbor` | `suite` | `adapted` | Official `kotlinx-serialization-cbor` |
| [kotlinx-hocon](https://github.com/lightbend/config) | `hocon` | `suite` | `adapted` | `kotlinx-serialization-hocon`; `{ batch = [...] }` for $N > 1$ |
| [kotlinx-ion](https://github.com/amazon-ion/ion-java) | `ion` | `suite` | `adapted` | Official `ion-java` wrapped as a `kotlinx.serialization` `BinaryFormat` |
| [kotlinx-json](https://github.com/Kotlin/kotlinx.serialization) | `json` | `suite`, `columnar` | `native` | Official compiler-generated JSON (`encodeToStream` on stream) |
| [kotlinx-properties](https://github.com/Kotlin/kotlinx.serialization) | `custom` | `suite` | `adapted` | `kotlinx-serialization-properties` + `java.util.Properties` store/load |
| [kotlinx-protobuf](https://github.com/Kotlin/kotlinx.serialization) | `protobuf` | `suite` | `adapted` | Official `kotlinx-serialization-protobuf` with `@ProtoNumber` annotations |
| [kryo](https://github.com/EsotericSoftware/kryo) | `custom` | `suite` | `native` | Reused `Kryo` + `Output` / `Input` (`writeClassAndObject`) |
| [ktoon](https://github.com/lukelast/ktoon) | `toon` | `suite` | `adapted` | Community Kotlin Multiplatform TOON over `kotlinx.serialization`; size in UTF-8 bytes |
| [moshi-codegen](https://github.com/square/moshi) | `json` | `suite` | `native` | KSP `@JsonClass`-generated `JsonAdapter` over Okio |
| [moshi-reflect](https://github.com/square/moshi) | `json` | `suite` | `native` | Reflection `KotlinJsonAdapterFactory` (added first to override codegen) |
| [msgpack](https://github.com/msgpack/msgpack-java) | `msgpack` | `suite` | `native` | `jackson-dataformat-msgpack` + Kotlin module |
| [obor](https://github.com/orandja/obor) | `cbor` | `suite` | `adapted` | Alternative `kotlinx.serialization` CBOR implementation |
| [orc](https://orc.apache.org/specification/ORCv1/) | `orc` | `columnar` | `adapted` | `orc-core` 2.3.1 (`nohive`), default ZSTD compression, `blockPadding(false)`; `table_project` projects `f_float_0` |
| [orc-uncompressed](https://orc.apache.org/specification/ORCv1/) | `orc` | `columnar` | `adapted` | Same `orc-core` writer with `CompressionKind.NONE` and `blockPadding(false)` |
| [parquet](https://parquet.apache.org/docs/file-format/) | `parquet` | `columnar` | `adapted` | `parquet-avro` 1.18.1 with explicit Snappy; `table_project` projects `f_float_0` |
| [parquet-uncompressed](https://parquet.apache.org/docs/file-format/) | `parquet` | `columnar` | `adapted` | Same `AvroParquetWriter` with `CompressionCodecName.UNCOMPRESSED` |
| [protobuf](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite`, `columnar` | `native` | Official `protobuf-java` builders (`newBuilder()`) |
| [protobuf-kotlin](https://github.com/protocolbuffers/protobuf) | `protobuf` | `suite` | `native` | Official `protobuf-kotlin` DSL builders (`message { }`) on the same wire types |
| [protostuff](https://github.com/protostuff/protostuff) | `custom` | `suite` | `native` | `protostuff-runtime` `RuntimeSchema` with reused `LinkedBuffer` |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | `sbe` | `columnar` | `adapted` | `sbe-tool` 1.40.2 + Agrona flyweight filled in `serializeBytes`; `nested_table` unsupported |
| [thrift](https://github.com/apache/thrift) | `thrift` | `suite` | `adapted` | `libthrift` `TCompactProtocol` matching suite field IDs |
| [tomlkt](https://github.com/Peanuuutz/tomlkt) | `toml` | `suite` | `adapted` | `kotlinx.serialization` TOML; `{ batch = [...] }` for $N > 1$ |

??? note "Library background & provenance"

    Origin and design rationale for each registered library. Links point to upstream repositories, standard-library paths, or in-tree reference implementations.

    - **[arrow-ipc](https://arrow.apache.org/docs/java/)** — Apache Arrow was created so analytic engines could share columnar batches without copying each one into a private layout. The problem was a convert-at-every-boundary tax. Arrow IPC is the stream format for those batches. This Kotlin row times arrow-vector 19.0.0 ArrowStreamWriter inside the bytes API, not the Arrow file format and not arrow-dataset. The schema is built in prepare. Row-to-column conversion stays inside serialize. table_project loads f_float_0 only. No compliance decoder.
    - **[avro](https://github.com/apache/avro)** — Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.
    - **[avro4k](https://github.com/avro-kotlin/avro4k)** — avro4k brings Apache Avro to kotlinx.serialization. Avro exists for compact, schema-driven records. avro4k generates the Avro path from `@Serializable` types instead of Java reflect.
    - **[capnproto](https://github.com/capnproto/capnproto-java)** — Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.
    - **[flatbuffers](https://github.com/google/flatbuffers)** — FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.
    - **[fory](https://github.com/apache/fory)** — Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol. This row uses the fory-kotlin module through ForyKotlin in native mode on Kotlin data classes.
    - **[gld-ion](https://github.com/leo-gan/gld-ion-kotlin)** — gld-ion-kotlin (leo-gan) is a vendored, from-scratch Amazon Ion 1.0 binary encoder and decoder for Kotlin, timing `ion.encode` and `ion.decode` on the five suite types.
    - **[gld-kiln-asm](https://github.com/leo-gan/gld-kiln-asm)** — gld-kiln-asm (leo-gan) is a pure x86-64 Assembly (GNU as) Kiln Wire Format v2 library with AOT schema codegen (`gld_kilngen_asm.py`) bound via shared `libkiln_asm_jni.so` (statically linking `libkiln_asm_bench.a`). Covers `suite` and `columnar` (`TableColumns` with `KILN_OPT_EMBEDDED` O(1) column-skip for `table_project`).
    - **[gson](https://github.com/google/gson)** — Gson was created at Google to convert Java objects to JSON and back with a simple API. The problem was boilerplate-heavy Java JSON. Gson solves it with reflection over POJOs and a JsonWriter/Reader stream API.
    - **[jackson](https://github.com/FasterXML/jackson-module-kotlin)**, **[jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary)** — Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack).
    - **[kaml](https://github.com/charleskorn/kaml)** — kaml is YAML for kotlinx.serialization. YAML exists as a human-friendly config language. kaml solves Kotlin YAML by implementing a format on the same `@Serializable` types.
    - **[kbson](https://github.com/jershell/kbson)** — kbson is BSON for kotlinx.serialization. BSON exists for MongoDB documents. kbson lets Kotlin `@Serializable` types dump/load BSON without a separate mapper.
    - **[kotlinx-cbor](https://github.com/Kotlin/kotlinx.serialization)**, **[kotlinx-json](https://github.com/Kotlin/kotlinx.serialization)**, **[kotlinx-properties](https://github.com/Kotlin/kotlinx.serialization)**, **[kotlinx-protobuf](https://github.com/Kotlin/kotlinx.serialization)** — kotlinx.serialization is JetBrains' official serialization framework for Kotlin. The problem was that Kotlin needed compile-time serializers, not Java reflection, across JSON and other formats. The compiler plugin generates serializers; format libraries plug in.
    - **[kotlinx-hocon](https://github.com/lightbend/config)** — HOCON (Human-Optimized Config Object Notation) was created at Typesafe/Lightbend for Play/Akka configuration. The problem was JSON/YAML config that was awkward for humans. kotlinx-serialization-hocon speaks that format.
    - **[kotlinx-ion](https://github.com/amazon-ion/ion-java)** — Amazon Ion was created as a rich, self-describing superset of JSON (text and binary) for Amazon services. Official Ion libraries and Jackson Ion modules implement that model.
    - **[kryo](https://github.com/EsotericSoftware/kryo)** — Kryo was written as a fast binary serializer for JVM object graphs (games, caches, RPC). The problem was Java serialization being slow and verbose. Kryo solves it with a compact binary and reusable Output/Input.
    - **[ktoon](https://github.com/lukelast/ktoon)** — ktoon is a community Kotlin Multiplatform TOON codec on kotlinx.serialization. There is no official Kotlin port. The timed path is encodeToString and decodeFromString. The Size column is the UTF-8 byte length.
    - **[moshi-codegen](https://github.com/square/moshi)**, **[moshi-reflect](https://github.com/square/moshi)** — Moshi was created at Square as a modern JSON library for Java and Android, successor-minded to Gson. The problem was Gson's older model on Android. Moshi solves it with JsonAdapter, codegen or reflection, and Okio.
        - `moshi-codegen`: This row times KSP-generated JsonAdapters on the same domain types as moshi-reflect.
        - `moshi-reflect`: This row times reflection adapters (`KotlinJsonAdapterFactory`) on the same types as moshi-codegen.
    - **[msgpack](https://github.com/msgpack/msgpack-java)** — msgpack-java is the official MessagePack library for the JVM. MessagePack exists as compact binary JSON. This suite times the Jackson MessagePack mapper on that stack.
    - **[obor](https://github.com/orandja/obor)** — obor is an alternative CBOR implementation for kotlinx.serialization. CBOR is the IETF binary JSON-like format. obor exists as a different kotlinx CBOR stack from the official one.
    - **[orc](https://orc.apache.org/specification/ORCv1/)** — Apache ORC was created as a columnar file with stripe indexes for scans. This Kotlin row times orc-core 2.3.1 (classifier nohive) and orc-format 1.1.1 nohive. OrcConf.COMPRESS defaults to ZSTD, so orc does not call compress(). orc-uncompressed sets CompressionKind.NONE. Both rows set blockPadding(false) so a small file is not padded toward the 256MB HDFS block. table_project includes f_float_0 only. No compliance decoder.
    - **[orc-uncompressed](https://orc.apache.org/specification/ORCv1/)** — This is the same orc-core writer as orc, with CompressionKind.NONE and blockPadding(false). The name is the override. No compliance decoder.
    - **[parquet](https://parquet.apache.org/docs/file-format/)** — Apache Parquet was created as a columnar file for scans that touch a few fields of many rows. The problem was row files that made every reader parse every column. This Kotlin row times parquet-avro 1.18.1 AvroParquetWriter. parquet-java's default codec is UNCOMPRESSED, so this row sets CompressionCodecName.SNAPPY. table_project sets AvroReadSupport requested projection to f_float_0. No compliance decoder.
    - **[parquet-uncompressed](https://parquet.apache.org/docs/file-format/)** — This is the same parquet-avro writer as parquet, with CompressionCodecName.UNCOMPRESSED. The name is the override. No compliance decoder.
    - **[protobuf](https://github.com/protocolbuffers/protobuf)**, **[protobuf-kotlin](https://github.com/protocolbuffers/protobuf)** — Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.
        - `protobuf-kotlin`: This row uses the generated Kotlin DSL builders on the same protobuf wire types as the Java API row.
    - **[protostuff](https://github.com/protostuff/protostuff)** — protostuff was created to serialize Java objects with protobuf-like efficiency without writing `.proto` files. The problem was protobuf's IDL tax for internal graphs. Runtime schemas and LinkedBuffer reuse are the solution this row times.
    - **[sbe](https://github.com/aeron-io/simple-binary-encoding)** — SBE (Simple Binary Encoding) was created for word-aligned financial messages: a fixed block, then repeating groups, then variable-length data. The problem was tag/length codecs that touch every field on the hot path. This Kotlin row fills the sbe-tool 1.40.2 Java flyweight inside serialize. Agrona is the runtime. The generator jar is sbe-all, copied from Maven at build time. It encodes table, table_project, and signal. nested_table is not an SBE body. The signal wire order is fixed fields, then the legs group, then symbol and venue. No compliance decoder.
    - **[thrift](https://github.com/apache/thrift)** — Apache Thrift was created at Facebook so many languages could share RPC and serialization from one IDL. The problem was hand-written cross-language services. Thrift solves it with a schema compiler and protocols such as TCompactProtocol.
    - **[tomlkt](https://github.com/Peanuuutz/tomlkt)** — tomlkt is TOML for kotlinx.serialization. TOML exists as an obvious config language. tomlkt encodes `@Serializable` types to TOML text.

## Measurement Caveats

- **JVM-only wire formats:** `kryo`, `fory`, and `protostuff` serialize JVM object graphs and are not cross-language wire standards.
- **Root-array batch wrappers:** `tomlkt`, `kotlinx-hocon`, and `kbson` wrap $N > 1$ batches in `{ batch = [...] }` because TOML, HOCON, and BSON do not allow bare root arrays (the key `batch` avoids colliding with `Document.items` / `Strings.items`).
- **Moshi codegen vs. reflection:** Both rows share the same domain types; `moshi-reflect` registers `KotlinJsonAdapterFactory` first so reflection takes precedence over KSP-generated adapters.
- **Columnar and SBE rules:** Identical to Java (`arrow-vector`, `parquet-avro` 1.18.1 with explicit Snappy, `orc-core` 2.3.1 `nohive` with default ZSTD and `blockPadding(false)`, `sbe-tool` 1.40.2 omitting `nested_table`). Row-to-column conversion stays inside timed `serializeBytes`, and stream mode is adapted.
- **Separation from Java:** Kotlin and Java share JVM 21 but use distinct data classes, Gradle vs. Maven builds, and adapters; compare rows within Kotlin only.

## Results & Further Reading

- **Live measurements (L1):** [Dashboard (Kotlin)](../dashboard/index.html?lang=kotlin&data=document@n=1&mode=bytes) · [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md)
- **Specification compliance:** [Compliance (Kotlin)](../dashboard/index.html#compliance)
- **Source-level analyses:** [Kotlin: `FlatBuffers` vs. `protobuf`](../analysis/call-sites/kotlin-flatbuffers-vs-protobuf.md) · [Kotlin: `kotlinx-json` vs. `Moshi`](../analysis/call-sites/kotlin-kotlinx-json-vs-moshi.md) · [Kotlin: `Protostuff` vs. `protobuf`](../analysis/call-sites/kotlin-protostuff-vs-protobuf.md)
- **Build & run guide:** [`kotlin/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/README.md) · [Timing contract](../analysis/TIMING_HONESTY.md)
