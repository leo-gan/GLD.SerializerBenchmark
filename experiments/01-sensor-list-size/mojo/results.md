# Experiment 4 results — mojo

**Date:** 2026-11-12
**Raw file:** `experiments/01-sensor-list-size/mojo/logs/mojo/2026-11-12-100611.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.80 | 1.22 | 2.03 | 107 | 0 | positional binary — no field names | fastest | yes | 91 |
| mojo-avro | 0.4.0 | 0.69 | 1.58 | 2.28 | 92 | 0 | Avro | similar | yes | 91 |
| mojo-protobuf | 0.7.0 | 1.39 | 1.97 | 3.46 | 94 | 0 | Protocol Buffers | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 1.17 | 2.38 | 3.51 | 124 | 0 | CBOR | slower | yes | 98 |
| mojo-json | 0.5.0 | 1.66 | 2.99 | 4.78 | 177 | 0 | JSON — mojo-json | slower | yes | 97 |
| mojo-flatbuffers | 0.4.0 | 3.53 | 1.94 | 5.30 | 160 | 0 | FlatBuffers | slower | yes | 97 |
| EmberJson | 0.3.4 | 4.08 | 3.52 | 7.62 | 220 | 0 | JSON — EmberJson | slower | yes | 98 |
| ehsanmok-json | 0.4.0 | 6.69 | 8.19 | 15.2 | 220 | 0 | JSON — ehsanmok/json | slower | yes | 98 |
| mojo-toml | 0.9.1 | 12.1 | 27.5 | 39.9 | 227 | 0 | TOML | slower | yes | 96 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.66 | 1.01 | 1.68 | 303 | 0 | positional binary — no field names | fastest | yes | 93 |
| mojo-avro | 0.4.0 | 0.73 | 1.66 | 2.49 | 288 | 0 | Avro | close | yes | 93 |
| mojo-protobuf | 0.7.0 | 1.18 | 1.81 | 2.99 | 291 | 0 | Protocol Buffers | slower | yes | 88 |
| mojo-cbor | 0.8.0 | 1.21 | 2.30 | 3.48 | 345 | 0 | CBOR | slower | yes | 93 |
| mojo-flatbuffers | 0.4.0 | 2.46 | 1.80 | 4.23 | 352 | 0 | FlatBuffers | slower | yes | 94 |
| mojo-json | 0.5.0 | 1.95 | 3.23 | 5.11 | 486 | 0 | JSON — mojo-json | slower | yes | 91 |
| EmberJson | 0.3.4 | 4.99 | 3.27 | 8.21 | 663 | 0 | JSON — EmberJson | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 9.06 | 9.80 | 18.8 | 663 | 0 | JSON — ehsanmok/json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 22.0 | 48.4 | 70.4 | 694 | 0 | TOML | slower | yes | 92 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 1.27 | 1.79 | 3.02 | 1073 | 0 | positional binary — no field names | fastest | yes | 92 |
| mojo-avro | 0.4.0 | 1.42 | 3.13 | 4.52 | 1059 | 0 | Avro | slower | yes | 91 |
| mojo-protobuf | 0.7.0 | 2.16 | 3.06 | 5.15 | 1061 | 0 | Protocol Buffers | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 3.01 | 4.30 | 7.31 | 1211 | 0 | CBOR | slower | yes | 91 |
| mojo-flatbuffers | 0.4.0 | 4.78 | 2.74 | 7.70 | 1128 | 0 | FlatBuffers | slower | yes | 89 |
| mojo-json | 0.5.0 | 5.29 | 7.90 | 13.3 | 1716 | 0 | JSON — mojo-json | slower | yes | 89 |
| EmberJson | 0.3.4 | 11.7 | 7.13 | 18.7 | 2407 | 0 | JSON — EmberJson | slower | yes | 90 |
| ehsanmok-json | 0.4.0 | 25.2 | 23.4 | 48.4 | 2407 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 74.0 | 152 | 228 | 2534 | 0 | TOML | slower | yes | 90 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 1.44 | 1.84 | 3.30 | 4140 | 0 | positional binary — no field names | fastest | yes | 87 |
| mojo-protobuf | 0.7.0 | 2.92 | 3.93 | 6.79 | 4128 | 0 | Protocol Buffers | slower | yes | 91 |
| mojo-flatbuffers | 0.4.0 | 5.84 | 3.79 | 9.73 | 4192 | 0 | FlatBuffers | slower | yes | 93 |
| mojo-avro | 0.4.0 | 3.14 | 7.25 | 10.4 | 4126 | 0 | Avro | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 8.38 | 10.1 | 18.5 | 4663 | 0 | CBOR | slower | yes | 94 |
| mojo-json | 0.5.0 | 15.6 | 20.7 | 36.3 | 6621 | 0 | JSON — mojo-json | slower | yes | 88 |
| EmberJson | 0.3.4 | 33.2 | 16.3 | 49.9 | 9363 | 0 | JSON — EmberJson | slower | yes | 88 |
| ehsanmok-json | 0.4.0 | 79.7 | 63.9 | 145 | 9363 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 270 | 529 | 809 | 9874 | 0 | TOML | slower | yes | 97 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `gld-kiln`, `mojo-avro`. Small gap: —. Time/size front: `gld-kiln`, `mojo-avro`.

**32 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: `mojo-avro`. Time/size front: `gld-kiln`, `mojo-avro`.

**128 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `mojo-avro`.

**512 numbers, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `mojo-protobuf`, `mojo-avro`.

