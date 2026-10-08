# Experiment 8 results — rust

**Date:** 2026-09-30
**Raw file:** `experiments/08-human-files/rust/logs/rust/2026-09-29-184454.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.151 | 0.81 | 2.37 | 3.17 | 460 | 254 | JSON | fastest | yes | 84 |
| serde_yaml | 0.9.34+deprecated | 12.5 | 22.1 | 34.6 | 438 | 244 | YAML | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.151 | 0.48 | 2.59 | 3.06 | 390 | 254 | JSON | fastest | yes | 87 |
| serde_yaml | 0.9.34+deprecated | 8.84 | 15.6 | 24.4 | 383 | 244 | YAML | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`, `serde_yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`, `serde_yaml`.

