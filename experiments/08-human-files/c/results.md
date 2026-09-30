# Experiment 8 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/08-human-files/c/logs/c/2026-09-29-184433.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.88 | 2.46 | 6.33 | 460 | 252 | JSON | fastest | yes | 89 |
| libyaml | 0.2.5 | 12.1 | 25.4 | 37.9 | 461 | 248 | YAML | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.51 | 2.45 | 3.96 | 387 | 252 | JSON | fastest | yes | 85 |
| libyaml | 0.2.5 | 7.22 | 13.9 | 21.2 | 447 | 248 | YAML | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| yyjson | 1 | 5.17 | 3.26 | 8.44 | real |
| libyaml | 1 | 12.8 | 25.9 | 39.0 | copied |
| yyjson | 1 | 2.44 | 3.07 | 5.52 | real |
| libyaml | 1 | 7.62 | 14.1 | 21.6 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample E (words), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

