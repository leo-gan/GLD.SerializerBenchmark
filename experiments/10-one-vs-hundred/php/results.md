# Experiment 10 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/php/logs/php/2026-10-11-150714.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.26 | 2.62 | 3.88 | 267 | 2411 | JSON — stdlib | fastest | yes | 96 |
| rybakit-msgpack | v0.9.2 | 5.70 | 7.41 | 13.2 | 209 | 2238 | MessagePack | slower | yes | 78 |
| protobuf | v4.33.6+php | 69.9 | 40.3 | 110 | 133 | 2080 | Protocol Buffers | slower | yes | 83 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 56.1 | 160 | 217 | 25976 | 2411 | JSON — stdlib | fastest | yes | 90 |
| rybakit-msgpack | v0.9.2 | 295 | 474 | 770 | 20078 | 2238 | MessagePack | slower | yes | 85 |
| protobuf | v4.33.6+php | 6084 | 3036 | 9124 | 12717 | 2080 | Protocol Buffers | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.43 | 1.89 | 3.31 | 168 | 2411 | JSON — stdlib | fastest | yes | 98 |
| rybakit-msgpack | v0.9.2 | 3.86 | 5.24 | 9.11 | 126 | 2238 | MessagePack | slower | yes | 87 |
| protobuf | v4.33.6+php | 32.5 | 18.0 | 50.6 | 54 | 2080 | Protocol Buffers | slower | yes | 85 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 69.5 | 88.6 | 158 | 16337 | 2411 | JSON — stdlib | fastest | yes | 92 |
| rybakit-msgpack | v0.9.2 | 144 | 279 | 424 | 11818 | 2238 | MessagePack | slower | yes | 92 |
| protobuf | v4.33.6+php | 2503 | 1153 | 3657 | 4665 | 2080 | Protocol Buffers | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

