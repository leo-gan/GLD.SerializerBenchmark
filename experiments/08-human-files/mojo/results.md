# Experiment 8 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/08-human-files/mojo/logs/mojo/2026-09-08-155400.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.49 | 1.57 | 2.07 | 452 | 0 | JSON | fastest | yes | 85 |
| ehsanmok-json | 0.3.0 | 53.6 | 5.82 | 59.4 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 71 |
| mojo-toml | 0.9.1 | 21.9 | 53.1 | 75.2 | 489 | 0 | TOML | slower | yes | 86 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.68 | 1.15 | 1.84 | 411 | 0 | JSON | fastest | yes | 84 |
| mojo-toml | 0.9.1 | 12.7 | 19.2 | 32.0 | 441 | 0 | TOML | slower | yes | 92 |
| ehsanmok-json | 0.3.0 | 53.5 | 4.04 | 57.7 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

