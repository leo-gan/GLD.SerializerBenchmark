# Experiment 6 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/06-document-db-formats/fortran/logs/fortran/2026-10-11-150334.csv`
**Language:** fortran
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 31.8 | 30.9 | 62.8 | 505 | 252 | JSON — jonquil | fastest | yes | 91 |
| json-fortran | 9.3.1 | 32.9 | 36.3 | 69.0 | 473 | 244 | JSON — json-fortran | slower | yes | 92 |
| rojff | 9f68e5aa4c12 | 41.3 | 42.8 | 84.4 | 473 | 244 | JSON — rojff | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jonquil`. Small gap: —. Time/size front: `jonquil`, `json-fortran`.

