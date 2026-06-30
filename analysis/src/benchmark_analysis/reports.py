"""Report generation (Markdown and HTML)."""

import base64
import io
import json
import os
from datetime import datetime
from typing import Dict, List, Tuple, Optional

import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import pandas as pd
import seaborn as sns


def _records_to_melted_df(records: List[Dict], language: str) -> pd.DataFrame:
    """Convert raw records to a melted dataframe for violin plots."""
    if not records:
        return pd.DataFrame()
    df = pd.DataFrame(records)
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

    # Normalize to nanoseconds for plotting (legacy C# ticks vs Python/new ns).
    # Heuristic: values > 1e6 are typically ticks (100 ns); multiply by 100.
    t = melted['Time_ns'].astype(float)
    if t.median() > 1_000_000:
        melted['Time_ns'] = t * 100.0
    else:
        melted['Time_ns'] = t

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

    # Filter to top N serializers by mean time if requested
    if top_n:
        # Calculate mean time per serializer (using Time_us)
        mean_times = subset.groupby('SerializerName')['Time_us'].mean().sort_values()
        top_serializers = mean_times.head(top_n).index.tolist()
        subset = subset[subset['SerializerName'].isin(top_serializers)].copy()

    # Use catplot (modern seaborn name for factorplot)
    try:
        g = sns.catplot(
            data=subset,
            x='Time_us',
            y='SerializerName',
            hue='Operation',
            kind='violin',
            split=True,
            inner=None,  # Remove box plot inner lines for cleaner violin appearance
            height=6,
            aspect=1.2,
            legend_out=False,
            order=subset.groupby('SerializerName')['Time_us'].mean().sort_values().index.tolist()
        )
        lang_prefix = f"{language} " if language else ""
        g.fig.suptitle(f'{lang_prefix}{data_type} - Top {top_n or "All"} Serializers',
                       fontsize=14, y=1.02)
        g.set_axis_labels('Time (microseconds)', 'Serializer')

        lang_suffix = f"_{language.lower().replace('#', 'sharp')}" if language else ""
        img_path = os.path.join(output_dir,
                                f'violin{lang_suffix}_{data_type.replace(" ", "_")}.png')
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


def _pivot_table_html(stats: Dict, rows_dim: str, cols_dim: str, value_key: str, title: str) -> str:
    """Generate an HTML pivot table from stats dict."""
    # Extract unique row and column values
    row_vals = sorted(set(s[rows_dim] for s in stats.values()))
    col_vals = sorted(set(s[cols_dim] for s in stats.values()))

    if not row_vals or not col_vals:
        return f'<h4>{title}</h4><p>No data available</p>'

    html = f'<h4>{title}</h4>\n<table class="pivot-table">\n'

    # Header row
    html += '    <thead>\n        <tr>\n'
    html += f'            <th>{rows_dim}</th>\n'
    for cv in col_vals:
        html += f'            <th>{cv}</th>\n'
    html += '        </tr>\n    </thead>\n    <tbody>\n'

    # Data rows
    for rv in row_vals:
        html += '        <tr>\n'
        html += f'            <td><strong>{rv}</strong></td>\n'
        for cv in col_vals:
            matching = [s for s in stats.values() if s[rows_dim] == rv and s[cols_dim] == cv]
            if matching:
                val = matching[0][value_key]
                if isinstance(val, float):
                    cell_val = f"{val:,.0f}"
                else:
                    cell_val = str(val)
            else:
                cell_val = "-"
            html += f'            <td>{cell_val}</td>\n'
        html += '        </tr>\n'

    html += '    </tbody>\n</table>\n'
    return html


def generate_markdown_summary(
    csharp_stats: Dict,
    python_stats: Dict,
    output_path: str,
    csharp_records: Optional[List[Dict]] = None,
    python_records: Optional[List[Dict]] = None,
    multi_lang_stats: Optional[Dict] = None,
    multi_lang_records: Optional[Dict] = None,
    **_kwargs,
) -> None:
    """Generate markdown summary report (C#/Python plus optional multi-language stats)."""
    lines = []
    lines.append("# Serializer Benchmark Summary\n")
    lines.append(f"**Generated:** {datetime.now().isoformat()}\n")
    lines.append("---\n\n")

    lines.append("## Methodology (scientific)\n")
    lines.append("- Warmup exclusion (RepetitionIndex 0)\n")
    lines.append("- IQR outlier filter (Tukey 1.5×IQR, groups ≥10)\n")
    lines.append("- Mean/median/std/MAD/CV + bootstrap 95% CI on mean (2000 resamples)\n")
    lines.append("- Within-group Cliff's δ / Hedges' g vs fastest serializer\n")
    lines.append("- Version A/B: `analyze-benchmarks --compare-a A.csv --compare-b B.csv`\n")
    lines.append("- Master config: `config/benchmark_config.yaml`\n\n")

    lines.append("## Pivot Tables\n")

    if csharp_stats:
        lines.append(_pivot_table_md(csharp_stats, 'serializer', 'mode', 'avg_time_total_ns',
                                       'C#: Avg Total Time (ns) by Serializer and Mode'))
        lines.append(_pivot_table_md(csharp_stats, 'serializer', 'test_data', 'avg_ops_per_sec',
                                       'C#: Ops/Sec by Serializer and Data Type'))

    if python_stats:
        lines.append(_pivot_table_md(python_stats, 'serializer', 'mode', 'avg_time_total_ns',
                                       'Python: Avg Total Time (ns) by Serializer and Mode'))
        lines.append(_pivot_table_md(python_stats, 'serializer', 'test_data', 'avg_ops_per_sec',
                                       'Python: Ops/Sec by Serializer and Data Type'))

    if multi_lang_stats:
        by_lang: Dict[str, Dict] = {}
        for key, entry in multi_lang_stats.items():
            lang = (entry.get('language') or 'unknown').lower()
            if lang in ('csharp', 'c#', 'cs', 'python'):
                continue
            by_lang.setdefault(lang, {})[key] = entry
        for lang, stats in sorted(by_lang.items()):
            if not stats:
                continue
            title = lang.upper() if lang == 'c' else lang.capitalize()
            lines.append(_pivot_table_md(stats, 'serializer', 'mode', 'avg_time_total_ns',
                                           f'{title}: Avg Total Time (ns) by Serializer and Mode'))
            lines.append(_pivot_table_md(stats, 'serializer', 'test_data', 'avg_ops_per_sec',
                                           f'{title}: Ops/Sec by Serializer and Data Type'))
            sample = next(iter(stats.values()))
            if sample.get('total_ci_low_ns') is not None:
                lines.append(
                    f"\n### {title} scientific metrics (sample: {sample.get('serializer')} / "
                    f"{sample.get('test_data')} / {sample.get('mode')})\n"
                )
                lines.append(
                    f"- mean total: {sample.get('total_mean_ns', 0):.0f} ns "
                    f"(95% CI [{sample.get('total_ci_low_ns', 0):.0f}, "
                    f"{sample.get('total_ci_high_ns', 0):.0f}])\n"
                )
                lines.append(
                    f"- median: {sample.get('total_median_ns', 0):.0f} ns, "
                    f"CV: {sample.get('total_cv', 0):.3f}, "
                    f"vs fastest Cliff's δ: {sample.get('effect_vs_fastest_cliffs_delta', 0):.3f} "
                    f"({sample.get('effect_vs_fastest_cliffs_label', 'n/a')})\n"
                )

    lines.append("\n---\n")
    lines.append("*Generated by Serializer Benchmark CI*\n")

    with open(output_path, 'w') as f:
        f.write('\n'.join(lines))

    print(f"Markdown summary written to: {output_path}")


