# Experiment 8 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/08-human-files/kotlin/logs/kotlin/2026-08-27-181747.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 56.9 | 91.8 | 154 | 440 | 256 | JSON | fastest | yes | 86 |
| tomlkt | 0.5.0 | 119 | 129 | 250 | 499 | 259 | TOML | slower | yes | 88 |
| kaml | 0.72.0 | 222 | 341 | 584 | 440 | 250 | YAML — kaml | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 28.5 | 31.7 | 61.2 | 411 | 256 | JSON | fastest | yes | 88 |
| tomlkt | 0.5.0 | 58.9 | 53.8 | 112 | 570 | 259 | TOML | slower | yes | 87 |
| kaml | 0.72.0 | 126 | 156 | 286 | 470 | 250 | YAML — kaml | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

**sample E (words), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

