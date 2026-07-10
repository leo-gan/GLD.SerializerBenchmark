#!/usr/bin/env bash
# Fail if regenerating schema artifacts changes tracked files (when outputs are committed).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$ROOT"

./scripts/schemas/generate-all.sh

if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  # Only fail on drift under known generated trees if they exist and are tracked.
  paths=()
  [[ -d python/generated/v2 ]] && paths+=(python/generated/v2)
  if ((${#paths[@]})); then
    if ! git diff --exit-code -- "${paths[@]}" 2>/dev/null; then
      echo "error: generated schema artifacts out of date; run scripts/schemas/generate-all.sh and commit" >&2
      exit 1
    fi
  fi
fi
echo "check-generated: ok"
