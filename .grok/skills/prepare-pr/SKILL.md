---
name: prepare-pr
description: >
  End-to-end pre-PR gate for the serializer-benchmark monorepo: refuse master/main,
  run full test suites, full multi-language benchmarks, fail on non-empty
  logs/<lang>/*.errors.csv, regenerate analysis artifacts, update dashboard data
  (dashboard/scripts/sync-data.py → public/data/*_latest.json.gz), commit, push,
  and draft a short PR description. Use when the user runs /prepare-pr, says
  "prepare a PR", "ready for review", "pre-PR gate", or "full PR validation".
metadata:
  short-description: "Test, bench, analyze, dashboard sync, push, PR body"
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

Hard fail if analysis exits non-zero or expected result pages/plots are missing after a full run.

---

## 6. Update dashboard data (**required**)

After benchmarks + analysis succeed, **always** refresh the analytics web dashboard payloads from the latest logs. This is a **first-class gate step**, not optional.

```bash
python3 dashboard/scripts/sync-data.py
```

**What it must update** (under `dashboard/public/data/`):

| Artifact | Purpose |
|----------|---------|
| `<lang>_latest.json.gz` | Compact stats + configs + errors + CSV slice per language (c, csharp, go, javascript, python, rust, …) |
| `available_runs.json` | Historical run-id list for the dashboard run picker |
| logs symlink (if used) | Local logs discovery for the dashboard |

**Verify before commit:**

```bash
# Each enabled language’s latest payload run_id should match STEM from step 3
python3 - <<'PY'
import gzip, json
from pathlib import Path
root = Path("dashboard/public/data")
for p in sorted(root.glob("*_latest.json.gz")):
    d = json.loads(gzip.open(p).read())
    print(f"{p.name}: run_id={d.get('run_id')} language={d.get('language')}")
runs = json.loads((root / "available_runs.json").read_text())
print("available_runs keys:", sorted(runs.keys()))
PY
```

Hard fail if `sync-data.py` exits non-zero or any enabled language is missing a `*_latest.json.gz` after sync.

**Do not** force-add raw `logs/**` CSVs (gitignored). **Do** stage the updated `dashboard/public/data/*` artifacts in step 7.

Avoid re-running sync solely to “touch” files when content is already current (gzip recompression can churn binaries with identical JSON).

---

## 7. Commit

```bash
git status
git diff --stat
git log -5 --oneline
```

- Stage **source**, **published docs** (results, plots, METRICS, skill files), and **dashboard data** (`dashboard/public/data/*_latest.json.gz`, `available_runs.json`).
- **Do not** force-add gitignored `logs/**` raw CSVs.
- If nothing to commit: print that and continue to push if remote is behind.
- Commit message: short, matches repo style; summarize branch intent vs base (`master`/`main`).
- Never commit secrets (`.env`, credentials).

---

## 8. Push

User invoked prepare-pr (explicit intent to publish the branch):

```bash
git push -u origin HEAD
```

On rejection: report output and **stop**.

---

## 9. Short PR description

Build a short body from `git log origin/master..HEAD` (or `main`) and validation results:

```markdown
## Summary
- <2–4 bullets from branch commits>

## Validation
- Tests: analysis / python / js (pass)
- Benchmarks: <mode>, stem `<STEM>`
- Error CSVs: clean (or list failures — should not ship)
- Analysis: results + violin plots regenerated
- Dashboard: `sync-data.py` → `*_latest.json.gz` + `available_runs.json` for stem `<STEM>`

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

## Helper scripts

| Script | Purpose |
|--------|---------|
| `.grok/skills/prepare-pr/scripts/check-error-csvs.sh [STEM]` | Exit 1 on **new** error keys (regression) or any rows (strict) |
| `dashboard/scripts/sync-data.py` | Build compressed dashboard payloads + `available_runs.json` from latest logs |

---

## Stop conditions (summary)

| Condition | Action |
|-----------|--------|
| On `master` / `main` / detached | Ask for new branch; do not proceed |
| Tests fail | Stop |
| Benchmarks fail | Stop |
| Error CSV regression (or strict non-empty) | Stop |
| Analysis fails | Stop |
| Dashboard `sync-data.py` fails or missing `*_latest.json.gz` | Stop |
| Push rejected | Stop; report |

