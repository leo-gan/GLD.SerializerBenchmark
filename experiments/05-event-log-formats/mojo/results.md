# Experiment 5 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/mojo/logs/mojo/2026-10-11-150201.csv`
**Language:** mojo
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.67 | 2.25 | 2.91 | 105 | 0 | Avro | fastest | yes | 98 |
| mojo-protobuf | 0.7.0 | 1.26 | 1.78 | 3.03 | 123 | 0 | Protocol Buffers | similar | yes | 97 |
| mojo-json | 0.5.0 | 1.00 | 2.27 | 3.32 | 257 | 0 | JSON — mojo-json | close | yes | 96 |
| mojo-cbor | 0.8.0 | 1.10 | 3.06 | 4.19 | 199 | 0 | CBOR | slower | yes | 97 |
| mojo-flatbuffers | 0.4.0 | 3.37 | 1.65 | 5.00 | 272 | 0 | FlatBuffers | slower | yes | 93 |
| EmberJson | 0.3.4 | 3.13 | 3.63 | 6.90 | 257 | 0 | JSON — EmberJson | slower | yes | 97 |
| ehsanmok-json | 0.4.0 | 1.57 | 6.37 | 8.01 | 257 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 16.5 | 29.2 | 45.7 | 271 | 0 | TOML | slower | yes | 95 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 22.9 | 78.0 | 101 | 25756 | 0 | JSON — mojo-json | fastest | yes | 94 |
| mojo-protobuf | 0.7.0 | 32.6 | 79.6 | 112 | 12477 | 0 | Protocol Buffers | slower | yes | 93 |
| mojo-avro | 0.4.0 | 22.4 | 125 | 148 | 10448 | 0 | Avro | slower | yes | 95 |
| EmberJson | 0.3.4 | 98.6 | 77.6 | 177 | 25756 | 0 | JSON — EmberJson | slower | yes | 92 |
| mojo-flatbuffers | 0.4.0 | 114 | 79.0 | 193 | 25968 | 0 | FlatBuffers | slower | yes | 97 |
| mojo-cbor | 0.8.0 | 49.8 | 157 | 207 | 19854 | 0 | CBOR | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 37.0 | 275 | 313 | 25756 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2033 | 2693 | 4736 | 27954 | 0 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: `mojo-json`. Time/size front: `mojo-avro`.

**N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-protobuf`, `mojo-avro`.

