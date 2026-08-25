# Experiment 13 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/python/logs/python/2026-08-17-104629.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.60 | 2.32 | 3.94 | 448 | 2603 | fast writer (Rust core) | fastest | yes | 90 |
| msgspec | 0.21.1 | 1.97 | 2.60 | 4.59 | 192 | 2322 | typed; writes a list of values | — | yes | 85 |
| serpyco-rs | 1.21.0 | 3.22 | 4.66 | 7.79 | 448 | 2603 | typed helper; uses orjson for the text | slower | yes | 92 |
| mashumaro | 3.22 | 3.59 | 7.94 | 11.4 | 448 | 2603 | typed helper; uses orjson for the text | slower | yes | 86 |
| rapidjson | 1.23 | 6.06 | 6.86 | 13.0 | 448 | 2603 | fast writer (C++ core) | slower | yes | 78 |
| json | python-3.14.0 | 12.5 | 8.37 | 20.8 | 448 | 2603 | ships with Python | slower | yes | 91 |
| pydantic | 2.13.4 | 9.03 | 16.8 | 25.8 | 448 | 2654 | checks types at the public door | slower | yes | 85 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 51.0 | 81.2 | 132 | 19804 | 2322 | typed; writes a list of values | — | yes | 84 |
| orjson | 3.11.9 | 57.6 | 127 | 184 | 45404 | 2603 | fast writer (Rust core) | fastest | yes | 80 |
| serpyco-rs | 1.21.0 | 140 | 262 | 402 | 45404 | 2603 | typed helper; uses orjson for the text | slower | yes | 89 |
| rapidjson | 1.23 | 176 | 299 | 475 | 45404 | 2603 | fast writer (C++ core) | slower | yes | 92 |
| mashumaro | 3.22 | 149 | 397 | 545 | 45404 | 2603 | typed helper; uses orjson for the text | slower | yes | 85 |
| json | python-3.14.0 | 303 | 294 | 599 | 45404 | 2603 | ships with Python | slower | yes | 93 |
| pydantic | 2.13.4 | 582 | 796 | 1378 | 51203 | 2654 | checks types at the public door | slower | yes | 89 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.29 | 1.65 | 3.02 | 257 | 2603 | fast writer (Rust core) | fastest | yes | 97 |
| msgspec | 0.21.1 | 1.59 | 2.09 | 3.67 | 144 | 2322 | typed; writes a list of values | — | yes | 87 |
| serpyco-rs | 1.21.0 | 2.35 | 3.13 | 5.48 | 257 | 2603 | typed helper; uses orjson for the text | slower | yes | 96 |
| mashumaro | 3.22 | 2.52 | 4.41 | 6.96 | 257 | 2603 | typed helper; uses orjson for the text | slower | yes | 93 |
| rapidjson | 1.23 | 4.34 | 4.92 | 9.23 | 257 | 2603 | fast writer (C++ core) | slower | yes | 89 |
| json | python-3.14.0 | 9.87 | 5.97 | 15.9 | 257 | 2603 | ships with Python | slower | yes | 90 |
| pydantic | 2.13.4 | 6.80 | 12.2 | 19.0 | 257 | 2654 | checks types at the public door | slower | yes | 83 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 45.5 | 56.2 | 102 | 14446 | 2322 | typed; writes a list of values | — | yes | 93 |
| orjson | 3.11.9 | 59.7 | 79.7 | 140 | 25746 | 2603 | fast writer (Rust core) | fastest | yes | 82 |
| serpyco-rs | 1.21.0 | 86.0 | 128 | 216 | 25746 | 2603 | typed helper; uses orjson for the text | slower | yes | 89 |
| rapidjson | 1.23 | 103 | 153 | 259 | 25746 | 2603 | fast writer (C++ core) | slower | yes | 90 |
| mashumaro | 3.22 | 88.6 | 181 | 270 | 25746 | 2603 | typed helper; uses orjson for the text | slower | yes | 93 |
| json | python-3.14.0 | 211 | 147 | 360 | 25746 | 2603 | ships with Python | slower | yes | 89 |
| pydantic | 2.13.4 | 379 | 409 | 789 | 28245 | 2654 | checks types at the public door | slower | yes | 92 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 0.74 | 1.06 | 1.83 | 168 | 2603 | fast writer (Rust core) | fastest | yes | 92 |
| msgspec | 0.21.1 | 1.30 | 1.30 | 2.65 | 80 | 2322 | typed; writes a list of values | — | yes | 89 |
| serpyco-rs | 1.21.0 | 1.81 | 2.17 | 3.96 | 168 | 2603 | typed helper; uses orjson for the text | slower | yes | 88 |
| mashumaro | 3.22 | 1.40 | 2.79 | 4.25 | 168 | 2603 | typed helper; uses orjson for the text | slower | yes | 95 |
| rapidjson | 1.23 | 3.66 | 3.93 | 7.59 | 168 | 2603 | fast writer (C++ core) | slower | yes | 92 |
| json | python-3.14.0 | 7.36 | 4.50 | 12.0 | 168 | 2603 | ships with Python | slower | yes | 94 |
| pydantic | 2.13.4 | 4.87 | 8.71 | 13.5 | 168 | 2654 | checks types at the public door | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 20.5 | 23.8 | 44.6 | 7746 | 2322 | typed; writes a list of values | — | yes | 84 |
| orjson | 3.11.9 | 19.4 | 36.6 | 55.6 | 16546 | 2603 | fast writer (Rust core) | fastest | yes | 90 |
| serpyco-rs | 1.21.0 | 36.1 | 55.7 | 92.3 | 16546 | 2603 | typed helper; uses orjson for the text | slower | yes | 88 |
| mashumaro | 3.22 | 33.9 | 80.0 | 114 | 16546 | 2603 | typed helper; uses orjson for the text | slower | yes | 92 |
| rapidjson | 1.23 | 88.4 | 105 | 194 | 16546 | 2603 | fast writer (C++ core) | slower | yes | 85 |
| json | python-3.14.0 | 116 | 102 | 218 | 16546 | 2603 | ships with Python | slower | yes | 90 |
| pydantic | 2.13.4 | 206 | 199 | 408 | 18145 | 2654 | checks types at the public door | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 0.95 | 1.27 | 2.25 | 410 | 2603 | fast writer (Rust core) | fastest | yes | 92 |
| serpyco-rs | 1.21.0 | 1.72 | 2.16 | 3.86 | 410 | 2603 | typed helper; uses orjson for the text | slower | yes | 88 |
| msgspec | 0.21.1 | 1.69 | 2.24 | 3.94 | 402 | 2322 | typed; writes a list of values | — | yes | 87 |
| mashumaro | 3.22 | 1.35 | 3.04 | 4.42 | 410 | 2603 | typed helper; uses orjson for the text | slower | yes | 91 |
| rapidjson | 1.23 | 4.00 | 3.55 | 7.65 | 410 | 2603 | fast writer (C++ core) | slower | yes | 85 |
| pydantic | 2.13.4 | 5.00 | 8.23 | 13.2 | 410 | 2654 | checks types at the public door | slower | yes | 86 |
| json | python-3.14.0 | 8.91 | 4.92 | 13.8 | 410 | 2603 | ships with Python | slower | yes | 89 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 71.3 | 101 | 174 | 40764 | 2322 | typed; writes a list of values | — | yes | 92 |
| orjson | 3.11.9 | 68.6 | 110 | 179 | 41564 | 2603 | fast writer (Rust core) | fastest | yes | 85 |
| serpyco-rs | 1.21.0 | 79.9 | 138 | 219 | 41564 | 2603 | typed helper; uses orjson for the text | slower | yes | 93 |
| mashumaro | 3.22 | 70.2 | 174 | 246 | 41564 | 2603 | typed helper; uses orjson for the text | slower | yes | 94 |
| rapidjson | 1.23 | 119 | 158 | 279 | 41564 | 2603 | fast writer (C++ core) | slower | yes | 94 |
| json | python-3.14.0 | 210 | 152 | 362 | 41564 | 2603 | ships with Python | slower | yes | 94 |
| pydantic | 2.13.4 | 319 | 259 | 578 | 44863 | 2654 | checks types at the public door | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.60 | 1.80 | 3.42 | 663 | 2603 | fast writer (Rust core) | fastest | yes | 90 |
| serpyco-rs | 1.21.0 | 2.48 | 3.24 | 5.71 | 663 | 2603 | typed helper; uses orjson for the text | slower | yes | 92 |
| msgspec | 0.21.1 | 3.48 | 2.94 | 6.39 | 633 | 2322 | typed; writes a list of values | — | yes | 85 |
| mashumaro | 3.22 | 2.13 | 4.38 | 6.51 | 663 | 2603 | typed helper; uses orjson for the text | slower | yes | 87 |
| pydantic | 2.13.4 | 6.96 | 16.3 | 23.5 | 663 | 2654 | checks types at the public door | slower | yes | 84 |
| rapidjson | 1.23 | 15.3 | 9.97 | 25.4 | 663 | 2603 | fast writer (C++ core) | slower | yes | 83 |
| json | python-3.14.0 | 18.8 | 11.3 | 30.2 | 663 | 2603 | ships with Python | slower | yes | 84 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 83.6 | 113 | 197 | 65958 | 2603 | fast writer (Rust core) | fastest | yes | 86 |
| msgspec | 0.21.1 | 120 | 123 | 246 | 62958 | 2322 | typed; writes a list of values | — | yes | 95 |
| serpyco-rs | 1.21.0 | 103 | 161 | 265 | 65958 | 2603 | typed helper; uses orjson for the text | slower | yes | 95 |
| mashumaro | 3.22 | 89.4 | 207 | 296 | 65958 | 2603 | typed helper; uses orjson for the text | slower | yes | 93 |
| json | python-3.14.0 | 1034 | 613 | 1644 | 65958 | 2603 | ships with Python | slower | yes | 94 |
| rapidjson | 1.23 | 1056 | 623 | 1682 | 65958 | 2603 | fast writer (C++ core) | slower | yes | 93 |
| pydantic | 2.13.4 | 1175 | 734 | 1906 | 69957 | 2654 | checks types at the public door | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample A (order), N = 100, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample D (event), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample D (event), N = 100, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample B (flat), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample B (flat), N = 100, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample E (words), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample E (words), N = 100, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

**sample C (sensor), N = 100, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`.

