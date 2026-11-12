# Experiment 4 results — zig

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/zig/logs/zig/2026-11-12-100608.csv`
**Language:** zig
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.14 | 0.20 | 0.34 | 107 | 710 | comptime packed | fastest | yes | 88 |
| flatbuffers | 0.2.3 | 0.33 | 0.24 | 0.56 | 156 | 748 | FlatBuffers | slower | yes | 87 |
| serde.msgpack | 1.2.4 | 0.26 | 0.35 | 0.62 | 124 | 778 | MessagePack | slower | yes | 87 |
| protobuf | 5.0.0 | 0.41 | 0.40 | 0.82 | 94 | 700 | Protocol Buffers | slower | yes | 90 |
| serde.json | 1.2.4 | 0.60 | 0.84 | 1.44 | 220 | 866 | JSON — serde.zig | slower | yes | 92 |
| std.json | 0.16.0 | 0.61 | 1.24 | 1.85 | 220 | 866 | JSON — stdlib | slower | yes | 87 |
| gld-kiln | 0.2.0 | 0.21 | 7.03 | 7.21 | 107 | 710 | positional binary — no field names | slower | yes | 88 |
| capnproto | 1.0.2 | 3.95 | 3.49 | 7.46 | 152 | 736 | Cap’n Proto | slower | yes | 88 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.18 | 0.22 | 0.40 | 303 | 710 | comptime packed | fastest | yes | 88 |
| flatbuffers | 0.2.3 | 0.41 | 0.32 | 0.74 | 348 | 748 | FlatBuffers | slower | yes | 89 |
| serde.msgpack | 1.2.4 | 0.43 | 0.43 | 0.88 | 346 | 778 | MessagePack | slower | yes | 83 |
| protobuf | 5.0.0 | 0.75 | 0.66 | 1.40 | 291 | 700 | Protocol Buffers | slower | yes | 85 |
| serde.json | 1.2.4 | 1.44 | 1.99 | 3.48 | 663 | 866 | JSON — serde.zig | slower | yes | 85 |
| std.json | 0.16.0 | 1.42 | 2.57 | 4.01 | 663 | 866 | JSON — stdlib | slower | yes | 86 |
| gld-kiln | 0.2.0 | 0.26 | 7.12 | 7.43 | 303 | 710 | positional binary — no field names | slower | yes | 88 |
| capnproto | 1.0.2 | 4.69 | 4.01 | 8.76 | 344 | 736 | Cap’n Proto | slower | yes | 88 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.31 | 0.29 | 0.61 | 1073 | 710 | comptime packed | fastest | yes | 86 |
| flatbuffers | 0.2.3 | 0.57 | 0.38 | 0.94 | 1124 | 748 | FlatBuffers | slower | yes | 87 |
| serde.msgpack | 1.2.4 | 0.82 | 0.60 | 1.42 | 1212 | 778 | MessagePack | slower | yes | 88 |
| protobuf | 5.0.0 | 1.43 | 1.13 | 2.56 | 1061 | 700 | Protocol Buffers | slower | yes | 88 |
| gld-kiln | 0.2.0 | 0.31 | 7.39 | 7.75 | 1073 | 710 | positional binary — no field names | slower | yes | 90 |
| serde.json | 1.2.4 | 4.91 | 6.23 | 11.1 | 2407 | 866 | JSON — serde.zig | slower | yes | 91 |
| capnproto | 1.0.2 | 5.94 | 5.30 | 11.3 | 1120 | 736 | Cap’n Proto | slower | yes | 90 |
| std.json | 0.16.0 | 4.80 | 8.04 | 12.8 | 2407 | 866 | JSON — stdlib | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.65 | 0.44 | 1.10 | 4140 | 710 | comptime packed | fastest | yes | 81 |
| serde.msgpack | 1.2.4 | 2.38 | 1.16 | 3.54 | 4663 | 778 | MessagePack | slower | yes | 86 |
| flatbuffers | 0.2.3 | 5.74 | 0.72 | 6.45 | 4188 | 748 | FlatBuffers | slower | yes | 85 |
| protobuf | 5.0.0 | 4.10 | 3.03 | 7.11 | 4128 | 700 | Protocol Buffers | slower | yes | 88 |
| gld-kiln | 0.2.0 | 0.61 | 8.51 | 9.09 | 4140 | 710 | positional binary — no field names | slower | yes | 83 |
| capnproto | 1.0.2 | 9.11 | 9.99 | 19.2 | 4184 | 736 | Cap’n Proto | slower | yes | 85 |
| serde.json | 1.2.4 | 19.3 | 22.9 | 42.3 | 9363 | 866 | JSON — serde.zig | slower | yes | 94 |
| std.json | 0.16.0 | 18.8 | 28.4 | 47.4 | 9363 | 866 | JSON — stdlib | slower | yes | 93 |

## Stream call (side note)

| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|--------|------------|-----------|-------------------|---------------------------|
| comptime-bin | 8 | 0.13 | 0.20 | 0.32 | copied |
| flatbuffers | 8 | 0.30 | 0.22 | 0.53 | copied |
| serde.msgpack | 8 | 0.24 | 0.36 | 0.60 | copied |
| protobuf | 8 | 0.39 | 0.38 | 0.78 | copied |
| serde.json | 8 | 0.58 | 0.81 | 1.38 | text_on_stream |
| std.json | 8 | 0.60 | 1.21 | 1.81 | text_on_stream |
| gld-kiln | 8 | 0.21 | 6.91 | 7.16 | copied |
| capnproto | 8 | 3.94 | 3.40 | 7.32 | copied |
| comptime-bin | 32 | 0.18 | 0.22 | 0.39 | copied |
| flatbuffers | 32 | 0.38 | 0.29 | 0.65 | copied |
| serde.msgpack | 32 | 0.42 | 0.42 | 0.86 | copied |
| protobuf | 32 | 0.77 | 0.66 | 1.44 | copied |
| serde.json | 32 | 1.45 | 1.97 | 3.41 | text_on_stream |
| std.json | 32 | 1.48 | 2.71 | 4.18 | text_on_stream |
| gld-kiln | 32 | 0.23 | 6.99 | 7.22 | copied |
| capnproto | 32 | 4.38 | 3.83 | 8.20 | copied |
| comptime-bin | 128 | 0.34 | 0.29 | 0.64 | copied |
| flatbuffers | 128 | 0.51 | 0.37 | 0.88 | copied |
| serde.msgpack | 128 | 0.85 | 0.59 | 1.44 | copied |
| protobuf | 128 | 1.49 | 1.17 | 2.68 | copied |
| gld-kiln | 128 | 0.30 | 7.13 | 7.52 | copied |
| capnproto | 128 | 5.79 | 5.36 | 11.1 | copied |
| serde.json | 128 | 5.09 | 6.41 | 11.5 | text_on_stream |
| std.json | 128 | 4.99 | 8.39 | 13.4 | text_on_stream |
| comptime-bin | 512 | 0.64 | 0.43 | 1.09 | copied |
| serde.msgpack | 512 | 2.40 | 1.14 | 3.53 | copied |
| flatbuffers | 512 | 5.44 | 0.72 | 6.16 | copied |
| protobuf | 512 | 4.08 | 3.05 | 7.11 | copied |
| gld-kiln | 512 | 0.59 | 7.91 | 8.57 | copied |
| capnproto | 512 | 9.76 | 10.4 | 20.1 | copied |
| serde.json | 512 | 19.4 | 23.0 | 42.4 | text_on_stream |
| std.json | 512 | 18.9 | 28.4 | 47.2 | text_on_stream |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**32 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**128 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**512 numbers, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

