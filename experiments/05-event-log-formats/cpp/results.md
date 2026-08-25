# Experiment 5 results — cpp

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/cpp/logs/cpp/2026-08-17-113834.csv`
**Language:** cpp
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| avro | binary-1.11 | 0.41 | 0.49 | 0.92 | 120 | — | Avro | fastest | yes | 92 |
| protobuf-wire | wire-v2 | 0.89 | 0.56 | 1.43 | 138 | — | Protocol Buffers — wire helper | slower | yes | 93 |
| avro_c | avro-c | 1.60 | 2.10 | 3.74 | 120 | — | Avro — C library from C++ | slower | yes | 92 |
| nlohmann_json | 3.11.3 | 1.64 | 4.01 | 5.64 | 272 | — | JSON | slower | yes | 94 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| avro | binary-1.11 | 19.0 | 25.8 | 44.7 | 10165 | — | Avro | fastest | yes | 88 |
| protobuf-wire | wire-v2 | 67.8 | 43.3 | 112 | 12183 | — | Protocol Buffers — wire helper | slower | yes | 94 |
| avro_c | avro-c | 96.0 | 128 | 227 | 10165 | — | Avro — C library from C++ | slower | yes | 88 |
| nlohmann_json | 3.11.3 | 96.7 | 284 | 386 | 25463 | — | JSON | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| avro | 1 | 0.43 | 0.48 | 0.91 | copied |
| protobuf-wire | 1 | 0.90 | 0.57 | 1.48 | copied |
| avro_c | 1 | 1.62 | 2.09 | 3.73 | copied |
| nlohmann_json | 1 | 2.12 | 4.77 | 6.89 | real |
| avro | 100 | 21.4 | 27.7 | 49.7 | copied |
| protobuf-wire | 100 | 72.1 | 44.8 | 119 | copied |
| avro_c | 100 | 105 | 134 | 240 | copied |
| nlohmann_json | 100 | 146 | 359 | 505 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `avro`. Small gap: —. Time/size front: `avro`.

**N = 100, memory** — not clearly slower: `avro`. Small gap: —. Time/size front: `avro`.

