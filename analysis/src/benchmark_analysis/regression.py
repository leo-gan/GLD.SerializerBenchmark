"""Regression detection and baseline management (A-4).

Default fail policy is AND: a noisy mean increase alone is not enough;
the bootstrap CI must also support a regression. See methodology docs.
"""

from __future__ import annotations

import json
import os
from datetime import datetime, timezone
from typing import Any, Dict, List, Optional, Sequence, Tuple

# Public API used by CLI / tests
__all__ = [
    "baseline_key",
    "check_regression",
    "load_baseline",
    "load_regression_config",
    "save_baseline",
]


def load_regression_config(config_path: Optional[str] = None) -> Dict[str, Any]:
    """Load ``regression:`` from master config with safe defaults."""
    cfg: Dict[str, Any] = {
        "enabled": True,
        "threshold_percent": 10.0,
        "metric": "total_median_ns",
        "combine": "and",  # and | or | practical_only | statistical_only
        "direction": "higher_is_worse",
        "cliffs_delta": {
            "enabled": True,
            "min_delta": 0.147,
            "require_for_fail": False,
        },
        "store_samples": True,
        "max_samples_stored": 500,
    }
    try:
        from .config_loader import dig, load_master_config

        data = load_master_config(config_path)
        block = data.get("regression") or {}
        for k, v in block.items():
            if isinstance(v, dict) and isinstance(cfg.get(k), dict):
                merged = dict(cfg[k])
                merged.update(v)
                cfg[k] = merged
            else:
                cfg[k] = v
        # Align cliffs min_delta with effect_sizes if present
        thr = dig(data, "statistics.effect_sizes.cliffs_delta_thresholds.negligible", None)
        if thr is not None and "min_delta" not in (block.get("cliffs_delta") or {}):
            cfg["cliffs_delta"]["min_delta"] = float(thr)
    except Exception as exc:
        print(f"Warning: could not load regression config: {exc}")
    return cfg


def baseline_key(
    language: str,
    serializer: str,
    test_data: str,
    mode: str,
    *,
    instance_count: Any = None,
    type_config_hash: Any = None,
) -> str:
    """Stable key for baseline entries (v2 includes batch axes)."""
    ic = instance_count if instance_count not in (None, "") else ""
    th = (type_config_hash or "") if type_config_hash not in (None,) else ""
    return f"{language}|{serializer}|{test_data}|{ic}|{th}|{mode}"


def baseline_key_from_stat(stat: Dict[str, Any]) -> str:
    return baseline_key(
        str(stat.get("language") or "unknown"),
        str(stat.get("serializer") or ""),
        str(stat.get("test_data") or ""),
        str(stat.get("mode") or ""),
        instance_count=stat.get("data_type_instance_count"),
        type_config_hash=stat.get("type_config_hash"),
    )


def legacy_baseline_key(stat: Dict[str, Any]) -> str:
    """v1 key without instance count / type hash."""
    return (
        f"{stat.get('language', 'unknown')}|{stat['serializer']}|"
        f"{stat['test_data']}|{stat['mode']}"
    )


def _normalize_baseline_payload(raw: Any) -> Dict[str, Dict[str, Any]]:
    """Return flat entry map from v1 flat dict or v2 wrapper."""
    if not isinstance(raw, dict):
        return {}
    if raw.get("schema_version") == 2 and isinstance(raw.get("entries"), dict):
        return {str(k): v for k, v in raw["entries"].items() if isinstance(v, dict)}
    # v1: top-level keys are entry keys
    out = {}
    for k, v in raw.items():
        if k in ("schema_version", "saved_at", "entries", "meta"):
            continue
        if isinstance(v, dict) and (
            "avg_time_total_ns" in v or "total_median_ns" in v
        ):
            out[str(k)] = v
    return out


def load_baseline(baseline_path: str) -> Dict[str, Dict[str, Any]]:
    if not os.path.exists(baseline_path):
        return {}
    with open(baseline_path, "r", encoding="utf-8") as f:
        raw = json.load(f)
    return _normalize_baseline_payload(raw)


