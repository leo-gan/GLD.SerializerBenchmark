# Experiment 6 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/06-document-db-formats/mojo/logs/mojo/2026-09-12-132646.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.57 | 1.11 | 1.69 | 452 | 0 | JSON — mojo-json | fastest | yes | 90 |
| EmberJson | 0.3.4 | 0.51 | 1.60 | 2.11 | 452 | 0 | JSON | slower | yes | 86 |
| mojo-cbor | 0.6.0 | 0.48 | 3.94 | 4.43 | 329 | 0 | CBOR | slower | yes | 90 |
| ehsanmok-json | 0.3.1 | 0.72 | 6.37 | 7.08 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 84 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-cbor`.

