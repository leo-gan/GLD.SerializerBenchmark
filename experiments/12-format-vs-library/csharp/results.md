# Experiment 12 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/12-format-vs-library/csharp/logs/csharp/2026-08-17-103204.csv`
**Language:** csharp
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MS Bond Fast | .NET 8.0.28 | 6.49 | 3.73 | 10.3 | 376 | — | Bond — Fast Binary | fastest | yes | 91 |
| MS Bond Compact | .NET 8.0.28 | 7.82 | 3.99 | 11.8 | 208 | — | Bond — Compact Binary | slower | yes | 90 |
| Google.Protobuf | 3.35.1 | 10.9 | 10.1 | 20.9 | 208 | — | Protocol Buffers — Google library | slower | yes | 91 |
| ProtoBuf | 2.4.9.1 | 11.7 | 13.9 | 25.8 | 208 | — | Protocol Buffers — protobuf-net | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| MS Bond Fast | 1 | 9.37 | 7.12 | 16.6 | real |
| MS Bond Compact | 1 | 10.6 | 7.65 | 18.4 | real |
| Google.Protobuf | 1 | 8.87 | 10.1 | 18.5 | real |
| ProtoBuf | 1 | 11.0 | 12.8 | 24.3 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `MS Bond Fast`. Small gap: —. Time/size front: `MS Bond Fast`, `MS Bond Compact`.

