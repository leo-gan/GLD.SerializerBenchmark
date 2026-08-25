# Experiment 6 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/06-document-db-formats/c/logs/c/2026-08-17-110021.csv`
**Language:** c
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mpack | 1.1 | 0.73 | 2.06 | 2.82 | 335 | — | MessagePack | fastest | yes | 94 |
| yyjson | 0.10.0 | 3.29 | 1.50 | 4.79 | 460 | — | JSON — Experiment 1 | slower | yes | 96 |
| libbson | 1.27.5 | 4.00 | 2.67 | 6.71 | 577 | — | BSON | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| mpack | 1 | 0.97 | 1.57 | 2.58 | copied |
| yyjson | 1 | 2.67 | 1.62 | 4.33 | copied |
| libbson | 1 | 3.78 | 2.80 | 6.66 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `mpack`. Small gap: —. Time/size front: `mpack`.

