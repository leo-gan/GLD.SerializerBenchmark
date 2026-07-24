"""Report generation (Markdown and HTML)."""

import math
import os
import re
from collections import defaultdict
from datetime import datetime
from typing import Any, Dict, List, Optional, Tuple

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from .stats import prepare_analysis_records


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


def _records_to_melted_df(
    records: List[Dict],
    language: str,
    *,
    stats_config: Optional[Dict] = None,
    pre_sanitized: bool = False,
    language_hint: Optional[str] = None,
) -> pd.DataFrame:
    """Convert records to a melted dataframe for latency-distribution plots.

    Uses the unified :func:`prepare_analysis_records` pipeline (warmup drop,
    config time-unit normalization, all-or-nothing paired IQR) so latency
    distributions reflect the *exact* sample population used for summary tables.
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

    # Split violins by instance count (N=1 vs N=100, …).
    if "DataTypeInstanceCount" in df.columns and "TestDataName" in df.columns:
        def _td_label(row: Any) -> str:
            n = row.get("DataTypeInstanceCount")
            base = row.get("TestDataName") or ""
            if n is None or (isinstance(n, float) and pd.isna(n)) or n == "":
                return str(base)
            try:
                return f"{base}@n={int(n)}"
            except (TypeError, ValueError):
                return str(base)

        df["TestDataName"] = df.apply(_td_label, axis=1)

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
    """Generate combined mean-bar + violin figure for one fixture.

    Layout (shared Y = serializer rank, both linear µs from 0):
      left  — horizontal bars at **mean** ser / deser (easy ranking; aligns with ops/s)
      right — split violins of full sample density (spread / shape)

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
    # Always linear X from 0 (no log): absolute µs stay comparable.

    try:
        # Per-serializer mean ser / deser for the bar panel (same family as ops/s).
        means = (
            subset.groupby(["SerializerName", "Operation"], as_index=False)["Time_us"]
            .mean()
            .rename(columns={"Time_us": "Mean_us"})
        )
        hue_order = ["Serialize", "Deserialize"]
        # Stable palette matching historical violin hues (blue / orange).
        palette = {"Serialize": "#4c72b0", "Deserialize": "#dd8452"}

        n_ser = max(len(order), 1)
        fig_h = max(5.5, 0.55 * n_ser + 2.2)
        fig_w = 12.0
        # Left bars (ranking) narrower; right violins (density) wider.
        fig, (ax_bar, ax_vio) = plt.subplots(
            1,
            2,
            sharey=True,
            figsize=(fig_w, fig_h),
            gridspec_kw={"width_ratios": [1.0, 1.55], "wspace": 0.08},
        )

        sns.barplot(
            data=means,
            x="Mean_us",
            y="SerializerName",
            hue="Operation",
            order=order,
            hue_order=hue_order,
            palette=palette,
            ax=ax_bar,
            errorbar=None,
            edgecolor="white",
            linewidth=0.4,
        )
        ax_bar.set_xlabel("Mean time (µs)")
        ax_bar.set_ylabel("Serializer")
        ax_bar.set_title("Mean (rank)", fontsize=11)
        bar_hi = float(means["Mean_us"].max()) if len(means) else 0.0
        ax_bar.set_xlim(0, bar_hi * 1.12 if bar_hi > 0 else None)
        ax_bar.grid(axis="x", linestyle=":", alpha=0.45)
        ax_bar.set_axisbelow(True)
        # Shared legend above both panels (avoids covering the slowest bars).
        handles, labels = ax_bar.get_legend_handles_labels()
        leg = ax_bar.get_legend()
        if leg is not None:
            leg.remove()
        if handles:
            fig.legend(
                handles,
                labels,
                title="Operation",
                loc="upper center",
                bbox_to_anchor=(0.5, 0.98),
                ncol=2,
                frameon=True,
                fontsize=9,
            )

        sns.violinplot(
            data=subset,
            x="Time_us",
            y="SerializerName",
            hue="Operation",
            order=order,
            hue_order=hue_order,
            palette=palette,
            split=True,
            cut=0,
            inner=None,
            ax=ax_vio,
            density_norm="width",
        )
        ax_vio.set_xlabel("Time (µs)")
        ax_vio.set_ylabel("")
        ax_vio.set_title("Distribution (density)", fontsize=11)
        vio_hi = float(subset["Time_us"].max())
        ax_vio.set_xlim(0, vio_hi * 1.05 if vio_hi > 0 else None)
        ax_vio.grid(axis="x", linestyle=":", alpha=0.45)
        ax_vio.set_axisbelow(True)
        # Avoid duplicate legend on the violin panel.
        leg_v = ax_vio.get_legend()
        if leg_v is not None:
            leg_v.remove()

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

        fig.suptitle(
            f"{language or lang_key} · {_format_fixture_display(data_type)}{top_note}",
            fontsize=12,
            y=1.02,
        )

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
        fig.text(
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
        fig.savefig(img_path, dpi=150, bbox_inches="tight")
        plt.close(fig)
        return os.path.basename(img_path)
    except Exception as e:
        lang_info = f" ({language})" if language else ""
        print(f"Warning: Could not generate violin plot for {data_type}{lang_info}: {e}")
        plt.close('all')
        return None


# Latency distributions: always show this many fastest serializers per fixture (all languages).
VIOLIN_TOP_N_SERIALIZERS = 5

# CSV StringOrStream values → human labels (not "number of bytes")
_MODE_DISPLAY = {
    "bytes": "bytes mode",
    "stream": "stream mode",
    "string": "bytes mode",  # C#/some harnesses log "string" for the buffer API
    "buffer": "bytes mode",
}


def _normalize_mode(mode: str) -> str:
    """Canonical harness API mode: bytes (in-memory buffer) | stream.

    Aligns with dashboard ``normalizeMode``: CSV may say ``string`` / ``Stream``
    / ``bytes`` / ``buffer`` depending on language harness.
    """
    key = (mode or "").strip().lower()
    if key in ("bytes", "string", "buffer"):
        return "bytes"
    if key == "stream":
        return "stream"
    return key


def _display_mode(mode: str) -> str:
    """Label harness API mode so it is not confused with payload size."""
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


def _pivot_table_md(stats: Dict, rows_dim: str, cols_dim: str, value_key: str, title: str) -> str:
    """Generate a markdown pivot table from stats dict.

    Semantic best-in-column values are bold (ops/throughput: max; time/size: min).
    Ties are all bolded. Unit scale and best use **displayed** cell values only.

    Latency metrics stored as ``*_ns`` are shown in **microseconds** (÷1000) as
    plain numbers (no K/M suffixes), so ~5400 ns appears as ``5.4`` not ``5.4K``.
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

    # Header (unit in column title when scaled, unless value_key is avg_ops_per_sec)
    show_unit = (value_key != "avg_ops_per_sec")
    header = (
        f"| {rows_dim} | "
        + " | ".join(_col_label(cv, col_units[cv][1] if show_unit else "") for cv in col_vals)
        + " |"
    )
    lines.append(header)
    lines.append("|" + "---|" * (len(col_vals) + 1))

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
        }


def _lang_order_list() -> list:
    try:
        from .config_loader import lang_order

        return list(lang_order())
    except Exception:
        return ["csharp", "python", "rust", "c", "javascript", "go", "java", "cpp"]


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
        "Optional blocks (`dataset`, `serializers`) appear only when the harness recorded them.",
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


def _scientific_summary_md(stats: Dict, profile: str = "multi_way") -> str:
    """Compact multi-way table: high-importance scientific fields (median-first)."""
    from .metrics_catalog import MULTI_WAY_SUMMARY_FIELDS, filter_field_ids, load_metrics_config

    if not stats:
        return ""
    cfg = load_metrics_config()
    field_ids = [f[0] for f in MULTI_WAY_SUMMARY_FIELDS]
    keep = set(filter_field_ids(field_ids, profile=profile, metrics_cfg=cfg))
    cols = [c for c in MULTI_WAY_SUMMARY_FIELDS if c[0] in keep and c[0] != "serializer_version"]
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

    lines = ["\n### Total Time\n"]
    
    headers = [
        "serializer", 
        "bytes mode/mean", 
        "bytes mode/median", 
        "stream mode/mean", 
        "stream mode/median"
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
            f"This page is a **snapshot of measured numbers** for {title} on one machine. "
            "Continuous integration deploys the documentation site; it does **not** re-run "
            "analysis when docs are published. Re-running benchmarks on another computer "
            "will usually change the numbers a little.",
            "",
            f"| Topic | Where to read |",
            f"|-------|---------------|",
            f"| Which libraries we measure, and caveats | [{title} overview](index.md) |",
            f"| How CSVs become these tables | [Analysis methodology](../analysis/ANALYSIS_METHODOLOGY.md) |",
            f"| What each metric means | [Metrics catalog](../analysis/METRICS.md) |",
            f"| All languages’ result links | [Results summary](../analysis/BENCHMARK_SUMMARY.md) |",
            "",
            "## How to read these tables",
            "",
            "Compare serializers **inside this language**. Prefer the same "
            "[category](../analysis/serialization_categories.md) "
            "(for example JSON with JSON) so the comparison stays fair.",
            "",
            "| Term | Meaning |",
            "|------|---------|",
            "| **data type** | Sample shape: `message`, `document`, `telemetry`, `strings`, or `event` "
            "(CSV `TestDataName`; older text may say “fixture”) |",
            "| **bytes mode** | In-memory buffer API (encode to bytes / decode from a buffer) |",
            "| **stream mode** | Stream-style API (write/read through a stream) |",
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
                    "the harness allows date-string drift on types that carry timestamps "
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

        items = plots_by_lang.get(lang_id) or []
        if items:
            lines.append("## Latency distributions")
            lines.append("")
            lines.append(
                "Each figure is a picture of **how long** serialize and deserialize took "
                "across many trials for one **data type** (and batch size):"
            )
            lines.append("")
            lines.append(
                "- **Left — mean bars:** average serialize time and average deserialize time "
                "in microseconds (scale starts at 0)."
            )
            lines.append(
                "- **Right — split violins:** the full distribution of sample times "
                "(thickness shows where trials cluster)."
            )
            lines.append(
                "- **Top 5 only:** charts show the five fastest serializers by mean total time "
                "for that data type so the picture stays readable. Tables above still list everyone."
            )
            lines.append(
                "- Each image also prints the data type, source CSV, modes, and sample size."
            )
            lines.append("")
            for dtype, fname in items:
                pretty = _format_fixture_display(dtype)
                lines.append(f"### {pretty}")
                lines.append("")
                lines.append(f"![{pretty}]({plot_rel_from_lang}/{fname}){{ width=\"80%\" }}")
                lines.append("")
        else:
            lines.append("*No latency distributions for this language in the current snapshot.*")
            lines.append("")

        lines.append("## How to regenerate this page")
        lines.append("")
        lines.append(
            "Snapshots are produced on a developer machine. "
            "After a harness run (each run writes a timestamped `YYYY-MM-DD-HHMMSS.csv`):"
        )
        lines.append("")
        lines.append("```bash")
        lines.append("analyze-benchmarks              # all languages")
        lines.append(f"analyze-benchmarks -l {lang_id}   # this language only")
        lines.append("```")
        lines.append("")
        lines.append(
            "That refreshes this language’s tables and the latency images under "
            "`docs/analysis/plots/violin/`. "
            "The hub [Results summary](../analysis/BENCHMARK_SUMMARY.md) is a **static** "
            "link index and is not rewritten by the CLI. "
            "Commit updated `results.md` and plot files when you want them on the site."
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
        print(f"Generated {len(generated)} latency distributions in: {output_dir}")
    # Attach meta for callers (results pages) without breaking dict return type
    violin_images["_meta"] = plot_meta  # type: ignore[assignment]
    return violin_images


