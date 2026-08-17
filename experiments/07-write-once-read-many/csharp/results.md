# Experiment 7 results — csharp

**Date:** 2026-08-17
**Raw file:** `experiments/07-write-once-read-many/csharp/logs/csharp/2026-08-17-110237.csv`
**Language:** csharp
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| ZeroFormatter | 1.6.4 | 7.79 | 5.50 | 13.6 | 288 | — | read-in-place / fewer objects | fastest | yes | 90 |
| MemoryPack | — | 11.0 | 6.88 | 17.9 | 352 | — | fewer new objects | slower | yes | 93 |
| FlatSharp | 7.5.1 | 16.1 | 9.93 | 26.5 | 572 | — | FlatBuffers-like on .NET | slower | yes | 92 |
| ProtoBuf | 2.4.9.1 | 13.0 | 14.0 | 27.2 | 208 | — | Protocol Buffers — protobuf-net | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| MemoryPack | — | 20.0 | 30.3 | 47.8 | 5540 | — | fewer new objects | fastest | yes | 88 |
| FlatSharp | 7.5.1 | 29.1 | 46.0 | 75.3 | 5588 | — | FlatBuffers-like on .NET | slower | yes | 90 |
| ZeroFormatter | 1.6.4 | 32.5 | 47.7 | 81.5 | 5520 | — | read-in-place / fewer objects | slower | yes | 82 |
| ProtoBuf | 2.4.9.1 | 35.9 | 57.4 | 88.3 | 6184 | — | Protocol Buffers — protobuf-net | slower | yes | 93 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| ZeroFormatter | 1 | 7.37 | 6.20 | 13.8 | real |
| MemoryPack | 1 | 11.3 | 8.70 | 20.2 | real |
| FlatSharp | 1 | 15.8 | 11.3 | 27.2 | real |
| ProtoBuf | 1 | 13.3 | 14.3 | 27.6 | real |
| MemoryPack | 1 | 13.6 | 7.33 | 21.3 | real |
| ProtoBuf | 1 | 14.7 | 16.2 | 30.9 | real |
| FlatSharp | 1 | 19.9 | 18.4 | 37.8 | real |
| ZeroFormatter | 1 | 27.5 | 25.1 | 52.6 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `ZeroFormatter`. Small gap: —. Time/size front: `ZeroFormatter`, `ProtoBuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `MemoryPack`. Small gap: —. Time/size front: `MemoryPack`, `ZeroFormatter`.

