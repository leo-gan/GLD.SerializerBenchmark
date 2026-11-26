# Benchmark Architecture

This specification describes the repository structure, measurement lifecycle, compiler/buffer policies, and trial-randomization schedule shared across all fourteen language benchmark runners. Statistical post-processing lives in [Analysis methodology](ANALYSIS_METHODOLOGY.md); timing boundary rules live in [Timing contract](TIMING_HONESTY.md).

## Repository Layout

| Path | Role |
|---|---|
| `config/benchmark_config.yaml` | Master configuration: run modes, data sets, statistics defaults, language registry, CSV schema |
| `config/dimensions.yaml` | Primary standard disambiguation and optional I/O folding rules |
| `config/library/*.yaml` | Run configurations selecting `(data_type, type_config, batch_size)` matrices |
| `schemas/` | Shared logical catalog (`data_catalog_v2.yaml`) and wire IDLs (`schemas/v2/`) |
| `c/`, `c-sharp/`, `cpp/`, `fortran/`, `go/`, `java/`, `javascript/`, `kotlin/`, `mojo/`, `php/`, `python/`, `rust/`, `swift/`, `zig/` | Standalone benchmark runners, one per language |
| `logs/<lang>/` | Raw timestamped CSVs and `*.configs.json` sidecars (gitignored) |
| `analysis/` | Python package implementing `analyze-benchmarks` |
| `dashboard/` | Static web Dashboard and packing scripts (`sync-data.py`, `sync-experiments.py`) |
| `scripts/run-all-benchmarks.sh` | Multi-language run orchestrator |

Published Dashboard bundles (`dashboard/public/data/stats_<lang>_latest.json.gz`) are generated locally from `reports/stats_<lang>_latest.json` via `python3 dashboard/scripts/sync-data.py`. Continuous integration validates smoke runs and publishes the documentation site; it does not re-execute full benchmark runs ([Claims and replication](CLAIMS_AND_REPLICATION.md)).

## Measurement Lifecycle {#measurement-model}

Every runner separates untimed preparation from the timed repetition loop:

1. **Prepare (untimed, once per cell):** Load schemas, compile/bind type-specific codecs, allocate reusable output buffers, and convert suite records into the library's native in-memory model. Encoded wire bytes must never be precomputed here ([Timing contract](TIMING_HONESTY.md)).
2. **Timed loop (for repetition $r = 0, \dots, R - 1$):** Measure `serialize` and `deserialize` independently in nanoseconds using monotonic high-resolution clocks.
3. **Fidelity verification (untimed, post-deserialize):** Verify semantic round-trip equality. Failed trials are recorded in `logs/<lang>/<ts>.errors.csv` and excluded from speed aggregates.
4. **Warmup logging:** Runners always write every successful repetition, including `RepetitionIndex = 0`. Analysis excludes repetition `0` downstream when `statistics.exclude_warmup` is enabled; raw logs are never mutated.

## Suite-Wide Engineering Policies {#timing-methodology-suite-wide-issue-59}

These invariants prevent systematic measurement artifacts across native and managed runtimes:

| Concern | Policy |
|---|---|
| **Output buffers** | Prefer a runner-owned or pre-sized scratch buffer cleared and reused across repetitions so cold growth lands in warmup. Document any allocator exception on the language page. |
| **Optimization barriers** | Compiled native runners (C, C++, Rust, Zig, Swift, Mojo, Fortran) must apply dead-code-elimination barriers (`black_box`, `DoNotOptimize`, volatile sinks, or equivalents) to timed inputs and outputs. |
| **Type dispatch** | Bind type-specific handlers during `prepare` (monomorphic functions, closures, function pointers) rather than branching on data-type IDs inside the timed loop. |
| **Determinism** | Payload PRNGs must be deterministic within each language for a given `(BENCHMARK_SEED, type_id, type_config, instance_index)`. Identical byte payloads across languages are not required. |
| **Per-serializer buffer floors** | Keep stream/buffer capacity state per serializer rather than shared across codecs so interleaved execution cannot amortize one library's allocation onto another. |

`rust/src/run_v2.rs` serves as a concise reference implementation of these policies.

## Timed-Trial Schedule (Block Shuffle) {#timed-trial-schedule}

To prevent systematic confounding between serializer registration order and wall-clock drift (CPU frequency scaling, thermal throttling, background load),[^1] runners default to `reproducibility.schedule.strategy: block_shuffle`:

```text
for cell in resolved_cells:                 # fixed YAML order
    prepare all eligible serializers        # untimed, once per cell
    for mode in io_modes:                   # sequential I/O mode blocks
        for rep in 0 .. repetitions - 1:
            order = FisherYates(serializers, seed = H(base_seed, cell, mode, rep))
            for ser in order:
                timed serialize + deserialize
                append CSV row (RepetitionIndex = rep, optional RunOrder, SchedulePosition)
```

Setting `strategy: none` or `BENCHMARK_SCHEDULE=none` restores legacy fixed execution order for diagnostic runs.

### Normative Shuffle Seed Recipe

All languages compute the same deterministic permutation using a dedicated PRNG (never advancing the payload generator):

```text
key  = "{base_seed}|{type_id}|{instance_count}|{type_config_hash}|{mode}|{rep}"
       (mode normalized: string|buffer → bytes; Stream → stream; lowercase)
u64  = first 8 bytes of SHA-256(UTF-8(key)), little-endian
prng = SplitMix64(u64)
Fisher-Yates: for i = n - 1 down to 1: j = prng.next_u64() % (i + 1); swap(order[i], order[j])
```

**Golden verification vector** (checked in `analysis/tests/test_schedule.py`, reference in `analysis/src/benchmark_analysis/schedule.py`): `names = [A, B, C]`, `base_seed = 42`, `type_id = message`, `n = 1`, `hash = abc`, `mode = bytes`, `rep = 0` yields **`[C, B, A]`**.

Optional audit columns `RunOrder` (monotonic 0-based process write index) and `SchedulePosition` (index within the shuffled repetition) support post-hoc drift checks without altering analysis grouping.

## Benchmark Runner Contract {#harness-contract-summary}

| Requirement | Normative Specification |
|---|---|
| Output path | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` conforming to `csv_schema` |
| Language id | Short lowercase id (`csharp`, `python`, `rust`, …) in `Language` |
| Time unit | **Nanoseconds** across every runner |
| I/O modes | `bytes` and optional `stream` with honest `StreamMode` ([Modes](modes.md)) |
| Run modes {#run-modes-how-many-repetitions} | Read repetition counts via `bench_mode_reps` (`smoke`, `all-single`, `full`, `research`; see [Modes](modes.md#part-2-run-modes-how-heavy-the-experiment-is)) |
| Schedule | Default `block_shuffle` matching golden vector `[C, B, A]` |
| Fidelity | Untimed semantic round-trip check; failures written to `*.errors.csv` |
| Sidecar | Optional `*.configs.json` recording `environment.machine_id`, runtime versions, and schedule |

Implementation walkthrough: [Adding a language](ADDING_A_LANGUAGE.md) · [Adding a serializer](ADDING_A_SERIALIZER.md).

## References

[^1]: Mytkowicz, T., Diwan, A., Hauswirth, M., & Sweeney, P. F. (2009). "Producing Wrong Data Without Doing Anything Obviously Wrong!" *Proceedings of ASPLOS '09*, 265–276. <https://doi.org/10.1145/1508244.1508275>