def _lookup_baseline(
    baseline: Dict[str, Dict[str, Any]], stat: Dict[str, Any]
) -> Optional[Dict[str, Any]]:
    k2 = baseline_key_from_stat(stat)
    if k2 in baseline:
        return baseline[k2]
    k1 = legacy_baseline_key(stat)
    if k1 in baseline:
        return baseline[k1]
    return None


def _point(stat_or_base: Dict[str, Any], metric: str) -> float:
    if metric in stat_or_base and stat_or_base[metric] not in (None, ""):
        try:
            return float(stat_or_base[metric])
        except (TypeError, ValueError):
            pass
    for fallback in ("total_median_ns", "avg_time_total_ns"):
        if fallback in stat_or_base and stat_or_base[fallback] not in (None, ""):
            try:
                return float(stat_or_base[fallback])
            except (TypeError, ValueError):
                pass
    return 0.0


def _subsample(samples: Sequence[float], max_n: int) -> List[float]:
    arr = [float(x) for x in samples]
    if max_n <= 0 or len(arr) <= max_n:
        return arr
    # Evenly spaced subsample for stable-ish δ
    if max_n == 1:
        return [arr[len(arr) // 2]]
    idxs = [int(round(i * (len(arr) - 1) / (max_n - 1))) for i in range(max_n)]
    return [arr[i] for i in idxs]


def save_baseline(
    stats: Dict,
    output_path: str,
    config: Optional[Dict[str, Any]] = None,
) -> None:
    """Save current stats as baseline (schema v2)."""
    cfg = config or load_regression_config()
    store_samples = bool(cfg.get("store_samples", True))
    max_s = int(cfg.get("max_samples_stored", 500))

    entries: Dict[str, Dict[str, Any]] = {}
    for _key, stat in stats.items():
        if not isinstance(stat, dict):
            continue
        key_str = baseline_key_from_stat(stat)
        entry: Dict[str, Any] = {
            "avg_time_total_ns": float(stat.get("avg_time_total_ns") or 0.0),
            "total_median_ns": float(
                stat.get("total_median_ns") or stat.get("avg_time_total_ns") or 0.0
            ),
            "total_ci_low_ns": float(
                stat.get("total_ci_low_ns") or stat.get("avg_time_total_ns") or 0.0
            ),
            "total_ci_high_ns": float(
                stat.get("total_ci_high_ns") or stat.get("avg_time_total_ns") or 0.0
            ),
            "avg_ops_per_sec": float(stat.get("avg_ops_per_sec") or 0.0),
            "median_size_bytes": float(stat.get("median_size_bytes") or 0.0),
            "runs": int(stat.get("runs") or 0),
        }
        if store_samples:
            samples = stat.get("_times_total_filtered") or []
            if samples:
                entry["samples_total_ns"] = _subsample(samples, max_s)
        entries[key_str] = entry

    payload = {
        "schema_version": 2,
        "saved_at": datetime.now(timezone.utc).isoformat(),
        "regression_config": {
            "threshold_percent": cfg.get("threshold_percent"),
            "metric": cfg.get("metric"),
            "combine": cfg.get("combine"),
        },
        "entries": entries,
    }

    out_dir = os.path.dirname(output_path) or "."
    os.makedirs(out_dir, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2)

    print(f"Baseline saved to: {output_path} ({len(entries)} entries, schema v2)")


def _combine_fail(
    combine: str, practical: bool, statistical: bool, effect: Optional[bool]
) -> bool:
    c = (combine or "and").strip().lower()
    if c == "or":
        return practical or statistical
    if c == "practical_only":
        return practical
    if c == "statistical_only":
        return statistical
    # default and
    return practical and statistical


def check_regression(
    current_stats: Dict,
    baseline_path: str,
    threshold_percent: Optional[float] = None,
    *,
    config: Optional[Dict[str, Any]] = None,
) -> Tuple[bool, List[str]]:
    """Check for performance regressions against baseline.

    Default combine is **and**: require both a practical percent increase
    *and* CI support (lower CI still above the threshold band). Use
    ``combine: or`` for the legacy, noisier behavior.

    Returns (has_regression, human-readable messages).
    Details are also attached on the function as ``last_details`` for CLI JSON.
    """
    cfg = dict(config or load_regression_config())
    if threshold_percent is not None:
        cfg["threshold_percent"] = float(threshold_percent)

    if not os.path.exists(baseline_path):
        print(f"Warning: Baseline file not found: {baseline_path}")
        check_regression.last_details = []  # type: ignore[attr-defined]
        return False, []

    baseline = load_baseline(baseline_path)
    threshold = float(cfg.get("threshold_percent", 10.0))
    metric = str(cfg.get("metric") or "total_median_ns")
    combine = str(cfg.get("combine") or "and")
    factor = 1.0 + (threshold / 100.0)

    cliffs_cfg = cfg.get("cliffs_delta") or {}
    cliffs_enabled = bool(cliffs_cfg.get("enabled", True))
    min_delta = float(cliffs_cfg.get("min_delta", 0.147))
    require_effect = bool(cliffs_cfg.get("require_for_fail", False))

    messages: List[str] = []
    details: List[Dict[str, Any]] = []
    has_regression = False

    for _key, current in current_stats.items():
        if not isinstance(current, dict):
            continue
        base = _lookup_baseline(baseline, current)
        if not base:
            continue

        base_point = _point(base, metric)
        cur_point = _point(current, metric)
        ci_low = float(current.get("total_ci_low_ns") or cur_point)

        if base_point <= 0:
            continue

        increase_pct = ((cur_point - base_point) / base_point) * 100.0
        practical = increase_pct > threshold
        statistical = ci_low > (base_point * factor)

        delta: Optional[float] = None
        effect_slow = None
        if cliffs_enabled:
            cur_s = current.get("_times_total_filtered") or []
            base_s = base.get("samples_total_ns") or []
            if len(cur_s) >= 2 and len(base_s) >= 2:
                try:
                    from .stats import cliffs_delta, cliffs_delta_label

                    delta = float(cliffs_delta(cur_s, base_s))
                    effect_slow = delta >= min_delta
                except Exception:
                    delta = None
                    effect_slow = None

        fail = _combine_fail(combine, practical, statistical, effect_slow)
        if require_effect and effect_slow is not None:
            fail = fail and bool(effect_slow)

        # Classification
        if fail:
            classification = "regression"
        elif abs(increase_pct) <= threshold and (
            delta is None or abs(delta) < min_delta
        ):
            classification = "equivalent"
        elif practical and not statistical:
            classification = "unclear"
        elif increase_pct < -threshold:
            classification = "improvement"
        else:
            classification = "ok"

        detail = {
            "key": baseline_key_from_stat(current),
            "language": current.get("language"),
            "serializer": current.get("serializer"),
            "test_data": current.get("test_data"),
            "mode": current.get("mode"),
            "metric": metric,
            "baseline_ns": base_point,
            "current_ns": cur_point,
            "ci_low_ns": ci_low,
            "pct_change": increase_pct,
            "practical": practical,
            "statistical": statistical,
            "cliffs_delta": delta,
            "classification": classification,
            "combine": combine,
            "threshold_percent": threshold,
        }
        details.append(detail)

        if classification == "regression":
            has_regression = True
            how_parts = []
            if practical and statistical:
                how_parts.append("mean/median+CI")
            elif practical:
                how_parts.append("practical-only")
            elif statistical:
                how_parts.append("CI-only")
            if delta is not None:
                how_parts.append(f"δ={delta:.3f}")
            how = f" [{'+'.join(how_parts)}]" if how_parts else ""
            messages.append(
                f"REGRESSION: {current.get('serializer')} on {current.get('test_data')} "
                f"({current.get('mode')}) - {increase_pct:+.1f}% slower{how} "
                f"({base_point:,.0f}ns → {cur_point:,.0f}ns, CI low {ci_low:,.0f}ns)"
            )
        elif classification == "unclear":
            messages.append(
                f"UNCLEAR: {current.get('serializer')} on {current.get('test_data')} "
                f"({current.get('mode')}) - {increase_pct:+.1f}% vs baseline but CI still "
                f"overlaps the no-regression band (CI low {ci_low:,.0f}ns, "
                f"band starts {base_point * factor:,.0f}ns)"
            )

    check_regression.last_details = details  # type: ignore[attr-defined]
    return has_regression, messages


# mutable attribute for CLI JSON export
check_regression.last_details = []  # type: ignore[attr-defined]
