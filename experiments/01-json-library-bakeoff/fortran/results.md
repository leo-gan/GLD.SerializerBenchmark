# Experiment 1 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/01-json-library-bakeoff/fortran/logs/fortran/2026-10-10-134152.csv`
**Language:** fortran
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 32.3 | 39.1 | 72.1 | 473 | 244 | yes | fastest | yes | 89 |
| jonquil | 0.3.2 | 37.7 | 34.4 | 72.4 | 505 | 252 | yes | similar | yes | 94 |
| rojff | 9f68e5aa4c12 | 47.6 | 47.7 | 96.1 | 473 | 244 | yes | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `json-fortran`, `jonquil`.
**Not both slower and larger than another named-JSON library:** `json-fortran`.

