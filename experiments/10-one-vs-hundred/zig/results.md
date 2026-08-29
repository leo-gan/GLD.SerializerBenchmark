# Experiment 10 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/10-one-vs-hundred/zig/logs/zig/2026-08-28-173413.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.12 | 0.23 | 0.36 | 142 | 2140 | packed binary | fastest | yes | 79 |
| protobuf | 5.0.0 | 0.31 | 0.39 | 0.71 | 123 | 2164 | Protocol Buffers | slower | yes | 83 |
| flatbuffers | 0.2.1 | 0.51 | 0.23 | 0.73 | 296 | 2576 | FlatBuffers | slower | yes | 76 |
| serde.msgpack | 1.0.7 | 0.57 | 0.37 | 0.94 | 199 | 2369 | MessagePack | slower | yes | 83 |
| std.json | 0.16.0 | 0.57 | 1.43 | 2.03 | 257 | 2648 | JSON — stdlib | slower | yes | 86 |
| capnproto | 1.0.2 | 3.13 | 3.52 | 6.66 | 256 | 2402 | Cap’n Proto | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 8.39 | 16.5 | 24.8 | 14549 | 2140 | packed binary | fastest | yes | 79 |
| flatbuffers | 0.2.1 | 23.3 | 14.9 | 38.2 | 31124 | 2576 | FlatBuffers | slower | yes | 87 |
| protobuf | 5.0.0 | 22.5 | 28.7 | 51.3 | 12649 | 2164 | Protocol Buffers | slower | yes | 88 |
| serde.msgpack | 1.0.7 | 39.0 | 28.6 | 67.5 | 20249 | 2369 | MessagePack | slower | yes | 89 |
| std.json | 0.16.0 | 55.5 | 128 | 183 | 26049 | 2648 | JSON — stdlib | slower | yes | 81 |
| capnproto | 1.0.2 | 279 | 319 | 601 | 26820 | 2402 | Cap’n Proto | slower | yes | 85 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.10 | 0.17 | 57 | 2140 | packed binary | fastest | yes | 88 |
| protobuf | 5.0.0 | 0.15 | 0.16 | 0.30 | 50 | 2164 | Protocol Buffers | slower | yes | 84 |
| flatbuffers | 0.2.1 | 0.24 | 0.11 | 0.34 | 108 | 2576 | FlatBuffers | slower | yes | 90 |
| serde.msgpack | 1.0.7 | 0.25 | 0.30 | 0.54 | 124 | 2369 | MessagePack | slower | yes | 92 |
| std.json | 0.16.0 | 0.42 | 0.83 | 1.23 | 168 | 2648 | JSON — stdlib | slower | yes | 90 |
| capnproto | 1.0.2 | 1.26 | 1.03 | 2.28 | 96 | 2402 | Cap’n Proto | slower | yes | 89 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 3.04 | 3.93 | 6.99 | 5758 | 2140 | packed binary | fastest | yes | 86 |
| protobuf | 5.0.0 | 6.95 | 8.16 | 15.3 | 5045 | 2164 | Protocol Buffers | slower | yes | 90 |
| flatbuffers | 0.2.1 | 9.73 | 5.95 | 15.7 | 10644 | 2576 | FlatBuffers | slower | yes | 84 |
| serde.msgpack | 1.0.7 | 13.5 | 18.3 | 31.7 | 12432 | 2369 | MessagePack | slower | yes | 88 |
| std.json | 0.16.0 | 32.5 | 61.1 | 93.6 | 16849 | 2648 | JSON — stdlib | slower | yes | 88 |
| capnproto | 1.0.2 | 96.8 | 81.2 | 178 | 9572 | 2402 | Cap’n Proto | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample D (event), N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample B (flat), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample B (flat), N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

