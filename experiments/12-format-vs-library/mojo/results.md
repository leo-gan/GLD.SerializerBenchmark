# Experiment 12 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/12-format-vs-library/mojo/logs/mojo/2026-09-08-155424.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.47 | 1.67 | 118 | 0 | Avro | fastest | yes | 80 |
| EmberJson | 0.3.4 | 0.51 | 1.64 | 2.15 | 452 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-protobuf | 0.6.0 | 0.54 | 1.76 | 2.31 | 157 | 0 | Protocol Buffers | slower | yes | 86 |
| mojo-cbor | 0.6.0 | 0.50 | 4.15 | 4.66 | 329 | 0 | CBOR | slower | yes | 77 |
| ehsanmok-json | 0.3.0 | 56.5 | 6.10 | 62.6 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 74 |
| mojo-toml | 0.9.1 | 22.9 | 55.6 | 78.5 | 489 | 0 | TOML | slower | yes | 74 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

