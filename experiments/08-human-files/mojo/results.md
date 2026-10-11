# Experiment 8 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/mojo/logs/mojo/2026-10-11-150457.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 0.93 | 2.05 | 3.04 | 448 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 3.88 | 3.64 | 7.46 | 448 | 0 | JSON | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 1.57 | 8.03 | 9.52 | 448 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 24.4 | 55.6 | 81.3 | 485 | 0 | TOML | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 0.94 | 2.58 | 3.56 | 411 | 0 | JSON — mojo-json | fastest | yes | 97 |
| EmberJson | 0.3.4 | 2.71 | 2.54 | 5.31 | 411 | 0 | JSON | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 1.56 | 5.68 | 7.20 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 13.4 | 22.6 | 35.8 | 441 | 0 | TOML | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

