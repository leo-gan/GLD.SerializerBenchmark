# Implementation Critique & Immediate Improvements

This document records an unvarnished review of the v2 refactor and what was fixed in-tree vs what remains.

## What is solid

1. **Unified config** (`config/benchmark_config.yaml`) — parameters are no longer scattered magic numbers.
2. **CSV contract with `Language`** — analysis is language-agnostic; adding Go/Java is documentation + harness, not analysis rewrites.
3. **Scientific stats** — bootstrap CI, Cliff's δ, Hedges' g, Mann–Whitney + Holm are appropriate for non-normal latency data; means-only reporting is insufficient for a paper.
4. **A/B path** — serializer authors have a first-class comparison mode, not a spreadsheet exercise.
5. **Three new harnesses** (Rust/C/JS) with ≥10 serializers each, docs, and runner scripts aligned with C#/Python modes.

## What was weak (and partially fixed)

### 1. C benchmark honesty (HIGH severity for a paper)

**Problem:** Default C build uses minimal JSON/binary *stand-ins* labeled with real library names (`cJSON`, `yyjson`, …). Citing those numbers as "yyjson vs cJSON" would be **misleading**.

**Fixed in docs:** Prominent caveats in `c/README.md`, `docs/c/*`, and methodology limitations.

**Not fully fixed in code:** Real library linkage is opt-in (vendoring + replace `register_serializers.c` bodies). For publication, **must** vendor yyjson/cJSON/mpack/tinycbor and time their optimal APIs. Until then, treat C results as **pipeline validation**, not library ranking.

### 2. Rust schema/zero-copy serializers are intermediate-payload based (MEDIUM)

**Problem:** `rkyv`, `prost-wire`, `minicbor` archive/wrap MessagePack bytes because untagged multi-type `Fixture` does not derive cleanly on all crates. That measures envelope overhead, not full `#[derive(Archive)]` / `prost-build` paths.

**Fixed:** Switched intermediate from postcard (fails on some f64/EDI cases) to MessagePack; documented caveats.

**Remaining:** Add `prost-build` from `schemas/benchmark_data.proto` and `rkyv` derives on concrete structs for paper-grade schema/zero-copy sections.

### 3. Stream mode is often fake (MEDIUM)

**Problem:** Several harnesses time the same buffer path for both `bytes` and `stream`, so stream columns may not show real incremental I/O cost.

**Remaining:** Per-serializer `Write`/`Read` / Node streams / C `FILE*` adapters. Analysis can still compare modes, but interpret with caution (documented in methodology).

### 4. Cross-language absolute ns comparisons (MEDIUM, conceptual)

**Problem:** Comparing Rust `sonic-rs` ns to Python `orjson` ns invites invalid conclusions (different heaps, GC, safety checks).

**Mitigation:** Reports group by language; effect sizes are within (language, data, mode). Papers should emphasize **within-language ranks** and normalized ratios, not absolute cross-runtime champions.

### 5. Fidelity is heuristic (LOW–MEDIUM)

**Problem:** Semantic equality via JSON/string compare loses datetime precision and Avro/protobuf field presence nuances.

**Mitigation:** Errors logged; fidelity score column present. For papers, define acceptance criteria per format family.

### 6. No environment pinning in default runs (MEDIUM)

**Problem:** Frequency scaling, noisy neighbors, and package versions affect latency tails.

**Partial fix:** Config has `reproducibility.capture_environment`; implement writers that dump `environment.json` (CPU model, governor, versions) beside logs — recommended before `research` mode runs.

### 7. Analysis dependencies not always installed (LOW)

**Problem:** `numpy`/plots require the analysis package install; CLI fails on bare Python.

**Mitigation:** Document `pip install -e analysis/`; tests live under `analysis/tests/`.

## Improvements implemented immediately in this refactor

| Improvement | Where |
|-------------|--------|
| Master YAML config | `config/benchmark_config.yaml` |
| Scientific stats module | `analysis/src/benchmark_analysis/stats.py` |
| Multi-lang CLI | `analysis/src/benchmark_analysis/cli.py` |
| Parser `Language` + optional columns | `analysis/src/benchmark_analysis/parser.py` |
| Version compare report | `--compare-a` / `--compare-b` |
| Rust / C / JS harnesses + docs | `rust/`, `c/`, `javascript/`, `docs/*` |
| Orchestrator multi-lang | `scripts/run-all-benchmarks.sh` |
| Extensibility guide | `docs/architecture/ADDING_A_LANGUAGE.md` |
| Unit tests | `analysis/tests/`, `javascript/test/`, `python/tests/` |
| Methodology v2 section | `docs/analysis/ANALYSIS_METHODOLOGY.md` |

## Recommended next PRs (priority order)

1. **Vendor real C libraries** and replace stand-in codecs (blocks credible C paper section).
2. **prost-build + rkyv derives** on concrete Rust types from shared schema.
3. **True stream implementations** per language/library.
4. **`environment.json` capture** + document hardware/OS in every report header.
5. **Bayesian hierarchical model** (optional) for multi-run meta-analysis across machines.
6. **Go + Java** harnesses using the same contract (highest ecosystem value after C#/Python/Rust).
7. **CI matrix** running smoke for all five languages without requiring Docker for Python (local `uv run` path).

## Bottom line

The repo is now a **credible multi-language benchmark *framework*** with statistics appropriate for a methods section. It is **not yet** a turnkey source of unadjusted "world champion serializer" tables: C stand-ins, intermediate Rust schema paths, and pseudo-stream modes must be fixed or explicitly scoped before claiming library-level superiority in a peer-reviewed venue. Use within-language, within-payload comparisons, report CIs and effect sizes, and treat cross-language numbers as exploratory.
