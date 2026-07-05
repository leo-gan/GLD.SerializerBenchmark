---
name: prepare-pr
description: >
  End-to-end pre-PR gate for the serializer-benchmark monorepo: refuse master/main,
  run full test suites, full benchmarks only for languages changed on the branch
  (detect-changed-langs.sh; override with PREPARE_PR_LANGS / PREPARE_PR_BENCH_ALL),
  fail on error-CSV regressions for those languages, regenerate analysis for them,
  update dashboard data (sync-data.py), commit, push, and draft a short PR
  description. Use when the user runs /prepare-pr, says "prepare a PR",
  "ready for review", "pre-PR gate", or "full PR validation".
metadata:
  short-description: "Test, changed-lang full bench, analyze, dashboard, PR"
---

# /prepare-pr — Pre-PR validation gate

Automate the monorepo review gate. **Stop on any hard failure** (do not push a broken branch).

Resolve repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

Optional overrides:

| Env / flag | Meaning |
|------------|---------|
| `PREPARE_PR_MODE` | `smoke` \| `all-single` \| `full` (default **`full`**) |
| `PREPARE_PR_LANGS` | Force language ids (comma or space), e.g. `c,javascript` — skip detection |
| `PREPARE_PR_BENCH_ALL=1` | Force full bench for **all** enabled languages |

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

## 3. Detect changed languages (**required before full bench**)

Default: run expensive full benchmarks **only** for languages whose **harness source** changed on this branch vs `main`/`master` merge-base.

```bash
CHANGED_LANGS=$(.grok/skills/prepare-pr/scripts/detect-changed-langs.sh)
# stdout: space-separated language ids (empty = no full bench needed)
# stderr: human diagnostics (forced / shared / skip)
echo "Changed languages for full bench: ${CHANGED_LANGS:-<none>}"
export PREPARE_PR_LANGS="${PREPARE_PR_LANGS:-$CHANGED_LANGS}"
```

### Detection rules (`detect-changed-langs.sh`)

| Path pattern | Effect |
|--------------|--------|
| `c/**` (not `c-sharp/**`) | → `c` |
| `c-sharp/**` | → `csharp` |
| `python/**` | → `python` |
| `rust/**` | → `rust` |
| `javascript/**` | → `javascript` |
| `go/**` | → `go` |
| `schemas/**`, `scripts/run-all-benchmarks.sh`, `scripts/lib/**`, `config/benchmark_config.yaml` | → **all** enabled languages |
| `docs/**`, `dashboard/public/data/**`, `logs/**`, `.grok/**` | **ignored** (regenerated / meta; do not select langs) |

Also considers unstaged/staged working-tree paths so uncommitted harness edits still trigger a re-bench.

**Empty `CHANGED_LANGS`:** skip step 4 full benchmarks (e.g. skill-only or docs-only PR). Still run analysis only if you intentionally regenerated logs; otherwise continue to dashboard sync (no churn expected) and commit.

**Override examples:**

```bash
PREPARE_PR_LANGS=c,javascript ./…     # force just these
PREPARE_PR_BENCH_ALL=1 ./…            # classic all-language full gate
```

---

## 4. Full benchmarks (**changed languages only**)

```bash
mkdir -p logs
MODE="${PREPARE_PR_MODE:-full}"
LOG="logs/prepare-pr-$(date +%Y%m%d-%H%M%S).log"

if [[ -z "${CHANGED_LANGS// }" ]]; then
  echo "[prepare-pr] No harness language changes — skipping full benchmarks" | tee -a "$LOG"
else
  # One orchestrator invocation per language so stems stay aligned when possible.
  # Prefer a single shared BENCHMARK_TS by exporting if the runners honor it;
  # otherwise capture the stem from each run’s log / newest CSV.
  {
    echo "Mode=$MODE langs=$CHANGED_LANGS"
    for lang in $CHANGED_LANGS; do
      echo "=== full bench: $lang ==="
      ./scripts/run-all-benchmarks.sh --mode "$MODE" --lang "$lang" --analyze
    done
  } 2>&1 | tee "$LOG"
fi
```

- Language id must match `config/benchmark_config.yaml` / `run-all-benchmarks.sh -l` (`c`, `csharp`, `python`, `rust`, `javascript`, `go`).
- Capture `BENCHMARK_TS` / stem from the log (`Run timestamp:`) or the newest result CSV under `logs/<lang>/` for **each** changed language.
- Long-running: high timeout / background + monitor.

Hard fail if any language run exits non-zero.

Do **not** re-bench unchanged languages “for completeness” unless `PREPARE_PR_BENCH_ALL=1` or a shared path forced all langs.

---

## 5. Error CSV gate (harness error **regressions**, changed langs only)

```bash
STEM="${BENCHMARK_TS:-}"  # prefer stem from step 4 when a single shared stem exists
# Check only languages that were benchmarked (or forced)
.grok/skills/prepare-pr/scripts/check-error-csvs.sh ${STEM:+"$STEM"} ${CHANGED_LANGS:+"$CHANGED_LANGS"}
# Optional zero-tolerance: CHECK_ERRORS_MODE=strict …
```

Rules (script enforces; note filename **`.errors.csv`**, plural):

