# Experiment 7 results — mojo

**Date:** 2026-09-08
**Raw file:** `experiments/07-write-once-read-many/mojo/logs/mojo/2026-09-08-155354.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.21 | 1.48 | 1.70 | 118 | 0 | Avro | fastest | yes | 88 |
| mojo-protobuf | 0.6.0 | 0.55 | 1.78 | 2.33 | 157 | 0 | Protocol Buffers | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 3.22 | 8.36 | 11.6 | 4135 | 0 | Avro | fastest | yes | 91 |
| mojo-protobuf | 0.6.0 | 4.30 | 11.4 | 15.7 | 4137 | 0 | Protocol Buffers | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

