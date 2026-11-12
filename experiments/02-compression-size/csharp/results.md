# Experiment 9 results — csharp

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/csharp/logs/csharp/2026-11-12-100923.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 5.56 | 3.99 | 9.50 | 57 | 75 | positional binary — no field names | fastest | yes | 91 |
| Google.Protobuf | 3.36.2 | 7.27 | 5.11 | 12.5 | 50 | 71 | Protocol Buffers — Google library | slower | yes | 91 |
| SpanJson | 4.2.1 | 8.74 | 3.72 | 12.8 | 157 | 140 | JSON — fast writer fast named JSON | slower | yes | 93 |
| System.Text.Json | 10.0.0.0 | 22.0 | 13.1 | 35.3 | 157 | 140 | JSON — ships with modern .NET | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 7.25 | 8.04 | 15.6 | 435 | 286 | positional binary — no field names | fastest | yes | 93 |
| Google.Protobuf | 3.36.2 | 8.87 | 10.2 | 19.2 | 367 | 265 | Protocol Buffers — Google library | slower | yes | 89 |
| SpanJson | 4.2.1 | 12.6 | 11.0 | 24.3 | 410 | 273 | JSON — fast writer fast named JSON | slower | yes | 94 |
| System.Text.Json | 10.0.0.0 | 30.3 | 25.5 | 55.7 | 410 | 273 | JSON — ships with modern .NET | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 6.99 | 4.37 | 11.4 | 1073 | 1089 | positional binary — no field names | fastest | yes | 87 |
| Google.Protobuf | 3.36.2 | 10.4 | 8.25 | 18.6 | 1061 | 1076 | Protocol Buffers — Google library | slower | yes | 87 |
| SpanJson | 4.2.1 | 68.1 | 33.7 | 101 | 2407 | 1224 | JSON — fast writer fast named JSON | slower | yes | 92 |
| System.Text.Json | 10.0.0.0 | 67.6 | 47.3 | 115 | 2407 | 1224 | JSON — ships with modern .NET | slower | yes | 90 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 3.16 | 3.53 | 6.62 | real |
| Google.Protobuf | 1 | 5.74 | 9.14 | 14.9 | real |
| Google.Protobuf | 1 | 9.32 | 8.26 | 17.7 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

