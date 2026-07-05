#!/usr/bin/env bash
# Check harness error sidecars (*.errors.csv) for regressions.
#
# Usage:
#   check-error-csvs.sh [STEM]
#   CHECK_ERRORS_MODE=strict|regression  (default: regression)
#
# Modes:
#   regression (default) — fail if the current STEM introduces error keys not
#     present in the previous timestamped run for that language.
#   strict — fail if any language has non-header data rows (zero-tolerance).
#
# Error key = TestDataName|SerializerName|StringOrStream (first 3 data columns).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../../.." && pwd)"
if [[ -f "$PROJECT_ROOT/scripts/lib/config.sh" ]]; then
  # shellcheck source=/dev/null
  source "$PROJECT_ROOT/scripts/lib/config.sh"
  LOGS_ROOT="$(bench_logs_root 2>/dev/null || echo "$PROJECT_ROOT/logs")"
  LANG_RUNNERS="$(bench_read_config --lang-runners 2>/dev/null || true)"
else
  LOGS_ROOT="$PROJECT_ROOT/logs"
  LANG_RUNNERS=""
fi

STEM="${1:-${BENCHMARK_TS:-}}"
MODE="${CHECK_ERRORS_MODE:-regression}"
# Optional: space- or comma-separated language ids (arg2 or PREPARE_PR_LANGS).
# When set, only those languages are checked (prepare-pr changed-lang mode).
LANG_FILTER_RAW="${2:-${PREPARE_PR_LANGS:-}}"
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; NC='\033[0m'

lang_allowed() {
  local id="$1"
  [[ -z "$LANG_FILTER_RAW" ]] && return 0
  local f
  f=" ${LANG_FILTER_RAW//,/ } "
  [[ "$f" == *" $id "* ]]
}

echo -e "${YELLOW}[check-error-csvs] mode=${MODE} logs=${LOGS_ROOT} stem=${STEM:-latest}${LANG_FILTER_RAW:+ langs=${LANG_FILTER_RAW//,/ }}${NC}"

fail=0
checked=0
declare -a REPORT_LINES=()

error_keys() {
  local errf="$1"
  # Skip header; key = first 3 CSV fields when present
  if [[ ! -f "$errf" ]]; then
    return 0
  fi
  tail -n +2 "$errf" | awk -F',' 'NF>=3 && $0 ~ /[^[:space:]]/ {
    gsub(/\r/,"",$1); gsub(/\r/,"",$2); gsub(/\r/,"",$3);
    print $1 "|" $2 "|" $3
  }' | sort -u
}

prev_stem_for_lang() {
  # Prefer a prior stem whose result CSV is comparable in size (≥50% of current
  # row count) so smoke runs are not used as baselines for full runs.
  local dir="$1" current="$2" current_csv="$3"
  local cur_lines min_lines path s lines
  cur_lines=$(wc -l < "$current_csv")
  min_lines=$(( cur_lines / 2 ))
  [[ "$min_lines" -lt 2 ]] && min_lines=2
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    s=$(basename "$path" .csv)
    if [[ -n "$current" && "$s" == "$current" ]]; then
      continue
    fi
    lines=$(wc -l < "$path")
    if [[ "$lines" -ge "$min_lines" ]]; then
      echo "$s"
      return 0
    fi
  done < <(ls -t "$dir"/*.csv 2>/dev/null | grep -v errors | head -30 || true)
  # Fallback: any previous stem
  while IFS= read -r path; do
    [[ -z "$path" ]] && continue
    s=$(basename "$path" .csv)
    if [[ -n "$current" && "$s" == "$current" ]]; then
      continue
    fi
    echo "$s"
    return 0
  done < <(ls -t "$dir"/*.csv 2>/dev/null | grep -v errors | head -30 || true)
  return 1
}

check_lang() {
  local id="$1"
  local dir="$LOGS_ROOT/$id"
  local f err ec prev prev_err
  if [[ -n "$STEM" ]]; then
    f="$dir/${STEM}.csv"
  else
    f="$(ls -t "$dir"/*.csv 2>/dev/null | grep -v errors | head -1 || true)"
  fi
  if [[ -z "${f:-}" || ! -f "$f" ]]; then
    echo -e "  $id: ${RED}FAIL${NC} no result CSV"
    fail=$((fail + 1))
    return
  fi
  local stem_used
  stem_used=$(basename "$f" .csv)
  err="${f%.csv}.errors.csv"
  checked=$((checked + 1))

  ec=0
  if [[ -f "$err" && $(wc -l < "$err") -gt 1 ]]; then
    ec=$(tail -n +2 "$err" | grep -c '[^[:space:]]' || true)
  fi

  if [[ "$MODE" == "strict" ]]; then
    if [[ "$ec" -gt 0 ]]; then
      echo -e "  $id: ${RED}FAIL${NC} $ec error row(s) in $(basename "$err") [strict]"
      fail=$((fail + 1))
      REPORT_LINES+=("$id: $ec errors (strict)")
    else
      echo -e "  $id: ${GREEN}OK${NC} $(basename "$f") (no error rows)"
    fi
    return
  fi

  # regression mode
  if [[ "$ec" -eq 0 ]]; then
    echo -e "  $id: ${GREEN}OK${NC} $(basename "$f") (0 error rows)"
    return
  fi

  prev="$(prev_stem_for_lang "$dir" "$stem_used" "$f" || true)"
  if [[ -z "${prev:-}" ]]; then
    echo -e "  $id: ${YELLOW}WARN${NC} $ec error row(s), no prior run to compare — not failing"
    REPORT_LINES+=("$id: $ec errors (baseline run, no prior)")
    return
  fi
  prev_err="$dir/${prev}.errors.csv"
  mapfile -t NEW_KEYS < <(comm -13 \
    <(error_keys "$prev_err") \
    <(error_keys "$err") )
  if [[ ${#NEW_KEYS[@]} -gt 0 && -n "${NEW_KEYS[0]:-}" ]]; then
    echo -e "  $id: ${RED}FAIL${NC} ${#NEW_KEYS[@]} NEW error key(s) vs prior $prev (total rows=$ec)"
    for k in "${NEW_KEYS[@]:0:8}"; do
      echo -e "      + $k"
    done
    fail=$((fail + 1))
    REPORT_LINES+=("$id: ${#NEW_KEYS[@]} new error keys vs $prev")
  else
    echo -e "  $id: ${GREEN}OK${NC} $ec known error row(s), no new keys vs $prev"
    REPORT_LINES+=("$id: $ec known errors (no regression vs $prev)")
  fi
}

if [[ -n "$LANG_RUNNERS" ]]; then
  while IFS='|' read -r id _rest; do
    [[ -z "$id" ]] && continue
    lang_allowed "$id" || continue
    check_lang "$id"
  done <<< "$LANG_RUNNERS"
else
  for dir in "$LOGS_ROOT"/*/; do
    [[ -d "$dir" ]] || continue
    id=$(basename "$dir")
    [[ "$id" == *backup* ]] && continue
    lang_allowed "$id" || continue
    check_lang "$id"
  done
fi

if [[ "$checked" -eq 0 ]]; then
  echo -e "${RED}[check-error-csvs] no languages checked${NC}"
  exit 1
fi
if [[ "$fail" -gt 0 ]]; then
  echo -e "${RED}[check-error-csvs] FAILED ($fail language(s))${NC}"
  exit 1
fi
echo -e "${GREEN}[check-error-csvs] all clear ($checked language(s))${NC}"
exit 0
