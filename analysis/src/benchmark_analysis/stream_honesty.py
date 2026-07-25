"""StreamMode honesty helpers (B-6).

Canonical CSV values on stream rows (lowercase):
  native | text_on_stream | adapted
"""

from __future__ import annotations

from collections import Counter
from typing import Any, Dict, Iterable, List, Optional, Sequence, Tuple

VALID_STREAM_MODES = frozenset({"native", "text_on_stream", "adapted"})


def normalize_stream_mode(value: Optional[str]) -> str:
    """Normalize a StreamMode cell; empty/unknown → \"\"."""
    if value is None:
        return ""
    s = str(value).strip().lower().replace("-", "_").replace(" ", "_")
    if s in ("text", "text_writer", "textonstream"):
        s = "text_on_stream"
    if s in VALID_STREAM_MODES:
        return s
    return s  # preserve unknown for diagnostics


def is_stream_io_mode(mode: Optional[str]) -> bool:
    m = (mode or "").strip().lower()
    return m in ("stream",)


def summarize_stream_modes(records: Sequence[Dict[str, Any]]) -> Dict[str, Any]:
    """Summarize StreamMode on stream I/O rows only."""
    counts: Counter = Counter()
    stream_rows = 0
    missing = 0
    for r in records:
        mode = r.get("StringOrStream") or r.get("mode")
        if not is_stream_io_mode(mode):
            continue
        stream_rows += 1
        sm = normalize_stream_mode(r.get("StreamMode"))
        if not sm:
            missing += 1
            counts[""] += 1
        else:
            counts[sm] += 1
    return {
        "stream_rows": stream_rows,
        "counts": dict(counts),
        "missing_labels": missing,
        "all_adapted": stream_rows > 0
        and missing == 0
        and set(counts.keys()) <= {"adapted"},
        "has_any_label": stream_rows > 0 and missing < stream_rows,
        "has_native": counts.get("native", 0) > 0,
        "has_text_on_stream": counts.get("text_on_stream", 0) > 0,
    }


def summarize_stream_modes_from_stats(stats: Dict[Any, Any]) -> Dict[str, Any]:
    """Summarize from analysis group stats (mode + optional StreamMode on entries)."""
    # Prefer raw StreamMode if attached; else only know I/O mode
    records: List[Dict[str, Any]] = []
    for e in stats.values():
        if not isinstance(e, dict):
            continue
        rec = {
            "mode": e.get("mode") or e.get("StringOrStream"),
            "StringOrStream": e.get("mode") or e.get("StringOrStream"),
            "StreamMode": e.get("StreamMode") or e.get("stream_mode"),
        }
        records.append(rec)
    return summarize_stream_modes(records)


def stream_honesty_banner_md(summary: Dict[str, Any]) -> str:
    """Markdown callout for language Results pages."""
    n = int(summary.get("stream_rows") or 0)
    if n <= 0:
        return (
            "> **Stream I/O:** not measured for this language snapshot "
            "(no stream-mode rows). See [Modes](../analysis/modes.md).\n"
        )
    counts = summary.get("counts") or {}
    missing = int(summary.get("missing_labels") or 0)
    parts = []
    for key in ("native", "text_on_stream", "adapted"):
        c = int(counts.get(key) or 0)
        if c:
            parts.append(f"**{key}** {c}")
    if missing:
        parts.append(f"unlabeled {missing}")
    legend = ", ".join(parts) if parts else "unlabeled"

    if summary.get("all_adapted"):
        return (
            "> **Stream honesty:** all stream rows are **`adapted`** "
            "(in-memory encode/decode then dump to a stream, or equivalent). "
            "Do **not** treat stream columns as proof of incremental I/O. "
            f"Labels: {legend}. "
            "See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).\n"
        )
    if missing == n:
        return (
            "> **Stream honesty:** stream rows are present but **lack `StreamMode` labels** "
            "(older CSV). Interpret stream columns with caution. "
            "See [Modes](../analysis/modes.md#three-levels-of-stream-honesty).\n"
        )
    return (
        f"> **Stream honesty:** stream rows labeled as {legend}. "
        "Only **`native`** (and carefully **`text_on_stream`**) support "
        "stream-API performance claims. "
        "See [Modes — stream honesty](../analysis/modes.md#three-levels-of-stream-honesty).\n"
    )
