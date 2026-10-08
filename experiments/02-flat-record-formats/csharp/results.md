# Experiment 2 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/02-flat-record-formats/csharp/logs/csharp/2026-09-29-184056.csv`
**Language:** csharp
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Google.Protobuf | 3.36.2 | 5.95 | 5.09 | 11.0 | 68 | 2369 | Protocol Buffers — Google library | fastest | yes | 88 |
| SpanJson | 4.2.1 | 8.19 | 2.98 | 11.3 | 157 | 2454 | JSON — fast writer from Experiment 1 | similar | yes | 86 |
| MessagePack-CSharp | 2.5.305 | 9.14 | 5.49 | 14.8 | 72 | 2241 | MessagePack | slower | yes | 87 |
| ProtoBuf | 2.4.9.1 | 8.71 | 8.34 | 17.1 | 68 | 2369 | Protocol Buffers — protobuf-net | slower | yes | 87 |
| System.Text.Json | 8.0.0.0 | 31.1 | 18.5 | 49.6 | 157 | 2454 | JSON — ships with modern .NET | slower | yes | 84 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MessagePack-CSharp | 2.5.305 | 45.0 | 75.5 | 117 | 6580 | 2241 | MessagePack | fastest | yes | 98 |
| SpanJson | 4.2.1 | 71.5 | 53.0 | 126 | 15456 | 2454 | JSON — fast writer from Experiment 1 | similar | yes | 99 |
| ProtoBuf | 2.4.9.1 | 53.2 | 73.7 | 129 | 6456 | 2369 | Protocol Buffers — protobuf-net | close | yes | 97 |
| Google.Protobuf | 3.36.2 | 77.4 | 66.8 | 151 | 6456 | 2369 | Protocol Buffers — Google library | similar | yes | 99 |
| System.Text.Json | 8.0.0.0 | 161 | 156 | 332 | 15456 | 2454 | JSON — ships with modern .NET | slower | yes | 98 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 5.17 | 4.74 | 9.88 | real |
| SpanJson | 1 | 7.40 | 4.17 | 11.7 | text_on_stream |
| ProtoBuf | 1 | 8.35 | 7.86 | 16.0 | real |
| MessagePack-CSharp | 1 | 15.2 | 6.03 | 21.3 | real |
| System.Text.Json | 1 | 29.1 | 20.9 | 49.9 | text_on_stream |
| Google.Protobuf | 100 | 17.1 | 19.2 | 36.3 | real |
| MessagePack-CSharp | 100 | 24.2 | 20.1 | 45.6 | real |
| ProtoBuf | 100 | 20.9 | 32.8 | 53.6 | real |
| SpanJson | 100 | 41.6 | 39.8 | 81.4 | text_on_stream |
| System.Text.Json | 100 | 55.4 | 73.0 | 129 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `Google.Protobuf`, `SpanJson`. Small gap: —. Time/size front: `Google.Protobuf`.

**N = 100, memory** — not clearly slower: `MessagePack-CSharp`, `SpanJson`, `Google.Protobuf`. Small gap: `ProtoBuf`. Time/size front: `MessagePack-CSharp`, `ProtoBuf`.

