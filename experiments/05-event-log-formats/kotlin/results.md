# Experiment 5 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/kotlin/logs/kotlin/2026-10-11-150153.csv`
**Language:** kotlin
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 36.1 | 27.0 | 64.1 | 123 | 4317 | Protocol Buffers | fastest | yes | 92 |
| avro | 1.12.1 | 66.3 | 87.0 | 157 | 105 | 3708 | Avro | slower | yes | 90 |
| avro4k | 2.9.0 | 94.9 | 69.1 | 170 | 105 | 3708 | Avro — avro4k | slower | yes | 97 |
| jackson | 2.19.0 | 77.9 | 113 | 195 | 254 | 4264 | JSON — common default | slower | yes | 88 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.35.0 | 106 | 79.4 | 191 | 12477 | 4317 | Protocol Buffers | fastest | yes | 84 |
| avro4k | 2.9.0 | 98.6 | 104 | 204 | 10448 | 3708 | Avro — avro4k | close | yes | 77 |
| avro | 1.12.1 | 88.1 | 133 | 224 | 10448 | 3708 | Avro | slower | yes | 80 |
| jackson | 2.19.0 | 98.1 | 212 | 310 | 25446 | 4264 | JSON — common default | slower | yes | 81 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 20.9 | 16.0 | 37.0 | real |
| avro | 1 | 29.6 | 45.6 | 74.4 | real |
| avro4k | 1 | 46.1 | 31.7 | 78.3 | copied |
| jackson | 1 | 30.6 | 52.6 | 81.4 | real |
| protobuf | 100 | 93.5 | 72.5 | 167 | real |
| avro4k | 100 | 74.6 | 91.9 | 168 | copied |
| avro | 100 | 77.9 | 114 | 193 | real |
| jackson | 100 | 69.3 | 204 | 274 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: `avro4k`. Time/size front: `protobuf`, `avro4k`.

