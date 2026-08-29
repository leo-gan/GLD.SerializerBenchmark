# Experiment 12 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/12-format-vs-library/zig/logs/zig/2026-08-28-173416.csv`
**Language:** zig
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.15 | 0.22 | 0.38 | 214 | 175 | in-tree — packed | fastest | yes | 95 |
| s2s | 0.0.1 | 0.28 | 0.27 | 0.55 | 266 | 187 | s2s — native binary | slower | yes | 92 |
| flatbuffers | 0.2.1 | 0.68 | 0.38 | 1.06 | 468 | 262 | FlatBuffers | slower | yes | 91 |
| protobuf | 5.0.0 | 0.56 | 0.53 | 1.10 | 155 | 176 | Protocol Buffers — zig-protobuf | slower | yes | 94 |
| serde.msgpack | 1.0.7 | 1.02 | 0.64 | 1.66 | 325 | 230 | serde.zig — MessagePack | slower | yes | 91 |
| serde.json | 1.0.7 | 1.07 | 1.40 | 2.47 | 448 | 233 | serde.zig — JSON | slower | yes | 93 |
| std.json | 0.16.0 | 1.01 | 2.46 | 3.46 | 448 | 233 | stdlib — JSON | slower | yes | 93 |
| zbor | 0.21.0 | 0.63 | 3.33 | 3.97 | 332 | 226 | zbor — CBOR | slower | yes | 96 |
| serde.toml | 1.0.7 | 1.00 | 4.08 | 5.06 | 508 | 234 | serde.zig — TOML | slower | yes | 91 |
| zig-msgpack | 0.0.14 | 2.10 | 3.25 | 5.35 | 325 | 232 | zigcc — MessagePack | slower | yes | 85 |
| capnproto | 1.0.2 | 3.54 | 4.00 | 7.57 | 376 | 240 | Cap’n Proto | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.31 | 0.44 | 0.76 | copied |
| s2s | 1 | 0.69 | 0.48 | 1.18 | real |
| flatbuffers | 1 | 1.08 | 0.97 | 2.08 | copied |
| protobuf | 1 | 1.02 | 1.25 | 2.30 | copied |
| serde.msgpack | 1 | 1.82 | 1.34 | 3.19 | copied |
| serde.json | 1 | 2.45 | 3.09 | 5.58 | copied |
| std.json | 1 | 1.96 | 4.73 | 6.67 | text_on_stream |
| zbor | 1 | 1.39 | 6.41 | 7.88 | copied |
| zig-msgpack | 1 | 3.79 | 5.26 | 9.12 | copied |
| serde.toml | 1 | 2.41 | 7.23 | 9.64 | text_on_stream |
| capnproto | 1 | 10.8 | 9.90 | 20.7 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

