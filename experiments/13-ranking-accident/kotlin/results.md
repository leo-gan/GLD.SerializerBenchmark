# Experiment 13 results — kotlin

**Date:** 2026-08-28
**Raw file:** `experiments/13-ranking-accident/kotlin/logs/kotlin/2026-08-27-181814.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 23.8 | 25.5 | 50.4 | 440 | 2584 | Moshi reflection | fastest | yes | 83 |
| moshi-codegen | 1.15.2 | 24.5 | 26.2 | 51.5 | 440 | 2584 | Moshi generated adapters | similar | yes | 84 |
| kotlinx-json | 1.8.1 | 36.6 | 60.5 | 103 | 440 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 88 |
| gson | 2.12.1 | 46.3 | 53.0 | 103 | 440 | 2584 | Google JSON library | slower | yes | 84 |
| jackson | 2.18.3 | 58.6 | 97.0 | 153 | 440 | 2584 | Jackson Kotlin module | slower | yes | 82 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 192 | 211 | 403 | 44604 | 2584 | Moshi generated adapters | fastest | yes | 88 |
| moshi-reflect | 1.15.2 | 196 | 212 | 412 | 44604 | 2584 | Moshi reflection | similar | yes | 90 |
| kotlinx-json | 1.8.1 | 215 | 228 | 443 | 44604 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 79 |
| jackson | 2.18.3 | 151 | 394 | 545 | 44604 | 2584 | Jackson Kotlin module | slower | yes | 88 |
| gson | 2.12.1 | 506 | 231 | 743 | 44604 | 2584 | Google JSON library | slower | yes | 83 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 4.55 | 6.14 | 10.9 | 254 | 2584 | Moshi reflection | fastest | yes | 82 |
| moshi-codegen | 1.15.2 | 4.59 | 6.33 | 11.0 | 254 | 2584 | Moshi generated adapters | similar | yes | 89 |
| kotlinx-json | 1.8.1 | 5.19 | 7.34 | 12.5 | 254 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 88 |
| gson | 2.12.1 | 8.43 | 8.31 | 16.9 | 254 | 2584 | Google JSON library | slower | yes | 84 |
| jackson | 2.18.3 | 8.93 | 11.8 | 21.1 | 254 | 2584 | Jackson Kotlin module | slower | yes | 89 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 99.8 | 114 | 215 | 25446 | 2584 | Moshi generated adapters | fastest | yes | 87 |
| moshi-reflect | 1.15.2 | 102 | 115 | 216 | 25446 | 2584 | Moshi reflection | similar | yes | 87 |
| kotlinx-json | 1.8.1 | 110 | 120 | 231 | 25446 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 88 |
| jackson | 2.18.3 | 78.1 | 191 | 269 | 25446 | 2584 | Jackson Kotlin module | slower | yes | 93 |
| gson | 2.12.1 | 243 | 114 | 361 | 25446 | 2584 | Google JSON library | slower | yes | 90 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 7.73 | 10.3 | 18.4 | 158 | 2584 | Moshi reflection | fastest | yes | 93 |
| moshi-codegen | 1.15.2 | 8.35 | 10.7 | 19.1 | 158 | 2584 | Moshi generated adapters | similar | yes | 86 |
| kotlinx-json | 1.8.1 | 11.3 | 23.8 | 35.7 | 158 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 92 |
| gson | 2.12.1 | 19.1 | 26.0 | 45.5 | 158 | 2584 | Google JSON library | slower | yes | 93 |
| jackson | 2.18.3 | 22.7 | 32.7 | 55.3 | 158 | 2584 | Jackson Kotlin module | slower | yes | 93 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 80.7 | 108 | 191 | 15546 | 2584 | Moshi reflection | fastest | yes | 86 |
| moshi-codegen | 1.15.2 | 81.3 | 109 | 195 | 15546 | 2584 | Moshi generated adapters | similar | yes | 87 |
| kotlinx-json | 1.8.1 | 86.6 | 126 | 209 | 15546 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 87 |
| jackson | 2.18.3 | 87.1 | 177 | 265 | 15546 | 2584 | Jackson Kotlin module | slower | yes | 84 |
| gson | 2.12.1 | 169 | 185 | 351 | 15546 | 2584 | Google JSON library | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 3.57 | 4.35 | 7.95 | 411 | 2584 | Moshi reflection | fastest | yes | 98 |
| moshi-codegen | 1.15.2 | 3.70 | 4.32 | 8.10 | 411 | 2584 | Moshi generated adapters | similar | yes | 94 |
| gson | 2.12.1 | 6.18 | 4.85 | 11.0 | 411 | 2584 | Google JSON library | slower | yes | 79 |
| kotlinx-json | 1.8.1 | 5.10 | 7.16 | 12.3 | 411 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 82 |
| jackson | 2.18.3 | 6.43 | 10.3 | 16.6 | 411 | 2584 | Jackson Kotlin module | slower | yes | 93 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 110 | 151 | 263 | 41431 | 2584 | Jackson Kotlin module | fastest | yes | 95 |
| moshi-codegen | 1.15.2 | 164 | 173 | 334 | 41431 | 2584 | Moshi generated adapters | slower | yes | 91 |
| moshi-reflect | 1.15.2 | 165 | 171 | 336 | 41431 | 2584 | Moshi reflection | slower | yes | 91 |
| kotlinx-json | 1.8.1 | 174 | 175 | 349 | 41431 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 91 |
| gson | 2.12.1 | 296 | 139 | 436 | 41431 | 2584 | Google JSON library | slower | yes | 90 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 8.90 | 30.3 | 39.5 | 663 | 2584 | Moshi reflection | fastest | yes | 87 |
| moshi-codegen | 1.15.2 | 9.65 | 30.9 | 40.0 | 663 | 2584 | Moshi generated adapters | similar | yes | 91 |
| gson | 2.12.1 | 16.1 | 30.8 | 46.7 | 663 | 2584 | Google JSON library | slower | yes | 85 |
| kotlinx-json | 1.8.1 | 16.5 | 35.0 | 51.8 | 663 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 91 |
| jackson | 2.18.3 | 21.3 | 43.4 | 65.8 | 663 | 2584 | Jackson Kotlin module | slower | yes | 89 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.18.3 | 301 | 725 | 1025 | 65958 | 2584 | Jackson Kotlin module | fastest | yes | 85 |
| kotlinx-json | 1.8.1 | 331 | 705 | 1038 | 65958 | 2584 | compiler-generated kotlinx.serialization JSON | similar | yes | 84 |
| gson | 2.12.1 | 373 | 829 | 1202 | 65958 | 2584 | Google JSON library | slower | yes | 85 |
| moshi-reflect | 1.15.2 | 345 | 904 | 1253 | 65958 | 2584 | Moshi reflection | slower | yes | 86 |
| moshi-codegen | 1.15.2 | 347 | 910 | 1265 | 65958 | 2584 | Moshi generated adapters | slower | yes | 77 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample A (order), N = 100, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample D (event), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample D (event), N = 100, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample B (flat), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample B (flat), N = 100, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample E (words), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample E (words), N = 100, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample C (sensor), N = 100, memory** — not clearly slower: `jackson`, `kotlinx-json`. Small gap: —. Time/size front: `jackson`.

