# Experiment 2 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/02-flat-record-formats/zig/logs/zig/2026-10-11-145859.csv`
**Language:** zig
**Sample:** one flat record (`message`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 0.07 | 0.09 | 0.16 | 57 | 2108 | comptime byte-packed binary | fastest | yes | 91 |
| flatbuffers | 0.2.1 | 0.23 | 0.13 | 0.35 | 108 | 2532 | FlatBuffers | slower | yes | 94 |
| protobuf | 5.0.0 | 0.20 | 0.19 | 0.38 | 50 | 2131 | Protocol Buffers | slower | yes | 92 |
| serde.msgpack | 1.2.2 | 0.21 | 0.30 | 0.51 | 124 | 2346 | MessagePack — serde.zig | slower | yes | 85 |
| std.json | 0.16.0 | 0.33 | 0.67 | 0.99 | 168 | 2624 | JSON — stdlib | slower | yes | 90 |
| zbor | 0.21.3 | 0.29 | 0.76 | 1.05 | 124 | 2330 | CBOR — zbor | slower | yes | 95 |
| zig-msgpack | 0.0.18 | 0.70 | 0.84 | 1.53 | 124 | 2382 | MessagePack — zigcc | slower | yes | 91 |
| capnproto | 1.0.2 | 2.39 | 1.78 | 4.10 | 96 | 2352 | Cap’n Proto | slower | yes | 95 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| comptime-bin | in-tree | 2.09 | 4.03 | 6.13 | 5758 | 2108 | comptime byte-packed binary | fastest | yes | 92 |
| flatbuffers | 0.2.1 | 10.5 | 6.18 | 16.8 | 10644 | 2532 | FlatBuffers | slower | yes | 95 |
| protobuf | 5.0.0 | 8.03 | 9.10 | 17.3 | 5045 | 2131 | Protocol Buffers | slower | yes | 96 |
| serde.msgpack | 1.2.2 | 8.95 | 14.5 | 23.8 | 12432 | 2346 | MessagePack — serde.zig | slower | yes | 93 |
| zbor | 0.21.3 | 17.3 | 54.4 | 71.9 | 12432 | 2330 | CBOR — zbor | slower | yes | 93 |
| std.json | 0.16.0 | 23.4 | 52.5 | 75.8 | 16849 | 2624 | JSON — stdlib | slower | yes | 90 |
| zig-msgpack | 0.0.18 | 51.9 | 73.3 | 126 | 12432 | 2382 | MessagePack — zigcc | slower | yes | 82 |
| capnproto | 1.0.2 | 118 | 96.0 | 214 | 9572 | 2352 | Cap’n Proto | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| comptime-bin | 1 | 0.07 | 0.10 | 0.17 | copied |
| flatbuffers | 1 | 0.23 | 0.13 | 0.36 | copied |
| protobuf | 1 | 0.19 | 0.20 | 0.39 | copied |
| serde.msgpack | 1 | 0.20 | 0.30 | 0.50 | copied |
| std.json | 1 | 0.35 | 0.68 | 1.03 | text_on_stream |
| zbor | 1 | 0.33 | 0.77 | 1.10 | copied |
| zig-msgpack | 1 | 0.72 | 0.86 | 1.58 | copied |
| capnproto | 1 | 2.50 | 1.82 | 4.33 | copied |
| comptime-bin | 100 | 2.10 | 4.00 | 6.13 | copied |
| flatbuffers | 100 | 10.4 | 6.07 | 16.6 | copied |
| protobuf | 100 | 7.91 | 9.00 | 17.0 | copied |
| serde.msgpack | 100 | 9.35 | 14.4 | 23.7 | copied |
| zbor | 100 | 17.3 | 54.0 | 71.4 | copied |
| std.json | 100 | 23.5 | 52.7 | 76.1 | copied |
| zig-msgpack | 100 | 51.8 | 70.9 | 122 | copied |
| capnproto | 100 | 118 | 96.4 | 215 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. Groups are computed **separately** for 1 record and for 100 records.

**N = 1, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

**N = 100, memory** — not clearly slower: `comptime-bin`. Small gap: —. Time/size front: `comptime-bin`, `protobuf`.

