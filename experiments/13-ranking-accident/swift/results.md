# Experiment 13 results — swift

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/swift/logs/swift/2026-10-11-150916.csv`
**Language:** swift
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 18.0 | 32.4 | 50.5 | 448 | 2603 | server JSON library | fastest | yes | 86 |
| Foundation.JSONEncoder | Foundation | 22.3 | 29.9 | 52.1 | 448 | 2595 | ships with Swift | slower | yes | 92 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 1265 | 1894 | 3160 | 45404 | 2595 | ships with Swift | fastest | yes | 95 |
| IkigaJSON | 2.5.4 | 1143 | 2208 | 3355 | 45404 | 2603 | server JSON library | slower | yes | 94 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 11.4 | 18.4 | 29.9 | 257 | 2603 | server JSON library | fastest | yes | 79 |
| Foundation.JSONEncoder | Foundation | 15.1 | 16.5 | 31.7 | 257 | 2595 | ships with Swift | slower | yes | 74 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 656 | 742 | 1397 | 25746 | 2595 | ships with Swift | fastest | yes | 95 |
| IkigaJSON | 2.5.4 | 570 | 974 | 1543 | 25746 | 2603 | server JSON library | slower | yes | 96 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 7.96 | 12.6 | 20.7 | 168 | 2603 | server JSON library | fastest | yes | 79 |
| Foundation.JSONEncoder | Foundation | 8.89 | 12.8 | 21.7 | 168 | 2595 | ships with Swift | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 274 | 412 | 691 | 16546 | 2595 | ships with Swift | fastest | yes | 96 |
| IkigaJSON | 2.5.4 | 306 | 474 | 782 | 16546 | 2603 | server JSON library | slower | yes | 91 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 13.4 | 18.5 | 31.9 | 411 | 2603 | server JSON library | fastest | yes | 85 |
| Foundation.JSONEncoder | Foundation | 19.7 | 16.2 | 35.8 | 411 | 2595 | ships with Swift | slower | yes | 87 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 887 | 1216 | 2107 | 41431 | 2603 | server JSON library | fastest | yes | 90 |
| Foundation.JSONEncoder | Foundation | 1277 | 1021 | 2296 | 41431 | 2595 | ships with Swift | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| IkigaJSON | 2.5.4 | 23.4 | 23.8 | 47.2 | 663 | 2603 | server JSON library | fastest | yes | 79 |
| Foundation.JSONEncoder | Foundation | 25.9 | 24.9 | 51.0 | 663 | 2595 | ships with Swift | slower | yes | 85 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Foundation.JSONEncoder | Foundation | 1765 | 1538 | 3301 | 65958 | 2595 | ships with Swift | fastest | yes | 94 |
| IkigaJSON | 2.5.4 | 1775 | 1532 | 3305 | 65958 | 2603 | server JSON library | similar | yes | 96 |

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

**sample C (sensor), N = 100, memory** — not clearly slower: `Foundation.JSONEncoder`, `IkigaJSON`. Small gap: —. Time/size front: `Foundation.JSONEncoder`.