- For each **selected** language: require a result CSV for the stem (or latest).
- Paired file: `logs/<lang>/<stem>.errors.csv` (header-only is OK).
- **regression (default):** fail only if error keys `(TestData, Serializer, Mode)` appear that were **not** in the previous run for that language.
- **strict:** fail on any data rows (opt-in via `CHECK_ERRORS_MODE=strict`).
- First run with no prior stem: warn, do not fail on existing errors.
- If step 4 skipped all langs, skip this gate (or run with empty filter only if you still have a STEM to validate).

Do **not** continue to push if the gate fails.

---

## 6. Analysis artifacts (changed languages)

Step 4 already passes `--analyze` per language. Re-run if needed for a clean pass **scoped to changed langs**:

```bash
if [[ -n "${CHANGED_LANGS// }" ]]; then
  for lang in $CHANGED_LANGS; do
    if command -v analyze-benchmarks >/dev/null 2>&1; then
      analyze-benchmarks -l "$lang" --logs-root logs --config config/benchmark_config.yaml
    else
      ( cd analysis && uv run analyze-benchmarks -l "$lang" --logs-root ../logs --config ../config/benchmark_config.yaml )
    fi
  done
fi
```

Confirm updates under `docs/<lang>/results.md` and/or `docs/analysis/plots/violin/<lang>_*.png` **for changed languages only**. Do not require rewrites of unrelated language result pages.

Hard fail if analysis exits non-zero for a language that was re-benched.

---

## 7. Update dashboard data (**required**)

After benchmarks + analysis (or a no-bench skill-only path), **always** refresh the analytics web dashboard payloads from the latest logs. This is a **first-class gate step**, not optional.

```bash
python3 dashboard/scripts/sync-data.py
```

`sync-data.py` rebuilds **all** `*_latest.json.gz` from each language’s **newest** log stem (unchanged languages keep their previous full-run latest on disk — no need to re-bench them).

**What it must update** (under `dashboard/public/data/`):

| Artifact | Purpose |
|----------|---------|
| `<lang>_latest.json.gz` | Compact stats + configs + errors + CSV slice per language |
| `available_runs.json` | Historical run-id list for the dashboard run picker |
| logs symlink (if used) | Local logs discovery for the dashboard |

**Verify before commit** (changed langs should show the new STEM; others may keep an older run_id):

```bash
python3 - <<'PY'
import gzip, json
from pathlib import Path
root = Path("dashboard/public/data")
for p in sorted(root.glob("*_latest.json.gz")):
    d = json.loads(gzip.open(p).read())
    print(f"{p.name}: run_id={d.get('run_id')} language={d.get('language')}")
print("available_runs keys:", sorted(json.loads((root / "available_runs.json").read_text()).keys()))
PY
```

Hard fail if `sync-data.py` exits non-zero or any enabled language is missing a `*_latest.json.gz` after sync.

**Do not** force-add raw `logs/**` CSVs (gitignored). **Do** stage updated `dashboard/public/data/*` in step 8.

Avoid re-running sync solely to “touch” files when content is already current (gzip recompression can churn binaries with identical JSON).

---

## 8. Commit

```bash
git status
git diff --stat
git log -5 --oneline
```

- Stage **source**, **published docs for changed langs** (results, plots), **skill files**, and **dashboard data**.
- Prefer not mass-touching unrelated language `docs/*/results.md` / violin plots unless those langs were re-benched or analysis was intentionally full-matrix.
- **Do not** force-add gitignored `logs/**` raw CSVs.
- If nothing to commit: print that and continue to push if remote is behind.
- Commit message: short, matches repo style; summarize branch intent vs base (`master`/`main`).
- Never commit secrets (`.env`, credentials).

---

## 9. Push

User invoked prepare-pr (explicit intent to publish the branch):

```bash
git push -u origin HEAD
```

On rejection: report output and **stop**.

---

## 10. Short PR description

Build a short body from `git log origin/master..HEAD` (or `main`) and validation results:

```markdown
## Summary
- <2–4 bullets from branch commits>

## Validation
- Tests: analysis / python / js (pass)
- Benchmarks: <mode>, langs `<CHANGED_LANGS or all/none>`, stem(s) `<STEM>`
- Error CSVs: clean for re-benched languages (or list failures — should not ship)
- Analysis: results + violin plots for re-benched languages
- Dashboard: `sync-data.py` → `*_latest.json.gz` + `available_runs.json`

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
| `.grok/skills/prepare-pr/scripts/detect-changed-langs.sh [BASE]` | Print space-separated language ids to full-bench (see step 3) |
| `.grok/skills/prepare-pr/scripts/check-error-csvs.sh [STEM] [LANGS]` | Exit 1 on **new** error keys (regression) or any rows (strict); optional lang filter |
| `dashboard/scripts/sync-data.py` | Build compressed dashboard payloads + `available_runs.json` from latest logs |

---

## Stop conditions (summary)

| Condition | Action |
|-----------|--------|
| On `master` / `main` / detached | Ask for new branch; do not proceed |
| Tests fail | Stop |
| Benchmarks fail (for any selected language) | Stop |
| Error CSV regression on a re-benched language | Stop |
| Analysis fails for a re-benched language | Stop |
| Dashboard `sync-data.py` fails or missing `*_latest.json.gz` | Stop |
| Push rejected | Stop; report |

