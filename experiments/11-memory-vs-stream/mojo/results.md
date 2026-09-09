# Experiment 11 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/11-memory-vs-stream/mojo/logs/mojo/2026-09-09-132157.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.19 | 1.40 | 1.60 | 118 | 0 | Avro | fastest | yes | 96 |
| EmberJson | 0.3.4 | 0.49 | 1.55 | 2.05 | 452 | 0 | JSON — EmberJson | slower | yes | 90 |
| mojo-protobuf | 0.6.0 | 0.52 | 1.69 | 2.21 | 157 | 0 | Protocol Buffers | slower | yes | 83 |
| mojo-cbor | 0.6.0 | 0.48 | 3.93 | 4.42 | 329 | 0 | CBOR | slower | yes | 94 |
| mojo-json | 0.2.0 | 2.19 | 2.85 | 5.03 | 452 | 0 | JSON — mojo-json | slower | yes | 91 |
| ehsanmok-json | 0.3.0 | 54.5 | 5.83 | 60.4 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 21.6 | 52.0 | 73.7 | 489 | 0 | TOML | slower | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

