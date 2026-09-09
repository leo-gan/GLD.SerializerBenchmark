# Experiment 5 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/05-event-log-formats/mojo/logs/mojo/2026-09-09-132117.csv`
**Language:** mojo
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.33 | 0.96 | 1.29 | 290 | 0 | JSON — EmberJson | fastest | yes | 91 |
| mojo-avro | 0.4.0 | 0.22 | 1.65 | 1.87 | 138 | 0 | Avro | slower | yes | 93 |
| mojo-protobuf | 0.6.0 | 0.39 | 1.75 | 2.15 | 156 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-json | 0.2.0 | 0.66 | 2.38 | 3.03 | 290 | 0 | JSON — mojo-json | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.29 | 2.81 | 3.10 | 232 | 0 | CBOR | slower | yes | 93 |
| ehsanmok-json | 0.3.0 | 24.0 | 3.59 | 27.6 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 11.5 | 19.4 | 31.0 | 304 | 0 | TOML | slower | yes | 90 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 39.4 | 79.8 | 120 | 27675 | 0 | JSON — EmberJson | fastest | yes | 88 |
| mojo-avro | 0.4.0 | 26.7 | 157 | 183 | 12367 | 0 | Avro | slower | yes | 87 |
| mojo-protobuf | 0.6.0 | 42.3 | 168 | 210 | 14449 | 0 | Protocol Buffers | slower | yes | 91 |
| mojo-json | 0.2.0 | 42.3 | 233 | 274 | 27675 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-cbor | 0.6.0 | 27.6 | 276 | 305 | 21773 | 0 | CBOR | slower | yes | 91 |
| mojo-toml | 0.9.1 | 2177 | 2690 | 4927 | 29873 | 0 | TOML | slower | yes | 95 |
| ehsanmok-json | 0.3.0 | 9985 | 355 | 10348 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

