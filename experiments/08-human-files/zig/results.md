# Experiment 8 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/zig/logs/zig/2026-10-11-150451.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| std.json | 0.16.0 | 0.83 | 2.14 | 2.99 | 448 | 260 | JSON | fastest | yes | 93 |
| serde.zon | 1.2.2 | 1.42 | 1.58 | 3.04 | 994 | 294 | ZON | similar | yes | 94 |
| serde.toml | 1.2.2 | 1.01 | 4.58 | 5.59 | 508 | 262 | TOML | slower | yes | 92 |
| std.zon | 0.16.0 | 1.33 | 6.36 | 7.65 | 429 | 260 | official std.zon | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.zon | 1.2.2 | 0.99 | 1.10 | 2.12 | 713 | 294 | ZON | fastest | yes | 93 |
| std.json | 0.16.0 | 0.71 | 2.00 | 2.72 | 411 | 260 | JSON | slower | yes | 92 |
| serde.toml | 1.2.2 | 0.81 | 2.48 | 3.30 | 441 | 262 | TOML | slower | yes | 91 |
| std.zon | 0.16.0 | 1.05 | 4.83 | 5.87 | 412 | 260 | official std.zon | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `std.json`, `serde.zon`. Small gap: —. Time/size front: `std.json`, `std.zon`.

**sample E (words), N = 1, memory** — not clearly slower: `serde.zon`. Small gap: —. Time/size front: `serde.zon`, `std.json`.

