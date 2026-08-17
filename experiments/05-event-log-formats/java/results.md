# Experiment 5 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/java/logs/java/2026-08-17-105740.csv`
**Language:** java
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 19.1 | 29.2 | 48.5 | 123 | — | Protocol Buffers | fastest | yes | 95 |
| avro | 1.12.0 | 27.7 | 46.2 | 74.8 | 105 | — | Avro | slower | yes | 95 |
| jackson | 2.18.3 | 33.1 | 40.7 | 77.6 | 254 | — | JSON — common default | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 4.28.3 | 43.3 | 86.4 | 129 | 12477 | — | Protocol Buffers | fastest | yes | 80 |
| jackson | 2.18.3 | 87.5 | 128 | 219 | 25446 | — | JSON — common default | slower | yes | 90 |
| avro | 1.12.0 | 71.4 | 154 | 223 | 10448 | — | Avro | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 8.75 | 16.2 | 25.2 | real |
| avro | 1 | 13.5 | 22.2 | 35.8 | real |
| jackson | 1 | 15.4 | 21.5 | 37.4 | real |
| protobuf | 100 | 33.5 | 60.4 | 95.1 | real |
| avro | 100 | 52.3 | 93.8 | 147 | real |
| jackson | 100 | 54.2 | 102 | 157 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

