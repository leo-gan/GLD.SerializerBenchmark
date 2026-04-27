"""Command-line interface for benchmark analysis."""

import argparse
import os
import sys

from .parser import parse_csv_file
from .stats import compute_statistics
from .reports import generate_markdown_summary, generate_html_dashboard
from .regression import check_regression, save_baseline


def main():
    parser = argparse.ArgumentParser(description='Analyze serializer benchmarks')
    parser.add_argument('--csharp-logs', help='Path to C# benchmark CSV')
    parser.add_argument('--python-logs', help='Path to Python benchmark CSV')
    parser.add_argument('--output-dir', default='reports', help='Output directory')
    parser.add_argument('--generate-dashboard', action='store_true', help='Generate HTML dashboard')
    parser.add_argument('--generate-summary', action='store_true', help='Generate Markdown summary')
    parser.add_argument('--check-regression', action='store_true', help='Check for regressions')
    parser.add_argument('--regression-threshold', type=float, default=10.0, help='Regression threshold %')
    parser.add_argument('--baseline-file', default='baseline.json', help='Baseline file path')
    parser.add_argument('--save-baseline', action='store_true', help='Save current as baseline')

    args = parser.parse_args()

    # Parse CSV files
    csharp_records = parse_csv_file(args.csharp_logs) if args.csharp_logs else []
    python_records = parse_csv_file(args.python_logs) if args.python_logs else []

    print(f"Loaded {len(csharp_records)} C# records, {len(python_records)} Python records")

    # Compute statistics
    csharp_stats = compute_statistics(csharp_records)
    python_stats = compute_statistics(python_records)

    print(f"Computed {len(csharp_stats)} C# stat entries, {len(python_stats)} Python stat entries")

    # Create output directory
    os.makedirs(args.output_dir, exist_ok=True)

    # Generate outputs
    if args.generate_summary:
        summary_path = os.path.join(args.output_dir, 'BENCHMARK_SUMMARY.md')
        generate_markdown_summary(csharp_stats, python_stats, summary_path)

    if args.generate_dashboard:
        dashboard_dir = os.path.join(args.output_dir, 'dashboard')
        generate_html_dashboard(csharp_stats, python_stats, dashboard_dir)

    # Check regression
    if args.check_regression:
        all_stats = {**csharp_stats, **python_stats}
        has_regression, regressions = check_regression(
            all_stats,
            args.baseline_file,
            args.regression_threshold
        )

        if regressions:
            print("\n=== Performance Regressions Detected ===")
            for r in regressions:
                print(f"  {r}")
            print("========================================\n")

        if has_regression:
            sys.exit(1)
        else:
            print("No performance regressions detected.")

    # Save baseline
    if args.save_baseline:
        all_stats = {**csharp_stats, **python_stats}
        save_baseline(all_stats, args.baseline_file)


if __name__ == '__main__':
    main()
