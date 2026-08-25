# Experiment 6 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/go/logs/go/2026-08-17-110018.csv`
**Language:** go
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.38 | 2.31 | 3.72 | 448 | — | JSON — Experiment 1 | fastest | yes | 86 |
| vmihailenco/msgpack | 5.4.1 | 2.36 | 4.07 | 6.41 | 397 | — | MessagePack | slower | yes | 87 |
| mongo-bson | 1.17.9 | 5.88 | 6.64 | 13.0 | 525 | — | BSON | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `vmihailenco/msgpack`.

