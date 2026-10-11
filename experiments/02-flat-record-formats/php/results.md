# Experiment 2 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/php/logs/php/2026-10-11-145903.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.43 | 1.81 | 3.22 | 168 | 2384 | JSON — stdlib | fastest | yes | 97 |
| rybakit-msgpack | v0.9.2 | 3.78 | 5.13 | 8.88 | 126 | 2210 | MessagePack | slower | yes | 89 |
| protobuf | v4.33.6+php | 32.2 | 17.9 | 50.2 | 54 | 2044 | Protocol Buffers | slower | yes | 81 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 68.8 | 87.2 | 157 | 16337 | 2384 | JSON — stdlib | fastest | yes | 88 |
| rybakit-msgpack | v0.9.2 | 143 | 277 | 419 | 11818 | 2210 | MessagePack | slower | yes | 82 |
| protobuf | v4.33.6+php | 2499 | 1134 | 3636 | 4665 | 2044 | Protocol Buffers | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.69 | 2.28 | 3.98 | text_on_stream |
| rybakit-msgpack | 1 | 4.11 | 5.59 | 9.71 | copied |
| protobuf | 1 | 32.8 | 18.6 | 51.5 | copied |
| json | 100 | 70.8 | 89.6 | 160 | text_on_stream |
| rybakit-msgpack | 100 | 146 | 283 | 429 | copied |
| protobuf | 100 | 2541 | 1163 | 3705 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

