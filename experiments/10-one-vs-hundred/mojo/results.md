# Experiment 10 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/10-one-vs-hundred/mojo/logs/mojo/2026-09-12-132720.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 0.35 | 0.94 | 1.29 | 290 | 0 | JSON — EmberJson | fastest | yes | 94 |
| mojo-json | 0.3.0 | 0.38 | 0.98 | 1.36 | 290 | 0 | JSON — mojo-json | slower | yes | 89 |
| mojo-avro | 0.4.0 | 0.23 | 1.63 | 1.86 | 138 | 0 | Avro | slower | yes | 96 |
| mojo-protobuf | 0.6.0 | 0.40 | 1.72 | 2.12 | 156 | 0 | Protocol Buffers | slower | yes | 90 |
| mojo-cbor | 0.6.0 | 0.30 | 2.76 | 3.06 | 232 | 0 | CBOR | slower | yes | 91 |
| ehsanmok-json | 0.3.1 | 0.46 | 3.79 | 4.25 | 290 | 0 | JSON — ehsanmok/json | slower | yes | 91 |
| mojo-toml | 0.9.1 | 11.3 | 19.1 | 30.4 | 304 | 0 | TOML | slower | yes | 87 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| EmberJson | 0.3.4 | 38.7 | 69.5 | 108 | 27675 | 0 | JSON — EmberJson | fastest | yes | 93 |
| mojo-json | 0.3.0 | 33.4 | 86.6 | 120 | 27675 | 0 | JSON — mojo-json | slower | yes | 91 |
| mojo-avro | 0.4.0 | 24.4 | 146 | 171 | 12367 | 0 | Avro | slower | yes | 89 |
| mojo-protobuf | 0.6.0 | 38.3 | 156 | 194 | 14449 | 0 | Protocol Buffers | slower | yes | 89 |
| mojo-cbor | 0.6.0 | 24.9 | 259 | 284 | 21773 | 0 | CBOR | slower | yes | 90 |
| ehsanmok-json | 0.3.1 | 38.6 | 348 | 386 | 27675 | 0 | JSON — ehsanmok/json | slower | yes | 92 |
| mojo-toml | 0.9.1 | 1941 | 2455 | 4394 | 29873 | 0 | TOML | slower | yes | 94 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.09 | 0.43 | 0.52 | 44 | 0 | Avro | fastest | yes | 96 |
| mojo-protobuf | 0.6.0 | 0.10 | 0.43 | 0.53 | 50 | 0 | Protocol Buffers | close | yes | 92 |
| mojo-json | 0.3.0 | 0.23 | 0.35 | 0.58 | 164 | 0 | JSON — mojo-json | slower | yes | 96 |
| EmberJson | 0.3.4 | 0.26 | 0.54 | 0.80 | 168 | 0 | JSON — EmberJson | slower | yes | 94 |
| mojo-cbor | 0.6.0 | 0.17 | 1.29 | 1.46 | 124 | 0 | CBOR | slower | yes | 95 |
| ehsanmok-json | 0.3.1 | 0.54 | 3.33 | 3.86 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 2.01 | 10.1 | 12.1 | 167 | 0 | TOML | slower | yes | 95 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 4.90 | 30.2 | 35.1 | 4051 | 0 | Avro | fastest | yes | 89 |
| mojo-json | 0.3.0 | 13.5 | 24.9 | 38.4 | 16114 | 0 | JSON — mojo-json | slower | yes | 85 |
| mojo-protobuf | 0.6.0 | 7.65 | 32.4 | 40.0 | 4841 | 0 | Protocol Buffers | slower | yes | 84 |
| EmberJson | 0.3.4 | 18.2 | 30.2 | 48.5 | 16556 | 0 | JSON — EmberJson | slower | yes | 88 |
| mojo-cbor | 0.6.0 | 9.79 | 113 | 122 | 12037 | 0 | CBOR | slower | yes | 82 |
| ehsanmok-json | 0.3.1 | 42.0 | 280 | 322 | 16556 | 0 | JSON — ehsanmok/json | slower | yes | 93 |
| mojo-toml | 0.9.1 | 462 | 999 | 1461 | 17554 | 0 | TOML | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample D (event), N = 100, memory** — not clearly slower: `EmberJson`. Small gap: —. Time/size front: `EmberJson`, `mojo-avro`.

**sample B (flat), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

**sample B (flat), N = 100, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

