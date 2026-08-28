# Experiment 9 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/09-compression-size/php/logs/php/2026-08-28-113613.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.24 | 1.55 | 2.78 | 168 | 137 | JSON — stdlib | fastest | yes | 94 |
| rybakit-msgpack | v0.9.2 | 3.75 | 5.05 | 8.80 | 126 | 127 | MessagePack | slower | yes | 89 |
| protobuf | v4.33.6+php | 30.4 | 17.3 | 47.8 | 54 | 75 | Protocol Buffers | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 0.98 | 2.01 | 3.00 | 326 | 227 | JSON — stdlib | fastest | yes | 86 |
| rybakit-msgpack | v0.9.2 | 5.07 | 7.30 | 12.3 | 261 | 215 | MessagePack | slower | yes | 86 |
| protobuf | v4.33.6+php | 61.8 | 52.5 | 115 | 283 | 220 | Protocol Buffers | slower | yes | 85 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 20.5 | 30.1 | 50.7 | 1203 | 1155 | MessagePack | fastest | yes | 86 |
| json | 8.3.19 | 56.8 | 26.4 | 83.2 | 2406 | 1320 | JSON — stdlib | slower | yes | 86 |
| protobuf | v4.33.6+php | 170 | 106 | 277 | 1052 | 1064 | Protocol Buffers | slower | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

