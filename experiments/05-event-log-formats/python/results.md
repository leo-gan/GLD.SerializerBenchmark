# Experiment 5 results — python

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/python/logs/python/2026-09-29-184258.csv`
**Language:** python
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| orjson | 3.12.0 | 2.01 | 2.54 | 4.47 | 257 | 4266 | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| protobuf | 7.36.1 | 3.27 | 2.95 | 6.23 | 123 | 4317 | Protocol Buffers | slower | yes | 96 |
| avro | 1.12.2 | 15.3 | 9.20 | 24.6 | 105 | 3706 | Avro | slower | yes | 96 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 7.36.1 | 32.0 | 38.7 | 70.5 | 12477 | 4317 | Protocol Buffers | fastest | yes | 89 |
| orjson | 3.12.0 | 47.1 | 80.9 | 128 | 25746 | 4266 | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| avro | 1.12.2 | 511 | 364 | 876 | 10445 | 3706 | Avro | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| orjson | 1 | 2.27 | 2.77 | 5.05 | copied |
| protobuf | 1 | 3.78 | 3.48 | 7.14 | copied |
| avro | 1 | 15.6 | 9.63 | 25.2 | copied |
| protobuf | 100 | 35.5 | 41.4 | 77.3 | copied |
| orjson | 100 | 53.2 | 87.9 | 141 | copied |
| avro | 100 | 531 | 384 | 916 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `orjson`. Small gap: —. Time/size front: `orjson`, `protobuf`, `avro`.

**N = 100, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`, `avro`.

