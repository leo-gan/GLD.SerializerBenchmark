# Experiment 12 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/12-format-vs-library/mojo/logs/mojo/2026-09-12-132737.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.20 | 1.37 | 1.57 | 118 | 0 | Avro | fastest | yes | 74 |
| mojo-json | 0.3.0 | 0.54 | 1.07 | 1.62 | 452 | 0 | JSON — mojo-json | close | yes | 80 |
| EmberJson | 0.3.4 | 0.49 | 1.57 | 2.07 | 452 | 0 | JSON — EmberJson | slower | yes | 81 |
| mojo-protobuf | 0.6.0 | 0.52 | 1.67 | 2.20 | 157 | 0 | Protocol Buffers | slower | yes | 82 |
| mojo-cbor | 0.6.0 | 0.48 | 3.87 | 4.35 | 329 | 0 | CBOR | slower | yes | 72 |
| ehsanmok-json | 0.3.1 | 0.69 | 6.26 | 6.95 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 69 |
| mojo-toml | 0.9.1 | 21.2 | 51.4 | 72.7 | 489 | 0 | TOML | slower | yes | 79 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-json`. Time/size front: `mojo-avro`.

