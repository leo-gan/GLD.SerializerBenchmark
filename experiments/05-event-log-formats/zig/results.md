# Experiment 5 results — zig

**Date:** 2026-08-29
**Raw file:** `experiments/05-event-log-formats/zig/logs/zig/2026-08-28-173405.csv`
**Language:** zig
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf | 5.0.0 | 0.32 | 0.38 | 0.70 | 123 | 4380 | Protocol Buffers | fastest | yes | 83 |
| flatbuffers | 0.2.1 | 0.51 | 0.22 | 0.73 | 296 | 5911 | FlatBuffers | slower | yes | 80 |
| serde.msgpack | 1.0.7 | 0.58 | 0.37 | 0.95 | 199 | 4676 | MessagePack | slower | yes | 82 |
| serde.json | 1.0.7 | 0.61 | 0.74 | 1.35 | 257 | 4550 | JSON — serde.zig | slower | yes | 81 |
| std.json | 0.16.0 | 0.58 | 1.44 | 2.01 | 257 | 4550 | JSON — stdlib | slower | yes | 86 |
| capnproto | 1.0.2 | 3.03 | 3.32 | 6.34 | 256 | 5388 | Cap’n Proto | slower | yes | 81 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 23.6 | 14.8 | 38.7 | 31124 | 5911 | FlatBuffers | fastest | yes | 89 |
| protobuf | 5.0.0 | 22.4 | 28.4 | 50.7 | 12649 | 4380 | Protocol Buffers | slower | yes | 85 |
| serde.msgpack | 1.0.7 | 38.3 | 28.2 | 66.7 | 20249 | 4676 | MessagePack | slower | yes | 85 |
| serde.json | 1.0.7 | 58.8 | 69.5 | 128 | 26049 | 4550 | JSON — serde.zig | slower | yes | 82 |
| std.json | 0.16.0 | 54.9 | 126 | 181 | 26049 | 4550 | JSON — stdlib | slower | yes | 87 |
| capnproto | 1.0.2 | 274 | 312 | 588 | 26820 | 5388 | Cap’n Proto | slower | yes | 85 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf | 1 | 0.32 | 0.39 | 0.71 | copied |
| flatbuffers | 1 | 0.52 | 0.22 | 0.74 | copied |
| serde.msgpack | 1 | 0.58 | 0.37 | 0.96 | copied |
| serde.json | 1 | 0.61 | 0.75 | 1.37 | copied |
| std.json | 1 | 0.59 | 1.46 | 2.05 | text_on_stream |
| capnproto | 1 | 3.05 | 3.39 | 6.43 | copied |
| flatbuffers | 100 | 23.7 | 14.8 | 38.5 | copied |
| protobuf | 100 | 22.6 | 28.4 | 51.2 | copied |
| serde.msgpack | 100 | 38.3 | 28.5 | 66.7 | copied |
| serde.json | 100 | 59.0 | 69.7 | 129 | copied |
| std.json | 100 | 55.0 | 126 | 181 | copied |
| capnproto | 100 | 275 | 313 | 588 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `protobuf`. Small gap: —. Time/size front: `protobuf`.

**N = 100, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`, `protobuf`.

