"""Load type catalog + run config, expand W×C cells, resolve type_config."""

from __future__ import annotations

import copy
import hashlib
import json
from pathlib import Path
from typing import Any

import yaml

def _find_repo_root() -> Path:
    """Walk parents for schemas/data_catalog_v2.yaml (works from any in-repo cwd)."""
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "schemas" / "data_catalog_v2.yaml").is_file():
            return p
    # Fallback: analysis/src/benchmark_analysis → repo root in standard layout
    return here.parents[3]


_REPO_ROOT = _find_repo_root()
DEFAULT_CATALOG = _REPO_ROOT / "schemas" / "data_catalog_v2.yaml"
DEFAULT_LIBRARY = _REPO_ROOT / "config" / "library"


class RunConfigError(ValueError):
    """Invalid catalog or run config."""


def _load_yaml(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise RunConfigError(f"file not found: {path}")
    with path.open(encoding="utf-8") as f:
        data = yaml.safe_load(f)
    if not isinstance(data, dict):
        raise RunConfigError(f"expected mapping at root: {path}")
    return data


def load_catalog(path: Path | None = None) -> dict[str, Any]:
    return _load_yaml(path or DEFAULT_CATALOG)


def canonical_json(obj: Any) -> str:
    """Stable JSON for hashing (sorted keys, compact separators)."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"), ensure_ascii=False)


def type_config_hash(resolved: dict[str, Any]) -> str:
    digest = hashlib.sha256(canonical_json(resolved).encode("utf-8")).hexdigest()
    return digest[:12]


def content_sha256(path: Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _resolve_primitive_types(raw: Any, catalog: dict[str, Any]) -> list[str]:
    if raw == "all_available" or raw is None:
        return list(catalog.get("primitives", {}).get("all_available", []))
    if not isinstance(raw, list):
        raise RunConfigError(f"primitive_types must be list or 'all_available', got {raw!r}")
    return list(raw)


def resolve_type_config(
    type_id: str,
    type_config: dict[str, Any] | None,
    catalog: dict[str, Any],
) -> dict[str, Any]:
    types = catalog.get("types") or {}
    if type_id not in types:
        raise RunConfigError(f"unknown type_id: {type_id!r}")
    forbidden = set(catalog.get("forbidden_type_config_keys") or [])
    user = dict(type_config or {})
    bad = forbidden.intersection(user.keys())
    if bad:
        raise RunConfigError(
            f"type_config for {type_id!r} must not contain {sorted(bad)} "
            "(owned by other config layers)"
        )
    defaults = copy.deepcopy(types[type_id].get("default_type_config") or {})
    # shallow merge then nested dict merge one level for known maps
    merged: dict[str, Any] = {**defaults, **user}
    for key in ("string_len", "int_range", "window"):
        if key in defaults and key in user and isinstance(defaults[key], dict) and isinstance(user[key], dict):
            merged[key] = {**defaults[key], **user[key]}
    if "primitive_types" in merged:
        merged["primitive_types"] = _resolve_primitive_types(merged["primitive_types"], catalog)
    _check_array_config(type_id, merged)
    return merged


def _require_int(merged: dict[str, Any], key: str, type_id: str, *, minimum: int) -> int:
    value = merged.get(key)
    if isinstance(value, bool) or not isinstance(value, int) or value < minimum:
        raise RunConfigError(
            f"{type_id} {key} must be an int >= {minimum}, got {value!r}"
        )
    return value


def _check_array_config(type_id: str, merged: dict[str, Any]) -> None:
    """grid and grid_window are one float64 array. The window must lie inside it."""
    if type_id not in ("grid", "grid_window"):
        return
    nx = _require_int(merged, "nx", type_id, minimum=1)
    ny = _require_int(merged, "ny", type_id, minimum=1)
    if type_id != "grid_window":
        return
    window = merged.get("window")
    if not isinstance(window, dict):
        raise RunConfigError(f"{type_id} window must be a mapping, got {window!r}")
    x0 = _require_int(window, "x0", type_id, minimum=0)
    y0 = _require_int(window, "y0", type_id, minimum=0)
    wx = _require_int(window, "wx", type_id, minimum=1)
    wy = _require_int(window, "wy", type_id, minimum=1)
    if x0 + wx > nx or y0 + wy > ny:
        raise RunConfigError(
            f"grid_window window ({x0},{y0}) {wx}x{wy} does not lie inside {nx}x{ny}"
        )


def _as_count_list(counts: Any, where: str) -> list[int]:
    if isinstance(counts, int):
        counts = [counts]
    if not isinstance(counts, list) or not counts:
        raise RunConfigError(f"{where} must be int or non-empty list[int]")
    for n in counts:
        if not isinstance(n, int) or n < 1:
            raise RunConfigError(f"{where} values must be int >= 1, got {n!r}")
    return list(counts)


def expand_cells(
    run_cfg: dict[str, Any],
    catalog: dict[str, Any],
) -> list[dict[str, Any]]:
    types = run_cfg.get("types")
    if not types:
        raise RunConfigError("run config missing non-empty 'types'")
    if run_cfg.get("data_type_instance_count") is None:
        raise RunConfigError("run config missing 'data_type_instance_count'")
    file_counts = _as_count_list(
        run_cfg.get("data_type_instance_count"),
        "data_type_instance_count",
    )

    cells: list[dict[str, Any]] = []
    for row in types:
        row_counts = file_counts
        if isinstance(row, str):
            type_id, tc = row, {}
        elif isinstance(row, dict):
            type_id = row.get("type_id")
            if not type_id:
                raise RunConfigError(f"type row missing type_id: {row!r}")
            tc = row.get("type_config") or {}
            if not isinstance(tc, dict):
                raise RunConfigError(f"type_config must be a mapping for {type_id}")
            if "data_type_instance_count" in row:
                row_counts = _as_count_list(
                    row["data_type_instance_count"],
                    f"{type_id} data_type_instance_count",
                )
        else:
            raise RunConfigError(f"invalid type row: {row!r}")
        resolved = resolve_type_config(type_id, tc, catalog)
        th = type_config_hash(resolved)
        for n in row_counts:
            cells.append(
                {
                    "type_id": type_id,
                    "type_config": resolved,
                    "type_config_hash": th,
                    "data_type_instance_count": n,
                }
            )
    return cells


def resolve_run_config(
    run_config_path: Path | str,
    *,
    catalog_path: Path | str | None = None,
    seed: int | None = None,
) -> dict[str, Any]:
    """Load run config + catalog, expand cells, return fully resolved document."""
    path = Path(run_config_path).resolve()
    catalog = load_catalog(Path(catalog_path) if catalog_path else None)
    run_cfg = _load_yaml(path)
    dm = run_cfg.get("data_model_version", catalog.get("data_model_version"))
    if dm != 2 and dm != "2":
        raise RunConfigError(f"expected data_model_version 2, got {dm!r}")

    cells = expand_cells(run_cfg, catalog)
    out: dict[str, Any] = {
        "data_model_version": 2,
        "run_config": {
            "id": run_cfg.get("id") or path.stem,
            "description": run_cfg.get("description"),
            "path": str(path),
            "content_sha256": content_sha256(path),
        },
        "seed": seed if seed is not None else run_cfg.get("seed"),
        "compression": run_cfg.get("compression") or {"mode": "none"},
        "execution": run_cfg.get("execution") or {},
        "budget": run_cfg.get("budget") or {},
        "cells": cells,
        "cell_count": len(cells),
        "catalog_path": str((Path(catalog_path) if catalog_path else DEFAULT_CATALOG).resolve()),
    }
    return out


def soft_budget_seconds(n_serializers: int, seconds_per_10: int = 60) -> int:
    if n_serializers < 1:
        n_serializers = 1
    return seconds_per_10 * ((n_serializers + 9) // 10)
