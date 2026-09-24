# Experiment 11 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/11-memory-vs-stream/mojo/logs/mojo/2026-09-23-181615.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.21 | 1.49 | 1.70 | 118 | 0 | Avro | fastest | yes | 83 |
| mojo-json | 0.3.0 | 0.57 | 1.14 | 1.72 | 452 | 0 | JSON — mojo-json | similar | yes | 77 |
| EmberJson | 0.3.4 | 0.54 | 1.62 | 2.17 | 452 | 0 | JSON — EmberJson | slower | yes | 82 |
| mojo-protobuf | 0.6.0 | 0.56 | 1.77 | 2.34 | 157 | 0 | Protocol Buffers | slower | yes | 74 |
| mojo-flatbuffers | 0.2.0 | 3.44 | 1.05 | 4.49 | 416 | 0 | FlatBuffers | slower | yes | 79 |
| mojo-cbor | 0.6.0 | 0.50 | 4.11 | 4.62 | 329 | 0 | CBOR | slower | yes | 82 |
| ehsanmok-json | 0.4.0 | 0.73 | 7.04 | 7.77 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 86 |
| mojo-toml | 0.9.1 | 22.8 | 55.3 | 78.1 | 489 | 0 | TOML | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-json`. Small gap: —. Time/size front: `mojo-avro`.

