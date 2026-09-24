# Experiment 5 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/05-event-log-formats/mojo/logs/mojo/2026-09-23-181510.csv`
**Language:** mojo
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.41 | 1.07 | 1.48 | 290 | 0 | JSON — EmberJson | fastest | yes | 83 |
| mojo-json | 0.3.0 | 0.43 | 1.09 | 1.53 | 290 | 0 | JSON — mojo-json | close | yes | 86 |
| mojo-avro | 0.4.0 | 0.24 | 1.84 | 2.09 | 138 | 0 | Avro | slower | yes | 90 |
| mojo-protobuf | 0.6.0 | 0.47 | 1.94 | 2.41 | 156 | 0 | Protocol Buffers | slower | yes | 85 |
| mojo-cbor | 0.6.0 | 0.33 | 3.13 | 3.46 | 232 | 0 | CBOR | slower | yes | 90 |
| mojo-flatbuffers | 0.2.0 | 2.46 | 1.13 | 3.63 | 320 | 0 | FlatBuffers | slower | yes | 96 |
| ehsanmok-json | 0.4.0 | 0.53 | 4.53 | 5.06 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 12.8 | 21.6 | 34.5 | 304 | 0 | TOML | slower | yes | 93 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 42.5 | 77.4 | 120 | 27675 | 0 | JSON — EmberJson | fastest | yes | 93 |
| mojo-json | 0.3.0 | 37.5 | 95.1 | 133 | 27675 | 0 | JSON — mojo-json | slower | yes | 85 |
| mojo-avro | 0.4.0 | 26.6 | 161 | 187 | 12367 | 0 | Avro | slower | yes | 82 |
| mojo-protobuf | 0.6.0 | 42.9 | 171 | 214 | 14449 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 28.6 | 283 | 313 | 21773 | 0 | CBOR | slower | yes | 89 |
| mojo-flatbuffers | 0.2.0 | 222 | 102 | 324 | 27896 | 0 | FlatBuffers | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 44.5 | 375 | 419 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 2154 | 2685 | 4850 | 29873 | 0 | TOML | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `EmberJson`. Small gap: `mojo-json`. Time/size front: `EmberJson`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

