# Experiment 8 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/08-human-files/mojo/logs/mojo/2026-09-12-132703.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.59 | 1.16 | 1.75 | 452 | 0 | JSON — mojo-json | fastest | yes | 81 |
| EmberJson | 0.3.4 | 0.53 | 1.66 | 2.20 | 452 | 0 | JSON | slower | yes | 86 |
| ehsanmok-json | 0.3.1 | 0.74 | 6.70 | 7.44 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 76 |
| mojo-toml | 0.9.1 | 22.9 | 55.4 | 78.4 | 489 | 0 | TOML | slower | yes | 81 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.65 | 1.24 | 1.90 | 411 | 0 | JSON | fastest | yes | 94 |
| mojo-json | 0.3.0 | 0.84 | 2.32 | 3.16 | 411 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.1 | 0.93 | 4.70 | 5.62 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 13.0 | 20.2 | 33.2 | 441 | 0 | TOML | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

