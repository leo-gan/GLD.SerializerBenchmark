"""Report generation (Markdown and HTML)."""

import math
import os
import re
from collections import defaultdict
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

# Machine key: type_id@n=<DataTypeInstanceCount> (filenames / join keys).
_FIXTURE_KEY_RE = re.compile(r"^(.*?)(?:@n=(\d+))+$", re.IGNORECASE)


def _format_fixture_display(label: str) -> str:
    """Decode cryptic ``message@n=100`` keys for titles and table headers.

    Examples:
      ``message@n=1``   → ``Message · 1 instance``
      ``message@n=100`` → ``Message · 100 instances``
      ``document``      → ``Document``
    """
    s = str(label or "").strip()
    if not s:
        return s
    m = _FIXTURE_KEY_RE.match(s)
    if m:
        base = (m.group(1) or "").strip() or s
        try:
            n = int(m.group(2))
        except (TypeError, ValueError):
            n = None
    else:
        base, n = s, None

    # Suite type_ids are lowercase words; legacy fixtures are already Title/Pascal.
    if base and base == base.lower() and re.fullmatch(r"[a-z][a-z0-9_]*", base):
        pretty = base.replace("_", " ").title()
    else:
        pretty = base

    if n is None:
        return pretty
    unit = "instance" if n == 1 else "instances"
    return f"{pretty} · {n} {unit}"


# CSV StringOrStream values → human labels (not "number of bytes")
_MODE_DISPLAY = {
    "bytes": "bytes mode",
    "stream": "stream mode",
    "string": "bytes mode",  # C#/some benchmark runners log "string" for the buffer API
    "buffer": "bytes mode",
}


def _normalize_mode(mode: str) -> str:
    """Canonical benchmark-runner API mode: bytes (in-memory buffer) | stream.

    Aligns with dashboard ``normalizeMode``: CSV may say ``string`` / ``Stream``
    / ``bytes`` / ``buffer`` depending on language benchmark runner.
    """
    key = (mode or "").strip().lower()
    if key in ("bytes", "string", "buffer"):
        return "bytes"
    if key == "stream":
        return "stream"
    return key


def _display_mode(mode: str) -> str:
    """Label benchmark-runner API mode so it is not confused with payload size."""
    key = _normalize_mode(mode)
    return _MODE_DISPLAY.get(key, mode or key)


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


def _format_sig(val: float, *, sig: int = 3) -> str:
    """Format *val* with ~*sig* significant digits for results tables.

    Rules:
    - Never scientific notation (``1.17e+03`` → bad; use fixed-point).
    - Thousands separators on the integer part: ``1230`` → ``1,230``.
    - Fractional part kept without grouping (``0.581``, ``18.4``).
    """
    try:
        v = float(val)
    except (TypeError, ValueError):
        return str(val)
    if v != v:  # NaN
        return "-"
    if v == 0:
        return "0"

    sign = "-" if v < 0 else ""
    a = abs(v)
    order = int(math.floor(math.log10(a))) if a > 0 else 0
    scale = 10 ** (order - sig + 1)
    # Round to sig significant figures (scale may be < 1 for small values).
    rounded = round(a / scale) * scale if scale != 0 else a
    # Rounding can bump order (e.g. 999 → 1000 with 3 sig).
    if rounded > 0:
        order = int(math.floor(math.log10(rounded)))
    decimals = max(0, sig - 1 - order)
    if decimals == 0:
        text = f"{int(round(rounded)):,}"
    else:
        # Comma on integer part only; strip trailing fractional zeros.
        text = f"{rounded:,.{decimals}f}".rstrip("0").rstrip(".")
    return sign + (text if text else "0")


def _format_in_unit(
    val: float,
    divisor: float,
    unit: str,
    *,
    sig: int = 2,
    bold: bool = False,
) -> str:
    """Format ``val`` in a fixed column unit with *sig* significant digits."""
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
        text = _format_sig(scaled, sig=sig)
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


