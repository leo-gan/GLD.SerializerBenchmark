---
title: "Mojo"
---

Mojo
====

Mojo’s serialization stack is still young. This runner times **pure-Mojo** libraries: EmberJson and ehsanmok/json for JSON, mojo-toml for TOML, and the leo-gan **gld-** libraries for CBOR, Protocol Buffers, and Avro.

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

The runner is timed in an optimized `mojo run` / `mojo build` path. EmberJson uses official reflection `serialize` / `deserialize`. ehsanmok/json times official `dumps` / `loads` on a `Value` tree (its reflection API does not cover `Int32` or `List[struct]`). CBOR and Avro time `encode` / `decode` on suite types that implement `CborDatum` / `AvroDatum`. Protobuf converts suite objects to generated messages **outside** the timer, then times `encode` / `decode`.

### What changes the numbers

Mojo 1.0 is a young compiler. A nightly compiler or a different pixi lock can move these numbers a lot. CBOR and Protobuf are compiled from vendored sources with renamed internal packages (`cbor_runtime`, `pb_runtime`, …) so they can share one process with mojo-avro, which owns the conda `runtime` / `wire` / `json` module names.

### Suite-specific gotchas

I/O mode is **bytes only**. None of the registered libraries expose a native stream API that is not a label on the bytes path.

There is no native MessagePack, BSON, YAML, XML, or FlatBuffers library in this first wave. Apache Arrow / Parquet (columnar file formats) are not object serializers for these fixtures.

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
| EmberJson | JSON | emberjson 0.3.4 | bytes only | Reflection `serialize` / `deserialize` |
| ehsanmok-json | JSON | ehsanmok/json 0.3.0 | bytes only | `dumps` / `loads` on `Value` (CPU parser) |
| mojo-cbor | Binary | leo-gan/gld-cbor 0.6.0 | bytes only | `CborDatum` encode / decode |
| mojo-protobuf | Schema | leo-gan/gld-protobuf 0.6.0 | bytes only | Generated from suite `.proto` |
| mojo-avro | Schema | leo-gan/gld-avro 0.4.0 | bytes only | `AvroDatum` encode / decode |
| mojo-toml | Text | DataBooth/mojo-toml 0.9.1 | bytes only | `to_toml` / `parse` |

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
- ehsanmok/json is vendored as `ehsanmok_json` so it does not collide with mojo-avro’s `json` module. GPU/`max` is stubbed; the timed path is the default CPU parser.
- Apache Arrow (marrow) and Parquet are columnar file/table APIs, not object codecs for these fixtures.
- `f0cii/mojo-csv` last moved in 2024 (Magic-era nightly) and does not compile on Mojo 1.0.
- `forfudan/decimojo` is a decimal-math library. Its old tomlmojo parser is not a standalone serializer.

Also: [`mojo/README.md`](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/mojo/README.md).

## Numbers

Measured numbers for this language live on the
[Dashboard](../dashboard/?lang=mojo&data=document@n=1&mode=bytes)
(pre-filtered). Claim level is **L1** (one machine, one session) —
see [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).
