# Experiment 10 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/zig/logs/zig/2026-10-11-150710.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.11 | 0.28 | 0.39 | 142 | 2140 | packed binary | fastest | yes | 96 |
| serde.msgpack | 1.2.2 | 0.28 | 0.47 | 0.74 | 199 | 2369 | MessagePack | slower | yes | 97 |
| flatbuffers | 0.2.1 | 0.54 | 0.28 | 0.83 | 296 | 2576 | FlatBuffers | slower | yes | 93 |
| protobuf | 5.0.0 | 0.37 | 0.46 | 0.83 | 123 | 2164 | Protocol Buffers | slower | yes | 92 |
| std.json | 0.16.0 | 0.52 | 1.25 | 1.76 | 257 | 2648 | JSON — stdlib | slower | yes | 93 |
| capnproto | 1.0.2 | 4.97 | 4.81 | 9.81 | 256 | 2402 | Cap’n Proto | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 6.18 | 16.3 | 22.5 | 14549 | 2140 | packed binary | fastest | yes | 87 |
| flatbuffers | 0.2.1 | 23.6 | 15.1 | 38.8 | 31124 | 2576 | FlatBuffers | slower | yes | 84 |
| serde.msgpack | 1.2.2 | 13.6 | 28.3 | 42.0 | 20249 | 2369 | MessagePack | slower | yes | 82 |
| protobuf | 5.0.0 | 22.2 | 28.8 | 51.2 | 12649 | 2164 | Protocol Buffers | slower | yes | 82 |
| std.json | 0.16.0 | 45.7 | 98.8 | 145 | 26049 | 2648 | JSON — stdlib | slower | yes | 83 |
| capnproto | 1.0.2 | 308 | 348 | 659 | 26820 | 2402 | Cap’n Proto | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.08 | 0.10 | 0.18 | 57 | 2140 | packed binary | fastest | yes | 97 |
| protobuf | 5.0.0 | 0.20 | 0.20 | 0.39 | 50 | 2164 | Protocol Buffers | slower | yes | 97 |
| flatbuffers | 0.2.1 | 0.26 | 0.15 | 0.40 | 108 | 2576 | FlatBuffers | slower | yes | 96 |
| serde.msgpack | 1.2.2 | 0.20 | 0.31 | 0.51 | 124 | 2369 | MessagePack | slower | yes | 97 |
| std.json | 0.16.0 | 0.35 | 0.73 | 1.08 | 168 | 2648 | JSON — stdlib | slower | yes | 96 |
| capnproto | 1.0.2 | 2.40 | 1.90 | 4.29 | 96 | 2402 | Cap’n Proto | slower | yes | 97 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 2.12 | 3.96 | 6.11 | 5758 | 2140 | packed binary | fastest | yes | 93 |
| flatbuffers | 0.2.1 | 10.3 | 6.21 | 16.5 | 10644 | 2576 | FlatBuffers | slower | yes | 92 |
| protobuf | 5.0.0 | 7.87 | 8.86 | 16.8 | 5045 | 2164 | Protocol Buffers | slower | yes | 92 |
| serde.msgpack | 1.2.2 | 9.35 | 14.0 | 23.6 | 12432 | 2369 | MessagePack | slower | yes | 91 |
| std.json | 0.16.0 | 23.8 | 52.6 | 76.3 | 16849 | 2648 | JSON — stdlib | slower | yes | 85 |
| capnproto | 1.0.2 | 115 | 96.7 | 213 | 9572 | 2402 | Cap’n Proto | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

