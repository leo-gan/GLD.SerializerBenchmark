#!/usr/bin/env bash
# Unified benchmark runner for all languages
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
REPORT_DIR="$PROJECT_ROOT/reports"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

MODE="all-single"
GENERATE_PLOTS=false
GENERATE_SUMMARY=false
CHECK_REGRESSION=false
REGRESSION_THRESHOLD=10
SAVE_BASELINE=false
LANG_FILTER=""  # empty = all enabled

print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run serializer benchmarks for supported languages and optionally generate reports.

OPTIONS:
    -m, --mode MODE             smoke|all-single|full|research (default: all-single)
    -l, --lang LANG             Only run one language: csharp|python|rust|c|javascript
    -p, --plots                 Generate violin plots under reports/plots/violin/ (local; gitignored)
    -s, --summary               Generate Markdown summary under reports/ (local)
    -r, --regression-check      Check for performance regressions
    -t, --threshold PERCENT     Regression threshold percentage (default: 10)
    -b, --save-baseline         Save current results as baseline
    -h, --help                  Show this help message

Reports default to reports/ (gitignored). For GitHub Pages snapshots, run
analyze-benchmarks with --output-dir docs/analysis and commit that tree.
EOF
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode) MODE="$2"; shift 2 ;;
        -l|--lang) LANG_FILTER="$2"; shift 2 ;;
        -p|--plots) GENERATE_PLOTS=true; shift ;;
        -s|--summary) GENERATE_SUMMARY=true; shift ;;
        -r|--regression-check) CHECK_REGRESSION=true; shift ;;
        -t|--threshold) REGRESSION_THRESHOLD="$2"; shift 2 ;;
        -b|--save-baseline) SAVE_BASELINE=true; shift ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1"; print_usage; exit 1 ;;
    esac
done

case "$MODE" in smoke|all-single|full|research) ;; *)
    echo -e "${RED}Error: Invalid mode '$MODE'${NC}"; exit 1 ;;
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
echo -e "Mode: ${YELLOW}$MODE${NC}  Lang filter: ${YELLOW}${LANG_FILTER:-all}${NC}"
mkdir -p "$LOG_DIR" "$REPORT_DIR"

run_lang csharp   c-sharp     scripts/run-benchmarks.sh
run_lang python   python      scripts/run-benchmarks.sh
run_lang rust     rust        scripts/run-benchmarks.sh
run_lang c        c           scripts/run-benchmarks.sh
run_lang javascript javascript scripts/run-benchmarks.sh

echo ""
echo -e "${BLUE}Verifying Results...${NC}"
cd "$PROJECT_ROOT"
for lang in csharp python rust c javascript; do
    f="$LOG_DIR/$lang/benchmark-log.csv"
    if [[ -f "$f" ]]; then
        n=$(tail -n +2 "$f" | wc -l)
        echo -e "  $lang: ${GREEN}$n${NC} records"
    else
        echo -e "  $lang: ${YELLOW}no log${NC}"
    fi
done

if [ "$GENERATE_PLOTS" = true ] || [ "$GENERATE_SUMMARY" = true ] || [ "$CHECK_REGRESSION" = true ] || [ "$SAVE_BASELINE" = true ]; then
    echo ""
    echo -e "${BLUE}Generating Reports...${NC}"
    ANALYSIS_CMD="analyze-benchmarks"
    for lang in csharp python rust c javascript; do
        f="$LOG_DIR/$lang/benchmark-log.csv"
        [[ -f "$f" ]] || continue
        case $lang in
            csharp) ANALYSIS_CMD="$ANALYSIS_CMD --csharp-logs \"$f\"" ;;
            python) ANALYSIS_CMD="$ANALYSIS_CMD --python-logs \"$f\"" ;;
            rust) ANALYSIS_CMD="$ANALYSIS_CMD --rust-logs \"$f\"" ;;
            c) ANALYSIS_CMD="$ANALYSIS_CMD --c-logs \"$f\"" ;;
            javascript) ANALYSIS_CMD="$ANALYSIS_CMD --javascript-logs \"$f\"" ;;
        esac
    done
    ANALYSIS_CMD="$ANALYSIS_CMD --output-dir \"$REPORT_DIR\""
    [ "$GENERATE_PLOTS" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --generate-plots"
    [ "$GENERATE_SUMMARY" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --generate-summary"
    [ "$CHECK_REGRESSION" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --check-regression --regression-threshold $REGRESSION_THRESHOLD"
    [ "$SAVE_BASELINE" = true ] && ANALYSIS_CMD="$ANALYSIS_CMD --save-baseline"
    if command -v analyze-benchmarks >/dev/null 2>&1; then
        eval "$ANALYSIS_CMD" || true
    else
        PYTHONPATH="$PROJECT_ROOT/analysis/src" python3 -m benchmark_analysis.cli \
            --logs-root "$LOG_DIR" --output-dir "$REPORT_DIR" \
            $([ "$GENERATE_SUMMARY" = true ] && echo --generate-summary) \
            $([ "$GENERATE_PLOTS" = true ] && echo --generate-plots) || true
    fi
fi

echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Benchmark Run Complete${NC}"
echo -e "${GREEN}============================================${NC}"
echo -e "Results: ${YELLOW}$LOG_DIR${NC}"
echo -e "Config:  ${YELLOW}$PROJECT_ROOT/config/benchmark_config.yaml${NC}"
