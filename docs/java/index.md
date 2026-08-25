---
title: "Java"
---

Java
====

Java’s serialization landscape spans **JSON** (Jackson, Gson, Fastjson2, DSL-JSON, Moshi, jsoniter), **high-performance native binary** (Kryo, Apache Fory, Protostuff, Hessian2, `java.io`), **portable binary** (MessagePack, CBOR, Smile, Ion, BSON), and **schema/IDL** stacks (Protocol Buffers, Avro).

## Benchmark runner

- Directory: `java/` (repository root)
- Output: monorepo `logs/java/YYYY-MM-DD-HHMMSS.csv` (`Language=java`, times in **nanoseconds**)
- Runner: `java/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`java/src/main/java/benchmark/serializers/Registry.java`](../../java/src/main/java/benchmark/serializers/Registry.java)
- Requires **JDK 17+** (benchmark runner targets 21) and **Maven 3.9+**

## Serializers

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| avro | Schema | avro | ReflectDatum* | native | Schema once; encoder reuse |
| bson | Document | org.mongodb:bson | DocumentCodec | adapted | Domain→Document in prepare |
| dsl-json | JSON | dsl-json | runtime DslJson | native | Reused JsonWriter buffer |
| fastjson2 | JSON | fastjson2 | FieldBased API | adapted | `toJSONBytes` / `parseObject` |
| fory | Binary | fory-core | serialize/deserialize | adapted | Apache Fory; register types before freeze |
| gson | JSON | gson | Gson + Type | native | `disableHtmlEscaping`; JsonWriter/Reader |
| hessian | Binary | hessian | Hessian2 write/readObject | native | Dubbo-era RPC binary |
| ion | Document | jackson-dataformat-ion | IonObjectMapper | native | Amazon Ion binary |
| jackson | JSON | jackson-databind | ObjectWriter/Reader | native | Reused ObjectMapper; no pretty-print |
| jackson-cbor | CBOR | jackson-dataformat-cbor | CBORMapper | native | IETF CBOR |
| jackson-smile | Binary JSON | jackson-dataformat-smile | SmileMapper | native | Elasticsearch ecosystem |
| java-serialization | Native | JDK | ObjectOutputStream | native | Language baseline |
| jsoniter | JSON | jsoniter | DYNAMIC + javassist | adapted | `JsonStream` / `JsonIterator` |
| kryo | Binary | kryo | writeClassAndObject | native | Reused Kryo + Output/Input |
| moshi | JSON | moshi | JsonAdapter | native | Okio Buffer; Square stack |
| msgpack | MessagePack | jackson-dataformat-msgpack | MessagePackMapper | native | Official msgpack-java binding |
| protobuf | Schema | protobuf-java | MessageLite wire | native | Domain convert untimed |
| protostuff | Binary | protostuff-runtime | RuntimeSchema | native | LinkedBuffer reuse; list APIs |

### Call-path contract (same idea as Go/Python/Rust)

```text
prepare(fixture)                 # untimed: mappers, schemas, Fory register, proto convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  toDomain (if needed)           # untimed (e.g. protobuf Message → model)
  fidelity(expected, actual)     # untimed
```

### Caveats

- **java-serialization**, **kryo**, **fory**, **hessian**, **protostuff** are not universal cross-language wire formats.
- **protobuf** domain conversion is outside the timer (fair codec measurement).
- Stream mode is **native** only where noted; others are adapted bytes+buffer.
- Some JSON codecs (e.g. **jsoniter**) shorten floating-point digits; fidelity uses float tolerance.

Also: [`java/README.md`](../../java/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=java&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).

## Design choices

1. **Prepare outside the loop** — ObjectMapper/ObjectWriter, Kryo buffers, Fory type registration, Avro schema, protobuf messages.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Shared domain types** in `benchmark.model.v2` with public fields for reflection codecs.
