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
    echo ""
    echo -e "${BLUE}csharp compliance…${NC}"
    CS_DLL="$PROJECT_ROOT/c-sharp/src/bin/Release/net8.0/GLD.SerializerBenchmark.dll"
    if [[ ! -f "$CS_DLL" ]]; then
        (cd "$PROJECT_ROOT/c-sharp/src" && dotnet build -c Release --nologo -v q) || true
    fi
    CS_PART="$LOG_DIR/csharp-parts"
    mkdir -p "$CS_PART"
    CS_SERS=(
        "System.Text.Json" "Json.Net" "Json.Net (Helper)" "Jil" "SpanJson" "Utf8Json"
        "fastJson" "ServiceStack Json" "FsPicklerJson" "MS DataContract Json" "MS Bond Json"
        "YamlDotNet" "SharpYaml" "MessagePack-CSharp" "Google.Protobuf" "ProtoBuf"
        "LightProto" "Apache.Avro" "MS Bond Compact" "MS Bond Fast" "FlatSharp"
    )
    # NetJSON hangs on some catalog cases; keep it out of the unattended loop.
    export DOTNET_GCHeapHardLimit="${DOTNET_GCHeapHardLimit:-0x80000000}"
    for s in "${CS_SERS[@]}"; do
        safe=$(echo "$s" | tr ' /()' '____')
        part="$CS_PART/${safe}.json"
        set +e
        timeout 180 dotnet "$CS_DLL" compliance --serializer "$s" --json-out "$part" "${fmt_args[@]+"${fmt_args[@]}"}"
        st=$?
        set -e
        if [[ $st -ne 0 || ! -s "$part" ]]; then
            echo -e "${YELLOW}⚠ csharp ${s} exited ${st}${NC}"
            rm -f "$part" "$part.part"
        fi
    done
    CS_OUT="$LOG_DIR/${TS}-csharp.json"
    python3 - "$CS_PART" "$CS_OUT" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
parts = sorted(Path(sys.argv[1]).glob("*.json"))
rows, errs, fmts = [], [], set()
for p in parts:
    d = json.loads(p.read_text())
    rows.extend(d.get("results") or [])
    errs.extend(d.get("serializer_errors") or [])
    for r in d.get("results") or []:
        if r.get("format"):
            fmts.add(r["format"])
passed = sum(1 for r in rows if r.get("outcome") == "pass")
failed = sum(1 for r in rows if r.get("outcome") == "fail")
skipped = sum(1 for r in rows if r.get("outcome") == "skip")
doc = {
    "schema": "gld.dashboard.compliance/1",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "language": "csharp",
    "languages": ["csharp"],
    "policy": "report-only",
    "scope": {"formats": sorted(fmts)},
    "passed": passed,
    "failed": failed,
    "skipped": skipped,
    "errors": len(rows) - passed - failed - skipped,
    "catalog_errors": [],
    "serializer_errors": errs,
    "results": rows,
}
Path(sys.argv[2]).write_text(json.dumps(doc))
print(f"  {passed} pass  {failed} fail  {len(rows)} total  {len({r.get('serializer') for r in rows})} serializers")
PY
    if [[ -s "$CS_OUT" ]]; then
        cp -f "$CS_OUT" "$LOG_DIR/latest-csharp.json"
    fi
fi
if command -v php >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/php/src/compliance.php" ]]; then
    run_lang php php "$PROJECT_ROOT/php/src/compliance.php"
fi
SWIFT_COMPLIANCE=""
if command -v swift >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/swift/Package.swift" ]]; then
    SWIFT_BIN_DIR="$(cd "$PROJECT_ROOT/swift" && swift build -c release --show-bin-path 2>/dev/null || true)"
    if [[ -n "$SWIFT_BIN_DIR" && -x "$SWIFT_BIN_DIR/Compliance" ]]; then
        SWIFT_COMPLIANCE="$SWIFT_BIN_DIR/Compliance"
    fi
