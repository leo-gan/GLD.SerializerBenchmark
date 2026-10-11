# Experiment 1 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/01-json-library-bakeoff/fortran/logs/fortran/2026-10-11-145822.csv`
**Language:** fortran
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| jonquil | 0.3.2 | 33.5 | 32.4 | 65.7 | 505 | 252 | yes | fastest | yes | 88 |
| json-fortran | 9.3.1 | 34.0 | 37.3 | 71.4 | 473 | 244 | yes | slower | yes | 90 |
| rojff | 9f68e5aa4c12 | 42.5 | 43.8 | 87.1 | 473 | 244 | yes | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest named-JSON library?

**Not clearly slower on this sample:** `jonquil`.
**Not both slower and larger than another named-JSON library:** `jonquil`, `json-fortran`.

