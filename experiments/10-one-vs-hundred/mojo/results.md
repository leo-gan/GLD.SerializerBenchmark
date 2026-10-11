# Experiment 10 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/10-one-vs-hundred/mojo/logs/mojo/2026-10-11-150730.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.59 | 1.92 | 2.56 | 105 | 0 | Avro | fastest | yes | 93 |
| mojo-protobuf | 0.7.0 | 1.12 | 1.53 | 2.66 | 123 | 0 | Protocol Buffers | similar | yes | 93 |
| mojo-json | 0.5.0 | 0.91 | 1.91 | 2.84 | 257 | 0 | JSON — mojo-json | close | yes | 94 |
| mojo-cbor | 0.8.0 | 0.89 | 2.65 | 3.55 | 199 | 0 | CBOR | slower | yes | 92 |
| mojo-flatbuffers | 0.4.0 | 2.66 | 1.34 | 3.95 | 272 | 0 | FlatBuffers | slower | yes | 94 |
| EmberJson | 0.3.4 | 2.63 | 2.89 | 5.53 | 257 | 0 | JSON — EmberJson | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 1.34 | 5.49 | 6.87 | 257 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 13.8 | 24.6 | 38.5 | 271 | 0 | TOML | slower | yes | 93 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 23.0 | 76.6 | 99.2 | 25756 | 0 | JSON — mojo-json | fastest | yes | 93 |
| mojo-protobuf | 0.7.0 | 29.6 | 77.6 | 107 | 12477 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-avro | 0.4.0 | 21.2 | 123 | 144 | 10448 | 0 | Avro | slower | yes | 91 |
| EmberJson | 0.3.4 | 98.5 | 73.6 | 172 | 25756 | 0 | JSON — EmberJson | slower | yes | 92 |
| mojo-flatbuffers | 0.4.0 | 107 | 75.8 | 181 | 25968 | 0 | FlatBuffers | slower | yes | 95 |
| mojo-cbor | 0.8.0 | 49.3 | 156 | 205 | 19854 | 0 | CBOR | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 36.6 | 281 | 317 | 25756 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 1801 | 2458 | 4249 | 27954 | 0 | TOML | slower | yes | 99 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 0.48 | 0.70 | 1.16 | 50 | 0 | Protocol Buffers | fastest | yes | 89 |
| mojo-avro | 0.4.0 | 0.44 | 1.04 | 1.51 | 44 | 0 | Avro | slower | yes | 90 |
| mojo-json | 0.5.0 | 0.70 | 1.33 | 2.08 | 164 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-flatbuffers | 0.4.0 | 1.55 | 0.79 | 2.47 | 104 | 0 | FlatBuffers | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 0.86 | 1.98 | 2.82 | 124 | 0 | CBOR | slower | yes | 95 |
| EmberJson | 0.3.4 | 2.38 | 2.59 | 4.95 | 168 | 0 | JSON — EmberJson | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 1.34 | 5.33 | 6.72 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 4.12 | 16.2 | 20.3 | 167 | 0 | TOML | slower | yes | 91 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 6.48 | 16.2 | 22.7 | 4841 | 0 | Protocol Buffers | fastest | yes | 92 |
| mojo-avro | 0.4.0 | 5.82 | 26.9 | 33.0 | 4051 | 0 | Avro | slower | yes | 89 |
| mojo-json | 0.5.0 | 10.4 | 23.7 | 34.3 | 16114 | 0 | JSON — mojo-json | slower | yes | 95 |
| mojo-flatbuffers | 0.4.0 | 29.5 | 15.9 | 45.4 | 8032 | 0 | FlatBuffers | slower | yes | 88 |
| EmberJson | 0.3.4 | 51.0 | 32.8 | 83.9 | 16556 | 0 | JSON — EmberJson | slower | yes | 89 |
| mojo-cbor | 0.8.0 | 25.4 | 69.8 | 95.5 | 12037 | 0 | CBOR | slower | yes | 92 |
| ehsanmok-json | 0.4.0 | 19.8 | 231 | 251 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 443 | 1016 | 1463 | 17554 | 0 | TOML | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: `mojo-json`. Time/size front: `mojo-avro`.

**sample D (event), N = 100, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-protobuf`, `mojo-avro`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

