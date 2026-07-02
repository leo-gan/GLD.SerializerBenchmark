"""Report generation (Markdown and HTML)."""

import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns

from .stats import normalize_to_nanoseconds


def _records_to_melted_df(records: List[Dict], language: str) -> pd.DataFrame:
    """Convert raw records to a melted dataframe for violin plots.

    Uses the exact same time normalization as the stats pipeline
    (normalize_to_nanoseconds) so violin plots match the summary tables.
    """
    if not records:
        return pd.DataFrame()
    df = pd.DataFrame(records)
    # Preserve per-row Language (from parser/CSV) for correct per-record
    # time normalization. The 'language' param is the display name for titles only.
    if 'Language' not in df.columns:
        df['Language'] = language
    # Melt serialize/deserialize into Operation column
    ser = df[['SerializerName', 'TestDataName', 'StringOrStream', 'TimeSer', 'OpPerSecSer', 'Language']].copy()
    ser['Operation'] = 'Serialize'
    ser = ser.rename(columns={'TimeSer': 'Time_ns', 'OpPerSecSer': 'OpPerSec'})

    deser = df[['SerializerName', 'TestDataName', 'StringOrStream', 'TimeDeser', 'OpPerSecDeser', 'Language']].copy()
    deser['Operation'] = 'Deserialize'
    deser = deser.rename(columns={'TimeDeser': 'Time_ns', 'OpPerSecDeser': 'OpPerSec'})

    melted = pd.concat([ser, deser], ignore_index=True)
    if melted.empty:
        return melted

    # Use the *same* language-aware normalizer as stats.py for consistency.
    # This fixes the previous mismatch (global median heuristic vs per-lang _detect).
    def _norm_row(row):
        return normalize_to_nanoseconds(float(row['Time_ns']), row.get('Language'))
    melted['Time_ns'] = melted.apply(_norm_row, axis=1)

    # Drop non-positive / absurd tails (e.g. multi-second GC stalls) without
    # the old erroneous "Time_ns < 60000" filter which wiped all real ns timings.
    melted = melted[melted['Time_ns'] > 0]
    if len(melted) >= 10:
        q99 = float(melted['Time_ns'].quantile(0.99))
        if q99 > 0:
            melted = melted[melted['Time_ns'] <= q99 * 10]
    return melted


