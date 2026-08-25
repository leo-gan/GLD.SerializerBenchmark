# Experiment 8 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/python/logs/python/2026-08-17-130308.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 2.02 | 3.11 | 5.16 | 448 | 250 | JSON | fastest | yes | 94 |
| yaml | 6.0.3 | 527 | 846 | 1372 | 429 | 242 | YAML — PyYAML | slower | yes | 94 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.31 | 1.89 | 3.32 | 410 | 250 | JSON | fastest | yes | 90 |
| yaml | 6.0.3 | 279 | 482 | 761 | 406 | 242 | YAML — PyYAML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `yaml`.

