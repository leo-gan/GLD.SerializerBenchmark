# Experiment 9 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/zig/logs/zig/2026-10-11-150553.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.10 | 0.17 | 57 | 74 | packed binary | fastest | yes | 93 |
| protobuf | 5.0.0 | 0.18 | 0.17 | 0.35 | 50 | 76 | Protocol Buffers | slower | yes | 88 |
| flatbuffers | 0.2.1 | 0.23 | 0.12 | 0.35 | 108 | 121 | FlatBuffers | slower | yes | 86 |
| serde.msgpack | 1.2.2 | 0.17 | 0.27 | 0.44 | 124 | 130 | MessagePack | slower | yes | 91 |
| std.json | 0.16.0 | 0.33 | 0.69 | 1.02 | 168 | 141 | JSON — stdlib | slower | yes | 89 |
| capnproto | 1.0.2 | 2.10 | 1.59 | 3.70 | 96 | 92 | Cap’n Proto | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.18 | 0.48 | 0.66 | 436 | 306 | packed binary | fastest | yes | 89 |
| flatbuffers | 0.2.1 | 0.56 | 0.26 | 0.82 | 660 | 430 | FlatBuffers | slower | yes | 91 |
| serde.msgpack | 1.2.2 | 0.29 | 0.56 | 0.86 | 346 | 276 | MessagePack | slower | yes | 94 |
| protobuf | 5.0.0 | 0.36 | 0.85 | 1.21 | 368 | 285 | Protocol Buffers | slower | yes | 91 |
| std.json | 0.16.0 | 0.68 | 1.89 | 2.57 | 411 | 287 | JSON — stdlib | slower | yes | 95 |
| capnproto | 1.0.2 | 6.97 | 8.07 | 15.1 | 736 | 427 | Cap’n Proto | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.23 | 0.27 | 0.49 | 1073 | 1088 | packed binary | fastest | yes | 90 |
| flatbuffers | 0.2.1 | 0.49 | 0.31 | 0.80 | 1124 | 1137 | FlatBuffers | slower | yes | 96 |
| serde.msgpack | 1.2.2 | 0.74 | 0.57 | 1.32 | 1212 | 1178 | MessagePack | slower | yes | 89 |
| protobuf | 5.0.0 | 1.26 | 0.99 | 2.26 | 1061 | 1085 | Protocol Buffers | slower | yes | 89 |
| capnproto | 1.0.2 | 4.59 | 4.34 | 8.97 | 1120 | 1123 | Cap’n Proto | slower | yes | 90 |
| std.json | 0.16.0 | 4.33 | 6.57 | 10.9 | 2407 | 1323 | JSON — stdlib | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `serde.msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

