# Experiment 11 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/11-memory-vs-stream/zig/logs/zig/2026-08-28-173414.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 0.70 | 0.39 | 1.09 | 468 | 262 | FlatBuffers | fastest | yes | 93 |
| protobuf | 5.0.0 | 0.59 | 0.54 | 1.12 | 155 | 176 | Protocol Buffers | close | yes | 95 |
| serde.msgpack | 1.0.7 | 1.09 | 0.67 | 1.76 | 325 | 230 | MessagePack | slower | yes | 95 |
| std.json | 0.16.0 | 1.08 | 2.61 | 3.69 | 448 | 233 | JSON | slower | yes | 92 |
| std.json.scanner | 0.16.0 | 1.09 | 2.62 | 3.71 | 448 | 233 | JSON — streaming parser | slower | yes | 97 |
| capnproto | 1.0.2 | 3.66 | 4.20 | 7.87 | 376 | 240 | Cap’n Proto | slower | yes | 94 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| flatbuffers | 1 | 0.68 | 0.37 | 1.04 | copied |
| protobuf | 1 | 0.57 | 0.53 | 1.07 | copied |
| serde.msgpack | 1 | 1.03 | 0.64 | 1.69 | copied |
| std.json.scanner | 1 | 1.01 | 2.48 | 3.51 | text_on_stream |
| std.json | 1 | 1.02 | 2.50 | 3.52 | text_on_stream |
| capnproto | 1 | 3.51 | 4.00 | 7.50 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `flatbuffers`. Small gap: `protobuf`. Time/size front: `flatbuffers`, `protobuf`.

