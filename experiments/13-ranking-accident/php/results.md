# Experiment 13 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/13-ranking-accident/php/logs/php/2026-08-28-113624.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.79 | 4.43 | 6.18 | 454 | 2514 | stdlib json_encode / json_decode | fastest | yes | 92 |
| symfony-json | v7.4.17 | 3.10 | 5.03 | 8.26 | 454 | 2514 | Symfony Serializer JSON | slower | yes | 92 |
| jms-json | 3.32.7 | 21.0 | 14.9 | 35.9 | 454 | 2514 | JMS Serializer JSON | slower | yes | 83 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 94.6 | 336 | 430 | 45480 | 2514 | stdlib json_encode / json_decode | fastest | yes | 88 |
| symfony-json | v7.4.17 | 97.4 | 336 | 436 | 45480 | 2514 | Symfony Serializer JSON | similar | yes | 92 |
| jms-json | 3.32.7 | 988 | 348 | 1338 | 45480 | 2514 | JMS Serializer JSON | slower | yes | 95 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.18 | 2.62 | 3.84 | 267 | 2514 | stdlib json_encode / json_decode | fastest | yes | 91 |
| symfony-json | v7.4.17 | 2.36 | 3.36 | 5.76 | 267 | 2514 | Symfony Serializer JSON | slower | yes | 88 |
| jms-json | 3.32.7 | 14.3 | 12.2 | 26.5 | 267 | 2514 | JMS Serializer JSON | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 60.5 | 161 | 221 | 25976 | 2514 | stdlib json_encode / json_decode | fastest | yes | 91 |
| symfony-json | v7.4.17 | 63.6 | 165 | 230 | 25976 | 2514 | Symfony Serializer JSON | close | yes | 88 |
| jms-json | 3.32.7 | 494 | 182 | 678 | 25976 | 2514 | JMS Serializer JSON | slower | yes | 87 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.29 | 1.69 | 3.00 | 168 | 2514 | stdlib json_encode / json_decode | fastest | yes | 93 |
| symfony-json | v7.4.17 | 2.48 | 2.45 | 4.96 | 168 | 2514 | Symfony Serializer JSON | slower | yes | 93 |
| jms-json | 3.32.7 | 12.2 | 11.3 | 23.7 | 168 | 2514 | JMS Serializer JSON | slower | yes | 97 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 71.0 | 91.9 | 164 | 16337 | 2514 | stdlib json_encode / json_decode | fastest | yes | 88 |
| symfony-json | v7.4.17 | 74.0 | 91.8 | 166 | 16337 | 2514 | Symfony Serializer JSON | close | yes | 85 |
| jms-json | 3.32.7 | 270 | 111 | 381 | 16337 | 2514 | JMS Serializer JSON | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.03 | 2.17 | 3.23 | 326 | 2514 | stdlib json_encode / json_decode | fastest | yes | 84 |
| symfony-json | v7.4.17 | 2.10 | 2.88 | 4.93 | 326 | 2514 | Symfony Serializer JSON | slower | yes | 89 |
| jms-json | 3.32.7 | 14.8 | 10.8 | 25.7 | 326 | 2514 | JMS Serializer JSON | slower | yes | 97 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 81.8 | 168 | 251 | 34941 | 2514 | stdlib json_encode / json_decode | fastest | yes | 87 |
| symfony-json | v7.4.17 | 86.3 | 174 | 260 | 34941 | 2514 | Symfony Serializer JSON | slower | yes | 85 |
| jms-json | 3.32.7 | 714 | 193 | 907 | 34941 | 2514 | JMS Serializer JSON | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 15.7 | 8.01 | 23.8 | 654 | 2514 | stdlib json_encode / json_decode | fastest | yes | 94 |
| symfony-json | v7.4.17 | 17.2 | 8.90 | 26.2 | 654 | 2514 | Symfony Serializer JSON | slower | yes | 92 |
| jms-json | 3.32.7 | 34.8 | 18.4 | 53.3 | 654 | 2514 | JMS Serializer JSON | slower | yes | 86 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1416 | 682 | 2098 | 65984 | 2514 | stdlib json_encode / json_decode | fastest | yes | 89 |
| symfony-json | v7.4.17 | 1428 | 674 | 2106 | 65984 | 2514 | Symfony Serializer JSON | similar | yes | 90 |
| jms-json | 3.32.7 | 2299 | 706 | 3012 | 65984 | 2514 | JMS Serializer JSON | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample A (order), N = 100, memory** — not clearly slower: `json`, `symfony-json`. Small gap: —. Time/size front: `json`.

**sample D (event), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample D (event), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample B (flat), N = 100, memory** — not clearly slower: `json`. Small gap: `symfony-json`. Time/size front: `json`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample E (words), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample C (sensor), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample C (sensor), N = 100, memory** — not clearly slower: `json`, `symfony-json`. Small gap: —. Time/size front: `json`.

