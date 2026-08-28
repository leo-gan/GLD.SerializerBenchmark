#!/usr/bin/env bash
# Time lab experiments for the given language ids.
#
# Usage:
#   run-experiments-for-langs.sh [lang ...]
#   CHANGED_LANGS="kotlin java" run-experiments-for-langs.sh
#
# Discovers experiments/*/experiment.yaml. For each enabled language in the
# argument list, runs that experiment's run.sh for that language only.
# Exits 1 if any run fails. Exits 0 with no work when no langs or no
# matching experiment folders.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$PROJECT_ROOT"

langs=()
if [[ $# -gt 0 ]]; then
  # shellcheck disable=SC2206
  langs=($*)
elif [[ -n "${CHANGED_LANGS:-}" ]]; then
  # shellcheck disable=SC2206
  langs=($CHANGED_LANGS)
elif [[ -n "${PREPARE_PR_LANGS:-}" ]]; then
  # shellcheck disable=SC2206
  langs=(${PREPARE_PR_LANGS//,/ })
fi

if [[ ${#langs[@]} -eq 0 ]]; then
  echo "[run-experiments] no languages — skipping" >&2
  exit 0
fi

enabled_in_yaml() {
  local yaml="$1" lang="$2"
  python3 - "$yaml" "$lang" <<'PY'
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    sys.exit(2)

path, lang = Path(sys.argv[1]), sys.argv[2]
data = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
for row in data.get("languages") or []:
    if not isinstance(row, dict):
        continue
    if row.get("id") == lang and row.get("enabled", True):
        sys.exit(0)
sys.exit(1)
PY
}

failed=()
ran=0
for exp in "$PROJECT_ROOT"/experiments/*/experiment.yaml; do
  [[ -f "$exp" ]] || continue
  folder="$(dirname "$exp")"
  name="$(basename "$folder")"
  runner="$folder/run.sh"
  for lang in "${langs[@]}"; do
    if ! enabled_in_yaml "$exp" "$lang"; then
      echo "[run-experiments] $name: $lang not enabled — skip"
      continue
    fi
    if [[ ! -x "$runner" ]]; then
      echo "[run-experiments] $name: missing executable run.sh" >&2
      failed+=("$name/$lang")
      continue
    fi
    echo "[run-experiments] ===== $name / $lang ====="
    if ( cd "$folder" && bash ./run.sh "$lang" ); then
      ran=$((ran + 1))
    else
      echo "[run-experiments] FAILED $name / $lang" >&2
      failed+=("$name/$lang")
    fi
  done
done

if [[ ${#failed[@]} -gt 0 ]]; then
  echo "[run-experiments] failed: ${failed[*]}" >&2
  exit 1
fi
echo "[run-experiments] finished $ran run(s) for: ${langs[*]}"
