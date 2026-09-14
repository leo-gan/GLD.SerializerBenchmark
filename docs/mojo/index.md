---
title: "Mojo"
---

Mojo
====

Mojo’s serialization stack is still young. This runner times **pure-Mojo** libraries: EmberJson and ehsanmok/json for JSON, mojo-toml for TOML, and the leo-gan **gld-** libraries for JSON, CBOR, Protocol Buffers, Avro, YAML, and MessagePack.

## Runtime

### What it is

Mojo compiles to **native machine code**. This suite targets **Mojo 1.0.0** on Linux x86_64 through a `pixi` environment (`mojo/pixi.toml`).

| | This suite |
|---|---|
| Tools | Mojo **1.0.0** via `pixi` (`https://conda.modular.com/max`) |
| Build | `pixi run mojo run -I src -I vendor/... src/main.mojo` |
| Prepare | `./scripts/install-host-requirements.sh mojo` |
| Run | `mojo/scripts/run-benchmarks.sh` |
| Memory | Manual ownership / compiler-managed, not a tracing GC |

### What this suite runs

The runner is timed in an optimized `mojo run` / `mojo build` path. EmberJson uses official reflection `serialize` / `deserialize`. ehsanmok/json times official `serialize_json` on suite types (v0.3.1 reflects `Int32` and `List[struct]` on the write path) except `telemetry`, which builds a `Value` tree because `serialize_json` mis-matches `List[Float64]`. Decode is `loads` plus a `Value` walk (`List[struct]` deserialize is still unsupported). CBOR and Avro time `encode` / `decode` on suite types that implement `CborDatum` / `AvroDatum`. Protobuf converts suite objects to generated messages **outside** the timer, then times `encode` / `decode`.

### What changes the numbers

Mojo 1.0 is a young compiler. A nightly compiler or a different pixi lock can move these numbers a lot. CBOR and Protobuf are compiled from vendored sources with renamed internal packages (`cbor_runtime`, `pb_runtime`, …) so they can share one process with mojo-avro, which owns the conda `runtime` / `wire` / `json` module names.

### Suite-specific gotchas

I/O mode is **bytes only**. None of the registered libraries expose a native stream API that is not a label on the bytes path.

There is no native BSON, XML, or FlatBuffers library in this wave. Apache Arrow / Parquet (columnar file formats) are not object serializers for these fixtures. `gld-toml` is not published yet, so TOML stays on DataBooth/mojo-toml.

These times cannot be ranked against another language.

### Where to go next

