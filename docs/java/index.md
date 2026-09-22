---
title: "Java"
---

# Java

Java’s serialization landscape spans **JSON** (Jackson, Gson, Fastjson2, DSL-JSON, Moshi, jsoniter), **high-performance native binary** (Kryo, Apache Fory, Protostuff, Hessian2, `java.io`), **portable binary** (MessagePack, CBOR, Smile, Ion, BSON), and **schema/IDL** stacks (Protocol Buffers, Avro).

## Runtime

### What it is

Java compiles to **bytecode**, which is an intermediate instruction set. A **Java Virtual Machine (JVM)** then runs that bytecode. The JVM used here is HotSpot. It starts by interpreting bytecode and later **JIT**-compiles (just-in-time compiles) hot methods into native machine code. Unused objects are reclaimed by a **garbage collector**.

The **JDK** (Java Development Kit) includes both the compiler (`javac`) and the JVM. A **JRE** (Java Runtime Environment) is the virtual machine without the compiler. This suite needs a JDK because it compiles the runner before it times anything.

|          | This suite                                                                                         |
| -------- | -------------------------------------------------------------------------------------------------- |
| Target   | Java **21** (`maven.compiler.release`)                                                             |
| Host JDK | JDK **17 or newer** is accepted. The install script places **Temurin 21**.                         |
| Build    | Maven **3.9 or newer**                                                                             |
| Prepare  | `./scripts/install-host-requirements.sh java` installs into `~/.local/jdk-21` and `~/.local/maven` |
| Run      | `java/scripts/run-benchmarks.sh` (`mvn package`)                                                   |
| Memory   | JVM garbage collector (HotSpot)                                                                    |

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

