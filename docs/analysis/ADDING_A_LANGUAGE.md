# Adding a language

This page is a **checklist for implementers**. Follow it when you want a new programming language in the suite without changing the shared analysis core.

Background (layout, timing model, contract): [Benchmark architecture](architecture.md).  
I/O modes and run modes: [Modes](modes.md).  
Test data: [Test data](test_data_configuration.md).  
How CSVs become tables: [Analysis methodology](ANALYSIS_METHODOLOGY.md).  
**Only adding one library to an existing language?** Use [Adding a serializer](ADDING_A_SERIALIZER.md) instead.

Kotlin (2026) showed that `benchmark_config.yaml` is **not** the only registry. Analysis, the Dashboard, experiments, CI, and host scripts each keep a closed list of language ids. A runner that is missing from any of those lists will time correctly and still be invisible.

---

## Learning goals

After this page you should be able to:

1. Register a language in the master config **and** every closed-set consumer.
2. Implement a benchmark runner that writes a valid CSV and respects the timing rules.
3. Publish Dashboard payloads, experiment tabs, and a 401 call-site article.
4. Land the language with [prepare-pr](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/.grok/skills/prepare-pr/SKILL.md).

---

## 0. Choose the id

Use a short lowercase id (`php`, `kotlin`, `go`). Check substring collisions **before** you name the tree:

| Collision | Rule |
|-----------|------|
| `c` vs `csharp` vs `cpp` | Longer path token first; `c-sharp/*` before `c/*` in detect scripts |
| `java` vs `kotlin` | Match `/kotlin/` before `/java/`. A Kotlin Gradle tree contains `src/main/java` |
| New id | If the id is a substring of an existing path token (or the reverse), add it to every path-inference list **before** the shorter token |

Do not pick an id that is a prefix of another language’s folder (`java` inside `javascript` is already handled by matching `/javascript/` first).

---

## 1. Register the language

Edit **`config/benchmark_config.yaml`**. That file is read by `scripts/read-config.py`, `scripts/run-all-benchmarks.sh`, and `analyze-benchmarks`.

```yaml
languages:
  php:  # short lowercase id
    display_name: PHP
    enabled: true
    runner_dir: php
    runner_script: scripts/run-benchmarks.sh
    log_dir: logs/php
    time_unit: nanoseconds
    docs_dir: docs/php
    serializers: [...]
```

If your config uses `paths.language_log_dirs`, add `php: logs/php`.

### Closed-set consumers (required)

`languages.*.enabled` is **not** enough. Update every list below or the language will disappear in one surface.

| Consumer | What to add |
|----------|-------------|
| `analysis/.../cli.py` `_KNOWN_LANGS` / `_LANG_ALIASES` | id + aliases (`php`) |
| `analysis/.../config_loader.py` fallback tuple | id |
| `analysis/.../reports.py` fallback list | id |
| `analysis/.../environment.py` `_infer_language` | path token, **ordered** (see §0) |
| `dashboard/main.js` `LANGUAGE_CATALOG` | `{ id, label }` **alphabetical by label** |
| `dashboard/experiments.js` `LANG_LABELS` | id → display name |
| `dashboard/exp-charts.js` | same label map if present |
| `dashboard/scripts/sync-data.py` `languages = [...]` | id (otherwise no `php_latest.json.gz`) |
| `docs/javascripts/languages-nav.js` | id if that map is hardcoded |
| `experiments/lib/experiment.config.schema.json` `languages.id.enum` | id |
| `experiments/lib/experiment_config.py` `RUNNERS` | `php`: `php/scripts/run-benchmarks.sh` |
| every `experiments/*/run.sh` `RUNNER` map | `[php]="$REPO/php/scripts/run-benchmarks.sh"` |
| `.grok/skills/prepare-pr/scripts/detect-changed-langs.sh` | `php/*)` → `HIT[php]` |
| `scripts/check-host-requirements.sh` | `KNOWN` + default `TARGETS` |
| `scripts/install-host-requirements.sh` | same |
| `.github/workflows/benchmark-ci.yml` | `changes` output, `dorny/paths-filter` `php/**`, `php-benchmark` job, analysis grep |
| `mkdocs.yml` **Languages** nest | one-child Overview, **alphabetical by display name** |
| root `README.md` Supported languages | link + serializer count, **alphabetical** |
| `docs/analysis/index.md` language table | same order |
| `docs/analysis/architecture.md` runner-folder list | add `php/` |
| `docs/analysis/ADDING_A_SERIALIZER.md` | build + serializer-dir rows |
| `docs/analysis/ANALYSIS_METHODOLOGY.md` | `Language` column example list |

