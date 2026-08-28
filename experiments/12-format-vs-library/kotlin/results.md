# Experiment 12 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/12-format-vs-library/kotlin/logs/kotlin/2026-08-27-181810.csv`
**Language:** kotlin
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 23.4 | 24.9 | 48.2 | 440 | 230 | JSON — another library (Moshi) | fastest | yes | 83 |
| kotlinx-cbor | 1.8.1 | 37.3 | 31.5 | 70.0 | 335 | 222 | kotlinx.serialization — CBOR | slower | yes | 89 |
| kotlinx-protobuf | 1.8.1 | 36.2 | 42.2 | 76.6 | 155 | 174 | kotlinx.serialization — ProtoBuf | slower | yes | 94 |
| kotlinx-json | 1.8.1 | 37.4 | 60.0 | 95.3 | 440 | 230 | kotlinx.serialization — JSON | slower | yes | 88 |
| gson | 2.12.1 | 47.6 | 52.1 | 100.0 | 440 | 230 | JSON — another library (Gson) | slower | yes | 88 |
| jackson-cbor | 2.18.3 | 55.8 | 86.5 | 144 | 334 | 222 | Jackson — CBOR | slower | yes | 84 |
| jackson | 2.18.3 | 54.1 | 87.1 | 144 | 440 | 230 | Jackson — JSON | slower | yes | 85 |
| msgpack | 0.9.8 | 75.9 | 94.9 | 170 | 317 | 227 | MessagePack | slower | yes | 85 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| moshi-codegen | 1 | 11.9 | 19.0 | 31.4 | real |
| kotlinx-cbor | 1 | 26.1 | 20.9 | 46.8 | copied |
| kotlinx-protobuf | 1 | 21.7 | 26.1 | 49.2 | copied |
| kotlinx-json | 1 | 25.9 | 41.2 | 67.2 | real |
| jackson-cbor | 1 | 32.2 | 54.4 | 86.2 | real |
| jackson | 1 | 31.7 | 56.9 | 88.4 | real |
| gson | 1 | 47.9 | 45.3 | 97.7 | real |
| msgpack | 1 | 42.4 | 59.1 | 100 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `moshi-codegen`. Small gap: —. Time/size front: `moshi-codegen`, `kotlinx-cbor`, `kotlinx-protobuf`.

