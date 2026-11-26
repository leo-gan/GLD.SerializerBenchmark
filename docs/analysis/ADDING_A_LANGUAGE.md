# Adding a Language

This checklist specifies every repository surface required to onboard a new programming language benchmark runner without modifying the shared statistical core. To add a single codec to an existing language, see [Adding a serializer](ADDING_A_SERIALIZER.md). Reference specifications: [Architecture](architecture.md) · [Timing contract](TIMING_HONESTY.md) · [Data sets](test_data_configuration.md) · [I/O & run modes](modes.md).

Experience onboarding later languages confirmed that `config/benchmark_config.yaml` is only one of several closed-set language registries; omitting any downstream consumer causes the runner to execute normally while remaining invisible in analysis, Dashboard, experiments, or CI.

## 1. Choose a Collision-Safe Language ID

Select a short lowercase identifier (`php`, `kotlin`, `zig`, `mojo`, `fortran`) and check for path-substring collisions before creating directories:

| Existing Pattern | Path-Matching Rule |
|---|---|
| `c` vs. `c-sharp` vs. `cpp` | Match longer path tokens first (`c-sharp/` and `cpp/` before `c/`). |
| `java` vs. `javascript` vs. `kotlin` | Match `/javascript/` and `/kotlin/` before `/java/` (Kotlin Gradle trees contain `src/main/java`). |
| Any new id | If the new id is a prefix or substring of an existing token (or vice versa), insert the longer token first in every path-inference table. |

## 2. Register Across All Closed-Set Consumers

Add the language block under `languages:` in `config/benchmark_config.yaml` (`display_name`, `enabled`, `runner_dir`, `runner_script`, `log_dir`, `time_unit: nanoseconds`, `docs_dir`, `serializers`), and register the id in every consumer below:

| Subsystem | Files & Symbols to Update |
|---|---|
| **Analysis package** | `analysis/.../cli.py` (`_KNOWN_LANGS`, `_LANG_ALIASES`), `config_loader.py` (fallback tuple), `reports.py` (fallback list), `environment.py` (`_infer_language`, collision-ordered) |
| **Dashboard** | `dashboard/main.js` (`LANGUAGE_CATALOG`, alphabetical by label), `dashboard/experiments.js` (`LANG_LABELS`), `dashboard/exp-charts.js` (if present), `dashboard/scripts/sync-data.py` (`languages = [...]`) |
| **Navigation & docs** | `docs/javascripts/languages-nav.js` (`DOCS_DIR_TO_LANG`), `mkdocs.yml` (`Languages` section, alphabetical), `docs/languages/index.md` (Runtime Matrix), `docs/index.md` (Languages table & lead count), `docs/analysis/architecture.md` (layout list), `docs/analysis/ADDING_A_SERIALIZER.md` (manifest table), root `README.md` |
| **Experiments** | `experiments/lib/experiment.config.schema.json` (`languages.id.enum`), `experiments/lib/experiment_config.py` (`RUNNERS`), every `experiments/*/run.sh` (`RUNNER` map) |
| **Host & CI scripts** | `scripts/check-host-requirements.sh` & `scripts/install-host-requirements.sh` (`KNOWN`, `TARGETS`), `scripts/run-all-benchmarks.sh` (verify auto-discovery), `.github/workflows/benchmark-ci.yml` (`changes` output, `dorny/paths-filter`, `<lang>-benchmark` job, analysis smoke assertion) |

## 3. Implement the Benchmark Runner Contract

