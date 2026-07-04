"""Report generation (Markdown and HTML)."""

import os
from collections import defaultdict
from datetime import datetime
from typing import Dict, List, Tuple, Optional

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from .stats import prepare_analysis_records


def _records_to_melted_df(
    records: List[Dict],
    language: str,
    *,
    stats_config: Optional[Dict] = None,
    pre_sanitized: bool = False,
    language_hint: Optional[str] = None,
) -> pd.DataFrame:
    """Convert records to a melted dataframe for violin plots.

    Uses the unified :func:`prepare_analysis_records` pipeline (warmup drop,
    config time-unit normalization, all-or-nothing paired IQR) so violin
    plots reflect the *exact* sample population used for summary tables.
    Pass ``pre_sanitized=True`` when *records* already came from that pipeline.
    """
    if not records:
        return pd.DataFrame()

    if pre_sanitized:
        clean = list(records)
    else:
        # language_hint should be a language *id* (e.g. python), not display name
        hint = language_hint
        clean, _ = prepare_analysis_records(
            records, config=stats_config, language_hint=hint
        )
    if not clean:
        return pd.DataFrame()

    df = pd.DataFrame(clean)
    if "Language" not in df.columns:
        df["Language"] = language_hint or language

    # Melt serialize/deserialize into Operation column. Times are already ns.
    need = [
        "SerializerName",
        "TestDataName",
        "StringOrStream",
        "TimeSer",
        "TimeDeser",
        "Language",
        "RepetitionIndex",
    ]
    for col in need:
        if col not in df.columns:
            if col == "RepetitionIndex":
                df[col] = -1
            else:
                return pd.DataFrame()

    ser = df[
        ["SerializerName", "TestDataName", "StringOrStream", "TimeSer", "Language", "RepetitionIndex"]
    ].copy()
    ser["Operation"] = "Serialize"
    ser = ser.rename(columns={"TimeSer": "Time_ns"})
    if "OpPerSecSer" in df.columns:
        ser["OpPerSec"] = df["OpPerSecSer"].values
    else:
        ser["OpPerSec"] = 0

    deser = df[
        ["SerializerName", "TestDataName", "StringOrStream", "TimeDeser", "Language", "RepetitionIndex"]
    ].copy()
    deser["Operation"] = "Deserialize"
    deser = deser.rename(columns={"TimeDeser": "Time_ns"})
    if "OpPerSecDeser" in df.columns:
        deser["OpPerSec"] = df["OpPerSecDeser"].values
    else:
        deser["OpPerSec"] = 0

    melted = pd.concat([ser, deser], ignore_index=True)
    if melted.empty:
        return melted

    # Drop non-positive (invalid) only — no extra q99 tail clip / independent IQR.
    melted = melted[melted["Time_ns"] > 0]
    return melted


