# Experiment 8 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/08-human-files/php/logs/php/2026-08-28-113612.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.87 | 4.36 | 6.33 | 454 | 229 | JSON | fastest | yes | 88 |
| yaml | v7.4.17 | 72.1 | 221 | 294 | 515 | 226 | YAML — Symfony | slower | yes | 76 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.13 | 2.14 | 3.26 | 326 | 229 | JSON | fastest | yes | 86 |
| yaml | v7.4.17 | 54.5 | 140 | 194 | 386 | 226 | YAML — Symfony | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

