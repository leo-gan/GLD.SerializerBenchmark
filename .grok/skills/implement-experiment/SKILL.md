---
name: implement-experiment
description: >
  Implement the next (or a named) serializer-benchmark lab experiment under
  experiments/: start a new-task branch, read PLAN.md, copy the Experiment 1
  skeleton, edit that folder's experiment.yaml, generate the shared sample,
  run enabled languages, rebuild combined results.md / results.json, update
  the plan, then open a PR. Use when the user runs /implement-experiment,
  says "implement the next experiment", "start experiment 2", "run experiment
  N", "add an experiment", or "do the next lab".
metadata:
  short-description: "Implement next experiments/ lab from PLAN.md"
---

# /implement-experiment — Next lab from the plan

Repo-local. Resolve the monorepo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
export PATH="${HOME}/.local/go/bin:${HOME}/.cargo/bin:${HOME}/.dotnet:${HOME}/.local/bin:${PATH}"
```

**Source of truth (do not fork these into the skill):**

| Fact | Where it lives |
|------|----------------|
| Which experiment is next, why, sample shape, what we must not claim | `experiments/PLAN.md` |
| Settings a later UI will edit | that experiment’s `experiment.yaml` |
| Field list for that file | `experiments/lib/experiment.config.schema.json` |
| How to load / write `run.yaml` | `experiments/lib/experiment_config.py` |
| Folder layout | `experiments/PLAN.md` § How an experiment is filed |
| Experiment 1 working copy (copy this) | `experiments/01-json-library-bakeoff/` |

---

## Non-negotiable

1. **Not `master` / `main`.** Start with the **new-task** skill (next section). Do not implement on those branches.
2. **One question per folder.** Number it `NN-short-kebab` (next free `NN` after existing dirs).
3. **Edit `experiment.yaml` only** for sample, languages, libraries, run mode, grouping cut-offs. `run.yaml` is generated. Do not keep a second library list.
4. **Shared sample** at the experiment root (`sample.json`). Language folders hold times and results only.
5. **Do not compare write times across languages.** Size is the only roughly fair cross-language number, and only when both sides write the same field description.
6. **Do not crown a single winner.** Use `top_group` (similar / close / slower via Cliff’s delta vs the fastest library in the comparison set). Not “top 5%.”
7. **Plain language** in `README.md`, `results.md`, and the PLAN update. If a word is not everyday English, define it or drop it.
8. **Do not overwrite** published site tables (`docs/<lang>/results.md`) or dashboard `*_latest.json.gz` unless the user asked to publish suite numbers.
9. After the run, **update `experiments/PLAN.md`**: mark the item done, add an **After Experiment *n*** block, change later questions only if the finding requires it. Do not rewrite old findings.

---

## 1. Start a new task

Follow the **new-task** skill first. Do not copy its remote or rebase steps here.

- Branch name: `exp-NN-short-kebab` (same as the folder you will create). If the user already gave a name, use that.
- If the working tree is dirty and the files are **not** this experiment’s in-progress work, stop and ask (new-task rule). Do not auto-stash or discard.
- After new-task, **continue** this skill. The work is already described.

If you are already on `exp-NN-short-kebab` with this experiment’s files, do not start a second branch.

---

## 2. Pick the experiment

1. Read `experiments/PLAN.md` (the series table + that experiment’s full section).
2. If the user named a number or title, use that. Otherwise take the first **planned** item on the first-wave path (**1 → 2 → 3 → 4 → 12 → 13**) that is not **done**.
3. State to the user: number, one-sentence question, sample (A–E), languages, who is in the comparison (and who is out).
4. If the plan says the suite **cannot** measure the real question, say so and implement only the part it can measure.

---

## 3. Scaffold from Experiment 1

```bash
SRC=experiments/01-json-library-bakeoff
DEST=experiments/NN-short-kebab
mkdir -p "$DEST"
cp "$SRC/experiment.yaml" "$SRC/summarize.py" "$SRC/run.sh" "$SRC/README.md" "$DEST/"
mkdir -p "$DEST/python"
cp "$SRC/python/save_sample.py" "$DEST/python/"
chmod +x "$DEST/run.sh" "$DEST/python/save_sample.py" "$DEST/python/run.sh"
```

Do **not** copy `results.*`, `sample.json`, `run.yaml`, or any `*/logs/`.

For each enabled language, add `$DEST/<lang>/run.sh` that execs `../run.sh <lang>` (same one-liner as Experiment 1).

`summarize.py` and `run.sh` already read `experiment.yaml` in their own folder. After the copy, only `experiment.yaml` and `README.md` need content edits.

---

## 4. Write `experiment.yaml`

Copy Experiment 1’s file and change:

| Key | What to set |
|-----|-------------|
| `id` | Folder name (`NN-short-kebab`) |
| `title` / `question` | From the PLAN section (ordinary words) |
| `sample.kind` | `message` \| `document` \| `telemetry` \| `strings` \| `event` |
| `sample.records_per_write` | `1` or `[1, 100]` |
| `sample.settings` | Only extra knobs (e.g. `points: 128`). `{}` = catalog defaults |
| `sample.seed` | `42` unless the PLAN says otherwise |
| `run.mode` | `full` for a claim; `all-single` only for a dry run the user asked for |
| `languages[].enabled` | `true` only for languages this question needs |
| `languages[].libraries` | **Only** libraries that answer this question (same job). Drop the rest. |
| `analysis.require_named_fields` | `true` when the comparison is ordinary named JSON; `false` for mixed formats |
| `analysis.top_group` | Keep Experiment 1’s method unless the PLAN says otherwise |

`writes_named_fields: false` only when the library writes a different JSON shape (e.g. a list of values). Mixed-format experiments (JSON vs MessagePack vs Protocol Buffers) still list each library; grouping uses the comparison set in `analysis`.

Validate after edits:

```bash
cd analysis
uv run python ../experiments/lib/experiment_config.py write-run ../experiments/NN-short-kebab/experiment.yaml
uv run python ../experiments/lib/experiment_config.py languages ../experiments/NN-short-kebab/experiment.yaml
```

---

## 5. Shared sample

```bash
cd analysis
uv run python ../experiments/NN-short-kebab/python/save_sample.py
```

Confirm `sample.json` exists at the experiment root and matches `sample.kind`. Preview copies under `experiments/samples/` are **not** the official file.

Language runners still build from `run.yaml` + seed. They may not spell the same random words. The saved `sample.json` is the record the write-up discusses.

---

## 6. Run

```bash
./experiments/NN-short-kebab/run.sh
# or a subset: ./experiments/NN-short-kebab/run.sh python go
```

- Continue through language failures; report which failed.
- Put `~/.local/go/bin` on `PATH` (Experiment 1’s `run.sh` already does).
- Hard-fail only if **every** requested language fails or `summarize.py` cannot write combined files.

Rebuild tables without new timing:

```bash
cd analysis
uv run python ../experiments/NN-short-kebab/summarize.py --all
```

---

## 7. What must exist before you open the PR

| Path | Role |
|------|------|
| `experiments/NN-…/experiment.yaml` | Settings |
| `experiments/NN-…/sample.json` | Shared record |
| `experiments/NN-…/results.md` | Combined human page (quick look) |
| `experiments/NN-…/results.json` | Combined machine file (`top_group` + rows) |
| `experiments/NN-…/<lang>/results.md` | Full table per language that ran |
| `experiments/PLAN.md` | Status + After Experiment *n* |
| `experiments/README.md` | Index row for the new folder |

`results.md` at the experiment root is the quick look. Per-language `results.md` stays for detail.

---

## 8. Writing the finding

In the PLAN **After** block and in `results.md`:

- Name the **similar** set and the **close** set per language. Do not say “the winner is X” unless the similar set has one name **and** you say “on this sample.”
- State what this changes about the **next** planned question.
- List what the suite still cannot tell (from that PLAN section).

---

## 9. Open a PR

Do this yourself. Do not ask whether to open it. Skip only if the user asked to plan or draft yaml, or if every language run failed.

1. Stage the experiment folder, `experiments/PLAN.md`, `experiments/README.md`, and this skill if you changed it.
2. Do **not** stage `__pycache__`, published site tables (`docs/<lang>/results.md`), or dashboard `*_latest.json.gz`.
3. Commit. Match repo style, for example: `feat(experiments): add <short question> across <N> languages`.
4. `git push -u origin HEAD`. Never push to `upstream`.
5. Open the PR against the source-of-truth default branch (`origin/master` when only `origin` exists; `upstream/master` or `upstream/main` when that remote exists):

```bash
gh pr create --title "Add Experiment N: <one-line question>" --body "$(cat <<'PR'
## Summary
- <what the experiment asks>
- Ran in <languages> (`full`).
- Combined page: `experiments/NN-…/results.md`. Rebuild: `summarize.py --all`.

