# Experiment 6 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/swift/logs/swift/2026-08-17-114013.csv`
**Language:** swift
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 18.2 | 31.1 | 49.4 | 448 | — | JSON — Experiment 1 | fastest | yes | 80 |
| SwiftMsgpack | 1.2.1 | 45.0 | 33.2 | 78.2 | 329 | — | MessagePack | slower | yes | 83 |
| SwiftBSON | 3.1.0 | 42.9 | 58.9 | 102 | 525 | — | BSON | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`, `SwiftMsgpack`.

