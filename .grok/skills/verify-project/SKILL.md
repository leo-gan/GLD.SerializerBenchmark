---
name: verify-project
description: >
  Verify the serializer-benchmark repo for inconsistencies and design flaws
  across every artifact type: language registry, schemas, runners, compliance
  corpora, serializer catalogs, published dashboard snapshots, experiments,
  docs, CI, and skills. Use when the user runs /verify-project, or says
  "verify the project", "check inconsistencies", "design flaws", "audit
  artifacts", "are the catalogs in sync", or "cross-check the repo".
metadata:
  short-description: "Cross-artifact consistency and design audit"
---

# /verify-project — Inconsistencies and design flaws

Read-only audit. Report findings. Do not edit the repo, re-bench, regenerate
schemas, rebuild the site, or bump versions unless the user asks to fix a
finding after seeing it.

Performance outliers and package-doc call paths are `/review-suspicious-results`,
not this skill.

Resolve the repo root first:

```bash
cd "$(git rev-parse --show-toplevel)"
```

If the user names a subset (one language, compliance, the dashboard), design-review
only those artifact ids. Still run the mechanical checker; it is the cross-check.

## 1. Load the artifact list

Read [references/artifacts.md](references/artifacts.md). That file is the list of
artifact types. Do not substitute a shorter list. Every id in it must show up
in the report as a finding, as checked, or as not checked with a reason.

Read [references/design-review.md](references/design-review.md) and the contract
paths it names before judging a design flaw.

## 2. Mechanical cross-check

```bash
python3 .grok/skills/verify-project/scripts/check-artifacts.py
```

The script compares registries, catalogs, copies, and published trees. It calls
`standard_for` and `data_set_for_type` rather than restating them. Exit 1 means
at least one `ERROR`.

Confirm each `ERROR` by opening the paths in the message. Keep it when the two
sides are supposed to agree. Drop it only when you can cite the rule that allows
the difference, and say that rule. `docs/dashboard/data` is the deployed copy of
`dashboard/public/data`. A difference there is drift, not an allowed cache.

Do not run `scripts/schemas/check-generated.sh` or any `sync-*.py` / `splice-*.py`
/ Vite build. They write the tree.

## 3. Contract tests

```bash
cd analysis && python -m pytest tests/test_dimensions.py tests/test_schedule.py -q --tb=line
cd dashboard && npm test
```

Failures are findings on the artifact the test is about (`dimension-contract`,
`analysis-package`, `dashboard-app`, or the file the assertion names). Do not
treat a failure as pre-existing noise. Say whether the failing file differs
from `HEAD` when the worktree is dirty.

## 4. Design pass

Walk every artifact id from the list (or the user's subset). For each:

- Open the canonical path and the peers named in the artifact entry.
- Apply the design-review questions. A large tree (every serializer wrapper,
  every theory page) is reviewed against the contract at the places that can
  lie: registration versus the inventory page, timed section versus
  `TIMING_HONESTY.md`, published `all@` and splice inputs, compliance cells
  with no corpus or no adapter. Do not read vendored upstream projects.
- Local `logs/` and `reports/` are checked when present. Their absence is a
  note, not a finding. When a timestamped CSV exists, compare its header to
  `csv_schema.required_columns` and its time unit to nanoseconds.

## 5. Report

Use this shape. Every artifact id appears in exactly one section.

```markdown
## Result
N inconsistencies, M design flaws, K notes.

## Inconsistencies
| Artifact | Where | What disagrees |

## Design flaws
| Artifact | Where | Contract | What is wrong |

## Notes
- …

## Checked, no finding
- id — one line

## Not checked
- id — why
```

An inconsistency is two artifacts that disagree about one fact, including a
derived copy that is stale. A design flaw is a break in a contract from
design-review.md even when no second file disagrees yet. A note is a gap in
local evidence or a judgment you are not ready to call a defect.

Do not offer a fix commit in the same turn. Stop after the report.
