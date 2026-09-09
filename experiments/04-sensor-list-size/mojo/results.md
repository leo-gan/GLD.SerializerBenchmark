# Experiment 4 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/04-sensor-list-size/mojo/logs/mojo/2026-09-09-132110.csv`
**Language:** mojo
**Sample:** one sensor record (`telemetry`), list lengths 8, 32, 128, 512
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 8 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.14 | 0.88 | 1.02 | 103 | 0 | Avro | fastest | yes | 84 |
| mojo-cbor | 0.6.0 | 0.29 | 1.21 | 1.50 | 135 | 0 | CBOR | slower | yes | 92 |
| EmberJson | 0.3.4 | 0.56 | 0.94 | 1.50 | 229 | 0 | JSON — EmberJson | slower | yes | 84 |
| mojo-protobuf | 0.6.0 | 0.42 | 1.16 | 1.57 | 105 | 0 | Protocol Buffers | slower | yes | 86 |
| mojo-json | 0.2.0 | 4.85 | 4.51 | 9.35 | 229 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 6.16 | 14.2 | 20.4 | 236 | 0 | TOML | slower | yes | 87 |
| ehsanmok-json | 0.3.0 | 16.9 | 4.36 | 21.3 | 229 | 0 | JSON — ehsanmok/json | slower | yes | 91 |

## In memory — 32 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.27 | 1.27 | 1.54 | 295 | 0 | Avro | fastest | yes | 87 |
| mojo-protobuf | 0.6.0 | 0.63 | 1.75 | 2.38 | 298 | 0 | Protocol Buffers | slower | yes | 87 |
| mojo-cbor | 0.6.0 | 0.64 | 1.75 | 2.39 | 352 | 0 | CBOR | slower | yes | 90 |
| EmberJson | 0.3.4 | 1.59 | 1.63 | 3.22 | 668 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-json | 0.2.0 | 22.1 | 15.0 | 37.1 | 668 | 0 | JSON — mojo-json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 16.7 | 35.0 | 51.6 | 699 | 0 | TOML | slower | yes | 85 |
| ehsanmok-json | 0.3.0 | 63.1 | 12.6 | 75.7 | 668 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — 128 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.72 | 2.50 | 3.21 | 1071 | 0 | Avro | fastest | yes | 91 |
| mojo-protobuf | 0.6.0 | 1.24 | 3.52 | 4.75 | 1073 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 1.90 | 3.46 | 5.36 | 1223 | 0 | CBOR | slower | yes | 88 |
| EmberJson | 0.3.4 | 5.53 | 4.08 | 9.62 | 2419 | 0 | JSON — EmberJson | slower | yes | 89 |
| mojo-json | 0.2.0 | 94.1 | 54.0 | 148 | 2419 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 56.0 | 112 | 168 | 2546 | 0 | TOML | slower | yes | 91 |
| ehsanmok-json | 0.3.0 | 456 | 42.7 | 498 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 85 |

## In memory — 512 numbers in the list

Times are middle values in microseconds (µs). Lower time is better **inside this language**. Size is the first number we care about on this curve.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 2.61 | 7.06 | 9.56 | 4135 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 3.37 | 9.77 | 13.2 | 4137 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 7.07 | 9.79 | 17.1 | 4672 | 0 | CBOR | slower | yes | 92 |
| EmberJson | 0.3.4 | 22.9 | 14.6 | 37.7 | 9368 | 0 | JSON — EmberJson | slower | yes | 93 |
| mojo-json | 0.2.0 | 402 | 205 | 607 | 9368 | 0 | JSON — mojo-json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 211 | 417 | 631 | 9879 | 0 | TOML | slower | yes | 91 |
| ehsanmok-json | 0.3.0 | 6016 | 173 | 6190 | 9368 | 0 | JSON — ehsanmok/json | slower | yes | 83 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each list length. Size is the first number we care about.

**8 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**32 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**128 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**512 numbers, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

