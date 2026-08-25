# Experiment 5 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/c/logs/c/2026-08-17-113831.csv`
**Language:** c
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.39 | 0.24 | 0.62 | 131 | — | Protocol Buffers — wire helper | fastest | yes | 97 |
| avro-c | 1.11.3 | 0.59 | 0.53 | 1.12 | 132 | — | Avro | slower | yes | 93 |
| yyjson | 0.10.0 | 1.36 | 1.00 | 2.36 | 265 | — | JSON — Experiment 1 | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 23.3 | 40.9 | 64.2 | 12525 | — | Protocol Buffers — wire helper | fastest | yes | 90 |
| avro-c | 1.11.3 | 25.0 | 50.4 | 75.3 | 12625 | — | Avro | slower | yes | 85 |
| yyjson | 0.10.0 | 101 | 121 | 223 | 25925 | — | JSON — Experiment 1 | slower | yes | 83 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.59 | 0.42 | 1.01 | copied |
| avro-c | 1 | 0.80 | 0.70 | 1.51 | copied |
| yyjson | 1 | 1.57 | 1.16 | 2.73 | copied |
| protobuf-wire | 100 | 24.9 | 43.3 | 68.3 | copied |
| avro-c | 100 | 26.7 | 52.9 | 79.4 | copied |
| yyjson | 100 | 104 | 128 | 233 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

