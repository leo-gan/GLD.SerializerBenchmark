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


def generate_html_dashboard(
    csharp_stats: Dict,
    python_stats: Dict,
    output_dir: str,
    csharp_records: Optional[List[Dict]] = None,
    python_records: Optional[List[Dict]] = None
) -> None:
    """Generate HTML dashboard with benchmark results including violin plots."""
    os.makedirs(output_dir, exist_ok=True)

    # Generate data for charts
    def stats_to_chart_data(stats: Dict) -> Tuple[List, List, List]:
        labels = []
        times = []
        sizes = []
        sorted_items = sorted(stats.items(), key=lambda x: x[1]['avg_time_total_ns'])[:15]
        for key, stat in sorted_items:
            labels.append(f"{stat['serializer']}")
            times.append(round(stat['avg_time_total_ns'] / 1000, 2))  # Convert to microseconds
            sizes.append(stat['median_size_bytes'])
        return labels, times, sizes

    cs_labels, cs_times, cs_sizes = stats_to_chart_data(csharp_stats)
    py_labels, py_times, py_sizes = stats_to_chart_data(python_stats)

    # Generate violin plots for each data type - separate for C# and Python, top 5 only
    cs_violin_images = {}
    py_violin_images = {}
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
                    cs_violin_images[dtype] = img_name

        # Generate separate Python plots
        if not py_melted.empty:
            py_data_types = sorted(py_melted['TestDataName'].unique())
            for dtype in py_data_types:
                img_name = _generate_violin_plot(py_melted, dtype, output_dir,
                                                 language='Python', top_n=5)
                if img_name:
                    py_violin_images[dtype] = img_name

    html = f'''<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Serializer Benchmark Dashboard</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        * {{ box-sizing: border-box; margin: 0; padding: 0; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #f5f5f5;
            color: #333;
            line-height: 1.6;
        }}
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 2rem;
            text-align: center;
        }}
        .header h1 {{ font-size: 2rem; margin-bottom: 0.5rem; }}
        .header p {{ opacity: 0.9; }}
        .container {{
            max-width: 1400px;
            margin: 0 auto;
            padding: 2rem;
        }}
        .grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));
            gap: 2rem;
            margin-bottom: 2rem;
        }}
        .card {{
            background: white;
            border-radius: 12px;
            padding: 1.5rem;
            box-shadow: 0 2px 8px rgba(0,0,0,0.1);
        }}
        .card h2 {{
            font-size: 1.25rem;
            margin-bottom: 1rem;
            color: #444;
            border-bottom: 2px solid #667eea;
            padding-bottom: 0.5rem;
        }}
        .stats-grid {{
            display: grid;
            grid-template-columns: repeat(auto-fit, minmax(200px, 1fr));
            gap: 1rem;
            margin-bottom: 2rem;
        }}
        .stat-card {{
            background: white;
            border-radius: 8px;
            padding: 1rem;
            text-align: center;
            box-shadow: 0 2px 4px rgba(0,0,0,0.05);
        }}
        .stat-value {{
            font-size: 2rem;
            font-weight: bold;
            color: #667eea;
        }}
        .stat-label {{
            font-size: 0.875rem;
            color: #666;
            margin-top: 0.25rem;
        }}
        .chart-container {{
            position: relative;
            height: 300px;
            margin-top: 1rem;
        }}
        table {{
            width: 100%;
            border-collapse: collapse;
            font-size: 0.875rem;
        }}
        th, td {{
            padding: 0.75rem;
            text-align: left;
            border-bottom: 1px solid #e0e0e0;
        }}
        th {{
            background: #f8f9fa;
            font-weight: 600;
            color: #555;
        }}
        tr:hover {{ background: #f8f9fa; }}
        .badge {{
            display: inline-block;
            padding: 0.25rem 0.5rem;
            border-radius: 4px;
            font-size: 0.75rem;
            font-weight: 500;
        }}
        .badge-csharp {{ background: #512bd4; color: white; }}
        .badge-python {{ background: #3776ab; color: white; }}
        .badge-stream {{ background: #28a745; color: white; }}
        .badge-string {{ background: #6c757d; color: white; }}
        .badge-integer {{ background: #fd7e14; color: white; }}
        .badge-person {{ background: #20c997; color: white; }}
        .badge-simple {{ background: #6f42c1; color: white; }}
        .tabs {{
            display: flex;
            border-bottom: 2px solid #e0e0e0;
            margin-bottom: 1rem;
        }}
        .tab {{
            padding: 0.75rem 1.5rem;
            cursor: pointer;
            border-bottom: 2px solid transparent;
            margin-bottom: -2px;
            font-weight: 500;
        }}
        .tab:hover {{ background: #f5f5f5; }}
        .tab.active {{
            border-bottom-color: #667eea;
            color: #667eea;
        }}
        .tab-content {{ display: none; }}
        .tab-content.active {{ display: block; }}
        .comparison-table {{
            width: 100%;
            margin-top: 1rem;
        }}
        .comparison-table th {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
        }}
        .winner {{ color: #28a745; font-weight: bold; }}
        .loser {{ color: #dc3545; }}
        .footer {{
            text-align: center;
            padding: 2rem;
            color: #666;
            font-size: 0.875rem;
        }}
    </style>
</head>
<body>
    <div class="header">
        <h1>Serializer Benchmark Dashboard</h1>
        <p>Serialization performance comparison</p>
        <p>Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
    </div>

    <div class="container">
        <div class="stats-grid">
            <div class="stat-card">
                <div class="stat-value">{len(csharp_stats)}</div>
                <div class="stat-label">C# Serializer Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{len(python_stats)}</div>
                <div class="stat-label">Python Serializer Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-value">{len(cs_labels) + len(py_labels)}</div>
                <div class="stat-label">Total Configurations</div>
            </div>
        </div>

        <div class="grid">
            <div class="card">
                <h2>C# Performance (Top 15)</h2>
                <div class="chart-container">
                    <canvas id="csharpChart"></canvas>
                </div>
            </div>
            <div class="card">
                <h2>Python Performance (Top 15)</h2>
                <div class="chart-container">
                    <canvas id="pythonChart"></canvas>
                </div>
            </div>
        </div>

        <!-- Pivot Tables -->
        <div class="card">
            <h2>Results by Mode and Data Type (Pivot Tables)</h2>
            <div class="tabs">
                <div class="tab active" onclick="showTab('pivot-csharp')">C# Pivot Tables</div>
                <div class="tab" onclick="showTab('pivot-python')">Python Pivot Tables</div>
            </div>

            <div id="pivot-csharp" class="tab-content active">
''' + (
    _pivot_table_html(csharp_stats, 'serializer', 'mode', 'avg_time_total_ns',
                       'C#: Avg Total Time (ns) by Serializer and Mode') +
    _pivot_table_html(csharp_stats, 'serializer', 'test_data', 'avg_ops_per_sec',
                       'C#: Ops/Sec by Serializer and Data Type')
    if csharp_stats else '<p>No C# data available</p>'
) + '''            </div>

            <div id="pivot-python" class="tab-content">
''' + (
    _pivot_table_html(python_stats, 'serializer', 'mode', 'avg_time_total_ns',
                       'Python: Avg Total Time (ns) by Serializer and Mode') +
    _pivot_table_html(python_stats, 'serializer', 'test_data', 'avg_ops_per_sec',
                       'Python: Ops/Sec by Serializer and Data Type')
    if python_stats else '<p>No Python data available</p>'
) + '''            </div>
        </div>
    </div>
'''

    # Add C# violin plots section
    if cs_violin_images:
        html += '''
    <div class="container">
        <div class="card">
            <h2>C# Distribution Analysis (Violin Plots)</h2>
            <p style="margin-bottom:1rem;">Top 5 serializers by mean time for each data type. Split violins show serialize (left) vs deserialize (right) time distributions.</p>
            <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));">
'''
        for dtype, img_name in sorted(cs_violin_images.items()):
            html += f'''                <div class="card" style="padding: 1rem;">
                    <h4>{dtype}</h4>
                    <img src="{img_name}" alt="C# violin plot for {dtype}" style="width: 100%; height: auto; border-radius: 8px;">
                </div>
'''
        html += '''            </div>
        </div>
    </div>
'''

    # Add Python violin plots section
    if py_violin_images:
        html += '''
    <div class="container">
        <div class="card">
            <h2>Python Distribution Analysis (Violin Plots)</h2>
            <p style="margin-bottom:1rem;">Top 5 serializers by mean time for each data type. Split violins show serialize (left) vs deserialize (right) time distributions.</p>
            <div class="grid" style="grid-template-columns: repeat(auto-fit, minmax(600px, 1fr));">
'''
        for dtype, img_name in sorted(py_violin_images.items()):
            html += f'''                <div class="card" style="padding: 1rem;">
                    <h4>{dtype}</h4>
                    <img src="{img_name}" alt="Python violin plot for {dtype}" style="width: 100%; height: auto; border-radius: 8px;">
                </div>
'''
        html += '''            </div>
        </div>
    </div>
'''

    html += '''
    <div class="footer">
        <p>Generated by Serializer Benchmark CI</p>
    </div>

    <script>
        // C# Chart
        new Chart(document.getElementById('csharpChart'), {{
            type: 'bar',
            data: {{
                labels: {json.dumps(cs_labels)},
                datasets: [{{
                    label: 'Total Time (microseconds)',
                    data: {json.dumps(cs_times)},
                    backgroundColor: 'rgba(81, 43, 212, 0.7)',
                    borderColor: 'rgba(81, 43, 212, 1)',
                    borderWidth: 1
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{
                    legend: {{ display: false }}
                }},
                scales: {{
                    y: {{
                        beginAtZero: true,
                        title: {{ display: true, text: 'Time (microseconds)' }}
                    }}
                }}
            }}
        }});

        // Python Chart
        new Chart(document.getElementById('pythonChart'), {{
            type: 'bar',
            data: {{
                labels: {json.dumps(py_labels)},
                datasets: [{{
                    label: 'Total Time (microseconds)',
                    data: {json.dumps(py_times)},
                    backgroundColor: 'rgba(55, 118, 171, 0.7)',
                    borderColor: 'rgba(55, 118, 171, 1)',
                    borderWidth: 1
                }}]
            }},
            options: {{
                responsive: true,
                maintainAspectRatio: false,
                plugins: {{
                    legend: {{ display: false }}
                }},
                scales: {{
                    y: {{
                        beginAtZero: true,
                        title: {{ display: true, text: 'Time (microseconds)' }}
                    }}
                }}
            }}
        }});

        // Tab switching function
        function showTab(tabId) {{
            document.querySelectorAll('.tab-content').forEach(t => t.classList.remove('active'));
            document.querySelectorAll('.tab').forEach(t => t.classList.remove('active'));
            document.getElementById(tabId).classList.add('active');
            event.target.classList.add('active');
        }}
    </script>
</body>
</html>
'''

    output_path = os.path.join(output_dir, 'index.html')
    with open(output_path, 'w') as f:
        f.write(html)

    print(f"HTML dashboard written to: {output_path}")