def _generate_violin_plot(
    melted_df: pd.DataFrame,
    data_type: str,
    output_dir: str,
    language: str = "",
    lang_id: str = "",
    top_n: Optional[int] = None,
    data_source: str = "",
) -> Optional[str]:
    """Generate violin plot for a specific data type, returning image filename.

    Embeds mapping metadata (fixture, language id, log path, modes, n) in the
    title/footer so plots can be tied back to CSV results.
    """
    if melted_df.empty or data_type not in melted_df['TestDataName'].values:
        return None

    subset = melted_df[melted_df['TestDataName'] == data_type].copy()
    if subset.empty:
        return None

    # Time_ns already normalized + filtered by the shared stats pipeline.
    subset['Time_us'] = subset['Time_ns'].astype(float) / 1000.0
    # Timings cannot be negative; drop any bad rows before KDE.
    subset = subset[subset['Time_us'] > 0].copy()
    if subset.empty:
        return None

    # Filter to top N serializers by mean time (default: top 5 for every language).
    # This is a *display* choice (plot density), not a change to the analysis sample
    # used for tables — tables always include every serializer.
    if top_n is None:
        top_n = VIOLIN_TOP_N_SERIALIZERS
    if top_n > 0:
        mean_times = subset.groupby("SerializerName")["Time_us"].mean().sort_values()
        # If fewer than top_n exist, head() returns all of them.
        top_serializers = mean_times.head(int(top_n)).index.tolist()
        subset = subset[subset["SerializerName"].isin(top_serializers)].copy()

    # No additional p99 winsorization: seaborn cut=0 already limits KDE to the
    # observed data range, and tables/plots must share the same sample values.

    order = subset.groupby('SerializerName')['Time_us'].mean().sort_values().index.tolist()
    # Wide dynamic range (e.g. cbor ~20× faster peers) → log x so small violins stay readable.
    med_by_ser = subset.groupby('SerializerName')['Time_us'].median()
    dyn_ratio = float(med_by_ser.max() / med_by_ser.min()) if len(med_by_ser) and med_by_ser.min() > 0 else 1.0
    use_log = dyn_ratio >= 5.0

    # Use catplot (modern seaborn name for factorplot)
    try:
        g = sns.catplot(
            data=subset,
            x='Time_us',
            y='SerializerName',
            hue='Operation',
            kind='violin',
            split=True,
            # cut=0: do not extend KDE past observed data (avoids fake negative times)
            cut=0,
            inner=None,  # Remove box plot inner lines for cleaner violin appearance
            height=max(6, 0.35 * len(order) + 2),
            aspect=1.35,
            legend_out=False,
            order=order,
        )
        lang_key = (lang_id or _lang_file_key("", language)).lower().replace("#", "sharp")
        safe_fixture = data_type.replace(" ", "_")
        img_name = f"{lang_key}_{safe_fixture}.png"
        src = data_source or f"logs/{lang_key}/benchmark-log.csv"
        modes = sorted(
            {str(m) for m in subset.get("StringOrStream", pd.Series(dtype=str)).dropna().unique()}
        )
        modes_s = ",".join(modes) if modes else "n/a"
        n_pts = len(subset)
        top_note = f" · Top {int(top_n)}" if top_n and int(top_n) > 0 else ""

        # Title: language · fixture · Top N (scale on x-axis label).
        g.fig.suptitle(
            f"{language or lang_key} · {data_type}{top_note}",
            fontsize=12,
            y=1.02,
        )
        if use_log:
            g.set_axis_labels('Time (µs, log scale)', 'Serializer')
            for ax in g.axes.flat:
                ax.set_xscale('log')
                # Log axes cannot include 0; pad within positive data range.
                lo = float(subset['Time_us'].min())
                hi = float(subset['Time_us'].max())
                ax.set_xlim(lo * 0.85, hi * 1.15)
        else:
            g.set_axis_labels('Time (µs)', 'Serializer')
            g.set(xlim=(0, None))

        # Footer: file + CSV + samples + mode (+ optional run id). No seed.
        run_bit = ""
        try:
            from .environment import load_run_config
            from .config_loader import repo_root as _repo_root

            cfg_doc = None
            if data_source:
                candidates = [data_source]
                if not os.path.isabs(data_source):
                    candidates.append(os.path.abspath(data_source))
                    try:
                        candidates.append(str(_repo_root() / data_source))
                    except Exception:
                        pass
                for cand in candidates:
                    if not cand:
                        continue
                    cfg_doc = load_run_config(cand)
                    if cfg_doc:
                        break
            if cfg_doc:
                ts = cfg_doc.get("benchmark_ts")
                if not ts and isinstance(cfg_doc.get("run"), dict):
                    ts = cfg_doc["run"].get("benchmark_ts")
                if ts:
                    run_bit = f"  |  run={ts}"
        except Exception:
            run_bit = ""
        g.fig.text(
            0.5,
            -0.02,
            f"{img_name}  |  {src}  |  samples={n_pts}  |  mode={modes_s}{run_bit}",
            ha="center",
            va="top",
            fontsize=8,
            color="#444444",
            wrap=True,
        )

        img_path = os.path.join(output_dir, img_name)
        plt.savefig(img_path, dpi=150, bbox_inches="tight")
        plt.close(g.fig)
        return os.path.basename(img_path)
    except Exception as e:
        lang_info = f" ({language})" if language else ""
        print(f"Warning: Could not generate violin plot for {data_type}{lang_info}: {e}")
        plt.close('all')
        return None


# Violin plots: always show this many fastest serializers per fixture (all languages).
VIOLIN_TOP_N_SERIALIZERS = 5

# CSV StringOrStream values → human labels (not "number of bytes")
_MODE_DISPLAY = {
    "bytes": "bytes mode",
    "stream": "stream mode",
    "string": "string mode",
}


def _display_mode(mode: str) -> str:
    """Label harness API mode so it is not confused with payload size."""
    key = (mode or "").strip().lower()
    return _MODE_DISPLAY.get(key, mode)


def _pick_column_unit(values: list) -> tuple:
    """Choose one scale for an entire column (no mixed K/M in one column).

    Returns ``(divisor, unit_suffix)`` where unit is ``""``, ``"K"``, or ``"M"``.
    Rule: use **M** if the column's max absolute value is ≥ 1e6, else **K** if
    max ≥ 1e3, else plain units (no suffix).
    """
    nums = []
    for v in values:
        try:
            x = float(v)
        except (TypeError, ValueError):
            continue
        if x == x:  # not NaN
            nums.append(abs(x))
    if not nums:
        return 1.0, ""
    mx = max(nums)
    if mx >= 1_000_000:
        return 1_000_000.0, "M"
    if mx >= 1_000:
        return 1_000.0, "K"
    return 1.0, ""


