# Experiment 5 results — go

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/go/logs/go/2026-08-17-105748.csv`
**Language:** go
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| hamba/avro | 2.31.0 | 1.08 | 1.06 | 2.08 | 107 | — | Avro — binds to structs | fastest | yes | 91 |
| linkedin/goavro | 2.15.0 | 1.30 | 1.95 | 3.28 | 105 | — | Avro — maps | slower | yes | 95 |
| protobuf | 1.36.11 | 1.39 | 1.80 | 3.30 | 123 | — | Protocol Buffers | slower | yes | 96 |
| sonic | 1.15.2 | 1.20 | 2.10 | 3.31 | 257 | — | JSON — fast writer | slower | yes | 90 |
| encoding/json | go1.24.13 | 1.30 | 5.82 | 7.14 | 257 | — | JSON — ships with Go | slower | yes | 93 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| hamba/avro | 2.31.0 | 26.8 | 28.2 | 55.4 | 10626 | — | Avro — binds to structs | fastest | yes | 94 |
| sonic | 1.15.2 | 35.4 | 48.2 | 86.0 | 25746 | — | JSON — fast writer | slower | yes | 90 |
| protobuf | 1.36.11 | 38.2 | 69.4 | 108 | 12477 | — | Protocol Buffers | slower | yes | 79 |
| linkedin/goavro | 2.15.0 | 38.6 | 107 | 145 | 10448 | — | Avro — maps | slower | yes | 90 |
| encoding/json | go1.24.13 | 51.3 | 277 | 328 | 25746 | — | JSON — ships with Go | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| hamba/avro | 1 | 1.26 | 1.50 | 2.86 | real |
| protobuf | 1 | 1.38 | 1.84 | 3.18 | copied |
| linkedin/goavro | 1 | 1.34 | 2.09 | 3.63 | copied |
| sonic | 1 | 1.35 | 2.43 | 3.88 | real |
| encoding/json | 1 | 1.53 | 6.69 | 8.17 | real |
| hamba/avro | 100 | 27.8 | 29.6 | 57.1 | real |
| sonic | 100 | 39.3 | 61.5 | 103 | real |
| protobuf | 100 | 39.4 | 76.5 | 117 | copied |
| linkedin/goavro | 100 | 38.8 | 111 | 150 | copied |
| encoding/json | 100 | 50.1 | 286 | 336 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `hamba/avro`. Small gap: —. Time/size front: `hamba/avro`, `linkedin/goavro`.

**N = 100, memory** — not clearly slower: `hamba/avro`. Small gap: —. Time/size front: `hamba/avro`, `linkedin/goavro`.

