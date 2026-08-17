# Experiment 8 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/javascript/logs/javascript/2026-08-17-130318.csv`
**Language:** javascript
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.94 | 4.56 | 8.69 | 448 | 258 | JSON | fastest | yes | 90 |
| js-yaml | 4.3.1 | 40.5 | 47.2 | 88.2 | 477 | 249 | YAML | slower | yes | 85 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.09 | 2.95 | 5.24 | 411 | 258 | JSON | fastest | yes | 87 |
| js-yaml | 4.3.1 | 25.4 | 25.2 | 51.1 | 471 | 249 | YAML | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

**sample E (words), N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`.

