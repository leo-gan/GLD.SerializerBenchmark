# Experiment 8 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/08-human-files/c/logs/c/2026-08-17-130327.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 3.55 | 2.36 | 5.97 | 460 | 252 | JSON | fastest | yes | 86 |
| libyaml | 0.2.5 | 11.1 | 21.1 | 32.4 | 461 | 248 | YAML | slower | yes | 89 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| yyjson | 0.10.0 | 1.41 | 2.34 | 3.76 | 387 | 252 | JSON | fastest | yes | 96 |
| libyaml | 0.2.5 | 6.49 | 12.1 | 18.6 | 447 | 248 | YAML | slower | yes | 98 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| yyjson | 1 | 4.49 | 2.98 | 7.44 | real |
| libyaml | 1 | 11.2 | 21.0 | 32.3 | copied |
| yyjson | 1 | 2.18 | 2.88 | 5.07 | real |
| libyaml | 1 | 6.78 | 12.1 | 18.9 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

**sample E (words), N = 1, memory** — not clearly slower: `yyjson`. Small gap: —. Time/size front: `yyjson`.

