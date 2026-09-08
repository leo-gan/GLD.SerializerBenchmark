# Experiment 4 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/04-sensor-list-size/mojo/logs/mojo/2026-09-08-155335.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.14 | 0.86 | 1.00 | 103 | 0 | Avro | fastest | yes | 97 |
| EmberJson | 0.3.4 | 0.56 | 0.90 | 1.47 | 229 | 0 | JSON — EmberJson | slower | yes | 96 |
| mojo-cbor | 0.6.0 | 0.30 | 1.20 | 1.50 | 135 | 0 | CBOR | slower | yes | 98 |
| mojo-protobuf | 0.6.0 | 0.42 | 1.14 | 1.57 | 105 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-toml | 0.9.1 | 6.10 | 14.2 | 20.3 | 236 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 16.8 | 4.43 | 21.2 | 229 | 0 | JSON — ehsanmok/json | slower | yes | 95 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.26 | 1.21 | 1.46 | 295 | 0 | Avro | fastest | yes | 86 |
| mojo-cbor | 0.6.0 | 0.63 | 1.70 | 2.33 | 352 | 0 | CBOR | slower | yes | 83 |
| mojo-protobuf | 0.6.0 | 0.65 | 1.73 | 2.37 | 298 | 0 | Protocol Buffers | slower | yes | 85 |
| EmberJson | 0.3.4 | 1.58 | 1.56 | 3.14 | 668 | 0 | JSON — EmberJson | slower | yes | 83 |
| mojo-toml | 0.9.1 | 16.3 | 35.2 | 51.7 | 699 | 0 | TOML | slower | yes | 87 |
| ehsanmok-json | 0.3.0 | 61.9 | 12.9 | 74.7 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 88 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.70 | 2.35 | 3.04 | 1071 | 0 | Avro | fastest | yes | 87 |
| mojo-protobuf | 0.6.0 | 1.23 | 3.52 | 4.75 | 1073 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 1.92 | 3.39 | 5.31 | 1223 | 0 | CBOR | slower | yes | 90 |
| EmberJson | 0.3.4 | 5.45 | 3.98 | 9.45 | 2419 | 0 | JSON — EmberJson | slower | yes | 91 |
| mojo-toml | 0.9.1 | 56.6 | 115 | 172 | 2546 | 0 | TOML | slower | yes | 95 |
| ehsanmok-json | 0.3.0 | 463 | 45.5 | 509 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 97 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 2.57 | 6.75 | 9.37 | 4135 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 3.52 | 10.0 | 13.6 | 4137 | 0 | Protocol Buffers | slower | yes | 95 |
| mojo-cbor | 0.6.0 | 7.18 | 9.42 | 16.8 | 4672 | 0 | CBOR | slower | yes | 92 |
| EmberJson | 0.3.4 | 22.4 | 14.4 | 36.8 | 9368 | 0 | JSON — EmberJson | slower | yes | 88 |
| mojo-toml | 0.9.1 | 214 | 425 | 643 | 9879 | 0 | TOML | slower | yes | 95 |
| ehsanmok-json | 0.3.0 | 5996 | 183 | 6187 | 9368 | 0 | JSON — ehsanmok/json | slower | yes | 88 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**32 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**128 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**512 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

