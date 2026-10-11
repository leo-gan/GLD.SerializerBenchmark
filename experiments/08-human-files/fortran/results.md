# Experiment 8 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/fortran/logs/fortran/2026-10-11-150526.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| toml-f | 0.5.2 | 31.6 | 29.5 | 61.5 | 524 | 270 | TOML | fastest | yes | 93 |
| json-fortran | 9.3.1 | 33.9 | 37.2 | 71.1 | 473 | 269 | JSON — json-fortran | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 17.3 | 17.4 | 34.7 | 430 | 269 | JSON — json-fortran | fastest | yes | 92 |
| toml-f | 0.5.2 | 26.7 | 25.6 | 52.4 | 462 | 270 | TOML | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `toml-f`. Small gap: —. Time/size front: `toml-f`, `json-fortran`.

**sample E (words), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

