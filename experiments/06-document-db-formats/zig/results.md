# Experiment 6 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/06-document-db-formats/zig/logs/zig/2026-08-28-173407.csv`
**Language:** zig
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 1.39 | 1.20 | 2.64 | 468 | 262 | FlatBuffers | fastest | yes | 91 |
| protobuf | 5.0.0 | 1.20 | 1.55 | 2.78 | 155 | 176 | Protocol Buffers | close | yes | 84 |
| serde.msgpack | 1.0.7 | 2.16 | 1.56 | 3.74 | 325 | 230 | MessagePack | slower | yes | 87 |
| serde.zon | 1.0.7 | 2.99 | 3.23 | 6.26 | 994 | 277 | ZON | slower | yes | 86 |
| std.json | 0.16.0 | 2.36 | 5.56 | 7.92 | 448 | 233 | JSON | slower | yes | 92 |
| capnproto | 1.0.2 | 13.3 | 12.1 | 25.9 | 376 | 240 | Cap’n Proto | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `protobuf`. Time/size front: `flatbuffers`, `protobuf`.

