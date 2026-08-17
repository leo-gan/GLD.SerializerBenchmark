# Experiment 5 results — javascript

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/javascript/logs/javascript/2026-08-17-113829.csv`
**Language:** javascript
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 2.98 | 2.99 | 5.89 | 257 | — | JSON | fastest | yes | 93 |
| avsc | 5.7.9 | 11.0 | 7.46 | 19.3 | 105 | — | Avro | slower | yes | 86 |
| protobufjs | 7.6.5 | 8.82 | 19.9 | 29.7 | 123 | — | Protocol Buffers | slower | yes | 83 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 72.1 | 155 | 225 | 25746 | — | JSON | fastest | yes | 86 |
| protobufjs | 7.6.5 | 157 | 180 | 336 | 12477 | — | Protocol Buffers | slower | yes | 83 |
| avsc | 5.7.9 | 346 | 260 | 608 | 10448 | — | Avro | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `avsc`.

**N = 100, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `protobufjs`, `avsc`.

