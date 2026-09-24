# Experiment 8 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/08-human-files/mojo/logs/mojo/2026-09-23-181542.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.56 | 1.14 | 1.71 | 452 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 0.54 | 1.59 | 2.13 | 452 | 0 | JSON | slower | yes | 89 |
| ehsanmok-json | 0.4.0 | 0.74 | 6.70 | 7.43 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 21.7 | 52.9 | 75.1 | 489 | 0 | TOML | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.70 | 1.21 | 1.91 | 411 | 0 | JSON | fastest | yes | 92 |
| mojo-json | 0.3.0 | 0.74 | 2.23 | 2.98 | 411 | 0 | JSON — mojo-json | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 0.95 | 4.87 | 5.82 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 13.1 | 19.9 | 33.0 | 441 | 0 | TOML | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

