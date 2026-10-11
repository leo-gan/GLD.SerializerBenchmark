# Experiment 5 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/05-event-log-formats/fortran/logs/fortran/2026-10-11-150230.csv`
**Language:** fortran
**Sample:** one event (`event`), 1 and 100 records per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.29 | 1.00 | 1.29 | 113 | 3945 | length-prefixed binary | fastest | yes | 90 |
| json-fortran | 9.3.1 | 13.6 | 14.1 | 27.8 | 258 | 4299 | JSON — json-fortran | slower | yes | 91 |
| fortran-messagepack | 0.3.1 | 22.3 | 25.3 | 47.7 | 197 | 4516 | MessagePack | slower | yes | 92 |

## In memory — 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 20.4 | 78.7 | 99.4 | 12029 | 3945 | length-prefixed binary | fastest | yes | 78 |
| json-fortran | 9.3.1 | 822 | 903 | 1728 | 26647 | 4299 | JSON — json-fortran | slower | yes | 80 |
| fortran-messagepack | 0.3.1 | 1408 | 1908 | 3311 | 20443 | 4516 | MessagePack | slower | yes | 90 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one event. Groups are computed **separately** for 1 record and for 100 records. Speed cannot override a failed compatibility story.

**N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**N = 100, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

