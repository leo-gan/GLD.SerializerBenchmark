# Experiment 5 results — cpp

**Date:** 2026-09-04
**Raw file:** `experiments/05-event-log-formats/cpp/logs/cpp/2026-09-04-111754.csv`
**Language:** cpp
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| avro | binary-1.11 | 1.40 | 1.50 | 2.89 | 120 | 3624 | Avro | fastest | yes | 92 |
| protobuf-wire | wire-v2 | 2.65 | 1.62 | 4.22 | 138 | 4232 | Protocol Buffers — wire helper | slower | yes | 96 |
| avro_c | avro-c | 5.57 | 6.34 | 12.1 | 120 | 3624 | Avro — C library from C++ | slower | yes | 98 |
| nlohmann_json | 3.11.3 | 4.03 | 10.6 | 14.5 | 272 | 4207 | JSON | slower | yes | 95 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| avro | binary-1.11 | 30.4 | 42.3 | 72.9 | 10165 | 3624 | Avro | fastest | yes | 90 |
| protobuf-wire | wire-v2 | 102 | 68.9 | 171 | 12183 | 4232 | Protocol Buffers — wire helper | slower | yes | 90 |
| avro_c | avro-c | 157 | 205 | 365 | 10165 | 3624 | Avro — C library from C++ | slower | yes | 93 |
| nlohmann_json | 3.11.3 | 141 | 485 | 631 | 25463 | 4207 | JSON | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| avro | 1 | 1.37 | 1.44 | 2.80 | copied |
| protobuf-wire | 1 | 2.44 | 1.35 | 3.77 | copied |
| avro_c | 1 | 4.41 | 5.45 | 10.1 | copied |
| nlohmann_json | 1 | 4.24 | 10.5 | 14.8 | real |
| avro | 100 | 30.2 | 40.8 | 70.6 | copied |
| protobuf-wire | 100 | 100 | 68.3 | 169 | copied |
| avro_c | 100 | 159 | 203 | 365 | copied |
| nlohmann_json | 100 | 228 | 479 | 702 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `avro`. Small gap: —. Time/size front: `avro`.

**N = 100, memory** — not clearly slower: `avro`. Small gap: —. Time/size front: `avro`.

