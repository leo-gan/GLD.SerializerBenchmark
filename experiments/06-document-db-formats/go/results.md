# Experiment 6 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/06-document-db-formats/go/logs/go/2026-09-29-184356.csv`
**Language:** go
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.88 | 2.80 | 4.58 | 448 | 234 | JSON — Experiment 1 | fastest | yes | 88 |
| vmihailenco/msgpack | 5.4.1 | 2.71 | 4.50 | 7.26 | 405 | 239 | MessagePack | slower | yes | 91 |
| mongo-bson | 1.17.9 | 6.31 | 7.30 | 13.7 | 525 | 281 | BSON | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `vmihailenco/msgpack`.

