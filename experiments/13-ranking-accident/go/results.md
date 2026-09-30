# Experiment 13 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/13-ranking-accident/go/logs/go/2026-09-29-185634.csv`
**Language:** go
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.57 | 2.34 | 3.85 | 448 | 2526 | fast writer | fastest | yes | 90 |
| segmentio/encoding/json | 0.5.4 | 1.21 | 2.77 | 4.01 | 448 | 2526 | production fork of encoding/json | similar | yes | 79 |
| sonic | 1.15.4 | 1.96 | 3.18 | 5.24 | 448 | 2526 | fast writer | slower | yes | 81 |
| jsoniter | 1.1.12 | 2.29 | 3.00 | 5.33 | 448 | 2526 | fast writer | slower | yes | 91 |
| ugorji/json | 1.3.2 | 2.56 | 4.09 | 6.61 | 448 | 2526 | multi-format library | slower | yes | 87 |
| encoding/json | go1.24.13 | 1.89 | 8.96 | 10.9 | 448 | 2526 | ships with Go | slower | yes | 82 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 59.5 | 94.9 | 157 | 45404 | 2526 | fast writer | fastest | yes | 76 |
| segmentio/encoding/json | 0.5.4 | 64.8 | 107 | 172 | 45404 | 2526 | production fork of encoding/json | slower | yes | 81 |
| goccy/go-json | 0.10.6 | 66.2 | 103 | 173 | 45404 | 2526 | fast writer | slower | yes | 85 |
| jsoniter | 1.1.12 | 96.0 | 138 | 238 | 45404 | 2526 | fast writer | slower | yes | 85 |
| ugorji/json | 1.3.2 | 72.3 | 179 | 251 | 45404 | 2526 | multi-format library | slower | yes | 80 |
| encoding/json | go1.24.13 | 93.3 | 530 | 625 | 45404 | 2526 | ships with Go | slower | yes | 84 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 1.01 | 1.39 | 2.42 | 257 | 2526 | fast writer | fastest | yes | 90 |
| segmentio/encoding/json | 0.5.4 | 0.82 | 1.95 | 2.80 | 257 | 2526 | production fork of encoding/json | close | yes | 87 |
| sonic | 1.15.4 | 1.03 | 1.91 | 3.03 | 257 | 2526 | fast writer | close | yes | 83 |
| jsoniter | 1.1.12 | 1.27 | 1.77 | 3.07 | 257 | 2526 | fast writer | slower | yes | 85 |
| ugorji/json | 1.3.2 | 1.62 | 2.47 | 4.09 | 257 | 2526 | multi-format library | slower | yes | 87 |
| encoding/json | go1.24.13 | 1.21 | 4.92 | 6.13 | 257 | 2526 | ships with Go | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 46.9 | 51.8 | 100 | 25746 | 2526 | fast writer | fastest | yes | 85 |
| goccy/go-json | 0.10.6 | 43.2 | 59.6 | 104 | 25746 | 2526 | fast writer | similar | yes | 87 |
| segmentio/encoding/json | 0.5.4 | 44.9 | 74.2 | 119 | 25746 | 2526 | production fork of encoding/json | slower | yes | 91 |
| jsoniter | 1.1.12 | 53.1 | 82.4 | 136 | 25746 | 2526 | fast writer | slower | yes | 89 |
| ugorji/json | 1.3.2 | 44.9 | 110 | 154 | 25746 | 2526 | multi-format library | slower | yes | 92 |
| encoding/json | go1.24.13 | 54.8 | 281 | 335 | 25746 | 2526 | ships with Go | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| goccy/go-json | 0.10.6 | 0.72 | 0.96 | 1.68 | 168 | 2526 | fast writer | fastest | yes | 84 |
| sonic | 1.15.4 | 0.57 | 1.11 | 1.69 | 168 | 2526 | fast writer | similar | yes | 86 |
| segmentio/encoding/json | 0.5.4 | 0.56 | 1.16 | 1.75 | 168 | 2526 | production fork of encoding/json | similar | yes | 88 |
| jsoniter | 1.1.12 | 0.98 | 1.31 | 2.32 | 168 | 2526 | fast writer | slower | yes | 86 |
| ugorji/json | 1.3.2 | 1.09 | 1.50 | 2.60 | 168 | 2526 | multi-format library | slower | yes | 88 |
| encoding/json | go1.24.13 | 0.79 | 2.70 | 3.52 | 168 | 2526 | ships with Go | slower | yes | 84 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 16.7 | 29.3 | 46.4 | 16546 | 2526 | fast writer | fastest | yes | 86 |
| goccy/go-json | 0.10.6 | 24.8 | 35.0 | 60.9 | 16546 | 2526 | fast writer | slower | yes | 82 |
| segmentio/encoding/json | 0.5.4 | 24.8 | 36.5 | 62.8 | 16546 | 2526 | production fork of encoding/json | slower | yes | 85 |
| ugorji/json | 1.3.2 | 30.0 | 63.1 | 93.1 | 16546 | 2526 | multi-format library | slower | yes | 85 |
| jsoniter | 1.1.12 | 37.5 | 56.4 | 94.5 | 16546 | 2526 | fast writer | slower | yes | 85 |
| encoding/json | go1.24.13 | 33.9 | 154 | 189 | 16546 | 2526 | ships with Go | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 0.67 | 1.12 | 1.85 | 411 | 2526 | fast writer | fastest | yes | 77 |
| goccy/go-json | 0.10.6 | 0.85 | 1.63 | 2.50 | 411 | 2526 | fast writer | slower | yes | 72 |
| segmentio/encoding/json | 0.5.4 | 0.71 | 2.11 | 2.85 | 411 | 2526 | production fork of encoding/json | slower | yes | 77 |
| jsoniter | 1.1.12 | 0.97 | 1.83 | 2.96 | 411 | 2526 | fast writer | slower | yes | 82 |
| ugorji/json | 1.3.2 | 1.09 | 2.15 | 3.31 | 411 | 2526 | multi-format library | slower | yes | 87 |
| encoding/json | go1.24.13 | 1.20 | 5.42 | 6.62 | 411 | 2526 | ships with Go | slower | yes | 80 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 78.7 | 65.0 | 144 | 41431 | 2526 | fast writer | fastest | yes | 89 |
| ugorji/json | 1.3.2 | 62.5 | 156 | 219 | 41431 | 2526 | multi-format library | slower | yes | 85 |
| goccy/go-json | 0.10.6 | 90.6 | 130 | 222 | 41431 | 2526 | fast writer | slower | yes | 87 |
| jsoniter | 1.1.12 | 86.7 | 148 | 238 | 41431 | 2526 | fast writer | slower | yes | 90 |
| segmentio/encoding/json | 0.5.4 | 91.0 | 151 | 240 | 41431 | 2526 | production fork of encoding/json | slower | yes | 89 |
| encoding/json | go1.24.13 | 101 | 466 | 564 | 41431 | 2526 | ships with Go | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 1.99 | 2.57 | 4.61 | 663 | 2526 | fast writer | fastest | yes | 87 |
| goccy/go-json | 0.10.6 | 3.37 | 4.00 | 7.40 | 663 | 2526 | fast writer | slower | yes | 85 |
| segmentio/encoding/json | 0.5.4 | 3.02 | 4.46 | 7.62 | 663 | 2526 | production fork of encoding/json | slower | yes | 85 |
| ugorji/json | 1.3.2 | 4.00 | 5.76 | 9.67 | 663 | 2526 | multi-format library | slower | yes | 89 |
| jsoniter | 1.1.12 | 3.67 | 6.89 | 10.6 | 663 | 2526 | fast writer | slower | yes | 85 |
| encoding/json | go1.24.13 | 3.52 | 8.81 | 12.5 | 663 | 2526 | ships with Go | slower | yes | 89 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| sonic | 1.15.4 | 148 | 127 | 276 | 65958 | 2526 | fast writer | fastest | yes | 78 |
| goccy/go-json | 0.10.6 | 262 | 290 | 553 | 65958 | 2526 | fast writer | slower | yes | 78 |
| segmentio/encoding/json | 0.5.4 | 249 | 317 | 561 | 65958 | 2526 | production fork of encoding/json | slower | yes | 84 |
| ugorji/json | 1.3.2 | 247 | 384 | 629 | 65958 | 2526 | multi-format library | slower | yes | 76 |
| jsoniter | 1.1.12 | 251 | 519 | 769 | 65958 | 2526 | fast writer | slower | yes | 84 |
| encoding/json | go1.24.13 | 270 | 638 | 914 | 65958 | 2526 | ships with Go | slower | yes | 81 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `goccy/go-json`, `segmentio/encoding/json`. Small gap: —. Time/size front: `goccy/go-json`.

**sample A (order), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample D (event), N = 1, memory** — not clearly slower: `goccy/go-json`. Small gap: `segmentio/encoding/json`, `sonic`. Time/size front: `goccy/go-json`.

**sample D (event), N = 100, memory** — not clearly slower: `sonic`, `goccy/go-json`. Small gap: —. Time/size front: `sonic`.

**sample B (flat), N = 1, memory** — not clearly slower: `goccy/go-json`, `sonic`, `segmentio/encoding/json`. Small gap: —. Time/size front: `goccy/go-json`.

**sample B (flat), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample E (words), N = 1, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample E (words), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample C (sensor), N = 1, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

**sample C (sensor), N = 100, memory** — not clearly slower: `sonic`. Small gap: —. Time/size front: `sonic`.

