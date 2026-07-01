"""Command-line interface for benchmark analysis."""

from __future__ import annotations

import argparse
import os
import sys
from pathlib import Path
from typing import Dict, List

from .parser import parse_csv_file
from .stats import compute_statistics, compare_versions, load_stats_config
from .reports import generate_markdown_summary, generate_violin_plots
from .regression import check_regression, save_baseline


def _default_logs_root() -> Path:
    # analysis/src/benchmark_analysis -> repo root
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "config" / "benchmark_config.yaml").exists() or (p / "logs").exists():
            return p / "logs"
    return Path("logs")


def _discover_logs(logs_root: Path) -> Dict[str, str]:
    """Auto-discover benchmark-log.csv under logs/<lang>/."""
    found: Dict[str, str] = {}
    if not logs_root.is_dir():
        return found
    for child in sorted(logs_root.iterdir()):
        if child.is_dir():
            log = child / "benchmark-log.csv"
            if log.is_file():
                found[child.name] = str(log)
    return found


def main():
    logs_root = _default_logs_root()
    defaults = _discover_logs(logs_root)

    parser = argparse.ArgumentParser(
        description="Analyze serializer benchmarks (multi-language, scientific stats)"
    )
    parser.add_argument("--logs-root", default=str(logs_root), help="Root logs directory")
    parser.add_argument("--csharp-logs", default=defaults.get("csharp", str(logs_root / "csharp" / "benchmark-log.csv")))
    parser.add_argument("--python-logs", default=defaults.get("python", str(logs_root / "python" / "benchmark-log.csv")))
    parser.add_argument("--rust-logs", default=defaults.get("rust", str(logs_root / "rust" / "benchmark-log.csv")))
    parser.add_argument("--c-logs", default=defaults.get("c", str(logs_root / "c" / "benchmark-log.csv")))
    parser.add_argument("--javascript-logs", default=defaults.get("javascript", str(logs_root / "javascript" / "benchmark-log.csv")))
    parser.add_argument("--extra-logs", action="append", default=[],
                        help="Extra lang=path pairs, e.g. java=logs/java/benchmark-log.csv")
    parser.add_argument("--output-dir", default="reports", help="Output directory")
    parser.add_argument("--generate-plots", action="store_true", help="Generate violin plot images")
    parser.add_argument("--generate-summary", action="store_true", help="Generate Markdown summary")
    parser.add_argument("--check-regression", action="store_true", help="Check for regressions")
    parser.add_argument("--regression-threshold", type=float, default=10.0, help="Regression threshold percent")
    parser.add_argument("--baseline-file", default="baseline.json", help="Baseline file path")
    parser.add_argument("--save-baseline", action="store_true", help="Save current as baseline")
    parser.add_argument("--compare-a", default=None, help="CSV for version A (serializer A/B compare)")
    parser.add_argument("--compare-b", default=None, help="CSV for version B (serializer A/B compare)")
    parser.add_argument("--config", default=None, help="Path to benchmark_config.yaml")

    args = parser.parse_args()

    stats_cfg = load_stats_config(args.config)

    lang_paths = {
        "csharp": args.csharp_logs,
        "python": args.python_logs,
        "rust": args.rust_logs,
        "c": args.c_logs,
        "javascript": args.javascript_logs,
    }
    for item in args.extra_logs or []:
        if "=" in item:
            k, v = item.split("=", 1)
            lang_paths[k.strip()] = v.strip()

    all_records: Dict[str, List[Dict]] = {}
    all_stats: Dict = {}
    total_loaded = 0
    for lang, path in lang_paths.items():
        recs = parse_csv_file(path, language_hint=lang) if path else []
        all_records[lang] = recs
        total_loaded += len(recs)
        if recs:
            st = compute_statistics(recs, config=stats_cfg, language_hint=lang)
            all_stats.update(st)
            print(f"Loaded {len(recs)} {lang} records -> {len(st)} stat groups")

    print(f"Total: {total_loaded} records, {len(all_stats)} stat groups")

    os.makedirs(args.output_dir, exist_ok=True)

    # Backward-compatible names for report generators
    csharp_stats = {k: v for k, v in all_stats.items() if (v.get("language") or "").lower() in ("csharp", "c#", "cs", "")}
    python_stats = {k: v for k, v in all_stats.items() if (v.get("language") or "").lower() == "python"}
    # If language not set on old data, fall back to path-based split
    if not csharp_stats and all_records.get("csharp"):
        csharp_stats = compute_statistics(all_records["csharp"], config=stats_cfg, language_hint="csharp")
    if not python_stats and all_records.get("python"):
        python_stats = compute_statistics(all_records["python"], config=stats_cfg, language_hint="python")

    violin_images = {}
    if args.generate_plots:
        plots_dir = os.path.join(args.output_dir, "plots", "violin")
        violin_images = generate_violin_plots(
            plots_dir,
            csharp_records=all_records.get("csharp", []),
            python_records=all_records.get("python", []),
            multi_lang_records=all_records,
        )
        # Plot embeds live on docs/<lang>/results.md (via generate_language_results_pages)

    if args.generate_summary:
        summary_path = os.path.join(args.output_dir, "BENCHMARK_SUMMARY.md")
        generate_markdown_summary(
            csharp_stats,
            python_stats,
            summary_path,
            csharp_records=all_records.get("csharp", []),
            python_records=all_records.get("python", []),
            multi_lang_stats=all_stats,
            multi_lang_records=all_records,
        )

    # Per-language results (pivots + plot embeds) under docs/<lang>/results.md
    if args.generate_summary or args.generate_plots:
        from .reports import generate_language_results_pages

        out_abs = os.path.abspath(args.output_dir)
        # When writing into docs/analysis, language pages live under docs/
        docs_root = os.path.dirname(out_abs) if os.path.basename(out_abs) == "analysis" else out_abs
        # If output is reports/, still try repo docs/ when present
        if os.path.basename(out_abs) != "analysis":
            repo_docs = os.path.join(os.path.dirname(out_abs), "docs")
            if os.path.isdir(repo_docs):
                docs_root = repo_docs
            elif os.path.isdir(os.path.join(out_abs, "..", "docs")):
                docs_root = os.path.abspath(os.path.join(out_abs, "..", "docs"))
        generate_language_results_pages(
            multi_lang_stats=all_stats,
            violin_images=violin_images,
            docs_root=docs_root,
        )

    if args.compare_a and args.compare_b:
        rec_a = parse_csv_file(args.compare_a)
        rec_b = parse_csv_file(args.compare_b)
        sa = compute_statistics(rec_a, config=stats_cfg)
        sb = compute_statistics(rec_b, config=stats_cfg)
        comps = compare_versions(sa, sb, config=stats_cfg)
        out_path = os.path.join(args.output_dir, "VERSION_COMPARE.md")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("# Serializer Version Comparison (A vs B)\n\n")
            f.write("| Serializer | Data | Mode | Mean A (ns) | Mean B (ns) | Δ% | Cliff's δ | Hedges' g | p (Holm) | Sig |\n")
            f.write("|---|---|---|---:|---:|---:|---:|---:|---:|:---:|\n")
            for c in comps:
                sig = "yes" if c.get("significant_holm", c.get("significant")) else "no"
                f.write(
                    f"| {c['serializer']} | {c['test_data']} | {c['mode']} | "
                    f"{c['mean_a_ns']:.0f} | {c['mean_b_ns']:.0f} | "
                    f"{(c.get('pct_change') or 0):+.1f} | {c['cliffs_delta']:.3f} | "
                    f"{c['hedges_g']:.3f} | {c.get('p_value_holm', c['p_value']):.4f} | {sig} |\n"
                )
        print(f"Wrote version comparison: {out_path} ({len(comps)} pairs)")

    if args.check_regression:
        has_regression, regressions = check_regression(
            all_stats,
            args.baseline_file,
            args.regression_threshold,
        )
        if has_regression:
            print(f"REGRESSION: {len(regressions)} entries exceeded threshold")
            for r in regressions[:20]:
                print(f"  {r}")
            if args.save_baseline:
                save_baseline(all_stats, args.baseline_file)
            sys.exit(1)

    if args.save_baseline:
        save_baseline(all_stats, args.baseline_file)
        print(f"Saved baseline to {args.baseline_file}")

    if not any([args.generate_summary, args.generate_plots, args.check_regression,
                args.save_baseline, args.compare_a]):
        print("No action specified. Use --generate-summary, --generate-plots, "
              "--check-regression, --save-baseline, or --compare-a/--compare-b")


if __name__ == "__main__":
    main()
