#!/usr/bin/env python3
"""Turn this experiment's CSVs into tables people can read and JSON a dashboard can load.

Rebuild from saved CSVs (no new timing run):

    cd analysis
    uv run python ../experiments/02-flat-record-formats/summarize.py --all

One language:

    uv run python ../experiments/02-flat-record-formats/summarize.py \\
        --language python --csv path/to/file.csv
"""

from __future__ import annotations

import argparse
import json
import statistics
import sys
from datetime import datetime, timezone
from pathlib import Path

HERE = Path(__file__).resolve().parent
REPO = HERE.parents[1]
LIB = REPO / "experiments" / "lib"
if str(LIB) not in sys.path:
    sys.path.insert(0, str(LIB))

from experiment_config import load_experiment, libraries_by_language

NS_PER_US = 1000.0
MEMORY_MODES = {"bytes", "string", "buffer"}
CONFIG_NAME = "experiment.yaml"


def _prep() -> None:
    src = str(REPO / "analysis" / "src")
    if src not in sys.path:
        sys.path.insert(0, src)


def _load_cfg(path: Path | None = None) -> dict:
    return load_experiment(path or (HERE / CONFIG_NAME))


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


def _ns(v) -> int | None:
    if v is None:
        return None
    return int(round(float(v)))


def _us(v) -> float | None:
    if v is None:
        return None
    return round(float(v) / NS_PER_US, 4)


def _median_extra(records: list[dict], name: str, mode: str, field: str) -> int | None:
    want = MEMORY_MODES if _io_label(mode) == "memory" else {mode.lower()}
    vals = [
        float(r[field])
        for r in records
        if r.get("SerializerName") == name
        and str(r.get("StringOrStream", "")).lower() in want
        and field in r
    ]
    if not vals:
        return None
    return int(round(statistics.median(vals)))


def _latest_csv(language: str) -> Path | None:
    folder = HERE / language / "logs"
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


def _assign_top_groups(rows: list[dict], samples: dict, analysis: dict) -> list[dict]:
    """One similar/close set per (n, io). Do not mix one-record and 100-record calls."""
    tg = analysis.get("top_group") or {}
    similar_max = float(tg.get("similar_max", 0.147))
    close_max = float(tg.get("close_max", 0.33))
    method = tg.get("method") or "cliffs_delta_vs_fastest"

    try:
        from benchmark_analysis.stats import cliffs_delta, cliffs_delta_label
    except ImportError:
        cliffs_delta = None  # type: ignore
        cliffs_delta_label = None  # type: ignore

    for r in rows:
        r["in_comparison"] = False
        r["tier"] = None
        r["cliffs_delta_vs_fastest"] = None
        r["cliffs_label"] = None
        r["on_time_size_front"] = False

    groups_out: list[dict] = []
    keys = sorted({(r.get("n"), r.get("io")) for r in rows if _in_main_set(r, analysis)})
    for n, io in keys:
        main = [r for r in rows if _in_main_set(r, analysis) and r.get("n") == n and r.get("io") == io]
        for r in main:
            r["in_comparison"] = True
        if not main:
            continue
        ref = min(main, key=lambda r: (r.get("total_median_ns") or 10**18, r["library"]))
        ref_times = samples.get((ref["library"], io, n)) or []
        for r in main:
            if r["library"] == ref["library"]:
                r["tier"] = "fastest"
                r["cliffs_delta_vs_fastest"] = 0.0
                r["cliffs_label"] = "reference"
                continue
            mine = samples.get((r["library"], io, n)) or []
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
        groups_out.append(
            {
                "method": method,
                "n": n,
                "io": io,
                "similar_max": similar_max,
                "close_max": close_max,
                "reference": ref["library"],
                "similar": [r["library"] for r in main if r.get("tier") in {"fastest", "similar"}],
                "close": [r["library"] for r in main if r.get("tier") == "close"],
                "time_size_front": [r["library"] for r in main if r.get("on_time_size_front")],
            }
        )
    return groups_out


