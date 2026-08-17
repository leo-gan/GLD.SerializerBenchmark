# Experiment 13 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/go/logs/go/2026-08-17-104731.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.45 | 2.18 | 3.66 | 448 | — | fast writer | fastest | yes | 91 |
| segmentio/encoding/json | 0.5.4 | 1.31 | 2.57 | 3.97 | 448 | — | production fork of encoding/json | similar | yes | 87 |
| sonic | 1.15.2 | 1.48 | 2.72 | 4.26 | 448 | — | fast writer | close | yes | 86 |
| jsoniter | 1.1.12 | 2.16 | 2.98 | 5.20 | 448 | — | fast writer | slower | yes | 94 |
| ugorji/json | 1.3.2 | 2.37 | 3.62 | 5.90 | 448 | — | multi-format library | slower | yes | 94 |
| encoding/json | go1.24.13 | 1.75 | 8.42 | 10.2 | 448 | — | ships with Go | slower | yes | 87 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 60.0 | 98.0 | 158 | 45404 | — | fast writer | fastest | yes | 80 |
| goccy/go-json | 0.10.6 | 67.3 | 103 | 173 | 45404 | — | fast writer | close | yes | 86 |
| segmentio/encoding/json | 0.5.4 | 68.1 | 113 | 181 | 45404 | — | production fork of encoding/json | slower | yes | 88 |
| jsoniter | 1.1.12 | 96.7 | 142 | 239 | 45404 | — | fast writer | slower | yes | 93 |
| ugorji/json | 1.3.2 | 74.7 | 179 | 254 | 45404 | — | multi-format library | slower | yes | 87 |
| encoding/json | go1.24.13 | 91.2 | 549 | 646 | 45404 | — | ships with Go | slower | yes | 86 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 0.83 | 1.22 | 2.02 | 257 | — | fast writer | fastest | yes | 87 |
| sonic | 1.15.2 | 0.76 | 1.32 | 2.06 | 257 | — | fast writer | similar | yes | 88 |
| segmentio/encoding/json | 0.5.4 | 0.69 | 1.54 | 2.25 | 257 | — | production fork of encoding/json | close | yes | 89 |
| jsoniter | 1.1.12 | 0.93 | 1.50 | 2.40 | 257 | — | fast writer | slower | yes | 90 |
| ugorji/json | 1.3.2 | 1.19 | 1.83 | 3.10 | 257 | — | multi-format library | slower | yes | 92 |
| encoding/json | go1.24.13 | 0.85 | 4.12 | 4.98 | 257 | — | ships with Go | slower | yes | 88 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 42.6 | 51.5 | 93.1 | 25746 | — | fast writer | fastest | yes | 91 |
| goccy/go-json | 0.10.6 | 42.0 | 61.2 | 105 | 25746 | — | fast writer | slower | yes | 88 |
| segmentio/encoding/json | 0.5.4 | 43.9 | 75.3 | 119 | 25746 | — | production fork of encoding/json | slower | yes | 91 |
| jsoniter | 1.1.12 | 51.3 | 84.9 | 137 | 25746 | — | fast writer | slower | yes | 88 |
| ugorji/json | 1.3.2 | 45.1 | 109 | 154 | 25746 | — | multi-format library | slower | yes | 90 |
| encoding/json | go1.24.13 | 54.6 | 292 | 349 | 25746 | — | ships with Go | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| segmentio/encoding/json | 0.5.4 | 0.66 | 1.19 | 1.88 | 168 | — | production fork of encoding/json | fastest | yes | 87 |
| sonic | 1.15.2 | 0.73 | 1.25 | 2.04 | 168 | — | fast writer | similar | yes | 85 |
| goccy/go-json | 0.10.6 | 0.89 | 1.12 | 2.08 | 168 | — | fast writer | similar | yes | 90 |
| jsoniter | 1.1.12 | 0.96 | 1.31 | 2.27 | 168 | — | fast writer | slower | yes | 87 |
| ugorji/json | 1.3.2 | 1.17 | 1.50 | 2.67 | 168 | — | multi-format library | slower | yes | 91 |
| encoding/json | go1.24.13 | 0.77 | 2.85 | 3.59 | 168 | — | ships with Go | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 14.5 | 26.2 | 40.2 | 16546 | — | fast writer | fastest | yes | 85 |
| goccy/go-json | 0.10.6 | 21.9 | 34.1 | 56.4 | 16546 | — | fast writer | slower | yes | 84 |
| segmentio/encoding/json | 0.5.4 | 21.7 | 38.1 | 60.5 | 16546 | — | production fork of encoding/json | slower | yes | 88 |
| jsoniter | 1.1.12 | 33.5 | 52.9 | 87.6 | 16546 | — | fast writer | slower | yes | 86 |
| ugorji/json | 1.3.2 | 28.3 | 60.3 | 88.8 | 16546 | — | multi-format library | slower | yes | 85 |
| encoding/json | go1.24.13 | 29.3 | 150 | 180 | 16546 | — | ships with Go | slower | yes | 85 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 0.90 | 1.46 | 2.32 | 411 | — | fast writer | fastest | yes | 92 |
| goccy/go-json | 0.10.6 | 1.21 | 1.95 | 3.22 | 411 | — | fast writer | slower | yes | 94 |
| jsoniter | 1.1.12 | 1.11 | 2.29 | 3.25 | 411 | — | fast writer | slower | yes | 95 |
| segmentio/encoding/json | 0.5.4 | 1.06 | 2.45 | 3.43 | 411 | — | production fork of encoding/json | slower | yes | 94 |
| ugorji/json | 1.3.2 | 1.33 | 2.50 | 3.94 | 411 | — | multi-format library | slower | yes | 92 |
| encoding/json | go1.24.13 | 1.38 | 6.26 | 7.58 | 411 | — | ships with Go | slower | yes | 95 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 79.5 | 66.7 | 148 | 41431 | — | fast writer | fastest | yes | 85 |
| ugorji/json | 1.3.2 | 63.7 | 150 | 214 | 41431 | — | multi-format library | slower | yes | 90 |
| goccy/go-json | 0.10.6 | 90.3 | 131 | 221 | 41431 | — | fast writer | slower | yes | 82 |
| jsoniter | 1.1.12 | 84.5 | 148 | 233 | 41431 | — | fast writer | slower | yes | 83 |
| segmentio/encoding/json | 0.5.4 | 89.2 | 144 | 235 | 41431 | — | production fork of encoding/json | slower | yes | 86 |
| encoding/json | go1.24.13 | 93.6 | 450 | 545 | 41431 | — | ships with Go | slower | yes | 82 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 1.79 | 2.40 | 4.32 | 663 | — | fast writer | fastest | yes | 90 |
| segmentio/encoding/json | 0.5.4 | 3.02 | 4.08 | 7.16 | 663 | — | production fork of encoding/json | slower | yes | 79 |
| goccy/go-json | 0.10.6 | 3.36 | 3.99 | 7.44 | 663 | — | fast writer | slower | yes | 85 |
| ugorji/json | 1.3.2 | 3.79 | 5.22 | 9.01 | 663 | — | multi-format library | slower | yes | 84 |
| jsoniter | 1.1.12 | 3.32 | 6.76 | 10.1 | 663 | — | fast writer | slower | yes | 88 |
| encoding/json | go1.24.13 | 3.35 | 8.71 | 12.2 | 663 | — | ships with Go | slower | yes | 80 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.2 | 139 | 126 | 267 | 65958 | — | fast writer | fastest | yes | 84 |
| segmentio/encoding/json | 0.5.4 | 247 | 301 | 553 | 65958 | — | production fork of encoding/json | slower | yes | 78 |
| goccy/go-json | 0.10.6 | 266 | 304 | 574 | 65958 | — | fast writer | slower | yes | 77 |
| ugorji/json | 1.3.2 | 235 | 379 | 620 | 65958 | — | multi-format library | slower | yes | 80 |
| jsoniter | 1.1.12 | 248 | 525 | 775 | 65958 | — | fast writer | slower | yes | 76 |
| encoding/json | go1.24.13 | 281 | 662 | 946 | 65958 | — | ships with Go | slower | yes | 82 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `goccy/go-json`, `segmentio/encoding/json`. Small gap: `sonic`. Time/size front: `goccy/go-json`.

**sample A (order), N = 100, memory** — not clearly slower: `sonic`. Small gap: `goccy/go-json`. Time/size front: `sonic`.

**sample D (event), N = 1, memory** — not clearly slower: `goccy/go-json`, `sonic`. Small gap: `segmentio/encoding/json`. Time/size front: `goccy/go-json`.

**sample D (event), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample B (flat), N = 1, memory** — not clearly slower: `segmentio/encoding/json`, `sonic`, `goccy/go-json`. Small gap: —. Time/size front: `segmentio/encoding/json`.

**sample B (flat), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample E (words), N = 1, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample E (words), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample C (sensor), N = 1, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample C (sensor), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

