# Experiment 9 results — csharp

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/csharp/logs/csharp/2026-11-12-163724.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 5.48 | 3.72 | 9.39 | 57 | 75 | positional binary — no field names | fastest | yes | 95 |
| SpanJson | 4.2.1 | 8.71 | 3.53 | 12.7 | 157 | 140 | JSON — fast writer fast named JSON | slower | yes | 95 |
| Google.Protobuf | 3.36.2 | 8.28 | 6.61 | 15.1 | 50 | 71 | Protocol Buffers — Google library | slower | yes | 96 |
| System.Text.Json | 10.0.0.0 | 17.6 | 10.8 | 28.0 | 157 | 140 | JSON — ships with modern .NET | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 5.70 | 6.99 | 12.9 | 435 | 286 | positional binary — no field names | fastest | yes | 91 |
| Google.Protobuf | 3.36.2 | 7.04 | 8.22 | 15.6 | 367 | 265 | Protocol Buffers — Google library | slower | yes | 88 |
| SpanJson | 4.2.1 | 11.2 | 10.00 | 21.4 | 410 | 273 | JSON — fast writer fast named JSON | slower | yes | 94 |
| System.Text.Json | 10.0.0.0 | 16.1 | 18.8 | 35.1 | 410 | 273 | JSON — ships with modern .NET | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 8.18 | 5.04 | 13.3 | 1073 | 1089 | positional binary — no field names | fastest | yes | 92 |
| Google.Protobuf | 3.36.2 | 11.0 | 8.15 | 19.1 | 1061 | 1076 | Protocol Buffers — Google library | slower | yes | 92 |
| SpanJson | 4.2.1 | 71.1 | 34.1 | 105 | 2407 | 1224 | JSON — fast writer fast named JSON | slower | yes | 89 |
| System.Text.Json | 10.0.0.0 | 71.1 | 47.6 | 117 | 2407 | 1224 | JSON — ships with modern .NET | slower | yes | 87 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| Google.Protobuf | 1 | 3.50 | 3.55 | 6.97 | real |
| Google.Protobuf | 1 | 5.67 | 7.59 | 13.6 | real |
| Google.Protobuf | 1 | 9.17 | 7.52 | 16.8 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `Google.Protobuf`.

