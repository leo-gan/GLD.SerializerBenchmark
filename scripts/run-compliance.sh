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

export PATH="${HOME}/.local/go/bin:${HOME}/.cargo/bin:${HOME}/.dotnet:${HOME}/.local/bin:${HOME}/.local/php/bin:${HOME}/.local/maven/bin:${HOME}/.local/jdk-21/bin:${HOME}/.local/zig:${HOME}/.local/share/swiftly/bin:${PATH}"
if [[ -f "${HOME}/.local/share/swiftly/env.sh" ]]; then
    # shellcheck disable=SC1091
    source "${HOME}/.local/share/swiftly/env.sh"
fi
if [[ -x "${HOME}/.pixi/bin/pixi" ]]; then
    export PATH="${HOME}/.pixi/bin:${PATH}"
fi

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

fmt_args=()
for f in "${FORMATS[@]+"${FORMATS[@]}"}"; do
    fmt_args+=(--format "$f")
done

run_lang() {
    local lang="$1"
    shift
    echo ""
    echo -e "${BLUE}${lang} compliance…${NC}"
    local out="$LOG_DIR/${TS}-${lang}.json"
    set +e
    "$@" --json-out "$out" "${fmt_args[@]+"${fmt_args[@]}"}"
    local st=$?
    set -e
    if [[ "$st" -eq 0 && -s "$out" ]]; then
        cp -f "$out" "$LOG_DIR/latest-${lang}.json"
    else
        echo -e "${YELLOW}⚠ ${lang} compliance exited ${st}${NC}"
    fi
}

if command -v node >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/javascript/src/compliance.mjs" ]]; then
    run_lang javascript env -C "$PROJECT_ROOT/javascript" node src/compliance.mjs
fi
if command -v go >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/go/compliance/main.go" ]]; then
    run_lang go env -C "$PROJECT_ROOT/go" go run ./compliance
fi
if command -v cargo >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/rust/src/bin/compliance.rs" ]]; then
    run_lang rust env -C "$PROJECT_ROOT/rust" cargo run --quiet --bin compliance --
fi
if command -v mvn >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/java/src/main/java/benchmark/Compliance.java" ]]; then
    echo ""
    echo -e "${BLUE}java compliance…${NC}"
    JAVA_OUT="$LOG_DIR/${TS}-java.json"
    set +e
    (cd "$PROJECT_ROOT/java" && mvn -q -DskipTests compile exec:java -Dexec.mainClass=benchmark.Compliance -Dexec.args="--json-out ${JAVA_OUT} ${fmt_args[*]}")
    JAVA_ST=$?
    set -e
    if [[ "$JAVA_ST" -eq 0 && -s "$JAVA_OUT" ]]; then
        cp -f "$JAVA_OUT" "$LOG_DIR/latest-java.json"
    else
        echo -e "${YELLOW}⚠ java compliance exited ${JAVA_ST}${NC}"
    fi
fi
if [[ -x "$PROJECT_ROOT/kotlin/gradlew" && -f "$PROJECT_ROOT/kotlin/src/main/kotlin/benchmark/Compliance.kt" ]]; then
    echo ""
    echo -e "${BLUE}kotlin compliance…${NC}"
    KT_OUT="$LOG_DIR/${TS}-kotlin.json"
    set +e
    (cd "$PROJECT_ROOT/kotlin" && ./gradlew -q run --args="compliance --json-out ${KT_OUT} ${fmt_args[*]}")
    KT_ST=$?
    set -e
    if [[ "$KT_ST" -eq 0 && -s "$KT_OUT" ]]; then
        cp -f "$KT_OUT" "$LOG_DIR/latest-kotlin.json"
    else
        echo -e "${YELLOW}⚠ kotlin compliance exited ${KT_ST}${NC}"
    fi
fi
if command -v dotnet >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/c-sharp/src/Compliance.cs" ]]; then
    run_lang csharp env -C "$PROJECT_ROOT/c-sharp/src" dotnet run -c Release --no-restore -- compliance
