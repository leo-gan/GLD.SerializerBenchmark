# Experiment 13 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/13-ranking-accident/mojo/logs/mojo/2026-09-09-132209.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.51 | 1.61 | 2.13 | 452 | 0 | JSON | fastest | yes | 84 |
| mojo-json | 0.2.0 | 2.23 | 2.93 | 5.18 | 452 | 0 | JSON — mojo-json | slower | yes | 73 |
| ehsanmok-json | 0.3.0 | 54.9 | 5.90 | 60.8 | 452 | 0 | JSON — ehsanmok/json | slower | yes | 77 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 52.9 | 131 | 184 | 47144 | 0 | JSON | fastest | yes | 88 |
| mojo-json | 0.2.0 | 50.9 | 299 | 350 | 47144 | 0 | JSON — mojo-json | slower | yes | 90 |
| ehsanmok-json | 0.3.0 | 20153 | 538 | 20693 | 47144 | 0 | JSON — ehsanmok/json | slower | yes | 93 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.34 | 0.99 | 1.33 | 290 | 0 | JSON | fastest | yes | 91 |
| mojo-json | 0.2.0 | 0.68 | 2.41 | 3.08 | 290 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 24.1 | 3.61 | 27.7 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 37.4 | 76.3 | 114 | 27675 | 0 | JSON | fastest | yes | 86 |
| mojo-json | 0.2.0 | 40.4 | 224 | 265 | 27675 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 9693 | 334 | 10021 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.25 | 0.57 | 0.82 | 168 | 0 | JSON | fastest | yes | 89 |
| mojo-json | 0.2.0 | 0.80 | 1.21 | 2.01 | 168 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 10.9 | 3.44 | 14.3 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 19.2 | 32.2 | 51.5 | 16556 | 0 | JSON | fastest | yes | 94 |
| mojo-json | 0.2.0 | 72.9 | 105 | 178 | 16556 | 0 | JSON — mojo-json | slower | yes | 93 |
| ehsanmok-json | 0.3.0 | 3877 | 311 | 4189 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.55 | 1.17 | 1.72 | 411 | 0 | JSON | fastest | yes | 90 |
| mojo-json | 0.2.0 | 2.03 | 5.58 | 7.64 | 411 | 0 | JSON — mojo-json | slower | yes | 90 |
| ehsanmok-json | 0.3.0 | 53.2 | 4.00 | 57.2 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 79.8 | 111 | 191 | 41441 | 0 | JSON | fastest | yes | 87 |
| mojo-json | 0.2.0 | 91.5 | 556 | 648 | 41441 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 13853 | 397 | 14253 | 41441 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 1.53 | 1.59 | 3.13 | 668 | 0 | JSON | fastest | yes | 94 |
| mojo-json | 0.2.0 | 21.4 | 14.5 | 35.9 | 668 | 0 | JSON — mojo-json | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 61.1 | 12.2 | 73.4 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 176 | 159 | 338 | 66898 | 0 | JSON | fastest | yes | 88 |
| mojo-json | 0.2.0 | 2240 | 1516 | 3757 | 66898 | 0 | JSON — mojo-json | slower | yes | 90 |
| ehsanmok-json | 0.3.0 | 16224 | 1181 | 17406 | 66898 | 0 | JSON — ehsanmok/json | slower | yes | 89 |

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

