# Experiment 5 results — php

**Date:** 2026-08-28
**Raw file:** `experiments/05-event-log-formats/php/logs/php/2026-08-28-113559.csv`
**Language:** php
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.17 | 2.36 | 3.48 | 267 | 4363 | JSON — stdlib | fastest | yes | 89 |
| avro | 5.2.0 | 21.1 | 27.4 | 48.4 | 115 | 3814 | Avro | slower | yes | 83 |
| protobuf | v4.33.6+php | 67.5 | 39.8 | 107 | 133 | 4424 | Protocol Buffers | slower | yes | 83 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 55.3 | 151 | 207 | 25976 | 4363 | JSON — stdlib | fastest | yes | 91 |
| avro | 5.2.0 | 1613 | 2099 | 3713 | 10678 | 3814 | Avro | slower | yes | 88 |
| protobuf | v4.33.6+php | 6296 | 3118 | 9419 | 12717 | 4424 | Protocol Buffers | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.33 | 2.72 | 4.06 | text_on_stream |
| avro | 1 | 21.5 | 27.8 | 49.6 | copied |
| protobuf | 1 | 68.1 | 40.0 | 108 | copied |
| json | 100 | 55.7 | 157 | 214 | text_on_stream |
| avro | 100 | 1623 | 2101 | 3732 | copied |
| protobuf | 100 | 6243 | 3100 | 9341 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `avro`.

**N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `avro`.