def _higher_is_better(value_key: str) -> bool:
    """Semantic direction for “best” in a results column.

    Throughput (ops/s) → higher is better; time/latency/size → lower is better.
    """
    key = (value_key or "").lower()
    if "ops" in key or "throughput" in key or "rate" in key:
        return True
    if (
        "time" in key
        or key.endswith("_ns")
        or key.endswith("_us")
        or key.endswith("_ms")
        or "latency" in key
        or "duration" in key
        or "size" in key
        or "bytes_len" in key
        or "payload" in key
    ):
        return False
    return True


def _column_best(values: list, *, higher_is_better: bool) -> Optional[float]:
    """Return the semantic best numeric value in *values*, or None if empty."""
    nums: List[float] = []
    for v in values:
        try:
            x = float(v)
        except (TypeError, ValueError):
            continue
        if x == x:  # not NaN
            nums.append(x)
    if not nums:
        return None
    return max(nums) if higher_is_better else min(nums)


def _format_in_unit(
    val: float,
    divisor: float,
    unit: str,
    *,
    sig: int = 2,
    bold: bool = False,
) -> str:
    """Format ``val`` in a fixed column unit with 2 significant digits."""
    try:
        v = float(val)
    except (TypeError, ValueError):
        return str(val)
    if v != v:  # NaN
        return "-"
    if v == 0:
        text = "0"
    else:
        scaled = v / divisor if divisor else v
        text = f"{float(f'%.{sig}g' % scaled)}"
        if text.endswith(".0") and "e" not in text.lower():
            text = text[:-2]
        text = f"{text}{unit}" if unit else text
    return f"**{text}**" if bold else text


def _time_ns_to_display_us(value_key: str) -> bool:
    """True when *value_key* is a latency stored in nanoseconds (display as µs)."""
    key = (value_key or "").lower()
    if not key.endswith("_ns"):
        return False
    # avg_time_*, total_median_ns, ser_p95_ns, total_ci_low_ns, etc.
    return (
        "time" in key
        or "latency" in key
        or "duration" in key
        or key.startswith(("ser_", "deser_", "total_"))
        or "_median_ns" in key
        or "_mean_ns" in key
        or "_p" in key  # percentiles *_p95_ns
        or "_ci_" in key
        or "_mad_ns" in key
        or "_std_ns" in key
        or "_min_ns" in key
        or "_max_ns" in key
    )


def _pivot_table_md(stats: Dict, rows_dim: str, cols_dim: str, value_key: str, title: str) -> str:
    """Generate a markdown pivot table from stats dict.

    Semantic best-in-column values are bold (ops/throughput: max; time/size: min).
    Ties are all bolded. Unit scale and best use **displayed** cell values only.

    Latency metrics stored as ``*_ns`` are shown in **microseconds** (÷1000) as
    plain numbers (no K/M suffixes), so ~5400 ns appears as ``5.4`` not ``5.4K``.
    """
    lines = [f"\n### {title}\n"]

    # Extract unique row and column values
    row_vals = sorted(set(s[rows_dim] for s in stats.values()))
    col_vals = sorted(set(s[cols_dim] for s in stats.values()))

    if not row_vals or not col_vals:
        lines.append("*No data available*\n")
        return '\n'.join(lines)

    # When columns are harness modes, spell out "bytes mode" / "stream mode"
    def _col_label(cv: str, unit: str = "") -> str:
        base = _display_mode(cv) if cols_dim == "mode" else cv
        if unit:
            return f"{base} ({unit})"
        return base

    higher = _higher_is_better(value_key)
    # Display latency in µs (analysis/stats remain nanoseconds in memory/CSV).
    to_us = _time_ns_to_display_us(value_key)
    display_scale = 1_000.0 if to_us else 1.0  # ns → µs

    # Resolve one numeric (or None) per displayed cell first — unit/best use these only
    cell: Dict[Tuple[str, str], Optional[float]] = {}
    for rv in row_vals:
        for cv in col_vals:
            matching = [
                s for s in stats.values() if s[rows_dim] == rv and s[cols_dim] == cv
            ]
            if not matching:
                cell[(rv, cv)] = None
                continue
            val = matching[0].get(value_key)
            if isinstance(val, (int, float)) and not isinstance(val, bool) and val == val:
                cell[(rv, cv)] = float(val) / display_scale
            else:
                cell[(rv, cv)] = None

    col_units: Dict[str, tuple] = {}
    col_best: Dict[str, Optional[float]] = {}
    for cv in col_vals:
        displayed = [cell[(rv, cv)] for rv in row_vals if cell[(rv, cv)] is not None]
        # Time-in-µs: keep plain numbers (avoid re-introducing K on large µs values).
        if to_us:
            col_units[cv] = (1.0, "")
        else:
            col_units[cv] = _pick_column_unit(displayed)
        col_best[cv] = _column_best(displayed, higher_is_better=higher)

    # Header (unit in column title when scaled)
    header = (
        f"| {rows_dim} | "
        + " | ".join(_col_label(cv, col_units[cv][1]) for cv in col_vals)
        + " |"
    )
    lines.append(header)
    lines.append("|" + "---|" * (len(col_vals) + 1))

    # Rows — all cells in a column share that column's unit; best is bold
    for rv in row_vals:
        row_cells = [rv]
        for cv in col_vals:
            val = cell[(rv, cv)]
            if val is None:
                row_cells.append("-")
            else:
                div, unit = col_units[cv]
                best = col_best[cv]
                is_best = best is not None and val == best
                row_cells.append(_format_in_unit(val, div, unit, bold=is_best))
        lines.append("| " + " | ".join(row_cells) + " |")

    lines.append("")
    return '\n'.join(lines)



