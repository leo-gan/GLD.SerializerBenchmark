# Experiment 7 results — fortran

**Date:** 2026-10-10
**Raw file:** `experiments/07-write-once-read-many/fortran/logs/fortran/2026-10-10-134112.csv`
**Language:** fortran
**Sample:** A–E (`document`, `message`, `telemetry`, `event`, `strings`), 1 and 100 records
**Cleaning:** first trial dropped; default stall filter (same as the project)

## In memory — sample A (order), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 0.77 | 2.26 | 3.03 | 211 | 2064 | length-prefixed binary | fastest | yes | 95 |
| json-fortran | 9.3.1 | 33.1 | 41.6 | 74.6 | 473 | 2760 | JSON — json-fortran | slower | yes | 95 |
| hdf5-fortran | 1.10.7 | 206 | 167 | 373 | 9536 | 2697 | HDF5 core virtual file driver | slower | yes | 87 |

## In memory — sample C (sensor), 1 record(s) per write

Times are middle values in microseconds (µs). Lower time is better **inside this language**.

| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |
|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|
| custom-binary | v2-1.0 | 3.33 | 3.64 | 7.01 | 4131 | 2064 | length-prefixed binary | fastest | yes | 87 |
| hdf5-fortran | 1.10.7 | 232 | 157 | 398 | 11256 | 2697 | HDF5 core virtual file driver | slower | yes | 89 |
| json-fortran | 9.3.1 | 721 | 525 | 1238 | 11802 | 2760 | JSON — json-fortran | slower | yes | 86 |

## Stream call (side note)

| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |
|---------|---|------------|-----------|-------------------|---------------------------|
| netcdf-fortran | 1 | 1037 | 747 | 1799 | real |
| netcdf-fortran | 1 | 986 | 653 | 1644 | real |

## Libraries that belong in the conversation

We do not name a single winner. Groups are separate for each sample and each number of records. Named JSON only.

**sample A (order), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

**sample C (sensor), N = 1, memory** — not clearly slower: `custom-binary`. Small gap: —. Time/size front: `custom-binary`.

