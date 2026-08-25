# Experiment 6 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/rust/logs/rust/2026-08-17-110020.csv`
**Language:** rust
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rmp-serde | 1.3.1 | 0.38 | 1.01 | 1.41 | 333 | — | MessagePack | fastest | yes | 88 |
| sonic-rs | 0.3.17 | 0.63 | 1.16 | 1.80 | 460 | — | JSON — Experiment 1 | slower | yes | 86 |
| bson | 2.15.0 | 1.34 | 2.63 | 3.92 | 540 | — | BSON | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `rmp-serde`. Small gap: —. Time/size front: `rmp-serde`.

