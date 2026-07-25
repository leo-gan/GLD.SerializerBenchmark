"""Multi-session aggregation for claim levels L2/L3.

Given several analyzed run stats dicts (or raw CSVs turned into stats),
summarize rank stability and session-to-session spread **within one language**.
"""

from __future__ import annotations

from collections import Counter, defaultdict
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence, Tuple

import numpy as np


def _group_key(entry: Dict[str, Any]) -> Tuple:
    return (
        entry.get("language"),
        entry.get("serializer"),
        entry.get("test_data"),
        entry.get("type_config_hash"),
        entry.get("data_type_instance_count"),
        entry.get("mode"),
    )


def _rank_key(entry: Dict[str, Any]) -> Tuple:
    """Group for ranking (exclude serializer)."""
    return (
        entry.get("language"),
        entry.get("test_data"),
        entry.get("type_config_hash"),
        entry.get("data_type_instance_count"),
        entry.get("mode"),
    )


def _point(entry: Dict[str, Any]) -> float:
    v = entry.get("total_median_ns")
    if v is None or v != v:
        v = entry.get("avg_time_total_ns") or float("inf")
    return float(v)


def aggregate_multi_session(
    sessions: Sequence[Dict[str, Any]],
    *,
    language: Optional[str] = None,
) -> Dict[str, Any]:
    """Aggregate a list of session payloads.

    Each session is::
        {"run_id": str, "machine_id": optional str, "stats": {group_key: entry}}

    Returns JSON-serializable summary with per-serializer-across-sessions stats
    and rank-frequency tables.
    """
    # serializer key -> list of session medians
    by_ser: Dict[Tuple, List[float]] = defaultdict(list)
    # rank group -> Counter of fastest serializer per session
    rank_wins: Dict[Tuple, Counter] = defaultdict(Counter)
    machine_ids: List[str] = []
    run_ids: List[str] = []

    for sess in sessions:
        run_id = str(sess.get("run_id") or "unknown")
        run_ids.append(run_id)
        mid = sess.get("machine_id")
        if mid:
            machine_ids.append(str(mid))
        stats = sess.get("stats") or {}
        # Rank winners within this session
        by_rg: Dict[Tuple, List[Dict[str, Any]]] = defaultdict(list)
        for entry in stats.values():
            if not isinstance(entry, dict):
                continue
            if language and entry.get("language") != language:
                continue
            by_ser[_group_key(entry)].append(_point(entry))
            by_rg[_rank_key(entry)].append(entry)
        for rg, entries in by_rg.items():
            if not entries:
                continue
            best = min(entries, key=_point)
            rank_wins[rg][str(best.get("serializer"))] += 1

    n_sessions = len(sessions)
    unique_machines = sorted(set(machine_ids))
    # L2 requires ≥3 sessions and exactly one *known* machine_id (missing
    # sidecars must not silently invent "same host").
    claim_level = "L1_single_session"
    if len(unique_machines) >= 2:
        claim_level = "L3_multi_machine"
    elif n_sessions >= 3 and len(unique_machines) == 1:
        claim_level = "L2_multi_session_same_host"
    elif n_sessions >= 3 and len(unique_machines) == 0:
        claim_level = "L2_multi_session_host_unknown"

    groups_out: List[Dict[str, Any]] = []
    for gkey, vals in sorted(by_ser.items(), key=lambda t: str(t[0])):
        arr = np.asarray(vals, dtype=float)
        groups_out.append(
            {
                "language": gkey[0],
                "serializer": gkey[1],
                "test_data": gkey[2],
                "type_config_hash": gkey[3],
                "data_type_instance_count": gkey[4],
                "mode": gkey[5],
                "n_sessions": int(len(arr)),
                "median_of_session_medians_ns": float(np.median(arr)),
                "iqr_across_sessions_ns": float(
                    np.percentile(arr, 75) - np.percentile(arr, 25)
                )
                if len(arr) >= 2
                else 0.0,
                "min_session_ns": float(np.min(arr)),
                "max_session_ns": float(np.max(arr)),
            }
        )

    rank_table: List[Dict[str, Any]] = []
    for rg, counter in sorted(rank_wins.items(), key=lambda t: str(t[0])):
        total = sum(counter.values()) or 1
        top = counter.most_common(5)
        rank_table.append(
            {
                "language": rg[0],
                "test_data": rg[1],
                "type_config_hash": rg[2],
                "data_type_instance_count": rg[3],
                "mode": rg[4],
                "n_sessions_ranked": total,
                "fastest_frequency": [
                    {"serializer": s, "wins": w, "fraction": w / total} for s, w in top
                ],
            }
        )

    return {
        "schema_version": 1,
        "language": language,
        "n_sessions": n_sessions,
        "run_ids": run_ids,
        "machine_ids": unique_machines,
        "claim_level": claim_level,
        "groups": groups_out,
        "rank_stability": rank_table,
    }


def load_stats_for_csv(
    csv_path: str,
    *,
    language_hint: Optional[str] = None,
    stats_config: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Parse one CSV and return compute_statistics result."""
    from .parser import parse_csv_file
    from .stats import compute_statistics, load_stats_config

    recs, _skipped = parse_csv_file(csv_path, language_hint=language_hint)
    cfg = stats_config or load_stats_config()
    return compute_statistics(recs, config=cfg, language_hint=language_hint)


def machine_id_from_sidecar(csv_path: str) -> Optional[str]:
    try:
        from .environment import load_environment

        doc = load_environment(csv_path)
        if not doc:
            return None
        env = doc.get("environment") if isinstance(doc.get("environment"), dict) else doc
        mid = env.get("machine_id") if isinstance(env, dict) else None
        return str(mid) if mid else None
    except Exception:
        return None


def multi_session_from_paths(
    paths: Sequence[str],
    *,
    language: Optional[str] = None,
) -> Dict[str, Any]:
    """Build multi-session report from CSV paths."""
    sessions: List[Dict[str, Any]] = []
    for p in paths:
        path = Path(p)
        if not path.is_file():
            continue
        stem = path.stem
        stats = load_stats_for_csv(str(path), language_hint=language)
        sessions.append(
            {
                "run_id": stem,
                "machine_id": machine_id_from_sidecar(str(path)),
                "stats": stats,
            }
        )
    return aggregate_multi_session(sessions, language=language)


def multi_session_markdown(report: Dict[str, Any]) -> str:
    """Short markdown summary for humans."""
    lines = [
        f"# Multi-session report ({report.get('language') or 'all'})",
        "",
        f"- **Sessions:** {report.get('n_sessions')}",
        f"- **Run ids:** {', '.join(report.get('run_ids') or [])}",
        f"- **Machine ids:** {', '.join(report.get('machine_ids') or ['(unknown)'])}",
        f"- **Claim level (heuristic):** `{report.get('claim_level')}`",
        "",
        "See [Claims and replication](../docs/analysis/CLAIMS_AND_REPLICATION.md) "
        "for what L1/L2/L3 allow you to say.",
        "",
        "## Rank stability (how often each serializer is fastest)",
        "",
    ]
    for row in (report.get("rank_stability") or [])[:40]:
        td = row.get("test_data")
        n = row.get("data_type_instance_count")
        mode = row.get("mode")
        lines.append(f"### {td} · n={n} · {mode}")
        lines.append("")
        lines.append("| serializer | wins | fraction |")
        lines.append("|------------|-----:|---------:|")
        for f in row.get("fastest_frequency") or []:
            lines.append(
                f"| {f.get('serializer')} | {f.get('wins')} | {f.get('fraction', 0):.2f} |"
            )
        lines.append("")
    return "\n".join(lines)
