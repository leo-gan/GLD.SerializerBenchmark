# Experiment 7 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/07-write-once-read-many/zig/logs/zig/2026-08-28-173409.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.16 | 0.23 | 0.39 | 214 | 2072 | packed binary | fastest | yes | 92 |
| flatbuffers | 0.2.1 | 0.71 | 0.38 | 1.09 | 468 | 2135 | FlatBuffers | slower | yes | 89 |
| protobuf | 5.0.0 | 0.60 | 0.54 | 1.12 | 155 | 2066 | Protocol Buffers | slower | yes | 93 |
| serde.msgpack | 1.0.7 | 1.05 | 0.66 | 1.70 | 325 | 2238 | MessagePack | slower | yes | 91 |
| capnproto | 1.0.2 | 3.57 | 4.13 | 7.72 | 376 | 2121 | Cap’n Proto | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 1.33 | 0.37 | 1.70 | 4140 | 2072 | packed binary | fastest | yes | 90 |
| capnproto | 1.0.2 | 2.79 | 2.43 | 5.17 | 4184 | 2121 | Cap’n Proto | slower | yes | 91 |
| serde.msgpack | 1.0.7 | 3.18 | 1.91 | 5.20 | 4663 | 2238 | MessagePack | slower | yes | 93 |
| flatbuffers | 0.2.1 | 6.23 | 0.55 | 6.74 | 4188 | 2135 | FlatBuffers | slower | yes | 88 |
| protobuf | 5.0.0 | 3.81 | 3.47 | 7.26 | 4128 | 2066 | Protocol Buffers | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

