# Experiment 9 results — mojo

**Date:** 2026-11-12
**Raw file:** `experiments/02-compression-size/mojo/logs/mojo/2026-11-12-101051.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.30 | 0.74 | 1.05 | 57 | 0 | positional binary — no field names | fastest | yes | 88 |
| mojo-avro | 0.4.0 | 0.45 | 0.75 | 1.20 | 44 | 0 | Avro | close | yes | 94 |
| mojo-protobuf | 0.7.0 | 0.53 | 0.79 | 1.36 | 50 | 0 | Protocol Buffers | close | yes | 96 |
| mojo-json | 0.5.0 | 0.66 | 1.47 | 2.15 | 164 | 0 | JSON — mojo-json | slower | yes | 92 |
| mojo-flatbuffers | 0.4.0 | 1.58 | 0.90 | 2.50 | 104 | 0 | FlatBuffers | slower | yes | 91 |
| mojo-cbor | 0.8.0 | 0.83 | 1.77 | 2.66 | 124 | 0 | CBOR | slower | yes | 96 |
| EmberJson | 0.3.4 | 2.57 | 2.28 | 4.90 | 168 | 0 | JSON — EmberJson | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 1.31 | 5.19 | 6.46 | 168 | 0 | JSON — ehsanmok/json | slower | yes | 94 |
| mojo-toml | 0.9.1 | 4.19 | 16.8 | 20.5 | 167 | 0 | TOML | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.70 | 1.40 | 2.14 | 436 | 0 | positional binary — no field names | fastest | yes | 95 |
| mojo-json | 0.5.0 | 1.25 | 3.14 | 4.45 | 411 | 0 | JSON — mojo-json | slower | yes | 94 |
| mojo-protobuf | 0.7.0 | 1.28 | 3.25 | 4.53 | 368 | 0 | Protocol Buffers | slower | yes | 89 |
| mojo-cbor | 0.8.0 | 1.37 | 3.50 | 4.80 | 345 | 0 | CBOR | slower | yes | 92 |
| mojo-avro | 0.4.0 | 1.06 | 4.71 | 5.83 | 338 | 0 | Avro | slower | yes | 93 |
| EmberJson | 0.3.4 | 3.27 | 2.68 | 5.95 | 411 | 0 | JSON — EmberJson | slower | yes | 97 |
| mojo-flatbuffers | 0.4.0 | 4.07 | 3.23 | 7.28 | 660 | 0 | FlatBuffers | slower | yes | 95 |
| ehsanmok-json | 0.4.0 | 2.03 | 7.38 | 9.52 | 411 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 16.4 | 27.1 | 43.8 | 441 | 0 | TOML | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| gld-kiln | 0.2.0 | 0.77 | 1.07 | 1.90 | 1073 | 0 | positional binary — no field names | fastest | yes | 95 |
| mojo-protobuf | 0.7.0 | 1.58 | 2.39 | 3.96 | 1061 | 0 | Protocol Buffers | slower | yes | 93 |
| mojo-avro | 0.4.0 | 1.19 | 2.78 | 4.06 | 1059 | 0 | Avro | slower | yes | 93 |
| mojo-flatbuffers | 0.4.0 | 3.14 | 2.29 | 5.39 | 1128 | 0 | FlatBuffers | slower | yes | 97 |
| mojo-cbor | 0.8.0 | 2.60 | 4.35 | 6.96 | 1211 | 0 | CBOR | slower | yes | 94 |
| mojo-json | 0.5.0 | 4.80 | 6.82 | 11.7 | 1716 | 0 | JSON — mojo-json | slower | yes | 95 |
| EmberJson | 0.3.4 | 10.7 | 6.00 | 16.6 | 2407 | 0 | JSON — EmberJson | slower | yes | 94 |
| ehsanmok-json | 0.4.0 | 20.3 | 20.9 | 41.7 | 2407 | 0 | JSON — ehsanmok/json | slower | yes | 96 |
| mojo-toml | 0.9.1 | 68.2 | 141 | 210 | 2534 | 0 | TOML | slower | yes | 94 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: `mojo-avro`, `mojo-protobuf`. Time/size front: `gld-kiln`, `mojo-avro`.

**sample E (words), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `mojo-json`, `mojo-protobuf`, `mojo-cbor`, `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `gld-kiln`. Small gap: —. Time/size front: `gld-kiln`, `mojo-protobuf`, `mojo-avro`.

