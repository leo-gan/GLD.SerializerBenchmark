# Experiment 8 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/08-human-files/fortran/logs/fortran/2026-10-10-134210.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| toml-f | 0.5.2 | 45.2 | 38.5 | 84.1 | 524 | 270 | TOML | fastest | yes | 97 |
| json-fortran | 9.3.1 | 40.3 | 46.8 | 86.8 | 473 | 269 | JSON — json-fortran | similar | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json-fortran | 9.3.1 | 23.9 | 23.1 | 47.3 | 430 | 269 | JSON — json-fortran | fastest | yes | 92 |
| toml-f | 0.5.2 | 34.9 | 33.5 | 69.9 | 462 | 270 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `toml-f`, `json-fortran`. Small gap: —. Time/size front: `toml-f`, `json-fortran`.

**sample E (words), N = 1, memory** — not clearly slower: `json-fortran`. Small gap: —. Time/size front: `json-fortran`.

