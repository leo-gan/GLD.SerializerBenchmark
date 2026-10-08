# Experiment 8 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/08-human-files/go/logs/go/2026-09-29-184453.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.90 | 2.83 | 4.86 | 448 | 262 | JSON | fastest | yes | 84 |
| pelletier/go-toml | 2.4.3 | 6.08 | 11.7 | 17.7 | 500 | 267 | TOML | slower | yes | 88 |
| goccy/go-yaml | 1.19.2 | 94.1 | 112 | 205 | 429 | 256 | YAML | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.15 | 1.97 | 3.12 | 411 | 262 | JSON | fastest | yes | 81 |
| pelletier/go-toml | 2.4.3 | 2.73 | 3.82 | 6.63 | 441 | 267 | TOML | slower | yes | 81 |
| goccy/go-yaml | 1.19.2 | 38.9 | 45.0 | 84.9 | 407 | 256 | YAML | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `goccy/go-yaml`.

**sample E (words), N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: —. Time/size front: `goccy/go-json`, `goccy/go-yaml`.

