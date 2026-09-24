# Experiment 10 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/10-one-vs-hundred/mojo/logs/mojo/2026-09-23-181604.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.45 | 1.17 | 1.63 | 290 | 0 | JSON — EmberJson | fastest | yes | 92 |
| mojo-json | 0.3.0 | 0.49 | 1.25 | 1.72 | 290 | 0 | JSON — mojo-json | close | yes | 96 |
| mojo-avro | 0.4.0 | 0.26 | 2.08 | 2.34 | 138 | 0 | Avro | slower | yes | 94 |
| mojo-protobuf | 0.6.0 | 0.51 | 2.20 | 2.70 | 156 | 0 | Protocol Buffers | slower | yes | 97 |
| mojo-cbor | 0.6.0 | 0.35 | 3.57 | 3.94 | 232 | 0 | CBOR | slower | yes | 96 |
| mojo-flatbuffers | 0.2.0 | 2.77 | 1.30 | 4.12 | 320 | 0 | FlatBuffers | slower | yes | 97 |
| ehsanmok-json | 0.4.0 | 0.59 | 5.11 | 5.73 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 98 |
| mojo-toml | 0.9.1 | 14.8 | 24.9 | 39.7 | 304 | 0 | TOML | slower | yes | 96 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 41.2 | 75.3 | 117 | 27675 | 0 | JSON — EmberJson | fastest | yes | 88 |
| mojo-json | 0.3.0 | 36.7 | 92.8 | 130 | 27675 | 0 | JSON — mojo-json | slower | yes | 88 |
| mojo-avro | 0.4.0 | 25.3 | 156 | 182 | 12367 | 0 | Avro | slower | yes | 90 |
| mojo-protobuf | 0.6.0 | 40.2 | 164 | 203 | 14449 | 0 | Protocol Buffers | slower | yes | 80 |
| mojo-cbor | 0.6.0 | 26.9 | 275 | 302 | 21773 | 0 | CBOR | slower | yes | 87 |
| mojo-flatbuffers | 0.2.0 | 214 | 97.8 | 312 | 27896 | 0 | FlatBuffers | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 43.0 | 361 | 404 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 2081 | 2607 | 4697 | 29873 | 0 | TOML | slower | yes | 90 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.6.0 | 0.10 | 0.44 | 0.55 | 50 | 0 | Protocol Buffers | fastest | yes | 86 |
| mojo-avro | 0.4.0 | 0.10 | 0.45 | 0.55 | 44 | 0 | Avro | similar | yes | 88 |
| mojo-json | 0.3.0 | 0.23 | 0.36 | 0.60 | 164 | 0 | JSON — mojo-json | slower | yes | 85 |
| EmberJson | 0.3.4 | 0.26 | 0.55 | 0.81 | 168 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-flatbuffers | 0.2.0 | 0.75 | 0.25 | 0.99 | 104 | 0 | FlatBuffers | slower | yes | 89 |
| mojo-cbor | 0.6.0 | 0.18 | 1.30 | 1.47 | 124 | 0 | CBOR | slower | yes | 88 |
| ehsanmok-json | 0.4.0 | 0.34 | 3.21 | 3.56 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 2.07 | 10.4 | 12.4 | 167 | 0 | TOML | slower | yes | 84 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.53 | 33.6 | 39.2 | 4051 | 0 | Avro | fastest | yes | 89 |
| mojo-json | 0.3.0 | 15.3 | 27.8 | 43.2 | 16114 | 0 | JSON — mojo-json | slower | yes | 86 |
| mojo-protobuf | 0.6.0 | 8.98 | 36.4 | 45.7 | 4841 | 0 | Protocol Buffers | slower | yes | 87 |
| EmberJson | 0.3.4 | 20.9 | 34.8 | 55.9 | 16556 | 0 | JSON — EmberJson | slower | yes | 95 |
| mojo-flatbuffers | 0.2.0 | 62.9 | 19.3 | 82.1 | 8032 | 0 | FlatBuffers | slower | yes | 89 |
| mojo-cbor | 0.6.0 | 10.8 | 124 | 135 | 12037 | 0 | CBOR | slower | yes | 90 |
| ehsanmok-json | 0.4.0 | 21.0 | 292 | 312 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 88 |
| mojo-toml | 0.9.1 | 514 | 1117 | 1634 | 17554 | 0 | TOML | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: `mojo-json`. Time/size front: `EmberJson`, `mojo-avro`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-protobuf`, `mojo-avro`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

