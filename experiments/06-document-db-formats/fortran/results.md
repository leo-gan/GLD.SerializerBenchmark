# Experiment 6 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/06-document-db-formats/fortran/logs/fortran/2026-10-10-134208.csv`
**Language:** fortran
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 40.6 | 37.1 | 78.2 | 505 | 252 | JSON — jonquil | fastest | yes | 92 |
| json-fortran | 9.3.1 | 35.9 | 44.5 | 80.9 | 473 | 244 | JSON — json-fortran | similar | yes | 91 |
| rojff | 9f68e5aa4c12 | 50.7 | 51.5 | 103 | 473 | 244 | JSON — rojff | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `jonquil`, `json-fortran`. Small gap: —. Time/size front: `jonquil`, `json-fortran`.

