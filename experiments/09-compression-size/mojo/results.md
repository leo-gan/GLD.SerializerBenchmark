# Experiment 9 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/mojo/logs/mojo/2026-10-11-150601.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 0.75 | 1.19 | 1.97 | 50 | 0 | Protocol Buffers | fastest | yes | 96 |
| mojo-avro | 0.4.0 | 0.77 | 1.81 | 2.54 | 44 | 0 | Avro | close | yes | 97 |
| mojo-json | 0.5.0 | 1.21 | 2.28 | 3.50 | 164 | 0 | JSON — mojo-json | slower | yes | 96 |
| mojo-flatbuffers | 0.4.0 | 2.43 | 1.15 | 3.70 | 104 | 0 | FlatBuffers | slower | yes | 96 |
| mojo-cbor | 0.8.0 | 1.19 | 3.19 | 4.38 | 124 | 0 | CBOR | slower | yes | 98 |
| EmberJson | 0.3.4 | 3.71 | 3.92 | 7.94 | 168 | 0 | JSON — EmberJson | slower | yes | 97 |
| ehsanmok-json | 0.4.0 | 2.00 | 8.74 | 10.7 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 97 |
| mojo-toml | 0.9.1 | 6.84 | 26.0 | 33.0 | 167 | 0 | TOML | slower | yes | 96 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-json | 0.5.0 | 0.88 | 2.49 | 3.37 | 411 | 0 | JSON — mojo-json | fastest | yes | 90 |
| mojo-protobuf | 0.7.0 | 1.07 | 2.73 | 3.80 | 368 | 0 | Protocol Buffers | slower | yes | 94 |
| mojo-cbor | 0.8.0 | 1.03 | 3.47 | 4.48 | 345 | 0 | CBOR | slower | yes | 92 |
| EmberJson | 0.3.4 | 2.58 | 2.46 | 5.02 | 411 | 0 | JSON — EmberJson | slower | yes | 94 |
| mojo-avro | 0.4.0 | 0.82 | 4.45 | 5.22 | 338 | 0 | Avro | slower | yes | 89 |
| mojo-flatbuffers | 0.4.0 | 3.22 | 2.65 | 5.86 | 660 | 0 | FlatBuffers | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 1.55 | 5.80 | 7.40 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 13.8 | 23.3 | 37.6 | 441 | 0 | TOML | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 1.53 | 2.35 | 3.85 | 1061 | 0 | Protocol Buffers | fastest | yes | 95 |
| mojo-avro | 0.4.0 | 1.08 | 3.34 | 4.42 | 1059 | 0 | Avro | slower | yes | 93 |
| mojo-flatbuffers | 0.4.0 | 2.78 | 2.20 | 4.98 | 1128 | 0 | FlatBuffers | slower | yes | 94 |
| mojo-cbor | 0.8.0 | 2.24 | 4.16 | 6.39 | 1211 | 0 | CBOR | slower | yes | 94 |
| mojo-json | 0.5.0 | 4.22 | 6.21 | 10.4 | 1716 | 0 | JSON — mojo-json | slower | yes | 94 |
| EmberJson | 0.3.4 | 9.65 | 6.17 | 15.8 | 2407 | 0 | JSON — EmberJson | slower | yes | 91 |
| ehsanmok-json | 0.4.0 | 19.4 | 19.0 | 38.3 | 2407 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 61.4 | 135 | 198 | 2534 | 0 | TOML | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: `mojo-avro`. Time/size front: `mojo-protobuf`, `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `mojo-json`. Small gap: —. Time/size front: `mojo-json`, `mojo-protobuf`, `mojo-cbor`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

