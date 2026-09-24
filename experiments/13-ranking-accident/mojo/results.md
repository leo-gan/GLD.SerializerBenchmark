# Experiment 13 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/13-ranking-accident/mojo/logs/mojo/2026-09-23-181637.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.58 | 1.12 | 1.70 | 452 | 0 | JSON — mojo-json | fastest | yes | 83 |
| EmberJson | 0.3.4 | 0.52 | 1.60 | 2.14 | 452 | 0 | JSON | slower | yes | 84 |
| ehsanmok-json | 0.4.0 | 0.73 | 6.92 | 7.65 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 79 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 48.8 | 121 | 170 | 47144 | 0 | JSON — mojo-json | fastest | yes | 83 |
| EmberJson | 0.3.4 | 56.5 | 139 | 196 | 47144 | 0 | JSON | slower | yes | 86 |
| ehsanmok-json | 0.4.0 | 63.0 | 649 | 714 | 47144 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.43 | 1.11 | 1.55 | 290 | 0 | JSON | fastest | yes | 88 |
| mojo-json | 0.3.0 | 0.43 | 1.16 | 1.59 | 290 | 0 | JSON — mojo-json | close | yes | 89 |
| ehsanmok-json | 0.4.0 | 0.56 | 4.68 | 5.24 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 46.0 | 84.0 | 131 | 27675 | 0 | JSON | fastest | yes | 91 |
| mojo-json | 0.3.0 | 39.7 | 100 | 140 | 27675 | 0 | JSON — mojo-json | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 48.5 | 388 | 437 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.26 | 0.40 | 0.66 | 164 | 0 | JSON — mojo-json | fastest | yes | 95 |
| EmberJson | 0.3.4 | 0.27 | 0.59 | 0.87 | 168 | 0 | JSON | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 0.37 | 3.66 | 4.03 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 17.6 | 30.6 | 48.7 | 16114 | 0 | JSON — mojo-json | fastest | yes | 94 |
| EmberJson | 0.3.4 | 23.4 | 39.5 | 63.0 | 16556 | 0 | JSON | slower | yes | 96 |
| ehsanmok-json | 0.4.0 | 24.7 | 322 | 347 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.75 | 1.22 | 1.97 | 411 | 0 | JSON | fastest | yes | 85 |
| mojo-json | 0.3.0 | 0.76 | 2.35 | 3.10 | 411 | 0 | JSON — mojo-json | slower | yes | 83 |
| ehsanmok-json | 0.4.0 | 1.04 | 5.15 | 6.20 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 84 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 94.0 | 117 | 212 | 41441 | 0 | JSON | fastest | yes | 87 |
| mojo-json | 0.3.0 | 86.9 | 227 | 314 | 41441 | 0 | JSON — mojo-json | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 101 | 476 | 577 | 41441 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 1.38 | 1.34 | 2.73 | 491 | 0 | JSON — mojo-json | fastest | yes | 87 |
| EmberJson | 0.3.4 | 1.81 | 1.84 | 3.66 | 668 | 0 | JSON | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 5.86 | 6.62 | 12.6 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 84 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 138 | 137 | 274 | 49656 | 0 | JSON — mojo-json | fastest | yes | 93 |
| EmberJson | 0.3.4 | 213 | 189 | 403 | 66898 | 0 | JSON | slower | yes | 90 |
| ehsanmok-json | 0.4.0 | 644 | 630 | 1289 | 66902 | 0 | JSON — ehsanmok/json | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample A (order), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: `mojo-json`. Time/size front: `EmberJson`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