fi
if command -v php >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/php/src/compliance.php" ]]; then
    run_lang php php "$PROJECT_ROOT/php/src/compliance.php"
fi
if command -v swift >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/swift/compliance.swift" ]]; then
    run_lang swift swift "$PROJECT_ROOT/swift/compliance.swift"
fi
NLOHMANN="$PROJECT_ROOT/cpp/third_party/nlohmann_json/include"
if command -v g++ >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/cpp/src/compliance.cpp" && -d "$NLOHMANN" ]]; then
    CPP_BIN="$LOG_DIR/compliance-cpp"
    if [[ ! -x "$CPP_BIN" || "$PROJECT_ROOT/cpp/src/compliance.cpp" -nt "$CPP_BIN" ]]; then
        g++ -O2 -std=c++20 -I"$NLOHMANN" "$PROJECT_ROOT/cpp/src/compliance.cpp" -o "$CPP_BIN" || true
    fi
    if [[ -x "$CPP_BIN" ]]; then
        run_lang cpp "$CPP_BIN"
    fi
fi
ZIG_BIN=""
if command -v zig >/dev/null 2>&1; then
    ZIG_BIN="$(command -v zig)"
elif [[ -x "${HOME}/.local/zig/zig" ]]; then
    ZIG_BIN="${HOME}/.local/zig/zig"
fi
if [[ -n "$ZIG_BIN" && -f "$PROJECT_ROOT/zig/src/compliance.zig" ]]; then
    run_lang zig env -C "$PROJECT_ROOT/zig" "$ZIG_BIN" run src/compliance.zig --
fi
CJSON_H="$PROJECT_ROOT/c/third_party/cJSON/cJSON.h"
if command -v pixi >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/mojo/src/compliance.mojo" ]]; then
    echo ""
    echo -e "${BLUE}mojo compliance…${NC}"
    MOJO_OUT="$LOG_DIR/${TS}-mojo.json"
    MOJO_LIST="$LOG_DIR/${TS}-mojo-catalog.txt"
    find "$PROJECT_ROOT/compliance/data" -name '*.json' ! -name '_*' | sort > "$MOJO_LIST"
    set +e
    (
        cd "$PROJECT_ROOT/mojo"
        if [[ ! -d .pixi/envs/default ]]; then
            pixi install
        fi
        pixi run mojo run \
            -I src -I vendor/cbor_src -I vendor/pb_src -I vendor/toml_src \
            -I vendor/ehsanmok_src -I vendor/gldjson_src -I vendor/yaml_src \
            -I vendor/msgpack_src \
            src/compliance.mojo -- --json-out "$MOJO_OUT" --list "$MOJO_LIST" "${fmt_args[@]+"${fmt_args[@]}"}"
    )
    MOJO_ST=$?
    set -e
    if [[ "$MOJO_ST" -eq 0 && -s "$MOJO_OUT" ]]; then
        cp -f "$MOJO_OUT" "$LOG_DIR/latest-mojo.json"
    else
        echo -e "${YELLOW}⚠ mojo compliance exited ${MOJO_ST}${NC}"
    fi
fi
if command -v gcc >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/c/src/compliance.c" && -f "$CJSON_H" ]]; then
    C_BIN="$LOG_DIR/compliance-c"
    if [[ ! -x "$C_BIN" || "$PROJECT_ROOT/c/src/compliance.c" -nt "$C_BIN" ]]; then
        gcc -O2 -I"$PROJECT_ROOT/c/third_party/cJSON" \
            "$PROJECT_ROOT/c/src/compliance.c" \
            "$PROJECT_ROOT/c/third_party/cJSON/cJSON.c" \
            -o "$C_BIN" || true
    fi
    if [[ -x "$C_BIN" ]]; then
        run_lang c "$C_BIN"
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
