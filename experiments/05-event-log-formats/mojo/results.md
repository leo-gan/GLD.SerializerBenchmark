# Experiment 5 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/05-event-log-formats/mojo/logs/mojo/2026-09-12-132637.csv`
**Language:** mojo
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.35 | 0.96 | 1.31 | 290 | 0 | JSON — EmberJson | fastest | yes | 88 |
| mojo-json | 0.3.0 | 0.40 | 1.01 | 1.40 | 290 | 0 | JSON — mojo-json | slower | yes | 93 |
| mojo-avro | 0.4.0 | 0.23 | 1.70 | 1.93 | 138 | 0 | Avro | slower | yes | 91 |
| mojo-protobuf | 0.6.0 | 0.42 | 1.78 | 2.20 | 156 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 0.31 | 2.89 | 3.20 | 232 | 0 | CBOR | slower | yes | 95 |
| ehsanmok-json | 0.3.1 | 0.47 | 3.97 | 4.45 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 11.7 | 20.0 | 31.8 | 304 | 0 | TOML | slower | yes | 91 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 41.3 | 74.4 | 116 | 27675 | 0 | JSON — EmberJson | fastest | yes | 94 |
| mojo-json | 0.3.0 | 35.4 | 90.0 | 126 | 27675 | 0 | JSON — mojo-json | slower | yes | 93 |
| mojo-avro | 0.4.0 | 26.0 | 155 | 181 | 12367 | 0 | Avro | slower | yes | 93 |
| mojo-protobuf | 0.6.0 | 40.8 | 165 | 206 | 14449 | 0 | Protocol Buffers | slower | yes | 91 |
| mojo-cbor | 0.6.0 | 26.9 | 274 | 301 | 21773 | 0 | CBOR | slower | yes | 92 |
| ehsanmok-json | 0.3.1 | 41.1 | 368 | 411 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 98 |
| mojo-toml | 0.9.1 | 2062 | 2603 | 4668 | 29873 | 0 | TOML | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

