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
# Mapping uses benchmark-runner *source* trees only (not regenerated docs/dashboard/logs,
# and not prose-only files such as README.md under schemas/ or scripts/).
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
    echo "csharp python rust c javascript go java kotlin php cpp swift zig"
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

# True if path is documentation / meta only — must not select langs or force-all.
is_prose_or_meta() {
  local p="$1"
  case "$p" in
    docs/*|dashboard/public/data/*|dashboard/dist/*|logs/*|reports/*|site/*|.grok/*)
      return 0
      ;;
  esac
  # README / markdown / license prose anywhere (including schemas/, scripts/, lang trees)
  case "$p" in
    *.md|*.mdx|*.rst|*.txt)
      return 0
      ;;
    */README|*/README.*|README|README.*)
      return 0
      ;;
    LICENSE|LICENSE.*|*/LICENSE|*/LICENSE.*)
      return 0
      ;;
  esac
  return 1
}

# True if path is a *real* shared input that invalidates every language's numbers.
is_shared_force_all() {
  local p="$1"
  case "$p" in
    # Wire schemas, catalogs, generators — not prose under schemas/
    schemas/*)
      return 0
      ;;
    scripts/run-all-benchmarks.sh|scripts/lib/*|scripts/read-config.py|scripts/resolve_run_config.py)
      return 0
      ;;
    config/benchmark_config.yaml)
      return 0
      ;;
  esac
  return 1
}

declare -A HIT=()
SHARED_FORCE_ALL=0
IGNORED_PROSE=0

for p in "${PATHS[@]}"; do
  [[ -z "$p" ]] && continue

  if is_prose_or_meta "$p"; then
    IGNORED_PROSE=1
    continue
  fi

  if is_shared_force_all "$p"; then
    SHARED_FORCE_ALL=1
    continue
  fi

  # Language benchmark-runner trees (order matters: c-sharp before c)
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
    kotlin/*)
      HIT[kotlin]=1
      ;;
    php/*)
      HIT[php]=1
      ;;
    cpp/*|c++/*|cxx/*)
      HIT[cpp]=1
      ;;
    swift/*)
      HIT[swift]=1
      ;;
    zig/*)
      HIT[zig]=1
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
    echo "csharp python rust c javascript go java kotlin php cpp swift zig"
  fi
  echo "[detect-changed-langs] shared path change vs $BASE_REF → all enabled languages" >&2
  exit 0
fi

ids=()
for id in csharp python rust c javascript go java kotlin php cpp swift zig; do
  [[ -n "${HIT[$id]:-}" ]] && ids+=("$id")
done

if [[ ${#ids[@]} -eq 0 ]]; then
  if [[ "$IGNORED_PROSE" -eq 1 ]]; then
    echo "[detect-changed-langs] prose/meta-only changes vs $BASE_REF → skip full benchmarks" >&2
  else
    echo "[detect-changed-langs] no benchmark-runner source changes vs $BASE_REF → skip full benchmarks" >&2
  fi
  echo ""
  exit 0
fi

echo "${ids[*]}"
echo "[detect-changed-langs] base=$BASE_REF langs=${ids[*]}" >&2
exit 0
