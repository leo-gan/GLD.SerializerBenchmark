# Experiment 13 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/python/logs/python/2026-09-29-185357.csv`
**Language:** python
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 3.65 | 3.79 | 7.33 | 448 | 2603 | fast writer (Rust core) | fastest | yes | 87 |
| msgspec | 0.21.1 | 4.05 | 4.26 | 8.11 | 192 | 2322 | typed; writes a list of values | — | yes | 95 |
| serpyco-rs | 1.22.0 | 7.41 | 8.25 | 15.9 | 448 | 2603 | typed helper; uses orjson for the text | slower | yes | 89 |
| mashumaro | 3.22 | 5.95 | 12.5 | 18.4 | 448 | 2603 | typed helper; uses orjson for the text | slower | yes | 88 |
| rapidjson | 1.25 | 11.4 | 11.0 | 22.9 | 448 | 2603 | fast writer (C++ core) | slower | yes | 92 |
| json | python-3.14.0 | 20.5 | 15.1 | 36.3 | 448 | 2603 | ships with Python | slower | yes | 95 |
| pydantic | 2.13.5 | 24.6 | 27.0 | 52.3 | 448 | 2603 | checks types at the public door | slower | yes | 95 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 61.6 | 105 | 170 | 19804 | 2322 | typed; writes a list of values | — | yes | 93 |
| orjson | 3.12.0 | 79.1 | 157 | 236 | 45404 | 2603 | fast writer (Rust core) | fastest | yes | 91 |
| serpyco-rs | 1.22.0 | 174 | 308 | 481 | 45404 | 2603 | typed helper; uses orjson for the text | slower | yes | 92 |
| rapidjson | 1.25 | 205 | 352 | 554 | 45404 | 2603 | fast writer (C++ core) | slower | yes | 87 |
| mashumaro | 3.22 | 185 | 460 | 645 | 45404 | 2603 | typed helper; uses orjson for the text | slower | yes | 85 |
| json | python-3.14.0 | 352 | 346 | 704 | 45404 | 2603 | ships with Python | slower | yes | 91 |
| pydantic | 2.13.5 | 282 | 801 | 1089 | 45404 | 2603 | checks types at the public door | slower | yes | 95 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.48 | 2.63 | 5.12 | 257 | 2603 | fast writer (Rust core) | fastest | yes | 88 |
| msgspec | 0.21.1 | 2.72 | 3.19 | 5.78 | 144 | 2322 | typed; writes a list of values | — | yes | 89 |
| serpyco-rs | 1.22.0 | 5.64 | 6.19 | 11.6 | 257 | 2603 | typed helper; uses orjson for the text | slower | yes | 96 |
| mashumaro | 3.22 | 4.47 | 7.37 | 11.9 | 257 | 2603 | typed helper; uses orjson for the text | slower | yes | 89 |
| rapidjson | 1.25 | 7.47 | 7.89 | 16.3 | 257 | 2603 | fast writer (C++ core) | slower | yes | 93 |
| json | python-3.14.0 | 15.7 | 11.3 | 27.4 | 257 | 2603 | ships with Python | slower | yes | 96 |
| pydantic | 2.13.5 | 14.2 | 15.5 | 29.7 | 257 | 2603 | checks types at the public door | slower | yes | 88 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 51.0 | 59.0 | 110 | 14446 | 2322 | typed; writes a list of values | — | yes | 78 |
| orjson | 3.12.0 | 71.7 | 83.1 | 155 | 25746 | 2603 | fast writer (Rust core) | fastest | yes | 86 |
| serpyco-rs | 1.22.0 | 96.8 | 131 | 228 | 25746 | 2603 | typed helper; uses orjson for the text | slower | yes | 88 |
| rapidjson | 1.25 | 106 | 156 | 261 | 25746 | 2603 | fast writer (C++ core) | slower | yes | 91 |
| mashumaro | 3.22 | 96.9 | 186 | 286 | 25746 | 2603 | typed helper; uses orjson for the text | slower | yes | 92 |
| json | python-3.14.0 | 216 | 148 | 365 | 25746 | 2603 | ships with Python | slower | yes | 82 |
| pydantic | 2.13.5 | 153 | 393 | 547 | 25746 | 2603 | checks types at the public door | slower | yes | 77 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 1.25 | 1.77 | 3.00 | 168 | 2603 | fast writer (Rust core) | fastest | yes | 85 |
| msgspec | 0.21.1 | 1.74 | 1.71 | 3.40 | 80 | 2322 | typed; writes a list of values | — | yes | 86 |
| mashumaro | 3.22 | 2.40 | 4.51 | 6.95 | 168 | 2603 | typed helper; uses orjson for the text | slower | yes | 87 |
| serpyco-rs | 1.22.0 | 3.50 | 4.01 | 7.73 | 168 | 2603 | typed helper; uses orjson for the text | slower | yes | 90 |
| rapidjson | 1.25 | 5.15 | 5.54 | 10.7 | 168 | 2603 | fast writer (C++ core) | slower | yes | 85 |
| pydantic | 2.13.5 | 8.19 | 8.91 | 17.4 | 168 | 2603 | checks types at the public door | slower | yes | 90 |
| json | python-3.14.0 | 10.8 | 8.61 | 19.4 | 168 | 2603 | ships with Python | slower | yes | 90 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 24.1 | 27.7 | 51.8 | 7746 | 2322 | typed; writes a list of values | — | yes | 96 |
| orjson | 3.12.0 | 27.2 | 46.8 | 73.0 | 16546 | 2603 | fast writer (Rust core) | fastest | yes | 96 |
| serpyco-rs | 1.22.0 | 49.8 | 71.2 | 120 | 16546 | 2603 | typed helper; uses orjson for the text | slower | yes | 95 |
| mashumaro | 3.22 | 41.3 | 97.8 | 139 | 16546 | 2603 | typed helper; uses orjson for the text | slower | yes | 95 |
| rapidjson | 1.25 | 101 | 124 | 222 | 16546 | 2603 | fast writer (C++ core) | slower | yes | 92 |
| pydantic | 2.13.5 | 71.5 | 163 | 238 | 16546 | 2603 | checks types at the public door | slower | yes | 97 |
| json | python-3.14.0 | 136 | 121 | 259 | 16546 | 2603 | ships with Python | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.16 | 2.20 | 4.46 | 410 | 2603 | fast writer (Rust core) | fastest | yes | 92 |
| msgspec | 0.21.1 | 2.47 | 2.83 | 5.25 | 402 | 2322 | typed; writes a list of values | — | yes | 90 |
| mashumaro | 3.22 | 2.49 | 4.33 | 6.92 | 410 | 2603 | typed helper; uses orjson for the text | slower | yes | 84 |
| serpyco-rs | 1.22.0 | 3.69 | 4.18 | 7.87 | 410 | 2603 | typed helper; uses orjson for the text | slower | yes | 91 |
| rapidjson | 1.25 | 5.94 | 4.70 | 10.6 | 410 | 2603 | fast writer (C++ core) | slower | yes | 91 |
| pydantic | 2.13.5 | 9.61 | 9.68 | 19.9 | 410 | 2603 | checks types at the public door | slower | yes | 93 |
| json | python-3.14.0 | 11.9 | 8.07 | 20.2 | 410 | 2603 | ships with Python | slower | yes | 90 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| msgspec | 0.21.1 | 76.3 | 105 | 183 | 40764 | 2322 | typed; writes a list of values | — | yes | 86 |
| orjson | 3.12.0 | 81.6 | 120 | 206 | 41564 | 2603 | fast writer (Rust core) | fastest | yes | 94 |
| serpyco-rs | 1.22.0 | 93.6 | 147 | 243 | 41564 | 2603 | typed helper; uses orjson for the text | slower | yes | 84 |
| mashumaro | 3.22 | 83.5 | 188 | 275 | 41564 | 2603 | typed helper; uses orjson for the text | slower | yes | 94 |
| rapidjson | 1.25 | 126 | 165 | 295 | 41564 | 2603 | fast writer (C++ core) | slower | yes | 91 |
| json | python-3.14.0 | 233 | 169 | 405 | 41564 | 2603 | ships with Python | slower | yes | 88 |
| pydantic | 2.13.5 | 123 | 368 | 494 | 41564 | 2603 | checks types at the public door | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.52 | 2.54 | 5.21 | 663 | 2603 | fast writer (Rust core) | fastest | yes | 85 |
| msgspec | 0.21.1 | 3.85 | 3.28 | 7.07 | 633 | 2322 | typed; writes a list of values | — | yes | 91 |
| mashumaro | 3.22 | 3.31 | 5.67 | 8.90 | 663 | 2603 | typed helper; uses orjson for the text | slower | yes | 89 |
| serpyco-rs | 1.22.0 | 4.40 | 4.83 | 9.20 | 663 | 2603 | typed helper; uses orjson for the text | slower | yes | 90 |
| pydantic | 2.13.5 | 9.57 | 10.1 | 19.6 | 663 | 2603 | checks types at the public door | slower | yes | 89 |
| rapidjson | 1.25 | 18.5 | 12.2 | 30.8 | 663 | 2603 | fast writer (C++ core) | slower | yes | 88 |
| json | python-3.14.0 | 22.7 | 15.9 | 38.9 | 663 | 2603 | ships with Python | slower | yes | 91 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 94.8 | 117 | 211 | 65958 | 2603 | fast writer (Rust core) | fastest | yes | 83 |
| msgspec | 0.21.1 | 126 | 123 | 250 | 62958 | 2322 | typed; writes a list of values | — | yes | 86 |
| serpyco-rs | 1.22.0 | 113 | 158 | 269 | 65958 | 2603 | typed helper; uses orjson for the text | slower | yes | 91 |
| mashumaro | 3.22 | 98.6 | 217 | 314 | 65958 | 2603 | typed helper; uses orjson for the text | slower | yes | 86 |
| pydantic | 2.13.5 | 171 | 319 | 488 | 65958 | 2603 | checks types at the public door | slower | yes | 81 |
| json | python-3.14.0 | 1053 | 627 | 1683 | 65958 | 2603 | ships with Python | slower | yes | 89 |
| rapidjson | 1.25 | 1149 | 647 | 1798 | 65958 | 2603 | fast writer (C++ core) | slower | yes | 92 |

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

