# Experiment 12 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/12-format-vs-library/csharp/logs/csharp/2026-09-29-184739.csv`
**Language:** csharp
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MS Bond Fast | .NET 8.0.28 | 8.09 | 4.56 | 12.9 | 376 | 243 | Bond — Fast Binary | fastest | yes | 91 |
| MS Bond Compact | .NET 8.0.28 | 9.10 | 4.90 | 14.0 | 208 | 199 | Bond — Compact Binary | close | yes | 93 |
| Google.Protobuf | 3.36.2 | 14.6 | 12.7 | 28.2 | 208 | 202 | Protocol Buffers — Google library | slower | yes | 96 |
| ProtoBuf | 2.4.9.1 | 17.8 | 17.6 | 36.1 | 208 | 202 | Protocol Buffers — protobuf-net | slower | yes | 95 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| MS Bond Fast | 1 | 11.2 | 8.93 | 20.2 | real |
| MS Bond Compact | 1 | 12.8 | 9.36 | 22.5 | real |
| Google.Protobuf | 1 | 12.3 | 12.2 | 25.4 | real |
| ProtoBuf | 1 | 15.9 | 16.7 | 32.5 | real |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `MS Bond Fast`. Small gap: `MS Bond Compact`. Time/size front: `MS Bond Fast`, `MS Bond Compact`.

