# Experiment 2 results — csharp

**Date:** 2026-08-16
**Raw file:** `experiments/02-flat-record-formats/csharp/logs/csharp/2026-08-16-154218.csv`
**Language:** csharp
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 4.96 | 2.48 | 7.50 | 157 | — | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| Google.Protobuf | 3.35.1 | 4.81 | 3.98 | 8.77 | 68 | — | Protocol Buffers — Google library | slower | yes | 89 |
| ProtoBuf | 2.4.9.1 | 7.01 | 7.05 | 14.0 | 68 | — | Protocol Buffers — protobuf-net | slower | yes | 93 |
| System.Text.Json | 8.0.0.0 | 18.8 | 12.7 | 31.6 | 212 | — | JSON — ships with modern .NET | slower | yes | 97 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 72.6 | 52.2 | 128 | 15456 | — | JSON — fast writer from Experiment 1 | fastest | yes | 99 |
| ProtoBuf | 2.4.9.1 | 60.2 | 80.2 | 141 | 6456 | — | Protocol Buffers — protobuf-net | close | yes | 99 |
| Google.Protobuf | 3.35.1 | 84.1 | 67.0 | 151 | 6456 | — | Protocol Buffers — Google library | close | yes | 99 |
| System.Text.Json | 8.0.0.0 | 164 | 216 | 387 | 20608 | — | JSON — ships with modern .NET | slower | yes | 99 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 4.07 | 3.91 | 7.90 | real |
| SpanJson | 1 | 5.21 | 3.55 | 8.81 | text_on_stream |
| ProtoBuf | 1 | 5.59 | 6.02 | 11.7 | real |
| System.Text.Json | 1 | 18.0 | 14.0 | 32.5 | text_on_stream |
| Google.Protobuf | 100 | 15.2 | 17.0 | 32.1 | real |
| ProtoBuf | 100 | 18.7 | 30.3 | 48.9 | real |
| SpanJson | 100 | 37.1 | 36.8 | 73.8 | text_on_stream |
| System.Text.Json | 100 | 51.4 | 67.6 | 119 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`.

**N = 100, memory** — not clearly slower: `SpanJson`. Small gap: `ProtoBuf`, `Google.Protobuf`. Time/size front: `SpanJson`, `ProtoBuf`.

