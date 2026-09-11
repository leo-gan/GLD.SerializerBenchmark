#!/usr/bin/env bash
# Spec-compliance runner — the quality counterpart to run-all-benchmarks.sh.
#
# Performance:  ./scripts/run-all-benchmarks.sh
# Compliance:   ./scripts/run-compliance.sh
#
# Library deviations print RFC/spec URLs and do not fail the process.
# Exit 2 only if the catalog cannot be loaded.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
# shellcheck source=lib/config.sh
source "$PROJECT_ROOT/scripts/lib/config.sh"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'

DETAILED=false
JSON_OUT=""
FORMATS=()
ADAPTERS=()

print_usage() {
    cat << USAGE
Usage: $(basename "$0") [OPTIONS]

Run serialization compliance suites (JSON, YAML, TOML, CBOR, MessagePack,
schema/binary cousins, Ion, UBJSON, Smile).
This is the spec-quality counterpart to run-all-benchmarks.sh: same libraries,
cited RFC/spec sections, no timings.

OPTIONS:
    -f, --format NAME     Limit to a format (repeatable): json yaml toml cbor msgpack protobuf avro bson flatbuffers ion ubjson smile
    -s, --serializer NAME Limit to a serializer (repeatable): json orjson msgspec yaml …
    -d, --detailed        Print every case, not only the summary and failures
    -o, --json-out PATH   Write the machine-readable report (default: logs/compliance/<ts>.json)
    -h, --help            Show this help message

Examples:
    ./scripts/run-compliance.sh
    ./scripts/run-compliance.sh --format json --serializer orjson
    ./scripts/run-compliance.sh --detailed
USAGE
}

while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--format) FORMATS+=("$2"); shift 2 ;;
        -s|--serializer|-a|--adapter) ADAPTERS+=("$2"); shift 2 ;;
        -d|--detailed) DETAILED=true; shift ;;
        -o|--json-out) JSON_OUT="$2"; shift 2 ;;
        -h|--help) print_usage; exit 0 ;;
        *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
    esac
done

if ! command -v uv >/dev/null 2>&1; then
    echo -e "${RED}Error: uv not found. Run: ./scripts/install-host-requirements.sh python${NC}" >&2
    exit 1
fi

TS=$(date +%Y-%m-%d-%H%M%S)
LOG_DIR="$PROJECT_ROOT/logs/compliance"
mkdir -p "$LOG_DIR"
if [[ -z "$JSON_OUT" ]]; then
    JSON_OUT="$LOG_DIR/${TS}.json"
fi

echo -e "${BLUE}============================================${NC}"
echo -e "${BLUE}  Serializer Compliance Runner${NC}"
echo -e "${BLUE}============================================${NC}"
echo -e "Corpus: ${YELLOW}compliance/data/${NC}"
echo -e "Report: ${YELLOW}$JSON_OUT${NC}"
if [[ ${#FORMATS[@]} -gt 0 ]]; then
    echo -e "Formats: ${YELLOW}${FORMATS[*]}${NC}"
fi
if [[ ${#ADAPTERS[@]} -gt 0 ]]; then
    echo -e "Serializers: ${YELLOW}${ADAPTERS[*]}${NC}"
fi
echo ""

PY_DIR="$PROJECT_ROOT/python"
cd "$PY_DIR"
uv sync --quiet

ARGS=(--json-out "$JSON_OUT")
if [[ "$DETAILED" == true ]]; then
    ARGS+=(--detailed)
fi
for f in "${FORMATS[@]+"${FORMATS[@]}"}"; do
    ARGS+=(--format "$f")
done
for a in "${ADAPTERS[@]+"${ADAPTERS[@]}"}"; do
    ARGS+=(--serializer "$a")
done

export PYTHONPATH="$PY_DIR/src${PYTHONPATH:+:$PYTHONPATH}"
set +e
uv run python -m compliance "${ARGS[@]}"
STATUS=$?
set -e
if [[ "$STATUS" -eq 0 ]]; then
    cp -f "$JSON_OUT" "$LOG_DIR/latest-python.json"
fi

JS_STATUS=0
if command -v node >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/javascript/src/compliance.mjs" ]]; then
    echo ""
    echo -e "${BLUE}JavaScript compliance…${NC}"
    JS_OUT="$LOG_DIR/${TS}-javascript.json"
    JS_ARGS=(--json-out "$JS_OUT")
    for f in "${FORMATS[@]+"${FORMATS[@]}"}"; do
        JS_ARGS+=(--format "$f")
    done
    # Do not forward Python serializer names. JS libraries have different names.
    set +e
    (cd "$PROJECT_ROOT/javascript" && node src/compliance.mjs "${JS_ARGS[@]}")
    JS_STATUS=$?
    set -e
    if [[ "$JS_STATUS" -eq 0 ]]; then
        cp -f "$JS_OUT" "$LOG_DIR/latest-javascript.json"
    else
        echo -e "${YELLOW}⚠ JavaScript compliance exited $JS_STATUS${NC}"
    fi
fi

echo ""
if [[ "$STATUS" -eq 0 ]]; then
    echo -e "${GREEN}✓ Compliance catalog finished${NC} (library misses are listed above; they are not a runner failure)"
    if [[ ${#FORMATS[@]} -eq 0 && ${#ADAPTERS[@]} -eq 0 ]]; then
        cp -f "$JSON_OUT" "$LOG_DIR/latest.json"
        echo -e "${BLUE}Syncing Dashboard payload…${NC}"
        if python3 "$PROJECT_ROOT/dashboard/scripts/sync-compliance.py"; then
            echo -e "${GREEN}✓ Dashboard data/compliance.json updated${NC}"
        else
            echo -e "${YELLOW}⚠ Dashboard sync skipped or failed${NC}"
        fi
    else
        echo -e "${YELLOW}Filtered run — Dashboard payload left unchanged (latest.json is the last full run)${NC}"
    fi
elif [[ "$STATUS" -eq 2 ]]; then
    echo -e "${RED}✗ Catalog could not be loaded${NC}"
else
    echo -e "${RED}✗ Compliance runner exited $STATUS${NC}"
fi
exit "$STATUS"
