# Experiment 8 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/08-human-files/php/logs/php/2026-10-11-150452.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.90 | 4.71 | 6.67 | 454 | 229 | JSON | fastest | yes | 99 |
| yaml | v7.4.18 | 76.1 | 218 | 294 | 515 | 226 | YAML — Symfony | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.29 | 2.22 | 3.53 | 326 | 229 | JSON | fastest | yes | 96 |
| yaml | v7.4.18 | 59.1 | 144 | 203 | 386 | 226 | YAML — Symfony | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`.

