# Experiment 4 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/04-sensor-list-size/mojo/logs/mojo/2026-10-11-150035.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.59 | 1.88 | 2.46 | 92 | 0 | Avro | fastest | yes | 91 |
| mojo-protobuf | 0.7.0 | 1.07 | 1.62 | 2.65 | 94 | 0 | Protocol Buffers | similar | yes | 91 |
| mojo-cbor | 0.8.0 | 0.84 | 2.21 | 3.10 | 124 | 0 | CBOR | slower | yes | 92 |
| mojo-json | 0.5.0 | 1.31 | 2.17 | 3.40 | 177 | 0 | JSON — mojo-json | slower | yes | 95 |
| mojo-flatbuffers | 0.4.0 | 2.44 | 1.45 | 3.90 | 160 | 0 | FlatBuffers | slower | yes | 90 |
| EmberJson | 0.3.4 | 3.01 | 2.95 | 6.01 | 220 | 0 | JSON — EmberJson | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 5.38 | 6.66 | 12.3 | 220 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 10.3 | 23.0 | 32.7 | 227 | 0 | TOML | slower | yes | 87 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.65 | 1.91 | 2.56 | 288 | 0 | Avro | fastest | yes | 88 |
| mojo-protobuf | 0.7.0 | 1.05 | 1.56 | 2.57 | 291 | 0 | Protocol Buffers | similar | yes | 87 |
| mojo-cbor | 0.8.0 | 1.04 | 2.45 | 3.47 | 345 | 0 | CBOR | slower | yes | 90 |
| mojo-flatbuffers | 0.4.0 | 2.23 | 1.51 | 3.69 | 352 | 0 | FlatBuffers | slower | yes | 89 |
| mojo-json | 0.5.0 | 1.70 | 2.71 | 4.44 | 486 | 0 | JSON — mojo-json | slower | yes | 90 |
| EmberJson | 0.3.4 | 4.31 | 3.42 | 7.62 | 663 | 0 | JSON — EmberJson | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 6.96 | 8.28 | 15.1 | 663 | 0 | JSON — ehsanmok/json | slower | yes | 87 |
| mojo-toml | 0.9.1 | 19.4 | 43.9 | 63.8 | 694 | 0 | TOML | slower | yes | 91 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 1.33 | 1.94 | 3.29 | 1061 | 0 | Protocol Buffers | fastest | yes | 90 |
| mojo-avro | 0.4.0 | 1.04 | 3.00 | 4.02 | 1059 | 0 | Avro | slower | yes | 94 |
| mojo-flatbuffers | 0.4.0 | 2.46 | 1.89 | 4.34 | 1128 | 0 | FlatBuffers | slower | yes | 94 |
| mojo-cbor | 0.8.0 | 2.10 | 3.70 | 5.82 | 1211 | 0 | CBOR | slower | yes | 92 |
| mojo-json | 0.5.0 | 4.11 | 5.85 | 9.89 | 1716 | 0 | JSON — mojo-json | slower | yes | 95 |
| EmberJson | 0.3.4 | 9.26 | 5.67 | 14.9 | 2407 | 0 | JSON — EmberJson | slower | yes | 93 |
| ehsanmok-json | 0.4.0 | 17.1 | 17.6 | 34.5 | 2407 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 57.8 | 127 | 185 | 2534 | 0 | TOML | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 2.19 | 2.97 | 5.17 | 4128 | 0 | Protocol Buffers | fastest | yes | 97 |
| mojo-flatbuffers | 0.4.0 | 3.50 | 2.82 | 6.25 | 4192 | 0 | FlatBuffers | slower | yes | 96 |
| mojo-avro | 0.4.0 | 2.57 | 6.87 | 9.49 | 4126 | 0 | Avro | slower | yes | 93 |
| mojo-cbor | 0.8.0 | 6.57 | 9.00 | 15.5 | 4663 | 0 | CBOR | slower | yes | 94 |
| mojo-json | 0.5.0 | 13.7 | 17.7 | 31.4 | 6621 | 0 | JSON — mojo-json | slower | yes | 96 |
| EmberJson | 0.3.4 | 29.2 | 14.7 | 44.0 | 9363 | 0 | JSON — EmberJson | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 60.3 | 56.5 | 117 | 9363 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 216 | 467 | 686 | 9874 | 0 | TOML | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**32 numbers, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**128 numbers, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

**512 numbers, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

