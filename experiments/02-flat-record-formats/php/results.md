# Experiment 2 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/02-flat-record-formats/php/logs/php/2026-08-28-113547.csv`
**Language:** php
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.28 | 1.54 | 2.83 | 168 | 2384 | JSON — stdlib | fastest | yes | 94 |
| rybakit-msgpack | v0.9.2 | 3.55 | 4.88 | 8.49 | 126 | 2210 | MessagePack | slower | yes | 91 |
| protobuf | v4.33.6+php | 30.1 | 16.9 | 47.0 | 54 | 2044 | Protocol Buffers | slower | yes | 88 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 69.8 | 86.4 | 157 | 16337 | 2384 | JSON — stdlib | fastest | yes | 87 |
| rybakit-msgpack | v0.9.2 | 142 | 273 | 417 | 11818 | 2210 | MessagePack | slower | yes | 83 |
| protobuf | v4.33.6+php | 2485 | 1140 | 3623 | 4665 | 2044 | Protocol Buffers | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.50 | 1.93 | 3.44 | text_on_stream |
| rybakit-msgpack | 1 | 3.86 | 5.31 | 9.14 | copied |
| protobuf | 1 | 30.2 | 17.2 | 47.4 | copied |
| json | 100 | 71.4 | 89.1 | 161 | text_on_stream |
| rybakit-msgpack | 100 | 143 | 275 | 419 | copied |
| protobuf | 100 | 2488 | 1134 | 3632 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `rybakit-msgpack`, `protobuf`.

