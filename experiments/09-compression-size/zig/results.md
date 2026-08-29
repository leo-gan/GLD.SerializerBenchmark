# Experiment 9 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/09-compression-size/zig/logs/zig/2026-08-28-173411.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.10 | 0.17 | 57 | 74 | packed binary | fastest | yes | 93 |
| protobuf | 5.0.0 | 0.15 | 0.15 | 0.30 | 50 | 76 | Protocol Buffers | slower | yes | 92 |
| flatbuffers | 0.2.1 | 0.23 | 0.11 | 0.33 | 108 | 121 | FlatBuffers | slower | yes | 95 |
| serde.msgpack | 1.0.7 | 0.25 | 0.28 | 0.53 | 124 | 130 | MessagePack | slower | yes | 91 |
| std.json | 0.16.0 | 0.41 | 0.79 | 1.20 | 168 | 141 | JSON — stdlib | slower | yes | 94 |
| capnproto | 1.0.2 | 1.45 | 1.29 | 2.75 | 96 | 92 | Cap’n Proto | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.26 | 0.58 | 0.85 | 436 | 306 | packed binary | fastest | yes | 92 |
| flatbuffers | 0.2.1 | 0.58 | 0.28 | 0.88 | 660 | 430 | FlatBuffers | close | yes | 88 |
| protobuf | 5.0.0 | 0.34 | 0.90 | 1.23 | 368 | 285 | Protocol Buffers | slower | yes | 91 |
| serde.msgpack | 1.0.7 | 0.63 | 0.75 | 1.39 | 346 | 276 | MessagePack | slower | yes | 89 |
| std.json | 0.16.0 | 0.91 | 2.32 | 3.23 | 411 | 287 | JSON — stdlib | slower | yes | 96 |
| capnproto | 1.0.2 | 6.88 | 8.17 | 15.1 | 736 | 427 | Cap’n Proto | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.41 | 0.26 | 0.67 | 1073 | 1088 | packed binary | fastest | yes | 94 |
| flatbuffers | 0.2.1 | 0.41 | 0.29 | 0.71 | 1124 | 1137 | FlatBuffers | close | yes | 91 |
| serde.msgpack | 1.0.7 | 1.34 | 0.85 | 2.19 | 1212 | 1178 | MessagePack | slower | yes | 94 |
| protobuf | 5.0.0 | 1.38 | 1.21 | 2.61 | 1061 | 1085 | Protocol Buffers | slower | yes | 95 |
| capnproto | 1.0.2 | 2.61 | 2.38 | 5.02 | 1120 | 1123 | Cap’n Proto | slower | yes | 87 |
| std.json | 0.16.0 | 4.96 | 7.96 | 12.9 | 2407 | 1323 | JSON — stdlib | slower | yes | 93 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: `flatbuffers`. Time/size front: `comptime-bin`, `protobuf`, `serde.msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: `flatbuffers`. Time/size front: `comptime-bin`, `protobuf`.