def _pivot_table_md(
    stats: Dict,
    rows_dim: str,
    cols_dim: str,
    value_key: str,
    title: str,
    *,
    include_row_average: bool = False,
    prefer_bytes_mode: bool = False,
) -> str:
    """Generate a markdown pivot table from stats dict.

    Semantic best-in-column values are bold (ops/throughput: max; time/size: min).
    Ties are all bolded. Unit scale and best use **displayed** cell values only.

    Latency metrics stored as ``*_ns`` are shown in **microseconds** (÷1000) as
    plain numbers (no K/M suffixes), so ~5400 ns appears as ``5.4`` not ``5.4K``.

    When ``include_row_average`` is true, insert an **Average** column after the
    row label. For Ops/s this matches the Dashboard ``all@all`` rule: unweighted
    mean of the per-cell values (each type × n column) for that serializer.
    """
    lines = [f"\n### {title}\n"]

    # Extract unique row and column values (case-insensitive name order for serializers)
    def _sort_dim(vals, dim: str):
        if dim == "serializer":
            return sorted(vals, key=lambda x: str(x).casefold())
        return sorted(vals)

    row_vals = _sort_dim(set(s[rows_dim] for s in stats.values()), rows_dim)
    col_vals = _sort_dim(set(s[cols_dim] for s in stats.values()), cols_dim)

    if not row_vals or not col_vals:
        lines.append("*No data available*\n")
        return '\n'.join(lines)

    # When columns are runner I/O modes, spell out "bytes mode" / "stream mode"
    def _col_label(cv: str, unit: str = "") -> str:
        base = _display_mode(cv) if cols_dim == "mode" else cv
        if unit:
            return f"{base} ({unit})"
        return base

    def _pick_entry(matching: List[Dict]) -> Optional[Dict]:
        if not matching:
            return None
        if not prefer_bytes_mode:
            return matching[0]
        bytes_m = [
            s
            for s in matching
            if _normalize_mode(str(s.get("mode") or s.get("StringOrStream") or ""))
            == "bytes"
        ]
        return bytes_m[0] if bytes_m else matching[0]

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
            entry = _pick_entry(matching)
            if not entry:
                cell[(rv, cv)] = None
                continue
            val = entry.get(value_key)
            if isinstance(val, (int, float)) and not isinstance(val, bool) and val == val:
                cell[(rv, cv)] = float(val) / display_scale
            else:
                cell[(rv, cv)] = None

    # all@all-style row average: mean of per-fixture cell values (type × n).
    row_avg: Dict[str, Optional[float]] = {}
    if include_row_average:
        for rv in row_vals:
            vals = [
                cell[(rv, cv)]
                for cv in col_vals
                if cell[(rv, cv)] is not None
            ]
            row_avg[rv] = (sum(vals) / len(vals)) if vals else None

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

    avg_unit = (1.0, "")
    avg_best: Optional[float] = None
    if include_row_average:
        avg_vals = [v for v in row_avg.values() if v is not None]
        if to_us:
            avg_unit = (1.0, "")
        else:
            avg_unit = _pick_column_unit(avg_vals)
        avg_best = _column_best(avg_vals, higher_is_better=higher)

    # Header (unit in column title when scaled, unless value_key is avg_ops_per_sec)
    show_unit = (value_key != "avg_ops_per_sec")
    header_parts = [rows_dim]
    if include_row_average:
        u = avg_unit[1] if show_unit else ""
        header_parts.append(f"Average ({u})" if u else "Average")
    header_parts.extend(
        _col_label(cv, col_units[cv][1] if show_unit else "") for cv in col_vals
    )
    lines.append("| " + " | ".join(header_parts) + " |")
    lines.append("|" + "---|" * len(header_parts))

    # Rows — all cells in a column share that column's unit; best is bold
    for rv in row_vals:
        if rows_dim == "serializer":
            version = ""
            matching_entries = [s for s in stats.values() if s[rows_dim] == rv]
            for s in matching_entries:
                v = s.get("serializer_version")
                if v:
                    version = str(v).strip()
                    break
            display_name = f"{rv}:{version}" if version else rv
        else:
            display_name = rv
        row_cells = [display_name]
        if include_row_average:
            av = row_avg.get(rv)
            if av is None:
                row_cells.append("-")
            else:
                div, unit = avg_unit
                is_best = avg_best is not None and av == avg_best
                row_cells.append(_format_in_unit(av, div, unit, bold=is_best))
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
            "cpp": "C++",
            "java": "Java",
            "kotlin": "Kotlin",
            "swift": "Swift",
            "mojo": "Mojo",
            "fortran": "Fortran",
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
            "cpp": "cpp",
            "java": "java",
            "kotlin": "kotlin",
            "swift": "swift",
            "mojo": "mojo",
            "fortran": "fortran",
        }


