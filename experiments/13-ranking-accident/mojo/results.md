# Experiment 13 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/mojo/logs/mojo/2026-10-11-151149.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 1.72 | 3.35 | 5.08 | 448 | 0 | JSON — mojo-json | fastest | yes | 95 |
| EmberJson | 0.3.4 | 5.11 | 5.32 | 10.6 | 448 | 0 | JSON | slower | yes | 96 |
| ehsanmok-json | 0.4.0 | 2.61 | 11.4 | 14.2 | 448 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 28.4 | 87.3 | 116 | 45414 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 175 | 125 | 300 | 45414 | 0 | JSON | slower | yes | 96 |
| ehsanmok-json | 0.4.0 | 53.7 | 503 | 553 | 45414 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 1.35 | 2.71 | 3.95 | 257 | 0 | JSON — mojo-json | fastest | yes | 95 |
| EmberJson | 0.3.4 | 3.39 | 4.19 | 7.73 | 257 | 0 | JSON | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 2.09 | 7.77 | 9.80 | 257 | 0 | JSON — ehsanmok/json | slower | yes | 99 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 23.4 | 76.7 | 100 | 25756 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 97.2 | 73.1 | 171 | 25756 | 0 | JSON | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 36.6 | 280 | 317 | 25756 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 1.04 | 1.78 | 2.88 | 164 | 0 | JSON — mojo-json | fastest | yes | 95 |
| EmberJson | 0.3.4 | 3.09 | 3.25 | 6.28 | 168 | 0 | JSON | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 1.64 | 6.58 | 8.22 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 11.2 | 25.5 | 37.0 | 16114 | 0 | JSON — mojo-json | fastest | yes | 90 |
| EmberJson | 0.3.4 | 52.8 | 34.7 | 87.7 | 16556 | 0 | JSON | slower | yes | 87 |
| ehsanmok-json | 0.4.0 | 21.6 | 235 | 258 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 1.23 | 3.36 | 4.57 | 411 | 0 | JSON — mojo-json | fastest | yes | 91 |
| EmberJson | 0.3.4 | 3.22 | 3.27 | 6.45 | 411 | 0 | JSON | slower | yes | 88 |
| ehsanmok-json | 0.4.0 | 2.08 | 7.48 | 9.71 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 154 | 107 | 260 | 41441 | 0 | JSON | fastest | yes | 97 |
| mojo-json | 0.5.0 | 55.9 | 211 | 266 | 41441 | 0 | JSON — mojo-json | close | yes | 95 |
| ehsanmok-json | 0.4.0 | 88.3 | 373 | 464 | 41441 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 2.59 | 3.88 | 6.50 | 486 | 0 | JSON — mojo-json | fastest | yes | 97 |
| EmberJson | 0.3.4 | 5.50 | 4.51 | 10.2 | 663 | 0 | JSON | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 9.22 | 10.4 | 19.6 | 663 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 90.6 | 135 | 227 | 48752 | 0 | JSON — mojo-json | fastest | yes | 94 |
| EmberJson | 0.3.4 | 214 | 151 | 367 | 65968 | 0 | JSON | slower | yes | 90 |
| ehsanmok-json | 0.4.0 | 489 | 437 | 932 | 65970 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample A (order), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample D (event), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample D (event), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample E (words), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: `mojo-json`. Time/size front: `EmberJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`.

