# Experiment 12 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/12-format-vs-library/fortran/logs/fortran/2026-10-11-150915.csv`
**Language:** fortran
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 32.4 | 31.1 | 64.1 | 505 | 252 | jonquil — JSON | fastest | yes | 95 |
| json-fortran | 9.3.1 | 32.7 | 36.3 | 68.3 | 473 | 244 | json-fortran — JSON | slower | yes | 91 |
| rojff | 9f68e5aa4c12 | 41.4 | 42.6 | 84.3 | 473 | 244 | rojff — JSON | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `jonquil`. Small gap: —. Time/size front: `jonquil`, `json-fortran`.