Leave historical prose such as `experiments/PLAN.md` (“nine languages”) alone unless you are rewriting that history.

---

## 2. Implement the benchmark runner contract

Meet the [benchmark runner contract](architecture.md#harness-contract-summary) and [measurement model](architecture.md#measurement-model). In particular:

| Requirement | Detail |
|-------------|--------|
| Output CSV | `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with columns from `csv_schema` |
| `Language` column | Must match the language id (for example `php`) |
| Time unit | **Nanoseconds** for all runners (including C#) |
| Modes | `bytes` and `stream` when there is a real second path (or `string` / `stream` on C#). If stream would be a label-only alias of bytes, emit **bytes only** |
| Stream honesty | On every stream row set CSV `StreamMode` to `native` \| `text_on_stream` \| `adapted` ([modes](modes.md#three-levels-of-stream-honesty)); never claim `native` if either timed half is still bytes |
| Warmup | Log repetition index 0; analysis excludes it from aggregates |
| Prepare outside the loop | Schema compile, type registration, buffer pools, bind data-type encode function — not timed |
| Timed section | Serialize and deserialize only |
| Schedule | Default `block_shuffle`: after prepare, nest `mode → rep → shuffled serializers`; match golden vector in [architecture — schedule](architecture.md#timed-trial-schedule); emit optional `RunOrder` |
| Output buffer | Runner-owned / pre-sized buffer reused across reps — see [timing rules](architecture.md#timing-methodology-suite-wide-issue-59) |
| Optimization barriers | `black_box` / `DoNotOptimize` / `KeepAlive` (or equivalent) on timed I/O for native compilers |
| Fidelity | Semantic round-trip check; write `logs/<lang>/<ts>.errors.csv` only when errors occur |
| Optional sidecars | `*.configs.json` (environment plus optional dataset / serializer metadata); include `schedule` strategy/seed when set |
| Seed | Master config `reproducibility.random_seed` / `BENCHMARK_SEED`; document the PRNG and any magic constants |

Use **official library APIs** on the timed path. Copy the newest language tree (Swift, then Kotlin) for the prepare / timed / fidelity shape; do not invent a second contract.

---

## 3. Test data types

Implement `make_one` (or the language equivalent) and run-config **cells** for the suite type ids:

`message` · `document` · `telemetry` · `strings` · `event`

See [Test data](test_data_configuration.md) for field shapes and batch rules.

- Expand cells with `./scripts/resolve_run_config.py`.
- Emit CSV columns `DataTypeInstanceCount` and `TypeConfigHash` when measuring batch cells.
- Generators live under each language tree (for example `python/.../data_v2`, `go/model/v2`, `rust/src/data_v2.rs`, `javascript/src/data_v2.js`, `kotlin/.../model/v2`).
- Wire schemas: `schemas/v2/` and `scripts/schemas/generate-all.sh`.
- Catalog defaults: `schemas/data_catalog_v2.yaml`.

---

## 4. Runner script

`runner_dir/scripts/run-benchmarks.sh` must accept modes:

`smoke` | `all-single` | `full` | `research`

Source `scripts/lib/config.sh` and use `bench_mode_reps "$MODE"` (reads `modes.<name>.repetitions`). Set `BENCHMARK_SEED` from `bench_random_seed`. Do **not** hard-code repetition counts.

Honor `LOG_DIR` and `BENCHMARK_RUN_CONFIG` so lab experiments can point at `experiments/<id>/run.yaml` and write under `experiments/<id>/<lang>/logs/<lang>/`.

---

## 5. First bench and suspicious results

1. Smoke: non-empty CSV, positive times, required columns.
2. `all-single` (or `full`) for this language only. Do **not** re-bench other languages to “complete” the matrix.
3. Run **review-suspicious-results** on that CSV: sizes that do not match the format, fidelity failures, and call paths that are not the official API.
4. Re-bench only this language after fixes.

---

## 6. Documentation

- `docs/<lang>/index.md` — ecosystem overview, registered inventory, caveats.
- After benchmarks: run `analyze-benchmarks` (unpublished `reports/<docs_dir>/results.md`) and pack Dashboard data (step 8).
- Register Overview under the **Languages** tab as a one-child nest in `mkdocs.yml`. The sidebar injects a Dashboard sibling.
- Keep **Supported languages** lists alphabetical by display name (README, docs analysis index, MkDocs Languages).

---

## 7. Experiments (required for the Experiments tab)

The Dashboard Experiments tab shows a language only when that experiment’s `results.json` has `languages.<id>.status = ok`. A `languages:` block in `experiment.yaml` is not enough.

For **each** `experiments/*/experiment.yaml` where this language can answer the question:

1. Add a `languages:` block. Map libraries the way Java or the nearest existing language does (JSON bakeoff → JSON libs; one-language store → native + portable; and so on). Use registry names from `config/benchmark_config.yaml`.
2. Add `experiments/<id>/<lang>/run.sh` that execs `../run.sh <lang>`.
3. Add the language to that experiment’s parent `run.sh` `RUNNER` map (and to `experiment_config.py` `RUNNERS` / the schema enum — once).
4. **Time it:** `./experiments/<id>/run.sh <lang>`. Then `python3 dashboard/scripts/sync-experiments.py`.

`summarize.py --language` already refreshes the combined `results.json`. A one-language run must **not** call `summarize.py --all`: leftover CSVs for other languages would rewrite their pages. `--all` must keep an existing `<lang>/results.json` when that folder has no CSV.

[prepare-pr](https://github.com/leo-gan/GLD.SerializerBenchmark/blob/master/.grok/skills/prepare-pr/SKILL.md) step 7 runs `run-experiments-for-langs.sh` for every changed language. Do not skip it.

---

## 8. Dashboard (required)

After the language bench and experiment runs:

```bash
python3 dashboard/scripts/sync-data.py
```

That writes `dashboard/public/data/<lang>_latest.json.gz`, `stats_<lang>_latest.json.gz`, `available_runs.json`, and the experiment catalog (`sync-experiments.py`).

**Do not** re-run sync only to “touch” files. gzip recompression churns other languages’ binaries even when the JSON is unchanged. If a full sync rewrote unrelated `*_latest.json.gz`, restore those binaries and keep only the new language plus `available_runs.json` / experiment payloads you actually updated.

Verify:

```bash
python3 - <<'PY'
import gzip, json
from pathlib import Path
root = Path("dashboard/public/data")
d = json.loads(gzip.open(root / "php_latest.json.gz").read())
print("run_id", d.get("run_id"), "language", d.get("language"))
print("available", "php" in json.loads((root / "available_runs.json").read_text()))
PY
```

Vite `outDir` is `docs/dashboard`, not `dist`. A local preview must be rebuilt (`npm run build` in `dashboard/`) or it will serve a stale copy.

---

## 9. Courses 101–401

| Course | Action |
|--------|--------|
| 101–301 | Language-agnostic. No roster change. |
| **401** | Add at least one timed-call-site article (`docs/theory/401/<lang>-*.md`) that opens two adapters on **document** n=1. Link it from `docs/theory/401/index.md`, `mkdocs.yml`, and [TIMING_HONESTY](TIMING_HONESTY.md). |

The first article usually compares the speed or size leader to the next interesting row (same bytes, two libraries; or same library, two encodings). Quote an L1 Dashboard slice; do not invent a ranking.

---

## 10. Wire orchestration and CI

Update `scripts/run-all-benchmarks.sh` if it does not already pick up `languages.*.enabled` automatically.

Analysis auto-discovers timestamped CSVs under `logs/<lang>/`. You can also pass explicit paths:

```bash
analyze-benchmarks --logs php=logs/php
```

Host scripts: `scripts/check-host-requirements.sh`, `scripts/install-host-requirements.sh`.

### GitHub Actions (required)

Update **`.github/workflows/benchmark-ci.yml`**:

1. `changes` job outputs and a `dorny/paths-filter` entry for `runner_dir/**` (and `schemas/**` if shared test data apply).
2. A new `*-benchmark` job: install the toolchain, run `check-host-requirements.sh <id>`, run `./scripts/run-benchmarks.sh` (smoke by default).
3. Analysis smoke step: assert the new id appears in `--enabled-langs` / `--lang-runners`.

Without this, pull requests that only touch the new benchmark runner never run it in CI.

---

## 11. Tests

At minimum:

- A smoke run produces a non-empty CSV.
- Times are positive.
- Required columns are present.
- Language-local unit tests for data models and registry (if the tree has a test runner).

Optional in prepare-pr: run those tests when the toolchain is present.

---

## 12. Prepare the PR

Stay off `master` / `main`. Run **prepare-pr**. That gate now:

1. Tests
2. Full bench **only** for changed languages
3. Error-CSV regression
4. Analysis artifacts
5. **Every experiment that enables those languages**
6. `sync-data.py` (Dashboard + experiment catalog)
7. Commit, push, PR body

Do not land a language whose Experiments tab is empty. That is how Kotlin shipped first and had to be filled in a follow-up.

---

## Suggested order

Do **1 → 0 (collisions) → 2–5 → 6 → 7 → 8 → 9 → 10–12**. Experiments and Dashboard last, after the harness is honest. prepare-pr is the last gate, not a substitute for the closed-set list.