# Display labels, MkDocs docs subdirs, and plot file keys
def _lang_display_map() -> dict:
    try:
        from .config_loader import known_language_ids, language_display_name

        return {lid: language_display_name(lid) for lid in known_language_ids()}
    except Exception:
        return {
            "csharp": "C#",
            "python": "Python",
            "rust": "Rust",
            "c": "C",
            "javascript": "JavaScript",
            "go": "Go",
        }


def _lang_docs_dir_map() -> dict:
    try:
        from .config_loader import known_language_ids, language_docs_dir

        return {lid: language_docs_dir(lid) for lid in known_language_ids()}
    except Exception:
        return {
            "csharp": "c-sharp",
            "python": "python",
            "rust": "rust",
            "c": "c",
            "javascript": "javascript",
            "go": "go",
        }


def _lang_order_list() -> list:
    try:
        from .config_loader import lang_order

        return list(lang_order())
    except Exception:
        return ["csharp", "python", "rust", "c", "javascript", "go"]


def _normalize_lang_id(lang: str) -> str:
    lang = (lang or "unknown").lower()
    try:
        from .config_loader import language_aliases

        return language_aliases().get(lang, lang if lang != "c#" else "csharp")
    except Exception:
        if lang in ("c#", "cs", "c-sharp"):
            return "csharp"
        return lang


def _stats_by_language(multi_lang_stats: Optional[Dict]) -> Dict[str, Dict]:
    """Group stat entries by normalized language id."""
    by_lang: Dict[str, Dict] = {}
    if not multi_lang_stats:
        return by_lang
    for key, entry in multi_lang_stats.items():
        lang = _normalize_lang_id(entry.get("language") or "unknown")
        by_lang.setdefault(lang, {})[key] = entry
    return by_lang



# Within-language comparison categories (prefer peers over cross-paradigm ranks).
_RUST_CATEGORY: Dict[str, str] = {
    "serde_json": "JSON",
    "simd-json": "JSON",
    "sonic-rs": "JSON",
    "rmp-serde": "Schemaless binary (interop)",
    "ciborium": "Schemaless binary (interop)",
    "minicbor": "Schemaless binary (interop)",
    "bson": "Schemaless binary (interop)",
    "bincode": "Rust-centric binary",
    "postcard": "Rust-centric binary",
    "bitcode": "Rust-centric binary",
    "nanoserde": "Rust-centric binary",
    "speedy": "Rust-centric binary",
    "flexbuffers": "Schema / zero-copy family",
    "rkyv": "Schema / zero-copy family",
    "prost": "Schema / zero-copy family",
}