def summarize_language(language: str, csv_path: Path, catalog: dict, analysis: dict) -> dict:
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
                f"No JSON-library rows in {csv_path.name} "
                f"(parsed {len(records)}, skipped {skipped})"
            ),
            "rows": [],
            "top_group": None,
        }

    stats = compute_statistics(kept, config=load_stats_config(), language_hint=language)
    rows = []
    samples: dict[tuple[str, str, int | None], list] = {}
    for g in stats.values():
        name = g["serializer"]
        info = meta.get(name) or {}
        mode = g.get("mode") or ""
        io = _io_label(mode)
        n_raw = g.get("data_type_instance_count")
        try:
            n = int(n_raw) if n_raw not in (None, "") else 1
        except (TypeError, ValueError):
            n = 1
        samples[(name, io, n)] = list(g.get("_times_total_filtered") or [])
        row = {
            "library": name,
            "n": n,
            "version": g.get("serializer_version") or None,
            "role": info.get("role"),
            "writes_named_fields": bool(info.get("writes_named_fields", True)),
            "io": io,
            "stream_kind": _stream_kind(g.get("StreamMode")),
            "write_median_ns": _ns(g.get("ser_median_ns")),
            "read_median_ns": _ns(g.get("deser_median_ns")),
            "total_median_ns": _ns(g.get("total_median_ns")),
            "write_median_us": _us(g.get("ser_median_ns")),
            "read_median_us": _us(g.get("deser_median_ns")),
            "total_median_us": _us(g.get("total_median_ns")),
            "total_mean_ns": _ns(g.get("total_mean_ns")),
            "total_p95_ns": _ns(g.get("total_p95_ns")),
            "total_p99_ns": _ns(g.get("total_p99_ns")),
            "total_ci_low_ns": _ns(g.get("total_ci_low_ns")),
            "total_ci_high_ns": _ns(g.get("total_ci_high_ns")),
            "size_bytes": _ns(g.get("median_size_bytes")),
            "size_gzip_bytes": _median_extra(kept, name, mode, "SizeGzip"),
            "fidelity": g.get("mean_fidelity"),
            "runs": int(g.get("runs") or 0),
            "runs_raw": int(g.get("runs_raw") or 0),
            "outliers_removed": int(g.get("outliers_removed") or 0),
        }
        rows.append(row)

    rows.sort(
        key=lambda r: (
            r.get("n") or 0,
            r["io"] != "memory",
            r["total_median_ns"] or 10**18,
            r["library"],
        )
    )
    top_groups = _assign_top_groups(rows, samples, analysis)
    return {
        "status": "ok",
        "language": language,
        "csv": _rel(csv_path),
        "error": None,
        "top_groups": top_groups,
        "top_group": next((g for g in top_groups if g.get("n") == 1), top_groups[0] if top_groups else None),
        "rows": rows,
    }


def _rel(path: Path) -> str:
    try:
        return str(path.resolve().relative_to(REPO))
    except ValueError:
        return str(path)


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


def write_language_markdown(language: str, pack: dict) -> str:
    lines = [
        f"# Experiment 2 results — {language}",
        "",
        f"**Date:** {datetime.now(timezone.utc).date().isoformat()}",
        f"**Raw file:** `{pack.get('csv') or '—'}`",
        f"**Language:** {language}",
        "**Sample:** one flat record (`message`), 1 and 100 records per write",
        "**Cleaning:** first trial dropped; default stall filter (same as the project)",
        "",
    ]
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
                "We do not name a single winner. This sample is one small flat record. "
                "A different record can change who is first. Groups are computed **separately** "
                "for 1 record and for 100 records.",
                "",
            ]
        )
        for tg in groups:
            if not tg:
                continue
            label = f"N = {tg.get('n')}, {tg.get('io')}"
            similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
            close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
            front = ", ".join(f"`{x}`" for x in (tg.get("time_size_front") or [])) or "—"
            lines.append(f"**{label}** — not clearly slower: {similar}. Small gap: {close}. Time/size front: {front}.")
            lines.append("")
    if pack.get("status") != "ok":
        lines.extend([f"**This run did not produce a table:** {pack.get('error')}", ""])
    return "\n".join(lines) + "\n"


def experiment_payload(cfg: dict, languages: dict) -> dict:
    sample_cfg = cfg.get("sample") or {}
    analysis = cfg.get("analysis") or {}
    saved = sample_cfg.get("saved_as") or "sample.json"
    sample_path = HERE / saved
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


def write_outputs(language: str, pack: dict) -> None:
    dest = HERE / language
    dest.mkdir(parents=True, exist_ok=True)
    (dest / "results.json").write_text(
        json.dumps(pack, indent=2, ensure_ascii=False) + "\n", encoding="utf-8"
    )
    (dest / "results.md").write_text(write_language_markdown(language, pack), encoding="utf-8")


