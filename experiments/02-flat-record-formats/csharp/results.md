# Experiment 2 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/02-flat-record-formats/csharp/logs/csharp/2026-08-17-130341.csv`
**Language:** csharp
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 7.04 | 3.09 | 10.2 | 157 | 2454 | JSON — fast writer from Experiment 1 | fastest | yes | 90 |
| Google.Protobuf | 3.35.1 | 5.64 | 4.96 | 10.6 | 68 | 2369 | Protocol Buffers — Google library | close | yes | 88 |
| MessagePack-CSharp | 2.5.302 | 8.68 | 5.27 | 13.9 | 72 | 2241 | MessagePack | slower | yes | 90 |
| ProtoBuf | 2.4.9.1 | 8.60 | 8.19 | 16.6 | 68 | 2369 | Protocol Buffers — protobuf-net | slower | yes | 89 |
| System.Text.Json | 8.0.0.0 | 29.1 | 18.3 | 47.2 | 212 | 3250 | JSON — ships with modern .NET | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MessagePack-CSharp | 2.5.302 | 41.4 | 69.3 | 110 | 6580 | 2241 | MessagePack | fastest | yes | 97 |
| Google.Protobuf | 3.35.1 | 76.3 | 58.8 | 134 | 6456 | 2369 | Protocol Buffers — Google library | similar | yes | 99 |
| ProtoBuf | 2.4.9.1 | 55.0 | 74.9 | 136 | 6456 | 2369 | Protocol Buffers — protobuf-net | close | yes | 99 |
| SpanJson | 4.2.1 | 70.0 | 72.9 | 149 | 15456 | 2454 | JSON — fast writer from Experiment 1 | close | yes | 98 |
| System.Text.Json | 8.0.0.0 | 161 | 168 | 346 | 20608 | 3250 | JSON — ships with modern .NET | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 4.89 | 4.78 | 9.72 | real |
| SpanJson | 1 | 6.72 | 4.16 | 10.8 | text_on_stream |
| ProtoBuf | 1 | 7.71 | 7.44 | 15.1 | real |
| MessagePack-CSharp | 1 | 14.7 | 5.63 | 20.4 | real |
| System.Text.Json | 1 | 26.9 | 19.4 | 46.5 | text_on_stream |
| Google.Protobuf | 100 | 22.6 | 24.2 | 47.1 | real |
| MessagePack-CSharp | 100 | 31.0 | 25.0 | 57.7 | real |
| ProtoBuf | 100 | 25.7 | 40.4 | 66.7 | real |
| SpanJson | 100 | 53.6 | 49.1 | 104 | text_on_stream |
| System.Text.Json | 100 | 68.0 | 85.8 | 153 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `SpanJson`. Small gap: `Google.Protobuf`. Time/size front: `SpanJson`, `Google.Protobuf`.

**N = 100, memory** — not clearly slower: `MessagePack-CSharp`, `Google.Protobuf`. Small gap: `ProtoBuf`, `SpanJson`. Time/size front: `MessagePack-CSharp`, `Google.Protobuf`.

