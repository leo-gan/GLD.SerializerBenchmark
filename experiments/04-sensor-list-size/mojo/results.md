# Experiment 4 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/04-sensor-list-size/mojo/logs/mojo/2026-09-12-132629.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.14 | 0.85 | 0.99 | 103 | 0 | Avro | fastest | yes | 81 |
| mojo-json | 0.3.0 | 0.48 | 0.60 | 1.08 | 186 | 0 | JSON — mojo-json | slower | yes | 80 |
| mojo-cbor | 0.6.0 | 0.30 | 1.21 | 1.51 | 135 | 0 | CBOR | slower | yes | 77 |
| EmberJson | 0.3.4 | 0.56 | 0.94 | 1.51 | 229 | 0 | JSON — EmberJson | slower | yes | 80 |
| mojo-protobuf | 0.6.0 | 0.42 | 1.14 | 1.57 | 105 | 0 | Protocol Buffers | slower | yes | 84 |
| ehsanmok-json | 0.3.1 | 4.00 | 4.56 | 8.56 | 229 | 0 | JSON — ehsanmok/json | slower | yes | 86 |
| mojo-toml | 0.9.1 | 6.09 | 14.0 | 20.1 | 236 | 0 | TOML | slower | yes | 85 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.26 | 1.26 | 1.53 | 295 | 0 | Avro | fastest | yes | 85 |
| mojo-cbor | 0.6.0 | 0.65 | 1.76 | 2.41 | 352 | 0 | CBOR | slower | yes | 81 |
| mojo-json | 0.3.0 | 1.26 | 1.20 | 2.46 | 491 | 0 | JSON — mojo-json | slower | yes | 82 |
| mojo-protobuf | 0.6.0 | 0.66 | 1.88 | 2.54 | 298 | 0 | Protocol Buffers | slower | yes | 85 |
| EmberJson | 0.3.4 | 1.65 | 1.65 | 3.30 | 668 | 0 | JSON — EmberJson | slower | yes | 87 |
| ehsanmok-json | 0.3.1 | 12.9 | 13.7 | 26.6 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 16.6 | 35.6 | 52.1 | 699 | 0 | TOML | slower | yes | 87 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.72 | 2.61 | 3.33 | 1071 | 0 | Avro | fastest | yes | 81 |
| mojo-protobuf | 0.6.0 | 1.30 | 4.13 | 5.42 | 1073 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 1.99 | 3.57 | 5.57 | 1223 | 0 | CBOR | slower | yes | 90 |
| mojo-json | 0.3.0 | 4.36 | 3.52 | 7.88 | 1727 | 0 | JSON — mojo-json | slower | yes | 93 |
| EmberJson | 0.3.4 | 5.72 | 4.26 | 9.99 | 2419 | 0 | JSON — EmberJson | slower | yes | 88 |
| ehsanmok-json | 0.3.1 | 47.9 | 48.6 | 96.5 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 90 |
| mojo-toml | 0.9.1 | 58.2 | 119 | 177 | 2546 | 0 | TOML | slower | yes | 96 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 2.51 | 7.39 | 9.92 | 4135 | 0 | Avro | fastest | yes | 86 |
| mojo-protobuf | 0.6.0 | 3.51 | 11.8 | 15.3 | 4137 | 0 | Protocol Buffers | slower | yes | 83 |
| mojo-cbor | 0.6.0 | 7.34 | 9.93 | 17.3 | 4672 | 0 | CBOR | slower | yes | 76 |
| mojo-json | 0.3.0 | 16.6 | 12.2 | 28.8 | 6627 | 0 | JSON — mojo-json | slower | yes | 80 |
| EmberJson | 0.3.4 | 23.9 | 15.0 | 39.0 | 9368 | 0 | JSON — EmberJson | slower | yes | 79 |
| ehsanmok-json | 0.3.1 | 193 | 186 | 379 | 9368 | 0 | JSON — ehsanmok/json | slower | yes | 83 |
| mojo-toml | 0.9.1 | 225 | 449 | 674 | 9879 | 0 | TOML | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**32 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**128 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**512 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

