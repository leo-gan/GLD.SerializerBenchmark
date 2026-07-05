---
name: prepare-pr
description: >
  End-to-end pre-PR gate for the serializer-benchmark monorepo: refuse master/main,
  run full test suites, full multi-language benchmarks, fail on non-empty
  logs/<lang>/*.errors.csv, regenerate analysis artifacts, commit, push, and draft
  a short PR description. Use when the user runs /prepare-pr, says "prepare a PR",
  "ready for review", "pre-PR gate", or "full PR validation".
metadata:
  short-description: "Full test, benchmark, analyze, push, PR body"
---

# /prepare-pr — Pre-PR validation gate

Automate the monorepo review gate. **Stop on any hard failure** (do not push a broken branch).

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

Optional: user may pass a benchmark mode override (`smoke` | `all-single` | `full`). **Default: `full`.**

---

## 1. Branch guard

```bash
branch=$(git branch --show-current)
echo "Branch: ${branch:-DETACHED}"
```

**STOP** if:

- `branch` is empty (detached HEAD), or
- `branch` is exactly `master` or `main`

When stopped: ask the user for a **new branch name**. Only after they provide it, run `git checkout -b <name>`, then restart from step 1.

Otherwise continue.

---

## 2. Full test suite

All must exit 0:

```bash
# Analysis package
( cd analysis && uv run pytest -q )

# Python harness (if tests/ exists)
if [[ -d python/tests ]]; then ( cd python && uv run pytest -q ); fi

# JavaScript (if package has test script)
if [[ -f javascript/package.json ]] && grep -q '"test"' javascript/package.json; then
  ( cd javascript && npm test )
fi
```

Rust (optional): if `command -v cargo` succeeds:

```bash
( cd rust && cargo test -q ) || echo "[WARN] cargo test failed or skipped"
```

Only **fail the skill** if cargo is present **and** tests fail. Missing cargo → warn only.

---

## 3. Full benchmarks (all enabled languages)

```bash
mkdir -p logs
MODE="${PREPARE_PR_MODE:-full}"   # or user override smoke|all-single|full
LOG="logs/prepare-pr-$(date +%Y%m%d-%H%M%S).log"
./scripts/run-all-benchmarks.sh --mode "$MODE" --analyze 2>&1 | tee "$LOG"
```

- Shared `BENCHMARK_TS` is set by the orchestrator — capture it from the log (`Run timestamp:` line) or from the newest common stem under `logs/*/`.
- Long-running: use a high timeout / background + monitor until complete.

Hard fail if the script exits non-zero.

---

## 4. Error CSV gate (harness error **regressions**)

```bash
STEM="${BENCHMARK_TS:-}"  # prefer the stem from step 3
# Default: regression mode (fail only on NEW error keys vs previous stem)
.grok/skills/prepare-pr/scripts/check-error-csvs.sh ${STEM:+"$STEM"}
# Optional zero-tolerance: CHECK_ERRORS_MODE=strict .grok/skills/prepare-pr/scripts/check-error-csvs.sh ...
```

Rules (script enforces; note filename **`.errors.csv`**, plural):

- For each enabled language: require a result CSV for the stem (or latest).
- Paired file: `logs/<lang>/<stem>.errors.csv`.
- **regression (default):** fail only if error keys `(TestData, Serializer, Mode)` appear that were **not** in the previous run for that language. Known ongoing failures (e.g. unsupported fixtures) do not block.
- **strict:** fail on any data rows (opt-in via `CHECK_ERRORS_MODE=strict`).
- First run with no prior stem: warn, do not fail on existing errors.

Do **not** continue to push if the gate fails.

---

## 5. Analysis artifacts

Step 3 already passes `--analyze`. Re-run if needed for a clean pass:

```bash
if command -v analyze-benchmarks >/dev/null 2>&1; then
  analyze-benchmarks --logs-root logs --config config/benchmark_config.yaml
else
  ( cd analysis && uv run analyze-benchmarks --logs-root ../logs --config ../config/benchmark_config.yaml )
fi
```

Confirm updates under `docs/<lang>/results.md` and/or `docs/analysis/plots/violin/`.

---

## 5b. Prepare data for dashboard

Prepare the compact, compressed online results for the analytics web dashboard:

```bash
python3 dashboard/scripts/sync-data.py
```

This packages the stats, environment configuration, errors, and raw logs into compressed `*_latest.json.gz` files, compiles the available historical runs list, and updates the symlink to local logs.

---

## 6. Commit

```bash
git status
git diff --stat
git log -5 --oneline
```

- Stage source + published docs (results, plots, METRICS, skill files, etc.).
- **Do not** force-add gitignored `logs/**` raw CSVs.
- If nothing to commit: print that and continue to push if remote is behind.
- Commit message: short, matches repo style; summarize branch intent vs base (`master`/`main`).
- Never commit secrets (`.env`, credentials).

---

## 7. Push

User invoked prepare-pr (explicit intent to publish the branch):

```bash
git push -u origin HEAD
```

On rejection: report output and **stop**.

---

## 8. Short PR description

Build a short body from `git log origin/master..HEAD` (or `main`) and validation results:

```markdown
## Summary
- <2–4 bullets from branch commits>

## Validation
- Tests: analysis / python / js (pass)
- Benchmarks: <mode>, stem `<STEM>`
- Error CSVs: clean (or list failures — should not ship)
- Analysis: results + violin plots regenerated

## Notes
- …
```

If `gh` is available and authenticated:

```bash
# Existing PR?
gh pr view --json url,title 2>/dev/null || \
gh pr create --title "<short title from branch>" --body "$(cat <<'PR'
...body...
PR
)"
```

If no `gh`: print title + body for the user to paste on GitHub.

---

## Helper script

| Script | Purpose |
|--------|---------|
| `.grok/skills/prepare-pr/scripts/check-error-csvs.sh [STEM]` | Exit 1 if any language has error data rows |

---

## Stop conditions (summary)

| Condition | Action |
|-----------|--------|
| On `master` / `main` / detached | Ask for new branch; do not proceed |
| Tests fail | Stop |
| Benchmarks fail | Stop |
| Non-empty `*.errors.csv` data rows | Stop |
| Analysis fails | Stop |
| Push rejected | Stop; report |

