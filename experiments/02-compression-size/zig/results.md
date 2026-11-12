# Experiment 9 results — zig

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/zig/logs/zig/2026-11-12-101049.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.12 | 0.19 | 57 | 74 | packed binary | fastest | yes | 93 |
| flatbuffers | 0.2.3 | 0.25 | 0.13 | 0.38 | 108 | 121 | FlatBuffers | slower | yes | 83 |
| protobuf | 5.0.0 | 0.21 | 0.22 | 0.42 | 50 | 76 | Protocol Buffers | slower | yes | 87 |
| serde.msgpack | 1.2.4 | 0.18 | 0.29 | 0.48 | 124 | 130 | MessagePack | slower | yes | 86 |
| std.json | 0.16.0 | 0.36 | 0.80 | 1.15 | 168 | 141 | JSON — stdlib | slower | yes | 89 |
| gld-kiln | 0.2.0 | 0.22 | 3.31 | 3.53 | 57 | 74 | positional binary — no field names | slower | yes | 83 |
| capnproto | 1.0.2 | 2.39 | 1.70 | 4.09 | 96 | 92 | Cap’n Proto | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.21 | 0.52 | 0.73 | 436 | 306 | packed binary | fastest | yes | 93 |
| serde.msgpack | 1.2.4 | 0.31 | 0.57 | 0.86 | 346 | 276 | MessagePack | slower | yes | 93 |
| flatbuffers | 0.2.3 | 0.61 | 0.30 | 0.91 | 660 | 430 | FlatBuffers | slower | yes | 91 |
| protobuf | 5.0.0 | 0.39 | 0.92 | 1.31 | 368 | 285 | Protocol Buffers | slower | yes | 98 |
| std.json | 0.16.0 | 0.69 | 2.15 | 2.83 | 411 | 287 | JSON — stdlib | slower | yes | 96 |
| gld-kiln | 0.2.0 | 0.40 | 7.19 | 7.55 | 436 | 306 | positional binary — no field names | slower | yes | 96 |
| capnproto | 1.0.2 | 7.29 | 8.52 | 15.8 | 736 | 427 | Cap’n Proto | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.30 | 0.30 | 0.61 | 1073 | 1088 | packed binary | fastest | yes | 91 |
| flatbuffers | 0.2.3 | 0.55 | 0.39 | 0.94 | 1124 | 1137 | FlatBuffers | slower | yes | 88 |
| serde.msgpack | 1.2.4 | 0.83 | 0.59 | 1.44 | 1212 | 1178 | MessagePack | slower | yes | 83 |
| protobuf | 5.0.0 | 1.36 | 1.11 | 2.47 | 1061 | 1085 | Protocol Buffers | slower | yes | 89 |
| gld-kiln | 0.2.0 | 0.28 | 6.72 | 7.03 | 1073 | 1088 | positional binary — no field names | slower | yes | 89 |
| capnproto | 1.0.2 | 5.20 | 4.94 | 10.1 | 1120 | 1123 | Cap’n Proto | slower | yes | 89 |
| std.json | 0.16.0 | 4.57 | 7.60 | 12.2 | 2407 | 1323 | JSON — stdlib | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample E (words), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `serde.msgpack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

