# Experiment 5 results — zig

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/zig/logs/zig/2026-10-11-150137.csv`
**Language:** zig
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| serde.msgpack | 1.2.2 | 0.24 | 0.44 | 0.69 | 199 | 4676 | MessagePack | fastest | yes | 95 |
| flatbuffers | 0.2.1 | 0.47 | 0.25 | 0.72 | 296 | 5911 | FlatBuffers | close | yes | 95 |
| protobuf | 5.0.0 | 0.34 | 0.43 | 0.76 | 123 | 4380 | Protocol Buffers | slower | yes | 93 |
| serde.json | 1.2.2 | 0.53 | 0.77 | 1.30 | 257 | 4550 | JSON — serde.zig | slower | yes | 94 |
| std.json | 0.16.0 | 0.48 | 1.17 | 1.65 | 257 | 4550 | JSON — stdlib | slower | yes | 90 |
| capnproto | 1.0.2 | 4.40 | 4.53 | 8.94 | 256 | 5388 | Cap’n Proto | slower | yes | 97 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| flatbuffers | 0.2.1 | 23.3 | 14.8 | 38.2 | 31124 | 5911 | FlatBuffers | fastest | yes | 82 |
| serde.msgpack | 1.2.2 | 13.1 | 27.8 | 41.1 | 20249 | 4676 | MessagePack | slower | yes | 76 |
| protobuf | 5.0.0 | 22.0 | 28.4 | 50.4 | 12649 | 4380 | Protocol Buffers | slower | yes | 87 |
| serde.json | 1.2.2 | 46.8 | 72.1 | 119 | 26049 | 4550 | JSON — serde.zig | slower | yes | 86 |
| std.json | 0.16.0 | 45.3 | 97.4 | 143 | 26049 | 4550 | JSON — stdlib | slower | yes | 88 |
| capnproto | 1.0.2 | 298 | 335 | 636 | 26820 | 5388 | Cap’n Proto | slower | yes | 85 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| serde.msgpack | 1 | 0.25 | 0.45 | 0.70 | copied |
| flatbuffers | 1 | 0.49 | 0.26 | 0.76 | copied |
| protobuf | 1 | 0.36 | 0.43 | 0.80 | copied |
| serde.json | 1 | 0.53 | 0.79 | 1.33 | text_on_stream |
| std.json | 1 | 0.49 | 1.23 | 1.71 | text_on_stream |
| capnproto | 1 | 4.58 | 4.64 | 9.16 | copied |
| flatbuffers | 100 | 23.7 | 15.1 | 38.9 | copied |
| serde.msgpack | 100 | 13.0 | 27.9 | 40.9 | copied |
| protobuf | 100 | 22.0 | 28.5 | 50.5 | copied |
| serde.json | 100 | 47.1 | 72.4 | 120 | copied |
| std.json | 100 | 45.0 | 97.8 | 143 | copied |
| capnproto | 100 | 300 | 337 | 639 | copied |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `serde.msgpack`. Small gap: `flatbuffers`. Time/size front: `serde.msgpack`, `protobuf`.

**N = 100, memory** — not clearly slower: `flatbuffers`. Small gap: —. Time/size front: `flatbuffers`, `serde.msgpack`, `protobuf`.