def _generate_violin_plot(melted_df: pd.DataFrame, data_type: str, output_dir: str,
                          language: str = "", top_n: Optional[int] = None) -> Optional[str]:
    """Generate violin plot for a specific data type, returning relative image path.

    Args:
        melted_df: Melted dataframe with benchmark records
        data_type: Name of the data type to plot
        output_dir: Directory to save the plot image
        language: Language label for the plot title (e.g., "C#", "Python")
        top_n: If specified, only include top N serializers by mean time
    """
    if melted_df.empty or data_type not in melted_df['TestDataName'].values:
        return None

    subset = melted_df[melted_df['TestDataName'] == data_type].copy()
    if subset.empty:
        return None

    # Time_ns is already normalized to nanoseconds in _records_to_melted_df.
    subset['Time_us'] = subset['Time_ns'].astype(float) / 1000.0
    # Timings cannot be negative; drop any bad rows before KDE.
    subset = subset[subset['Time_us'] > 0].copy()
    if subset.empty:
        return None

    # Filter to top N serializers by mean time if requested
    if top_n:
        # Calculate mean time per serializer (using Time_us)
        mean_times = subset.groupby('SerializerName')['Time_us'].mean().sort_values()
        top_serializers = mean_times.head(top_n).index.tolist()
        subset = subset[subset['SerializerName'].isin(top_serializers)].copy()

    # Per-serializer high-end winsorize (p99): one stalled rep must not stretch the KDE.
    def _clip_hi(s: pd.Series) -> pd.Series:
        if len(s) < 4:
            return s
        hi = float(s.quantile(0.99))
        if hi > 0:
            return s.clip(upper=hi)
        return s

    subset['Time_us'] = subset.groupby('SerializerName', group_keys=False)['Time_us'].transform(_clip_hi)
    subset = subset[subset['Time_us'] > 0].copy()
    if subset.empty:
        return None

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
        lang_prefix = f"{language} " if language else ""
        scale_note = " (log µs)" if use_log else ""
        g.fig.suptitle(
            f'{lang_prefix}{data_type} - Top {top_n or "All"} Serializers{scale_note}',
            fontsize=14,
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
            g.set_axis_labels('Time (microseconds)', 'Serializer')
            g.set(xlim=(0, None))

        # Under plots/violin/; no redundant "violin_" prefix in the filename.
        lang_key = language.lower().replace("#", "sharp").replace(" ", "_") if language else "unknown"
        img_path = os.path.join(output_dir, f'{lang_key}_{data_type.replace(" ", "_")}.png')
        plt.savefig(img_path, dpi=150, bbox_inches='tight')
        plt.close(g.fig)
        return os.path.basename(img_path)
    except Exception as e:
        lang_info = f" ({language})" if language else ""
        print(f"Warning: Could not generate violin plot for {data_type}{lang_info}: {e}")
        plt.close('all')
        return None


def _pivot_table_md(stats: Dict, rows_dim: str, cols_dim: str, value_key: str, title: str) -> str:
    """Generate a markdown pivot table from stats dict."""
    lines = [f"\n### {title}\n"]

    # Extract unique row and column values
    row_vals = sorted(set(s[rows_dim] for s in stats.values()))
    col_vals = sorted(set(s[cols_dim] for s in stats.values()))

    if not row_vals or not col_vals:
        lines.append("*No data available*\n")
        return '\n'.join(lines)

    # Header
    header = f"| {rows_dim} | " + " | ".join(col_vals) + " |"
    lines.append(header)
    lines.append("|" + "---|" * (len(col_vals) + 1))

    # Rows
    for rv in row_vals:
        row_cells = [rv]
        for cv in col_vals:
            matching = [s for s in stats.values() if s[rows_dim] == rv and s[cols_dim] == cv]
            if matching:
                val = matching[0][value_key]
                if isinstance(val, float):
                    row_cells.append(f"{val:,.0f}")
                else:
                    row_cells.append(str(val))
            else:
                row_cells.append("-")
        lines.append("| " + " | ".join(row_cells) + " |")

    lines.append("")
    return '\n'.join(lines)



# Display labels, MkDocs docs subdirs, and plot file keys
_LANG_DISPLAY = {
    "csharp": "C#",
    "python": "Python",
    "rust": "Rust",
    "c": "C",
    "javascript": "JavaScript",
}

# lang_id -> docs/<dir>/results.md
_LANG_DOCS_DIR = {
    "csharp": "c-sharp",
    "python": "python",
    "rust": "rust",
    "c": "c",
    "javascript": "javascript",
}

_LANG_ORDER = ["csharp", "python", "rust", "c", "javascript"]


def _normalize_lang_id(lang: str) -> str:
    lang = (lang or "unknown").lower()
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


def _lang_result_links_md(prefix: str = "../") -> List[str]:
    """Markdown bullet links to per-language results pages."""
    lines = []
    for lang_id in _LANG_ORDER:
        docs_dir = _LANG_DOCS_DIR.get(lang_id)
        if not docs_dir:
            continue
        title = _LANG_DISPLAY.get(lang_id, lang_id)
        lines.append(f"- [{title} results]({prefix}{docs_dir}/results.md)")
    return lines


def generate_markdown_summary(
    output_path: str,
    *,
    multi_lang_stats: Optional[Dict] = None,
    multi_lang_records: Optional[Dict] = None,
    **_kwargs,
) -> None:
    """Write a thin index: methodology notes + links to per-language results pages.

    Pivot tables and plots live on ``docs/<lang>/results.md`` (see
    ``generate_language_results_pages``).
    """
    lines = [
        "# Benchmark Results",
        "",
        f"**Generated:** {datetime.now().isoformat()}",
        "",
        "This page is an **index** of published snapshot results. Pivot tables and "
        "violin plots are on each language's **Results** page (generated locally, "
        "not by GitHub Actions). Re-running benchmarks elsewhere may differ — that is OK.",
        "",
        "---",
        "",
        "## Results by language",
        "",
        *(_lang_result_links_md("../")),
        "",
        "Hand-written inventories (what we measure): "
        "[C#](../c-sharp/index.md) · [Python](../python/index.md) · "
        "[Rust](../rust/index.md) · [C](../c/index.md) · [JavaScript](../javascript/index.md).",
        "",
        "Methods: [Analysis Methodology](ANALYSIS_METHODOLOGY.md).",
        "",
        "---",
        "",
        "*Local snapshot — regenerate with* "
        "`analyze-benchmarks --generate-summary --generate-plots`",
        "",
    ]
    _ = (multi_lang_stats, multi_lang_records)  # referenced for completeness

    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))

    print(f"Markdown summary index written to: {output_path}")