Use an existing mature runner (such as `rust/`, `zig/`, or `kotlin/`) as a structural reference and satisfy every requirement in [Benchmark architecture](architecture.md#harness-contract-summary) and [Timing contract](TIMING_HONESTY.md):

1. **CSV contract:** Write `logs/<lang>/YYYY-MM-DD-HHMMSS.csv` with timings in **nanoseconds**, runtime `SerializerVersion`, `DataTypeInstanceCount`, `TypeConfigHash`, and honest `StreamMode` (`native`, `text_on_stream`, `adapted`, or `bytes`-only if no distinct stream path exists).
2. **Schedule & warmup:** Implement `block_shuffle` matching golden vector `[C, B, A]` ([Architecture](architecture.md#timed-trial-schedule)) and always log repetition index `0` (analysis drops warmup).
3. **Suite data types:** Implement deterministic `make_one` generators for `message`, `document`, `telemetry`, `strings`, and `event` matching `schemas/data_catalog_v2.yaml` and wire IDLs under `schemas/v2/`. Expand run-config cells with `./scripts/resolve_run_config.py`. Add `columnar`, `graph`, `array`, or `tensor` support whenever the language has qualified libraries.
4. **Runner wrapper script:** Implement `<dir>/scripts/run-benchmarks.sh` accepting `smoke | all-single | full | research`, sourcing `scripts/lib/config.sh` (`bench_mode_reps`, `bench_random_seed`), and honoring `LOG_DIR` and `BENCHMARK_RUN_CONFIG` for experiment runners.
5. **Sidecar & fidelity:** Verify semantic round trips after deserialize (writing failures to `*.errors.csv`) and emit a `*.configs.json` sidecar containing `environment.machine_id`, runtime versions, and schedule metadata.

## 4. Verify, Run Experiments, and Pack Dashboard Data

1. **Smoke and full benchmark (changed language only):**
   ```bash
   ./scripts/check-host-requirements.sh <lang>
   ./scripts/run-all-benchmarks.sh --mode smoke --lang <lang>
   ./scripts/run-all-benchmarks.sh --mode full --lang <lang> --analyze
   ```
   Audit the resulting CSV for realistic wire sizes vs. same-standard peers, non-empty `SerializerVersion`, `FidelityScore = 1.0`, and zero unexpected `*.errors.csv` rows.
2. **Compliance:** Execute `./scripts/run-compliance.sh --lang <lang>` and verify `logs/compliance/latest-<lang>.json` is produced.
3. **Experiments:** For each applicable experiment (`01-sensor-list-size`, `02-compression-size`, `03-memory-vs-stream`, `04-fortran-ffi-tax`), add a `languages:` block to `experiments/<id>/experiment.yaml`, add `experiments/<id>/<lang>/run.sh`, run `./experiments/<id>/run.sh <lang>`, and verify `languages.<lang>.status = ok` in `results.json`. Do not run `summarize.py --all` after a single-language execution.
4. **Pack Dashboard data:**
   ```bash
   python3 dashboard/scripts/sync-data.py
   python3 dashboard/scripts/sync-experiments.py
   ```
   Commit only the new language's `dashboard/public/data/<lang>_latest.json.gz`, `stats_<lang>_latest.json.gz`, updated `available_runs.json`, and updated experiment payloads; restore any unrelated `.json.gz` files touched solely by gzip recompression. Note that Vite outputs the built Dashboard to `docs/dashboard/` (`npm run build` inside `dashboard/`).

## 5. Author Language Documentation and Call-Site Note

1. Create `docs/<lang>/index.md` following the uniform five-section specification (`Runtime & Environment`, `Registered Serializers`, `Measurement Caveats`, `Results & Further Reading`), populate `config/serializer-specifics.json`, and run `write-serializer-sources.py` + `apply-serializer-sources-to-docs.py`.
2. Author at least one source-level call-site note under `docs/analysis/call-sites/<lang>-*.md` comparing two timed adapters on `document` ($n = 1$, `bytes`). Link it from `docs/analysis/call-sites/index.md`, `mkdocs.yml`, `docs/analysis/TIMING_HONESTY.md`, and `docs/<lang>/index.md`.
3. Validate documentation and strict MkDocs build before opening a pull request:
   ```bash
   python3 scripts/check-docs.py
   mkdocs build --strict
   ```
