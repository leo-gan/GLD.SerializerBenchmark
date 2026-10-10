# Experiment 5 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/05-event-log-formats/fortran/logs/fortran/2026-10-10-134200.csv`
**Language:** fortran
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.60 | 1.50 | 2.13 | 113 | 3945 | length-prefixed binary | fastest | yes | 90 |
| json-fortran | 9.3.1 | 18.8 | 19.4 | 38.1 | 258 | 4299 | JSON — json-fortran | slower | yes | 85 |
| fortran-messagepack | 0.3.1 | 29.4 | 30.4 | 60.4 | 197 | 4516 | MessagePack | slower | yes | 84 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 22.0 | 85.1 | 109 | 12029 | 3945 | length-prefixed binary | fastest | yes | 81 |
| json-fortran | 9.3.1 | 1151 | 1016 | 2181 | 26647 | 4299 | JSON — json-fortran | slower | yes | 97 |
| fortran-messagepack | 0.3.1 | 1831 | 2362 | 4198 | 20443 | 4516 | MessagePack | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