def _category_pivot_md(stats: Dict, lang_id: str, title: str) -> str:
    """Markdown table: mean Ser+Deser ops/s (bytes mode) by serializer within category."""
    cat_map = _RUST_CATEGORY if lang_id == "rust" else {}
    if not cat_map or not stats:
        return ""

    # entry fields from compute_statistics list or dict values
    entries = list(stats.values()) if isinstance(stats, dict) else list(stats)
    # Prefer bytes mode only for category ranking
    by_cat: Dict[str, List[Tuple[str, float]]] = {}
    for e in entries:
        if not isinstance(e, dict):
            continue
        mode = (e.get("mode") or e.get("StringOrStream") or "").lower()
        if mode != "bytes":
            continue
        ser = e.get("serializer") or e.get("SerializerName") or ""
        if ser not in cat_map:
            continue
        ops = e.get("avg_ops_per_sec")
        if ops is None:
            tot = e.get("avg_time_total_ns") or 0
            ops = (1_000_000_000.0 / tot) if tot else 0.0
        # Aggregate per serializer across test_data (mean later)
        by_cat.setdefault(cat_map[ser], []).append((ser, float(ops)))

    if not by_cat:
        return ""

    lines = [
        f"### {title}",
        "",
        "Compare serializers **within the same paradigm** (not across JSON vs zero-copy).",
        "Values are mean Ser+Deser **ops/s** over fixtures, using the harness "
        "**bytes mode** only (buffer API: encode to a byte buffer / decode from a slice — "
        "not “number of bytes”). Higher is better. Stream mode is excluded here. "
        "Each numeric column uses **one** unit (K or M) for the whole column, "
        "with **2 significant digits** (display only; CSV unchanged). "
        "**Bold** = best in column (ops/s: highest).",
        "",
    ]
    for cat in sorted(by_cat.keys()):
        # average ops per serializer across fixtures
        acc: Dict[str, List[float]] = defaultdict(list)
        for ser, ops in by_cat[cat]:
            acc[ser].append(ops)
        ranked = sorted(
            ((s, sum(v) / len(v)) for s, v in acc.items()),
            key=lambda x: -x[1],
        )
        col_vals = [ops for _, ops in ranked]
        div, unit = _pick_column_unit(col_vals)
        best = _column_best(col_vals, higher_is_better=True)
        unit_label = f" ({unit})" if unit else ""
        lines.append(f"#### {cat}")
        lines.append("")
        lines.append(f"| serializer | mean ops/s (bytes mode){unit_label} |")
        lines.append("|---|---:|")
        for ser, mean_ops in ranked:
            is_best = best is not None and mean_ops == best
            lines.append(
                f"| {ser} | {_format_in_unit(mean_ops, div, unit, bold=is_best)} |"
            )
        lines.append("")
    return "\n".join(lines)


def _load_lang_run_config(csv_path: Optional[str]) -> Optional[Dict]:
    if not csv_path:
        return None
    try:
        from .environment import load_run_config

        return load_run_config(csv_path)
    except Exception:
        return None


def _config_section_md(lang_id: str, csv_path: Optional[str]) -> str:
    """Run-config block for the **end** of Results pages.

    Always emits a visible ``## Run configuration (important)`` heading (TOC +
    page end). Body is collapsed by default via Material/pymdownx ``???`` details
    (only the details summary line is clickable; expand to see host/seed/etc.).
    """
    from .environment import important_config_summary

    doc = _load_lang_run_config(csv_path)
    # Indent body by 4 spaces so it stays inside the collapsed details block.
    body: List[str] = [
        "Key fields from the run sidecar (`*.configs.json`, or legacy "
        "`*.environment.json`). Full metric definitions: "
        "[Metrics catalog](../analysis/METRICS.md). "
        "Optional blocks (`dataset`, `serializers`) appear only when captured.",
        "",
    ]
    if csv_path:
        body.append(f"- **Source CSV:** `{csv_path.replace(chr(92), '/')}`")
    summary = important_config_summary(doc)
    if summary:
        for s in summary:
            body.append(f"- {s}")
    else:
        body.append(
            "- *No sidecar config found beside the latest CSV "
            "(re-run harness with environment capture to populate).*"
        )
    if doc:
        ds = doc.get("dataset") if isinstance(doc.get("dataset"), dict) else {}
        if ds.get("fixtures"):
            names = [f.get("name") for f in ds["fixtures"] if isinstance(f, dict) and f.get("name")]
            if names:
                body.append(f"- **Fixtures (config):** {', '.join(str(n) for n in names)}")
        ser = doc.get("serializers") if isinstance(doc.get("serializers"), dict) else {}
        items = ser.get("items") if isinstance(ser.get("items"), list) else []
        if items:
            body.append("- **Serializers (from CSV):**")
            for it in items[:40]:
                if not isinstance(it, dict):
                    continue
                n, v = it.get("name"), it.get("version") or ""
                body.append(f"  - `{n}`" + (f" @ {v}" if v else ""))
            if len(items) > 40:
                body.append(f"  - … ({len(items) - 40} more)")

    # H2 always visible at end of page; details body collapsed by default.
    lines = [
        "",
        "## Run configuration (important)",
        "",
        '??? note "Show host, seed, serializers, and source CSV"',
        "",
    ]
    for line in body:
        lines.append(f"    {line}" if line else "    ")
    lines.append("")
    return "\n".join(lines)


