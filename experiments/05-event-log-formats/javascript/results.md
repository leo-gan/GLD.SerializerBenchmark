# Experiment 5 results — javascript

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/javascript/logs/javascript/2026-09-29-184339.csv`
**Language:** javascript
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| JSON.stringify | node-24.15.0 | 3.39 | 4.36 | 7.61 | 257 | 4208 | JSON | fastest | yes | 91 |
| avsc | 5.7.9 | 6.32 | 5.29 | 12.4 | 105 | 3645 | Avro | slower | yes | 88 |
| protobufjs | 7.6.6 | 11.4 | 10.2 | 22.0 | 123 | 4277 | Protocol Buffers | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| avsc | 5.7.9 | 98.4 | 73.8 | 174 | 10448 | 3645 | Avro | fastest | yes | 82 |
| protobufjs | 7.6.6 | 160 | 91.8 | 259 | 12477 | 4277 | Protocol Buffers | slower | yes | 87 |
| JSON.stringify | node-24.15.0 | 74.9 | 185 | 262 | 25746 | 4208 | JSON | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `JSON.stringify`. Small gap: —. Time/size front: `JSON.stringify`, `avsc`.

**N = 100, memory** — not clearly slower: `avsc`. Small gap: —. Time/size front: `avsc`.

