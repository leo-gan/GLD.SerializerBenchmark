# Experiment 8 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/08-human-files/mojo/logs/mojo/2026-09-09-132137.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.53 | 1.67 | 2.23 | 452 | 0 | JSON | fastest | yes | 88 |
| mojo-json | 0.2.0 | 2.32 | 2.94 | 5.26 | 452 | 0 | JSON — mojo-json | slower | yes | 87 |
| ehsanmok-json | 0.3.0 | 56.4 | 6.06 | 62.4 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 76 |
| mojo-toml | 0.9.1 | 22.7 | 53.7 | 76.4 | 489 | 0 | TOML | slower | yes | 75 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.56 | 1.22 | 1.79 | 411 | 0 | JSON | fastest | yes | 89 |
| mojo-json | 0.2.0 | 2.08 | 5.85 | 7.93 | 411 | 0 | JSON — mojo-json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 13.1 | 19.6 | 32.8 | 441 | 0 | TOML | slower | yes | 89 |
| ehsanmok-json | 0.3.0 | 55.6 | 4.16 | 59.6 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

