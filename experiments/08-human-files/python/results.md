# Experiment 8 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/08-human-files/python/logs/python/2026-09-29-184448.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.94 | 3.69 | 6.48 | 448 | 250 | JSON | fastest | yes | 89 |
| yaml | 6.0.3 | 612 | 978 | 1577 | 429 | 242 | YAML — PyYAML | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 1.95 | 2.46 | 4.54 | 410 | 250 | JSON | fastest | yes | 92 |
| yaml | 6.0.3 | 332 | 575 | 907 | 406 | 242 | YAML — PyYAML | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `yaml`.