def _lang_order_list() -> list:
    try:
        from .config_loader import lang_order

        return list(lang_order())
    except Exception:
        return ["csharp", "python", "rust", "c", "javascript", "go", "java", "kotlin", "php", "cpp", "swift", "zig", "mojo", "fortran"]


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
        mode = _normalize_mode(e.get("mode") or e.get("StringOrStream") or "")
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
        "Compare serializers **inside the same family** only (for example JSON with JSON, "
        "not JSON with a zero-copy schema codec). "
        "Each value is mean serialize+deserialize **operations per second** across data types, "
        "using **bytes mode** only (the in-memory buffer API — not “payload size in bytes”). "
        "Higher is better. Stream mode is left out of this ranking. "
        "Rows are sorted by serializer name; **bold** marks the highest ops/s in the column.",
        "",
    ]
    for cat in sorted(by_cat.keys()):
        # average ops per serializer across fixtures; rows sorted by name
        acc: Dict[str, List[float]] = defaultdict(list)
        for ser, ops in by_cat[cat]:
            acc[ser].append(ops)
        named = sorted(
            ((s, sum(v) / len(v)) for s, v in acc.items()),
            key=lambda x: str(x[0]).casefold(),
        )
        col_vals = [ops for _, ops in named]
        div, unit = _pick_column_unit(col_vals)
        best = _column_best(col_vals, higher_is_better=True)
        unit_label = f" ({unit})" if unit else ""
        lines.append(f"#### {cat}")
        lines.append("")
        lines.append(f"| serializer | mean ops/s (bytes mode){unit_label} |")
        lines.append("|---|---:|")
        for ser, mean_ops in named:
            # Find the version of this serializer in entries
            version = ""
            for e in entries:
                if (e.get("serializer") or e.get("SerializerName")) == ser:
                    v = e.get("serializer_version")
                    if v:
                        version = str(v).strip()
                        break
            display_name = f"{ser}:{version}" if version else ser
            is_best = best is not None and mean_ops == best
            lines.append(
                f"| {display_name} | {_format_in_unit(mean_ops, div, unit, bold=is_best)} |"
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
        "These fields come from the run sidecar next to the CSV "
        "(`*.configs.json`, or older `*.environment.json` files). "
        "They describe the machine and the run setup, not the timing formulas. "
        "For metric definitions, see the [Metrics catalog](../analysis/METRICS.md). "
        "Optional blocks (`dataset`, `serializers`) appear only when the benchmark runner recorded them.",
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
            "(re-run the benchmark runner with environment capture to populate).*"
        )
    if doc:
        ds = doc.get("dataset") if isinstance(doc.get("dataset"), dict) else {}
        if ds.get("fixtures"):
            names = [f.get("name") for f in ds["fixtures"] if isinstance(f, dict) and f.get("name")]
            if names:
                body.append(
                    f"- **Data types (config):** {', '.join(str(n) for n in names)}"
                )
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