The steps to install the toolchain and run the benchmark are in [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md). Language overview: [Mojo](https://www.modular.com/mojo).

## Benchmark runner

- Directory: `mojo/`
- Output: `logs/mojo/YYYY-MM-DD-HHMMSS.csv` (`Language=mojo`, times in **nanoseconds**)
- Runner: `mojo/scripts/run-benchmarks.sh {smoke|all-single|full|research}`
- Registration: [`mojo/src/bench/runner.mojo`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/src/bench/runner.mojo)

## Serializers

| Serializer | Category | Package | Stream | Notes |
|------------|----------|---------|--------|-------|
| [EmberJson](https://github.com/bgreni/EmberJson) | JSON | emberjson 0.3.4 | bytes only | Reflection `serialize` / `deserialize` |
| [ehsanmok-json](https://github.com/ehsanmok/json) | JSON | ehsanmok/json 0.4.0 | bytes only | `serialize_json` encode; `loads` + Value walk decode (CPU parser) |
| [mojo-json](https://github.com/leo-gan/gld-json) | JSON | leo-gan/gld-json 0.4.0 | bytes only | Typed WireWriter / WireReader (vendored as `gldjson`) |
| [mojo-cbor](https://github.com/leo-gan/gld-cbor) | Binary | leo-gan/gld-cbor 0.7.0 | bytes only | `CborDatum` encode / decode |
| [mojo-protobuf](https://github.com/leo-gan/gld-protobuf) | Schema | leo-gan/gld-protobuf 0.6.0 | bytes only | Generated from suite `.proto` |
| [mojo-avro](https://github.com/leo-gan/gld-avro) | Schema | leo-gan/gld-avro 0.4.0 | bytes only | `AvroDatum` encode / decode |
| [mojo-toml](https://github.com/DataBooth/mojo-toml) | Text | DataBooth/mojo-toml 0.9.1 | bytes only | `to_toml` / `parse` |
| [gld-yaml](https://github.com/leo-gan/gld-yaml) | Text | [leo-gan/gld-yaml](https://github.com/leo-gan/gld-yaml) 0.5.0 | bytes only | `yaml.encode` / `yaml.decode` on suite types |
| [mojo-msgpack](https://github.com/leo-gan/gld-messagepack) | Binary | leo-gan/gld-messagepack 0.3.0 | bytes only | WireWriter / WireReader |

### Specifics

Why each library exists, what problem it was written to solve, and how. Names link to the source repository (or the stdlib / in-tree path this suite times). A version after the name is the last measured `SerializerVersion` from this suite's latest bench.

#### [EmberJson](https://github.com/bgreni/EmberJson) · `0.3.4`

EmberJson is a Mojo JSON library using language reflection. Mojo is a young language; EmberJson exists to give it a community JSON serialize/deserialize path. This row times that reflection API.

#### [ehsanmok-json](https://github.com/ehsanmok/json) · `0.4.0`

ehsanmok/json is a Mojo JSON parser/serializer. It was written to give Mojo a JSON stack with a Value tree and a `serialize_json` path. Decode in this suite is `loads` plus a Value walk.

#### [mojo-json](https://github.com/leo-gan/gld-json) · `0.3.0`

gld-json (leo-gan) is a typed JSON WireWriter/Reader for Mojo. It was created because Mojo lacked a suite-ready, typed JSON codec aligned with this benchmark's domain types.

#### [mojo-cbor](https://github.com/leo-gan/gld-cbor) · `0.6.0`

gld-cbor (leo-gan) implements CBOR for Mojo via a `CborDatum` trait. CBOR is the IETF binary JSON-like format. The library exists to give Mojo a first-class CBOR encode/decode.

#### [mojo-protobuf](https://github.com/leo-gan/gld-protobuf) · `0.6.0`

gld-protobuf (leo-gan) is a Protocol Buffers implementation for Mojo. Protobuf exists as a language-neutral IDL. This library generates Mojo from the suite `.proto` and times encode/decode.

#### [mojo-avro](https://github.com/leo-gan/gld-avro) · `0.4.0`

gld-avro (leo-gan) implements Apache Avro for Mojo via `AvroDatum`. Avro exists for compact, schema-driven records. The library gives Mojo that encoding.

#### [mojo-toml](https://github.com/DataBooth/mojo-toml) · `0.9.1`

DataBooth/mojo-toml is a TOML library for Mojo. TOML exists as an obvious config language. This is the published Mojo TOML implementation (`gld-toml` is not out yet).

#### [gld-yaml](https://github.com/leo-gan/gld-yaml) · `0.2.0`

gld-yaml (leo-gan) implements YAML encode/decode for Mojo. YAML exists as a human-friendly config language. The library was written so Mojo can speak YAML on suite types.

#### [mojo-msgpack](https://github.com/leo-gan/gld-messagepack) · `0.3.0`

gld-messagepack (leo-gan) is a MessagePack WireWriter/Reader for Mojo. MessagePack exists as compact binary JSON. The library gives Mojo that format.

### Call-path contract

```text
prepare(fixture)                 # untimed: schema, generated message
serialize_bytes                  # timed
deserialize_bytes                # timed (+ domain conversion for protobuf)
fidelity                         # untimed, float-tolerant
```

### Caveats

- Stream mode is not claimed (`stream_policy: bytes_only`).
- EmberJson 0.3.4 is the modular-community package. The newer `from_json` / `to_json` API on EmberJson main is not what this row times.
- ehsanmok/json is vendored as `ehsanmok_json` so it does not collide with mojo-avro’s `json` module. GPU/`max` is stubbed; the timed path is the default CPU parser. v0.3.1 added `Value.object()` / `Value.array()` so adapters no longer parse `"{}"` / `"[]"` per node. This suite times **v0.4.0**.
- Apache Arrow (marrow) and Parquet are columnar file/table APIs, not object codecs for these fixtures.
- `f0cii/mojo-csv` last moved in 2024 (Magic-era nightly) and does not compile on Mojo 1.0.
- `forfudan/decimojo` is a decimal-math library. Its old tomlmojo parser is not a standalone serializer.

Also: [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=mojo&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
