# Experiment 12 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/12-format-vs-library/zig/logs/zig/2026-10-11-150840.csv`
**Language:** zig
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.13 | 0.24 | 0.38 | 214 | 175 | in-tree — packed | fastest | yes | 94 |
| s2s | 0.0.1 | 0.34 | 0.26 | 0.61 | 266 | 187 | s2s — native binary | slower | yes | 93 |
| flatbuffers | 0.2.1 | 0.74 | 0.44 | 1.17 | 468 | 262 | FlatBuffers | slower | yes | 92 |
| serde.msgpack | 1.2.2 | 0.49 | 0.68 | 1.18 | 325 | 230 | serde.zig — MessagePack | slower | yes | 96 |
| protobuf | 5.0.0 | 0.67 | 0.65 | 1.33 | 155 | 176 | Protocol Buffers — zig-protobuf | slower | yes | 91 |
| serde.json | 1.2.2 | 0.96 | 1.52 | 2.47 | 448 | 233 | serde.zig — JSON | slower | yes | 94 |
| std.json | 0.16.0 | 0.86 | 2.19 | 3.05 | 448 | 233 | stdlib — JSON | slower | yes | 95 |
| zbor | 0.21.3 | 0.78 | 3.52 | 4.30 | 332 | 226 | zbor — CBOR | slower | yes | 94 |
| serde.toml | 1.2.2 | 1.06 | 4.48 | 5.52 | 508 | 234 | serde.zig — TOML | slower | yes | 92 |
| zig-msgpack | 0.0.18 | 2.26 | 3.46 | 5.69 | 325 | 232 | zigcc — MessagePack | slower | yes | 92 |
| capnproto | 1.0.2 | 5.66 | 5.70 | 11.3 | 376 | 240 | Cap’n Proto | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.14 | 0.25 | 0.39 | copied |
| s2s | 1 | 0.35 | 0.27 | 0.63 | real |
| serde.msgpack | 1 | 0.49 | 0.67 | 1.16 | copied |
| flatbuffers | 1 | 0.73 | 0.43 | 1.16 | copied |
| protobuf | 1 | 0.67 | 0.67 | 1.35 | copied |
| serde.json | 1 | 0.97 | 1.53 | 2.49 | text_on_stream |
| std.json | 1 | 0.86 | 2.20 | 3.07 | text_on_stream |
| zbor | 1 | 0.76 | 3.52 | 4.27 | copied |
| serde.toml | 1 | 1.06 | 4.50 | 5.56 | text_on_stream |
| zig-msgpack | 1 | 2.20 | 3.44 | 5.65 | copied |
| capnproto | 1 | 5.64 | 5.84 | 11.4 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small order. A different record can change who is first. Holding one library still is not a claim about every writer of that format.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

