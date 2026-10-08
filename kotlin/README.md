# Kotlin Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers (32)

The registry is the previous 26 rows plus Arrow IPC, Parquet (Snappy and uncompressed), ORC (ZSTD default and uncompressed), and SBE.

| Name | Category | Package | Call path notes |
|------|----------|---------|-----------------|
| kotlinx-json | JSON | kotlinx-serialization-json | Compiler-generated serializers; `encodeToStream` / `decodeFromStream` |
| kotlinx-cbor | CBOR | kotlinx-serialization-cbor | Official Kotlin CBOR |
| kotlinx-protobuf | Schema | kotlinx-serialization-protobuf | `@ProtoNumber` on domain types |
| kotlinx-properties | Text | kotlinx-serialization-properties | `encodeToStringMap` + `java.util.Properties` store/load |
| kotlinx-hocon | Text | kotlinx-serialization-hocon | `Hocon.encodeToConfig` / `decodeFromConfig` |
| kaml | YAML | com.charleskorn.kaml | Same `@Serializable` core |
| jackson | JSON | jackson-module-kotlin | Reuse `ObjectMapper` + typed writer/reader |
| moshi-codegen | JSON | moshi-kotlin-codegen | KSP `@JsonClass` adapters; Okio Buffer |
| moshi-reflect | JSON | moshi-kotlin | `KotlinJsonAdapterFactory` first (reflection) |
| gson | JSON | gson | Reuse `Gson`; `disableHtmlEscaping`; JsonWriter/Reader |
| jackson-cbor | CBOR | jackson-dataformat-cbor | `CBORMapper` + Kotlin module |
| msgpack | MessagePack | jackson-dataformat-msgpack | Official msgpack-java Jackson binding |
| obor | CBOR | net.orandja.obor | kotlinx.serialization CBOR alternative |
| kryo | Binary | kryo | Reuse Kryo + Output/Input; `writeClassAndObject` |
| fory | Binary | fory-core | Apache Fory JIT; register types once |
| protostuff | Binary | protostuff-runtime | `RuntimeSchema` + `LinkedBuffer` |
| kbson | BSON | com.github.jershell:kbson | kotlinx BSON `dump` / `load` |
| kotlinx-ion | Ion | ion-java | Amazon Ion binary via kotlinx encoder + ion-java |
| tomlkt | TOML | net.peanuuutz.tomlkt | Table root; list wrap `{ items = [...] }` for N>1 |
| protobuf | Schema | protobuf-java | Java `newBuilder()`; timed `toByteArray`/`parseFrom` |
| protobuf-kotlin | Schema | protobuf-kotlin | Kotlin DSL builders (`message { }`) then wire encode |
| avro4k | Schema | avro4k-core | kotlinx Avro `encodeToByteArray` |
| avro | Schema | avro | ReflectDatumWriter/Reader + BinaryEncoder reuse |
| thrift | Schema | libthrift | TCompactProtocol field ids aligned with suite proto |
| flatbuffers | Schema | flatbuffers-java | Reused `FlatBufferBuilder`; generated tables |
| capnproto | Schema | org.capnproto:runtime | `Serialize.write` / `Serialize.read`; generated schema |
| arrow-ipc | Columnar | arrow-vector 19.0.0 | IPC stream bytes, not the Arrow file format. `table_project` loads `f_float_0` only |
| parquet | Columnar | parquet-avro 1.18.1 | Sets `CompressionCodecName.SNAPPY`. parquet-java 1.18.1 defaults to UNCOMPRESSED |
| parquet-uncompressed | Columnar | parquet-avro 1.18.1 | `CompressionCodecName.UNCOMPRESSED` |
| orc | Columnar | orc-core 2.3.1 `nohive` + orc-format 1.1.1 `nohive` | Does not call `compress()`. ORC 2.3.1 default is ZSTD. `blockPadding(false)` |
| orc-uncompressed | Columnar | orc-core 2.3.1 `nohive` + orc-format 1.1.1 `nohive` | `CompressionKind.NONE`. `blockPadding(false)` |
| sbe | Schema | sbe-tool 1.40.2 / agrona 2.6.1 | Flyweight filled inside timed serialize. No `nested_table` |

### Call-path contract

1. `prepare(fixture)` — untimed
2. `serializeBytes` / `deserializeBytes` — timed
3. Stream: **native** or **adapted** (`streamMode`)

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`, plus columnar `table`, `table_project`, `nested_table`, and `signal`.
Smoke filter default stays `message`. The six columnar rows support only the four new ids. SBE does not support `nested_table`. kotlinx-json, protobuf, flatbuffers, and reflect Avro also round-trip those ids.

`table_project` serializes every column and deserializes `f_float_0` only (a list of length N, including N=1). Arrow, Parquet, and ORC project inside the format. The peers full-decode and then slice. Schema objects, writer properties, and SBE codegen are untimed. Row-to-column conversion and the SBE flyweight fill stay inside `serializeBytes`. There is no compliance decoder for these rows.

`parquet` sets Snappy because parquet-java 1.18.1 defaults to UNCOMPRESSED. `orc` leaves ORC 2.3.1's ZSTD default in place. Both ORC rows use the `nohive` classifier on `orc-core` and `orc-format` so the writer links `org.apache.orc.protobuf` instead of `com.google.protobuf`. Both set `blockPadding(false)`.

## Run

```bash
./scripts/run-benchmarks.sh smoke
./scripts/run-benchmarks.sh full
```

Requires **JDK 17+** (21 recommended). The Gradle wrapper is in-tree.

```bash
./scripts/install-host-requirements.sh kotlin
```

`LOG_DIR` may be a logs **root** (results under `$LOG_DIR/kotlin/`).

Analysis: `analyze-benchmarks -l kotlin`.
