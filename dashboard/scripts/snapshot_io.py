"""Read and write the dashboard's gzip JSON snapshots.

One writer so a stats file is compact, replaced atomically, and reflected
in bench-versions.json. A language pack uses the same bytes and does not
touch the roster.
"""

from __future__ import annotations

import gzip
import json
from pathlib import Path


def load_json_gz(path) -> dict:
    """Load a gzip JSON object. A list or a scalar is a broken snapshot."""
    path = Path(path)
    with gzip.open(path, "rt", encoding="utf-8") as handle:
        data = json.load(handle)
    if not isinstance(data, dict):
        raise SystemExit(f"{path} is not a JSON object")
    return data


def write_json_gz(path, payload: dict) -> None:
    """Write compact gzip JSON. A stats_*_latest file also updates the roster."""
    path = Path(path)
    raw = json.dumps(payload, separators=(",", ":")).encode("utf-8")
    tmp = path.with_suffix(path.suffix + ".tmp")
    with gzip.open(tmp, "wb", compresslevel=9) as handle:
        handle.write(raw)
    tmp.replace(path)
    from bench_versions import note_stats_file

    note_stats_file(path, payload)
