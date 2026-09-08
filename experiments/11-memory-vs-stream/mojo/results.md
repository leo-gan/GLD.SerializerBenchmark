# Experiment 11 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/11-memory-vs-stream/mojo/logs/mojo/2026-09-08-155418.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.43 | 1.63 | 118 | 0 | Avro | fastest | yes | 86 |
| EmberJson | 0.3.4 | 0.51 | 1.60 | 2.12 | 452 | 0 | JSON — EmberJson | slower | yes | 85 |
| mojo-protobuf | 0.6.0 | 0.54 | 1.74 | 2.28 | 157 | 0 | Protocol Buffers | slower | yes | 80 |
| mojo-cbor | 0.6.0 | 0.48 | 4.05 | 4.54 | 329 | 0 | CBOR | slower | yes | 76 |
| ehsanmok-json | 0.3.0 | 55.4 | 6.04 | 61.4 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 83 |
| mojo-toml | 0.9.1 | 22.4 | 54.4 | 76.9 | 489 | 0 | TOML | slower | yes | 78 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

