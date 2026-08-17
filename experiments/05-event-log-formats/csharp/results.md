# Experiment 5 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/05-event-log-formats/csharp/logs/csharp/2026-08-17-113737.csv`
**Language:** csharp
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 7.70 | 4.46 | 12.1 | 254 | — | JSON — Experiment 1 | fastest | yes | 83 |
| Google.Protobuf | 3.35.1 | 8.74 | 8.06 | 16.9 | 164 | — | Protocol Buffers | slower | yes | 85 |
| Apache.Avro | 1.12.1 | 18.8 | 18.3 | 37.3 | 140 | — | Avro | slower | yes | 88 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 47.0 | 65.2 | 113 | 25456 | — | JSON — Experiment 1 | fastest | yes | 74 |
| Google.Protobuf | 3.35.1 | 85.8 | 81.5 | 167 | 16636 | — | Protocol Buffers | slower | yes | 77 |
| Apache.Avro | 1.12.1 | 308 | 274 | 577 | 13932 | — | Avro | slower | yes | 74 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 9.32 | 6.38 | 15.9 | text_on_stream |
| Google.Protobuf | 1 | 8.83 | 9.03 | 17.8 | real |
| Apache.Avro | 1 | 22.0 | 19.6 | 41.4 | real |
| Google.Protobuf | 100 | 62.9 | 60.0 | 123 | real |
| SpanJson | 100 | 50.8 | 78.6 | 130 | text_on_stream |
| Apache.Avro | 100 | 295 | 232 | 535 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `Apache.Avro`.

**N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `Apache.Avro`.

