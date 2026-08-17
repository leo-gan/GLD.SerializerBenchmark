# Experiment 8 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/go/logs/go/2026-08-17-110416.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 2.00 | 3.23 | 5.32 | 448 | — | JSON | fastest | yes | 87 |
| pelletier/go-toml | 2.4.3 | 6.39 | 12.6 | 19.4 | 500 | — | TOML | slower | yes | 89 |
| goccy/go-yaml | 1.19.2 | 90.3 | 111 | 201 | 429 | — | YAML | slower | yes | 89 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.33 | 2.17 | 3.56 | 411 | — | JSON | fastest | yes | 85 |
| pelletier/go-toml | 2.4.3 | 2.92 | 4.11 | 7.03 | 441 | — | TOML | slower | yes | 90 |
| goccy/go-yaml | 1.19.2 | 43.1 | 51.9 | 94.7 | 407 | — | YAML | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `goccy/go-yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `goccy/go-yaml`.

