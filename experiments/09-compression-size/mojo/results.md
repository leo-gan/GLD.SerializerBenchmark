# Experiment 9 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/09-compression-size/mojo/logs/mojo/2026-09-08-155405.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.10 | 0.46 | 0.56 | 44 | 0 | Avro | fastest | yes | 91 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.47 | 0.58 | 50 | 0 | Protocol Buffers | slower | yes | 82 |
| EmberJson | 0.3.4 | 0.26 | 0.56 | 0.82 | 168 | 0 | JSON — EmberJson | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.17 | 1.37 | 1.55 | 124 | 0 | CBOR | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2.15 | 11.0 | 13.2 | 167 | 0 | TOML | slower | yes | 93 |
| ehsanmok-json | 0.3.0 | 10.8 | 3.44 | 14.2 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.65 | 1.09 | 1.74 | 411 | 0 | JSON — EmberJson | fastest | yes | 94 |
| mojo-avro | 0.4.0 | 0.51 | 3.92 | 4.43 | 338 | 0 | Avro | slower | yes | 78 |
| mojo-cbor | 0.6.0 | 0.33 | 4.22 | 4.55 | 345 | 0 | CBOR | slower | yes | 84 |
| mojo-protobuf | 0.6.0 | 0.83 | 4.18 | 5.02 | 368 | 0 | Protocol Buffers | slower | yes | 71 |
| mojo-toml | 0.9.1 | 12.4 | 18.7 | 31.0 | 441 | 0 | TOML | slower | yes | 70 |
| ehsanmok-json | 0.3.0 | 52.4 | 3.84 | 56.2 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 77 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.74 | 2.34 | 3.08 | 1071 | 0 | Avro | fastest | yes | 86 |
| mojo-protobuf | 0.6.0 | 1.21 | 3.49 | 4.71 | 1073 | 0 | Protocol Buffers | slower | yes | 85 |
| mojo-cbor | 0.6.0 | 1.90 | 3.39 | 5.30 | 1223 | 0 | CBOR | slower | yes | 89 |
| EmberJson | 0.3.4 | 5.35 | 3.92 | 9.28 | 2419 | 0 | JSON — EmberJson | slower | yes | 86 |
| mojo-toml | 0.9.1 | 55.7 | 113 | 169 | 2546 | 0 | TOML | slower | yes | 93 |
| ehsanmok-json | 0.3.0 | 456 | 44.7 | 500 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

