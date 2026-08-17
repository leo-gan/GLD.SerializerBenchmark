# Experiment 8 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/java/logs/java/2026-08-17-130310.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 41.4 | 45.4 | 88.9 | 440 | 256 | JSON | fastest | yes | 85 |
| jackson-yaml | unknown | 174 | 218 | 388 | 441 | 252 | YAML — Jackson | slower | yes | 84 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 15.0 | 15.7 | 31.1 | 411 | 256 | JSON | fastest | yes | 85 |
| jackson-yaml | unknown | 61.2 | 83.9 | 149 | 471 | 252 | YAML — Jackson | slower | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

**sample E (words), N = 1, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

