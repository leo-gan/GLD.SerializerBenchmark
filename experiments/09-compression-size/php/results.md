# Experiment 9 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/php/logs/php/2026-10-11-150555.csv`
**Language:** php
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.51 | 1.89 | 3.40 | 168 | 137 | JSON — stdlib | fastest | yes | 98 |
| rybakit-msgpack | v0.9.2 | 3.96 | 5.27 | 9.24 | 126 | 127 | MessagePack | slower | yes | 82 |
| protobuf | v4.33.6+php | 33.0 | 18.1 | 51.2 | 54 | 75 | Protocol Buffers | slower | yes | 82 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.20 | 2.31 | 3.61 | 326 | 227 | JSON — stdlib | fastest | yes | 96 |
| rybakit-msgpack | v0.9.2 | 5.28 | 7.49 | 12.8 | 261 | 215 | MessagePack | slower | yes | 88 |
| protobuf | v4.33.6+php | 63.4 | 53.1 | 117 | 283 | 220 | Protocol Buffers | slower | yes | 93 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| rybakit-msgpack | v0.9.2 | 20.1 | 29.2 | 49.3 | 1203 | 1155 | MessagePack | fastest | yes | 89 |
| json | 8.3.19 | 56.4 | 26.2 | 82.8 | 2406 | 1320 | JSON — stdlib | slower | yes | 85 |
| protobuf | v4.33.6+php | 168 | 104 | 272 | 1052 | 1064 | Protocol Buffers | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `rybakit-msgpack`. Small gap: —. Time/size front: `rybakit-msgpack`, `protobuf`.

