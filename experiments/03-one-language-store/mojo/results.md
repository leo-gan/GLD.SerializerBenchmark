# Experiment 3 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/03-one-language-store/mojo/logs/mojo/2026-09-08-155330.csv`
**Language:** mojo
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.10 | 0.45 | 0.55 | 44 | 0 | Avro | fastest | yes | 85 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.47 | 0.57 | 50 | 0 | Protocol Buffers | close | yes | 82 |
| EmberJson | 0.3.4 | 0.28 | 0.57 | 0.85 | 168 | 0 | JSON — EmberJson | slower | yes | 92 |
| mojo-cbor | 0.6.0 | 0.18 | 1.35 | 1.53 | 124 | 0 | CBOR | slower | yes | 81 |
| mojo-toml | 0.9.1 | 2.13 | 10.7 | 12.9 | 167 | 0 | TOML | slower | yes | 82 |
| ehsanmok-json | 0.3.0 | 10.8 | 3.39 | 14.2 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

