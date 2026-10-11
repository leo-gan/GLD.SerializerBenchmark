# Experiment 12 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/12-format-vs-library/kotlin/logs/kotlin/2026-10-11-150843.csv`
**Language:** kotlin
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 21.3 | 22.1 | 44.8 | 440 | 230 | JSON — another library (Moshi) | fastest | yes | 82 |
| kotlinx-cbor | 1.8.1 | 33.5 | 31.2 | 64.2 | 335 | 222 | kotlinx.serialization — CBOR | slower | yes | 80 |
| kotlinx-protobuf | 1.8.1 | 37.3 | 40.3 | 78.7 | 155 | 174 | kotlinx.serialization — ProtoBuf | slower | yes | 85 |
| kotlinx-json | 1.8.1 | 30.8 | 54.4 | 87.1 | 440 | 230 | kotlinx.serialization — JSON | slower | yes | 86 |
| gson | 2.14.0 | 38.2 | 48.0 | 87.2 | 440 | 230 | JSON — another library (Gson) | slower | yes | 85 |
| jackson-cbor | 2.19.0 | 50.3 | 81.7 | 135 | 334 | 222 | Jackson — CBOR | slower | yes | 81 |
| jackson | 2.19.0 | 53.2 | 84.7 | 144 | 440 | 230 | Jackson — JSON | slower | yes | 84 |
| msgpack | 0.9.8 | 71.3 | 90.2 | 160 | 317 | 227 | MessagePack | slower | yes | 88 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 1 | 18.1 | 24.9 | 43.2 | real |
| kotlinx-cbor | 1 | 26.9 | 22.9 | 50.8 | copied |
| kotlinx-protobuf | 1 | 26.2 | 32.7 | 59.6 | copied |
| kotlinx-json | 1 | 27.0 | 41.5 | 68.4 | real |
| jackson-cbor | 1 | 36.3 | 56.0 | 92.9 | real |
| jackson | 1 | 37.1 | 60.5 | 99.9 | real |
| msgpack | 1 | 43.4 | 63.8 | 105 | real |
| gson | 1 | 56.6 | 55.4 | 113 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `kotlinx-cbor`, `kotlinx-protobuf`.

