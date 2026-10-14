# Artifact types

This is the complete list. A verify-project run accounts for every id below
(in the report as a finding, as checked, or as not checked with a reason).

Derived files are copies or projections. When they disagree with the source,
the defect is drift. Do not hand-edit the copy. Re-run the author when a fix
is requested.

| Source | Derived | Author |
|--------|---------|--------|
| `dashboard/scripts/write-compliance-catalog.py` | `compliance/serializer-standards.json`, `dashboard/compliance-catalog.js` | that script |
| `dashboard/scripts/write-serializer-sources.py` | `config/serializer-sources.json`, then the dashboard copies | that script, then `scripts/apply-serializer-sources-to-docs.py` for `docs/<lang>/index.md` Specifics |
| `compliance/serializer-standards.json` + `schemas/data_catalog_v2.yaml` + `config/dimensions.yaml` | `dashboard/public/data/dimension-labels.json` | no single author script; the analysis helpers `standard_for` and `data_set_for_type` are the rule |
| `dashboard/public/data/` | `docs/dashboard/data/` | Vite build (`dashboard/vite.config.js` `outDir` is `docs/dashboard`) |
| `schemas/` | per-language `gen` / `generated` / `dagr_gen` trees | `scripts/schemas/generate-all.sh` and the language generate scripts |
| `experiments/<id>/experiment.yaml` | `dashboard/public/data/experiments/` | `dashboard/scripts/sync-experiments.py` |

`config/serializer-sources.json` is not hand-edited. `config/README.md` says so.

## Registry and measurement contract

### language-registry
Enabled languages in `config/benchmark_config.yaml` (`languages`, `paths.language_log_dirs`). Must match CI path filters in `.github/workflows/benchmark-ci.yml`, the mkdocs Languages nav, `docs/javascripts/languages-nav.js`, `scripts/check-host-requirements.sh` `KNOWN`, each `runner_dir`/`runner_script`, and `docs/<lang>/index.md`. Script checks this.

### readme
Root `README.md`: language count badge, Supported languages list, commands, and mode names. Counts come from the language registry, not from a sentence someone remembers.

### run-modes
`modes` in `config/benchmark_config.yaml` (`smoke`, `all-single`, `full`, `research`) and the repetitions runners read via `scripts/read-config.py`. Docs that quote a repetition count must match. CI `workflow_dispatch` choices are the same mode names.

### csv-contract
`csv_schema` in `config/benchmark_config.yaml`: required columns, optional columns, time unit nanoseconds, log filenames (`YYYY-MM-DD-HHMMSS.csv`, `.configs.json`, `.errors.csv`).

### metrics-catalog
`metrics` in `config/benchmark_config.yaml`, including `catalog_version`. Prose catalog: `docs/analysis/METRICS.md`.

### statistics-policy
`statistics` and `regression` in `config/benchmark_config.yaml`. Prose: `docs/analysis/ANALYSIS_METHODOLOGY.md`. Warmup row is logged and then dropped by analysis.

### data-catalog
`schemas/data_catalog_v2.yaml`. Type ids, `data_set`, primitives, forbidden `type_config` keys. Prose: `docs/analysis/test_data_configuration.md` and `docs/analysis/data_model_v2.md`. `analysis/tests/test_dimensions.py` owns the suite/columnar/graph/array membership sets.

### run-matrices
`config/library/*.yaml` (`default`, `smoke`, `columnar`, `columnar-smoke`, `graph`, `array`, `array-smoke`). Type ids and `data_model_version` must exist in the data catalog. Columnar, graph, and array matrices are not part of `default.yaml`.

### dimension-contract
`config/dimensions.yaml`. Standard catalog path, empty list → `custom`, primary id when a serializer has several standards, data-set ids, optional-I/O rules (who is in-memory only, same-size parent vs Base64 child).

### optional-io-list
`config/optional-io.txt`. Names that may publish a second I/O level. `analysis/tests/test_dimensions.py` checks this list against the dimension contract.

### file-only-list
`config/file-only.txt`. Serializers with no in-memory bytes API. Their published parent is the native stream/file row. Script checks each name against the standards catalog.

## Schemas, generators, dependencies

