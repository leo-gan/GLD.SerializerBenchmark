# Experiment 13 results — swift

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/swift/logs/swift/2026-08-17-105237.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 20.4 | 33.9 | 54.7 | 448 | — | server JSON library | fastest | yes | 85 |
| Foundation.JSONEncoder | Foundation | 23.3 | 33.4 | 56.7 | 448 | — | ships with Swift | slower | yes | 79 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 1320 | 2062 | 3387 | 45404 | — | ships with Swift | fastest | yes | 91 |
| IkigaJSON | 2.5.3 | 1208 | 2265 | 3472 | 45404 | — | server JSON library | slower | yes | 92 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 12.5 | 18.1 | 30.7 | 257 | — | server JSON library | fastest | yes | 81 |
| Foundation.JSONEncoder | Foundation | 14.6 | 17.0 | 31.9 | 257 | — | ships with Swift | slower | yes | 78 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 671 | 776 | 1450 | 25746 | — | ships with Swift | fastest | yes | 95 |
| IkigaJSON | 2.5.3 | 588 | 983 | 1574 | 25746 | — | server JSON library | slower | yes | 97 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 7.84 | 11.9 | 19.7 | 168 | — | server JSON library | fastest | yes | 79 |
| Foundation.JSONEncoder | Foundation | 8.71 | 11.8 | 20.5 | 168 | — | ships with Swift | slower | yes | 78 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 281 | 425 | 707 | 16546 | — | ships with Swift | fastest | yes | 90 |
| IkigaJSON | 2.5.3 | 307 | 485 | 794 | 16546 | — | server JSON library | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 14.1 | 18.9 | 33.1 | 411 | — | server JSON library | fastest | yes | 77 |
| Foundation.JSONEncoder | Foundation | 19.2 | 16.7 | 36.0 | 411 | — | ships with Swift | slower | yes | 82 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 921 | 1299 | 2218 | 41431 | — | server JSON library | fastest | yes | 93 |
| Foundation.JSONEncoder | Foundation | 1321 | 1068 | 2391 | 41431 | — | ships with Swift | slower | yes | 95 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 24.1 | 24.7 | 49.1 | 663 | — | server JSON library | fastest | yes | 92 |
| Foundation.JSONEncoder | Foundation | 27.7 | 25.3 | 52.8 | 663 | — | ships with Swift | slower | yes | 91 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.3 | 1717 | 1577 | 3294 | 65958 | — | server JSON library | fastest | yes | 89 |
| Foundation.JSONEncoder | Foundation | 1836 | 1596 | 3439 | 65958 | — | ships with Swift | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample A (order), N = 100, memory** — not clearly slower: `Foundation.JSONEncoder`. Small gap: —. Time/size front: `Foundation.JSONEncoder`.

**sample D (event), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample D (event), N = 100, memory** — not clearly slower: `Foundation.JSONEncoder`. Small gap: —. Time/size front: `Foundation.JSONEncoder`.

**sample B (flat), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample B (flat), N = 100, memory** — not clearly slower: `Foundation.JSONEncoder`. Small gap: —. Time/size front: `Foundation.JSONEncoder`.

**sample E (words), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample E (words), N = 100, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample C (sensor), N = 1, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

**sample C (sensor), N = 100, memory** — not clearly slower: `IkigaJSON`. Small gap: —. Time/size front: `IkigaJSON`.

