# Experiment 13 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/13-ranking-accident/mojo/logs/mojo/2026-09-08-155429.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.53 | 1.67 | 2.20 | 452 | 0 | JSON | fastest | yes | 90 |
| ehsanmok-json | 0.3.0 | 57.8 | 6.12 | 63.8 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 75 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 56.5 | 136 | 193 | 47144 | 0 | JSON | fastest | yes | 84 |
| ehsanmok-json | 0.3.0 | 21103 | 550 | 21656 | 47144 | 0 | JSON — ehsanmok/json | slower | yes | 87 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.36 | 0.98 | 1.35 | 290 | 0 | JSON | fastest | yes | 89 |
| ehsanmok-json | 0.3.0 | 25.1 | 3.75 | 28.9 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 40.6 | 75.8 | 116 | 27675 | 0 | JSON | fastest | yes | 91 |
| ehsanmok-json | 0.3.0 | 10020 | 349 | 10363 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.26 | 0.56 | 0.82 | 168 | 0 | JSON | fastest | yes | 90 |
| ehsanmok-json | 0.3.0 | 10.8 | 3.47 | 14.3 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 19.4 | 32.8 | 52.4 | 16556 | 0 | JSON | fastest | yes | 94 |
| ehsanmok-json | 0.3.0 | 4018 | 312 | 4328 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.68 | 1.14 | 1.82 | 411 | 0 | JSON | fastest | yes | 88 |
| ehsanmok-json | 0.3.0 | 53.5 | 3.98 | 57.4 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 83 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 85.2 | 108 | 193 | 41441 | 0 | JSON | fastest | yes | 81 |
| ehsanmok-json | 0.3.0 | 13728 | 388 | 14113 | 41441 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 1.72 | 1.68 | 3.40 | 668 | 0 | JSON | fastest | yes | 93 |
| ehsanmok-json | 0.3.0 | 66.7 | 14.0 | 80.7 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 69 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 181 | 162 | 342 | 66898 | 0 | JSON | fastest | yes | 85 |
| ehsanmok-json | 0.3.0 | 16305 | 1256 | 17570 | 66898 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample A (order), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample B (flat), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample B (flat), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample C (sensor), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