def _sample_filter_banner_md() -> str:
    """Explain *how outliers were filtered* for Markdown results tables.

    This is the same choice as the Dashboard toolbar **Samples** control
    (IQR / all trials / winsorize) — not a “number of samples” column.
    Language Results use the analysis config’s single default policy.
    """
    exclude_warmup = True
    method = "iqr"
    iqr_k = 1.5
    try:
        from .config_loader import load_master_config

        stats_cfg = (load_master_config().get("statistics") or {})
        exclude_warmup = bool(stats_cfg.get("exclude_warmup", True))
        method = str(stats_cfg.get("outlier_method") or "iqr").strip().lower()
        iqr_k = float(stats_cfg.get("iqr_k", 1.5))
    except Exception:
        pass

    warmup_bit = (
        "First the first timed repetition is dropped as warmup "
        "(`RepetitionIndex == 0`). Then "
        if exclude_warmup
        else "Warmup rows are kept. Then "
    )
    if method == "iqr":
        policy_name = f"IQR k={iqr_k:g}"
        dash_label = f"IQR k={iqr_k:g}" + (" (default)" if abs(iqr_k - 1.5) < 1e-9 else "")
        dash_id = "iqr_1.5" if abs(iqr_k - 1.5) < 1e-9 else f"iqr_{iqr_k:g}"
        detail = (
            f"outliers are removed with **paired Tukey {policy_name}** — the same "
            f"rule as the Dashboard **Samples** menu item **“{dash_label}”** "
            f"(`{dash_id}`). A whole trial is dropped if serialize, deserialize, or "
            "total time falls outside the fences."
        )
    elif method == "winsorize":
        detail = (
            "extremes are **winsorized at the 5th/95th percentile** — the same rule "
            "as Dashboard **Samples → Winsorize 5–95%** (`winsorize_5_95`). "
            "Values are clipped; trials are not dropped."
        )
    elif method in ("none", "off", "disabled"):
        detail = (
            "no outlier filter is applied after warmup — the same as Dashboard "
            "**Samples → All trials** (`all`)."
        )
    else:
        detail = (
            f"outlier handling is **{method}** "
            "(see analysis config `statistics.outlier_method`)."
        )

    return (
        f"> **How these numbers were filtered (Dashboard “Samples”):** {warmup_bit}"
        f"{detail} "
        "Raw CSVs still store every trial. "
        "On the Dashboard you can switch among four **Samples** policies without "
        "re-running the benchmark; this Results page is the **default policy only**. "
        "Details: [Analysis methodology — outlier filtering]"
        "(../analysis/ANALYSIS_METHODOLOGY.md#outlier-filtering) · "
        "[Dashboard filter policies]"
        "(../analysis/ANALYSIS_METHODOLOGY.md#dashboard-filter-policies-multi-aggregation-export)."
    )


