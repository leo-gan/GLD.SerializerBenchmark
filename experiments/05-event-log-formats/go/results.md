# Experiment 5 results — go

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/go/logs/go/2026-09-29-184344.csv`
**Language:** go
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| hamba/avro | 2.31.0 | 0.99 | 0.89 | 1.91 | 107 | 3766 | Avro — binds to structs | fastest | yes | 90 |
| protobuf | 1.36.12 | 1.02 | 1.49 | 2.52 | 123 | 4302 | Protocol Buffers | slower | yes | 90 |
| linkedin/goavro | 2.15.0 | 0.94 | 1.65 | 2.59 | 105 | 3654 | Avro — maps | slower | yes | 87 |
| sonic | 1.15.4 | 0.90 | 1.84 | 2.81 | 257 | 4198 | JSON — fast writer | slower | yes | 89 |
| encoding/json | go1.24.13 | 1.21 | 5.08 | 6.28 | 257 | 4198 | JSON — ships with Go | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| hamba/avro | 2.31.0 | 30.6 | 30.7 | 62.8 | 10626 | 3766 | Avro — binds to structs | fastest | yes | 94 |
| sonic | 1.15.4 | 44.3 | 52.5 | 99.4 | 25746 | 4198 | JSON — fast writer | slower | yes | 89 |
| protobuf | 1.36.12 | 45.6 | 78.6 | 125 | 12477 | 4302 | Protocol Buffers | slower | yes | 89 |
| linkedin/goavro | 2.15.0 | 50.8 | 116 | 170 | 10448 | 3654 | Avro — maps | slower | yes | 90 |
| encoding/json | go1.24.13 | 58.4 | 292 | 356 | 25746 | 4198 | JSON — ships with Go | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| hamba/avro | 1 | 1.28 | 1.29 | 2.63 | real |
| linkedin/goavro | 1 | 1.15 | 2.01 | 3.14 | copied |
| protobuf | 1 | 1.36 | 1.85 | 3.28 | copied |
| sonic | 1 | 1.25 | 2.53 | 3.80 | real |
| encoding/json | 1 | 1.47 | 6.25 | 7.92 | real |
| hamba/avro | 100 | 31.4 | 30.9 | 62.2 | real |
| sonic | 100 | 44.4 | 65.5 | 110 | real |
| protobuf | 100 | 42.9 | 82.3 | 130 | copied |
| linkedin/goavro | 100 | 53.5 | 119 | 175 | copied |
| encoding/json | 100 | 54.7 | 298 | 352 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `hamba/avro`. Small gap: —. Time/size front: `hamba/avro`, `linkedin/goavro`.

**N = 100, memory** — not clearly slower: `hamba/avro`. Small gap: —. Time/size front: `hamba/avro`, `linkedin/goavro`.

