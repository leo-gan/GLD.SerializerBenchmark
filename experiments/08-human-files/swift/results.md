# Experiment 8 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/swift/logs/swift/2026-08-17-110418.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 20.0 | 33.0 | 53.2 | 448 | — | JSON | fastest | yes | 87 |
| TOML | 2.0.0 | 153 | 42.9 | 196 | 508 | — | TOML | slower | yes | 81 |
| XMLCoder | 0.18.2 | 186 | 227 | 413 | 729 | — | XML | slower | yes | 85 |
| Yams | 5.4.0 | 237 | 180 | 417 | 429 | — | YAML | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 14.6 | 19.9 | 34.6 | 411 | — | JSON | fastest | yes | 85 |
| TOML | 2.0.0 | 44.1 | 31.4 | 76.2 | 441 | — | TOML | slower | yes | 92 |
| Yams | 5.4.0 | 262 | 58.3 | 320 | 407 | — | YAML | slower | yes | 92 |
| XMLCoder | 0.18.2 | 204 | 197 | 402 | 803 | — | XML | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`, `Yams`.

**sample E (words), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`, `Yams`.

