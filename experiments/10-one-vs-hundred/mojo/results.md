# Experiment 10 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/10-one-vs-hundred/mojo/logs/mojo/2026-09-09-132149.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.32 | 0.96 | 1.28 | 290 | 0 | JSON — EmberJson | fastest | yes | 93 |
| mojo-avro | 0.4.0 | 0.22 | 1.65 | 1.88 | 138 | 0 | Avro | slower | yes | 96 |
| mojo-protobuf | 0.6.0 | 0.39 | 1.75 | 2.14 | 156 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-json | 0.2.0 | 0.66 | 2.41 | 3.08 | 290 | 0 | JSON — mojo-json | slower | yes | 93 |
| mojo-cbor | 0.6.0 | 0.29 | 2.82 | 3.11 | 232 | 0 | CBOR | slower | yes | 83 |
| ehsanmok-json | 0.3.0 | 24.0 | 3.71 | 27.7 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 11.4 | 19.7 | 31.1 | 304 | 0 | TOML | slower | yes | 89 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 37.5 | 75.7 | 113 | 27675 | 0 | JSON — EmberJson | fastest | yes | 85 |
| mojo-avro | 0.4.0 | 25.7 | 152 | 178 | 12367 | 0 | Avro | slower | yes | 92 |
| mojo-protobuf | 0.6.0 | 39.6 | 160 | 200 | 14449 | 0 | Protocol Buffers | slower | yes | 88 |
| mojo-json | 0.2.0 | 39.8 | 222 | 262 | 27675 | 0 | JSON — mojo-json | slower | yes | 92 |
| mojo-cbor | 0.6.0 | 26.4 | 265 | 293 | 21773 | 0 | CBOR | slower | yes | 92 |
| mojo-toml | 0.9.1 | 2070 | 2574 | 4645 | 29873 | 0 | TOML | slower | yes | 89 |
| ehsanmok-json | 0.3.0 | 9557 | 345 | 9897 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.11 | 0.44 | 0.55 | 44 | 0 | Avro | fastest | yes | 93 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.45 | 0.56 | 50 | 0 | Protocol Buffers | similar | yes | 92 |
| EmberJson | 0.3.4 | 0.24 | 0.54 | 0.78 | 168 | 0 | JSON — EmberJson | slower | yes | 95 |
| mojo-cbor | 0.6.0 | 0.17 | 1.33 | 1.50 | 124 | 0 | CBOR | slower | yes | 97 |
| mojo-json | 0.2.0 | 0.76 | 1.18 | 1.94 | 168 | 0 | JSON — mojo-json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 2.07 | 10.4 | 12.4 | 167 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 10.6 | 3.27 | 13.9 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.26 | 30.8 | 36.0 | 4051 | 0 | Avro | fastest | yes | 88 |
| mojo-protobuf | 0.6.0 | 7.54 | 32.9 | 40.4 | 4841 | 0 | Protocol Buffers | slower | yes | 89 |
| EmberJson | 0.3.4 | 18.2 | 30.9 | 49.0 | 16556 | 0 | JSON — EmberJson | slower | yes | 92 |
| mojo-cbor | 0.6.0 | 9.63 | 114 | 123 | 12037 | 0 | CBOR | slower | yes | 87 |
| mojo-json | 0.2.0 | 70.2 | 102 | 172 | 16556 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 471 | 1017 | 1488 | 17554 | 0 | TOML | slower | yes | 89 |
| ehsanmok-json | 0.3.0 | 3784 | 298 | 4080 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 96 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`, `mojo-protobuf`. Small gap: —. Time/size front: `mojo-avro`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

