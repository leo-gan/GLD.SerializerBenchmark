# Experiment 9 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/09-compression-size/csharp/logs/csharp/2026-09-29-184458.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 11.9 | 3.96 | 16.3 | 157 | 139 | JSON — fast writer from Experiment 1 | fastest | yes | 97 |
| Google.Protobuf | 3.36.2 | 10.6 | 7.82 | 18.5 | 68 | 88 | Protocol Buffers — Google library | close | yes | 93 |
| System.Text.Json | 8.0.0.0 | 32.1 | 19.4 | 51.0 | 157 | 139 | JSON — ships with modern .NET | slower | yes | 99 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| SpanJson | 4.2.1 | 11.8 | 8.44 | 20.4 | 410 | 272 | JSON — fast writer from Experiment 1 | fastest | yes | 89 |
| Google.Protobuf | 3.36.2 | 13.0 | 11.7 | 26.0 | 492 | 386 | Protocol Buffers — Google library | slower | yes | 97 |
| System.Text.Json | 8.0.0.0 | 29.3 | 24.8 | 54.2 | 410 | 272 | JSON — ships with modern .NET | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| Google.Protobuf | 3.36.2 | 18.1 | 18.2 | 34.7 | 1416 | 1102 | Protocol Buffers — Google library | fastest | yes | 94 |
| System.Text.Json | 8.0.0.0 | 84.2 | 54.9 | 140 | 2407 | 1320 | JSON — ships with modern .NET | slower | yes | 96 |
| SpanJson | 4.2.1 | 79.4 | 75.7 | 158 | 2407 | 1320 | JSON — fast writer from Experiment 1 | slower | yes | 92 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 5.43 | 5.30 | 10.6 | real |
| SpanJson | 1 | 7.77 | 4.90 | 12.8 | text_on_stream |
| System.Text.Json | 1 | 17.9 | 14.6 | 32.6 | text_on_stream |
| Google.Protobuf | 1 | 11.6 | 18.0 | 29.4 | real |
| SpanJson | 1 | 15.8 | 14.1 | 30.6 | text_on_stream |
| System.Text.Json | 1 | 37.1 | 37.9 | 73.3 | text_on_stream |
| Google.Protobuf | 1 | 11.2 | 8.58 | 20.3 | real |
| SpanJson | 1 | 49.0 | 55.0 | 105 | text_on_stream |
| System.Text.Json | 1 | 63.0 | 73.2 | 125 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: `Google.Protobuf`. Time/size front: `SpanJson`, `Google.Protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `SpanJson`. Small gap: —. Time/size front: `SpanJson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `Google.Protobuf`. Small gap: —. Time/size front: `Google.Protobuf`.

