# Experiment 6 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/06-document-db-formats/zig/logs/zig/2026-10-11-150300.csv`
**Language:** zig
**Sample:** one order-like record (`document`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 0.67 | 0.41 | 1.08 | 468 | 262 | FlatBuffers | fastest | yes | 92 |
| serde.msgpack | 1.2.2 | 0.45 | 0.62 | 1.08 | 325 | 230 | MessagePack | similar | yes | 93 |
| protobuf | 5.0.0 | 0.64 | 0.63 | 1.26 | 155 | 176 | Protocol Buffers | slower | yes | 93 |
| std.json | 0.16.0 | 0.84 | 2.16 | 3.00 | 448 | 233 | JSON | slower | yes | 91 |
| serde.zon | 1.2.2 | 1.39 | 1.54 | 3.00 | 994 | 277 | ZON | slower | yes | 92 |
| capnproto | 1.0.2 | 5.15 | 5.40 | 10.5 | 376 | 240 | Cap’n Proto | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `flatbuffers`, `serde.msgpack`. Small gap: —. Time/size front: `flatbuffers`, `serde.msgpack`, `protobuf`.

