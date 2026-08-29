# Experiment 4 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/04-sensor-list-size/zig/logs/zig/2026-08-28-173404.csv`
**Language:** zig
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.09 | 0.16 | 0.24 | 107 | 710 | comptime packed | fastest | yes | 89 |
| flatbuffers | 0.2.1 | 0.24 | 0.14 | 0.39 | 156 | 748 | FlatBuffers | slower | yes | 81 |
| serde.msgpack | 1.0.7 | 0.33 | 0.26 | 0.59 | 124 | 778 | MessagePack | slower | yes | 90 |
| protobuf | 5.0.0 | 0.31 | 0.29 | 0.61 | 94 | 700 | Protocol Buffers | slower | yes | 92 |
| serde.json | 1.0.7 | 0.53 | 0.63 | 1.16 | 220 | 866 | JSON — serde.zig | slower | yes | 85 |
| std.json | 0.16.0 | 0.56 | 1.08 | 1.66 | 220 | 866 | JSON — stdlib | slower | yes | 93 |
| capnproto | 1.0.2 | 1.72 | 1.61 | 3.34 | 152 | 736 | Cap’n Proto | slower | yes | 92 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.15 | 0.17 | 0.33 | 303 | 710 | comptime packed | fastest | yes | 96 |
| flatbuffers | 0.2.1 | 0.31 | 0.18 | 0.49 | 348 | 748 | FlatBuffers | slower | yes | 89 |
| protobuf | 5.0.0 | 0.60 | 0.52 | 1.12 | 291 | 700 | Protocol Buffers | slower | yes | 92 |
| serde.msgpack | 1.0.7 | 0.73 | 0.41 | 1.15 | 346 | 778 | MessagePack | slower | yes | 93 |
| serde.json | 1.0.7 | 1.30 | 1.47 | 2.77 | 663 | 866 | JSON — serde.zig | slower | yes | 89 |
| capnproto | 1.0.2 | 1.77 | 1.67 | 3.46 | 344 | 736 | Cap’n Proto | slower | yes | 87 |
| std.json | 0.16.0 | 1.32 | 2.33 | 3.65 | 663 | 866 | JSON — stdlib | slower | yes | 95 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.35 | 0.23 | 0.58 | 1073 | 710 | comptime packed | fastest | yes | 88 |
| flatbuffers | 0.2.1 | 0.34 | 0.28 | 0.62 | 1124 | 748 | FlatBuffers | close | yes | 90 |
| serde.msgpack | 1.0.7 | 1.22 | 0.74 | 1.98 | 1212 | 778 | MessagePack | slower | yes | 90 |
| protobuf | 5.0.0 | 1.16 | 1.07 | 2.23 | 1061 | 700 | Protocol Buffers | slower | yes | 92 |
| capnproto | 1.0.2 | 1.96 | 1.79 | 3.77 | 1120 | 736 | Cap’n Proto | slower | yes | 86 |
| serde.json | 1.0.7 | 4.30 | 4.47 | 8.79 | 2407 | 866 | JSON — serde.zig | slower | yes | 88 |
| std.json | 0.16.0 | 4.23 | 6.73 | 11.0 | 2407 | 866 | JSON — stdlib | slower | yes | 81 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 1.26 | 0.34 | 1.61 | 4140 | 710 | comptime packed | fastest | yes | 87 |
| serde.msgpack | 1.0.7 | 3.04 | 1.79 | 4.82 | 4663 | 778 | MessagePack | slower | yes | 88 |
| capnproto | 1.0.2 | 2.64 | 2.29 | 4.93 | 4184 | 736 | Cap’n Proto | slower | yes | 87 |
| flatbuffers | 0.2.1 | 6.12 | 0.52 | 6.65 | 4188 | 748 | FlatBuffers | slower | yes | 88 |
| protobuf | 5.0.0 | 3.60 | 3.32 | 6.94 | 4128 | 700 | Protocol Buffers | slower | yes | 89 |
| serde.json | 1.0.7 | 17.9 | 17.4 | 35.5 | 9363 | 866 | JSON — serde.zig | slower | yes | 93 |
| std.json | 0.16.0 | 17.2 | 25.6 | 42.6 | 9363 | 866 | JSON — stdlib | slower | yes | 91 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| comptime-bin | 8 | 0.08 | 0.15 | 0.24 | copied |
| flatbuffers | 8 | 0.24 | 0.14 | 0.38 | copied |
| serde.msgpack | 8 | 0.32 | 0.25 | 0.57 | copied |
| protobuf | 8 | 0.31 | 0.29 | 0.60 | copied |
| serde.json | 8 | 0.52 | 0.62 | 1.15 | copied |
| std.json | 8 | 0.55 | 1.06 | 1.61 | text_on_stream |
| capnproto | 8 | 1.69 | 1.58 | 3.27 | copied |
| comptime-bin | 32 | 0.16 | 0.18 | 0.33 | copied |
| flatbuffers | 32 | 0.33 | 0.18 | 0.52 | copied |
| protobuf | 32 | 0.60 | 0.53 | 1.13 | copied |
| serde.msgpack | 32 | 0.74 | 0.41 | 1.15 | copied |
| serde.json | 32 | 1.33 | 1.51 | 2.85 | copied |
| capnproto | 32 | 1.83 | 1.71 | 3.56 | copied |
| std.json | 32 | 1.35 | 2.41 | 3.78 | text_on_stream |
| comptime-bin | 128 | 0.38 | 0.24 | 0.63 | copied |
| flatbuffers | 128 | 0.42 | 0.30 | 0.72 | copied |
| serde.msgpack | 128 | 1.29 | 0.79 | 2.11 | copied |
| protobuf | 128 | 1.25 | 1.17 | 2.43 | copied |
| capnproto | 128 | 2.12 | 1.92 | 4.09 | copied |
| serde.json | 128 | 4.70 | 4.89 | 9.59 | copied |
| std.json | 128 | 4.67 | 7.51 | 12.2 | text_on_stream |
| comptime-bin | 512 | 1.25 | 0.34 | 1.59 | copied |
| serde.msgpack | 512 | 2.99 | 1.79 | 4.80 | copied |
| capnproto | 512 | 2.61 | 2.23 | 4.89 | copied |
| flatbuffers | 512 | 6.22 | 0.52 | 6.73 | copied |
| protobuf | 512 | 3.59 | 3.30 | 6.89 | copied |
| serde.json | 512 | 17.7 | 17.1 | 34.8 | copied |
| std.json | 512 | 17.1 | 25.3 | 42.4 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**32 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**128 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: `flatbuffers`. Time/size front: `comptime-bin`, `protobuf`.

**512 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

