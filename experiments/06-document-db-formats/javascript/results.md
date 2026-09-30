# Experiment 6 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/06-document-db-formats/javascript/logs/javascript/2026-09-29-184354.csv`
**Language:** javascript
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 4.42 | 5.63 | 10.3 | 448 | 230 | JSON | fastest | yes | 85 |
| msgpackr | 1.12.1 | 6.50 | 13.0 | 19.7 | 345 | 232 | MessagePack | slower | yes | 84 |
| bson | 6.10.4 | 18.2 | 12.9 | 32.6 | 493 | 276 | BSON | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `msgpackr`.

