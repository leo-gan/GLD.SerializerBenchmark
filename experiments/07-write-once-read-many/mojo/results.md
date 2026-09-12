# Experiment 7 results — mojo

**Date:** 2026-09-12
**Raw file:** `experiments/07-write-once-read-many/mojo/logs/mojo/2026-09-12-132654.csv`
**Language:** mojo
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 0.22 | 1.48 | 1.70 | 118 | 0 | Avro | fastest | yes | 71 |
| mojo-protobuf | 0.6.0 | 0.57 | 1.79 | 2.37 | 157 | 0 | Protocol Buffers | slower | yes | 72 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| mojo-avro | 0.4.0 | 2.72 | 6.98 | 9.70 | 4135 | 0 | Avro | fastest | yes | 88 |
| mojo-protobuf | 0.6.0 | 3.70 | 10.7 | 14.5 | 4137 | 0 | Protocol Buffers | slower | yes | 87 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

**sample C (sensor), N = 1, memory** — not clearly slower: `mojo-avro`. Small gap: —. Time/size front: `mojo-avro`.

