# Experiment 10 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/csharp/logs/csharp/2026-08-17-130410.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 4.29 | 3.53 | 7.87 | 254 | 2482 | JSON — fast writer from Experiment 1 | fastest | yes | 85 |
| Google.Protobuf | 3.35.1 | 5.20 | 5.40 | 10.8 | 164 | 2404 | Protocol Buffers — Google library | slower | yes | 85 |
| ProtoBuf | 2.4.9.1 | 5.27 | 5.82 | 11.0 | 164 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 89 |
| MessagePack-CSharp | 2.5.302 | 6.96 | 4.48 | 11.4 | 156 | 2274 | MessagePack | slower | yes | 93 |
| System.Text.Json | 8.0.0.0 | 10.4 | 8.74 | 19.3 | 340 | 3292 | JSON — ships with modern .NET | slower | yes | 85 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 45.2 | 65.8 | 112 | 25456 | 2482 | JSON — fast writer from Experiment 1 | fastest | yes | 71 |
| MessagePack-CSharp | 2.5.302 | 51.0 | 87.7 | 140 | 15536 | 2274 | MessagePack | slower | yes | 87 |
| Google.Protobuf | 3.35.1 | 83.3 | 80.0 | 163 | 16636 | 2404 | Protocol Buffers — Google library | slower | yes | 90 |
| ProtoBuf | 2.4.9.1 | 53.0 | 133 | 187 | 16636 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 85 |
| System.Text.Json | 8.0.0.0 | 106 | 186 | 295 | 33944 | 3292 | JSON — ships with modern .NET | slower | yes | 88 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 7.02 | 3.62 | 10.7 | 157 | 2482 | JSON — fast writer from Experiment 1 | fastest | yes | 86 |
| Google.Protobuf | 3.35.1 | 5.74 | 4.99 | 10.8 | 68 | 2404 | Protocol Buffers — Google library | similar | yes | 93 |
| MessagePack-CSharp | 2.5.302 | 8.30 | 5.12 | 13.3 | 72 | 2274 | MessagePack | slower | yes | 82 |
| ProtoBuf | 2.4.9.1 | 8.35 | 7.61 | 16.1 | 68 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 80 |
| System.Text.Json | 8.0.0.0 | 30.3 | 19.4 | 50.1 | 212 | 3292 | JSON — ships with modern .NET | slower | yes | 88 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MessagePack-CSharp | 2.5.302 | 35.8 | 48.2 | 83.8 | 6580 | 2274 | MessagePack | fastest | yes | 98 |
| SpanJson | 4.2.1 | 51.0 | 49.1 | 100 | 15456 | 2482 | JSON — fast writer from Experiment 1 | close | yes | 93 |
| ProtoBuf | 2.4.9.1 | 47.2 | 68.5 | 116 | 6456 | 2404 | Protocol Buffers — protobuf-net | close | yes | 98 |
| Google.Protobuf | 3.35.1 | 72.3 | 55.0 | 127 | 6456 | 2404 | Protocol Buffers — Google library | similar | yes | 98 |
| System.Text.Json | 8.0.0.0 | 131 | 147 | 278 | 20608 | 3292 | JSON — ships with modern .NET | slower | yes | 99 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 5.12 | 4.02 | 9.02 | text_on_stream |
| ProtoBuf | 1 | 4.72 | 5.51 | 10.4 | real |
| Google.Protobuf | 1 | 4.88 | 5.59 | 10.7 | real |
| MessagePack-CSharp | 1 | 8.92 | 4.43 | 13.3 | real |
| System.Text.Json | 1 | 10.6 | 9.65 | 20.4 | text_on_stream |
| MessagePack-CSharp | 100 | 49.3 | 67.7 | 118 | real |
| Google.Protobuf | 100 | 61.8 | 60.3 | 124 | real |
| SpanJson | 100 | 49.2 | 77.8 | 127 | text_on_stream |
| ProtoBuf | 100 | 47.7 | 107 | 157 | real |
| System.Text.Json | 100 | 98.9 | 168 | 267 | text_on_stream |
| Google.Protobuf | 1 | 4.61 | 4.53 | 9.20 | real |
| SpanJson | 1 | 6.69 | 4.20 | 10.8 | text_on_stream |
| ProtoBuf | 1 | 7.66 | 7.24 | 14.9 | real |
| MessagePack-CSharp | 1 | 14.7 | 5.51 | 20.1 | real |
| System.Text.Json | 1 | 26.9 | 20.0 | 47.2 | text_on_stream |
| Google.Protobuf | 100 | 16.6 | 19.0 | 35.6 | real |
| MessagePack-CSharp | 100 | 24.6 | 21.1 | 45.7 | real |
| ProtoBuf | 100 | 19.9 | 32.4 | 52.5 | real |
| SpanJson | 100 | 41.3 | 39.8 | 80.9 | text_on_stream |
| System.Text.Json | 100 | 58.0 | 72.6 | 132 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `MessagePack-CSharp`.

**sample D (event), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `MessagePack-CSharp`.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`, `Google.Protobuf`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `MessagePack-CSharp`, `Google.Protobuf`. Small gap: `SpanJson`, `ProtoBuf`. Time/size front: `MessagePack-CSharp`, `ProtoBuf`.