# Display labels and stable file-name keys for violin plots
_LANG_DISPLAY = {
    "csharp": "C#",
    "python": "Python",
    "rust": "Rust",
    "c": "C",
    "javascript": "JavaScript",
}


def _lang_file_key(lang_id: str, display: str) -> str:
    """Stable suffix used in violin_<key>_<TestData>.png filenames."""
    if lang_id:
        return lang_id.lower().replace("#", "sharp")
    return display.lower().replace("#", "sharp").replace(" ", "_")


def generate_violin_plots(
    output_dir: str,
    csharp_records: Optional[List[Dict]] = None,
    python_records: Optional[List[Dict]] = None,
    multi_lang_records: Optional[Dict] = None,
    **_kwargs,
) -> Dict[str, str]:
    """Generate violin plot images for all languages with records.

    Prefer ``multi_lang_records`` (lang_id -> list of row dicts). Legacy
    ``csharp_records`` / ``python_records`` are merged in when provided.

    Returns a dict mapping ``{lang_key}_{TestDataName}`` to image filenames.
    """
    os.makedirs(output_dir, exist_ok=True)

    by_lang: Dict[str, List[Dict]] = {}
    if multi_lang_records:
        for k, recs in multi_lang_records.items():
            if recs:
                by_lang[str(k).lower()] = list(recs)
    if csharp_records and "csharp" not in by_lang:
        by_lang["csharp"] = list(csharp_records)
    if python_records and "python" not in by_lang:
        by_lang["python"] = list(python_records)

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


def write_violin_plots_markdown(
    violin_images: Dict[str, str],
    output_path: str,
    image_subdir: str = "dashboard",
) -> None:
    """Write a Markdown page embedding generated violin plots, grouped by language."""
    # Group keys lang_testdata -> filename
    by_lang: Dict[str, List[Tuple[str, str]]] = {}
    for key, fname in sorted(violin_images.items()):
        if "_" not in key:
            continue
        # key is {lang}_{TestDataName} but TestDataName may contain underscores (rare)
        # Prefer longest known lang prefix
        lang_key = None
        for candidate in ("javascript", "csharp", "python", "rust", "c"):
            if key.startswith(candidate + "_"):
                lang_key = candidate
                dtype = key[len(candidate) + 1 :]
                break
        if lang_key is None:
            lang_key, dtype = key.split("_", 1)
        by_lang.setdefault(lang_key, []).append((dtype, fname))

    display_order = ["csharp", "python", "rust", "c", "javascript"]
    lines = [
        "# Performance (Violin Plots)",
        "",
        "Violin plots show the density of serialize / deserialize timings "
        "(wider = more samples at that duration). Generated by "
        "`analyze-benchmarks --generate-plots` for every language with CSV logs.",
        "",
        "Time axis is **microseconds** (normalized from ticks or nanoseconds in the CSVs).",
        "",
    ]
    for lang_key in display_order + sorted(k for k in by_lang if k not in display_order):
        items = by_lang.get(lang_key)
        if not items:
            continue
        title = _LANG_DISPLAY.get(lang_key, lang_key)
        lines.append(f"## {title}")
        lines.append("")
        for dtype, fname in items:
            lines.append(f"### {dtype}")
            lines.append(f'![{title} {dtype}]({image_subdir}/{fname}){{ width="50%" }}')
            lines.append("")
        lines.append("---")
        lines.append("")

    if len(lines) <= 6:
        lines.append("_No plots generated — run benchmarks then "
                     "`analyze-benchmarks --generate-plots`._")
        lines.append("")

    os.makedirs(os.path.dirname(os.path.abspath(output_path)) or ".", exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        f.write("\n".join(lines))
    print(f"Violin plots markdown written to: {output_path}")
