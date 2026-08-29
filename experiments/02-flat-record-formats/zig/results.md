# Experiment 2 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/02-flat-record-formats/zig/logs/zig/2026-08-28-173401.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.10 | 0.16 | 57 | 2108 | comptime byte-packed binary | fastest | yes | 90 |
| protobuf | 5.0.0 | 0.14 | 0.16 | 0.30 | 50 | 2131 | Protocol Buffers | slower | yes | 86 |
| flatbuffers | 0.2.1 | 0.22 | 0.11 | 0.33 | 108 | 2532 | FlatBuffers | slower | yes | 91 |
| serde.msgpack | 1.0.7 | 0.25 | 0.29 | 0.54 | 124 | 2346 | MessagePack — serde.zig | slower | yes | 91 |
| zbor | 0.21.0 | 0.23 | 0.73 | 0.95 | 124 | 2330 | CBOR — zbor | slower | yes | 91 |
| std.json | 0.16.0 | 0.41 | 0.82 | 1.24 | 168 | 2624 | JSON — stdlib | slower | yes | 93 |
| zig-msgpack | 0.0.14 | 0.64 | 0.88 | 1.53 | 124 | 2382 | MessagePack — zigcc | slower | yes | 89 |
| capnproto | 1.0.2 | 1.49 | 1.29 | 2.79 | 96 | 2352 | Cap’n Proto | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 3.07 | 3.91 | 6.98 | 5758 | 2108 | comptime byte-packed binary | fastest | yes | 90 |
| flatbuffers | 0.2.1 | 9.60 | 5.93 | 15.6 | 10644 | 2532 | FlatBuffers | slower | yes | 88 |
| protobuf | 5.0.0 | 7.21 | 8.56 | 15.9 | 5045 | 2131 | Protocol Buffers | slower | yes | 95 |
| serde.msgpack | 1.0.7 | 13.7 | 18.7 | 32.6 | 12432 | 2346 | MessagePack — serde.zig | slower | yes | 93 |
| zbor | 0.21.0 | 16.6 | 57.0 | 74.0 | 12432 | 2330 | CBOR — zbor | slower | yes | 90 |
| std.json | 0.16.0 | 33.7 | 63.5 | 96.9 | 16849 | 2624 | JSON — stdlib | slower | yes | 96 |
| zig-msgpack | 0.0.14 | 52.0 | 73.7 | 126 | 12432 | 2382 | MessagePack — zigcc | slower | yes | 92 |
| capnproto | 1.0.2 | 99.0 | 83.2 | 181 | 9572 | 2352 | Cap’n Proto | slower | yes | 97 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.07 | 0.10 | 0.17 | copied |
| protobuf | 1 | 0.15 | 0.16 | 0.31 | copied |
| flatbuffers | 1 | 0.24 | 0.11 | 0.36 | copied |
| serde.msgpack | 1 | 0.26 | 0.30 | 0.56 | copied |
| zbor | 1 | 0.23 | 0.75 | 0.99 | copied |
| std.json | 1 | 0.43 | 0.83 | 1.25 | text_on_stream |
| zig-msgpack | 1 | 0.68 | 0.95 | 1.62 | copied |
| capnproto | 1 | 1.49 | 1.34 | 2.84 | copied |
| comptime-bin | 100 | 3.02 | 3.85 | 6.85 | copied |
| flatbuffers | 100 | 9.63 | 5.82 | 15.5 | copied |
| protobuf | 100 | 7.30 | 8.23 | 15.7 | copied |
| serde.msgpack | 100 | 13.3 | 17.8 | 31.1 | copied |
| zbor | 100 | 16.3 | 54.9 | 71.7 | copied |
| std.json | 100 | 32.0 | 59.3 | 91.9 | copied |
| zig-msgpack | 100 | 50.4 | 70.3 | 121 | copied |
| capnproto | 100 | 95.0 | 79.6 | 175 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

