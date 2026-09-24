# Experiment 4 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/04-sensor-list-size/mojo/logs/mojo/2026-09-23-181459.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.15 | 0.88 | 1.03 | 103 | 0 | Avro | fastest | yes | 84 |
| mojo-json | 0.3.0 | 0.50 | 0.61 | 1.12 | 186 | 0 | JSON — mojo-json | slower | yes | 88 |
| mojo-cbor | 0.6.0 | 0.29 | 1.23 | 1.53 | 135 | 0 | CBOR | slower | yes | 91 |
| EmberJson | 0.3.4 | 0.58 | 0.96 | 1.55 | 229 | 0 | JSON — EmberJson | slower | yes | 88 |
| mojo-protobuf | 0.6.0 | 0.43 | 1.16 | 1.60 | 105 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-flatbuffers | 0.2.0 | 1.29 | 0.73 | 2.04 | 176 | 0 | FlatBuffers | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 2.25 | 2.88 | 5.12 | 229 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 6.19 | 14.6 | 20.8 | 236 | 0 | TOML | slower | yes | 88 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.28 | 1.28 | 1.57 | 295 | 0 | Avro | fastest | yes | 91 |
| mojo-cbor | 0.6.0 | 0.66 | 1.82 | 2.48 | 352 | 0 | CBOR | slower | yes | 94 |
| mojo-flatbuffers | 0.2.0 | 1.50 | 0.98 | 2.49 | 368 | 0 | FlatBuffers | slower | yes | 92 |
| mojo-protobuf | 0.6.0 | 0.66 | 1.84 | 2.51 | 298 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-json | 0.3.0 | 1.29 | 1.25 | 2.55 | 491 | 0 | JSON — mojo-json | slower | yes | 95 |
| EmberJson | 0.3.4 | 1.69 | 1.69 | 3.38 | 668 | 0 | JSON — EmberJson | slower | yes | 88 |
| ehsanmok-json | 0.4.0 | 5.44 | 6.15 | 11.6 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 95 |
| mojo-toml | 0.9.1 | 16.8 | 37.2 | 54.2 | 699 | 0 | TOML | slower | yes | 91 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.74 | 2.52 | 3.26 | 1071 | 0 | Avro | fastest | yes | 91 |
| mojo-flatbuffers | 0.2.0 | 1.84 | 1.45 | 3.29 | 1136 | 0 | FlatBuffers | close | yes | 86 |
| mojo-protobuf | 0.6.0 | 1.25 | 3.79 | 5.05 | 1073 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 2.04 | 3.63 | 5.67 | 1223 | 0 | CBOR | slower | yes | 95 |
| mojo-json | 0.3.0 | 4.41 | 3.55 | 7.95 | 1727 | 0 | JSON — mojo-json | slower | yes | 92 |
| EmberJson | 0.3.4 | 5.86 | 4.38 | 10.3 | 2419 | 0 | JSON — EmberJson | slower | yes | 89 |
| ehsanmok-json | 0.4.0 | 17.0 | 18.4 | 35.4 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 85 |
| mojo-toml | 0.9.1 | 58.0 | 123 | 181 | 2546 | 0 | TOML | slower | yes | 92 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-flatbuffers | 0.2.0 | 3.27 | 2.49 | 5.85 | 4200 | 0 | FlatBuffers | fastest | yes | 93 |
| mojo-avro | 0.4.0 | 2.64 | 6.76 | 9.37 | 4135 | 0 | Avro | slower | yes | 92 |
| mojo-protobuf | 0.6.0 | 3.28 | 10.3 | 13.6 | 4137 | 0 | Protocol Buffers | slower | yes | 91 |
| mojo-cbor | 0.6.0 | 7.47 | 9.90 | 17.4 | 4672 | 0 | CBOR | slower | yes | 90 |
| mojo-json | 0.3.0 | 16.7 | 12.3 | 29.1 | 6627 | 0 | JSON — mojo-json | slower | yes | 88 |
| EmberJson | 0.3.4 | 24.1 | 15.2 | 39.5 | 9368 | 0 | JSON — EmberJson | slower | yes | 85 |
| ehsanmok-json | 0.4.0 | 64.1 | 64.7 | 130 | 9368 | 0 | JSON — ehsanmok/json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 219 | 463 | 681 | 9879 | 0 | TOML | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**32 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**128 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-flatbuffers`. Time/size front: `mojo-avro`.

**512 numbers, memory** — not clearly slower: `mojo-flatbuffers`. Small gap: —. Time/size front: `mojo-flatbuffers`, `mojo-avro`.

