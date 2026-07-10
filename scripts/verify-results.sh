#!/usr/bin/env bash
# Verify latest (or shared-stem) result CSVs for enabled languages.
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

LOGS_ROOT="$(bench_logs_root)"
STEM="${BENCHMARK_TS:-}"
LANG_FILTER="${1:-}"

echo -e "${YELLOW}[INFO] Verifying benchmark results under ${LOGS_ROOT}${NC}"

ok=0
fail=0
while IFS='|' read -r id _runner_dir _script; do
  [[ -z "$id" ]] && continue
  if [[ -n "$LANG_FILTER" && "$LANG_FILTER" != "$id" ]]; then
    continue
  fi
  dir="$LOGS_ROOT/$id"
  if [[ -n "$STEM" ]]; then
    f="$dir/${STEM}.csv"
  else
    f="$(ls -t "$dir"/*.csv 2>/dev/null | grep -v errors | head -1 || true)"
  fi
  if [[ -z "${f:-}" || ! -f "$f" ]]; then
    echo -e "  $id: ${RED}no result CSV${NC}"
    fail=$((fail + 1))
    continue
  fi
  lines=$(wc -l < "$f")
  if [[ "$lines" -lt 2 ]]; then
    echo -e "  $id: ${RED}empty or header-only${NC} ($f)"
    fail=$((fail + 1))
    continue
  fi
  err="${f%.csv}.errors.csv"
  cfg="${f%.csv}.configs.json"
  extra=""
  if [[ -f "$err" ]]; then
    ec=$(($(wc -l < "$err") - 1))
    [[ "$ec" -gt 0 ]] && extra=" ${YELLOW}(${ec} errors in $(basename "$err"))${NC}"
  fi
  if [[ ! -f "$cfg" && ! -f "${f%.csv}.environment.json" ]]; then
    extra="${extra} ${YELLOW}(no configs.json)${NC}"
  fi
  echo -e "  $id: ${GREEN}$((lines - 1)) records${NC} ($(basename "$f"))$extra"
  ok=$((ok + 1))
done < <(bench_read_config --lang-runners)

echo -e "${GREEN}[DONE]${NC} verified=$ok missing_or_empty=$fail"
[[ "$fail" -eq 0 && "$ok" -gt 0 ]]
