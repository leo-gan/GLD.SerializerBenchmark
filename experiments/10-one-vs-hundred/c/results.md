# Experiment 10 results — c

**Date:** 2026-08-17
**Raw file:** `experiments/10-one-vs-hundred/c/logs/c/2026-08-17-110704.csv`
**Language:** c
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample D (event), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 0.39 | 0.22 | 0.62 | 121 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 90 |
| protobuf-c | 1.5.0 | 0.40 | 0.23 | 0.63 | 121 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | close | yes | 85 |
| msgpack-c | 6.0.1 | 0.66 | 1.32 | 1.95 | 197 | — | MessagePack — official C library | slower | yes | 90 |
| mpack | 1.1 | 0.53 | 1.49 | 2.04 | 197 | — | MessagePack | slower | yes | 93 |
| yyjson | 0.10.0 | 1.43 | 1.02 | 2.47 | 255 | — | JSON — fast writer from Experiment 1 | slower | yes | 85 |
| cJSON | 1.7.18 | 3.26 | 2.36 | 5.63 | 255 | — | JSON — common C library | slower | yes | 89 |

## In memory — sample D (event), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 24.0 | 29.0 | 52.9 | 12764 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 85 |
| protobuf-c | 1.5.0 | 24.4 | 28.7 | 53.3 | 12764 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | close | yes | 85 |
| mpack | 1.1 | 27.9 | 70.8 | 98.7 | 20364 | — | MessagePack | slower | yes | 88 |
| msgpack-c | 6.0.1 | 39.3 | 65.3 | 105 | 20364 | — | MessagePack — official C library | slower | yes | 84 |
| yyjson | 0.10.0 | 105 | 110 | 215 | 26164 | — | JSON — fast writer from Experiment 1 | slower | yes | 87 |
| cJSON | 1.7.18 | 237 | 220 | 457 | 26164 | — | JSON — common C library | slower | yes | 91 |

## In memory — sample B (flat), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-c | 1.5.0 | 0.11 | 0.10 | 0.21 | 51 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | fastest | yes | 91 |
| protobuf-wire | wire-v2 | 0.11 | 0.10 | 0.22 | 51 | — | Protocol Buffers — in-tree wire helper | close | yes | 91 |
| msgpack-c | 6.0.1 | 0.36 | 0.56 | 0.93 | 125 | — | MessagePack — official C library | slower | yes | 90 |
| mpack | 1.1 | 0.26 | 0.68 | 0.93 | 125 | — | MessagePack | slower | yes | 93 |
| yyjson | 0.10.0 | 0.81 | 0.41 | 1.22 | 170 | — | JSON — fast writer from Experiment 1 | slower | yes | 89 |
| cJSON | 1.7.18 | 2.17 | 1.19 | 3.35 | 170 | — | JSON — common C library | slower | yes | 86 |

## In memory — sample B (flat), 100 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| protobuf-wire | wire-v2 | 4.79 | 22.9 | 27.8 | 4932 | — | Protocol Buffers — in-tree wire helper | fastest | yes | 90 |
| protobuf-c | 1.5.0 | 4.78 | 23.1 | 27.9 | 4932 | — | Protocol Buffers — protobuf-c (timed path is the suite wire codec) | similar | yes | 86 |
| mpack | 1.1 | 11.0 | 45.4 | 56.4 | 12295 | — | MessagePack | slower | yes | 79 |
| msgpack-c | 6.0.1 | 18.5 | 41.2 | 59.5 | 12295 | — | MessagePack — official C library | slower | yes | 86 |
| yyjson | 0.10.0 | 55.2 | 49.9 | 105 | 16717 | — | JSON — fast writer from Experiment 1 | slower | yes | 86 |
| cJSON | 1.7.18 | 179 | 119 | 297 | 16741 | — | JSON — common C library | slower | yes | 89 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| protobuf-wire | 1 | 0.67 | 0.44 | 1.11 | copied |
| protobuf-c | 1 | 0.69 | 0.47 | 1.18 | copied |
| mpack | 1 | 0.83 | 1.17 | 2.02 | copied |
| msgpack-c | 1 | 0.98 | 1.03 | 2.03 | copied |
| yyjson | 1 | 1.72 | 1.29 | 3.01 | copied |
| cJSON | 1 | 4.29 | 3.17 | 7.47 | copied |
| protobuf-c | 100 | 25.0 | 29.0 | 54.0 | copied |
| protobuf-wire | 100 | 24.6 | 29.5 | 54.2 | copied |
| mpack | 100 | 28.7 | 72.1 | 101 | copied |
| msgpack-c | 100 | 40.1 | 66.3 | 107 | copied |
| yyjson | 100 | 106 | 112 | 218 | copied |
| cJSON | 100 | 236 | 221 | 459 | copied |
| protobuf-c | 1 | 0.38 | 0.31 | 0.70 | copied |
| protobuf-wire | 1 | 0.38 | 0.31 | 0.71 | copied |
| mpack | 1 | 0.57 | 0.81 | 1.38 | copied |
| msgpack-c | 1 | 0.67 | 0.70 | 1.39 | copied |
| yyjson | 1 | 1.19 | 0.69 | 1.89 | copied |
| cJSON | 1 | 2.76 | 1.58 | 4.34 | copied |
| protobuf-wire | 100 | 5.30 | 23.9 | 29.2 | copied |
| protobuf-c | 100 | 5.47 | 23.9 | 29.3 | copied |
| mpack | 100 | 11.6 | 48.0 | 59.5 | copied |
| msgpack-c | 100 | 19.6 | 43.3 | 63.0 | copied |
| yyjson | 100 | 56.6 | 51.7 | 108 | copied |
| cJSON | 100 | 183 | 120 | 304 | copied |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample D (event), N = 1, memory** — not clearly slower: `protobuf-wire`. Small gap: `protobuf-c`. Time/size front: `protobuf-wire`.

**sample D (event), N = 100, memory** — not clearly slower: `protobuf-wire`. Small gap: `protobuf-c`. Time/size front: `protobuf-wire`.

**sample B (flat), N = 1, memory** — not clearly slower: `protobuf-c`. Small gap: `protobuf-wire`. Time/size front: `protobuf-c`.

**sample B (flat), N = 100, memory** — not clearly slower: `protobuf-wire`, `protobuf-c`. Small gap: —. Time/size front: `protobuf-wire`.

