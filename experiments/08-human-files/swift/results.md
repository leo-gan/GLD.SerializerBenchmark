# Experiment 8 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/swift/logs/swift/2026-10-11-150425.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 18.2 | 33.0 | 51.0 | 448 | 255 | JSON | fastest | yes | 80 |
| TOML | 2.0.0 | 150 | 42.4 | 192 | 508 | 258 | TOML | slower | yes | 92 |
| XMLCoder | 0.18.2 | 180 | 220 | 401 | 729 | 272 | XML | slower | yes | 93 |
| Yams | 5.4.0 | 226 | 175 | 404 | 429 | 247 | YAML | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 13.4 | 18.8 | 32.2 | 411 | 255 | JSON | fastest | yes | 84 |
| TOML | 2.0.0 | 42.1 | 30.8 | 73.1 | 441 | 258 | TOML | slower | yes | 77 |
| Yams | 5.4.0 | 243 | 52.9 | 297 | 407 | 247 | YAML | slower | yes | 87 |
| XMLCoder | 0.18.2 | 194 | 188 | 382 | 803 | 272 | XML | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`, `Yams`.

**sample E (words), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`, `Yams`.

