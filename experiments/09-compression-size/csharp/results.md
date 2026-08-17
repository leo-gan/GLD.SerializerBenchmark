# Experiment 9 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/09-compression-size/csharp/logs/csharp/2026-08-17-115915.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 6.12 | 2.61 | 8.74 | 157 | 139 | JSON — fast writer from Experiment 1 | fastest | yes | 94 |
| Google.Protobuf | 3.35.1 | 5.85 | 4.68 | 10.6 | 68 | 88 | Protocol Buffers — Google library | slower | yes | 95 |
| System.Text.Json | 8.0.0.0 | 16.0 | 13.2 | 29.3 | 212 | 189 | JSON — ships with modern .NET | slower | yes | 95 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Google.Protobuf | 3.35.1 | 8.94 | 8.27 | 17.4 | 492 | 386 | Protocol Buffers — Google library | fastest | yes | 89 |
| SpanJson | 4.2.1 | 10.1 | 7.61 | 17.4 | 410 | 272 | JSON — fast writer from Experiment 1 | similar | yes | 93 |
| System.Text.Json | 8.0.0.0 | 22.3 | 21.6 | 44.3 | 548 | 389 | JSON — ships with modern .NET | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Google.Protobuf | 3.35.1 | 12.3 | 10.1 | 22.9 | 1416 | 1102 | Protocol Buffers — Google library | fastest | yes | 94 |
| System.Text.Json | 8.0.0.0 | 71.7 | 48.8 | 122 | 3212 | 1778 | JSON — ships with modern .NET | slower | yes | 91 |
| SpanJson | 4.2.1 | 67.6 | 68.9 | 137 | 2407 | 1320 | JSON — fast writer from Experiment 1 | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 3.92 | 3.83 | 7.79 | real |
| SpanJson | 1 | 5.37 | 3.99 | 9.39 | text_on_stream |
| System.Text.Json | 1 | 14.3 | 12.1 | 26.9 | text_on_stream |
| Google.Protobuf | 1 | 6.96 | 10.5 | 17.8 | real |
| SpanJson | 1 | 11.2 | 11.3 | 22.7 | text_on_stream |
| System.Text.Json | 1 | 21.7 | 25.8 | 47.9 | text_on_stream |
| Google.Protobuf | 1 | 9.46 | 8.00 | 17.4 | real |
| SpanJson | 1 | 65.0 | 36.7 | 102 | text_on_stream |
| System.Text.Json | 1 | 68.7 | 49.2 | 117 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `Google.Protobuf`, `SpanJson`. Small gap: —. Time/size front: `Google.Protobuf`, `SpanJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `Google.Protobuf`. Small gap: —. Time/size front: `Google.Protobuf`.

