# Experiment 5 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/05-event-log-formats/csharp/logs/csharp/2026-09-29-184203.csv`
**Language:** csharp
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 8.35 | 5.04 | 13.5 | 254 | 4275 | JSON — Experiment 1 | fastest | yes | 90 |
| Google.Protobuf | 3.36.2 | 9.63 | 8.12 | 18.0 | 164 | 5506 | Protocol Buffers | slower | yes | 90 |
| Apache.Avro | 1.12.2 | 20.4 | 19.5 | 40.5 | 140 | 4847 | Avro | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 49.6 | 66.2 | 116 | 25456 | 4275 | JSON — Experiment 1 | fastest | yes | 77 |
| Google.Protobuf | 3.36.2 | 83.1 | 77.5 | 161 | 16636 | 5506 | Protocol Buffers | slower | yes | 73 |
| Apache.Avro | 1.12.2 | 310 | 267 | 577 | 13932 | 4847 | Avro | slower | yes | 76 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 8.80 | 6.08 | 14.7 | text_on_stream |
| Google.Protobuf | 1 | 8.53 | 8.75 | 17.6 | real |
| Apache.Avro | 1 | 19.4 | 18.8 | 38.3 | real |
| Google.Protobuf | 100 | 62.6 | 59.2 | 123 | real |
| SpanJson | 100 | 52.3 | 77.9 | 131 | text_on_stream |
| Apache.Avro | 100 | 295 | 232 | 529 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `Apache.Avro`.

**N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `Apache.Avro`.

