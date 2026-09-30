# Experiment 5 results — c

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/c/logs/c/2026-09-29-184158.csv`
**Language:** c
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.52 | 0.33 | 0.86 | 131 | 4282 | Protocol Buffers — wire helper | fastest | yes | 91 |
| avro-c | 1.11.3 | 0.83 | 0.70 | 1.53 | 132 | 4091 | Avro | slower | yes | 86 |
| yyjson | 0.10.0 | 2.02 | 1.58 | 3.58 | 265 | 4365 | JSON — Experiment 1 | slower | yes | 94 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 24.5 | 42.8 | 67.3 | 12525 | 4282 | Protocol Buffers — wire helper | fastest | yes | 89 |
| avro-c | 1.11.3 | 27.2 | 51.7 | 79.6 | 12625 | 4091 | Avro | slower | yes | 92 |
| yyjson | 0.10.0 | 103 | 126 | 229 | 25925 | 4365 | JSON — Experiment 1 | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.83 | 0.58 | 1.40 | copied |
| avro-c | 1 | 1.24 | 0.99 | 2.24 | copied |
| yyjson | 1 | 3.23 | 2.36 | 5.56 | real |
| protobuf-wire | 100 | 24.4 | 41.2 | 65.7 | copied |
| avro-c | 100 | 26.8 | 50.4 | 77.6 | copied |
| yyjson | 100 | 149 | 153 | 303 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

**N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: —. Time/size front: `protobuf-wire`.

