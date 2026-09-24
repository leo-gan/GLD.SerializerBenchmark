# Experiment 6 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/06-document-db-formats/mojo/logs/mojo/2026-09-23-181521.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.57 | 1.16 | 1.74 | 452 | 0 | JSON — mojo-json | fastest | yes | 84 |
| EmberJson | 0.3.4 | 0.52 | 1.64 | 2.16 | 452 | 0 | JSON | slower | yes | 85 |
| mojo-cbor | 0.6.0 | 0.51 | 4.11 | 4.62 | 329 | 0 | CBOR | slower | yes | 89 |
| ehsanmok-json | 0.4.0 | 0.76 | 7.03 | 7.78 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-cbor`.

