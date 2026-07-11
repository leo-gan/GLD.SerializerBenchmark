#!/usr/bin/env bash
# Detect which benchmark language ids are affected by branch changes.
#
# Usage:
#   detect-changed-langs.sh [BASE_REF]
#   PREPARE_PR_LANGS=c,javascript detect-changed-langs.sh   # force list (skip detection)
#   PREPARE_PR_BENCH_ALL=1 detect-changed-langs.sh          # all enabled languages
#
# Prints space-separated language ids on stdout (empty if none / no bench needed).
# Prints human diagnostics on stderr.
#
# Mapping uses harness source trees only (not regenerated docs/dashboard/logs).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
cd "$PROJECT_ROOT"

# Force overrides
if [[ -n "${PREPARE_PR_LANGS:-}" ]]; then
  # shellcheck disable=SC2086
  echo "${PREPARE_PR_LANGS//,/ }" | xargs
  echo "[detect-changed-langs] forced PREPARE_PR_LANGS=${PREPARE_PR_LANGS}" >&2
  exit 0
fi

if [[ "${PREPARE_PR_BENCH_ALL:-0}" == "1" ]]; then
  if [[ -f "$PROJECT_ROOT/scripts/lib/config.sh" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/scripts/lib/config.sh"
    runners="$(bench_read_config --lang-runners 2>/dev/null || true)"
    ids=()
    while IFS='|' read -r id _rest; do
      [[ -n "$id" ]] && ids+=("$id")
    done <<< "$runners"
    echo "${ids[*]}"
  else
    echo "csharp python rust c javascript go java"
  fi
  echo "[detect-changed-langs] PREPARE_PR_BENCH_ALL=1 → all enabled" >&2
  exit 0
fi

BASE_REF="${1:-}"
if [[ -z "$BASE_REF" ]]; then
  for cand in origin/main origin/master main master; do
    if git rev-parse --verify "$cand" >/dev/null 2>&1; then
      BASE_REF=$(git merge-base HEAD "$cand" 2>/dev/null || true)
      [[ -n "$BASE_REF" ]] && break
    fi
  done
fi
if [[ -z "$BASE_REF" ]]; then
  echo "[detect-changed-langs] WARN: no merge-base; default empty (no langs)" >&2
  echo ""
  exit 0
fi

# Collect changed paths (committed + unstaged/staged working tree)
mapfile -t PATHS < <({
  git diff --name-only "$BASE_REF"...HEAD
  git diff --name-only
  git diff --name-only --cached
} | sort -u)

declare -A HIT=()
SHARED_FORCE_ALL=0

for p in "${PATHS[@]}"; do
  [[ -z "$p" ]] && continue

  # Regenerated / non-harness artifacts — never select a language alone
  case "$p" in
    docs/*|dashboard/public/data/*|logs/*|reports/*|site/*|.grok/*)
      continue
      ;;
  esac

  # Shared inputs that affect every language harness
  case "$p" in
    schemas/*|scripts/run-all-benchmarks.sh|scripts/lib/*|scripts/read-config.py)
      SHARED_FORCE_ALL=1
      continue
      ;;
    config/benchmark_config.yaml)
      # modes / test_data / enabled languages — re-bench all enabled
      SHARED_FORCE_ALL=1
      continue
      ;;
  esac

  # Language harness trees (order matters: c-sharp before c)
  case "$p" in
    c-sharp/*|csharp/*)
      HIT[csharp]=1
      ;;
    c/*)
      HIT[c]=1
      ;;
    python/*)
      HIT[python]=1
      ;;
    rust/*)
      HIT[rust]=1
      ;;
    javascript/*|js/*)
      HIT[javascript]=1
      ;;
    go/*)
      HIT[go]=1
      ;;
    java/*)
      HIT[java]=1
      ;;
  esac
done

if [[ "$SHARED_FORCE_ALL" -eq 1 ]]; then
  if [[ -f "$PROJECT_ROOT/scripts/lib/config.sh" ]]; then
    # shellcheck source=/dev/null
    source "$PROJECT_ROOT/scripts/lib/config.sh"
    runners="$(bench_read_config --lang-runners 2>/dev/null || true)"
    ids=()
    while IFS='|' read -r id _rest; do
      [[ -n "$id" ]] && ids+=("$id")
    done <<< "$runners"
    echo "${ids[*]}"
  else
    echo "csharp python rust c javascript go java"
  fi
  echo "[detect-changed-langs] shared path change vs $BASE_REF → all enabled languages" >&2
  exit 0
fi

ids=()
for id in csharp python rust c javascript go java; do
  [[ -n "${HIT[$id]:-}" ]] && ids+=("$id")
done

if [[ ${#ids[@]} -eq 0 ]]; then
  echo "[detect-changed-langs] no harness changes vs $BASE_REF → skip full benchmarks" >&2
  echo ""
  exit 0
fi

echo "${ids[*]}"
echo "[detect-changed-langs] base=$BASE_REF langs=${ids[*]}" >&2
exit 0
