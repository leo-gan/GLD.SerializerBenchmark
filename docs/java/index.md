---
title: "Java"
---

Java
====

Java’s serialization landscape spans **JSON** (Jackson, Gson, Fastjson2, DSL-JSON, Moshi, jsoniter), **high-performance native binary** (Kryo, Apache Fory, Protostuff, Hessian2, `java.io`), **portable binary** (MessagePack, CBOR, Smile, Ion, BSON), and **schema/IDL** stacks (Protocol Buffers, Avro).

## Runtime

### What it is

Java compiles to **bytecode**, which is an intermediate instruction set. A **Java Virtual Machine (JVM)** then runs that bytecode. The JVM used here is HotSpot. It starts by interpreting bytecode and later **JIT**-compiles (just-in-time compiles) hot methods into native machine code. Unused objects are reclaimed by a **garbage collector**.

The **JDK** (Java Development Kit) includes both the compiler (`javac`) and the JVM. A **JRE** (Java Runtime Environment) is the virtual machine without the compiler. This suite needs a JDK because it compiles the runner before it times anything.

| | This suite |
|---|---|
| Target | Java **21** (`maven.compiler.release`) |
| Host JDK | JDK **17 or newer** is accepted. The install script places **Temurin 21**. |
| Build | Maven **3.9 or newer** |
| Prepare | `./scripts/install-host-requirements.sh java` installs into `~/.local/jdk-21` and `~/.local/maven` |
| Run | `java/scripts/run-benchmarks.sh` (`mvn package`) |
| Memory | JVM garbage collector (HotSpot) |

### What this suite runs

We compile and run as Java 21. [Kotlin](../kotlin/) uses the same kind of JVM. Java is built with Maven. Kotlin is built with the Gradle wrapper that lives inside `kotlin/`.

### What changes the numbers

The first repetitions pay for JIT warmup. Later repetitions are closer to the steady state the Dashboard reports. Reusing mappers and buffers, such as Jackson’s `ObjectMapper` and Kryo’s `Output`, keeps allocation down. Libraries that use reflection, and the built-in `java.io` serialization, allocate more. Those formats are also not portable to other languages.

These milliseconds cannot be ranked against C# or Python. The virtual machines are different.

### Suite-specific gotchas

**kryo**, **fory**, **hessian**, **protostuff**, and **java-serialization** encode JVM object graphs. They are not universal cross-language wires.

Some JSON codecs shorten floating-point digits. Fidelity checks use a numeric tolerance for that reason.

Stream mode is native only where the serializer table says so. Elsewhere the stream path is the bytes path written through a buffer.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`java/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/java/README.md). Oracle’s overview is [Java SE 21](https://docs.oracle.com/en/java/javase/21/). For garbage collection and latency, see [Latency tails and GC](../theory/301/latency-tails-and-gc.md).

## Benchmark runner

- Directory: `java/` (repository root)
- Output: monorepo `logs/java/YYYY-MM-DD-HHMMSS.csv` (`Language=java`, times in **nanoseconds**)
- Runner: `java/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`java/src/main/java/benchmark/serializers/Registry.java`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/java/src/main/java/benchmark/serializers/Registry.java)

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

Also: [`java/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/java/README.md). [Serialization Categories](../analysis/serialization_categories.md).

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
