# Experiment 14 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/14-starter-kit/fortran/logs/fortran/2026-10-10-134318.csv`
**Language:** fortran
**Sample:** one nested document (`document`, one record)
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In-memory call (the main comparison)

Times are middle values in microseconds (µs). Lower time is better.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 38.0 | 46.2 | 84.8 | 473 | 244 | yes | fastest | yes | 84 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Instead we ask: across the timed trials, how often is this library slower than the fastest library in this starter kit? A faster row is not automatically the right public format.

**Not clearly slower on this sample:** `json-fortran`.
**Not both slower and larger than another library in the kit:** `json-fortran`.

