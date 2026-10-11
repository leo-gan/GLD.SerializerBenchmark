# Experiment 6 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/06-document-db-formats/mojo/logs/mojo/2026-10-11-150306.csv`
**Language:** mojo
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 1.48 | 3.05 | 4.63 | 448 | 0 | JSON — mojo-json | fastest | yes | 96 |
| mojo-cbor | 0.8.0 | 1.93 | 5.38 | 7.18 | 332 | 0 | CBOR | slower | yes | 94 |
| EmberJson | 0.3.4 | 5.31 | 5.26 | 10.7 | 448 | 0 | JSON | slower | yes | 96 |
| ehsanmok-json | 0.4.0 | 2.44 | 12.6 | 14.8 | 448 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-cbor`.

