# Experiment 8 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/08-human-files/cpp/logs/cpp/2026-09-04-111817.csv`
**Language:** cpp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 4.48 | 14.6 | 19.4 | 458 | 260 | JSON | fastest | yes | 92 |
| yaml-cpp | 0.8.0 | 87.4 | 147 | 236 | 486 | 252 | YAML | slower | yes | 81 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| nlohmann_json | 3.11.3 | 3.76 | 9.63 | 13.3 | 411 | 260 | JSON | fastest | yes | 88 |
| yaml-cpp | 0.8.0 | 74.8 | 109 | 185 | 470 | 252 | YAML | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`.

**sample E (words), N = 1, memory** — not clearly slower: `nlohmann_json`. Small gap: —. Time/size front: `nlohmann_json`.

