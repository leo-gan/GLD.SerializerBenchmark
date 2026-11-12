"""Shared statistical aggregation, markdown table builders, and CLI for experiment summarize.py scripts."""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

LIB = Path(__file__).resolve().parent
REPO = LIB.parents[1]
if str(LIB) not in sys.path:
    sys.path.insert(0, str(LIB))

from experiment_config import load_experiment, libraries_by_language
from language_results import load_language_blocks, saved_language

NS_PER_US = 1000.0
MEMORY_MODES = {"bytes", "string", "buffer"}
CONFIG_NAME = "experiment.yaml"
PACKET_MARKS_BYTES = (128, 512)
KIND_LABEL = {
    "document": "A (order)",
    "message": "B (flat)",
    "telemetry": "C (sensor)",
    "event": "D (event)",
    "strings": "E (words)",
}


def _prep() -> None:
    src = str(REPO / "analysis" / "src")
    if src not in sys.path:
        sys.path.insert(0, src)


def _lib_meta(catalog: dict, language: str) -> dict[str, dict]:
    return {row["name"]: row for row in catalog.get(language, [])}


def _io_label(mode: str) -> str:
    m = (mode or "").lower()
    if m in MEMORY_MODES:
        return "memory"
    if m == "stream":
        return "stream"
    return mode or "unknown"


def _stream_kind(raw: str | None) -> str | None:
    return {
        "native": "real",
        "adapted": "copied",
        "text_on_stream": "text_on_stream",
    }.get(raw or "")


def _ns(v: Any) -> int | None:
    if v is None:
        return None
    return int(round(float(v)))


def _median_extra(
    records: list[dict], name: str, mode: str, field: str, kind: str | None = None
) -> int | None:
    want = MEMORY_MODES if _io_label(mode) == "memory" else {mode.lower()}
    vals = [
        float(r[field])
        for r in records
        if r.get("SerializerName") == name
        and str(r.get("StringOrStream", "")).lower() in want
        and field in r
        and (kind is None or r.get("TestDataName") == kind)
    ]
    if not vals:
        return None
    return int(round(statistics.median(vals)))


def latest_csv(here: Path, language: str) -> Path | None:
    folder = here / language / "logs"
    found = sorted(folder.rglob("*.csv"), key=lambda p: p.stat().st_mtime, reverse=True)
    return found[0] if found else None


def _fmt_us(ns: float | None) -> str:
    if ns is None:
        return "—"
    us = ns / NS_PER_US
    if us < 10:
        return f"{us:.2f}"
    if us < 100:
        return f"{us:.1f}"
    return f"{us:.0f}"


def _in_main_set(row: dict, analysis: dict) -> bool:
    if row.get("io") != (analysis.get("main_io") or "memory"):
        return False
    if analysis.get("require_named_fields", True) and not row.get("writes_named_fields"):
        return False
    return True


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO))
    except ValueError:
        return str(path)


