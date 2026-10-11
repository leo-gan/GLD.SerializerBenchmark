# Experiment 12 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/12-format-vs-library/mojo/logs/mojo/2026-10-11-150847.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.66 | 1.94 | 2.62 | 114 | 0 | Avro | fastest | yes | 77 |
| mojo-json | 0.5.0 | 0.93 | 2.00 | 2.95 | 448 | 0 | JSON — mojo-json | slower | yes | 97 |
| mojo-protobuf | 0.7.0 | 1.25 | 1.84 | 3.07 | 155 | 0 | Protocol Buffers | slower | yes | 96 |
| mojo-flatbuffers | 0.4.0 | 3.24 | 1.56 | 4.79 | 408 | 0 | FlatBuffers | slower | yes | 85 |
| mojo-cbor | 0.8.0 | 1.35 | 3.80 | 5.11 | 332 | 0 | CBOR | slower | yes | 98 |
| EmberJson | 0.3.4 | 3.75 | 3.49 | 7.32 | 448 | 0 | JSON — EmberJson | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 1.57 | 8.02 | 9.62 | 448 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 23.7 | 55.0 | 78.9 | 485 | 0 | TOML | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

