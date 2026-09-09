# Experiment 9 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/09-compression-size/mojo/logs/mojo/2026-09-09-132143.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.11 | 0.46 | 0.58 | 44 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.6.0 | 0.11 | 0.49 | 0.60 | 50 | 0 | Protocol Buffers | slower | yes | 93 |
| EmberJson | 0.3.4 | 0.25 | 0.58 | 0.83 | 168 | 0 | JSON — EmberJson | slower | yes | 95 |
| mojo-cbor | 0.6.0 | 0.18 | 1.41 | 1.59 | 124 | 0 | CBOR | slower | yes | 89 |
| mojo-json | 0.2.0 | 0.82 | 1.25 | 2.08 | 168 | 0 | JSON — mojo-json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 2.23 | 11.1 | 13.3 | 167 | 0 | TOML | slower | yes | 92 |
| ehsanmok-json | 0.3.0 | 11.2 | 3.54 | 14.7 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.59 | 1.22 | 1.81 | 411 | 0 | JSON — EmberJson | fastest | yes | 84 |
| mojo-avro | 0.4.0 | 0.49 | 4.14 | 4.63 | 338 | 0 | Avro | slower | yes | 73 |
| mojo-cbor | 0.6.0 | 0.37 | 4.44 | 4.81 | 345 | 0 | CBOR | slower | yes | 80 |
| mojo-protobuf | 0.6.0 | 0.87 | 4.34 | 5.21 | 368 | 0 | Protocol Buffers | slower | yes | 69 |
| mojo-json | 0.2.0 | 2.13 | 5.80 | 7.93 | 411 | 0 | JSON — mojo-json | slower | yes | 79 |
| mojo-toml | 0.9.1 | 13.1 | 19.5 | 32.8 | 441 | 0 | TOML | slower | yes | 76 |
| ehsanmok-json | 0.3.0 | 55.4 | 4.16 | 59.6 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.80 | 2.62 | 3.43 | 1071 | 0 | Avro | fastest | yes | 87 |
| mojo-protobuf | 0.6.0 | 1.23 | 3.75 | 4.98 | 1073 | 0 | Protocol Buffers | slower | yes | 85 |
| mojo-cbor | 0.6.0 | 1.98 | 3.68 | 5.67 | 1223 | 0 | CBOR | slower | yes | 84 |
| EmberJson | 0.3.4 | 5.91 | 4.37 | 10.3 | 2419 | 0 | JSON — EmberJson | slower | yes | 85 |
| mojo-json | 0.2.0 | 99.0 | 56.7 | 156 | 2419 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 59.4 | 119 | 178 | 2546 | 0 | TOML | slower | yes | 90 |
| ehsanmok-json | 0.3.0 | 486 | 45.1 | 531 | 2419 | 0 | JSON — ehsanmok/json | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