### shared-schemas
`schemas/v2/` (protobuf, Avro, Dagr `schema.py`, SBE XML, FlatBuffers/Cap'n Proto schemas that live under language trees but describe the shared suite). One logical model. Field names, tags, and nullability that must agree across languages are a design flaw when they do not.

### generated-bindings
Committed generator output: `go/gen`, `cpp/gen`, `cpp/dagr_gen`, `rust/gen`, `rust/dagr_gen`, `python/generated`, `javascript/src/generated`, `mojo/src/gen`, `swift/DagrGen`, `zig/src/gen`, `java` and `kotlin` generated Cap'n Proto/FlatBuffers/protobuf trees, `c-sharp/src/Protobuf`, `php/src/Generated`. A hand edit inside a generated file is a design flaw. `scripts/schemas/check-generated.sh` regenerates and then diffs only the paths it lists. Read that script for the current list. Other generated trees are not gated by it. The script writes the tree, so do not run it during a read-only verify.

### schema-tooling
`scripts/schemas/` (`generate-all.sh`, `generate-protobuf.sh`, `check-generated.sh`, `tool-versions.env`). Tool versions named here must be the versions CI installs.

### dependency-pins
Language manifests and lockfiles: `pyproject.toml` files, `package.json` / lock, `Cargo.toml` / `Cargo.lock`, `go.mod` / `go.sum`, `pom.xml`, `build.gradle.kts`, `composer.json` / lock, `fpm.toml`, `build.zig.zon`, `pixi.toml` / `pixi.lock`, `*.csproj`. A pin is the version the runner is supposed to measure. `SerializerVersion` in a published snapshot is the version that was measured. Those are different facts; a mismatch is a finding.

### vendored-trees
Committed or local third-party trees: `mojo/vendor`, `kotlin/vendor`, `compliance/vendor`, `c/third_party`, `cpp/third_party`, `php/vendor`, language `node_modules`. `c/third_party/VERSIONS.md` and `cpp/third_party/VERSIONS.md` are the pin notes. Do not review upstream code style. Do check that the runner documents the vendored revision it compiles.

### repo-version
The suite version that must match across `pyproject.toml`, `python/pyproject.toml`, `analysis/pyproject.toml`, `mojo/pixi.toml` (`workspace.version`), `rust/Cargo.toml` (`package.version`), `dashboard/package.json`, `javascript/package.json`. Generated crates (`rust/gen/sbe`, `rust/dagr_gen`) keep their own version. Script checks the suite set.

## Runners and compliance

### harness-runners
One tree per enabled language (`runner_dir` in the language registry): runner, data generators, serializer wrappers, tests, `scripts/run-benchmarks.sh`. Contract: `docs/analysis/TIMING_HONESTY.md`, `docs/analysis/architecture.md` (schedule, CSV, nanoseconds, fidelity), `docs/analysis/ADDING_A_LANGUAGE.md`.

### serializer-roster
The names a language actually registers, the `serializers:` list in `benchmark_config.yaml` when present, the inventory table in `docs/<lang>/index.md`, `config/serializer-sources.json`, and `compliance/serializer-standards.json`. The same display name is one serializer. Aliases that the dashboard must apply live in `dashboard/compliance-groups.js` `SERIALIZER_ALIASES`. Script compares sources to standards.

### compliance-corpora
`compliance/data/<standard>/*.json`. Directory name is the standard id. Script compares directories to `FORMAT_LABELS` in `dashboard/compliance-groups.js`.

### compliance-standards
`compliance/serializer-standards.json` (authored by `write-compliance-catalog.py`). Lists of standard ids per serializer. Empty list means no public spec (`custom`), not a failure. Several ids need a primary in `config/dimensions.yaml`.

### compliance-adapters
Per-language compliance executables (for example `c/src/compliance.c`, `go/compliance`, `fortran/app/compliance.f90`, and the equivalents). A standard is scored only where this language has an adapter. An empty cell is not a pass or a fail.

### compliance-docs
`docs/compliance/*.md` and the Compliance section of `mkdocs.yml`. One page per standard id, plus the meta pages `index`, `reading-results`, `adapters`, `legal`. Script compares pages, nav, and corpora.

### compliance-legal
`compliance/LEGAL.md`, `compliance/THIRD_PARTY_NOTICES.md`, `compliance/vendor/*`, `docs/compliance/legal.md`. A corpus imported from upstream needs the notice that matches `compliance/data`.

### compliance-results
`logs/compliance/latest.json` and `latest-<lang>.json` (gitignored, local). Published pack: `dashboard/public/data/compliance.json.gz`. Scores must cite the corpus the adapter ran. Do not treat a missing adapter as zero.

### serializer-sources
`config/serializer-sources.json` plus `dashboard/public/data/serializer-sources.json` and `docs/dashboard/data/serializer-sources.json`. Specifics headings in `docs/<lang>/index.md` are applied from this file. Script compares the three JSON documents and the name sets against the standards catalog.

## Results and dashboard

### benchmark-logs
`logs/<lang>/YYYY-MM-DD-HHMMSS.csv` and sidecars. Gitignored. Local files are evidence of the csv contract. Missing logs are not a failure. Publication CSVs that are not timestamp stems (`*-columnar-*`, `*-dagr-*`, `*-graph-*`, `*-array-*`) are inputs to the splice scripts, not to `sync-data.py` alone.

### analysis-package
`analysis/` (`analyze-benchmarks`, dimensions, schedule, I/O folding, tests). Golden schedule vector is `analysis/tests/test_schedule.py`.

### reports
`reports/` (gitignored): `stats_<lang>_latest.json`, `baseline.json`, plots. Analysis output before dashboard packing.

### published-snapshots
`dashboard/public/data/*_latest.json.gz`, `stats_*_latest.json.gz`, `available_runs.json`, `dimension-labels.json`, `baseline.json`, `compliance.json.gz`. One parent row per comparison cell. `all@` averages only the five suite types. Columnar, graph, and array rows stay out of that average. Script checks labels, names, type ids, and that this tree matches the deployed copy.

### publication-scripts
`dashboard/scripts/sync-data.py`, `sync-compliance.py`, `sync-experiments.py`, `splice-columnar-stats.py`, `splice-dagr-stats.py`, `splice-graph-stats.py`, `splice-array-stats.py`, `write-serializer-sources.py`, `write-compliance-catalog.py`, `scripts/apply-serializer-sources-to-docs.py`. A script that can drop a spliced family (columnar, Dagr, graph, array) without the matching `DASHBOARD_REPLACE_*=1` guard is a design flaw.

### dashboard-app
`dashboard/*.js`, `dashboard/*.css`, `dashboard/index.html`, `dashboard/test/`. Views: Overview, Compare, Experiments, Compliance. Filters: Language, Standard, Data set, Data type, Samples. Standard menu order and the No public spec label are part of the contract in the JS that builds those menus.

### dashboard-build
Vite output under `docs/dashboard/` (`index.html`, hashed assets, `data/`). `docs/dashboard/data` must match `dashboard/public/data` after a build. `docs/dashboard/logs` is a log archive, not the live `logs/` tree. Script compares the two `data/` trees. Uncompressed JSON beside a gzip is a leftover, not a second catalog.

## Experiments, docs, CI

### experiments
`experiments/<id>/` with `experiment.yaml` (`schema: gld.experiment.config/1`, id equals the folder name), `experiments/lib/experiment.config.schema.json`, `experiments/samples/`, `experiments/PLAN.md`. One folder, one question. The run block must measure that question.

### experiment-catalog
`dashboard/public/data/experiments/index.json` and `<id>.json.gz`, and the same paths under `docs/dashboard/data/experiments/`. Prose index: `docs/experiments/index.md`. Script compares folder ids to both published catalogs.

### docs-site
`mkdocs.yml`, `docs/` pages other than the per-language inventories and the compliance pages (those have their own ids), `docs_theme/`, `docs/assets/`, `docs/stylesheets/`, `docs/javascripts/`. The built `site/` directory is output, not a source.

### theory-course
`docs/theory/101`, `201`, `301`, `401`, and `docs/theory/assets/diagrams`. 101 and 201 are flat in the nav. 301 and 401 are grouped. A page that states a suite rule must match the contract, not an older design note.

### notebooks
`docs/theory/notebooks/` and `requirements-colab.txt`. A notebook that loads a serializer or a data shape must use the same names as the roster and the data catalog.

### ci-workflows
`.github/workflows/benchmark-ci.yml` and `docs.yml`. Every enabled language has a filter and a job. Shared contract globs are the specific schema paths, not `schemas/**`. Docs-only pushes do not bench. `docs.yml` deploys the site that is already in the tree; it does not re-bench.

### host-scripts
`scripts/check-host-requirements.sh`, `scripts/install-host-requirements.sh`, `scripts/run-all-benchmarks.sh`, `scripts/run-compliance.sh`, `scripts/lib/config.sh`, `scripts/read-config.py`, `scripts/resolve_run_config.py`. Language ids here are the registry ids.

### internal-notes
`docs/internal/`. Research notes. Not in the published nav. A published page that presents a rejected note as the suite design is a design flaw. The note itself can disagree with the product.

### agent-skills
`.grok/skills/*/SKILL.md`. Instructions for later sessions. A skill that names a path, a count, a mode, or a command that the repo no longer has will send the next session the wrong way.
