#!/bin/bash
# Unified benchmark runner for all languages
# Runs C# and Python benchmarks, generates reports, and optionally checks for regressions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
LOG_DIR="$PROJECT_ROOT/logs"
REPORT_DIR="$PROJECT_ROOT/reports"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Default values
MODE="all-single"
GENERATE_DASHBOARD=false
GENERATE_SUMMARY=false
CHECK_REGRESSION=false
REGRESSION_THRESHOLD=10
SAVE_BASELINE=false

# Print usage
print_usage() {
    cat << EOF
Usage: $(basename "$0") [OPTIONS]

Run serializer benchmarks for all supported languages and optionally generate reports.

OPTIONS:
    -m, --mode MODE             Benchmark mode: smoke|all-single|full (default: all-single)
    -d, --dashboard             Generate HTML dashboard
    -s, --summary               Generate Markdown summary
    -r, --regression-check      Check for performance regressions
    -t, --threshold PERCENT     Regression threshold percentage (default: 10)
    -b, --save-baseline         Save current results as baseline
    -h, --help                  Show this help message

EXAMPLES:
    # Run smoke tests only
    $(basename "$0") --mode smoke

    # Run full benchmarks with dashboard and summary
    $(basename "$0") --mode full --dashboard --summary

    # Check for regressions against baseline
    $(basename "$0") --mode all-single --regression-check --threshold 15

    # Save current results as new baseline
    $(basename "$0") --mode all-single --save-baseline

EOF
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -m|--mode)
            MODE="$2"
            shift 2
            ;;
        -d|--dashboard)
            GENERATE_DASHBOARD=true
            shift
            ;;
        -s|--summary)
            GENERATE_SUMMARY=true
            shift
            ;;
        -r|--regression-check)
            CHECK_REGRESSION=true
            shift
            ;;
        -t|--threshold)
            REGRESSION_THRESHOLD="$2"
            shift 2
            ;;
        -b|--save-baseline)
            SAVE_BASELINE=true
            shift
            ;;
        -h|--help)
            print_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_usage
            exit 1
            ;;
    esac
done

# Validate mode
case $MODE in
    smoke|all-single|full)
        ;;
    *)
        echo -e "${RED}Error: Invalid mode '$MODE'. Use smoke, all-single, or full.${NC}"
        exit 1
        ;;
esac

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Serializer Benchmark Runner${NC}"
echo -e "${BLUE}============================================${NC}"
echo ""
echo -e "Mode:               ${YELLOW}$MODE${NC}"
echo -e "Generate Dashboard: ${YELLOW}$GENERATE_DASHBOARD${NC}"
echo -e "Generate Summary:   ${YELLOW}$GENERATE_SUMMARY${NC}"
echo -e "Check Regression:   ${YELLOW}$CHECK_REGRESSION${NC}"
echo -e "Threshold:          ${YELLOW}${REGRESSION_THRESHOLD}%${NC}"
echo -e "Save Baseline:      ${YELLOW}$SAVE_BASELINE${NC}"
echo ""

# Create directories
mkdir -p "$LOG_DIR"
mkdir -p "$REPORT_DIR"

# Run C# Benchmark
echo -e "${BLUE}[1/3] Running C# Benchmarks...${NC}"
cd "$PROJECT_ROOT/c-sharp"
if ./scripts/run-benchmarks.sh "$MODE"; then
    echo -e "${GREEN}✓ C# benchmarks completed${NC}"
else
    echo -e "${YELLOW}⚠ C# benchmarks failed or partially completed${NC}"
fi

# Run Python Benchmark
echo ""
echo -e "${BLUE}[2/3] Running Python Benchmarks...${NC}"
cd "$PROJECT_ROOT/python"
if ./scripts/run-benchmarks.sh "$MODE"; then
    echo -e "${GREEN}✓ Python benchmarks completed${NC}"
else
    echo -e "${YELLOW}⚠ Python benchmarks failed or partially completed${NC}"