def generate_language_results_pages(
    multi_lang_stats: Optional[Dict],
    violin_images: Optional[Dict[str, str]],
    docs_root: str,
    plot_rel_from_lang: str = "../analysis/plots/violin",
) -> List[str]:
    """Write ``docs/<lang>/results.md`` with pivots + violin embeds per language.

    Args:
        multi_lang_stats: Stat groups from analysis (any languages).
        violin_images: Map ``{lang_key}_{TestData}`` -> filename under plots/violin/.
        docs_root: Path to the MkDocs ``docs/`` directory.
        plot_rel_from_lang: Relative path from ``docs/<lang>/`` to plot images.

    Returns:
        List of written file paths.
    """
    by_lang = _stats_by_language(multi_lang_stats)
    violin_images = violin_images or {}
    written: List[str] = []

    # Group plot keys by lang_id
    plots_by_lang: Dict[str, List[Tuple[str, str]]] = {}
    for key, fname in sorted(violin_images.items()):
        lang_key = None
        dtype = None
        # Longest key first so "javascript" wins over a future "java"
        for candidate in sorted(_LANG_DOCS_DIR.keys(), key=len, reverse=True):
            if key.startswith(candidate + "_"):
                lang_key = candidate
                dtype = key[len(candidate) + 1 :]
                break
        if lang_key is None:
            continue
        plots_by_lang.setdefault(lang_key, []).append((dtype, fname))

    langs = [l for l in _LANG_ORDER if l in by_lang or l in plots_by_lang]
    for extra in sorted(set(by_lang) | set(plots_by_lang)):
        if extra not in langs:
            langs.append(extra)

    for lang_id in langs:
        docs_dir = _LANG_DOCS_DIR.get(lang_id, lang_id)
        title = _LANG_DISPLAY.get(lang_id, lang_id)
        stats = by_lang.get(lang_id) or {}
        out_path = os.path.join(docs_root, docs_dir, "results.md")
        os.makedirs(os.path.dirname(out_path), exist_ok=True)

        lines = [
            f"# {title} — Benchmark Results",
            "",
            f"**Generated:** {datetime.now().isoformat()}",
            "",
            "Published **local snapshot** (not regenerated by GitHub Actions). "
            "Numbers may differ if you re-run benchmarks on another machine.",
            "",
            f"Serializer inventory and caveats: [{title} overview](index.md). "
            "Methods: [Analysis Methodology](../analysis/ANALYSIS_METHODOLOGY.md).",
            "",
        ]

        if stats:
            lines.append("## Pivot tables")
            lines.append("")
            lines.append(
                _pivot_table_md(
                    stats,
                    "serializer",
                    "mode",
                    "avg_time_total_ns",
                    f"{title}: Avg Total Time (ns) by Serializer and Mode",
                )
            )
            lines.append(
                _pivot_table_md(
                    stats,
                    "serializer",
                    "test_data",
                    "avg_ops_per_sec",
                    f"{title}: Ops/Sec by Serializer and Data Type",
                )
            )
            sample = next(iter(stats.values()))
            if sample.get("total_ci_low_ns") is not None:
                lines.append(
                    f"### Scientific metrics (sample: {sample.get('serializer')} / "
                    f"{sample.get('test_data')} / {sample.get('mode')})"
                )
                lines.append("")
                lines.append(
                    f"- mean total: {sample.get('total_mean_ns', 0):.0f} ns "
                    f"(95% CI [{sample.get('total_ci_low_ns', 0):.0f}, "
                    f"{sample.get('total_ci_high_ns', 0):.0f}])"
                )
                lines.append(
                    f"- median: {sample.get('total_median_ns', 0):.0f} ns, "
                    f"CV: {sample.get('total_cv', 0):.3f}, "
                    f"vs fastest Cliff's δ: {sample.get('effect_vs_fastest_cliffs_delta', 0):.3f} "
                    f"({sample.get('effect_vs_fastest_cliffs_label', 'n/a')})"
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
                "Density of serialize / deserialize timings (µs; log scale when medians span ≥5×)."
            )
            lines.append("")
            lines.append("| Fixture | Plot |")
            lines.append("|---------|------|")
            for dtype, fname in items:
                img = f'![{dtype}]({plot_rel_from_lang}/{fname}){{ width="50%" }}'
                lines.append(f"| {dtype} | {img} |")
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
        lines.append(
            "analyze-benchmarks --generate-summary --generate-plots"
        )
        lines.append("```")
        lines.append("")
        lines.append(
            "That refreshes this page, other languages' `results.md`, plot images under "
            "`docs/analysis/plots/violin/`, and the [Benchmark Results](../analysis/BENCHMARK_SUMMARY.md) hub. "
            "Commit those paths to update the documentation site."
        )
        lines.append("")

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
    **_kwargs,
) -> Dict[str, str]:
    """Generate violin plot images for all languages with records.

    ``multi_lang_records`` maps lang_id -> list of row dicts.

    Returns a dict mapping ``{lang_key}_{TestDataName}`` to image filenames.
    """
    os.makedirs(output_dir, exist_ok=True)

    by_lang: Dict[str, List[Dict]] = {}
    if multi_lang_records:
        for k, recs in multi_lang_records.items():
            if recs:
                by_lang[str(k).lower()] = list(recs)

    # Stable ordering for docs / reports
    order = ["csharp", "python", "rust", "c", "javascript"]
    lang_ids = [lid for lid in order if lid in by_lang] + sorted(
        lid for lid in by_lang if lid not in order
    )

    violin_images: Dict[str, str] = {}

    for lang_id in lang_ids:
        records = by_lang[lang_id]
        display = _LANG_DISPLAY.get(lang_id, lang_id)
        melted = _records_to_melted_df(records, display)
        if melted.empty:
            continue
        n_sers = int(melted["SerializerName"].nunique())
        # Cap series on crowded languages (historical C# behaviour: top 5)
        top_n = 5 if n_sers > 12 else None
        file_key = _lang_file_key(lang_id, display)
        for dtype in sorted(melted["TestDataName"].unique()):
            img_name = _generate_violin_plot(
                melted, dtype, output_dir, language=display, top_n=top_n
            )
            if img_name:
                violin_images[f"{file_key}_{dtype}"] = img_name

    generated = list(violin_images.values())
    if generated:
        print(f"Generated {len(generated)} violin plots in: {output_dir}")
    return violin_images


