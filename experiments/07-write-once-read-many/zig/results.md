# Experiment 7 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/07-write-once-read-many/zig/logs/zig/2026-10-11-150346.csv`
**Language:** zig
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.14 | 0.25 | 0.39 | 214 | 2072 | packed binary | fastest | yes | 95 |
| flatbuffers | 0.2.1 | 0.73 | 0.45 | 1.18 | 468 | 2135 | FlatBuffers | slower | yes | 88 |
| serde.msgpack | 1.2.2 | 0.50 | 0.70 | 1.20 | 325 | 2238 | MessagePack | slower | yes | 98 |
| protobuf | 5.0.0 | 0.69 | 0.68 | 1.39 | 155 | 2066 | Protocol Buffers | slower | yes | 95 |
| capnproto | 1.0.2 | 5.53 | 5.85 | 11.4 | 376 | 2121 | Cap’n Proto | slower | yes | 94 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.53 | 0.42 | 0.95 | 4140 | 2072 | packed binary | fastest | yes | 94 |
| serde.msgpack | 1.2.2 | 2.19 | 1.03 | 3.24 | 4663 | 2238 | MessagePack | slower | yes | 94 |
| flatbuffers | 0.2.1 | 4.52 | 0.59 | 5.11 | 4188 | 2135 | FlatBuffers | slower | yes | 93 |
| protobuf | 5.0.0 | 3.69 | 2.66 | 6.35 | 4128 | 2066 | Protocol Buffers | slower | yes | 91 |
| capnproto | 1.0.2 | 7.79 | 8.75 | 16.6 | 4184 | 2121 | Cap’n Proto | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**sample C (sensor), N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

