# Experiment 5 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/05-event-log-formats/kotlin/logs/kotlin/2026-08-27-181729.csv`
**Language:** kotlin
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 27.8 | 19.0 | 47.6 | 123 | 4317 | Protocol Buffers | fastest | yes | 90 |
| avro | 1.12.0 | 50.3 | 64.4 | 120 | 105 | 3708 | Avro | slower | yes | 93 |
| avro4k | 2.9.0 | 78.7 | 50.9 | 133 | 105 | 3708 | Avro — avro4k | slower | yes | 91 |
| jackson | 2.18.3 | 50.7 | 87.2 | 140 | 254 | 4264 | JSON — common default | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 122 | 103 | 226 | 12477 | 4317 | Protocol Buffers | fastest | yes | 95 |
| avro4k | 2.9.0 | 119 | 113 | 235 | 10448 | 3708 | Avro — avro4k | close | yes | 90 |
| avro | 1.12.0 | 101 | 172 | 276 | 10448 | 3708 | Avro | close | yes | 84 |
| jackson | 2.18.3 | 103 | 232 | 363 | 25446 | 4264 | JSON — common default | slower | yes | 84 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 18.3 | 15.7 | 34.2 | real |
| avro | 1 | 28.1 | 41.1 | 70.2 | real |
| avro4k | 1 | 47.9 | 31.5 | 79.2 | copied |
| jackson | 1 | 28.4 | 51.1 | 79.4 | real |
| protobuf | 100 | 86.2 | 74.0 | 162 | real |
| avro4k | 100 | 82.6 | 92.2 | 178 | copied |
| avro | 100 | 82.3 | 117 | 199 | real |
| jackson | 100 | 73.8 | 212 | 287 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: `avro4k`, `avro`. Time/size front: `protobuf`, `avro4k`.

