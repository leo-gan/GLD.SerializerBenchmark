# Experiment 9 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/09-compression-size/mojo/logs/mojo/2026-09-23-181553.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.15 | 0.65 | 0.82 | 44 | 0 | Avro | fastest | yes | 86 |
| mojo-protobuf | 0.6.0 | 0.17 | 0.65 | 0.82 | 50 | 0 | Protocol Buffers | similar | yes | 82 |
| mojo-json | 0.3.0 | 0.35 | 0.55 | 0.89 | 164 | 0 | JSON — mojo-json | slower | yes | 78 |
| EmberJson | 0.3.4 | 0.40 | 0.83 | 1.20 | 168 | 0 | JSON — EmberJson | slower | yes | 89 |
| mojo-flatbuffers | 0.2.0 | 1.11 | 0.39 | 1.50 | 104 | 0 | FlatBuffers | slower | yes | 88 |
| mojo-cbor | 0.6.0 | 0.25 | 1.96 | 2.22 | 124 | 0 | CBOR | slower | yes | 64 |
| ehsanmok-json | 0.4.0 | 0.52 | 4.93 | 5.44 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 63 |
| mojo-toml | 0.9.1 | 3.08 | 15.3 | 18.4 | 167 | 0 | TOML | slower | yes | 68 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.69 | 1.14 | 1.83 | 411 | 0 | JSON — EmberJson | fastest | yes | 88 |
| mojo-json | 0.3.0 | 0.81 | 2.20 | 3.01 | 411 | 0 | JSON — mojo-json | slower | yes | 80 |
| mojo-avro | 0.4.0 | 0.53 | 4.04 | 4.57 | 338 | 0 | Avro | slower | yes | 71 |
| mojo-cbor | 0.6.0 | 0.33 | 4.36 | 4.70 | 345 | 0 | CBOR | slower | yes | 68 |
| mojo-protobuf | 0.6.0 | 0.84 | 4.26 | 5.11 | 368 | 0 | Protocol Buffers | slower | yes | 64 |
| mojo-flatbuffers | 0.2.0 | 3.15 | 2.42 | 5.58 | 660 | 0 | FlatBuffers | slower | yes | 85 |
| ehsanmok-json | 0.4.0 | 0.98 | 4.75 | 5.73 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 12.6 | 19.3 | 32.0 | 441 | 0 | TOML | slower | yes | 70 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-flatbuffers | 0.2.0 | 1.76 | 1.42 | 3.19 | 1136 | 0 | FlatBuffers | fastest | yes | 89 |
| mojo-avro | 0.4.0 | 0.76 | 2.64 | 3.40 | 1071 | 0 | Avro | slower | yes | 91 |
| mojo-protobuf | 0.6.0 | 1.26 | 4.22 | 5.47 | 1073 | 0 | Protocol Buffers | slower | yes | 91 |
| mojo-cbor | 0.6.0 | 1.98 | 3.65 | 5.64 | 1223 | 0 | CBOR | slower | yes | 95 |
| mojo-json | 0.3.0 | 4.41 | 3.55 | 7.97 | 1727 | 0 | JSON — mojo-json | slower | yes | 93 |
| EmberJson | 0.3.4 | 5.88 | 4.29 | 10.2 | 2419 | 0 | JSON — EmberJson | slower | yes | 88 |
| ehsanmok-json | 0.4.0 | 17.6 | 18.5 | 36.1 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 87 |
| mojo-toml | 0.9.1 | 58.1 | 122 | 180 | 2546 | 0 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-flatbuffers`. Small gap: —. Time/size front: `mojo-flatbuffers`, `mojo-avro`.

