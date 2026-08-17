# Experiment 13 results — java

**Date:** 2026-08-17
**Raw file:** `experiments/13-ranking-accident/java/logs/java/2026-08-17-104741.csv`
**Language:** java
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 24.0 | 26.2 | 51.1 | 440 | — | fast writer | fastest | yes | 92 |
| fastjson2 | 2.0.57 | 41.6 | 45.2 | 87.9 | 440 | — | fast writer | slower | yes | 94 |
| moshi | 1.15.2 | 43.8 | 49.2 | 93.9 | 440 | — | Square JSON library | slower | yes | 92 |
| gson | 2.12.1 | 45.5 | 44.8 | 96.2 | 440 | — | Google JSON library | slower | yes | 88 |
| jackson | 2.18.3 | 44.7 | 52.2 | 97.0 | 440 | — | common default in Java services | slower | yes | 88 |
| dsl-json | 2.0.2 | 47.7 | 60.8 | 109 | 440 | — | fast writer | slower | yes | 86 |

## In memory — sample A (order), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 76.4 | 95.2 | 168 | 44604 | — | fast writer | fastest | yes | 82 |
| fastjson2 | 2.0.57 | 118 | 124 | 248 | 44604 | — | fast writer | slower | yes | 84 |
| dsl-json | 2.0.2 | 112 | 139 | 257 | 44604 | — | fast writer | slower | yes | 86 |
| jackson | 2.18.3 | 139 | 189 | 325 | 44604 | — | common default in Java services | slower | yes | 79 |
| moshi | 1.15.2 | 218 | 226 | 443 | 44604 | — | Square JSON library | slower | yes | 84 |
| gson | 2.12.1 | 491 | 236 | 727 | 44604 | — | Google JSON library | slower | yes | 85 |

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| dsl-json | 2.0.2 | 5.54 | 5.80 | 11.3 | 254 | — | fast writer | fastest | yes | 89 |
| jsoniter | 0.9.23 | 5.11 | 6.43 | 11.8 | 254 | — | fast writer | similar | yes | 92 |
| gson | 2.12.1 | 6.61 | 5.80 | 12.4 | 254 | — | Google JSON library | close | yes | 90 |
| moshi | 1.15.2 | 5.95 | 6.08 | 12.5 | 254 | — | Square JSON library | similar | yes | 90 |
| jackson | 2.18.3 | 6.26 | 8.83 | 15.1 | 254 | — | common default in Java services | slower | yes | 88 |
| fastjson2 | 2.0.57 | 12.2 | 8.81 | 20.9 | 254 | — | fast writer | slower | yes | 86 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 51.3 | 72.9 | 123 | 25446 | — | fast writer | fastest | yes | 89 |
| fastjson2 | 2.0.57 | 60.7 | 68.7 | 131 | 25446 | — | fast writer | close | yes | 94 |
| dsl-json | 2.0.2 | 70.8 | 95.6 | 167 | 25446 | — | fast writer | slower | yes | 94 |
| jackson | 2.18.3 | 74.3 | 111 | 185 | 25446 | — | common default in Java services | slower | yes | 88 |
| moshi | 1.15.2 | 116 | 133 | 251 | 25446 | — | Square JSON library | slower | yes | 84 |
| gson | 2.12.1 | 252 | 119 | 372 | 25446 | — | Google JSON library | slower | yes | 88 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 14.0 | 13.7 | 28.2 | 150 | — | fast writer | fastest | yes | 86 |
| moshi | 1.15.2 | 20.1 | 23.3 | 43.5 | 158 | — | Square JSON library | slower | yes | 90 |
| fastjson2 | 2.0.57 | 24.4 | 21.4 | 47.5 | 158 | — | fast writer | slower | yes | 88 |
| gson | 2.12.1 | 28.6 | 25.6 | 52.9 | 158 | — | Google JSON library | slower | yes | 94 |
| dsl-json | 2.0.2 | 32.5 | 23.8 | 56.9 | 158 | — | fast writer | slower | yes | 89 |
| jackson | 2.18.3 | 26.1 | 36.7 | 61.5 | 158 | — | common default in Java services | slower | yes | 87 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 40.3 | 58.0 | 102 | 14804 | — | fast writer | fastest | yes | 94 |
| fastjson2 | 2.0.57 | 50.5 | 70.1 | 125 | 15547 | — | fast writer | close | yes | 86 |
| jackson | 2.18.3 | 60.6 | 103 | 167 | 15546 | — | common default in Java services | slower | yes | 85 |
| dsl-json | 2.0.2 | 84.7 | 81.6 | 169 | 15546 | — | fast writer | slower | yes | 85 |
| moshi | 1.15.2 | 91.2 | 129 | 221 | 15546 | — | Square JSON library | slower | yes | 79 |
| gson | 2.12.1 | 160 | 115 | 277 | 15546 | — | Google JSON library | slower | yes | 88 |

