# Experiment 11 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/11-memory-vs-stream/mojo/logs/mojo/2026-09-12-132729.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.41 | 1.61 | 118 | 0 | Avro | fastest | yes | 79 |
| mojo-json | 0.3.0 | 0.56 | 1.12 | 1.70 | 452 | 0 | JSON — mojo-json | slower | yes | 88 |
| EmberJson | 0.3.4 | 0.51 | 1.60 | 2.11 | 452 | 0 | JSON — EmberJson | slower | yes | 87 |
| mojo-protobuf | 0.6.0 | 0.52 | 1.71 | 2.23 | 157 | 0 | Protocol Buffers | slower | yes | 84 |
| mojo-cbor | 0.6.0 | 0.47 | 3.95 | 4.43 | 329 | 0 | CBOR | slower | yes | 89 |
| ehsanmok-json | 0.3.1 | 0.71 | 6.40 | 7.14 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 86 |
| mojo-toml | 0.9.1 | 21.5 | 52.0 | 73.5 | 489 | 0 | TOML | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