| Serializer                                                               | Category    | Package                    | Native path               | Stream  | Notes                                     |
| ------------------------------------------------------------------------ | ----------- | -------------------------- | ------------------------- | ------- | ----------------------------------------- |
| [avro](https://github.com/apache/avro)                                   | Schema      | avro                       | ReflectDatum\*            | native  | Schema once; encoder reuse                |
| [bson](https://github.com/mongodb/mongo-java-driver)                     | Document    | org.mongodb:bson           | DocumentCodec             | adapted | Domain→Document in prepare                |
| [dsl-json](https://github.com/ngs-doo/dsl-json)                          | JSON        | dsl-json                   | runtime DslJson           | native  | Reused JsonWriter buffer                  |
| [fastjson2](https://github.com/alibaba/fastjson2)                        | JSON        | fastjson2                  | FieldBased API            | adapted | `toJSONBytes` / `parseObject`             |
| [fory](https://github.com/apache/fory)                                   | Binary      | fory-core                  | serialize/deserialize     | adapted | Apache Fory; register types before freeze |
| [gson](https://github.com/google/gson)                                   | JSON        | gson                       | Gson + Type               | native  | `disableHtmlEscaping`; JsonWriter/Reader  |
| [hessian](https://github.com/ebourg/hessian)                             | Binary      | hessian                    | Hessian2 write/readObject | native  | Dubbo-era RPC binary                      |
| [ion](https://github.com/amazon-ion/ion-java)                            | Document    | jackson-dataformat-ion     | IonObjectMapper           | native  | Amazon Ion binary                         |
| [jackson](https://github.com/FasterXML/jackson-databind)                 | JSON        | jackson-databind           | ObjectWriter/Reader       | native  | Reused ObjectMapper; no pretty-print      |
| [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary)  | CBOR        | jackson-dataformat-cbor    | CBORMapper                | native  | IETF CBOR                                 |
| [jackson-smile](https://github.com/FasterXML/jackson-dataformats-binary) | Binary JSON | jackson-dataformat-smile   | SmileMapper               | native  | Elasticsearch ecosystem                   |
| [java-serialization](https://github.com/openjdk/jdk)                     | Native      | JDK                        | ObjectOutputStream        | native  | Language baseline                         |
| [jsoniter](https://github.com/json-iterator/java)                        | JSON        | jsoniter                   | DYNAMIC + javassist       | adapted | `JsonStream` / `JsonIterator`             |
| [kryo](https://github.com/EsotericSoftware/kryo)                         | Binary      | kryo                       | writeClassAndObject       | native  | Reused Kryo + Output/Input                |
| [moshi](https://github.com/square/moshi)                                 | JSON        | moshi                      | JsonAdapter               | native  | Okio Buffer; Square stack                 |
| [msgpack](https://github.com/msgpack/msgpack-java)                       | MessagePack | jackson-dataformat-msgpack | MessagePackMapper         | native  | Official msgpack-java binding             |
| [protobuf](https://github.com/protocolbuffers/protobuf)                  | Schema      | protobuf-java              | MessageLite wire          | native  | Domain convert untimed                    |
| [protostuff](https://github.com/protostuff/protostuff)                   | Binary      | protostuff-runtime         | RuntimeSchema             | native  | LinkedBuffer reuse; list APIs             |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [avro](https://github.com/apache/avro) · `1.12.1`

Apache Avro was created for Hadoop-era pipelines: compact binary records with the schema stored out of band. Official language runtimes implement that encoding. This row times the platform's Avro library.

#### [bson](https://github.com/mongodb/mongo-java-driver) · `5.5.1`

BSON (Binary JSON) was created for MongoDB so documents could be stored and traversed without a text parse. Official language drivers implement that spec. This row times that library's serialize/deserialize path.

#### [dsl-json](https://github.com/ngs-doo/dsl-json) · `2.0.2`

dsl-json was written for very high-performance JSON on the JVM with compile-time binding. The problem was reflection mappers allocating too much. It reuses a JsonWriter buffer on the hot path.

#### [fastjson2](https://github.com/alibaba/fastjson2) · `2.0.57`

fastjson2 is Alibaba's rewrite of fastjson for high-performance JSON on the JVM. The problem was JSON cost in large Java services (and security issues in fastjson 1.x). fastjson2 solves it with a new FieldBased API.

#### [fory](https://github.com/apache/fory) · `1.3.0`

Apache Fory (formerly Fury) was created for high-performance, cross-language serialization. The problem was that JVM-centric binary codecs and slow portable formats left a gap. Fory registers types and serializes with a compact binary protocol.

#### [gson](https://github.com/google/gson) · `2.14.0`

Gson was created at Google to convert Java objects to JSON and back with a simple API. The problem was boilerplate-heavy Java JSON. Gson solves it with reflection over POJOs and a JsonWriter/Reader stream API.

#### [hessian](https://github.com/ebourg/hessian) · `4.0.66`

Hessian is Caucho's compact binary web-service protocol from the Dubbo/Caucho era. The problem was SOAP/XML RPC overhead. Hessian2 write/readObject is the binary that this row times.

#### [ion](https://github.com/amazon-ion/ion-java) · `2.19.0`

Amazon Ion was created as a rich, self-describing superset of JSON (text and binary) for Amazon services. Official Ion libraries and Jackson Ion modules implement that model.

#### [jackson](https://github.com/FasterXML/jackson-databind) · `2.19.0`

Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack).

#### [jackson-cbor](https://github.com/FasterXML/jackson-dataformats-binary) · `2.19.0`

Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack). This row times Jackson's CBOR mapper.

#### [jackson-smile](https://github.com/FasterXML/jackson-dataformats-binary) · `2.19.0`

Jackson was created as the standard data-binding toolkit for Java JSON (and later many binary/text formats). The problem was that Java needed a fast, annotation-driven mapper for REST and services. Jackson solves it with ObjectMapper / ObjectWriter and format modules (CBOR, Smile, YAML, Ion, MessagePack). This row times Jackson's Smile (binary JSON) mapper.

#### [java-serialization](https://github.com/openjdk/jdk) · `21.0.11`

Java Object Serialization (`ObjectOutputStream`) is the language's built-in graph serializer. It exists so the JVM can persist and RMI Java objects. It is not a portable wire format.

#### [jsoniter](https://github.com/json-iterator/java) · `0.9.23`

jsoniter for Java was created as a high-performance JSON library with an optional codegen path. The problem was Jackson/Gson overhead. This suite uses DYNAMIC mode plus javassist.

#### [kryo](https://github.com/EsotericSoftware/kryo) · `5.6.2`

Kryo was written as a fast binary serializer for JVM object graphs (games, caches, RPC). The problem was Java serialization being slow and verbose. Kryo solves it with a compact binary and reusable Output/Input.

#### [moshi](https://github.com/square/moshi) · `1.15.2`

Moshi was created at Square as a modern JSON library for Java and Android, successor-minded to Gson. The problem was Gson's older model on Android. Moshi solves it with JsonAdapter, codegen or reflection, and Okio.

#### [msgpack](https://github.com/msgpack/msgpack-java) · `0.9.8`

msgpack-java is the official MessagePack library for the JVM. MessagePack exists as compact binary JSON. This suite times the Jackson MessagePack mapper on that stack.

#### [protobuf](https://github.com/protocolbuffers/protobuf) · `4.35.0`

Protocol Buffers were created at Google so many languages could share a compact, evolving binary contract without hand-written parsers. The problem was ad-hoc binary formats and verbose XML. Protobuf solves it with an IDL, generated code, and a documented tag/length wire format.

#### [protostuff](https://github.com/protostuff/protostuff) · `1.8.0`

protostuff was created to serialize Java objects with protobuf-like efficiency without writing `.proto` files. The problem was protobuf's IDL tax for internal graphs. Runtime schemas and LinkedBuffer reuse are the solution this row times.

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
