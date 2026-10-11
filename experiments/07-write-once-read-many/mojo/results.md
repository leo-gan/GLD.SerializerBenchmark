# Experiment 7 results — mojo

**Date:** 2026-10-11
**Raw file:** `experiments/07-write-once-read-many/mojo/logs/mojo/2026-10-11-150355.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.86 | 2.55 | 3.39 | 114 | 0 | Avro | fastest | yes | 92 |
| mojo-protobuf | 0.7.0 | 1.63 | 2.26 | 3.87 | 155 | 0 | Protocol Buffers | close | yes | 93 |
| mojo-flatbuffers | 0.4.0 | 4.54 | 1.89 | 6.38 | 408 | 0 | FlatBuffers | slower | yes | 92 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-protobuf | 0.7.0 | 2.25 | 2.96 | 5.21 | 4128 | 0 | Protocol Buffers | fastest | yes | 95 |
| mojo-flatbuffers | 0.4.0 | 3.74 | 2.76 | 6.53 | 4192 | 0 | FlatBuffers | slower | yes | 95 |
| mojo-avro | 0.4.0 | 2.66 | 8.29 | 11.0 | 4126 | 0 | Avro | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: `mojo-protobuf`. Time/size front: `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-protobuf`. Small gap: —. Time/size front: `mojo-protobuf`, `mojo-avro`.

