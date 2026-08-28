---
title: "Kotlin"
---

Kotlin
======

Kotlin’s serialization landscape spans the **kotlinx.serialization format family** (JSON, CBOR, ProtoBuf, Properties, HOCON) plus **kaml** YAML on the same `@Serializable` types; **JVM JSON** (Jackson Kotlin, Moshi codegen vs reflection, Gson); **high-performance JVM binary** (Kryo, Apache Fory, Protostuff); **portable binary** (Jackson CBOR, MessagePack, Obor, KBson, Amazon Ion); **text** (tomlkt); and **schema/IDL** stacks (protobuf-java, protobuf-kotlin, FlatBuffers, Cap'n Proto, Avro4k, Apache Avro, Thrift).

## Benchmark runner

- Directory: `kotlin/` (repository root)
- Output: monorepo `logs/kotlin/YYYY-MM-DD-HHMMSS.csv` (`Language=kotlin`, times in **nanoseconds**)
- Runner: `kotlin/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`kotlin/src/main/kotlin/benchmark/serializers/Registry.kt`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/kotlin/src/main/kotlin/benchmark/serializers/Registry.kt)
- Requires **JDK 17+** (benchmark runner targets 21). Gradle wrapper is in-tree.

## Serializers

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| avro | Schema | avro | ReflectDatum* | native | Schema once; encoder reuse |
| avro4k | Schema | avro4k-core | encodeToByteArray | adapted | kotlinx Avro |
| capnproto | Schema | org.capnproto:runtime | Serialize.write/read | adapted | Generated suite schema |
| flatbuffers | Schema | flatbuffers-java | FlatBufferBuilder | adapted | Generated tables; builder reuse |
| fory | Binary | fory-core | serialize/deserialize | adapted | Apache Fory; register types before freeze |
| gson | JSON | gson | Gson + Type | native | `disableHtmlEscaping`; JsonWriter/Reader |
| jackson | JSON | jackson-module-kotlin | ObjectWriter/Reader | native | Reused ObjectMapper; no pretty-print |
| jackson-cbor | CBOR | jackson-dataformat-cbor | CBORMapper | native | IETF CBOR + Kotlin module |
| kaml | YAML | kaml | encodeToString | adapted | Same `@Serializable` core |
| kbson | BSON | kbson | dump/load | adapted | kotlinx BSON |
| kotlinx-cbor | CBOR | kotlinx-serialization-cbor | encodeToByteArray | adapted | Official Kotlin CBOR |
| kotlinx-hocon | HOCON | kotlinx-serialization-hocon | encodeToConfig | adapted | List wrap `{ items = [...] }` for N>1 |
| kotlinx-ion | Ion | ion-java | IonWriter/Reader | adapted | Amazon Ion binary via kotlinx encoder |
| kotlinx-json | JSON | kotlinx-serialization-json | encodeToStream | native | Compiler-generated serializers |
| kotlinx-properties | Properties | kotlinx-serialization-properties | encodeToStringMap | adapted | Then `java.util.Properties` store/load |
| kotlinx-protobuf | Schema | kotlinx-serialization-protobuf | encodeToByteArray | adapted | `@ProtoNumber` on domain types |
| kryo | Binary | kryo | writeClassAndObject | native | Reused Kryo + Output/Input |
| moshi-codegen | JSON | moshi-kotlin-codegen | generated JsonAdapter | native | KSP `@JsonClass` |
| moshi-reflect | JSON | moshi-kotlin | KotlinJsonAdapterFactory | native | Reflection; factory added first |
| msgpack | MessagePack | jackson-dataformat-msgpack | MessagePackMapper | native | Official msgpack-java + Kotlin module |
| obor | CBOR | obor | encodeToByteArray | adapted | kotlinx CBOR alternative |
| protobuf | Schema | protobuf-java | MessageLite wire | native | Java `newBuilder()` |
| protobuf-kotlin | Schema | protobuf-kotlin | Kotlin DSL + wire | native | `message { }` builders |
| protostuff | Binary | protostuff-runtime | RuntimeSchema | native | LinkedBuffer reuse; list APIs |
| thrift | Schema | libthrift | TCompactProtocol | adapted | Field ids match suite proto |
| tomlkt | TOML | tomlkt | encodeToString | adapted | List wrap `{ items = [...] }` for N>1 |

### Call-path contract (same idea as Java/Go/Python/Rust)

```text
prepare(fixture)                 # untimed: mappers, schemas, Fory register, proto convert
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