def write_combined_markdown(cfg: dict, languages: dict) -> str:
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
        "Times in two languages are **not** one contest. Read each row as "
        "an answer inside that language only.",
        "",
        "We do not name a single winner. This sample is one small flat record. "
        "A different record can change who is first. **Similar** means we "
        "cannot tell the library apart from the fastest in the comparison set "
        "on this sample. **Close** means a small gap. Groups for 1 record and "
        "for 100 records are separate.",
        "",
        "## At a glance (1 record per write)",
        "",
        "| Language | Status | Not clearly slower | Small gap | Time/size front | Full table |",
        "|----------|--------|--------------------|-----------|-----------------|------------|",
    ]
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
        if status != "ok":
            lines.append(f"| {lang} | {status} | — | — | — |")
            continue
        if not tg:
            lines.append(f"| {lang} | {status} | — | — | — |")
            continue
        similar = ", ".join(f"`{x}`" for x in (tg.get("similar") or [])) or "—"
        close = ", ".join(f"`{x}`" for x in (tg.get("close") or [])) or "—"
        front = ", ".join(f"`{x}`" for x in (tg.get("time_size_front") or [])) or "—"
        lines.append(f"| {lang} | {status} | {similar} | {close} | {front} |")

    lines.extend(
        [
            "",
            "## In memory, by language",
            "",
            "Every listed library (JSON, MessagePack, Protocol Buffers). "
            "Times are middle values in microseconds. Lower is better **inside that language**.",
            "",
        ]
    )
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

    lines.extend(
        [
            "## What we saw",
            "",
            "Leaving JSON is not one answer. It depends on the language.",
            "",
            "- **Python:** `orjson` is close to `msgspec-msgpack` at one record. "
            "Protocol Buffers is smaller but slower than `orjson` here. "
            "At 100 records, `orjson` is no longer close.",
            "- **JavaScript and C#:** ordinary JSON is still the fastest "
            "write-and-read on this sample. C# has no MessagePack row.",
            "- **Go, Java, Rust, C, C++, Swift:** a Protocol Buffers row is "
            "clearly fastest and about three times smaller than JSON.",
            "",
            "C `protobuf-c` and the C/C++ `protobuf-wire` rows use the suite "
            "wire path. Official Google `libprotobuf` did not run in C or C++.",
            "",
            "## What this page is not",
            "",
            "- It is not a ranking of languages.",
            "- It is not a promise that the same names stay on top if you change the record.",
            "- A small gap on this tiny record is not a reason to change a public contract.",
            "",
        ]
    )
    return "\n".join(lines) + "\n"


def write_aggregate(cfg: dict, languages: dict) -> Path:
    rel = (cfg.get("paths") or {}).get("results") or "results.json"
    out = HERE / rel
    out.write_text(
        json.dumps(experiment_payload(cfg, languages), indent=2, ensure_ascii=False) + "\n",
        encoding="utf-8",
    )
    md_rel = (cfg.get("paths") or {}).get("summary") or "results.md"
    md = HERE / md_rel
    md.write_text(write_combined_markdown(cfg, languages), encoding="utf-8")
    return out


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
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
        default=HERE / CONFIG_NAME,
        help="Path to experiment.yaml",
    )
    args = parser.parse_args()
    cfg = _load_cfg(args.config)
    catalog = libraries_by_language(cfg)

    if args.all:
        languages = {}
        for lang in catalog:
            csv_path = _latest_csv(lang)
            if csv_path is None:
                languages[lang] = {
                    "status": "missing",
                    "language": lang,
                    "csv": None,
                    "error": "no CSV in this language folder yet",
                    "rows": [],
                }
                write_outputs(lang, languages[lang])
                continue
            pack = summarize_language(lang, csv_path, catalog, cfg.get("analysis") or {})
            languages[lang] = pack
            write_outputs(lang, pack)
            print(f"{lang}: {pack['status']} ({pack.get('csv')})")
        path = write_aggregate(cfg, languages)
        print(f"Wrote {path}")
        return 0

    if not args.language or not args.csv:
        parser.error("pass --all, or both --language and --csv")

    pack = summarize_language(args.language, args.csv, catalog, cfg.get("analysis") or {})
    write_outputs(args.language, pack)
    # Refresh the combined file from whatever language JSON we already have.
    languages = {}
    for lang in catalog:
        p = HERE / lang / "results.json"
        if p.is_file():
            languages[lang] = json.loads(p.read_text(encoding="utf-8"))
        elif lang == args.language:
            languages[lang] = pack
    write_aggregate(cfg, languages)
    print(f"Wrote {HERE / args.language / 'results.json'}")
    return 0 if pack["status"] == "ok" else 1


if __name__ == "__main__":
    raise SystemExit(main())
