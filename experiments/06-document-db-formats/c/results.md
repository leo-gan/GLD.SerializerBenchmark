# Experiment 6 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/06-document-db-formats/c/logs/c/2026-09-29-184352.csv`
**Language:** c
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mpack | 1.1.1 | 1.03 | 2.06 | 3.12 | 335 | 236 | MessagePack | fastest | yes | 83 |
| yyjson | 0.10.0 | 3.75 | 2.39 | 6.15 | 460 | 239 | JSON — Experiment 1 | slower | yes | 80 |
| libbson | 1.27.5 | 4.70 | 3.86 | 8.62 | 577 | 296 | BSON | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| mpack | 1 | 1.37 | 2.35 | 3.74 | copied |
| yyjson | 1 | 4.99 | 3.07 | 8.08 | real |
| libbson | 1 | 5.22 | 4.34 | 9.62 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mpack`. Small gap: —. Time/size front: `mpack`.

