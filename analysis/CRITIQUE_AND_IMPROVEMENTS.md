# Implementation Critique & Immediate Improvements

This document records an unvarnished review of the v2 refactor and what was fixed in-tree vs what remains.

## What is solid

1. **Unified config** (`config/benchmark_config.yaml`) — parameters are no longer scattered magic numbers.
2. **CSV contract with `Language`** — analysis is language-agnostic; adding Java (or another language) is documentation + harness, not analysis rewrites.
3. **Scientific stats** — bootstrap CI, Cliff's δ, Hedges' g, Mann–Whitney + Holm are appropriate for non-normal latency data; means-only reporting is insufficient for a paper.
4. **A/B path** — serializer authors have a first-class comparison mode, not a spreadsheet exercise.
5. **Six language harnesses** (C#, Python, Rust, C, JavaScript, Go) with runner scripts, docs, and native host execution (no Docker).
6. **Host prepare step** — `scripts/check-host-requirements.sh` / `install-host-requirements.sh` separate toolchains from benchmark runs.
7. **CI smoke matrix** — path-filtered jobs install native toolchains (`dotnet`, `uv`, `setup-go` 1.24, etc.) before `run-benchmarks.sh`.

## What was weak (status)

### 1. C benchmark honesty (HIGH) — **fixed**

**Problem (historical):** Default C build once used minimal JSON/binary *stand-ins* labeled with real library names.

**Fixed:** Vendored libraries under `c/third_party/` (cJSON, yyjson, mpack, tinycbor, …), built via `c/scripts/fetch-and-build-deps.sh`, registered through real `HAS_*` paths in `register_serializers.c`. Pins in `c/third_party/VERSIONS.md`. Residual: a few **in-tree** codecs (minimal UBJSON, log name `protobuf-wire`) — document, do not mislabel as third-party Google upb.

### 2. Rust schema/zero-copy intermediate payloads (MEDIUM) — **fixed**

**Problem (historical):** `rkyv` / `prost` / `minicbor` once wrapped intermediate MessagePack.

**Fixed:** `prost-build` from `schemas/v2/protobuf/benchmark_v2.proto`; full `rkyv` `Archive` on concrete types; direct `minicbor` `Encode`/`Decode`; inventory on [Rust overview](../docs/rust/index.md).

### 3. Stream mode is often adapted (MEDIUM) — **open**

**Problem:** Several harnesses time the same buffer path for both `bytes` and `stream`, so stream columns may not show real incremental I/O cost.

**Remaining:** Per-serializer `Write`/`Read` / Node streams / C `FILE*` where APIs exist. Prefer emitting honest `StreamMode=native|adapted`. Analysis can still compare modes; interpret with caution ([methodology](../docs/analysis/ANALYSIS_METHODOLOGY.md)).

### 4. Cross-language absolute ns comparisons (MEDIUM, conceptual)

**Problem:** Comparing Rust `sonic-rs` ns to Python `orjson` ns invites invalid conclusions.

**Mitigation:** Reports group by language; effect sizes are within (language, data, mode). Emphasize **within-language ranks**, not absolute cross-runtime champions.

### 5. Fidelity is heuristic (LOW–MEDIUM)

**Problem:** Semantic equality via JSON/string compare loses datetime precision and Avro/protobuf field presence nuances.

**Mitigation:** Errors logged; fidelity score column present. For papers, define acceptance criteria per format family.

### 6. Environment capture (MEDIUM) — **mostly fixed**

**Problem:** Frequency scaling, noisy neighbors, and package versions affect latency tails.

**Fixed:** `*.configs.json` sidecars via `benchmark_analysis.environment` (CPU, OS, memory, runtimes, git, dataset, serializers). Reports surface key fields. Legacy `*.environment.json` still loadable.

**Still optional for research-grade isolation:** CPU governor, affinity, quiet machine — document/require for `research` mode; not automated.

### 7. Analysis dependencies not always installed (LOW)

**Problem:** `numpy`/plots require the analysis package install; CLI fails on bare Python.

**Mitigation:** Document `pip install -e analysis/` or `uv`; CI installs `analysis/.[dev]`. Host check lists `python3` / `uv`.

## Improvements implemented in the v2 framework era

| Improvement | Where |
|-------------|--------|
| Master YAML config | `config/benchmark_config.yaml` |
| Scientific stats module | `analysis/src/benchmark_analysis/stats.py` |
| Multi-lang CLI | `analysis/src/benchmark_analysis/cli.py` |
| Parser `Language` + optional columns | `analysis/src/benchmark_analysis/parser.py` |
| Version compare report | `--compare-a` / `--compare-b` |
| Language harnesses + docs | `c-sharp/`, `python/`, `rust/`, `c/`, `javascript/`, `go/`, `java/`, `cpp/`, `docs/*` |
| Orchestrator multi-lang | `scripts/run-all-benchmarks.sh` |
| Host toolchain check/install | `scripts/check-host-requirements.sh`, `install-host-requirements.sh` |
| Native runners (no Docker) | language `scripts/run-benchmarks.sh` |
| CI native smoke matrix | `.github/workflows/benchmark-ci.yml` |
| Extensibility guide | `docs/analysis/ADDING_A_LANGUAGE.md` |
| Unit tests | `analysis/tests/`, `javascript/test/`, `python/tests/` |
| Methodology | `docs/analysis/ANALYSIS_METHODOLOGY.md` |
| Run sidecars | `*.configs.json` (`environment` block) |

## Recommended next PRs (priority order)

Status of the original list:

| # | Item | Status |
|---|------|--------|
| 1 | Vendor real C libraries | **Done** |
| 2 | prost-build + rkyv on concrete types | **Done** |
| 3 | True stream implementations | **Open** (main remaining MEDIUM scientific gap) |
| 4 | Environment capture + report headers | **Done** as `*.configs.json` (+ report summary) |
| 5 | Bayesian hierarchical model | **Open** (optional research) |
| 6 | Go + Java harnesses | **Go done**; **Java not started** |
| 7 | CI matrix native toolchains | **Done** (keep in sync when runners change) |

**Priority from here:**

1. **True stream implementations** per language/library (phased; emit `native` vs `adapted`).
2. **Java harness** on the same CSV / run-config contract.
3. **Research-mode environment discipline** (governor, affinity, quiet host) — docs + optional sidecar fields.
4. **Bayesian hierarchical model** (optional) for multi-run / multi-machine meta-analysis.

## Bottom line

The repo is a **multi-language benchmark framework** with statistics appropriate for a methods section, real C library linkage, honest Rust schema/zero-copy paths, Go coverage, and native CI smokes. It is **not** a source of unadjusted “world champion serializer” tables across runtimes: **adapted stream modes** and **cross-language absolute latency** still require careful scoping. Prefer within-language, within-payload comparisons; report CIs and effect sizes; treat exploratory leaderboards accordingly.
