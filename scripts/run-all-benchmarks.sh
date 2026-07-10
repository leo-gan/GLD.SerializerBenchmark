#!/usr/bin/env bash
# Unified benchmark runner for all languages (registry from config/benchmark_config.yaml)
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

LOG_DIR="$(bench_logs_root)"
REPORT_DIR="$(bench_read_config --reports-root 2>/dev/null || echo "$PROJECT_ROOT/reports")"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

MODE="all-single"
GENERATE_ARTIFACTS=false
CHECK_REGRESSION=false
REGRESSION_THRESHOLD="$(bench_read_config regression.threshold_percent 2>/dev/null || echo 10)"
SAVE_BASELINE=false
LANG_FILTER=""  # empty = all enabled

print_usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS]

Run serializer benchmarks for enabled languages (languages.*.enabled in
config/benchmark_config.yaml) and optionally generate reports.

OPTIONS:
    -m, --mode MODE             Mode from config modes: (default: all-single)
    -l, --lang LANG             Only run one language id from config
    -a, --analyze               Generate analysis artifacts (tables + plots) via analyze-benchmarks
    -r, --regression-check      Check for performance regressions
    -t, --threshold PERCENT     Regression threshold (default: regression.threshold_percent)
    -b, --save-baseline         Save current results as baseline
    -h, --help                  Show this help message

Reports default to reports/ (gitignored). For GitHub Pages snapshots, run
analyze-benchmarks (optionally -l LANG) and commit docs/.
USAGE
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode) MODE="$2"; shift 2 ;;
        -l|--lang) LANG_FILTER="$2"; shift 2 ;;
        -a|--analyze) GENERATE_ARTIFACTS=true; shift ;;
        -r|--regression-check) CHECK_REGRESSION=true; shift ;;
        -t|--threshold) REGRESSION_THRESHOLD="$2"; shift 2 ;;
        -b|--save-baseline) SAVE_BASELINE=true; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done

VALID_MODES="$(bench_read_config --valid-modes 2>/dev/null || echo 'smoke all-single full research')"
case " $VALID_MODES " in
  *" $MODE "*) ;;
  *) echo -e "${RED}Error: Invalid mode '$MODE' (valid: $VALID_MODES)${NC}"; exit 1 ;;
esac