def _scientific_summary_md(stats: Dict, title: str, profile: str = "multi_way") -> str:
    """Compact multi-way table: high-importance scientific fields (median-first)."""
    from .metrics_catalog import MULTI_WAY_SUMMARY_FIELDS, filter_field_ids, load_metrics_config

    if not stats:
        return ""
    cfg = load_metrics_config()
    field_ids = [f[0] for f in MULTI_WAY_SUMMARY_FIELDS]
    keep = set(filter_field_ids(field_ids, profile=profile, metrics_cfg=cfg))
    cols = [c for c in MULTI_WAY_SUMMARY_FIELDS if c[0] in keep]
    if not cols:
        return ""

    # One row per serializer: prefer bytes mode, average medians across fixtures if needed
    by_ser: Dict[str, List[Dict]] = {}
    for e in stats.values():
        if not isinstance(e, dict):
            continue
        by_ser.setdefault(str(e.get("serializer") or ""), []).append(e)

    # Rank by total_median_ns (mean of medians across entries) ascending
    def rank_key(ser: str) -> float:
        entries = by_ser[ser]
        vals = [float(e.get("total_median_ns") or e.get("avg_time_total_ns") or 1e300) for e in entries]
        return sum(vals) / max(len(vals), 1)

    serializers = sorted(by_ser.keys(), key=rank_key)
    if not serializers:
        return ""

    lines = [
        f"### {title}: scientific summary (multi-way, important metrics)",
        "",
        "Default multi-serializer view shows **high-importance** metrics only "
        "([METRICS.md](../analysis/METRICS.md)). "
        "**Primary rank:** median total latency (lower is better). "
        "Pairwise / version A/B reports use the full metric set. "
        "Latency cells are **µs** (analysis storage remains ns).",
        "",
    ]
    headers = ["serializer"] + [c[1] for c in cols]
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "---|" * len(headers))

    # Best median total for bold
    best_med = min(rank_key(s) for s in serializers) if serializers else None

    for ser in serializers:
        entries = by_ser[ser]
        cells = [ser]
        is_best = best_med is not None and abs(rank_key(ser) - best_med) < 1e-9
        for field_id, _title, is_time, _hib in cols:
            vals = []
            for e in entries:
                v = e.get(field_id)
                if v is None and field_id == "total_median_ns":
                    v = e.get("avg_time_total_ns")
                if v is None:
                    continue
                if isinstance(v, (int, float)) and not isinstance(v, bool):
                    vals.append(float(v))
                elif field_id in ("serializer_version", "effect_vs_fastest_cliffs_label"):
                    # take first non-empty string
                    if str(v).strip():
                        vals.append(str(v).strip())  # type: ignore[arg-type]
                        break
            if not vals:
                cells.append("-")
                continue
            if field_id in ("serializer_version", "effect_vs_fastest_cliffs_label"):
                cells.append(str(vals[0]))
                continue
            if field_id == "runs":
                cells.append(str(int(sum(vals))))
                continue
            num = sum(vals) / len(vals)
            if is_time:
                text = f"{num / 1000.0:.3g}"  # ns → µs
            elif field_id == "avg_ops_per_sec":
                text = f"{num:.3g}"
            elif field_id == "mean_fidelity":
                text = f"{num:.2f}"
            elif field_id == "median_size_bytes":
                text = f"{num:.4g}"
            else:
                text = f"{num:.4g}"
            if is_best and field_id == "total_median_ns":
                text = f"**{text}**"
            cells.append(text)
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    return "\n".join(lines)


