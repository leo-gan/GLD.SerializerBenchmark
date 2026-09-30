# Experiment 6 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/06-document-db-formats/rust/logs/rust/2026-09-29-184357.csv`
**Language:** rust
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rmp-serde | 1.3.1 | 0.70 | 2.27 | 3.01 | 333 | 231 | MessagePack | fastest | yes | 90 |
| sonic-rs | 0.3.17 | 0.85 | 2.57 | 3.44 | 460 | 237 | JSON — Experiment 1 | close | yes | 92 |
| bson | 2.15.0 | 2.26 | 4.72 | 7.11 | 540 | 291 | BSON | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `rmp-serde`. Small gap: `sonic-rs`. Time/size front: `rmp-serde`.