run_lang() {
    local id="$1" dir="$2" script="$3"
    if [[ -n "$LANG_FILTER" && "$LANG_FILTER" != "$id" ]]; then return 0; fi
    if [[ ! -x "$PROJECT_ROOT/$dir/$script" && ! -f "$PROJECT_ROOT/$dir/$script" ]]; then
        echo -e "${YELLOW}⚠ Skip $id (no runner at $dir/$script)${NC}"
        return 0
    fi
    echo -e "${BLUE}Running $id benchmarks...${NC}"
    cd "$PROJECT_ROOT/$dir"
    if bash "$script" "$MODE"; then
        echo -e "${GREEN}✓ $id benchmarks completed${NC}"
    else
        echo -e "${YELLOW}⚠ $id benchmarks failed or partially completed${NC}"
    fi
}

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Serializer Benchmark Runner${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Config: ${YELLOW}$PROJECT_ROOT/config/benchmark_config.yaml${NC}"
echo -e "Mode: ${YELLOW}$MODE${NC} (reps=$(bench_mode_reps "$MODE"))  Lang filter: ${YELLOW}${LANG_FILTER:-all enabled}${NC}"
echo -e "Data model: ${YELLOW}v2${NC} (type_ids: message document telemetry strings event)"

# Timestamp used for all result files in this run so they share the same stem.
TS=$(date +%Y-%m-%d-%H%M%S)
export BENCHMARK_TS="$TS"
export BENCHMARK_SEED="$(bench_random_seed)"
echo -e "Run timestamp: ${YELLOW}$TS${NC}  seed: ${YELLOW}$BENCHMARK_SEED${NC}"

mkdir -p "$LOG_DIR" "$REPORT_DIR"

# Discover enabled languages from master config.
# Read into a variable first so a failing bench_read_config trips set -e
# (process substitution failures are not always fatal under set -e).
LANG_RUNNERS="$(bench_read_config --lang-runners)"
if [[ -z "$LANG_RUNNERS" ]]; then
    echo -e "${RED}Error: no enabled languages from config (bench_read_config --lang-runners)${NC}"
    exit 1
fi
ENABLED_LANGS=()
while IFS='|' read -r id runner_dir runner_script; do
    [[ -z "$id" ]] && continue
    ENABLED_LANGS+=("$id")
    run_lang "$id" "$runner_dir" "$runner_script"
done <<< "$LANG_RUNNERS"

echo ""
echo -e "${BLUE}Capturing run config sidecars (configs.json)...${NC}"
cd "$PROJECT_ROOT"
for lang in "${ENABLED_LANGS[@]}"; do
    f="$LOG_DIR/$lang/${BENCHMARK_TS}.csv"
    # language_log_dirs may differ; try config path then default
    if [[ ! -f "$f" ]]; then
        f="$PROJECT_ROOT/logs/$lang/${BENCHMARK_TS}.csv"
    fi
    if [[ -f "$f" ]]; then
        if command -v python3 >/dev/null 2>&1; then
            PYTHONPATH="$PROJECT_ROOT/analysis/src" python3 -m benchmark_analysis.environment "$f" >/dev/null 2>&1 \
                && echo -e "  $lang: ${GREEN}✓${NC} configs.json written" \
                || echo -e "  $lang: ${YELLOW}skipped${NC} (analysis package not available)"
        fi
    fi
done

echo ""
echo -e "${BLUE}Verifying Results...${NC}"
cd "$PROJECT_ROOT"
for lang in "${ENABLED_LANGS[@]}"; do
    f="$LOG_DIR/$lang/${BENCHMARK_TS}.csv"
    if [[ ! -f "$f" ]]; then
        f="$PROJECT_ROOT/logs/$lang/${BENCHMARK_TS}.csv"
    fi
    if [[ -f "$f" ]]; then
        n=$(tail -n +2 "$f" | wc -l 2>/dev/null || echo 0)
        echo -e "  $lang: ${GREEN}$n${NC} records  (${BENCHMARK_TS}.csv)"
    else
        echo -e "  $lang: ${YELLOW}no log${NC}"
    fi
done

if [ "$GENERATE_ARTIFACTS" = true ] || [ "$CHECK_REGRESSION" = true ] || [ "$SAVE_BASELINE" = true ]; then
    echo ""
    echo -e "${BLUE}Generating Reports...${NC}"
    ANALYSIS_CMD="analyze-benchmarks --logs-root \"$LOG_DIR\" --config \"$PROJECT_ROOT/config/benchmark_config.yaml\""
    if [[ -n "$LANG_FILTER" ]]; then
        ANALYSIS_CMD="$ANALYSIS_CMD -l \"$LANG_FILTER\""
    fi
    for lang in "${ENABLED_LANGS[@]}"; do
        f="$LOG_DIR/$lang/${BENCHMARK_TS}.csv"
        [[ -f "$f" ]] || f="$PROJECT_ROOT/logs/$lang/${BENCHMARK_TS}.csv"
        [[ -f "$f" ]] || continue
        ANALYSIS_CMD="$ANALYSIS_CMD --logs ${lang}=\"$f\""
    done
    if [ "$GENERATE_ARTIFACTS" != true ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --skip-generate"
    fi
    [ "$CHECK_REGRESSION" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --check-regression --regression-threshold $REGRESSION_THRESHOLD"
    [ "$SAVE_BASELINE" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --save-baseline"
    if command -v analyze-benchmarks >/dev/null 2>&1; then
        eval "$ANALYSIS_CMD" || true
    else
        PYTHONPATH="$PROJECT_ROOT/analysis/src" python3 -m benchmark_analysis.cli \
            --logs-root "$LOG_DIR" \
            --config "$PROJECT_ROOT/config/benchmark_config.yaml" \
            ${LANG_FILTER:+-l "$LANG_FILTER"} \
            $([ "$GENERATE_ARTIFACTS" != true ] && echo --skip-generate) || true
    fi
fi

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Benchmark Run Complete${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results: ${YELLOW}$LOG_DIR${NC}"
echo -e "Config:  ${YELLOW}$PROJECT_ROOT/config/benchmark_config.yaml${NC}"
