# What does a Fortran call add?

**Question:** For one shop order, how much time does a Fortran call add over the C runner calling the same C library?
**Date:** 2026-10-11
**Sample:** `document`, 1 record(s) per write · [`sample.json`](sample.json)
**Settings:** [`experiment.yaml`](experiment.yaml)
**Machine-readable file:** [`results.json`](results.json)

Times in two languages are **not** one contest. Read each row as an answer inside that language only.

We do not name a single winner. This sample is one small order. A different record can change who is first. **Similar** means we cannot tell the library apart from the fastest named-JSON library on this sample. **Close** means a small gap.

## At a glance

| Language | Status | Not clearly slower | Small gap | Not both slower and larger | Full table |
|----------|--------|--------------------|-----------|----------------------------|------------|
| c | ok | `flatcc` | — | `flatcc`, `nanopb` | [c/results.md](c/results.md) |
| fortran | ok | `flatcc` | — | `flatcc`, `nanopb` | [fortran/results.md](fortran/results.md) |

## Named JSON, in memory, by language

Only libraries that write ordinary named fields, in-memory call. Times are middle values in microseconds. Lower is better **inside that language**.

### c

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| flatcc | 1.07 | 236 | fastest |
| nanopb | 1.19 | 166 | slower |
| avro-c | 1.59 | 210 | slower |
| mpack | 3.11 | 335 | slower |
| yyjson | 5.86 | 460 | slower |
| tinycbor | 7.72 | 343 | slower |
| libbson | 8.06 | 577 | slower |
| cJSON | 13.9 | 460 | slower |
| ion-c | 21.2 | 249 | slower |
| libyaml | 33.6 | 461 | slower |

### fortran

| Library | Write + read (µs) | Size (bytes) | Group |
|---------|-------------------|--------------|-------|
| flatcc | 0.91 | 240 | fastest |
| nanopb | 1.06 | 169 | slower |
| avro-c | 1.15 | 214 | slower |
| mpack | 2.20 | 337 | slower |
| yyjson | 4.89 | 464 | slower |
| tinycbor | 6.87 | 344 | slower |
| libbson | 7.30 | 581 | slower |
| cJSON | 10.5 | 464 | slower |
| ion-c | 14.5 | 251 | slower |
| libyaml | 22.2 | 465 | slower |

## What this page is not

- It is not a ranking of languages.
- It is not a ranking of formats. Everyone here writes JSON text.
- It is not a promise that the same names stay on top if you change the record.

