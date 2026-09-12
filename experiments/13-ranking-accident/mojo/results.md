# Experiment 13 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/13-ranking-accident/mojo/logs/mojo/2026-09-12-132744.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.53 | 1.06 | 1.58 | 452 | 0 | JSON — mojo-json | fastest | yes | 88 |
| EmberJson | 0.3.4 | 0.48 | 1.54 | 2.02 | 452 | 0 | JSON | slower | yes | 87 |
| ehsanmok-json | 0.3.1 | 0.68 | 6.15 | 6.83 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 82 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 43.5 | 109 | 153 | 47144 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 49.8 | 122 | 172 | 47144 | 0 | JSON | slower | yes | 90 |
| ehsanmok-json | 0.3.1 | 55.2 | 558 | 613 | 47144 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.34 | 0.97 | 1.31 | 290 | 0 | JSON | fastest | yes | 87 |
| mojo-json | 0.3.0 | 0.38 | 1.01 | 1.39 | 290 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.1 | 0.47 | 3.93 | 4.40 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 38.4 | 70.1 | 109 | 27675 | 0 | JSON | fastest | yes | 92 |
| mojo-json | 0.3.0 | 33.8 | 87.2 | 121 | 27675 | 0 | JSON — mojo-json | slower | yes | 91 |
| ehsanmok-json | 0.3.1 | 39.0 | 353 | 393 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 93 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 0.23 | 0.36 | 0.59 | 164 | 0 | JSON — mojo-json | fastest | yes | 93 |
| EmberJson | 0.3.4 | 0.25 | 0.54 | 0.79 | 168 | 0 | JSON | slower | yes | 92 |
| ehsanmok-json | 0.3.1 | 0.53 | 3.47 | 4.00 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 14.3 | 25.0 | 39.3 | 16114 | 0 | JSON — mojo-json | fastest | yes | 89 |
| EmberJson | 0.3.4 | 17.9 | 30.1 | 48.1 | 16556 | 0 | JSON | slower | yes | 91 |
| ehsanmok-json | 0.3.1 | 41.8 | 285 | 327 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.60 | 1.12 | 1.72 | 411 | 0 | JSON | fastest | yes | 87 |
| mojo-json | 0.3.0 | 0.65 | 2.08 | 2.73 | 411 | 0 | JSON — mojo-json | slower | yes | 96 |
| ehsanmok-json | 0.3.1 | 0.90 | 4.27 | 5.17 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 82.8 | 105 | 188 | 41441 | 0 | JSON | fastest | yes | 91 |
| mojo-json | 0.3.0 | 75.6 | 210 | 285 | 41441 | 0 | JSON — mojo-json | slower | yes | 90 |
| ehsanmok-json | 0.3.1 | 89.3 | 421 | 512 | 41441 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 1.21 | 1.15 | 2.36 | 491 | 0 | JSON — mojo-json | fastest | yes | 92 |
| EmberJson | 0.3.4 | 1.53 | 1.53 | 3.06 | 668 | 0 | JSON | slower | yes | 93 |
| ehsanmok-json | 0.3.1 | 12.2 | 12.8 | 25.0 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 80 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.3.0 | 112 | 103 | 215 | 49656 | 0 | JSON — mojo-json | fastest | yes | 89 |
| EmberJson | 0.3.4 | 171 | 154 | 326 | 66898 | 0 | JSON | slower | yes | 83 |
| ehsanmok-json | 0.3.1 | 1301 | 1254 | 2559 | 66898 | 0 | JSON — ehsanmok/json | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample A (order), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample E (words), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

