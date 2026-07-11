# Java Serializer Benchmark

Part of the [Multi-Language Serializer Benchmark](../README.md).

## Serializers (18)

| Name | Category | Package | Call path notes |
|------|----------|---------|-----------------|
| jackson | JSON | jackson-databind | Reuse `ObjectMapper` + typed `ObjectWriter`/`ObjectReader` |
| gson | JSON | gson | Reuse `Gson`; `disableHtmlEscaping`; stream JsonWriter/Reader |
| fastjson2 | JSON | fastjson2 | `FieldBased` `toJSONBytes` / `parseObject` |
| dsl-json | JSON | dsl-json | Runtime `DslJson` + reused `JsonWriter` |
| moshi | JSON | moshi | Reuse `Moshi` + `JsonAdapter`; Okio `Buffer` |
| jsoniter | JSON | jsoniter | DYNAMIC mode + javassist; `JsonStream` / `JsonIterator` |
| kryo | Binary | kryo | Reuse Kryo + Output/Input; `writeClassAndObject` |
| fory | Binary | fory-core | Apache Fory JIT; register types once; `serialize`/`deserialize` |
| protostuff | Binary | protostuff-runtime | `RuntimeSchema` + `LinkedBuffer`; list APIs for batches |
| hessian | Binary | hessian | Hessian2 `writeObject` / `readObject` |
| java-serialization | Native | JDK | `ObjectOutputStream` / `ObjectInputStream` |
| msgpack | MessagePack | jackson-dataformat-msgpack | `MessagePackMapper` typed writer/reader |
| jackson-cbor | CBOR | jackson-dataformat-cbor | `CBORMapper` |
| jackson-smile | Binary JSON | jackson-dataformat-smile | `SmileMapper` |
| ion | Document binary | jackson-dataformat-ion | `IonObjectMapper` (binary Ion) |
| bson | Document | org.mongodb:bson | DocumentCodec wire; domain Document in prepare |
| protobuf | Schema | protobuf-java | Timed `toByteArray`/`parseFrom`; domain convert untimed |
| avro | Schema | avro | ReflectDatumWriter/Reader + BinaryEncoder reuse |

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

Requires **JDK 17+** (21 recommended) and **Maven 3.9+**.

```bash
./scripts/install-host-requirements.sh java
```

`LOG_DIR` may be a logs **root** (results under `$LOG_DIR/java/`).

Analysis: `analyze-benchmarks -l java`.

## Build notes

- Protobuf stubs are generated from `schemas/v2/protobuf/benchmark_v2.proto` via `protobuf-maven-plugin` at build time.
- Shaded jar: `target/serializer-benchmark-java-*-SNAPSHOT.jar`
