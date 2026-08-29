# Experiment 3 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/03-one-language-store/zig/logs/zig/2026-08-28-173403.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.06 | 0.09 | 0.15 | 57 | 74 | one language — comptime packed | fastest | yes | 86 |
| s2s | 0.0.1 | 0.10 | 0.11 | 0.21 | 73 | 88 | one language — s2s stream | slower | yes | 93 |
| protobuf | 5.0.0 | 0.13 | 0.14 | 0.28 | 50 | 76 | other languages can read — Protocol Buffers | slower | yes | 91 |
| flatbuffers | 0.2.1 | 0.20 | 0.10 | 0.31 | 108 | 112 | other languages can read — FlatBuffers | slower | yes | 91 |
| serde.msgpack | 1.0.7 | 0.22 | 0.27 | 0.49 | 124 | 130 | other languages can read — MessagePack | slower | yes | 91 |
| std.json | 0.16.0 | 0.38 | 0.74 | 1.12 | 168 | 141 | other languages can read — JSON | slower | yes | 90 |
| capnproto | 1.0.2 | 1.16 | 0.93 | 2.09 | 96 | 92 | other languages can read — Cap’n Proto | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.06 | 0.09 | 0.16 | copied |
| s2s | 1 | 0.09 | 0.11 | 0.20 | real |
| protobuf | 1 | 0.13 | 0.14 | 0.27 | copied |
| flatbuffers | 1 | 0.21 | 0.10 | 0.32 | copied |
| serde.msgpack | 1 | 0.22 | 0.28 | 0.50 | copied |
| std.json | 1 | 0.38 | 0.74 | 1.13 | text_on_stream |
| capnproto | 1 | 1.19 | 0.95 | 2.16 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

