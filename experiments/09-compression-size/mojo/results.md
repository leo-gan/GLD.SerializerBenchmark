# Experiment 9 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/09-compression-size/mojo/logs/mojo/2026-09-12-132712.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.6.0 | 0.10 | 0.44 | 0.54 | 50 | 0 | Protocol Buffers | fastest | yes | 92 |
| mojo-avro | 0.4.0 | 0.10 | 0.45 | 0.55 | 44 | 0 | Avro | similar | yes | 88 |
| mojo-json | 0.3.0 | 0.23 | 0.37 | 0.60 | 164 | 0 | JSON — mojo-json | slower | yes | 88 |
| EmberJson | 0.3.4 | 0.25 | 0.56 | 0.82 | 168 | 0 | JSON — EmberJson | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.18 | 1.34 | 1.51 | 124 | 0 | CBOR | slower | yes | 91 |
| ehsanmok-json | 0.3.1 | 0.54 | 3.50 | 4.05 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 89 |
| mojo-toml | 0.9.1 | 2.13 | 10.7 | 12.8 | 167 | 0 | TOML | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.59 | 1.17 | 1.76 | 411 | 0 | JSON — EmberJson | fastest | yes | 74 |
| mojo-json | 0.3.0 | 0.66 | 2.11 | 2.78 | 411 | 0 | JSON — mojo-json | slower | yes | 83 |
| mojo-avro | 0.4.0 | 0.51 | 3.91 | 4.43 | 338 | 0 | Avro | slower | yes | 74 |
| mojo-cbor | 0.6.0 | 0.33 | 4.22 | 4.54 | 345 | 0 | CBOR | slower | yes | 72 |
| mojo-protobuf | 0.6.0 | 0.78 | 4.16 | 4.93 | 368 | 0 | Protocol Buffers | slower | yes | 70 |
| ehsanmok-json | 0.3.1 | 0.85 | 4.38 | 5.24 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 85 |
| mojo-toml | 0.9.1 | 12.0 | 18.7 | 30.8 | 441 | 0 | TOML | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.70 | 2.59 | 3.28 | 1071 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 1.27 | 3.72 | 4.99 | 1073 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-cbor | 0.6.0 | 2.32 | 3.24 | 5.57 | 1223 | 0 | CBOR | slower | yes | 92 |
| mojo-json | 0.3.0 | 4.13 | 3.57 | 7.68 | 1727 | 0 | JSON — mojo-json | slower | yes | 94 |
| EmberJson | 0.3.4 | 5.60 | 4.16 | 9.76 | 2419 | 0 | JSON — EmberJson | slower | yes | 88 |
| ehsanmok-json | 0.3.1 | 46.5 | 47.4 | 93.8 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 56.8 | 116 | 173 | 2546 | 0 | TOML | slower | yes | 95 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-protobuf`, `mojo-avro`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

