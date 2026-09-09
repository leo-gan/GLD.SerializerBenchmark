# Experiment 3 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/03-one-language-store/mojo/logs/mojo/2026-09-09-132105.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.11 | 0.43 | 0.55 | 44 | 0 | Avro | fastest | yes | 96 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.45 | 0.55 | 50 | 0 | Protocol Buffers | similar | yes | 91 |
| EmberJson | 0.3.4 | 0.24 | 0.54 | 0.78 | 168 | 0 | JSON — EmberJson | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.17 | 1.31 | 1.47 | 124 | 0 | CBOR | slower | yes | 95 |
| mojo-json | 0.2.0 | 0.77 | 1.15 | 1.92 | 168 | 0 | JSON — mojo-json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2.07 | 10.2 | 12.2 | 167 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 10.4 | 3.22 | 13.6 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

