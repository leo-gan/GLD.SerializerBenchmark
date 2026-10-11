# Experiment 13 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/php/logs/php/2026-10-11-151051.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.92 | 4.62 | 6.54 | 454 | 2514 | stdlib json_encode / json_decode | fastest | yes | 96 |
| symfony-json | v7.4.18 | 3.20 | 5.24 | 8.54 | 454 | 2514 | Symfony Serializer JSON | slower | yes | 90 |
| jms-json | 3.32.9 | 21.0 | 14.9 | 36.0 | 454 | 2514 | JMS Serializer JSON | slower | yes | 84 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 94.2 | 340 | 436 | 45480 | 2514 | stdlib json_encode / json_decode | fastest | yes | 87 |
| symfony-json | v7.4.18 | 98.6 | 343 | 445 | 45480 | 2514 | Symfony Serializer JSON | close | yes | 88 |
| jms-json | 3.32.9 | 978 | 353 | 1331 | 45480 | 2514 | JMS Serializer JSON | slower | yes | 92 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.36 | 2.78 | 4.10 | 267 | 2514 | stdlib json_encode / json_decode | fastest | yes | 98 |
| symfony-json | v7.4.18 | 2.67 | 3.52 | 6.25 | 267 | 2514 | Symfony Serializer JSON | slower | yes | 94 |
| jms-json | 3.32.9 | 15.7 | 13.0 | 28.8 | 267 | 2514 | JMS Serializer JSON | slower | yes | 77 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 62.9 | 168 | 230 | 25976 | 2514 | stdlib json_encode / json_decode | fastest | yes | 80 |
| symfony-json | v7.4.18 | 66.4 | 169 | 237 | 25976 | 2514 | Symfony Serializer JSON | close | yes | 83 |
| jms-json | 3.32.9 | 504 | 188 | 698 | 25976 | 2514 | JMS Serializer JSON | slower | yes | 90 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.46 | 1.81 | 3.25 | 168 | 2514 | stdlib json_encode / json_decode | fastest | yes | 99 |
| symfony-json | v7.4.18 | 2.72 | 2.51 | 5.23 | 168 | 2514 | Symfony Serializer JSON | slower | yes | 95 |
| jms-json | 3.32.9 | 13.0 | 11.5 | 24.5 | 168 | 2514 | JMS Serializer JSON | slower | yes | 84 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 71.0 | 92.0 | 164 | 16337 | 2514 | stdlib json_encode / json_decode | fastest | yes | 87 |
| symfony-json | v7.4.18 | 75.6 | 94.6 | 172 | 16337 | 2514 | Symfony Serializer JSON | slower | yes | 86 |
| jms-json | 3.32.9 | 278 | 114 | 396 | 16337 | 2514 | JMS Serializer JSON | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.31 | 2.24 | 3.57 | 326 | 2514 | stdlib json_encode / json_decode | fastest | yes | 95 |
| symfony-json | v7.4.18 | 2.56 | 3.04 | 5.55 | 326 | 2514 | Symfony Serializer JSON | slower | yes | 94 |
| jms-json | 3.32.9 | 16.2 | 11.7 | 28.0 | 326 | 2514 | JMS Serializer JSON | slower | yes | 91 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 83.2 | 173 | 258 | 34941 | 2514 | stdlib json_encode / json_decode | fastest | yes | 87 |
| symfony-json | v7.4.18 | 86.4 | 174 | 262 | 34941 | 2514 | Symfony Serializer JSON | close | yes | 88 |
| jms-json | 3.32.9 | 723 | 197 | 920 | 34941 | 2514 | JMS Serializer JSON | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 15.3 | 7.68 | 22.9 | 654 | 2514 | stdlib json_encode / json_decode | fastest | yes | 93 |
| symfony-json | v7.4.18 | 16.6 | 8.64 | 25.4 | 654 | 2514 | Symfony Serializer JSON | slower | yes | 91 |
| jms-json | 3.32.9 | 34.6 | 18.6 | 53.4 | 654 | 2514 | JMS Serializer JSON | slower | yes | 81 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1417 | 688 | 2112 | 65984 | 2514 | stdlib json_encode / json_decode | fastest | yes | 89 |
| symfony-json | v7.4.18 | 1429 | 690 | 2119 | 65984 | 2514 | Symfony Serializer JSON | close | yes | 93 |
| jms-json | 3.32.9 | 2305 | 706 | 3014 | 65984 | 2514 | JMS Serializer JSON | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample A (order), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

**sample D (event), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample D (event), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample B (flat), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample E (words), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

**sample C (sensor), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

