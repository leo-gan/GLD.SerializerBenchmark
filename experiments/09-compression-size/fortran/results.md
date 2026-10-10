# Experiment 9 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/09-compression-size/fortran/logs/fortran/2026-10-10-134212.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.53 | 1.50 | 2.01 | 44 | 62 | length-prefixed binary | fastest | yes | 90 |
| toml-f | 0.5.2 | 17.8 | 18.9 | 37.0 | 169 | 139 | TOML | slower | yes | 87 |
| fortran-messagepack | 0.3.1 | 19.8 | 21.3 | 41.2 | 120 | 121 | MessagePack | slower | yes | 93 |
| json-fortran | 9.3.1 | 21.7 | 23.7 | 46.0 | 172 | 142 | JSON — json-fortran | slower | yes | 93 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.80 | 1.97 | 2.74 | 383 | 290 | length-prefixed binary | fastest | yes | 85 |
| json-fortran | 9.3.1 | 21.7 | 21.1 | 42.5 | 430 | 294 | JSON — json-fortran | slower | yes | 87 |
| fortran-messagepack | 0.3.1 | 26.4 | 31.2 | 57.6 | 362 | 285 | MessagePack | slower | yes | 84 |
| toml-f | 0.5.2 | 32.6 | 31.6 | 64.2 | 462 | 299 | TOML | slower | yes | 81 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 1.20 | 1.70 | 2.92 | 1059 | 1071 | length-prefixed binary | fastest | yes | 91 |
| fortran-messagepack | 0.3.1 | 36.2 | 38.5 | 74.9 | 1209 | 1163 | MessagePack | slower | yes | 85 |
| toml-f | 0.5.2 | 189 | 149 | 337 | 2758 | 1486 | TOML | slower | yes | 89 |
| json-fortran | 9.3.1 | 210 | 135 | 345 | 3008 | 1417 | JSON — json-fortran | slower | yes | 86 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample B (flat), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample E (words), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`, `fortran-messagepack`.

**sample C (sensor), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

