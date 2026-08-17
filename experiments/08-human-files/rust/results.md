# Experiment 8 results — rust

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/rust/logs/rust/2026-08-17-130319.csv`
**Language:** rust
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.150 | 0.73 | 2.16 | 2.90 | 460 | 254 | JSON | fastest | yes | 86 |
| serde_yaml | — | 11.5 | 19.1 | 30.7 | 438 | 244 | YAML | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde_json | 1.0.150 | 0.44 | 2.06 | 2.54 | 390 | 254 | JSON | fastest | yes | 87 |
| serde_yaml | — | 8.08 | 14.6 | 22.8 | 383 | 244 | YAML | slower | yes | 79 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`, `serde_yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `serde_json`. Small gap: —. Time/size front: `serde_json`, `serde_yaml`.