## How to read
- Times in two languages are not one contest.
- Read the similar / close sets. Do not crown a single winner.

## Validation
- Timed runs completed for: <list>. Failed: <list or none>.
- No language harness source changed; published site Results / dashboard payloads were not regenerated.

## Notes
- `run.yaml` is generated from `experiment.yaml`.
- Raw CSVs live under `experiments/**/logs/` so tables can be recalculated.
PR
)"
```

6. Put the PR URL in the PLAN **After Experiment *n*** block. Commit and push that edit.

---

## Stop conditions

| Condition | Action |
|-----------|--------|
| On `master` / `main` / detached | Run **new-task**; do not implement on those branches |
| Dirty tree that is not this experiment | Stop and ask (new-task rule) |
| PLAN says this question is out of suite scope | Implement only the measurable slice; say what was skipped |
| `experiment.yaml` fails `write-run` / `languages` | Fix the file; do not hand-edit `run.yaml` as the source |
| All requested language runners fail | Stop; report; do not open a PR |
| User asked only to plan / draft yaml | Stop after steps 2–4 (no timing, no PR) |

---

## Related

- **new-task** — first step (branch from source-of-truth `master` / `main`).
- **prepare-pr** — suite tests + published Results/dashboard. Do **not** run it for an experiment PR (it would overwrite site tables this skill forbids).
- **review-suspicious-results** — harness/client outliers. Use if a library’s size or time looks impossible after the experiment run.
