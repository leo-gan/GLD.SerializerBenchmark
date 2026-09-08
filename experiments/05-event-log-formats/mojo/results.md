# Experiment 5 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/05-event-log-formats/mojo/logs/mojo/2026-09-08-155342.csv`
**Language:** mojo
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.36 | 0.95 | 1.31 | 290 | 0 | JSON — EmberJson | fastest | yes | 84 |
| mojo-avro | 0.4.0 | 0.21 | 1.68 | 1.90 | 138 | 0 | Avro | slower | yes | 87 |
| mojo-protobuf | 0.6.0 | 0.40 | 1.79 | 2.18 | 156 | 0 | Protocol Buffers | slower | yes | 82 |
| mojo-cbor | 0.6.0 | 0.30 | 2.85 | 3.15 | 232 | 0 | CBOR | slower | yes | 86 |
| ehsanmok-json | 0.3.0 | 24.3 | 3.94 | 28.2 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 85 |
| mojo-toml | 0.9.1 | 11.8 | 19.9 | 31.8 | 304 | 0 | TOML | slower | yes | 74 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 38.7 | 72.7 | 111 | 27675 | 0 | JSON — EmberJson | fastest | yes | 88 |
| mojo-avro | 0.4.0 | 24.9 | 149 | 174 | 12367 | 0 | Avro | slower | yes | 89 |
| mojo-protobuf | 0.6.0 | 40.0 | 159 | 200 | 14449 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 26.0 | 264 | 290 | 21773 | 0 | CBOR | slower | yes | 88 |
| mojo-toml | 0.9.1 | 2052 | 2526 | 4579 | 29873 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 9436 | 358 | 9812 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

