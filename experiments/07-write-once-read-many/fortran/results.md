# Experiment 7 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/07-write-once-read-many/fortran/logs/fortran/2026-10-11-150423.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.30 | 1.12 | 1.42 | 211 | 2064 | length-prefixed binary | fastest | yes | 96 |
| json-fortran | 9.3.1 | 32.4 | 36.1 | 68.0 | 473 | 2760 | JSON — json-fortran | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 2.32 | 2.44 | 4.80 | 4131 | 2064 | length-prefixed binary | fastest | yes | 92 |
| json-fortran | 9.3.1 | 714 | 522 | 1240 | 11802 | 2760 | JSON — json-fortran | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample C (sensor), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

