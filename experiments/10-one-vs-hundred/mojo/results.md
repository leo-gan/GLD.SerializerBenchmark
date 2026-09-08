# Experiment 10 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/10-one-vs-hundred/mojo/logs/mojo/2026-09-08-155411.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.36 | 0.99 | 1.35 | 290 | 0 | JSON — EmberJson | fastest | yes | 95 |
| mojo-avro | 0.4.0 | 0.23 | 1.72 | 1.95 | 138 | 0 | Avro | slower | yes | 88 |
| mojo-protobuf | 0.6.0 | 0.41 | 1.81 | 2.21 | 156 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 0.30 | 2.93 | 3.24 | 232 | 0 | CBOR | slower | yes | 96 |
| ehsanmok-json | 0.3.0 | 24.6 | 3.73 | 28.3 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 12.0 | 20.3 | 32.4 | 304 | 0 | TOML | slower | yes | 91 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 40.5 | 76.8 | 117 | 27675 | 0 | JSON — EmberJson | fastest | yes | 90 |
| mojo-avro | 0.4.0 | 26.0 | 156 | 182 | 12367 | 0 | Avro | slower | yes | 83 |
| mojo-protobuf | 0.6.0 | 42.0 | 165 | 208 | 14449 | 0 | Protocol Buffers | slower | yes | 92 |
| mojo-cbor | 0.6.0 | 26.9 | 275 | 302 | 21773 | 0 | CBOR | slower | yes | 84 |
| mojo-toml | 0.9.1 | 2124 | 2627 | 4748 | 29873 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 9883 | 343 | 10224 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 86 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.10 | 0.44 | 0.54 | 44 | 0 | Avro | fastest | yes | 97 |
| mojo-protobuf | 0.6.0 | 0.11 | 0.45 | 0.55 | 50 | 0 | Protocol Buffers | close | yes | 95 |
| EmberJson | 0.3.4 | 0.26 | 0.54 | 0.79 | 168 | 0 | JSON — EmberJson | slower | yes | 97 |
| mojo-cbor | 0.6.0 | 0.17 | 1.31 | 1.47 | 124 | 0 | CBOR | slower | yes | 99 |
| mojo-toml | 0.9.1 | 2.06 | 10.3 | 12.3 | 167 | 0 | TOML | slower | yes | 93 |
| ehsanmok-json | 0.3.0 | 10.3 | 3.29 | 13.5 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 98 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 5.15 | 32.2 | 37.5 | 4051 | 0 | Avro | fastest | yes | 94 |
| mojo-protobuf | 0.6.0 | 8.16 | 34.4 | 42.7 | 4841 | 0 | Protocol Buffers | slower | yes | 90 |
| EmberJson | 0.3.4 | 19.5 | 32.9 | 52.6 | 16556 | 0 | JSON — EmberJson | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 10.1 | 118 | 128 | 12037 | 0 | CBOR | slower | yes | 89 |
| mojo-toml | 0.9.1 | 500 | 1066 | 1567 | 17554 | 0 | TOML | slower | yes | 94 |
| ehsanmok-json | 0.3.0 | 3951 | 317 | 4270 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

