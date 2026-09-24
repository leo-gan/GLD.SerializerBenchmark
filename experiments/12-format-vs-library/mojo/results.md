# Experiment 12 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/12-format-vs-library/mojo/logs/mojo/2026-09-23-181626.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.21 | 1.54 | 1.75 | 118 | 0 | Avro | fastest | yes | 77 |
| mojo-json | 0.3.0 | 0.60 | 1.18 | 1.78 | 452 | 0 | JSON — mojo-json | close | yes | 74 |
| EmberJson | 0.3.4 | 0.55 | 1.71 | 2.25 | 452 | 0 | JSON — EmberJson | slower | yes | 84 |
| mojo-protobuf | 0.6.0 | 0.58 | 1.84 | 2.43 | 157 | 0 | Protocol Buffers | slower | yes | 71 |
| mojo-flatbuffers | 0.2.0 | 3.56 | 1.09 | 4.65 | 416 | 0 | FlatBuffers | slower | yes | 73 |
| mojo-cbor | 0.6.0 | 0.53 | 4.32 | 4.85 | 329 | 0 | CBOR | slower | yes | 67 |
| ehsanmok-json | 0.4.0 | 0.78 | 7.27 | 8.05 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 69 |
| mojo-toml | 0.9.1 | 23.5 | 57.1 | 80.6 | 489 | 0 | TOML | slower | yes | 64 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-json`. Time/size front: `mojo-avro`.