fi

# Verify results exist
echo ""
echo -e "${BLUE}[3/3] Verifying Results...${NC}"
cd "$PROJECT_ROOT"

CS_LOG="$LOG_DIR/csharp/benchmark-log.csv"
PY_LOG="$LOG_DIR/python/benchmark-log.csv"

CS_RECORDS=0
PY_RECORDS=0

if [ -f "$CS_LOG" ]; then
    CS_RECORDS=$(tail -n +2 "$CS_LOG" | wc -l)
    echo -e "C# records: ${GREEN}$CS_RECORDS${NC}"
else
    echo -e "C# log: ${YELLOW}Not found${NC}"
fi

if [ -f "$PY_LOG" ]; then
    PY_RECORDS=$(tail -n +2 "$PY_LOG" | wc -l)
    echo -e "Python records: ${GREEN}$PY_RECORDS${NC}"
else
    echo -e "Python log: ${YELLOW}Not found${NC}"
fi

# Generate reports if requested
if [ "$GENERATE_DASHBOARD" = true ] || [ "$GENERATE_SUMMARY" = true ] || [ "$CHECK_REGRESSION" = true ] || [ "$SAVE_BASELINE" = true ]; then
    echo ""
    echo -e "${BLUE}Generating Reports...${NC}"

    # Build analysis command
    ANALYSIS_CMD="analyze-benchmarks"

    if [ -f "$CS_LOG" ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --csharp-logs \"$CS_LOG\""
    fi

    if [ -f "$PY_LOG" ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --python-logs \"$PY_LOG\""
    fi

    ANALYSIS_CMD="$ANALYSIS_CMD --output-dir \"$REPORT_DIR\""

    if [ "$GENERATE_DASHBOARD" = true ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --generate-dashboard"
    fi

    if [ "$GENERATE_SUMMARY" = true ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --generate-summary"
    fi

    if [ "$CHECK_REGRESSION" = true ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --check-regression --regression-threshold $REGRESSION_THRESHOLD"
    fi

    if [ "$SAVE_BASELINE" = true ]; then
        ANALYSIS_CMD="$ANALYSIS_CMD --save-baseline"
    fi

    # Run analysis
    cd "$PROJECT_ROOT"
    if eval "$ANALYSIS_CMD"; then
        echo -e "${GREEN}✓ Analysis completed${NC}"
    else
        ANALYSIS_EXIT=$?
        if [ "$CHECK_REGRESSION" = true ] && [ $ANALYSIS_EXIT -eq 1 ]; then
            echo -e "${RED}✗ Performance regressions detected!${NC}"
            exit 1
        else
            echo -e "${YELLOW}⚠ Analysis completed with warnings${NC}"
        fi
    fi
fi

# Print summary
echo ""
echo -e "${GREEN}============================================${NC}"
echo -e "${GREEN}  Benchmark Run Complete${NC}"
echo -e "${GREEN}============================================${NC}"
echo ""
echo -e "Results:     ${YELLOW}$LOG_DIR${NC}"

if [ "$GENERATE_DASHBOARD" = true ] || [ "$GENERATE_SUMMARY" = true ]; then
    echo -e "Reports:     ${YELLOW}$REPORT_DIR${NC}"
fi

if [ "$GENERATE_SUMMARY" = true ] && [ -f "$REPORT_DIR/BENCHMARK_SUMMARY.md" ]; then
    echo -e "Summary:     ${YELLOW}$REPORT_DIR/BENCHMARK_SUMMARY.md${NC}"
fi

if [ "$GENERATE_DASHBOARD" = true ] && [ -f "$REPORT_DIR/dashboard/index.html" ]; then
    echo -e "Dashboard:   ${YELLOW}$REPORT_DIR/dashboard/index.html${NC}"
    echo ""
    echo "To view dashboard:"
    echo "  python -m http.server 8080 -d $REPORT_DIR/dashboard"
    echo "  Then open: http://localhost:8080"
fi

echo ""