def _scientific_summary_md(stats: Dict, profile: str = "multi_way") -> str:
    """Compact multi-way table: high-importance scientific fields (median-first)."""
    from .metrics_catalog import MULTI_WAY_SUMMARY_FIELDS, filter_field_ids, load_metrics_config

    if not stats:
        return ""
    cfg = load_metrics_config()
    field_ids = [f[0] for f in MULTI_WAY_SUMMARY_FIELDS]
    keep = set(filter_field_ids(field_ids, profile=profile, metrics_cfg=cfg))
    cols = [
        c
        for c in MULTI_WAY_SUMMARY_FIELDS
        if c[0] in keep
        and c[0] not in ("serializer_version", "mean_fidelity", "runs")
    ]
    if not cols:
        return ""

    # One row per serializer: prefer bytes mode, average medians across fixtures if needed
    by_ser: Dict[str, List[Dict]] = {}
    for e in stats.values():
        if not isinstance(e, dict):
            continue
        by_ser.setdefault(str(e.get("serializer") or ""), []).append(e)

    # Rows sorted by serializer name (stable lookup); bold still marks best-in-column.
    serializers = sorted(by_ser.keys(), key=lambda s: s.casefold())
    if not serializers:
        return ""

    lines = [
        "### Summary",
        "",
        "One row per serializer (averaged across data types; bytes mode preferred when both exist). "
        "Only **high-importance** columns appear here by default "
        "([Metrics catalog](../analysis/METRICS.md)). "
        "Times are **µs**. **Bold** = best in that column.",
        "",
    ]
    headers = ["serializer"] + [c[1] for c in cols]
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "---|" * len(headers))

    # 1. Resolve one numeric value per displayed cell first — so we can determine the best value per column
    cell_vals: Dict[Tuple[str, str], float] = {}
    for ser in serializers:
        entries = by_ser[ser]
        for field_id, _title, is_time, hib in cols:
            if field_id in ("serializer_version", "effect_vs_fastest_cliffs_label"):
                continue
            vals = []
            for e in entries:
                v = e.get(field_id)
                if v is None and field_id == "total_median_ns":
                    v = e.get("avg_time_total_ns")
                if v is None:
                    continue
                if isinstance(v, (int, float)) and not isinstance(v, bool):
                    vals.append(float(v))
            if not vals:
                continue
            if field_id == "runs":
                cell_vals[(ser, field_id)] = sum(vals)
            else:
                cell_vals[(ser, field_id)] = sum(vals) / len(vals)

    # 2. Find best value for each column across all serializers
    col_bests: Dict[str, float] = {}
    for field_id, _title, is_time, hib in cols:
        if hib is None:
            continue
        vals_in_col = [cell_vals[(ser, field_id)] for ser in serializers if (ser, field_id) in cell_vals]
        if vals_in_col:
            col_bests[field_id] = max(vals_in_col) if hib else min(vals_in_col)

    # Shared K/M scale per column (same rule as ops/s and pivot tables)
    col_units: Dict[str, tuple] = {}
    for field_id in ("avg_ops_per_sec", "median_size_bytes"):
        vals_in_col = [cell_vals[(ser, field_id)] for ser in serializers if (ser, field_id) in cell_vals]
        if vals_in_col:
            col_units[field_id] = _pick_column_unit(vals_in_col)

    # 3. Render rows
    for ser in serializers:
        entries = by_ser[ser]
        version = ""
        for e in entries:
            v = e.get("serializer_version")
            if v:
                version = str(v).strip()
                break
        display_name = f"{ser}:{version}" if version else ser
        cells = [display_name]
        for field_id, _title, is_time, hib in cols:
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
                    if str(v).strip():
                        vals.append(str(v).strip())  # type: ignore[arg-type]
                        break
            if not vals:
                cells.append("-")
                continue
            if field_id in ("serializer_version", "effect_vs_fastest_cliffs_label"):
                cells.append(str(vals[0]))
                continue
            
            num = cell_vals.get((ser, field_id))
            if num is None:
                cells.append("-")
                continue
                
            if field_id == "runs":
                text = str(int(num))
            elif is_time:
                # ns → µs; fixed-point only (never 1.17e+03)
                text = _format_sig(num / 1000.0, sig=3)
            elif field_id in ("avg_ops_per_sec", "median_size_bytes"):
                # 3 significant digits + shared column K/M (thousands / millions)
                div, unit = col_units.get(field_id) or _pick_column_unit([num])
                text = _format_in_unit(num, div, unit, sig=3)
            elif field_id == "mean_fidelity":
                text = f"{num:.2f}"
            else:
                text = _format_sig(num, sig=4)
                
            best_val = col_bests.get(field_id)
            is_best_col = (best_val is not None and abs(num - best_val) < 1e-9)
            if is_best_col:
                text = f"**{text}**"
            cells.append(text)
        lines.append("| " + " | ".join(cells) + " |")
    lines.append("")
    return "\n".join(lines)


