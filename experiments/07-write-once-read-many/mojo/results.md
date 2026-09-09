# Experiment 7 results — mojo

**Date:** 2026-09-09
**Raw file:** `experiments/07-write-once-read-many/mojo/logs/mojo/2026-09-09-132131.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.19 | 1.39 | 1.58 | 118 | 0 | Avro | fastest | yes | 90 |
| mojo-protobuf | 0.6.0 | 0.51 | 1.64 | 2.15 | 157 | 0 | Protocol Buffers | slower | yes | 89 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 2.62 | 7.00 | 9.61 | 4135 | 0 | Avro | fastest | yes | 90 |
| mojo-protobuf | 0.6.0 | 3.23 | 9.48 | 12.7 | 4137 | 0 | Protocol Buffers | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

