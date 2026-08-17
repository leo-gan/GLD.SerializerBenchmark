# Experiment 5 results — python

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/python/logs/python/2026-08-17-105721.csv`
**Language:** python
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.11.9 | 1.10 | 1.62 | 2.78 | 257 | 4266 | JSON — fast writer from Experiment 1 | fastest | yes | 99 |
| protobuf | 7.35.1 | 2.04 | 2.29 | 4.32 | 123 | 4317 | Protocol Buffers | slower | yes | 85 |
| avro | 1.12.2 | 12.1 | 7.28 | 19.3 | 105 | 3706 | Avro | slower | yes | 86 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.35.1 | 27.9 | 35.3 | 63.1 | 12477 | 4317 | Protocol Buffers | fastest | yes | 70 |
| orjson | 3.11.9 | 41.5 | 74.5 | 118 | 25746 | 4266 | JSON — fast writer from Experiment 1 | slower | yes | 91 |
| avro | 1.12.2 | 486 | 337 | 825 | 10445 | 3706 | Avro | slower | yes | 92 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| orjson | 1 | 1.36 | 1.92 | 3.31 | copied |
| protobuf | 1 | 2.27 | 2.42 | 4.71 | copied |
| avro | 1 | 12.2 | 7.50 | 19.6 | copied |
| protobuf | 100 | 29.2 | 35.8 | 64.8 | copied |
| orjson | 100 | 40.1 | 73.8 | 115 | copied |
| avro | 100 | 475 | 336 | 814 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `protobuf`, `avro`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

