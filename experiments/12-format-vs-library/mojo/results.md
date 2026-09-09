# Experiment 12 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/12-format-vs-library/mojo/logs/mojo/2026-09-09-132203.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.19 | 1.41 | 1.61 | 118 | 0 | Avro | fastest | yes | 85 |
| EmberJson | 0.3.4 | 0.50 | 1.56 | 2.07 | 452 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-protobuf | 0.6.0 | 0.54 | 1.69 | 2.23 | 157 | 0 | Protocol Buffers | slower | yes | 81 |
| mojo-cbor | 0.6.0 | 0.48 | 3.97 | 4.46 | 329 | 0 | CBOR | slower | yes | 77 |
| mojo-json | 0.2.0 | 2.18 | 2.84 | 5.03 | 452 | 0 | JSON — mojo-json | slower | yes | 78 |
| ehsanmok-json | 0.3.0 | 54.4 | 5.79 | 60.3 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 76 |
| mojo-toml | 0.9.1 | 21.7 | 52.1 | 73.8 | 489 | 0 | TOML | slower | yes | 74 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

