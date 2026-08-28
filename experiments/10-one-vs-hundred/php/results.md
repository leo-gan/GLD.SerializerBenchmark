# Experiment 10 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/10-one-vs-hundred/php/logs/php/2026-08-28-113615.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.18 | 2.51 | 3.67 | 267 | 2411 | JSON — stdlib | fastest | yes | 92 |
| rybakit-msgpack | v0.9.2 | 5.70 | 7.30 | 13.0 | 209 | 2238 | MessagePack | slower | yes | 84 |
| protobuf | v4.33.6+php | 66.3 | 39.0 | 105 | 133 | 2080 | Protocol Buffers | slower | yes | 91 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 55.3 | 162 | 217 | 25976 | 2411 | JSON — stdlib | fastest | yes | 89 |
| rybakit-msgpack | v0.9.2 | 298 | 476 | 776 | 20078 | 2238 | MessagePack | slower | yes | 82 |
| protobuf | v4.33.6+php | 6206 | 3042 | 9265 | 12717 | 2080 | Protocol Buffers | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.27 | 1.57 | 2.87 | 168 | 2411 | JSON — stdlib | fastest | yes | 93 |
| rybakit-msgpack | v0.9.2 | 3.72 | 5.09 | 8.83 | 126 | 2238 | MessagePack | slower | yes | 88 |
| protobuf | v4.33.6+php | 30.8 | 17.5 | 48.3 | 54 | 2080 | Protocol Buffers | slower | yes | 85 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 70.6 | 88.0 | 158 | 16337 | 2411 | JSON — stdlib | fastest | yes | 96 |
| rybakit-msgpack | v0.9.2 | 144 | 275 | 419 | 11818 | 2238 | MessagePack | slower | yes | 87 |
| protobuf | v4.33.6+php | 2483 | 1133 | 3626 | 4665 | 2080 | Protocol Buffers | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