def _total_time_pivot_table_md(stats: Dict) -> str:
    """Generate a combined Mean/Median Total Time pivot table."""
    # Rows sorted by serializer name (stable lookup); bold still marks best-in-column.
    by_ser: Dict[str, List[Dict]] = {}
    for e in stats.values():
        if not isinstance(e, dict):
            continue
        by_ser.setdefault(str(e.get("serializer") or ""), []).append(e)

    serializers = sorted(by_ser.keys(), key=lambda s: s.casefold())
    if not serializers:
        return ""

    # Values are ns→µs in _get_val; units live on the column headers only.
    lines = ["\n### Total Time\n"]
    
    headers = [
        "serializer",
        "bytes mode/mean (µs)",
        "bytes mode/median (µs)",
        "stream mode/mean (µs)",
        "stream mode/median (µs)",
    ]
    lines.append("| " + " | ".join(headers) + " |")
    lines.append("|" + "---|" * len(headers))

    # Collect values to find min (best) per column
    col_vals = {
        "bytes_mean": [],
        "bytes_median": [],
        "stream_mean": [],
        "stream_median": []
    }
    
    def _get_val(entry, key):
        if not entry:
            return None
        v = entry.get(key)
        if v is None and key == "total_median_ns":
            v = entry.get("avg_time_total_ns")
        if isinstance(v, (int, float)) and not isinstance(v, bool) and v == v:
            return float(v) / 1000.0
        return None

    def _entry_for_mode(entries, want: str):
        return next(
            (e for e in entries if _normalize_mode(str(e.get("mode") or "")) == want),
            None,
        )

    for ser in serializers:
        entries = by_ser[ser]
        bytes_entry = _entry_for_mode(entries, "bytes")
        stream_entry = _entry_for_mode(entries, "stream")

        bm_val = _get_val(bytes_entry, "avg_time_total_ns")
        bmed_val = _get_val(bytes_entry, "total_median_ns")
        sm_val = _get_val(stream_entry, "avg_time_total_ns")
        smed_val = _get_val(stream_entry, "total_median_ns")

        if bm_val is not None: col_vals["bytes_mean"].append(bm_val)
        if bmed_val is not None: col_vals["bytes_median"].append(bmed_val)
        if sm_val is not None: col_vals["stream_mean"].append(sm_val)
        if smed_val is not None: col_vals["stream_median"].append(smed_val)

    bests = {
        "bytes_mean": min(col_vals["bytes_mean"]) if col_vals["bytes_mean"] else None,
        "bytes_median": min(col_vals["bytes_median"]) if col_vals["bytes_median"] else None,
        "stream_mean": min(col_vals["stream_mean"]) if col_vals["stream_mean"] else None,
        "stream_median": min(col_vals["stream_median"]) if col_vals["stream_median"] else None
    }

    for ser in serializers:
        entries = by_ser[ser]
        version = ""
        for e in entries:
            v = e.get("serializer_version")
            if v:
                version = str(v).strip()
                break
        display_name = f"{ser}:{version}" if version else ser

        bytes_entry = _entry_for_mode(entries, "bytes")
        stream_entry = _entry_for_mode(entries, "stream")

        bm_val = _get_val(bytes_entry, "avg_time_total_ns")
        bmed_val = _get_val(bytes_entry, "total_median_ns")
        sm_val = _get_val(stream_entry, "avg_time_total_ns")
        smed_val = _get_val(stream_entry, "total_median_ns")

        row_cells = [display_name]
        for val, key in [(bm_val, "bytes_mean"), (bmed_val, "bytes_median"), (sm_val, "stream_mean"), (smed_val, "stream_median")]:
            if val is None:
                row_cells.append("-")
            else:
                is_best = bests[key] is not None and abs(val - bests[key]) < 1e-9
                text = _format_sig(val, sig=3)  # already µs; fixed-point only
                if is_best:
                    text = f"**{text}**"
                row_cells.append(text)
        
        lines.append("| " + " | ".join(row_cells) + " |")

    lines.append("")
    return "\n".join(lines)


