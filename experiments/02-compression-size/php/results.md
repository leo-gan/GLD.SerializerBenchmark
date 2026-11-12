# Experiment 9 results — php

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/php/logs/php/2026-11-12-163818.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.50 | 1.91 | 3.44 | 168 | 137 | JSON — stdlib | fastest | yes | 97 |
| rybakit-msgpack | v0.9.2 | 4.14 | 5.51 | 9.60 | 126 | 127 | MessagePack | slower | yes | 87 |
| protobuf | v4.33.6+php | 34.4 | 19.2 | 53.6 | 54 | 75 | Protocol Buffers | slower | yes | 78 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.35 | 2.49 | 3.87 | 326 | 227 | JSON — stdlib | fastest | yes | 94 |
| rybakit-msgpack | v0.9.2 | 5.86 | 8.18 | 14.0 | 261 | 215 | MessagePack | slower | yes | 86 |
| protobuf | v4.33.6+php | 68.8 | 57.9 | 126 | 283 | 220 | Protocol Buffers | slower | yes | 86 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 22.2 | 32.3 | 54.9 | 1203 | 1155 | MessagePack | fastest | yes | 92 |
| json | 8.3.19 | 61.2 | 28.1 | 89.2 | 2406 | 1320 | JSON — stdlib | slower | yes | 91 |
| protobuf | v4.33.6+php | 184 | 114 | 299 | 1052 | 1064 | Protocol Buffers | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

