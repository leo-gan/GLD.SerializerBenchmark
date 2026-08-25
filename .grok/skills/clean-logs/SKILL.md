---
name: clean-logs
description: >
  Prune the serializer-benchmark monorepo logs/ tree: remove prepare-pr and ad-hoc
  top-level logs, drop known backup dirs, keep only the latest timestamped run stem
  per language (dashboard/sync), refresh available_runs.json without gzip churn.
  Use when the user runs /clean-logs, says "clean up logs", "prune logs", "free disk
  logs", "delete old benchmark logs", or "trim logs directory".
metadata:
  short-description: "Prune logs/ to latest stems"
---

# /clean-logs — Prune `logs/` safely

Repo-local skill. Run from the monorepo root (or let the agent resolve it).

## Goals

- Free disk after prepare-pr / multi-run work without breaking the **dashboard** or **sync-data**.
- Keep **one latest stem** per language (`YYYY-MM-DD-HHMMSS.csv` + sibling configs/errors/env files).
- Never touch `.git/logs`, language harness trees outside `logs/`, or force-commit gzip recompression.

## When to run

- User asks to clean / prune / free **logs**.
- After large prepare-pr or multi-language benches when `logs/` is hundreds of MiB.
- Not required before every PR; optional housekeeping.

## Prefer the script

```bash
cd "$(git rev-parse --show-toplevel)"
.grok/skills/clean-logs/scripts/clean-logs.sh          # apply
.grok/skills/clean-logs/scripts/clean-logs.sh --dry-run # preview
```

| Flag | Effect |
|------|--------|
| `--dry-run` | Print actions only |
| `--keep-all-stems` | Do not delete older per-language run stems (only top-level logs + backups) |
| `--no-sync` | Skip `dashboard/scripts/sync-data.py` / `available_runs.json` update |

Exit non-zero on unexpected failure. Root-owned dirs that cannot be deleted are **reported**, not a hard fail.

## Manual procedure (if script missing)

### 1. Measure

```bash
du -sh logs
du -sh logs/* | sort -hr | head -30
```

### 2. Top-level noise

Remove prepare-pr and other ad-hoc logs under `logs/` (not under language subdirs):

```bash
rm -f logs/prepare-pr*.log logs/b1-after-full-*.log logs/csharp-full-*.log logs/*.log
```

### 3. Backup / snapshot directories

Safe to delete when writable (not used by dashboard “latest” sync):

| Path | Notes |
|------|--------|
| `logs/b1-before/` | Experiment snapshot |
| `logs/csharp.root-owned-backup/` | Often **root-owned** — needs `sudo rm -rf` |
| `logs/python.root-docker-backup.old/` | Often **root-owned** — needs `sudo rm -rf` |

```bash
rm -rf logs/b1-before
# if permission denied:
sudo rm -rf logs/csharp.root-owned-backup logs/python.root-docker-backup.old
```

Do **not** delete `logs/<lang>/` wholesale.

### 4. Keep only latest stem per language

Languages: `c` `cpp` `csharp` `go` `java` `javascript` `python` `rust` `swift`.

For each `logs/<lang>/`:

1. Find latest CSV matching `^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\.csv$` (sort reverse).
2. Stem = filename without `.csv`.
3. Delete every file in that dir whose name does **not** start with `stem`.

Keep all siblings for the stem: `.csv`, `.configs.json`, `.environment.json`, `.errors.csv`, etc.

Dashboard / sync-data use **newest** timestamped CSV per language; older stems are only for history download when present.

### 5. Refresh `available_runs.json`

After pruning stems, history lists must not reference deleted runs:

```bash
python3 dashboard/scripts/sync-data.py
```

Then **avoid committing gzip-only churn**:

```bash
# if inside git: restore recompressed identical packs; keep available_runs if changed
git checkout -- \
  dashboard/public/data/*_latest.json.gz \
  dashboard/public/data/stats_*_latest.json.gz \
  2>/dev/null || true
# stage only if desired:
# git add dashboard/public/data/available_runs.json
```

Hard fail only if sync exits non-zero and the user needed a dashboard refresh.

### 6. Do not touch

| Path | Why |
|------|-----|
| `.git/logs` | Git internals |
| `logs/` contents that are the sole latest stem | Needed for re-analysis / dashboard |
| `docs/dashboard/logs` / `dashboard/public/logs` if **symlink** to `logs/` | Same tree |
| Forced `git add` of raw CSVs | Usually gitignored |

## Expected size (order of magnitude)

| State | Approx |
|-------|--------|
| Many historical stems + prepare-pr logs | hundreds of MiB (e.g. ~400 MiB) |
| After prune to 1 stem/lang + no backups | tens of MiB (e.g. ~50–65 MiB) |

## Agent checklist

1. Confirm repo root; never run against the wrong monorepo.
2. Prefer `scripts/clean-logs.sh`; use `--dry-run` first if the user is cautious.
3. Report before/after `du -sh logs` and any remaining root-owned paths.
4. Mention the one-liner for sudo backups if still present.
5. Do not push or open a PR unless the user asked to commit the `available_runs` update.

## Related

- **prepare-pr** writes `logs/prepare-pr-*.log` and new language stems — clean-logs is the complementary prune.
- **sync-data.py** packages **latest** stem only into `*_latest.json.gz`; multi-stem history is optional.