def generate_language_results_pages(
    multi_lang_stats: Optional[Dict],
    docs_root: str,
    lang_sources: Optional[Dict[str, str]] = None,
    metrics_profile: str = "multi_way",
) -> List[str]:
    """Write ``<docs_root>/<docs_dir>/results.md`` (unpublished language report).

    ``docs_root`` is typically ``reports/`` so C# lands at
    ``reports/c-sharp/results.md`` via ``_lang_docs_dir_map``.

    Multi-way pages emphasize **high-importance** metrics (see METRICS.md).
    Important run-config fields from ``*.configs.json`` are published when present.
    """
    by_lang = _stats_by_language(multi_lang_stats)
    lang_sources = lang_sources or {}
    written: List[str] = []

    langs = [l for l in _lang_order_list() if l in by_lang]
    for extra in sorted(by_lang):
        if extra not in langs:
            langs.append(extra)

    for lang_id in langs:
        docs_dir = _lang_docs_dir_map().get(lang_id, lang_id)
        title = _lang_display_map().get(lang_id, lang_id)
        stats = by_lang.get(lang_id) or {}
        out_path = os.path.join(docs_root, docs_dir, "results.md")
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

        src_csv = lang_sources.get(lang_id)
        lines = [
            f"# {title} — Benchmark Results",
            "",
            f"**Generated:** {datetime.now().isoformat()}",
            "",
            f"This page is a **snapshot of measured numbers** for {title} on **one machine, "
            "one session** (claim level **L1**). "
            "Continuous integration deploys the documentation site; it does **not** re-run "
            "analysis when docs are published. Re-running benchmarks on another computer "
            "will usually change the numbers a little. "
            "Stronger multi-session / multi-machine claims need more evidence — see "
            "[Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md).",
            "",
            f"| Topic | Where to read |",
            f"|-------|---------------|",
            f"| Which libraries we measure, and caveats | [{title} overview](index.md) |",
            f"| I/O modes and run modes | [Modes](../analysis/modes.md) |",
            f"| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |",
            f"| What each metric means | [Metrics catalog](../analysis/METRICS.md) |",
            f"| What you may claim (L1/L2/L3) | [Claims and replication](../analysis/CLAIMS_AND_REPLICATION.md) |",
            f"| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |",
            "",
            "## How to read these tables",
            "",
            "Compare serializers **inside this language**. Prefer the same "
            "[family](../analysis/families.md) "
            "(for example JSON with JSON) and the same "
            "[I/O mode](../analysis/modes.md) "
            "so the comparison stays fair.",
            "",
            "| Term | Meaning |",
            "|------|---------|",
            "| **data type** | Sample shape: `message`, `document`, `telemetry`, `strings`, `event`, "
            "`table`, `table_project`, `nested_table`, or `signal` "
            "(CSV `TestDataName`; older text may say “fixture”). "
            "The last four are on the columnar run config. |",
            "| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer). "
            "See [Modes](../analysis/modes.md). |",
            "| **stream mode** | Stream-style API (write/read through a stream). "
            "May be native or adapted — see [Modes](../analysis/modes.md). |",
            "| **µs** | Microseconds (one microsecond = 1000 nanoseconds). Tables show µs; raw CSVs store nanoseconds. |",
            "| **Ops/s** | Operations per second from mean total time — higher is faster |",
            "| **Bold** | Best value in that column (lowest time/size; highest ops/s). Ties are all bolded. |",
            "",
            "Rows are sorted by **serializer name** (easy lookup), not by rank. "
            "Batch workloads appear as **Data type · N instances** "
            "(for example Message · 100 instances). "
            "Default multi-serializer tables show **high-importance** metrics only; "
            "pairwise / version A/B reports can show the full set "
            "([Metrics](../analysis/METRICS.md)).",
            "",
        ]

        # Outlier / aggregation policy = Dashboard "Samples" control (not a count column).
        lines.append(_sample_filter_banner_md())
        lines.append("")

        # Exploratory ranking banner (multi-way effect-vs-fastest is descriptive)
        lines.append(
            "> **Exploratory ranks:** effect sizes vs the fastest codec are **descriptive**. "
            "When we attach Holm-adjusted tests, they only correct for many serializers "
            "**inside one** (data type × batch size × I/O mode) group — not for every "
            "comparison on this page. Prefer pairwise A/B "
            "(`analyze-benchmarks --compare-a … --compare-b …`) for confirmatory checks. "
            "See [Analysis methodology — ranks](../analysis/ANALYSIS_METHODOLOGY.md#exploratory-ranks)."
        )
        lines.append("")

        # Stream honesty banner (native / text_on_stream / adapted)
        try:
            from .stream_honesty import (
                stream_honesty_banner_md,
                summarize_stream_modes_from_stats,
            )

            honesty = summarize_stream_modes_from_stats(stats or {})
            # Prefer raw records if available on plot_meta / lang_sources later;
            # stats entries may lack StreamMode — still emit no-stream banner.
            lines.append(stream_honesty_banner_md(honesty))
            lines.append("")
        except Exception:
            pass

        if stats:
            # Show type@n=<instance_count> so N=1 vs N=100 do not collapse.
            display_stats = {}
            for k, e in (stats.items() if isinstance(stats, dict) else enumerate(stats)):
                if not isinstance(e, dict):
                    display_stats[k] = e
                    continue
                e2 = dict(e)
                n = e2.get("data_type_instance_count")
                base = str(e2.get("test_data") or "")
                if n not in (None, ""):
                    try:
                        e2["test_data"] = _format_fixture_display(f"{base}@n={int(n)}")
                    except (TypeError, ValueError):
                        e2["test_data"] = _format_fixture_display(base)
                else:
                    e2["test_data"] = _format_fixture_display(base)
                display_stats[k] = e2

            lines.append("## Summary tables")
            lines.append("")
            sci = _scientific_summary_md(
                display_stats,
                profile=metrics_profile or "multi_way",
            )
            if sci:
                lines.append(sci)
            lines.append(_total_time_pivot_table_md(display_stats))
            lines.append(
                _pivot_table_md(
                    display_stats,
                    "serializer",
                    "test_data",
                    "avg_ops_per_sec",
                    "Ops/Sec",
                    # Dashboard all@all: unweighted mean of type×n ops/s (bytes preferred).
                    include_row_average=True,
                    prefer_bytes_mode=True,
                )
            )
            cat_md = _category_pivot_md(
                display_stats,
                lang_id,
                "Within-category ranking",
            )
            if cat_md:
                lines.append(cat_md)
            if lang_id == "rust":
                lines.append("### Fidelity notes (Rust)")
                lines.append("")
                lines.append(
                    "These notes explain odd-looking correctness or speed edges on Rust only:"
                )
                lines.append("")
                lines.append(
                    "- **prost** maps ISO timestamps through millisecond integers; "
                    "the benchmark runner allows date-string drift on types that carry timestamps "
                    "(message, event, document, telemetry)."
                )
                lines.append(
                    "- **rkyv** timed deserialize **builds owned values** for comparison; "
                    "a pure zero-copy `access` path would be faster and is documented on the overview."
                )
                lines.append(
                    "- **simd-json** serialize still goes through `serde_json` "
                    "(the crate focuses on parse speed)."
                )
                lines.append("")
        else:
            lines.append("*No statistics for this language in the current snapshot.*")
            lines.append("")

        lines.append("## How to regenerate this page")
        lines.append("")
        lines.append(
            "Snapshots are produced on a developer machine. "
            "After a benchmark-runner run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):"
        )
        lines.append("")
        lines.append("```bash")
        lines.append("analyze-benchmarks              # all languages")
        lines.append(f"analyze-benchmarks -l {lang_id}   # this language only")
        lines.append("```")
        lines.append("")
        lines.append(
            "That writes unpublished tables under `reports/<docs_dir>/results.md`. "
            "The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** "
            "link index and is not rewritten by the CLI. "
            "Do not commit `reports/<docs_dir>/results.md` to the published site."
        )
        lines.append("")
        # Collapsed at end: title always visible, body hidden by default (Material ??? details).
        lines.append(
            _config_section_md(lang_id, src_csv if isinstance(src_csv, str) else None)
        )

        with open(out_path, "w", encoding="utf-8") as f:
            f.write("\n".join(lines))
        written.append(out_path)
        print(f"Unpublished language report written to: {out_path}")

    return written
