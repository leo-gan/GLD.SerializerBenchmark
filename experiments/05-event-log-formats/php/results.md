# Experiment 5 results — php

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/php/logs/php/2026-10-11-150142.csv`
**Language:** php
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 1.26 | 2.63 | 3.88 | 267 | 4363 | JSON — stdlib | fastest | yes | 97 |
| avro | 5.2.0 | 21.1 | 26.9 | 48.2 | 115 | 3814 | Avro | slower | yes | 92 |
| protobuf | v4.33.6+php | 67.1 | 39.2 | 106 | 133 | 4424 | Protocol Buffers | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| json | 8.3.19 | 54.7 | 158 | 213 | 25976 | 4363 | JSON — stdlib | fastest | yes | 92 |
| avro | 5.2.0 | 1589 | 2039 | 3624 | 10678 | 3814 | Avro | slower | yes | 93 |
| protobuf | v4.33.6+php | 6090 | 3005 | 9090 | 12717 | 4424 | Protocol Buffers | slower | yes | 93 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| json | 1 | 1.54 | 3.21 | 4.76 | text_on_stream |
| avro | 1 | 21.7 | 27.9 | 49.7 | copied |
| protobuf | 1 | 69.7 | 40.7 | 111 | copied |
| json | 100 | 55.7 | 164 | 220 | text_on_stream |
| avro | 100 | 1583 | 2034 | 3617 | copied |
| protobuf | 100 | 6090 | 3005 | 9094 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `avro`.

**N = 100, memory** — not clearly slower: `json`. Small gap: —. Time/size front: `json`, `avro`.

