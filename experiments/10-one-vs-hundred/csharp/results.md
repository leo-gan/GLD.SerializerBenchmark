# Experiment 10 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/10-one-vs-hundred/csharp/logs/csharp/2026-09-29-184535.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 5.08 | 3.57 | 8.82 | 254 | 2482 | JSON — fast writer from Experiment 1 | fastest | yes | 85 |
| Google.Protobuf | 3.36.2 | 5.63 | 5.74 | 11.4 | 164 | 2404 | Protocol Buffers — Google library | slower | yes | 81 |
| MessagePack-CSharp | 2.5.305 | 8.11 | 4.63 | 12.8 | 156 | 2274 | MessagePack | slower | yes | 84 |
| ProtoBuf | 2.4.9.1 | 6.36 | 6.49 | 12.9 | 164 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 81 |
| System.Text.Json | 8.0.0.0 | 11.8 | 9.47 | 21.3 | 254 | 2482 | JSON — ships with modern .NET | slower | yes | 75 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 51.8 | 66.6 | 119 | 25456 | 2482 | JSON — fast writer from Experiment 1 | fastest | yes | 84 |
| MessagePack-CSharp | 2.5.305 | 54.5 | 90.5 | 147 | 15536 | 2274 | MessagePack | slower | yes | 83 |
| Google.Protobuf | 3.36.2 | 93.8 | 87.2 | 181 | 16636 | 2404 | Protocol Buffers — Google library | slower | yes | 87 |
| ProtoBuf | 2.4.9.1 | 58.9 | 139 | 200 | 16636 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 86 |
| System.Text.Json | 8.0.0.0 | 102 | 150 | 252 | 25456 | 2482 | JSON — ships with modern .NET | slower | yes | 84 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Google.Protobuf | 3.36.2 | 6.01 | 5.50 | 11.6 | 68 | 2404 | Protocol Buffers — Google library | fastest | yes | 91 |
| SpanJson | 4.2.1 | 9.38 | 3.46 | 13.2 | 157 | 2482 | JSON — fast writer from Experiment 1 | similar | yes | 92 |
| MessagePack-CSharp | 2.5.305 | 12.2 | 6.73 | 18.5 | 72 | 2274 | MessagePack | slower | yes | 93 |
| ProtoBuf | 2.4.9.1 | 11.6 | 9.98 | 21.7 | 68 | 2404 | Protocol Buffers — protobuf-net | slower | yes | 93 |
| System.Text.Json | 8.0.0.0 | 37.2 | 21.2 | 58.9 | 157 | 2482 | JSON — ships with modern .NET | slower | yes | 96 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MessagePack-CSharp | 2.5.305 | 41.7 | 52.9 | 92.3 | 6580 | 2274 | MessagePack | fastest | yes | 96 |
| SpanJson | 4.2.1 | 56.5 | 51.1 | 114 | 15456 | 2482 | JSON — fast writer from Experiment 1 | similar | yes | 97 |
| ProtoBuf | 2.4.9.1 | 58.3 | 73.2 | 132 | 6456 | 2404 | Protocol Buffers — protobuf-net | close | yes | 98 |
| Google.Protobuf | 3.36.2 | 74.8 | 61.0 | 137 | 6456 | 2404 | Protocol Buffers — Google library | similar | yes | 99 |
| System.Text.Json | 8.0.0.0 | 97.8 | 126 | 212 | 15456 | 2482 | JSON — ships with modern .NET | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 5.78 | 4.43 | 10.3 | text_on_stream |
| Google.Protobuf | 1 | 4.96 | 6.18 | 11.2 | real |
| ProtoBuf | 1 | 5.99 | 6.42 | 12.4 | real |
| MessagePack-CSharp | 1 | 10.5 | 5.02 | 15.5 | real |
| System.Text.Json | 1 | 12.8 | 11.3 | 24.3 | text_on_stream |
| MessagePack-CSharp | 100 | 50.0 | 68.3 | 119 | real |
| Google.Protobuf | 100 | 65.5 | 62.1 | 129 | real |
| SpanJson | 100 | 51.8 | 77.7 | 131 | text_on_stream |
| ProtoBuf | 100 | 49.4 | 108 | 158 | real |
| System.Text.Json | 100 | 104 | 169 | 275 | text_on_stream |
| Google.Protobuf | 1 | 5.83 | 5.31 | 11.0 | real |
| SpanJson | 1 | 8.15 | 4.88 | 13.0 | text_on_stream |
| ProtoBuf | 1 | 9.48 | 8.39 | 18.3 | real |
| MessagePack-CSharp | 1 | 17.0 | 6.73 | 23.6 | real |
| System.Text.Json | 1 | 32.3 | 22.4 | 56.1 | text_on_stream |
| Google.Protobuf | 100 | 17.8 | 19.8 | 37.6 | real |
| MessagePack-CSharp | 100 | 24.2 | 21.4 | 46.1 | real |
| ProtoBuf | 100 | 21.4 | 34.7 | 56.1 | real |
| SpanJson | 100 | 44.9 | 41.5 | 86.3 | text_on_stream |
| System.Text.Json | 100 | 62.7 | 75.6 | 137 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`, `MessagePack-CSharp`.

**sample D (event), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `MessagePack-CSharp`.

**sample B (flat), N = 1, memory** — not clearly slower: `Google.Protobuf`, `SpanJson`. Small gap: —. Time/size front: `Google.Protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `MessagePack-CSharp`, `SpanJson`, `Google.Protobuf`. Small gap: `ProtoBuf`. Time/size front: `MessagePack-CSharp`, `ProtoBuf`.

