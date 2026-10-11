# Experiment 4 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/04-sensor-list-size/zig/logs/zig/2026-10-11-150022.csv`
**Language:** zig
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.09 | 0.19 | 0.28 | 107 | 710 | comptime packed | fastest | yes | 94 |
| flatbuffers | 0.2.1 | 0.27 | 0.17 | 0.43 | 156 | 748 | FlatBuffers | slower | yes | 94 |
| serde.msgpack | 1.2.2 | 0.24 | 0.34 | 0.59 | 124 | 778 | MessagePack | slower | yes | 94 |
| protobuf | 5.0.0 | 0.35 | 0.36 | 0.71 | 94 | 700 | Protocol Buffers | slower | yes | 92 |
| serde.json | 1.2.2 | 0.55 | 0.73 | 1.28 | 220 | 866 | JSON — serde.zig | slower | yes | 98 |
| std.json | 0.16.0 | 0.54 | 1.07 | 1.61 | 220 | 866 | JSON — stdlib | slower | yes | 94 |
| capnproto | 1.0.2 | 3.35 | 2.79 | 6.12 | 152 | 736 | Cap’n Proto | slower | yes | 95 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.14 | 0.20 | 0.33 | 303 | 710 | comptime packed | fastest | yes | 89 |
| flatbuffers | 0.2.1 | 0.32 | 0.24 | 0.55 | 348 | 748 | FlatBuffers | slower | yes | 92 |
| serde.msgpack | 1.2.2 | 0.42 | 0.42 | 0.85 | 346 | 778 | MessagePack | slower | yes | 94 |
| protobuf | 5.0.0 | 0.69 | 0.57 | 1.27 | 291 | 700 | Protocol Buffers | slower | yes | 92 |
| serde.json | 1.2.2 | 1.38 | 1.80 | 3.20 | 663 | 866 | JSON — serde.zig | slower | yes | 95 |
| std.json | 0.16.0 | 1.36 | 2.28 | 3.67 | 663 | 866 | JSON — stdlib | slower | yes | 91 |
| capnproto | 1.0.2 | 3.78 | 3.23 | 7.02 | 344 | 736 | Cap’n Proto | slower | yes | 92 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.24 | 0.26 | 0.50 | 1073 | 710 | comptime packed | fastest | yes | 90 |
| flatbuffers | 0.2.1 | 0.40 | 0.33 | 0.72 | 1124 | 748 | FlatBuffers | slower | yes | 92 |
| serde.msgpack | 1.2.2 | 0.81 | 0.57 | 1.37 | 1212 | 778 | MessagePack | slower | yes | 93 |
| protobuf | 5.0.0 | 1.26 | 0.99 | 2.27 | 1061 | 700 | Protocol Buffers | slower | yes | 92 |
| capnproto | 1.0.2 | 4.57 | 4.33 | 8.88 | 1120 | 736 | Cap’n Proto | slower | yes | 93 |
| serde.json | 1.2.2 | 4.65 | 5.78 | 10.5 | 2407 | 866 | JSON — serde.zig | slower | yes | 95 |
| std.json | 0.16.0 | 4.54 | 6.98 | 11.6 | 2407 | 866 | JSON — stdlib | slower | yes | 90 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.55 | 0.42 | 0.98 | 4140 | 710 | comptime packed | fastest | yes | 79 |
| serde.msgpack | 1.2.2 | 2.60 | 1.11 | 3.69 | 4663 | 778 | MessagePack | slower | yes | 89 |
| flatbuffers | 0.2.1 | 5.09 | 0.63 | 5.74 | 4188 | 748 | FlatBuffers | slower | yes | 87 |
| protobuf | 5.0.0 | 3.80 | 2.77 | 6.59 | 4128 | 700 | Protocol Buffers | slower | yes | 90 |
| capnproto | 1.0.2 | 8.25 | 9.15 | 17.4 | 4184 | 736 | Cap’n Proto | slower | yes | 85 |
| serde.json | 1.2.2 | 19.1 | 22.6 | 41.6 | 9363 | 866 | JSON — serde.zig | slower | yes | 84 |
| std.json | 0.16.0 | 18.6 | 26.2 | 44.7 | 9363 | 866 | JSON — stdlib | slower | yes | 86 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| comptime-bin | 8 | 0.09 | 0.18 | 0.28 | copied |
| flatbuffers | 8 | 0.27 | 0.17 | 0.44 | copied |
| serde.msgpack | 8 | 0.24 | 0.33 | 0.57 | copied |
| protobuf | 8 | 0.35 | 0.36 | 0.72 | copied |
| serde.json | 8 | 0.55 | 0.73 | 1.27 | text_on_stream |
| std.json | 8 | 0.55 | 1.08 | 1.64 | text_on_stream |
| capnproto | 8 | 3.40 | 2.87 | 6.29 | copied |
| comptime-bin | 32 | 0.13 | 0.20 | 0.33 | copied |
| flatbuffers | 32 | 0.30 | 0.24 | 0.54 | copied |
| serde.msgpack | 32 | 0.43 | 0.42 | 0.86 | copied |
| protobuf | 32 | 0.69 | 0.56 | 1.25 | copied |
| serde.json | 32 | 1.39 | 1.80 | 3.23 | text_on_stream |
| std.json | 32 | 1.38 | 2.31 | 3.71 | text_on_stream |
| capnproto | 32 | 3.92 | 3.31 | 7.21 | copied |
| comptime-bin | 128 | 0.24 | 0.27 | 0.51 | copied |
| flatbuffers | 128 | 0.37 | 0.31 | 0.70 | copied |
| serde.msgpack | 128 | 0.81 | 0.55 | 1.37 | copied |
| protobuf | 128 | 1.25 | 0.97 | 2.24 | copied |
| capnproto | 128 | 4.52 | 4.32 | 8.87 | copied |
| serde.json | 128 | 4.66 | 5.82 | 10.5 | text_on_stream |
| std.json | 128 | 4.58 | 7.01 | 11.7 | text_on_stream |
| comptime-bin | 512 | 0.54 | 0.42 | 0.96 | copied |
| serde.msgpack | 512 | 2.55 | 1.04 | 3.60 | copied |
| flatbuffers | 512 | 4.90 | 0.61 | 5.56 | copied |
| protobuf | 512 | 3.75 | 2.74 | 6.51 | copied |
| capnproto | 512 | 8.00 | 9.02 | 17.1 | copied |
| serde.json | 512 | 18.9 | 22.5 | 41.4 | text_on_stream |
| std.json | 512 | 18.4 | 26.1 | 44.4 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**32 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**128 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**512 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

