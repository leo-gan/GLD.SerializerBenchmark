#!/usr/bin/env bash
# Link gld-arrow-fortran 0.2.0 and score the IPC stream catalog.
# The library has no IPC reader. Each buffer is rejected. The one accept
# case fails; the three reject cases pass.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARROW_REPO="${ARROW_REPO:-/home/leo/PycharmProjects/GLD/gld-arrow-fortran}"
OUT="${KILN_SCORE_DIR:-/tmp/kiln-scores}"
mkdir -p "$OUT"

if git -C "$ARROW_REPO" grep -n -i ipc 0.2.0 -- '*.f90' | grep -v -i 'no IPC' >/dev/null; then
  echo "gld-arrow-fortran 0.2.0 mentions IPC in Fortran sources; refusing a reject-all score" >&2
  git -C "$ARROW_REPO" grep -n -i ipc 0.2.0 -- '*.f90' >&2 || true
  exit 1
fi

work=/tmp/arrow-ipc-probe
rm -rf "$work"
mkdir -p "$work/app"
cp "$ROOT/compliance/arrow/fpm.toml" "$work/fpm.toml"
cp "$ROOT/compliance/arrow/app/arrow_ipc_probe.f90" "$work/app/arrow_ipc_probe.f90"
compiler="${FORTRAN_COMPILER:-gfortran-12}"
if ! command -v "$compiler" >/dev/null 2>&1; then
  compiler=gfortran
fi
(
  cd "$work"
  fpm run --compiler "$compiler" >"$OUT/fortran-probe.txt"
)

python3 - "$ROOT" "$OUT/fortran-probe.txt" "$OUT/fortran.json" <<'PY'
import json, sys
from pathlib import Path
root, probe_path, dest = sys.argv[1:]
text = Path(probe_path).read_text()
version = ""
endian = ""
for line in text.splitlines():
    if line.startswith("version="):
        version = line.split("=", 1)[1].strip()
    elif line.startswith("little_endian="):
        endian = line.split("=", 1)[1].strip()
if version != "0.2.0":
    raise SystemExit(f"linked ARROW_VERSION {version!r}, want 0.2.0\n{text}")
corpus = json.loads((Path(root) / "compliance/data/arrow/ipc-stream.json").read_text())
detail = (
    f"gld-arrow {version} exports Arrow C Data Interface arrays "
    f"(little_endian={endian}) and has no IPC stream reader. The buffer is rejected."
)
cases = []
for case in corpus["cases"]:
    outcome = "pass" if case["expect"] == "reject" else "fail"
    cases.append({
        "id": case["id"],
        "outcome": outcome,
        "observed": "reject",
        "detail": detail,
        "stricter": "",
    })
doc = {
    "language": "fortran",
    "serializer": "gld-arrow",
    "serializer_version": version,
    "format": "arrow",
    "pin": "gld-arrow-fortran tag 0.2.0",
    "passed": sum(1 for case in cases if case["outcome"] == "pass"),
    "failed": sum(1 for case in cases if case["outcome"] != "pass"),
    "stricter_failed": 0,
    "cases": cases,
}
Path(dest).write_text(json.dumps(doc))
print(f"version={version} little_endian={endian} pass={doc['passed']} fail={doc['failed']}")
PY
