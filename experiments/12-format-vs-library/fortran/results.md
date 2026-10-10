# Experiment 12 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/12-format-vs-library/fortran/logs/fortran/2026-10-10-134228.csv`
**Language:** fortran
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 38.9 | 47.1 | 85.7 | 473 | 244 | json-fortran — JSON | fastest | yes | 89 |
| jonquil | 0.3.2 | 45.8 | 40.0 | 86.1 | 505 | 252 | jonquil — JSON | similar | yes | 90 |
| rojff | 9f68e5aa4c12 | 54.4 | 56.1 | 111 | 473 | 244 | rojff — JSON | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `json-fortran`, `jonquil`. Small gap: —. Time/size front: `json-fortran`.

