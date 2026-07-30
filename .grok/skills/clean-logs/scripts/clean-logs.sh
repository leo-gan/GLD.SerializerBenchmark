#!/usr/bin/env bash
# Prune repo logs/: keep latest timestamped stem per language; drop prepare-pr logs & backups.
# Usage: clean-logs.sh [--dry-run] [--keep-all-stems] [--no-sync]
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
cd "$ROOT"

DRY_RUN=0
KEEP_ALL_STEMS=0
NO_SYNC=0
for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=1 ;;
    --keep-all-stems) KEEP_ALL_STEMS=1 ;;
    --no-sync) NO_SYNC=1 ;;
    -h|--help)
      sed -n '1,20p' "$0"
      exit 0
      ;;
    *)
      echo "Unknown arg: $arg" >&2
      exit 2
      ;;
  esac
done

LANGS=(c cpp csharp go java javascript python rust swift)
run() {
  if [[ "$DRY_RUN" -eq 1 ]]; then
    echo "[dry-run] $*"
  else
    eval "$@"
  fi
}

before=$(du -sh logs 2>/dev/null | cut -f1 || echo "?")
echo "logs/ before: $before"

# --- Top-level experiment / prepare-pr logs ---
shopt -s nullglob
top_logs=(logs/prepare-pr*.log logs/b1-after-full-*.log logs/csharp-full-*.log logs/*.log)
if ((${#top_logs[@]})); then
  echo "Removing top-level logs: ${#top_logs[@]} file(s)"
  run "rm -f ${top_logs[*]}"
fi

# --- Writable backup trees (not language runners) ---
for d in logs/b1-before; do
  if [[ -d "$d" ]]; then
    echo "Removing backup tree: $d ($(du -sh "$d" | cut -f1))"
    run "rm -rf \"$d\""
  fi
done

# --- Root-owned leftovers (report; try sudo -n only) ---
for d in logs/csharp.root-owned-backup logs/python.root-docker-backup.old; do
  if [[ -d "$d" ]]; then
    owner=$(stat -c '%U' "$d" 2>/dev/null || echo unknown)
    if [[ "$owner" == "root" ]] || [[ ! -w "$d" ]]; then
      echo "Root/unwritable backup: $d ($(du -sh "$d" | cut -f1))"
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] would try: sudo -n rm -rf \"$d\""
      else
        if sudo -n rm -rf "$d" 2>/dev/null; then
          echo "  removed via sudo -n"
        else
          echo "  SKIP — run manually: sudo rm -rf $d"
        fi
      fi
    else
      run "rm -rf \"$d\""
    fi
  fi
done

# --- Per language: keep only latest YYYY-MM-DD-HHMMSS stem ---
if [[ "$KEEP_ALL_STEMS" -eq 1 ]]; then
  echo "Keeping all language stems (--keep-all-stems)"
else
  for lang in "${LANGS[@]}"; do
    dir="logs/$lang"
    [[ -d "$dir" ]] || continue
    latest=$(ls -1 "$dir" 2>/dev/null | grep -E '^[0-9]{4}-[0-9]{2}-[0-9]{2}-[0-9]{6}\.csv$' | sort -r | head -1 | sed 's/\.csv$//' || true)
    if [[ -z "${latest:-}" ]]; then
      echo "  $lang: no timestamped CSV — leave as-is"
      continue
    fi
    removed=0
    for f in "$dir"/*; do
      [[ -e "$f" ]] || continue
      base=$(basename "$f")
      if [[ "$base" == "$latest"* ]]; then
        continue
      fi
      if [[ "$DRY_RUN" -eq 1 ]]; then
        echo "[dry-run] rm -rf $f"
      else
        rm -rf "$f"
      fi
      removed=$((removed + 1))
    done
    kept=$(ls -1 "$dir" 2>/dev/null | wc -l | tr -d ' ')
    echo "  $lang: kept stem $latest ($kept files), removed $removed"
  done
fi

after=$(du -sh logs 2>/dev/null | cut -f1 || echo "?")
echo "logs/ after: $after"

# --- Refresh available_runs.json (do not force-commit gzip churn) ---
if [[ "$NO_SYNC" -eq 1 ]]; then
  echo "Skipping dashboard sync (--no-sync)"
elif [[ "$DRY_RUN" -eq 1 ]]; then
  echo "[dry-run] would run: python3 dashboard/scripts/sync-data.py"
  echo "[dry-run] would keep available_runs.json; restore accidental *.json.gz churn"
else
  if [[ -f dashboard/scripts/sync-data.py ]]; then
    python3 dashboard/scripts/sync-data.py
    # Avoid dirtying the tree with identical-content gzip rewrites
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
      git checkout -- \
        dashboard/public/data/*_latest.json.gz \
        dashboard/public/data/stats_*_latest.json.gz \
        2>/dev/null || true
      # Keep available_runs if it changed (lists stems still on disk)
      if git status --porcelain dashboard/public/data/available_runs.json 2>/dev/null | grep -q .; then
        echo "Updated dashboard/public/data/available_runs.json (stage if you want it committed)"
      fi
    fi
  else
    echo "WARN: dashboard/scripts/sync-data.py missing — skip available_runs refresh"
  fi
fi

echo "Done."
