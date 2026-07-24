# Java

Java’s serialization landscape spans **JSON** (Jackson, Gson, Fastjson2, DSL-JSON, Moshi, jsoniter), **high-performance native binary** (Kryo, Apache Fory, Protostuff, Hessian2, `java.io`), **portable binary** (MessagePack, CBOR, Smile, Ion, BSON), and **schema/IDL** stacks (Protocol Buffers, Avro).

## Benchmark harness

- Directory: `java/` (repository root)
- Output: monorepo `logs/java/YYYY-MM-DD-HHMMSS.csv` (`Language=java`, times in **nanoseconds**)
- Runner: `java/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`java/src/main/java/benchmark/serializers/Registry.java`](../../java/src/main/java/benchmark/serializers/Registry.java)
- Requires **JDK 17+** (harness targets 21) and **Maven 3.9+**

## Serializers (18)

| Serializer | Category | Package | Native path | Stream | Notes |
|------------|----------|---------|-------------|--------|-------|
| jackson | JSON | jackson-databind | ObjectWriter/Reader | native | Reused ObjectMapper; no pretty-print |
| gson | JSON | gson | Gson + Type | native | `disableHtmlEscaping`; JsonWriter/Reader |
| fastjson2 | JSON | fastjson2 | FieldBased API | adapted | `toJSONBytes` / `parseObject` |
| dsl-json | JSON | dsl-json | runtime DslJson | native | Reused JsonWriter buffer |
| moshi | JSON | moshi | JsonAdapter | native | Okio Buffer; Square stack |
| jsoniter | JSON | jsoniter | DYNAMIC + javassist | adapted | `JsonStream` / `JsonIterator` |
| kryo | Binary | kryo | writeClassAndObject | native | Reused Kryo + Output/Input |
| fory | Binary | fory-core | serialize/deserialize | adapted | Apache Fory; register types before freeze |
| protostuff | Binary | protostuff-runtime | RuntimeSchema | native | LinkedBuffer reuse; list APIs |
| hessian | Binary | hessian | Hessian2 write/readObject | native | Dubbo-era RPC binary |
| java-serialization | Native | JDK | ObjectOutputStream | native | Language baseline |
| msgpack | MessagePack | jackson-dataformat-msgpack | MessagePackMapper | native | Official msgpack-java binding |
| jackson-cbor | CBOR | jackson-dataformat-cbor | CBORMapper | native | IETF CBOR |
| jackson-smile | Binary JSON | jackson-dataformat-smile | SmileMapper | native | Elasticsearch ecosystem |
| ion | Document | jackson-dataformat-ion | IonObjectMapper | native | Amazon Ion binary |
| bson | Document | org.mongodb:bson | DocumentCodec | adapted | Domain→Document in prepare |
| protobuf | Schema | protobuf-java | MessageLite wire | native | Domain convert untimed |
| avro | Schema | avro | ReflectDatum* | native | Schema once; encoder reuse |

### Call-path contract (same idea as Go/Python/Rust)

```text
prepare(fixture)                 # untimed: mappers, schemas, Fory register, proto convert
for rep:
  serialize_bytes / stream       # timed
  deserialize_bytes / stream     # timed (codec only)
  toDomain (if needed)           # untimed (e.g. protobuf Message → model)
  fidelity(expected, actual)     # untimed
```

### Suite data types

Type ids: `message`, `document`, `telemetry`, `strings`, `event`.

### Caveats

- **java-serialization**, **kryo**, **fory**, **hessian**, **protostuff** are not universal cross-language wire formats.
- **protobuf** domain conversion is outside the timer (fair codec measurement).
- Stream mode is **native** only where noted; others are adapted bytes+buffer.
- Some JSON codecs (e.g. **jsoniter**) shorten floating-point digits; fidelity uses float tolerance.

Also: [`java/README.md`](../../java/README.md). [Serialization Categories](../analysis/serialization_categories.md).

## Design choices

1. **Prepare outside the loop** — ObjectMapper/ObjectWriter, Kryo buffers, Fory type registration, Avro schema, protobuf messages.
2. **Optimal APIs** — library-recommended encode/decode; no pretty-print.
3. **Dual mode** — `bytes` and `stream` with `StreamMode` metadata.
4. **Shared domain types** in `benchmark.model.v2` with public fields for reflection codecs.