def generate_language_results_pages(
    multi_lang_stats: Optional[Dict],
    violin_images: Optional[Dict[str, str]],
    docs_root: str,
    plot_rel_from_lang: str = "../analysis/plots/violin",
    lang_sources: Optional[Dict[str, str]] = None,
    metrics_profile: str = "multi_way",
) -> List[str]:
    """Write ``docs/<lang>/results.md`` with pivots + violin embeds per language.

    Multi-way pages emphasize **high-importance** metrics (see METRICS.md).
    Important run-config fields from ``*.configs.json`` are published when present.
    """
    by_lang = _stats_by_language(multi_lang_stats)
    violin_images = dict(violin_images or {})
    plot_meta = violin_images.pop("_meta", None) or {}
    lang_sources = lang_sources or {}
    written: List[str] = []

    # Group plot keys by lang_id
    plots_by_lang: Dict[str, List[Tuple[str, str]]] = {}
    for key, fname in sorted(violin_images.items()):
        if key == "_meta" or not isinstance(fname, str):
            continue
        lang_key = None
        dtype = None
        # Longest key first so "javascript" wins over a future "java"
        docs_map = _lang_docs_dir_map()
        for candidate in sorted(docs_map.keys(), key=len, reverse=True):
            if key.startswith(candidate + "_"):
                lang_key = candidate
                dtype = key[len(candidate) + 1 :]
                break
        if lang_key is None:
            continue
        plots_by_lang.setdefault(lang_key, []).append((dtype, fname))

    langs = [l for l in _lang_order_list() if l in by_lang or l in plots_by_lang]
    for extra in sorted(set(by_lang) | set(plots_by_lang)):
        if extra not in langs:
            langs.append(extra)

    for lang_id in langs:
        docs_dir = _lang_docs_dir_map().get(lang_id, lang_id)
        title = _lang_display_map().get(lang_id, lang_id)
        stats = by_lang.get(lang_id) or {}
        out_path = os.path.join(docs_root, docs_dir, "results.md")
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

        src_csv = lang_sources.get(lang_id) or (plot_meta.get(lang_id) or {}).get("source")
        lines = [
            f"# {title} — Benchmark Results",
            "",
            f"**Generated:** {datetime.now().isoformat()}",
            "",
            "Published **local snapshot** (not regenerated by GitHub Actions). "
            "Numbers may differ if you re-run benchmarks on another machine.",
            "",
            f"Serializer inventory and caveats: [{title} overview](index.md). "
            "Methods: [Analysis Methodology](../analysis/ANALYSIS_METHODOLOGY.md). "
            "Metric definitions & importance tiers: [Metrics catalog](../analysis/METRICS.md).",
            "",
        ]

        if stats:
            lines.append("## Pivot tables")
            lines.append("")
            lines.append(
                "Multi-way leaderboards emphasize **high-importance** metrics "
                "(configurable via `metrics.multi_way` in master config). "
                "Harness **modes** (CSV `StringOrStream`): **bytes mode** = in-memory buffer "
                "API; **stream mode** = write/read through a stream-like path. "
                "These names are *not* payload sizes. "
                "In each table, **bold** marks the semantic best value in that column "
                "(lowest time; highest ops/s). Ties are all bolded. "
                "Latency tables are in **microseconds** (µs)."
            )
            lines.append("")
            sci = _scientific_summary_md(
                stats,
                title,
                profile=metrics_profile or "multi_way",
            )
            if sci:
                lines.append(sci)
            lines.append(
                _pivot_table_md(
                    stats,
                    "serializer",
                    "mode",
                    "total_median_ns",
                    f"{title}: Median Total Time (µs) by Serializer and API Mode",
                )
            )
            lines.append(
                _pivot_table_md(
                    stats,
                    "serializer",
                    "mode",
                    "avg_time_total_ns",
                    f"{title}: Mean Total Time (µs) by Serializer and API Mode",
                )
            )
            lines.append(
                _pivot_table_md(
                    stats,
                    "serializer",
                    "test_data",
                    "avg_ops_per_sec",
                    f"{title}: Ops/Sec (from mean) by Serializer and Data Type",
                )
            )
            cat_md = _category_pivot_md(
                stats,
                lang_id,
                f"{title}: within-category ranking (bytes mode only)",
            )
            if cat_md:
                lines.append(cat_md)
            if lang_id == "rust":
                lines.append("### Fidelity notes (Rust)")
                lines.append("")
                lines.append(
                    "- **prost** maps ISO timestamps through millisecond integers; "
                    "harness fidelity allows date-string drift on Person/Simple/Telemetry/EDI."
                )
                lines.append(
                    "- **rkyv** timed deserialize **materializes** owned values for comparison; "
                    "pure `access` (zero-copy) would be faster and is documented on the overview."
                )
                lines.append(
                    "- **simd-json** serialize uses `serde_json` (crate optimizes parse)."
                )
                lines.append("")
        else:
            lines.append("*No statistics for this language in the current snapshot.*")
            lines.append("")

        items = plots_by_lang.get(lang_id) or []
        if items:
            lines.append("## Violin plots")
            lines.append("")
            lines.append(
                "Density of serialize / deserialize timings (µs; log scale when medians span ≥5×). "
                "**Each plot shows only the top 5 serializers by mean total time** for that fixture "
                "(same rule for every language). Full rankings are in the pivot tables above. "
                "Provenance (fixture, CSV path, modes, *n*) is printed on each image."
            )
            lines.append("")
            for dtype, fname in items:
                lines.append(f"### {dtype}")
                lines.append("")
                lines.append(f"![{dtype}]({plot_rel_from_lang}/{fname}){{ width=\"80%\" }}")
                lines.append("")
        else:
            lines.append("*No violin plots for this language in the current snapshot.*")
            lines.append("")

        lines.append("## Regenerate")
        lines.append("")
        lines.append(
            "Published snapshots are produced **locally** (not by GitHub Actions). "
            "After running benchmarks (each run creates a timestamped `YYYY-MM-DD-HHMMSS.csv`):"
        )
        lines.append("")
        lines.append("```bash")
        lines.append("analyze-benchmarks              # all languages")
        lines.append(f"analyze-benchmarks -l {lang_id}   # this language only")
        lines.append("```")
        lines.append("")
        lines.append(
            "That refreshes this language's results tables and violin plots under "
            "`docs/analysis/plots/violin/`. The hub "
            "[Benchmark Results](../analysis/BENCHMARK_SUMMARY.md) is a **static** index "
            "and is not rewritten. Commit the updated `results.md` / plot paths as needed."
        )
        lines.append("")
        # Collapsed at end: title always visible, body hidden by default (Material ??? details).
        lines.append(
            _config_section_md(lang_id, src_csv if isinstance(src_csv, str) else None)
        )

        with open(out_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        written.append(out_path)
        print(f"Language results written to: {out_path}")

    return written


def _lang_file_key(lang_id: str, display: str) -> str:
    """Stable key used in plots/violin/<key>_<TestData>.png filenames."""
    if lang_id:
        return lang_id.lower().replace("#", "sharp")
    return display.lower().replace("#", "sharp").replace(" ", "_")


def generate_violin_plots(
    output_dir: str,
    multi_lang_records: Optional[Dict] = None,
    lang_sources: Optional[Dict[str, str]] = None,
    *,
    stats_config: Optional[Dict] = None,
    pre_sanitized: bool = False,
    **_kwargs,
) -> Dict[str, str]:
    """Generate violin plot images for all languages with records.

    ``multi_lang_records`` maps lang_id -> list of row dicts.
    ``lang_sources`` optional map lang_id -> CSV path used for those records
    (embedded on the PNG for result↔plot mapping).

    When ``pre_sanitized`` is True, records are assumed to already have been
    processed by :func:`prepare_analysis_records` (same population as tables).

    Returns a dict mapping ``{lang_key}_{TestDataName}`` to image filenames.
    """
    os.makedirs(output_dir, exist_ok=True)
    lang_sources = lang_sources or {}

    by_lang: Dict[str, List[Dict]] = {}
    if multi_lang_records:
        for k, recs in multi_lang_records.items():
            if recs:
                by_lang[str(k).lower()] = list(recs)

    # Stable ordering for docs / reports (prefer master config order).
    order = _lang_order_list()
    lang_ids = [lid for lid in order if lid in by_lang] + sorted(
        lid for lid in by_lang if lid not in order
    )

    violin_images: Dict[str, str] = {}
    # lang_id -> {fixture -> plot filename} plus source path for results.md
    plot_meta: Dict[str, Dict] = {}

    for lang_id in lang_ids:
        records = by_lang[lang_id]
        display = _lang_display_map().get(lang_id, lang_id)
        melted = _records_to_melted_df(
            records,
            display,
            stats_config=stats_config,
            pre_sanitized=pre_sanitized,
            language_hint=lang_id,
        )
        if melted.empty:
            continue
        # Same top-N for csharp, python, rust, c, javascript, go, …
        top_n = VIOLIN_TOP_N_SERIALIZERS
        file_key = _lang_file_key(lang_id, display)
        src = lang_sources.get(lang_id) or lang_sources.get(file_key)
        if src:
            # Prefer path relative to repo if under logs/
            src_disp = src.replace("\\", "/")
            if "/logs/" in src_disp:
                src_disp = "logs/" + src_disp.split("/logs/", 1)[1]
            data_source = src_disp
        else:
            data_source = f"logs/{lang_id}/benchmark-log.csv"
        plot_meta[lang_id] = {"source": data_source, "files": {}}
        for dtype in sorted(melted["TestDataName"].unique()):
            img_name = _generate_violin_plot(
                melted,
                dtype,
                output_dir,
                language=display,
                lang_id=file_key,
                top_n=top_n,
                data_source=data_source,
            )
            if img_name:
                violin_images[f"{file_key}_{dtype}"] = img_name
                plot_meta[lang_id]["files"][dtype] = img_name

    generated = list(violin_images.values())
    if generated:
        print(f"Generated {len(generated)} violin plots in: {output_dir}")
    # Attach meta for callers (results pages) without breaking dict return type
    violin_images["_meta"] = plot_meta  # type: ignore[assignment]
    return violin_images


