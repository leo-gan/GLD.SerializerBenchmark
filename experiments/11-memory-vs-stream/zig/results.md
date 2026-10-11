# Experiment 11 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/11-memory-vs-stream/zig/logs/zig/2026-10-11-150806.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 0.73 | 0.43 | 1.16 | 468 | 262 | FlatBuffers | fastest | yes | 91 |
| serde.msgpack | 1.2.2 | 0.54 | 0.71 | 1.25 | 325 | 230 | MessagePack | close | yes | 95 |
| protobuf | 5.0.0 | 0.70 | 0.67 | 1.38 | 155 | 176 | Protocol Buffers | slower | yes | 92 |
| std.json.scanner | 0.16.0 | 0.88 | 2.29 | 3.16 | 448 | 233 | JSON — streaming parser | slower | yes | 89 |
| std.json | 0.16.0 | 0.89 | 2.29 | 3.17 | 448 | 233 | JSON | slower | yes | 92 |
| capnproto | 1.0.2 | 5.92 | 6.15 | 12.1 | 376 | 240 | Cap’n Proto | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| flatbuffers | 1 | 0.74 | 0.44 | 1.16 | copied |
| serde.msgpack | 1 | 0.54 | 0.70 | 1.26 | copied |
| protobuf | 1 | 0.71 | 0.69 | 1.40 | copied |
| std.json.scanner | 1 | 0.89 | 2.31 | 3.19 | text_on_stream |
| std.json | 1 | 0.89 | 2.32 | 3.20 | text_on_stream |
| capnproto | 1 | 6.00 | 6.14 | 12.2 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `serde.msgpack`. Time/size front: `flatbuffers`, `serde.msgpack`, `protobuf`.

