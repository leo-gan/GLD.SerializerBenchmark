# Experiment 3 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/03-one-language-store/fortran/logs/fortran/2026-10-10-134110.csv`
**Language:** fortran
**Sample:** one flat record (`message`), 1 record per write
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.42 | 1.32 | 1.82 | 44 | 62 | one language — length-prefixed binary | fastest | yes | 98 |
| json-fortran | 9.3.1 | 18.0 | 19.4 | 37.6 | 172 | 142 | other languages can read — JSON | slower | yes | 91 |
| hdf5-fortran | 1.10.7 | 182 | 149 | 334 | 7704 | 614 | HDF5 core virtual file driver | slower | yes | 91 |

## Libraries that belong in the conversation

We do not name a single winner. This sample is one small flat record. A different record can change who is first. A faster one-language library is not proof that the store is safe.

**N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

