---
title: "Kotlin"
---

Kotlin
======

Kotlin’s serialization landscape spans the **kotlinx.serialization format family** (JSON, CBOR, ProtoBuf, Properties, HOCON) plus **kaml** YAML on the same `@Serializable` types; **JVM JSON** (Jackson Kotlin, Moshi codegen vs reflection, Gson); **high-performance JVM binary** (Kryo, Apache Fory, Protostuff); **portable binary** (Jackson CBOR, MessagePack, Obor, KBson, Amazon Ion); **text** (tomlkt); **schema/IDL** stacks (protobuf-java, protobuf-kotlin, FlatBuffers, Cap'n Proto, Avro4k, Apache Avro, Thrift, SBE); and **columnar** files (Arrow IPC, Parquet, ORC). The registry has **32** serializers (26 plus these 6).

## Runtime

### What it is

Kotlin is a programming language. This runner targets the **same JVM** as [Java](../java/): bytecode on HotSpot, just-in-time compilation, and garbage collection. Kotlin can also compile to native code or to JavaScript. This suite does not measure those backends. It measures Kotlin running on the JVM.

| | This suite |
|---|---|
| Target | JVM **21** (`jvmToolchain(21)`), Kotlin **2.1** |
| Host JDK | JDK **17 or newer** is accepted. The same Temurin 21 install as Java is used. |
| Build | Gradle wrapper in `kotlin/` (not Maven) |
| Prepare | `./scripts/install-host-requirements.sh kotlin` |
| Run | `kotlin/scripts/run-benchmarks.sh` (`./gradlew shadowJar`) |
| Memory | JVM garbage collector (HotSpot) |

### What this suite runs

Kotlin 2.1 compiles to Java 21 bytecode. The Gradle wrapper is checked into `kotlin/`, so you do not install Gradle yourself. Domain types are `@Serializable` data classes with `@JvmField`, so JVM reflection codecs such as Jackson, Kryo, and Moshi see public fields.

### What changes the numbers

Warmup and garbage collection work the same way as on Java: the first repetitions pay for JIT compilation, and later ones are closer to steady state. **kotlinx.serialization** generates encode and decode methods at compile time. **moshi-codegen** uses KSP (Kotlin Symbol Processing) to generate an adapter. **moshi-reflect** uses reflection on the same types and is slower.

Sharing a JVM with Java does not make the Java and Kotlin rows one measurement. The wrappers and the domain types are different.

### Suite-specific gotchas

**kryo**, **fory**, and **protostuff** encode JVM object graphs. They are not portable to other languages.

When a cell has more than one instance, the TOML, HOCON, and BSON rows wrap the payload as `{ batch = [...] }`. Those formats cannot use a bare array as the document root.

Kotlin times cannot be ranked against Java, or against any other language, as a single contest.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`kotlin/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/README.md). JetBrains’ overview is [Kotlin/JVM](https://kotlinlang.org/docs/jvm-get-started.html). For garbage collection and latency, see [Latency tails and GC](../theory/301/latency-tails-and-gc.md).

## Benchmark runner

- Directory: `kotlin/` (repository root)
- Output: monorepo `logs/kotlin/YYYY-MM-DD-HHMMSS.csv` (`Language=kotlin`, times in **nanoseconds**)
- Runner: `kotlin/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`kotlin/src/main/kotlin/benchmark/serializers/Registry.kt`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/src/main/kotlin/benchmark/serializers/Registry.kt)

