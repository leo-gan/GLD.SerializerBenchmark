# Experiment 13 results — kotlin

**Date:** 2026-10-11
**Raw file:** `experiments/13-ranking-accident/kotlin/logs/kotlin/2026-10-11-151126.csv`
**Language:** kotlin
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 22.4 | 23.4 | 45.4 | 440 | 2584 | Moshi reflection | fastest | yes | 85 |
| moshi-codegen | 1.15.2 | 21.7 | 22.8 | 45.7 | 440 | 2584 | Moshi generated adapters | similar | yes | 85 |
| gson | 2.14.0 | 39.0 | 51.7 | 92.0 | 440 | 2584 | Google JSON library | slower | yes | 84 |
| kotlinx-json | 1.8.1 | 35.0 | 60.0 | 98.0 | 440 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 86 |
| jackson | 2.19.0 | 53.1 | 85.9 | 137 | 440 | 2584 | Jackson Kotlin module | slower | yes | 88 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 181 | 192 | 372 | 44604 | 2584 | Moshi generated adapters | fastest | yes | 85 |
| moshi-reflect | 1.15.2 | 183 | 192 | 374 | 44604 | 2584 | Moshi reflection | similar | yes | 84 |
| kotlinx-json | 1.8.1 | 202 | 223 | 429 | 44604 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 85 |
| gson | 2.14.0 | 235 | 220 | 458 | 44604 | 2584 | Google JSON library | slower | yes | 82 |
| jackson | 2.19.0 | 144 | 367 | 512 | 44604 | 2584 | Jackson Kotlin module | slower | yes | 82 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 4.76 | 6.07 | 10.8 | 254 | 2584 | Moshi generated adapters | fastest | yes | 92 |
| moshi-reflect | 1.15.2 | 4.85 | 6.38 | 11.2 | 254 | 2584 | Moshi reflection | similar | yes | 79 |
| kotlinx-json | 1.8.1 | 6.03 | 8.27 | 14.2 | 254 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 90 |
| gson | 2.14.0 | 7.50 | 8.79 | 16.4 | 254 | 2584 | Google JSON library | slower | yes | 88 |
| jackson | 2.19.0 | 9.10 | 14.2 | 23.6 | 254 | 2584 | Jackson Kotlin module | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 97.9 | 112 | 211 | 25446 | 2584 | Moshi generated adapters | fastest | yes | 92 |
| moshi-reflect | 1.15.2 | 99.4 | 111 | 212 | 25446 | 2584 | Moshi reflection | similar | yes | 88 |
| kotlinx-json | 1.8.1 | 111 | 119 | 229 | 25446 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 85 |
| gson | 2.14.0 | 114 | 117 | 236 | 25446 | 2584 | Google JSON library | slower | yes | 90 |
| jackson | 2.19.0 | 74.8 | 188 | 264 | 25446 | 2584 | Jackson Kotlin module | slower | yes | 87 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 9.91 | 11.8 | 22.1 | 158 | 2584 | Moshi reflection | fastest | yes | 90 |
| moshi-codegen | 1.15.2 | 11.0 | 12.3 | 23.3 | 158 | 2584 | Moshi generated adapters | similar | yes | 92 |
| kotlinx-json | 1.8.1 | 15.9 | 31.1 | 49.0 | 158 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 93 |
| gson | 2.14.0 | 23.5 | 27.2 | 51.9 | 158 | 2584 | Google JSON library | slower | yes | 91 |
| jackson | 2.19.0 | 25.5 | 37.0 | 65.0 | 158 | 2584 | Jackson Kotlin module | slower | yes | 86 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 67.5 | 97.4 | 164 | 15546 | 2584 | Moshi reflection | fastest | yes | 91 |
| moshi-codegen | 1.15.2 | 67.7 | 96.1 | 164 | 15546 | 2584 | Moshi generated adapters | similar | yes | 89 |
| kotlinx-json | 1.8.1 | 76.5 | 95.6 | 174 | 15546 | 2584 | compiler-generated kotlinx.serialization JSON | close | yes | 90 |
| jackson | 2.19.0 | 57.7 | 139 | 199 | 15546 | 2584 | Jackson Kotlin module | slower | yes | 87 |
| gson | 2.14.0 | 95.7 | 105 | 207 | 15546 | 2584 | Google JSON library | slower | yes | 87 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-codegen | 1.15.2 | 3.72 | 4.68 | 8.39 | 411 | 2584 | Moshi generated adapters | fastest | yes | 96 |
| moshi-reflect | 1.15.2 | 3.74 | 4.73 | 8.48 | 411 | 2584 | Moshi reflection | similar | yes | 90 |
| gson | 2.14.0 | 4.80 | 5.08 | 10.1 | 411 | 2584 | Google JSON library | slower | yes | 88 |
| kotlinx-json | 1.8.1 | 5.60 | 7.43 | 13.1 | 411 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 89 |
| jackson | 2.19.0 | 7.01 | 10.3 | 17.2 | 411 | 2584 | Jackson Kotlin module | slower | yes | 90 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.19.0 | 106 | 145 | 251 | 41431 | 2584 | Jackson Kotlin module | fastest | yes | 92 |
| gson | 2.14.0 | 153 | 137 | 290 | 41431 | 2584 | Google JSON library | slower | yes | 91 |
| moshi-reflect | 1.15.2 | 153 | 165 | 319 | 41431 | 2584 | Moshi reflection | slower | yes | 97 |
| moshi-codegen | 1.15.2 | 156 | 166 | 324 | 41431 | 2584 | Moshi generated adapters | slower | yes | 91 |
| kotlinx-json | 1.8.1 | 173 | 172 | 346 | 41431 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| moshi-reflect | 1.15.2 | 10.6 | 24.4 | 35.3 | 663 | 2584 | Moshi reflection | fastest | yes | 89 |
| kotlinx-json | 1.8.1 | 18.5 | 22.7 | 39.5 | 663 | 2584 | compiler-generated kotlinx.serialization JSON | close | yes | 93 |
| moshi-codegen | 1.15.2 | 12.0 | 26.5 | 39.9 | 663 | 2584 | Moshi generated adapters | close | yes | 92 |
| gson | 2.14.0 | 23.6 | 29.6 | 56.3 | 663 | 2584 | Google JSON library | slower | yes | 95 |
| jackson | 2.19.0 | 24.0 | 40.4 | 66.2 | 663 | 2584 | Jackson Kotlin module | slower | yes | 94 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jackson | 2.19.0 | 284 | 662 | 945 | 65958 | 2584 | Jackson Kotlin module | fastest | yes | 87 |
| kotlinx-json | 1.8.1 | 321 | 643 | 963 | 65958 | 2584 | compiler-generated kotlinx.serialization JSON | slower | yes | 89 |
| gson | 2.14.0 | 296 | 782 | 1078 | 65958 | 2584 | Google JSON library | slower | yes | 88 |
| moshi-codegen | 1.15.2 | 325 | 845 | 1168 | 65958 | 2584 | Moshi generated adapters | slower | yes | 85 |
| moshi-reflect | 1.15.2 | 326 | 845 | 1170 | 65958 | 2584 | Moshi reflection | slower | yes | 92 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample A (order), N = 100, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample D (event), N = 1, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample D (event), N = 100, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample B (flat), N = 1, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: —. Time/size front: `moshi-reflect`.

**sample B (flat), N = 100, memory** — not clearly slower: `moshi-reflect`, `moshi-codegen`. Small gap: `kotlinx-json`. Time/size front: `moshi-reflect`.

**sample E (words), N = 1, memory** — not clearly slower: `moshi-codegen`, `moshi-reflect`. Small gap: —. Time/size front: `moshi-codegen`.

**sample E (words), N = 100, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

**sample C (sensor), N = 1, memory** — not clearly slower: `moshi-reflect`. Small gap: `kotlinx-json`, `moshi-codegen`. Time/size front: `moshi-reflect`.

**sample C (sensor), N = 100, memory** — not clearly slower: `jackson`. Small gap: —. Time/size front: `jackson`.

