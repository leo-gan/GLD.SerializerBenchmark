# Experiment 8 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/kotlin/logs/kotlin/2026-10-11-150453.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.19.0 | 72.6 | 117 | 193 | 440 | 256 | JSON | fastest | yes | 90 |
| tomlkt | 0.5.0 | 137 | 154 | 301 | 499 | 259 | TOML | slower | yes | 91 |
| kaml | 0.72.0 | 262 | 446 | 723 | 440 | 250 | YAML — kaml | slower | yes | 91 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.19.0 | 30.3 | 34.4 | 64.3 | 411 | 256 | JSON | fastest | yes | 92 |
| tomlkt | 0.5.0 | 62.8 | 54.9 | 119 | 570 | 259 | TOML | slower | yes | 92 |
| kaml | 0.72.0 | 124 | 174 | 297 | 470 | 250 | YAML — kaml | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

**sample E (words), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

