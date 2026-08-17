# Experiment 8 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/cpp/logs/cpp/2026-08-17-130335.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 3.17 | 9.36 | 12.6 | 458 | 260 | JSON | fastest | yes | 84 |
| yaml-cpp | 0.8.0 | 61.4 | 104 | 165 | 486 | 252 | YAML | slower | yes | 83 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 2.50 | 5.85 | 8.33 | 411 | 260 | JSON | fastest | yes | 83 |
| yaml-cpp | 0.8.0 | 51.4 | 77.1 | 128 | 470 | 252 | YAML | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`.

**sample E (words), N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`.