## Serializers

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| [arrow-ipc](https://github.com/apache/arrow-java) | Columnar | arrow-vector | ArrowStreamWriter | adapted | IPC stream bytes, not the Arrow file format. `table_project` loads `f_float_0` only |
| [avro](https://github.com/apache/avro) | Schema | avro | ReflectDatum* | native | Schema once; encoder reuse |
| [avro4k](https://github.com/avro-kotlin/avro4k) | Schema | avro4k-core | encodeToByteArray | adapted | kotlinx Avro |
| [capnproto](https://github.com/capnproto/capnproto-java) | Schema | org.capnproto:runtime | Serialize.write/read | adapted | Generated suite schema |
| [flatbuffers](https://github.com/google/flatbuffers) | Schema | flatbuffers-java | FlatBufferBuilder | adapted | Generated tables; builder reuse |
| [fory](https://github.com/apache/fory) | Binary | fory-core | serialize/deserialize | adapted | Apache Fory; register types before freeze |
| [gson](https://github.com/google/gson) | JSON | gson | Gson + Type | native | `disableHtmlEscaping`; JsonWriter/Reader |
| [jackson](https://github.com/FasterXML/jackson-module-kotlin) | JSON | jackson-module-kotlin | ObjectWriter/Reader | native | Reused ObjectMapper; no pretty-print |
| [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary) | CBOR | jackson-dataformat-cbor | CBORMapper | native | IETF CBOR + Kotlin module |
| [kaml](https://github.com/charleskorn/kaml) | YAML | kaml | encodeToString | adapted | Same `@Serializable` core |
| [kbson](https://github.com/jershell/kbson) | BSON | kbson | dump/load | adapted | kotlinx BSON |
| [kotlinx-cbor](https://github.com/Kotlin/kotlinx.serialization) | CBOR | kotlinx-serialization-cbor | encodeToByteArray | adapted | Official Kotlin CBOR |
| [kotlinx-hocon](https://github.com/lightbend/config) | HOCON | kotlinx-serialization-hocon | encodeToConfig | adapted | List wrap `{ items = [...] }` for N>1 |
| [kotlinx-ion](https://github.com/amazon-ion/ion-java) | Ion | ion-java | IonWriter/Reader | adapted | Amazon Ion binary via kotlinx encoder |
| [kotlinx-json](https://github.com/Kotlin/kotlinx.serialization) | JSON | kotlinx-serialization-json | encodeToStream | native | Compiler-generated serializers |
| [kotlinx-properties](https://github.com/Kotlin/kotlinx.serialization) | Properties | kotlinx-serialization-properties | encodeToStringMap | adapted | Then `java.util.Properties` store/load |
| [kotlinx-protobuf](https://github.com/Kotlin/kotlinx.serialization) | Schema | kotlinx-serialization-protobuf | encodeToByteArray | adapted | `@ProtoNumber` on domain types |
| [kryo](https://github.com/EsotericSoftware/kryo) | Binary | kryo | writeClassAndObject | native | Reused Kryo + Output/Input |
| [moshi-codegen](https://github.com/square/moshi) | JSON | moshi-kotlin-codegen | generated JsonAdapter | native | KSP `@JsonClass` |
| [moshi-reflect](https://github.com/square/moshi) | JSON | moshi-kotlin | KotlinJsonAdapterFactory | native | Reflection; factory added first |
| [msgpack](https://github.com/msgpack/msgpack-java) | MessagePack | jackson-dataformat-msgpack | MessagePackMapper | native | Official msgpack-java + Kotlin module |
| [obor](https://github.com/orandja/obor) | CBOR | obor | encodeToByteArray | adapted | kotlinx CBOR alternative |
| [orc](https://github.com/apache/orc) | Columnar | orc-core `nohive` | OrcFile.Writer | adapted | No `compress()` call. ORC 2.3.1 default is ZSTD. `blockPadding(false)` |
| [orc-uncompressed](https://github.com/apache/orc) | Columnar | orc-core `nohive` | OrcFile.Writer | adapted | `CompressionKind.NONE`. `blockPadding(false)` |
| [parquet](https://github.com/apache/parquet-java) | Columnar | parquet-avro | AvroParquetWriter | adapted | Snappy. parquet-java 1.18.1 defaults to UNCOMPRESSED, so this row sets the codec |
| [parquet-uncompressed](https://github.com/apache/parquet-java) | Columnar | parquet-avro | AvroParquetWriter | adapted | `CompressionCodecName.UNCOMPRESSED` |
| [protobuf](https://github.com/protocolbuffers/protobuf) | Schema | protobuf-java | MessageLite wire | native | Java `newBuilder()` |
| [protobuf-kotlin](https://github.com/protocolbuffers/protobuf) | Schema | protobuf-kotlin | Kotlin DSL + wire | native | `message { }` builders |
| [protostuff](https://github.com/protostuff/protostuff) | Binary | protostuff-runtime | RuntimeSchema | native | LinkedBuffer reuse; list APIs |
| [sbe](https://github.com/aeron-io/simple-binary-encoding) | Schema | sbe-tool / agrona | flyweight | adapted | Tool 1.40.2. No `nested_table`. Flyweight filled inside the timed serialize |
| [thrift](https://github.com/apache/thrift) | Schema | libthrift | TCompactProtocol | adapted | Field ids match suite proto |
| [tomlkt](https://github.com/Peanuuutz/tomlkt) | TOML | tomlkt | encodeToString | adapted | List wrap `{ items = [...] }` for N>1 |

### Columnar and SBE

The six columnar rows support `table`, `table_project`, `nested_table`, and `signal` only. SBE returns false for `nested_table` because that body is not in the schema. The original codecs still support `message`, `document`, `telemetry`, `strings`, and `event`. kotlinx-json, protobuf (the Java API row, not kotlinx-protobuf or protobuf-kotlin), flatbuffers, and the reflect Avro row also round-trip the four new ids.

`prepare` builds the Arrow schema, the Parquet/Avro schema, and the ORC `TypeDescription` plus writer options. SBE codegen runs at build time. Row-to-column conversion and the SBE flyweight wrap run inside timed `serializeBytes`. There is no compliance decoder. Stream methods on these rows are the adapted bytes path.

`table_project` serializes the full row and deserializes `f_float_0` only, including when N is 1. The runner compares that column (`Fidelity.expectedForFidelity`), not the full rows. Arrow reads that column with `MessageChannelReader`, `MessageSerializer.deserializeRecordBatch`, and `VectorLoader` on a one-field schema. Parquet sets `AvroReadSupport.setRequestedProjection` and `setAvroReadSchema`. ORC sets `Reader.Options.include` with the root and `f_float_0` column ids. Peers full-decode, then slice inside `deserialize`.

`orc` and `orc-uncompressed` both set `blockPadding(false)`. Default padding would extend a small file toward the 256MB HDFS block. That flag is not a compression override. ORC 2.3.1's own default compression is ZSTD (`OrcConf.COMPRESS`), so `orc` does not call `compress()`. `orc-uncompressed` sets `CompressionKind.NONE`. The `nohive` jars relocate Hive vectors to `org.apache.orc.storage` and protobuf to `org.apache.orc.protobuf`. `orc-core` nohive is paired with `orc-format` nohive 1.1.1; the default `orc-format` jar is compiled against `com.google.protobuf` and does not link. parquet-java 1.18.1 defaults to UNCOMPRESSED, so `parquet` sets `CompressionCodecName.SNAPPY` and `parquet-uncompressed` sets `UNCOMPRESSED`.

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [arrow-ipc](https://github.com/apache/arrow-java) · `19.0.0`

Apache Arrow was created so analytic engines could share a columnar memory layout. Arrow IPC is the stream of that layout. This row writes an IPC stream (not the Arrow file format and not Arrow Dataset) and, for `table_project`, loads only the `f_float_0` buffers. There is no compliance decoder.

#### [avro](https://github.com/apache/avro) · `1.12.1`

Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.

#### [avro4k](https://github.com/avro-kotlin/avro4k) · `2.9.0`

avro4k brings Apache Avro to kotlinx.serialization. Avro exists for compact, schema-driven records. avro4k generates the Avro path from `@Serializable` types instead of Java reflect.

#### [capnproto](https://github.com/capnproto/capnproto-java) · `0.1.16`

Cap'n Proto was created by Kenton Varda (after protobuf 2) so RPC and storage could use a binary layout that is already the in-memory representation — no encode step. The problem was protobuf's parse/serialize cost. Cap'n Proto solves it with an IDL and packed/unpacked segments.

#### [flatbuffers](https://github.com/google/flatbuffers) · `24.3.25`

FlatBuffers was created at Google so games and clients could access serialized data without an unpack step. The problem was that protobuf-style decode allocated a full object graph. FlatBuffers solves it with a schema and a binary layout that can be traversed in place.

#### [fory](https://github.com/apache/fory) · `1.3.0`

Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol.

#### [gson](https://github.com/google/gson) · `2.14.0`

Gson was created at Google to convert Java objects to JSON and back with a simple API. The problem was boilerplate-heavy Java JSON. Gson solves it with reflection over POJOs and a JsonWriter/Reader stream API.

#### [jackson](https://github.com/FasterXML/jackson-module-kotlin) · `2.19.0`

Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack).

#### [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary) · `2.19.0`

Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack).

#### [kaml](https://github.com/charleskorn/kaml) · `0.72.0`

kaml is YAML for kotlinx.serialization. YAML exists as a human-friendly config language. kaml solves Kotlin YAML by implementing a format on the same `@Serializable` types.

#### [kbson](https://github.com/jershell/kbson) · `0.5.0`

kbson is BSON for kotlinx.serialization. BSON exists for MongoDB documents. kbson lets Kotlin `@Serializable` types dump/load BSON without a separate mapper.

#### [kotlinx-cbor](https://github.com/Kotlin/kotlinx.serialization) · `1.8.1`

kotlinx.serialization is JetBrains' official serialization framework for Kotlin. The problem was that Kotlin needed compile-time serializers, not Java reflection, across JSON and other formats. The compiler plugin generates serializers; format libraries plug in.

#### [kotlinx-hocon](https://github.com/lightbend/config) · `1.8.1`

HOCON (Human-Optimized Config Object Notation) was created at Typesafe/Lightbend for Play/Akka configuration. The problem was JSON/YAML config that was awkward for humans. kotlinx-serialization-hocon speaks that format.

#### [kotlinx-ion](https://github.com/amazon-ion/ion-java) · `1.11.11`

Amazon Ion was created as a rich, self-describing superset of JSON (text and binary) for Amazon services. Official Ion libraries and Jackson Ion modules implement that model.

#### [kotlinx-json](https://github.com/Kotlin/kotlinx.serialization) · `1.8.1`

kotlinx.serialization is JetBrains' official serialization framework for Kotlin. The problem was that Kotlin needed compile-time serializers, not Java reflection, across JSON and other formats. The compiler plugin generates serializers; format libraries plug in.

#### [kotlinx-properties](https://github.com/Kotlin/kotlinx.serialization) · `1.8.1`

kotlinx.serialization is JetBrains' official serialization framework for Kotlin. The problem was that Kotlin needed compile-time serializers, not Java reflection, across JSON and other formats. The compiler plugin generates serializers; format libraries plug in.

#### [kotlinx-protobuf](https://github.com/Kotlin/kotlinx.serialization) · `1.8.1`

kotlinx.serialization is JetBrains' official serialization framework for Kotlin. The problem was that Kotlin needed compile-time serializers, not Java reflection, across JSON and other formats. The compiler plugin generates serializers; format libraries plug in.

#### [kryo](https://github.com/EsotericSoftware/kryo) · `5.6.2`

Kryo was written as a fast binary serializer for JVM object graphs (games, caches, RPC). The problem was Java serialization being slow and verbose. Kryo solves it with a compact binary and reusable Output/Input.

#### [moshi-codegen](https://github.com/square/moshi) · `1.15.2`

Moshi was created at Square as a modern JSON library for Java and Android, successor-minded to Gson. The problem was Gson's older model on Android. Moshi solves it with JsonAdapter, codegen or reflection, and Okio. This row times KSP-generated JsonAdapters on the same domain types as moshi-reflect.

#### [moshi-reflect](https://github.com/square/moshi) · `1.15.2`

Moshi was created at Square as a modern JSON library for Java and Android, successor-minded to Gson. The problem was Gson's older model on Android. Moshi solves it with JsonAdapter, codegen or reflection, and Okio. This row times reflection adapters (`KotlinJsonAdapterFactory`) on the same types as moshi-codegen.

#### [msgpack](https://github.com/msgpack/msgpack-java) · `0.9.8`

msgpack-java is the official MessagePack library for the JVM. MessagePack exists as compact binary JSON. This suite times the Jackson MessagePack mapper on that stack.

#### [obor](https://github.com/orandja/obor) · `2.1.3`

obor is an alternative CBOR implementation for kotlinx.serialization. CBOR is the IETF binary JSON-like format. obor exists as a different kotlinx CBOR stack from the official one.

#### [orc](https://github.com/apache/orc) · `2.3.1`

ORC was created for Hive as a columnar file with indexes and compression. This row uses `orc-core` and `orc-format` with the `nohive` classifier so vectors live in `org.apache.orc.storage` and the writer calls `org.apache.orc.protobuf`. The default `orc-format` jar is compiled against `com.google.protobuf` and does not link. ORC 2.3.1 defaults to ZSTD, so this row does not call `compress()`. Both ORC rows set `blockPadding(false)`. `table_project` uses `Reader.Options.include`. There is no compliance decoder.

#### [orc-uncompressed](https://github.com/apache/orc) · `2.3.1`

Same ORC writer as `orc`, with `CompressionKind.NONE` and `blockPadding(false)`. The payload differs from the ZSTD default row.

#### [parquet](https://github.com/apache/parquet-java) · `1.18.1`

Apache Parquet was created as a columnar file for analytic scans. This row uses parquet-avro. parquet-java 1.18.1's default codec is UNCOMPRESSED, so this row sets `CompressionCodecName.SNAPPY`. `table_project` sets an Avro requested projection on `f_float_0`. There is no compliance decoder.

#### [parquet-uncompressed](https://github.com/apache/parquet-java) · `1.18.1`

Same Parquet writer as `parquet`, with `CompressionCodecName.UNCOMPRESSED`. The footer codec and the bytes differ from the Snappy row.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `4.35.0`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [protobuf-kotlin](https://github.com/protocolbuffers/protobuf) · `4.35.0`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format. This row uses the generated Kotlin DSL builders on the same protobuf wire types as the Java API row.

#### [protostuff](https://github.com/protostuff/protostuff) · `1.8.0`

protostuff was created to serialize Java objects with protobuf-like efficiency without writing `.proto` files. The problem was protobuf's IDL tax for internal graphs. Runtime schemas and LinkedBuffer reuse are the solution this row times.

#### [sbe](https://github.com/aeron-io/simple-binary-encoding) · `1.40.2`

Simple Binary Encoding was created for low-latency finance messages: a schema compiler emits flyweights over a direct buffer instead of allocating a message object. This row times sbe-tool 1.40.2 with Agrona at runtime. Codegen is untimed. The flyweight fill is inside timed serialize. `nested_table` is not an SBE body. There is no compliance decoder.

#### [thrift](https://github.com/apache/thrift) · `0.21.0`

Apache Thrift was created at Facebook so many languages could share RPC and serialization from one IDL. The problem was hand-written cross-language services. Thrift solves it with a schema compiler and protocols such as TCompactProtocol.

#### [tomlkt](https://github.com/Peanuuutz/tomlkt) · `0.5.0`

tomlkt is TOML for kotlinx.serialization. TOML exists as an obvious config language. tomlkt encodes `@Serializable` types to TOML text.

### Call-path contract (same idea as Java/Go/Python/Rust)

```text
prepare(fixture)                 # untimed: mappers, schemas, Fory register, proto convert
                                 # columnar: schema and writer options only; row-to-column stays in serialize
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  toDomain (if needed)           # untimed
  fidelity(expected, actual)     # untimed
```

### Caveats

- **kryo**, **fory**, and **protostuff** are not universal cross-language wire formats.
- **moshi-codegen** vs **moshi-reflect** share the same domain types; reflection adds `KotlinJsonAdapterFactory` first so it wins over generated adapters.
- **tomlkt**, **kotlinx-hocon**, and **kbson** wrap N>1 fixtures as a table `{ batch = [...] }` (TOML/HOCON have no root array; BSON forbids a root array). The wrap key is `batch`, not `items`, so it does not collide with `Document.items` / `Strings.items`.
- **protobuf** uses the Java builder API; **protobuf-kotlin** uses the generated Kotlin DSL on the same wire types.
- **kotlinx-ion** uses official `ion-java` through a kotlinx `BinaryFormat` (the community `kotlinx-serialization-ion` artifact is JitPack-only and unmaintained).
- Stream mode is **native** only where noted; others are adapted bytes+buffer.
- **arrow-ipc**, **parquet**, **parquet-uncompressed**, **orc**, **orc-uncompressed**, and **sbe** support only `table`, `table_project`, `nested_table`, and `signal`. **sbe** does not support `nested_table`. There is no compliance decoder for these rows. This page does not report a full columnar publish.

Also: [`kotlin/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=kotlin&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## Design choices

1. **Prepare outside the loop** — Json/ObjectMapper, Kryo buffers, Fory type registration, Avro schema, protobuf parser bind.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Shared domain types** in `benchmark.model.v2` as `@Serializable` data classes with `@JvmField` for JVM reflection codecs.