fi
if [[ -z "$SWIFT_COMPLIANCE" ]]; then
    for p in "$PROJECT_ROOT"/swift/.build/*/release/Compliance; do
        if [[ -x "$p" ]]; then SWIFT_COMPLIANCE="$p"; break; fi
    done
fi
if [[ -n "$SWIFT_COMPLIANCE" ]]; then
    run_lang swift "$SWIFT_COMPLIANCE"
elif command -v swift >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/swift/compliance.swift" ]]; then
    run_lang swift swift "$PROJECT_ROOT/swift/compliance.swift"
fi
NLOHMANN="$PROJECT_ROOT/cpp/third_party/nlohmann_json/include"
if command -v g++ >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/cpp/src/compliance.cpp" && -d "$NLOHMANN" ]]; then
    CPP_BIN="$LOG_DIR/compliance-cpp"
    CPP_INC=(-I"$NLOHMANN")
    CPP_LIBS=()
    for d in rapidjson/include glaze/include ArduinoJson/src jsoncons/include msgpack-c/include flatbuffers/include yaml-cpp/include; do
        if [[ -d "$PROJECT_ROOT/cpp/third_party/$d" ]]; then
            CPP_INC+=(-I"$PROJECT_ROOT/cpp/third_party/$d")
        fi
    done
    YAML_LIB="$PROJECT_ROOT/cpp/third_party/_fetch/yaml_cpp-build/libyaml-cpp.a"
    if [[ -f "$YAML_LIB" ]]; then
        CPP_LIBS+=("$YAML_LIB")
    fi
    if [[ ! -x "$CPP_BIN" || "$PROJECT_ROOT/cpp/src/compliance.cpp" -nt "$CPP_BIN" ]]; then
        g++ -O2 -std=c++20 "${CPP_INC[@]}" "$PROJECT_ROOT/cpp/src/compliance.cpp" "${CPP_LIBS[@]}" -o "$CPP_BIN" || true
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
if [[ -n "$ZIG_BIN" && -f "$PROJECT_ROOT/zig/build.zig" ]]; then
    echo ""
    echo -e "${BLUE}zig compliance…${NC}"
    (cd "$PROJECT_ROOT/zig" && "$ZIG_BIN" build -Doptimize=ReleaseSafe) || true
    ZIG_EXE="$PROJECT_ROOT/zig/zig-out/bin/compliance"
    if [[ -x "$ZIG_EXE" ]]; then
        ZIG_PART="$LOG_DIR/zig-parts"
        mkdir -p "$ZIG_PART"
        ZIG_FMTS=(json protobuf msgpack capnp cbor flatbuffers zon)
        if [[ ${#FORMATS[@]} -gt 0 ]]; then
            ZIG_FMTS=("${FORMATS[@]}")
        fi
        for zf in "${ZIG_FMTS[@]}"; do
            zpart="$ZIG_PART/${zf}.json"
            set +e
            timeout 120 "$ZIG_EXE" --format "$zf" --json-out "$zpart"
            zst=$?
            set -e
            if [[ $zst -ne 0 || ! -s "$zpart" ]]; then
                echo -e "${YELLOW}⚠ zig ${zf} exited ${zst}${NC}"
                rm -f "$zpart"
            fi
        done
        ZIG_OUT="$LOG_DIR/${TS}-zig.json"
        python3 - "$ZIG_PART" "$ZIG_OUT" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
parts = sorted(Path(sys.argv[1]).glob("*.json"))
rows = []
for p in parts:
    rows.extend(json.loads(p.read_text()).get("results") or [])
passed = sum(1 for r in rows if r.get("outcome") == "pass")
failed = sum(1 for r in rows if r.get("outcome") == "fail")
doc = {
    "schema": "gld.dashboard.compliance/1",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "language": "zig",
    "languages": ["zig"],
    "policy": "report-only",
    "scope": {"formats": sorted({r.get("format") for r in rows if r.get("format")})},
    "passed": passed,
    "failed": failed,
    "skipped": 0,
    "errors": 0,
    "catalog_errors": [],
    "serializer_errors": [],
    "results": rows,
}
Path(sys.argv[2]).write_text(json.dumps(doc))
print(f"  {passed} pass  {failed} fail  {len(rows)} total  {len({r.get('serializer') for r in rows})} serializers")
PY
        if [[ -s "$ZIG_OUT" ]]; then
            cp -f "$ZIG_OUT" "$LOG_DIR/latest-zig.json"
        fi
    fi
fi
CJSON_H="$PROJECT_ROOT/c/third_party/cJSON/cJSON.h"
if command -v pixi >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/mojo/src/compliance.mojo" ]]; then
    echo ""
    echo -e "${BLUE}mojo compliance…${NC}"
    MOJO_OUT="$LOG_DIR/${TS}-mojo.json"
    MOJO_BIN="$LOG_DIR/mojo-compliance"
    MOJO_PART="$LOG_DIR/mojo-parts"
    mkdir -p "$MOJO_PART"
    (
        cd "$PROJECT_ROOT/mojo"
        if [[ ! -d .pixi/envs/default ]]; then
            pixi install
        fi
        pixi run mojo build \
            -I src -I vendor/cbor_src -I vendor/pb_src -I vendor/toml_src \
            -I vendor/ehsanmok_src -I vendor/gldjson_src -I vendor/yaml_src \
            -I vendor/msgpack_src \
            src/compliance.mojo -o "$MOJO_BIN"
    ) || true
    if [[ -x "$MOJO_BIN" ]]; then
        python3 - "$PROJECT_ROOT/compliance/data" "$MOJO_PART" <<'PY'
import json, sys
from pathlib import Path
root, dest = Path(sys.argv[1]), Path(sys.argv[2])
# EmberJson OOMs on official YAML catalogs (~230KB). Split those into small chunks.
for src in sorted(root.rglob("*.json")):
    if src.name.startswith("_"):
        continue
    rel = src.relative_to(root)
    if src.parent.name == "yaml":
        doc = json.loads(src.read_text())
        cases = doc.get("cases") or []
        meta = {k: v for k, v in doc.items() if k != "cases"}
        step = 20
        for i in range(0, len(cases), step):
            chunk = dict(meta)
            chunk["cases"] = cases[i : i + step]
            out = dest / f"yaml-{src.stem}-{i:04d}.json"
            out.write_text(json.dumps(chunk, separators=(",", ":")))
    else:
        (dest / f"{rel.parent}-{src.stem}.json").write_text(src.read_text())
print("mojo catalog chunks ready")
PY
        for chunk in "$MOJO_PART"/*.json; do
            [[ "$chunk" == *-out.json ]] && continue
            list="$chunk.list"
            printf '%s\n' "$chunk" > "$list"
            out="${chunk%.json}-out.json"
            set +e
            timeout 25 "$MOJO_BIN" --json-out "$out" --list "$list" "${fmt_args[@]+"${fmt_args[@]}"}"
            st=$?
            set -e
            if [[ $st -ne 0 || ! -s "$out" ]]; then
                echo -e "${YELLOW}⚠ mojo chunk $(basename "$chunk") exited ${st}${NC}"
                rm -f "$out"
            fi
        done
        python3 - "$MOJO_PART" "$MOJO_OUT" <<'PY'
import json, sys
from datetime import datetime, timezone
from pathlib import Path
rows = []
for p in sorted(Path(sys.argv[1]).glob("*-out.json")):
    rows.extend(json.loads(p.read_text()).get("results") or [])
passed = sum(1 for r in rows if r.get("outcome") == "pass")
failed = sum(1 for r in rows if r.get("outcome") == "fail")
doc = {
    "schema": "gld.dashboard.compliance/1",
    "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
    "language": "mojo",
    "languages": ["mojo"],
    "policy": "report-only",
    "scope": {"formats": sorted({r.get("format") for r in rows if r.get("format")})},
    "passed": passed,
    "failed": failed,
    "skipped": 0,
    "errors": 0,
    "catalog_errors": [],
    "serializer_errors": [],
    "results": rows,
}
Path(sys.argv[2]).write_text(json.dumps(doc))
print(f"  {passed} pass  {failed} fail  {len(rows)} total  {len({r.get('serializer') for r in rows})} serializers")
PY
        if [[ -s "$MOJO_OUT" ]]; then
            cp -f "$MOJO_OUT" "$LOG_DIR/latest-mojo.json"
        fi
    else
        echo -e "${YELLOW}⚠ mojo compliance failed to build${NC}"
    fi
fi
if command -v cmake >/dev/null 2>&1 && [[ -f "$PROJECT_ROOT/c/CMakeLists.txt" ]]; then
    echo ""
    echo -e "${BLUE}c compliance (mapping-driven)…${NC}"
    cmake -S "$PROJECT_ROOT/c" -B "$PROJECT_ROOT/c/build" -DCMAKE_BUILD_TYPE=Release >/dev/null
    if cmake --build "$PROJECT_ROOT/c/build" --target c_compliance -j"$(nproc 2>/dev/null || echo 2)"; then
        run_lang c "$PROJECT_ROOT/c/build/c_compliance"
    else
        echo -e "${YELLOW}⚠ c_compliance failed to build${NC}"
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