## In memory — sample E (words), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| dsl-json | 2.0.2 | 2.31 | 2.57 | 4.90 | 411 | — | fast writer | fastest | yes | 81 |
| moshi | 1.15.2 | 3.09 | 3.10 | 6.19 | 411 | — | Square JSON library | slower | yes | 74 |
| jsoniter | 0.9.23 | 2.59 | 3.44 | 6.33 | 411 | — | fast writer | slower | yes | 81 |
| gson | 2.12.1 | 4.39 | 3.07 | 7.47 | 411 | — | Google JSON library | slower | yes | 84 |
| jackson | 2.18.3 | 3.45 | 4.55 | 8.12 | 411 | — | common default in Java services | slower | yes | 78 |
| fastjson2 | 2.0.57 | 3.53 | 6.05 | 9.64 | 411 | — | fast writer | slower | yes | 84 |

## In memory — sample E (words), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 94.4 | 126 | 220 | 41431 | — | fast writer | fastest | yes | 85 |
| dsl-json | 2.0.2 | 105 | 116 | 223 | 41431 | — | fast writer | similar | yes | 86 |
| fastjson2 | 2.0.57 | 105 | 122 | 226 | 41431 | — | fast writer | close | yes | 90 |
| jackson | 2.18.3 | 99.4 | 130 | 230 | 41431 | — | common default in Java services | slower | yes | 87 |
| moshi | 1.15.2 | 154 | 166 | 321 | 41431 | — | Square JSON library | slower | yes | 86 |
| gson | 2.12.1 | 286 | 135 | 422 | 41431 | — | Google JSON library | slower | yes | 88 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 16.0 | 20.0 | 36.4 | 387 | — | fast writer | fastest | yes | 90 |
| dsl-json | 2.0.2 | 26.2 | 26.5 | 50.4 | 663 | — | fast writer | slower | yes | 90 |
| fastjson2 | 2.0.57 | 34.3 | 32.2 | 65.4 | 663 | — | fast writer | slower | yes | 93 |
| moshi | 1.15.2 | 32.1 | 43.0 | 75.8 | 663 | — | Square JSON library | slower | yes | 95 |
| gson | 2.12.1 | 36.1 | 42.7 | 77.1 | 663 | — | Google JSON library | slower | yes | 94 |
| jackson | 2.18.3 | 33.2 | 50.6 | 87.0 | 663 | — | common default in Java services | slower | yes | 94 |

## In memory — sample C (sensor), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| jsoniter | 0.9.23 | 90.5 | 102 | 193 | 39143 | — | fast writer | fastest | yes | 85 |
| fastjson2 | 2.0.57 | 176 | 194 | 373 | 65960 | — | fast writer | slower | yes | 89 |
| dsl-json | 2.0.2 | 428 | 206 | 637 | 65958 | — | fast writer | slower | yes | 87 |
| jackson | 2.18.3 | 304 | 671 | 978 | 65958 | — | common default in Java services | slower | yes | 87 |
| gson | 2.12.1 | 551 | 921 | 1470 | 65958 | — | Google JSON library | slower | yes | 86 |
| moshi | 1.15.2 | 484 | 1034 | 1521 | 65958 | — | Square JSON library | slower | yes | 85 |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`.

**sample A (order), N = 100, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`.

**sample D (event), N = 1, memory** — not clearly slower: `dsl-json`, `jsoniter`, `moshi`. Small gap: `gson`. Time/size front: `dsl-json`.

**sample D (event), N = 100, memory** — not clearly slower: `jsoniter`. Small gap: `fastjson2`. Time/size front: `jsoniter`.

**sample B (flat), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`.

**sample B (flat), N = 100, memory** — not clearly slower: `jsoniter`. Small gap: `fastjson2`. Time/size front: `jsoniter`.

**sample E (words), N = 1, memory** — not clearly slower: `dsl-json`. Small gap: —. Time/size front: `dsl-json`.

**sample E (words), N = 100, memory** — not clearly slower: `jsoniter`, `dsl-json`. Small gap: `fastjson2`. Time/size front: `jsoniter`.

**sample C (sensor), N = 1, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`.

**sample C (sensor), N = 100, memory** — not clearly slower: `jsoniter`. Small gap: —. Time/size front: `jsoniter`.

