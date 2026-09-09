# Experiment 6 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/06-document-db-formats/mojo/logs/mojo/2026-09-09-132125.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.52 | 1.60 | 2.13 | 452 | 0 | JSON | fastest | yes | 86 |
| mojo-cbor | 0.6.0 | 0.48 | 4.03 | 4.53 | 329 | 0 | CBOR | slower | yes | 88 |
| mojo-json | 0.2.0 | 2.23 | 2.92 | 5.16 | 452 | 0 | JSON — mojo-json | slower | yes | 87 |
| ehsanmok-json | 0.3.0 | 54.6 | 5.90 | 60.6 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-cbor`.

