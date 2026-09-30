# Experiment 7 results — csharp

**Date:** 2026-09-30
**Raw file:** `experiments/07-write-once-read-many/csharp/logs/csharp/2026-09-29-184403.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| ZeroFormatter | 1.6.4 | 7.71 | 4.61 | 12.2 | 288 | 2188 | read-in-place / fewer objects | fastest | yes | 84 |
| MemoryPack | — | 10.7 | 6.86 | 17.5 | 352 | 2210 | fewer new objects | slower | yes | 82 |
| FlatSharp | 7.5.1 | 15.7 | 9.23 | 24.6 | 572 | 2254 | FlatBuffers-like on .NET | slower | yes | 85 |
| ProtoBuf | 2.4.9.1 | 12.6 | 14.2 | 26.7 | 208 | 2210 | Protocol Buffers — protobuf-net | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MemoryPack | — | 17.5 | 28.4 | 45.4 | 5540 | 2210 | fewer new objects | fastest | yes | 91 |
| FlatSharp | 7.5.1 | 26.2 | 40.7 | 65.3 | 5588 | 2254 | FlatBuffers-like on .NET | slower | yes | 92 |
| ZeroFormatter | 1.6.4 | 29.7 | 43.0 | 72.6 | 5520 | 2188 | read-in-place / fewer objects | slower | yes | 94 |
| ProtoBuf | 2.4.9.1 | 38.8 | 55.4 | 91.2 | 6184 | 2210 | Protocol Buffers — protobuf-net | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| ZeroFormatter | 1 | 7.29 | 5.58 | 12.9 | real |
| MemoryPack | 1 | 10.3 | 7.74 | 17.9 | real |
| FlatSharp | 1 | 15.5 | 10.2 | 25.7 | real |
| ProtoBuf | 1 | 12.5 | 13.7 | 26.5 | real |
| ZeroFormatter | 1 | 8.40 | 5.77 | 14.1 | real |
| FlatSharp | 1 | 9.15 | 5.82 | 15.3 | real |
| MemoryPack | 1 | 10.2 | 4.65 | 15.5 | real |
| ProtoBuf | 1 | 10.7 | 10.2 | 20.9 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `ZeroFormatter`. Small gap: —. Time/size front: `ZeroFormatter`, `ProtoBuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `MemoryPack`. Small gap: —. Time/size front: `MemoryPack`, `ZeroFormatter`.

