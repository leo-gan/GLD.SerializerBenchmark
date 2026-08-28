# Experiment 7 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/07-write-once-read-many/php/logs/php/2026-08-28-113609.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | v4.33.6+php | 129 | 71.3 | 200 | 160 | 2060 | Protocol Buffers | fastest | yes | 81 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | v4.33.6+php | 595 | 370 | 964 | 4124 | 2060 | Protocol Buffers | fastest | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