def points_by_hash(here: Path) -> dict[str, int]:
    """Map TypeConfigHash → telemetry points from the shared sample file."""
    sample_path = here / "sample.json"
    if not sample_path.is_file():
        return {}
    try:
        blob = json.loads(sample_path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return {}
    out: dict[str, int] = {}
    for cell in blob.get("cells") or []:
        h = cell.get("settings_hash")
        pts = (cell.get("settings") or {}).get("points")
        if h and pts is not None:
            try:
                out[str(h)] = int(pts)
            except (TypeError, ValueError):
                pass
    return out


def _score_group(
    main: list[dict],
    samples: dict,
    key_fn,
    similar_max: float,
    close_max: float,
    method: str,
    extra_meta: dict,
) -> dict:
    try:
        from benchmark_analysis.stats import cliffs_delta, cliffs_delta_label
    except ImportError:
        cliffs_delta = None  # type: ignore
        cliffs_delta_label = None  # type: ignore

    ref = min(main, key=lambda r: (r.get("total_median_ns") or 10**18, r["library"]))
    ref_times = samples.get(key_fn(ref)) or []
    for r in main:
        if r["library"] == ref["library"]:
            r["tier"] = "fastest"
            r["cliffs_delta_vs_fastest"] = 0.0
            r["cliffs_label"] = "reference"
            continue
        mine = samples.get(key_fn(r)) or []
        if cliffs_delta and mine and ref_times:
            delta = float(cliffs_delta(mine, ref_times))
            label = cliffs_delta_label(
                delta, {"negligible": similar_max, "small": close_max, "medium": 0.474}
            )
        else:
            delta = None
            label = None
        r["cliffs_delta_vs_fastest"] = None if delta is None else round(delta, 4)
        r["cliffs_label"] = label
        ad = abs(delta) if delta is not None else None
        if ad is not None and ad < similar_max:
            r["tier"] = "similar"
        elif ad is not None and ad < close_max:
            r["tier"] = "close"
        else:
            r["tier"] = "slower"

    for r in main:
        t, s = r.get("total_median_ns"), r.get("size_bytes")
        if t is None or s is None:
            continue
        dominated = any(
            o["library"] != r["library"]
            and o.get("total_median_ns") is not None
            and o.get("size_bytes") is not None
            and o["total_median_ns"] <= t
            and o["size_bytes"] <= s
            and (o["total_median_ns"] < t or o["size_bytes"] < s)
            for o in main
        )
        r["on_time_size_front"] = not dominated

    return {
        "method": method,
        **extra_meta,
        "similar_max": similar_max,
        "close_max": close_max,
        "reference": ref["library"],
        "similar": [r["library"] for r in main if r.get("tier") in {"fastest", "similar"}],
        "close": [r["library"] for r in main if r.get("tier") == "close"],
        "time_size_front": [r["library"] for r in main if r.get("on_time_size_front")],
    }


def _assign_top_group(rows: list[dict], samples: dict, analysis: dict) -> dict:
    """Single top_group for single-cell experiments (01, 14, 15)."""
    tg = analysis.get("top_group") or {}
    similar_max = float(tg.get("similar_max", 0.147))
    close_max = float(tg.get("close_max", 0.33))
    method = tg.get("method") or "cliffs_delta_vs_fastest"
    main = [r for r in rows if _in_main_set(r, analysis)]
    for r in rows:
        r["in_comparison"] = _in_main_set(r, analysis)
        r["tier"] = None
        r["cliffs_delta_vs_fastest"] = None
        r["cliffs_label"] = None
        r["on_time_size_front"] = False
    if not main:
        return {
            "method": method,
            "similar_max": similar_max,
            "close_max": close_max,
            "reference": None,
            "similar": [],
            "close": [],
            "time_size_front": [],
        }
    return _score_group(
        main,
        samples,
        lambda r: (r["library"], r["io"]),
        similar_max,
        close_max,
        method,
        {},
    )


def assign_top_groups_by(
    rows: list[dict], samples: dict, analysis: dict, mode: str = "n_io"
) -> list[dict]:
    """Grouped top_groups for multi-cell experiments: 'n_io', 'points_io', or 'kind_n_io'."""
    tg = analysis.get("top_group") or {}
    similar_max = float(tg.get("similar_max", 0.147))
    close_max = float(tg.get("close_max", 0.33))
    method = tg.get("method") or "cliffs_delta_vs_fastest"

    for r in rows:
        r["in_comparison"] = False
        r["tier"] = None
        r["cliffs_delta_vs_fastest"] = None
        r["cliffs_label"] = None
        r["on_time_size_front"] = False

    groups_out: list[dict] = []
    if mode == "points_io":
        keys = sorted({(r.get("points"), r.get("io")) for r in rows if _in_main_set(r, analysis)})
        for points, io in keys:
            main = [
                r
                for r in rows
                if _in_main_set(r, analysis) and r.get("points") == points and r.get("io") == io
            ]
            for r in main:
                r["in_comparison"] = True
            if not main:
                continue
            groups_out.append(
                _score_group(
                    main,
                    samples,
                    lambda r, io=io, points=points: (r["library"], io, points),
                    similar_max,
                    close_max,
                    method,
                    {"n": 1, "points": points, "io": io},
                )
            )
    elif mode == "kind_n_io":
        keys = sorted(
            {
                (r.get("kind") or "", r.get("n"), r.get("io"))
                for r in rows
                if _in_main_set(r, analysis)
            }
        )
        for kind, n, io in keys:
            main = [
                r
                for r in rows
                if _in_main_set(r, analysis)
                and r.get("kind") == kind
                and r.get("n") == n
                and r.get("io") == io
            ]
            for r in main:
                r["in_comparison"] = True
            if not main:
                continue
            groups_out.append(
                _score_group(
                    main,
                    samples,
                    lambda r, io=io, n=n, kind=kind: (r["library"], io, n, kind),
                    similar_max,
                    close_max,
                    method,
                    {"kind": kind, "n": n, "io": io},
                )
            )
    else:  # "n_io"
        keys = sorted({(r.get("n"), r.get("io")) for r in rows if _in_main_set(r, analysis)})
        for n, io in keys:
            main = [
                r
                for r in rows
                if _in_main_set(r, analysis) and r.get("n") == n and r.get("io") == io
            ]
            for r in main:
                r["in_comparison"] = True
            if not main:
                continue
            groups_out.append(
                _score_group(
                    main,
                    samples,
                    lambda r, io=io, n=n: (r["library"], io, n),
                    similar_max,
                    close_max,
                    method,
                    {"n": n, "io": io},
                )
            )
    return groups_out


def summarize_language_for(
    language: str,
    csv_path: Path,
    catalog: dict,
    analysis: dict,
    *,
    mode: str = "n_io",
    empty_noun: str = "JSON-library",
    include_zstd: bool = False,
    hash_to_points: dict[str, int] | None = None,
) -> dict:
    """Shared implementation of summarize_language across all 6 experiment variants."""
    _prep()
    from benchmark_analysis.parser import parse_csv_file
    from benchmark_analysis.stats import compute_statistics, load_stats_config

    meta = _lib_meta(catalog, language)
    names = set(meta)
    records, skipped = parse_csv_file(str(csv_path), language_hint=language)
    kept = [r for r in records if r.get("SerializerName") in names]
    if not kept:
        return {
            "status": "empty",
            "language": language,
            "csv": _rel(csv_path),
            "error": (
                f"No {empty_noun} rows in {csv_path.name} "
                f"(parsed {len(records)}, skipped {skipped})"
            ),
            "rows": [],
            "top_group": None,
        }

    stats = compute_statistics(kept, config=load_stats_config(), language_hint=language)
    rows = []
    samples: dict[Any, list] = {}
    for g in stats.values():
        name = g["serializer"]
        info = meta.get(name) or {}
        raw_mode = g.get("mode") or ""
        io = _io_label(raw_mode)
        n_raw = g.get("data_type_instance_count")
        try:
            n = int(n_raw) if n_raw not in (None, "") else 1
        except (TypeError, ValueError):
            n = 1
        kind = g.get("test_data") or "unknown"
        th = g.get("type_config_hash") or ""
        points = (hash_to_points or {}).get(str(th))

        times = list(g.get("_times_total_filtered") or [])
        if mode == "single":
            samples[(name, io)] = times
        elif mode == "points_io":
            samples[(name, io, points)] = times
        elif mode == "kind_n_io":
            samples[(name, io, n, kind)] = times
        else:
            samples[(name, io, n)] = times

        row: dict[str, Any] = {"library": name}
        if mode == "kind_n_io":
            row["kind"] = kind
        if mode != "single":
            row["n"] = n
        if mode == "points_io":
            row["points"] = points
            row["type_config_hash"] = th or None

        row.update(
            {
                "version": g.get("serializer_version") or None,
                "role": info.get("role"),
                "writes_named_fields": bool(info.get("writes_named_fields", True)),
                "io": io,
                "stream_kind": _stream_kind(g.get("StreamMode")),
                "write_median_ns": _ns(g.get("ser_median_ns")),
                "read_median_ns": _ns(g.get("deser_median_ns")),
                "total_median_ns": _ns(g.get("total_median_ns")),
                "total_mean_ns": _ns(g.get("total_mean_ns")),
                "total_p95_ns": _ns(g.get("total_p95_ns")),
                "total_p99_ns": _ns(g.get("total_p99_ns")),
                "total_ci_low_ns": _ns(g.get("total_ci_low_ns")),
                "total_ci_high_ns": _ns(g.get("total_ci_high_ns")),
                "write_std_ns": _ns(g.get("ser_std_ns")),
                "read_std_ns": _ns(g.get("deser_std_ns")),
                "size_bytes": _ns(g.get("median_size_bytes")),
                "size_gzip_bytes": _median_extra(
                    kept, name, raw_mode, "SizeGzip", kind if include_zstd else None
                ),
            }
        )
        if include_zstd:
            row["size_zstd_bytes"] = _median_extra(kept, name, raw_mode, "SizeZstd", kind)
        row.update(
            {
                "fidelity": g.get("mean_fidelity"),
                "runs": int(g.get("runs") or 0),
                "runs_raw": int(g.get("runs_raw") or 0),
                "outliers_removed": int(g.get("outliers_removed") or 0),
            }
        )
        rows.append(row)

    if mode == "single":
        rows.sort(key=lambda r: (r["io"] != "memory", r["total_median_ns"] or 10**18, r["library"]))
        top_group = _assign_top_group(rows, samples, analysis)
        return {
            "status": "ok",
            "language": language,
            "csv": _rel(csv_path),
            "error": None,
            "top_group": top_group,
            "rows": rows,
        }

    if mode == "points_io":
        rows.sort(
            key=lambda r: (
                r.get("points") if r.get("points") is not None else 10**9,
                r.get("n") or 0,
                r["io"] != "memory",
                r["total_median_ns"] or 10**18,
                r["library"],
            )
        )
        top_groups = assign_top_groups_by(rows, samples, analysis, mode="points_io")
        return {
            "status": "ok",
            "language": language,
            "csv": _rel(csv_path),
            "error": None,
            "top_groups": top_groups,
            "top_group": top_groups[0] if top_groups else None,
            "rows": rows,
        }

    if mode == "kind_n_io":
        rows.sort(
            key=lambda r: (
                r.get("kind") or "",
                r.get("n") or 0,
                r["io"] != "memory",
                r["total_median_ns"] or 10**18,
                r["library"],
            )
        )
        top_groups = assign_top_groups_by(rows, samples, analysis, mode="kind_n_io")
        return {
            "status": "ok",
            "language": language,
            "csv": _rel(csv_path),
            "error": None,
            "top_groups": top_groups,
            "top_group": next(
                (g for g in top_groups if g.get("kind") == "document" and g.get("n") == 1),
                top_groups[0] if top_groups else None,
            ),
            "rows": rows,
        }

    # mode == "n_io"
    rows.sort(
        key=lambda r: (
            r.get("n") or 0,
            r["io"] != "memory",
            r["total_median_ns"] or 10**18,
            r["library"],
        )
    )
    top_groups = assign_top_groups_by(rows, samples, analysis, mode="n_io")
    return {
        "status": "ok",
        "language": language,
        "csv": _rel(csv_path),
        "error": None,
        "top_groups": top_groups,
        "top_group": next((g for g in top_groups if g.get("n") == 1), top_groups[0] if top_groups else None),
        "rows": rows,
    }


def _emit_memory_table(lines: list[str], rows: list[dict]) -> None:
    lines.extend(
        [
            "| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Role | Group | Same information? | Trials kept |",
            "|---------|---------|------------|-----------|-------------------|--------------|-------------------------|------|-------|-------------------|-------------|",
        ]
    )
    for r in rows:
        fid = r.get("fidelity")
        ok = "yes" if fid is not None and fid >= 0.999 else ("—" if fid is None else f"{fid:.3f}")
        gz = r.get("size_gzip_bytes")
        lines.append(
            "| {lib} | {ver} | {w} | {rd} | {t} | {sz} | {gz} | {role} | {tier} | {ok} | {kept} |".format(
                lib=r["library"],
                ver=r.get("version") or "—",
                w=_fmt_us(r.get("write_median_ns")),
                rd=_fmt_us(r.get("read_median_ns")),
                t=_fmt_us(r.get("total_median_ns")),
                sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                gz=gz if gz is not None else "—",
                role=r.get("role") or "—",
                tier=r.get("tier") or "—",
                ok=ok,
                kept=r.get("runs") or 0,
            )
        )


def render_single_language_markdown(
    exp_num: int,
    language: str,
    pack: dict,
    *,
    sample_desc: str = "one nested document (`document`, one record)",
    conv_intro: str = (
        "We do not name a single winner. This sample is one small order. "
        "A different record can change who is first. Instead we ask: "
        "across the timed trials, how often is this library slower than "
        "the fastest named-JSON library?"
    ),
    front_label: str = "Not both slower and larger than another named-JSON library:",
) -> str:
    """Shared language markdown for single-group experiments (01, 14, 15)."""
    mem = [r for r in pack["rows"] if r["io"] == "memory"]
    stream = [r for r in pack["rows"] if r["io"] == "stream"]
    lines = [
        f"# Experiment {exp_num} results — {language}",
        "",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Raw file:** `{pack.get('csv') or '—'}`",
        f"**Language:** {language}",
        f"**Sample:** {sample_desc}",
        "**Cleaning:** first trial dropped; default stall filter (same as the project)",
        "",
        "## In-memory call (the main comparison)",
        "",
        "Times are middle values in microseconds (µs). Lower time is better.",
        "",
        "| Library | Version | Write (µs) | Read (µs) | Write + read (µs) | Size (bytes) | Size after gzip (bytes) | Named fields? | Group | Same information? | Trials kept |",
        "|---------|---------|------------|-----------|-------------------|--------------|-------------------------|---------------|-------|-------------------|-------------|",
    ]
    for r in mem:
        fid = r.get("fidelity")
        ok = "yes" if fid is not None and fid >= 0.999 else ("—" if fid is None else f"{fid:.3f}")
        named = "yes" if r.get("writes_named_fields") else "no (list)"
        gz = r.get("size_gzip_bytes")
        tier = r.get("tier") or "—"
        lines.append(
            "| {lib} | {ver} | {w} | {rd} | {t} | {sz} | {gz} | {named} | {tier} | {ok} | {n} |".format(
                lib=r["library"],
                ver=r.get("version") or "—",
                w=_fmt_us(r.get("write_median_ns")),
                rd=_fmt_us(r.get("read_median_ns")),
                t=_fmt_us(r.get("total_median_ns")),
                sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                gz=gz if gz is not None else "—",
                named=named,
                tier=tier,
                ok=ok,
                n=r.get("runs") or 0,
            )
        )

    if stream:
        lines.extend(
            [
                "",
                "## Stream call (side note)",
                "",
                "| Library | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |",
                "|---------|------------|-----------|-------------------|---------------------------|",
            ]
        )
        for r in stream:
            lines.append(
                "| {lib} | {w} | {rd} | {t} | {sk} |".format(
                    lib=r["library"],
                    w=_fmt_us(r.get("write_median_ns")),
                    rd=_fmt_us(r.get("read_median_ns")),
                    t=_fmt_us(r.get("total_median_ns")),
                    sk=r.get("stream_kind") or "—",
                )
            )

    tg = pack.get("top_group") or {}
    similar = tg.get("similar") or []
    close = tg.get("close") or []
    front = tg.get("time_size_front") or []
    if similar or close:
        lines.extend(["", "## Libraries that belong in the conversation", ""])
        lines.append(conv_intro)
        lines.append("")
        if similar:
            lines.append(
                "**Not clearly slower on this sample:** "
                + ", ".join(f"`{n}`" for n in similar)
                + "."
            )
        if close:
            lines.append(
                "**A small gap (a different record could change the order):** "
                + ", ".join(f"`{n}`" for n in close)
                + "."
            )
        if front:
            lines.append(
                f"**{front_label}** "
                + ", ".join(f"`{n}`" for n in front)
                + "."
            )
        lines.append("")
    if pack.get("status") != "ok":
        lines.extend(["", f"**This run did not produce a table:** {pack.get('error')}", ""])
    return "\n".join(lines) + "\n"


def render_grouped_language_markdown(
    exp_num: int,
    language: str,
    pack: dict,
    *,
    sample_desc: str,
    conv_intro: str,
    mode: str = "n_io",
) -> str:
    """Shared language markdown for multi-group experiments (02–13)."""
    lines = [
        f"# Experiment {exp_num} results — {language}",
        "",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Raw file:** `{pack.get('csv') or '—'}`",
        f"**Language:** {language}",
        f"**Sample:** {sample_desc}",
        "**Cleaning:** first trial dropped; default stall filter (same as the project)",
        "",
    ]
    if mode == "points_io":
        pts = sorted(
            {
                r.get("points")
                for r in pack.get("rows") or []
                if r.get("io") == "memory" and r.get("points") is not None
            }
        )
        for p in pts:
            mem = [r for r in pack["rows"] if r["io"] == "memory" and r.get("points") == p]
            lines.extend(
                [
                    f"## In memory — {p} numbers in the list",
                    "",
                    "Times are middle values in microseconds (µs). Lower time is better **inside this language**. "
                    "Size is the first number we care about on this curve.",
                    "",
                ]
            )
            _emit_memory_table(lines, mem)
            lines.append("")
    elif mode == "kind_n_io":
        kinds = sorted({r.get("kind") for r in pack.get("rows") or [] if r.get("io") == "memory"})
        ns = sorted({r.get("n") for r in pack.get("rows") or [] if r.get("io") == "memory"})
        for kind in kinds:
            for n in ns:
                mem = [
                    r
                    for r in pack["rows"]
                    if r["io"] == "memory" and r.get("kind") == kind and r.get("n") == n
                ]
                if not mem:
                    continue
                label = KIND_LABEL.get(kind or "", kind)
                lines.extend(
                    [
                        f"## In memory — sample {label}, {n} record(s) per write",
                        "",
                        "Times are middle values in microseconds (µs). Lower time is better **inside this language**.",
                        "",
                    ]
                )
                _emit_memory_table(lines, mem)
                lines.append("")
    else:  # "n_io"
        ns = sorted({r.get("n") for r in pack.get("rows") or [] if r.get("io") == "memory"})
        for n in ns:
            mem = [r for r in pack["rows"] if r["io"] == "memory" and r.get("n") == n]
            lines.extend(
                [
                    f"## In memory — {n} record(s) per write",
                    "",
                    "Times are middle values in microseconds (µs). Lower time is better **inside this language**.",
                    "",
                ]
            )
            _emit_memory_table(lines, mem)
            lines.append("")

    stream = [r for r in pack.get("rows") or [] if r["io"] == "stream"]
    if stream:
        if mode == "points_io":
            lines.extend(
                [
                    "## Stream call (side note)",
                    "",
                    "| Library | Points | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |",
                    "|---------|--------|------------|-----------|-------------------|---------------------------|",
                ]
            )
            for r in stream:
                lines.append(
                    "| {lib} | {p} | {w} | {rd} | {t} | {sk} |".format(
                        lib=r["library"],
                        p=r.get("points") if r.get("points") is not None else "—",
                        w=_fmt_us(r.get("write_median_ns")),
                        rd=_fmt_us(r.get("read_median_ns")),
                        t=_fmt_us(r.get("total_median_ns")),
                        sk=r.get("stream_kind") or "—",
                    )
                )
        else:
            lines.extend(
                [
                    "## Stream call (side note)",
                    "",
                    "| Library | N | Write (µs) | Read (µs) | Write + read (µs) | How the stream path works |",
                    "|---------|---|------------|-----------|-------------------|---------------------------|",
                ]
            )
            for r in stream:
                lines.append(
                    "| {lib} | {n} | {w} | {rd} | {t} | {sk} |".format(
                        lib=r["library"],
                        n=r.get("n") or "—",
                        w=_fmt_us(r.get("write_median_ns")),
                        rd=_fmt_us(r.get("read_median_ns")),
                        t=_fmt_us(r.get("total_median_ns")),
                        sk=r.get("stream_kind") or "—",
                    )
                )
        lines.append("")

    groups = pack.get("top_groups") or ([pack["top_group"]] if pack.get("top_group") else [])
    if groups:
        lines.extend(
            [
                "## Libraries that belong in the conversation",
                "",
                conv_intro,
                "",
            ]
        )
        for tg in groups:
            if not tg:
                continue
            if mode == "points_io":
                label = f"{tg.get('points')} numbers, {tg.get('io')}"
            elif mode == "kind_n_io":
                klabel = KIND_LABEL.get(tg.get("kind") or "", tg.get("kind") or "?")
                label = f"sample {klabel}, N = {tg.get('n')}, {tg.get('io')}"
            else:
                label = f"N = {tg.get('n')}, {tg.get('io')}"
            similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
            close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
            front = ", ".join(f"`{x}`" for x in (tg.get("time_size_front") or [])) or "—"
            lines.append(
                f"**{label}** — not clearly slower: {similar}. Small gap: {close}. Time/size front: {front}."
            )
            lines.append("")
    if pack.get("status") != "ok":
        lines.extend([f"**This run did not produce a table:** {pack.get('error')}", ""])
    return "\n".join(lines) + "\n"


def _ref_for(pack: dict, kind: str, n: int) -> str:
    groups = pack.get("top_groups") or []
    tg = next((g for g in groups if g.get("kind") == kind and g.get("n") == n), None)
    if not tg:
        return "—"
    return tg.get("reference") or "—"


def _size_over_marks(size: int | None) -> str:
    if size is None:
        return "—"
    parts = []
    for mark in PACKET_MARKS_BYTES:
        parts.append(f">{mark}" if size > mark else f"≤{mark}")
    return ", ".join(parts)


def render_single_combined_markdown(
    cfg: dict,
    languages: dict,
    *,
    intro_paragraphs: list[str],
    section_heading: str,
    section_intro: str,
    empty_msg: str,
    include_role: bool = False,
    footer_lines: list[str],
) -> str:
    """Combined markdown for single-group experiments (01, 14, 15)."""
    title = cfg.get("title") or cfg["question"]
    sample = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    kind = sample.get("kind") or "document"
    n = sample.get("records_per_write", 1)
    lines = [
        f"# {title}",
        "",
        f"**Question:** {cfg['question']}",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Sample:** `{kind}`, {n} record(s) per write · [`sample.json`](sample.json)",
        f"**Settings:** [`experiment.yaml`](experiment.yaml)",
        f"**Machine-readable file:** [`results.json`](results.json)",
        "",
    ]
    for p in intro_paragraphs:
        lines.extend([p, ""])
    lines.extend(
        [
            "## At a glance",
            "",
            "| Language | Status | Not clearly slower | Small gap | Not both slower and larger | Full table |",
            "|----------|--------|--------------------|-----------|----------------------------|------------|",
        ]
    )
    for lang, pack in languages.items():
        status = pack.get("status") or "—"
        tg = pack.get("top_group") or {}
        similar = ", ".join(f"`{n}`" for n in (tg.get("similar") or [])) or "—"
        close = ", ".join(f"`{n}`" for n in (tg.get("close") or [])) or "—"
        front = ", ".join(f"`{n}`" for n in (tg.get("time_size_front") or [])) or "—"
        if status != "ok":
            similar = close = front = pack.get("error") or status
        lines.append(
            f"| {lang} | {status} | {similar} | {close} | {front} | [{lang}/results.md]({lang}/results.md) |"
        )

    lines.extend(["", f"## {section_heading}", "", section_intro, ""])
    main_io = analysis.get("main_io") or "memory"
    named_only = bool(analysis.get("require_named_fields", True))
    for lang, pack in languages.items():
        lines.extend([f"### {lang}", ""])
        if pack.get("status") != "ok":
            lines.extend([f"{pack.get('error') or pack.get('status')}", ""])
            continue
        rows = [
            r
            for r in pack.get("rows") or []
            if r.get("io") == main_io and (not named_only or r.get("writes_named_fields"))
        ]
        if not rows:
            lines.extend([empty_msg, ""])
            continue
        if include_role:
            lines.extend(
                [
                    "| Library | Write + read (µs) | Size (bytes) | Role | Group |",
                    "|---------|-------------------|--------------|------|-------|",
                ]
            )
            for r in rows:
                lines.append(
                    "| {lib} | {t} | {sz} | {role} | {tier} |".format(
                        lib=r["library"],
                        t=_fmt_us(r.get("total_median_ns")),
                        sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                        role=r.get("role") or "—",
                        tier=r.get("tier") or "—",
                    )
                )
        else:
            lines.extend(
                [
                    "| Library | Write + read (µs) | Size (bytes) | Group |",
                    "|---------|-------------------|--------------|-------|",
                ]
            )
            for r in rows:
                lines.append(
                    "| {lib} | {t} | {sz} | {tier} |".format(
                        lib=r["library"],
                        t=_fmt_us(r.get("total_median_ns")),
                        sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                        tier=r.get("tier") or "—",
                    )
                )
        lines.append("")

    lines.extend(footer_lines)
    return "\n".join(lines) + "\n"


def render_points_io_combined_markdown(cfg: dict, languages: dict) -> str:
    """Combined markdown for telemetry list-length experiment (04)."""
    title = cfg.get("title") or cfg["question"]
    sample = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    kind = sample.get("kind") or "telemetry"
    pts_setting = (sample.get("settings") or {}).get("points") or [8, 32, 128, 512]
    lines = [
        f"# {title}",
        "",
        f"**Question:** {cfg['question']}",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Sample:** `{kind}`, one record, list lengths {pts_setting} · [`sample.json`](sample.json)",
        f"**Settings:** [`experiment.yaml`](experiment.yaml)",
        f"**Machine-readable file:** [`results.json`](results.json)",
        "",
        "Times in two languages are **not** one contest. **Size** is the first "
        "number on this curve. We mark two example packet sizes: "
        f"**{PACKET_MARKS_BYTES[0]} bytes** and **{PACKET_MARKS_BYTES[1]} bytes**. "
        "Your radio may differ.",
        "",
        "We do not name a single winner. Groups are separate for each list length.",
        "",
        "## Size curve (in memory)",
        "",
        "Bytes written. Lower is smaller. Marks: "
        + ", ".join(f"{m} B" for m in PACKET_MARKS_BYTES)
        + ".",
        "",
    ]
    main_io = analysis.get("main_io") or "memory"
    for lang, pack in languages.items():
        lines.extend([f"### {lang}", ""])
        if pack.get("status") != "ok":
            lines.extend([f"{pack.get('error') or pack.get('status')}", ""])
            continue
        libs = []
        seen = set()
        for r in pack.get("rows") or []:
            if r.get("io") == main_io and r["library"] not in seen:
                libs.append(r["library"])
                seen.add(r["library"])
        point_vals = sorted(
            {
                r.get("points")
                for r in pack.get("rows") or []
                if r.get("io") == main_io and r.get("points") is not None
            }
        )
        header = (
            "| Library | "
            + " | ".join(f"{p} nums" for p in point_vals)
            + " | vs 128 / 512 at 512 nums | Role |"
        )
        sep = (
            "|---------|"
            + "|".join(["--------"] * len(point_vals))
            + "|--------------------------|------|"
        )
        lines.extend([header, sep])
        for lib in libs:
            sizes = []
            at_512 = None
            role = "—"
            for p in point_vals:
                row = next(
                    (
                        r
                        for r in pack.get("rows") or []
                        if r.get("io") == main_io and r["library"] == lib and r.get("points") == p
                    ),
                    None,
                )
                if row:
                    role = row.get("role") or role
                    sz = row.get("size_bytes")
                    sizes.append(str(sz) if sz is not None else "—")
                    if p == 512:
                        at_512 = sz
                else:
                    sizes.append("—")
            lines.append(
                "| {lib} | {sz} | {marks} | {role} |".format(
                    lib=lib,
                    sz=" | ".join(sizes),
                    marks=_size_over_marks(at_512),
                    role=role,
                )
            )
        lines.append("")

    lines.extend(
        [
            "## Time and groups, by list length",
            "",
            "Write + read middle values in microseconds. Lower is better **inside that language**.",
            "",
        ]
    )
    for lang, pack in languages.items():
        lines.extend([f"### {lang}", ""])
        if pack.get("status") != "ok":
            lines.extend([f"{pack.get('error') or pack.get('status')}", ""])
            continue
        point_vals = sorted(
            {
                r.get("points")
                for r in pack.get("rows") or []
                if r.get("io") == main_io and r.get("points") is not None
            }
        )
        groups = pack.get("top_groups") or []
        for p in point_vals:
            rows = [
                r
                for r in pack.get("rows") or []
                if r.get("io") == main_io and r.get("points") == p
            ]
            if not rows:
                continue
            tg = next((g for g in groups if g.get("points") == p and g.get("io") == main_io), {})
            similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
            close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
            lines.extend(
                [
                    f"**{p} numbers** — not clearly slower: {similar}. Small gap: {close}.",
                    "",
                    "| Library | Write + read (µs) | Size (bytes) | Group |",
                    "|---------|-------------------|--------------|-------|",
                ]
            )
            for r in rows:
                lines.append(
                    "| {lib} | {t} | {sz} | {tier} |".format(
                        lib=r["library"],
                        t=_fmt_us(r.get("total_median_ns")),
                        sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                        tier=r.get("tier") or "—",
                    )
                )
            lines.append("")

    lines.extend(
        [
            "## What we saw",
            "",
            "Read the **Rust** size curve. C sizes do **not** grow with the list, "
            "so C cannot answer this question on this machine.",
            "",
            "In Rust, JSON is 234 bytes at 8 numbers (already over a 128-byte "
            "packet) and 672 bytes at 32 numbers (over a 512-byte packet). "
            "`postcard` and `prost` stay about half that size. They still fit "
            "a 512-byte packet at 32 numbers (about 286–290 bytes) and overflow "
            "it at 128 numbers (about 1051 bytes). MessagePack and CBOR sit "
            "between JSON and postcard.",
            "",
            "C rows stay near 320–670 bytes at every list length. That is not "
            "a growing list of numbers on the wire. Do not quote those C sizes "
            "as a device answer.",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not the size of the library in flash memory.",
            "- It is not battery use, and it is not a promise that your radio uses 128 or 512 bytes.",
            "- C `nanopb` and `protobuf-wire` are not a full generated Google pack.",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def render_n_io_combined_markdown(
    cfg: dict,
    languages: dict,
    *,
    intro_paragraphs: list[str],
    include_100_table: bool,
    in_memory_intro: str,
    footer_lines: list[str],
) -> str:
    """Combined markdown for n_io grouped experiments (02, 03, 05, 06, 11, 12)."""
    title = cfg.get("title") or cfg["question"]
    sample = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    kind = sample.get("kind") or "document"
    n = sample.get("records_per_write", 1)
    lines = [
        f"# {title}",
        "",
        f"**Question:** {cfg['question']}",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Sample:** `{kind}`, {n} record(s) per write · [`sample.json`](sample.json)",
        f"**Settings:** [`experiment.yaml`](experiment.yaml)",
        f"**Machine-readable file:** [`results.json`](results.json)",
        "",
    ]
    for p in intro_paragraphs:
        lines.extend([p, ""])

    glance_heading = (
        "## At a glance (1 record per write)" if include_100_table else "## At a glance"
    )
    lines.extend(
        [
            glance_heading,
            "",
            "| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |",
            "|----------|--------|--------------------|-----------|-----------------|------------|",
        ]
    )
    for lang, pack in languages.items():
        status = pack.get("status") or "—"
        groups = pack.get("top_groups") or []
        tg = next((g for g in groups if g.get("n") == 1), pack.get("top_group") or {})
        similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
        close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
        front = ", ".join(f"`{x}`" for x in (tg.get("time_size_front") or [])) or "—"
        if status != "ok":
            similar = close = front = pack.get("error") or status
        lines.append(
            f"| {lang} | {status} | {similar} | {close} | {front} | [{lang}/results.md]({lang}/results.md) |"
        )

    if include_100_table:
        lines.extend(
            [
                "",
                "## At a glance (100 records per write)",
                "",
                "| Language | Status | Not clearly slower | Small gap | Time/size front |",
                "|----------|--------|--------------------|-----------|-----------------|",
            ]
        )
        for lang, pack in languages.items():
            status = pack.get("status") or "—"
            groups = pack.get("top_groups") or []
            tg = next((g for g in groups if g.get("n") == 100), {})
            if status != "ok" or not tg:
                lines.append(f"| {lang} | {status} | — | — | — |")
                continue
            similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
            close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
            front = ", ".join(f"`{x}`" for x in (tg.get("time_size_front") or [])) or "—"
            lines.append(f"| {lang} | {status} | {similar} | {close} | {front} |")

    lines.extend(["", "## In memory, by language", "", in_memory_intro, ""])
    main_io = analysis.get("main_io") or "memory"
    for lang, pack in languages.items():
        lines.extend([f"### {lang}", ""])
        if pack.get("status") != "ok":
            lines.extend([f"{pack.get('error') or pack.get('status')}", ""])
            continue
        ns = sorted({r.get("n") for r in pack.get("rows") or [] if r.get("io") == main_io})
        for rec_n in ns:
            rows = [
                r
                for r in pack.get("rows") or []
                if r.get("io") == main_io and r.get("n") == rec_n
            ]
            if not rows:
                continue
            lines.extend(
                [
                    f"**{rec_n} record(s) per write**",
                    "",
                    "| Library | Write + read (µs) | Size (bytes) | Role | Group |",
                    "|---------|-------------------|--------------|------|-------|",
                ]
            )
            for r in rows:
                lines.append(
                    "| {lib} | {t} | {sz} | {role} | {tier} |".format(
                        lib=r["library"],
                        t=_fmt_us(r.get("total_median_ns")),
                        sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                        role=r.get("role") or "—",
                        tier=r.get("tier") or "—",
                    )
                )
            lines.append("")

    lines.extend(footer_lines)
    return "\n".join(lines) + "\n"


def render_multi_sample_combined_markdown(
    cfg: dict,
    languages: dict,
    *,
    split_write_read: bool = False,
    what_we_saw_intro: str = "On named JSON, some languages keep one first place; others flip.",
) -> str:
    """Combined markdown for A–E multi-sample experiments (07, 08, 09, 10, 13)."""
    title = cfg.get("title") or cfg["question"]
    sample = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    kind = sample.get("kind") or "document"
    n = sample.get("records_per_write", 1)
    lines = [
        f"# {title}",
        "",
        f"**Question:** {cfg['question']}",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Sample:** `{kind}`, {n} record(s) per write · [`sample.json`](sample.json)",
        f"**Settings:** [`experiment.yaml`](experiment.yaml)",
        f"**Machine-readable file:** [`results.json`](results.json)",
        "",
        "Times in two languages are **not** one contest. Named JSON only. "
        "A rank that flips when the sample or the stall rule changes was never "
        "a fact about the libraries.",
        "",
        "## Does the fastest named-JSON library stay the same? (N = 1)",
        "",
        "| Language | A order | B flat | C sensor | D event | E words | Same as A? | Full table |",
        "|----------|---------|--------|----------|---------|---------|------------|------------|",
    ]
    kind_order = ["document", "message", "telemetry", "event", "strings"]
    for lang, pack in languages.items():
        status = pack.get("status") or "—"
        if status != "ok":
            lines.append(
                f"| {lang} | {pack.get('error') or status} | — | — | — | — | — | "
                f"[{lang}/results.md]({lang}/results.md) |"
            )
            continue
        refs = [_ref_for(pack, k, 1) for k in kind_order]
        a = refs[0]
        same = "yes" if all(r == a and r != "—" for r in refs) else "no"
        lines.append(
            "| {lang} | {a} | {b} | {c} | {d} | {e} | {same} | [{lang}/results.md]({lang}/results.md) |".format(
                lang=lang, a=refs[0], b=refs[1], c=refs[2], d=refs[3], e=refs[4], same=same
            )
        )

    lines.extend(
        [
            "",
            "## Does the fastest stay the same at 100 records?",
            "",
            "| Language | Sample | Fastest at 1 | Fastest at 100 | Same? |",
            "|----------|--------|--------------|----------------|-------|",
        ]
    )
    for lang, pack in languages.items():
        if pack.get("status") != "ok":
            lines.append(f"| {lang} | — | {pack.get('error') or pack.get('status')} | — | — |")
            continue
        for k in kind_order:
            one = _ref_for(pack, k, 1)
            hun = _ref_for(pack, k, 100)
            if one == "—" and hun == "—":
                continue
            same = "yes" if one == hun and one != "—" else "no"
            lines.append(
                f"| {lang} | {KIND_LABEL.get(k, k)} | {one} | {hun} | {same} |"
            )

    lines.extend(
        [
            "",
            "## One order (n=1) — not clearly slower",
            "",
            "| Language | Status | Not clearly slower | Small gap |",
            "|----------|--------|--------------------|-----------|",
        ]
    )
    for lang, pack in languages.items():
        status = pack.get("status") or "—"
        groups = pack.get("top_groups") or []
        tg = next((g for g in groups if g.get("kind") == "document" and g.get("n") == 1), {})
        similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
        close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
        if status != "ok":
            similar = close = pack.get("error") or status
        lines.append(f"| {lang} | {status} | {similar} | {close} |")

    main_io = analysis.get("main_io") or "memory"
    lines.extend(["", "## In memory, by language and sample", ""])
    for lang, pack in languages.items():
        lines.extend([f"### {lang}", ""])
        if pack.get("status") != "ok":
            lines.extend([f"{pack.get('error') or pack.get('status')}", ""])
            continue
        kinds = sorted({r.get("kind") for r in pack.get("rows") or [] if r.get("io") == main_io})
        ns = sorted({r.get("n") for r in pack.get("rows") or [] if r.get("io") == main_io})
        for k in kinds:
            for rec_n in ns:
                rows = [
                    r
                    for r in pack.get("rows") or []
                    if r.get("io") == main_io
                    and r.get("kind") == k
                    and r.get("n") == rec_n
                    and (not analysis.get("require_named_fields", True) or r.get("writes_named_fields"))
                ]
                if not rows:
                    continue
                if split_write_read:
                    lines.extend(
                        [
                            f"**{KIND_LABEL.get(k or '', k)}, {rec_n} record(s)**",
                            "",
                            "| Library | Write (µs) | Read (µs) | Size (bytes) | Group |",
                            "|---------|------------|-----------|--------------|-------|",
                        ]
                    )
                    for r in rows:
                        lines.append(
                            "| {lib} | {w} | {rd} | {sz} | {tier} |".format(
                                lib=r["library"],
                                w=_fmt_us(r.get("write_median_ns")),
                                rd=_fmt_us(r.get("read_median_ns")),
                                sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                                tier=r.get("tier") or "—",
                            )
                        )
                else:
                    lines.extend(
                        [
                            f"**{KIND_LABEL.get(k or '', k)}, {rec_n} record(s)**",
                            "",
                            "| Library | Write + read (µs) | Size (bytes) | Group |",
                            "|---------|-------------------|--------------|-------|",
                        ]
                    )
                    for r in rows:
                        lines.append(
                            "| {lib} | {t} | {sz} | {tier} |".format(
                                lib=r["library"],
                                t=_fmt_us(r.get("total_median_ns")),
                                sz=r.get("size_bytes") if r.get("size_bytes") is not None else "—",
                                tier=r.get("tier") or "—",
                            )
                        )
                lines.append("")

    lines.extend(
        [
            "## What we saw",
            "",
            what_we_saw_intro,
            "",
            "- **Python:** `orjson` is first on every sample and at both 1 and 100 records. "
            "On Sample A it is about **5.3 times** faster than `json`. That ratio stays "
            "put if we keep every trial after warm-up, drop more stalls (IQR 3.0), or "
            "keep the first trial. That gap is a stable fact for named JSON in Python.",
            "- **JavaScript, C, Rust, Swift (N = 1):** the fast named-JSON library stays first "
            "on every sample (`JSON.stringify`, `yyjson`, `sonic-rs`, `IkigaJSON`).",
            "- **Go, Java, C++, C#:** the first place **depends on the sample**. "
            "Go moves among `goccy/go-json`, `segmentio/encoding/json`, and `sonic`. "
            "Java is `jsoniter` on A–C and `dsl-json` on D–E. C++ moves among "
            "`simdjson`, `yyjson`, and `nlohmann_json`. C# is `SpanJson` except "
            "`NetJSON` on the sensor list.",
            "- **1 vs 100:** Python, JavaScript, and C keep the same name. Go, Swift, "
            "and some Java / Rust / C++ / C# cells flip. Quote the number of records "
            "that matches the product.",
            "",
            "Never quote a rank without naming the sample and N. A close contest "
            "(Go on Sample A) is not the same kind of fact as `orjson` versus `json`.",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not three separate evenings on this machine.",
            "- It is not shuffled-order vs fixed-order (the runner always shuffles blocks).",
            "- It is not two versions of the same library.",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def experiment_payload_for(here: Path, cfg: dict, languages: dict) -> dict:
    sample_cfg = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    saved = sample_cfg.get("saved_as") or "sample.json"
    sample_path = here / saved
    settings_hash = None
    if sample_path.is_file():
        try:
            blob = json.loads(sample_path.read_text(encoding="utf-8"))
            cells = blob.get("cells") or []
            if cells:
                settings_hash = cells[0].get("settings_hash")
        except (OSError, json.JSONDecodeError):
            pass
    n = sample_cfg.get("records_per_write", 1)
    return {
        "schema": "gld.experiment.results/1",
        "experiment_id": cfg["id"],
        "question": cfg["question"],
        "config": "experiment.yaml",
        "sample": {
            "kind": sample_cfg.get("kind"),
            "n": n if isinstance(n, int) else list(n),
            "file": saved if sample_path.is_file() else None,
            "settings_hash": settings_hash,
        },
        "cleaning": {
            "drop_first_trial": bool(analysis.get("drop_first_trial", True)),
            "filter_id": analysis.get("filter_id") or "iqr_1.5",
            "main_io": analysis.get("main_io") or "memory",
            "require_named_fields": bool(analysis.get("require_named_fields", True)),
        },
        "generated_at": datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "languages": languages,
    }


def write_outputs_for(here: Path, language: str, pack: dict, write_language_markdown_fn) -> None:
    """Write the language page. The numbers live in the combined results.json."""
    dest = here / language
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "results.md").write_text(write_language_markdown_fn(language, pack), encoding="utf-8")


def dumps_experiment_results(payload: dict) -> str:
    """Format experiment results JSON with 2-space outer indent and one line per row/top_group."""
    import copy

    clone = copy.deepcopy(payload)
    inline_map: dict[str, str] = {}
    idx = 0
    for lang_block in (clone.get("languages") or {}).values():
        if not isinstance(lang_block, dict):
            continue
        for key in ("rows", "top_groups"):
            items = lang_block.get(key)
            if isinstance(items, list):
                new_items = []
                for item in items:
                    token = f"__INLINE_{idx}__"
                    idx += 1
                    inline_map[f'"{token}"'] = json.dumps(
                        item, separators=(",", ":"), ensure_ascii=False
                    )
                    new_items.append(token)
                lang_block[key] = new_items
        tg = lang_block.get("top_group")
        if isinstance(tg, dict):
            token = f"__INLINE_{idx}__"
            idx += 1
            inline_map[f'"{token}"'] = json.dumps(
                tg, separators=(",", ":"), ensure_ascii=False
            )
            lang_block["top_group"] = token
    out = json.dumps(clone, indent=2, ensure_ascii=False)
    for k, v in inline_map.items():
        out = out.replace(k, v)
    return out + "\n"


def write_aggregate_for(
    here: Path, cfg: dict, languages: dict, experiment_payload_fn, write_combined_markdown_fn
) -> Path:
    rel = (cfg.get("paths") or {}).get("results") or "results.json"
    out = here / rel
    out.write_text(
        dumps_experiment_results(experiment_payload_fn(cfg, languages)),
        encoding="utf-8",
    )
    md_rel = (cfg.get("paths") or {}).get("summary") or "results.md"
    md = here / md_rel
    md.write_text(write_combined_markdown_fn(cfg, languages), encoding="utf-8")
    return out


def run_summarize_cli(ns: dict[str, Any], argv: list[str] | None = None) -> int:
    """Shared CLI entry point that delegates through ``ns`` (module globals) so tests can monkeypatch."""
    parser = argparse.ArgumentParser(description=ns.get("__doc__"))
    parser.add_argument("--language", help="Language id (python, go, …)")
    parser.add_argument("--csv", type=Path, help="Raw CSV for that language")
    parser.add_argument(
        "--all",
        action="store_true",
        help="Rebuild every language that has a CSV, then write results.json",
    )
    parser.add_argument(
        "--config",
        type=Path,
        default=ns["HERE"] / CONFIG_NAME,
        help="Path to experiment.yaml",
    )
    args = parser.parse_args(argv)
    cfg = ns["_load_cfg"](args.config)
    catalog = ns["libraries_by_language"](cfg)

    if args.all:
        saved = load_language_blocks(ns["HERE"])
        languages = {}
        for lang in catalog:
            csv_path = ns["_latest_csv"](lang)
            if csv_path is None:
                block = saved_language(ns["HERE"], lang, saved)
                if block is not None:
                    languages[lang] = block
                    print(f"{lang}: kept saved results (no CSV)")
                    continue
                languages[lang] = {
                    "status": "missing",
                    "language": lang,
                    "csv": None,
                    "error": "no CSV in this language folder yet",
                    "rows": [],
                }
                ns["write_outputs"](lang, languages[lang])
                continue
            pack = ns["summarize_language"](lang, csv_path, catalog, cfg.get("analysis") or {})
            languages[lang] = pack
            ns["write_outputs"](lang, pack)
            print(f"{lang}: {pack['status']} ({pack.get('csv')})")
        path = ns["write_aggregate"](cfg, languages)
        print(f"Wrote {path}")
        return 0

    if not args.language or not args.csv:
        parser.error("pass --all, or both --language and --csv")

    pack = ns["summarize_language"](args.language, args.csv, catalog, cfg.get("analysis") or {})
    ns["write_outputs"](args.language, pack)
    saved = load_language_blocks(ns["HERE"])
    languages = {}
    for lang in catalog:
        if lang == args.language:
            languages[lang] = pack
            continue
        block = saved_language(ns["HERE"], lang, saved)
        if block is not None:
            languages[lang] = block
    ns["write_aggregate"](cfg, languages)
    print(f"Wrote {ns['HERE'] / 'results.json'}")
    return 0 if pack["status"] == "ok" else 1
