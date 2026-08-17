# Experiment 6 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/javascript/logs/javascript/2026-08-17-110017.csv`
**Language:** javascript
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.48 | 3.93 | 7.13 | 448 | — | JSON | fastest | yes | 86 |
| msgpackr | 1.12.1 | 6.40 | 10.9 | 17.6 | 345 | — | MessagePack | slower | yes | 84 |
| bson | 6.10.4 | 15.2 | 11.7 | 27.2 | 493 | — | BSON | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

