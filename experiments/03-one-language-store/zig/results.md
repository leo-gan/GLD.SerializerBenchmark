# Experiment 3 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/03-one-language-store/zig/logs/zig/2026-10-11-145946.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.10 | 0.18 | 57 | 74 | one language — comptime packed | fastest | yes | 92 |
| s2s | 0.0.1 | 0.14 | 0.13 | 0.28 | 73 | 88 | one language — s2s stream | slower | yes | 91 |
| flatbuffers | 0.2.1 | 0.23 | 0.14 | 0.36 | 108 | 112 | other languages can read — FlatBuffers | slower | yes | 86 |
| protobuf | 5.0.0 | 0.20 | 0.20 | 0.40 | 50 | 76 | other languages can read — Protocol Buffers | slower | yes | 89 |
| serde.msgpack | 1.2.2 | 0.19 | 0.31 | 0.50 | 124 | 130 | other languages can read — MessagePack | slower | yes | 94 |
| std.json | 0.16.0 | 0.36 | 0.74 | 1.10 | 168 | 141 | other languages can read — JSON | slower | yes | 91 |
| capnproto | 1.0.2 | 2.35 | 1.74 | 4.09 | 96 | 92 | other languages can read — Cap’n Proto | slower | yes | 91 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.07 | 0.10 | 0.18 | copied |
| s2s | 1 | 0.15 | 0.13 | 0.28 | real |
| flatbuffers | 1 | 0.23 | 0.13 | 0.35 | copied |
| protobuf | 1 | 0.20 | 0.19 | 0.38 | copied |
| serde.msgpack | 1 | 0.18 | 0.29 | 0.48 | copied |
| std.json | 1 | 0.36 | 0.75 | 1.12 | text_on_stream |
| capnproto | 1 | 2.41 | 1.75 | 4.20 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

