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
    # Clean up outliers (same logic as notebook: z-score < 3 and Time_ns < 60000)
    if not melted.empty:
        melted = melted[melted['Time_ns'] < 60000]
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

    # Convert time to microseconds for display (C# ticks are 100ns, so ticks * 100 / 1000 = ticks / 10)
    sample_time = subset['Time_ns'].median()
    if sample_time > 1_000_000:
        # C# ticks: convert to microseconds (ticks * 100ns / 1000 = ticks / 10)
        subset['Time_us'] = subset['Time_ns'] / 10  # ticks to microseconds
    else:
        # Python nanoseconds: convert to microseconds
        subset['Time_us'] = subset['Time_ns'] / 1000

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
    python_records: Optional[List[Dict]] = None
) -> None:
    """Generate markdown summary report."""
    lines = []
    lines.append("# Serializer Benchmark Summary\n")
    lines.append(f"**Generated:** {datetime.now().isoformat()}\n")
    lines.append("---\n\n")

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

    lines.append("\n---\n")
    lines.append("*Generated by Serializer Benchmark CI*\n")

    with open(output_path, 'w') as f:
        f.write('\n'.join(lines))

    print(f"Markdown summary written to: {output_path}")


def generate_violin_plots(
    output_dir: str,
    csharp_records: Optional[List[Dict]] = None,
    python_records: Optional[List[Dict]] = None
) -> Dict[str, str]:
    """Generate violin plot images for benchmark results.

    Returns a dict mapping data type names to image filenames.
    """
    os.makedirs(output_dir, exist_ok=True)

    violin_images = {}

    if csharp_records or python_records:
        cs_melted = _records_to_melted_df(csharp_records or [], 'C#')
        py_melted = _records_to_melted_df(python_records or [], 'Python')

        # Generate separate C# plots
        if not cs_melted.empty:
            cs_data_types = sorted(cs_melted['TestDataName'].unique())
            for dtype in cs_data_types:
                img_name = _generate_violin_plot(cs_melted, dtype, output_dir,
                                                 language='C#', top_n=5)
                if img_name:
                    violin_images[f"csharp_{dtype}"] = img_name

        # Generate separate Python plots
        if not py_melted.empty:
            py_data_types = sorted(py_melted['TestDataName'].unique())
            for dtype in py_data_types:
                img_name = _generate_violin_plot(py_melted, dtype, output_dir,
                                                 language='Python', top_n=5)
                if img_name:
                    violin_images[f"python_{dtype}"] = img_name

    generated = list(violin_images.values())
    if generated:
        print(f"Generated {len(generated)} violin plots in: {output_dir}")
    return violin_images
