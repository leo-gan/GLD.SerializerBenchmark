# Experiment 10 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/csharp/logs/csharp/2026-08-17-110711.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 4.59 | 4.40 | 9.01 | 254 | — | JSON — fast writer from Experiment 1 | fastest | yes | 89 |
| Google.Protobuf | 3.35.1 | 5.64 | 4.26 | 9.98 | 164 | — | Protocol Buffers — Google library | close | yes | 90 |
| ProtoBuf | 2.4.9.1 | 5.37 | 5.79 | 11.2 | 164 | — | Protocol Buffers — protobuf-net | slower | yes | 89 |
| System.Text.Json | 8.0.0.0 | 9.72 | 8.36 | 18.0 | 340 | — | JSON — ships with modern .NET | slower | yes | 92 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 47.0 | 67.6 | 115 | 25456 | — | JSON — fast writer from Experiment 1 | fastest | yes | 85 |
| Google.Protobuf | 3.35.1 | 83.4 | 83.9 | 167 | 16636 | — | Protocol Buffers — Google library | slower | yes | 84 |
| ProtoBuf | 2.4.9.1 | 53.2 | 132 | 187 | 16636 | — | Protocol Buffers — protobuf-net | slower | yes | 86 |
| System.Text.Json | 8.0.0.0 | 104 | 187 | 296 | 33944 | — | JSON — ships with modern .NET | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 10.4 | 3.85 | 14.4 | 157 | — | JSON — fast writer from Experiment 1 | fastest | yes | 92 |
| Google.Protobuf | 3.35.1 | 8.93 | 6.48 | 15.7 | 68 | — | Protocol Buffers — Google library | similar | yes | 90 |
| ProtoBuf | 2.4.9.1 | 14.8 | 12.4 | 27.9 | 68 | — | Protocol Buffers — protobuf-net | slower | yes | 94 |
| System.Text.Json | 8.0.0.0 | 45.3 | 26.3 | 70.1 | 212 | — | JSON — ships with modern .NET | slower | yes | 98 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 78.0 | 56.5 | 140 | 15456 | — | JSON — fast writer from Experiment 1 | fastest | yes | 98 |
| ProtoBuf | 2.4.9.1 | 66.2 | 92.9 | 162 | 6456 | — | Protocol Buffers — protobuf-net | close | yes | 97 |
| Google.Protobuf | 3.35.1 | 87.1 | 69.1 | 165 | 6456 | — | Protocol Buffers — Google library | similar | yes | 97 |
| System.Text.Json | 8.0.0.0 | 177 | 263 | 445 | 20608 | — | JSON — ships with modern .NET | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| SpanJson | 1 | 4.69 | 3.79 | 8.55 | text_on_stream |
| Google.Protobuf | 1 | 4.10 | 4.84 | 8.84 | real |
| ProtoBuf | 1 | 5.10 | 5.71 | 10.8 | real |
| System.Text.Json | 1 | 10.4 | 9.51 | 20.1 | text_on_stream |
| Google.Protobuf | 100 | 59.1 | 61.0 | 120 | real |
| SpanJson | 100 | 48.0 | 75.2 | 123 | text_on_stream |
| ProtoBuf | 100 | 46.8 | 106 | 154 | real |
| System.Text.Json | 100 | 94.5 | 170 | 269 | text_on_stream |
| Google.Protobuf | 1 | 6.06 | 5.18 | 11.3 | real |
| SpanJson | 1 | 8.74 | 5.23 | 14.1 | text_on_stream |
| ProtoBuf | 1 | 8.66 | 7.93 | 16.4 | real |
| System.Text.Json | 1 | 31.2 | 22.0 | 53.1 | text_on_stream |
| Google.Protobuf | 100 | 16.7 | 18.9 | 35.6 | real |
| ProtoBuf | 100 | 20.9 | 33.3 | 54.5 | real |
| SpanJson | 100 | 43.1 | 41.3 | 85.1 | text_on_stream |
| System.Text.Json | 100 | 57.8 | 78.9 | 137 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: `Google.Protobuf`. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`, `Google.Protobuf`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `SpanJson`, `Google.Protobuf`. Small gap: `ProtoBuf`. Time/size front: `SpanJson`, `ProtoBuf`.

