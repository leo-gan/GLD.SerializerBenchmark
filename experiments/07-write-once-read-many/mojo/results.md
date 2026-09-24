# Experiment 7 results — mojo

**Date:** 2026-09-24
**Raw file:** `experiments/07-write-once-read-many/mojo/logs/mojo/2026-09-23-181532.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.22 | 1.53 | 1.75 | 118 | 0 | Avro | fastest | yes | 84 |
| mojo-protobuf | 0.6.0 | 0.59 | 1.85 | 2.43 | 157 | 0 | Protocol Buffers | slower | yes | 79 |
| mojo-flatbuffers | 0.2.0 | 3.59 | 1.10 | 4.68 | 416 | 0 | FlatBuffers | slower | yes | 84 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-flatbuffers | 0.2.0 | 3.21 | 2.55 | 5.72 | 4200 | 0 | FlatBuffers | fastest | yes | 90 |
| mojo-avro | 0.4.0 | 2.71 | 7.65 | 10.4 | 4135 | 0 | Avro | slower | yes | 89 |
| mojo-protobuf | 0.6.0 | 3.26 | 10.3 | 13.6 | 4137 | 0 | Protocol Buffers | slower | yes | 89 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-flatbuffers`. Small gap: —. Time/size front: `mojo-flatbuffers`, `mojo-avro`.

