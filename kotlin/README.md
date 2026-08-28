# Kotlin Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers (26)

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

### Call-path contract

1. `prepare(fixture)` — untimed
2. `serializeBytes` / `deserializeBytes` — timed
3. Stream: **native** or **adapted** (`streamMode`)

## Test data

Suite type ids: `message`, `document`, `telemetry`, `strings`, `event`
(smoke filter default: `message`).

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
