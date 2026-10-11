# Experiment 9 results — fortran

**Date:** 2026-10-11
**Raw file:** `experiments/09-compression-size/fortran/logs/fortran/2026-10-11-150630.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.16 | 0.87 | 1.04 | 44 | 62 | length-prefixed binary | fastest | yes | 93 |
| toml-f | 0.5.2 | 10.8 | 10.5 | 21.2 | 169 | 139 | TOML | slower | yes | 92 |
| json-fortran | 9.3.1 | 13.0 | 13.9 | 26.8 | 172 | 142 | JSON — json-fortran | slower | yes | 84 |
| fortran-messagepack | 0.3.1 | 15.1 | 14.9 | 30.0 | 120 | 121 | MessagePack | slower | yes | 92 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.46 | 1.38 | 1.83 | 383 | 290 | length-prefixed binary | fastest | yes | 99 |
| json-fortran | 9.3.1 | 15.7 | 15.1 | 30.8 | 430 | 294 | JSON — json-fortran | slower | yes | 93 |
| fortran-messagepack | 0.3.1 | 22.0 | 23.3 | 45.3 | 362 | 285 | MessagePack | slower | yes | 92 |
| toml-f | 0.5.2 | 25.7 | 24.0 | 49.9 | 462 | 299 | TOML | slower | yes | 96 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.74 | 1.32 | 2.09 | 1059 | 1071 | length-prefixed binary | fastest | yes | 77 |
| fortran-messagepack | 0.3.1 | 32.6 | 34.5 | 67.2 | 1209 | 1163 | MessagePack | slower | yes | 83 |
| toml-f | 0.5.2 | 172 | 141 | 313 | 2758 | 1486 | TOML | slower | yes | 91 |
| json-fortran | 9.3.1 | 195 | 129 | 324 | 3008 | 1417 | JSON — json-fortran | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample E (words), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`, `fortran-messagepack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

