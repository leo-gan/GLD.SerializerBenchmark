# Experiment 8 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/08-human-files/zig/logs/zig/2026-08-28-173410.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.zon | 1.0.7 | 1.97 | 1.44 | 3.40 | 994 | 294 | ZON | fastest | yes | 94 |
| std.json | 0.16.0 | 1.10 | 2.73 | 3.84 | 448 | 260 | JSON | slower | yes | 91 |
| serde.toml | 1.0.7 | 1.13 | 4.53 | 5.70 | 508 | 262 | TOML | slower | yes | 95 |
| std.zon | 0.16.0 | 1.38 | 6.89 | 8.30 | 429 | 260 | official std.zon | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.zon | 1.0.7 | 1.35 | 1.13 | 2.53 | 713 | 294 | ZON | fastest | yes | 89 |
| std.json | 0.16.0 | 1.02 | 2.55 | 3.56 | 411 | 260 | JSON | slower | yes | 94 |
| serde.toml | 1.0.7 | 1.08 | 2.64 | 3.72 | 441 | 262 | TOML | slower | yes | 90 |
| std.zon | 0.16.0 | 1.22 | 5.11 | 6.35 | 412 | 260 | official std.zon | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `serde.zon`. Small gap: —. Time/size front: `serde.zon`, `std.json`, `std.zon`.

**sample E (words), N = 1, memory** — not clearly slower: `serde.zon`. Small gap: —. Time/size front: `serde.zon`, `std.json`.

