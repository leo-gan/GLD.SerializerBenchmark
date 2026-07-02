"""Command-line interface for benchmark analysis."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence

from .parser import parse_csv_file
from .stats import compute_statistics, compare_versions, load_stats_config
from .regression import check_regression, save_baseline


# Matches result filename format: 2026-06-12-123415.csv
_TS_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")

_KNOWN_LANGS = ("rust", "python", "csharp", "c", "javascript")

_LANG_ALIASES = {
    "py": "python",
    "cs": "csharp",
    "c#": "csharp",
    "csharp": "csharp",
    "c-sharp": "csharp",
    "js": "javascript",
    "node": "javascript",
    "javascript": "javascript",
    "python": "python",
    "rust": "rust",
    "c": "c",
}


def _is_timestamped_result(name: str) -> bool:
    return bool(_TS_PATTERN.match(name))


def _repo_root() -> Path:
    """Walk up from this file to find the repo root (has config/ or logs/)."""
    here = Path(__file__).resolve()
    for p in here.parents:
        if (p / "config" / "benchmark_config.yaml").exists() or (p / "logs").exists():
            return p
    return Path(".")


def _default_logs_root() -> Path:
    return _repo_root() / "logs"


def _default_reports_root() -> Path:
    return _repo_root() / "reports"


def find_latest_csv(directory: Path) -> Optional[Path]:
    """Find the most recent timestamped result CSV in a language log directory.

    Only considers YYYY-MM-DD-HHMMSS.csv files. Lexical sort = chronological.
    Returns None if no timestamped results exist.
    """
    if not directory or not directory.is_dir():
        return None

    ts_files = [
        p for p in directory.iterdir()
        if p.is_file() and _is_timestamped_result(p.name)
    ]
    if not ts_files:
        return None

    ts_files.sort(key=lambda p: p.name, reverse=True)
    return ts_files[0]


def _resolve_log_spec(spec: str) -> Optional[str]:
    """Resolve a log spec to a concrete CSV path.

    Supports:
    - Direct file path:  logs/rust/2026-06-12-123415.csv
    - Directory path:    logs/rust  (picks latest timestamped file)
    - Shorthand:         rust:2026-06-12  (partial timestamp match)
    - Shorthand:         rust:latest  (latest timestamped file)
    - Shorthand:         rust  (same as rust:latest)
    """
    # Try shorthand first: "lang:qualifier" or bare "lang"
    if ":" in spec and not os.path.exists(spec):
        lang, qualifier = spec.split(":", 1)
        lang_dir = _default_logs_root() / lang
        if lang_dir.is_dir():
            if qualifier == "latest":
                latest = find_latest_csv(lang_dir)
                return str(latest) if latest else None
            # Partial timestamp match
            matches = [
                p for p in lang_dir.iterdir()
                if p.is_file() and _is_timestamped_result(p.name) and qualifier in p.stem
            ]
            if matches:
                matches.sort(key=lambda p: p.name, reverse=True)
                return str(matches[0])
            return None

    p = Path(spec)

    # Bare language name as shorthand
    if not p.exists():
        lang_dir = _default_logs_root() / spec
        if lang_dir.is_dir():
            latest = find_latest_csv(lang_dir)
            return str(latest) if latest else None
        return None

    # Directory → pick latest
    if p.is_dir():
        latest = find_latest_csv(p)
        return str(latest) if latest else None

    # Direct file
    return str(p) if p.is_file() else None


def _normalize_language(name: str) -> str:
    key = name.strip().lower()
    if key not in _LANG_ALIASES:
        known = ", ".join(_KNOWN_LANGS)
        raise SystemExit(
            f"Unknown language '{name}'. Use one of: {known} "
            f"(aliases: py, cs, c#, c-sharp, js, node)."
        )
    return _LANG_ALIASES[key]


def _infer_language_from_path(filepath: str) -> Optional[str]:
    """Try to extract a language hint from the file path (e.g. /logs/rust/ → 'rust')."""
    norm = filepath.replace("\\", "/")
    # Longest first so javascript wins over a hypothetical java
    for lang in sorted(_KNOWN_LANGS, key=len, reverse=True):
        if f"/{lang}/" in norm:
            return lang
    return None


def _discover_logs(logs_root: Path) -> Dict[str, str]:
    """Auto-discover the latest timestamped result CSV under logs/<lang>/."""
    found: Dict[str, str] = {}
    if not logs_root.is_dir():
        return found
    for child in sorted(logs_root.iterdir()):
        if child.is_dir():
            latest = find_latest_csv(child)
            if latest:
                found[child.name] = str(latest)
    return found


def _filter_lang_paths(
    lang_paths: Dict[str, Optional[str]],
    languages: Optional[Sequence[str]],
) -> Dict[str, Optional[str]]:
    """Keep only selected languages (normalized ids)."""
    if not languages:
        return lang_paths
    wanted = {_normalize_language(x) for x in languages}
    return {k: v for k, v in lang_paths.items() if k in wanted}


def _generate_artifacts(
    *,
    all_records: Dict[str, List[Dict]],
    all_stats: Dict,
    lang_paths: Dict[str, Optional[str]],
    publish_root: Path,
    docs_dir: Path,
    reports_root: Path,
) -> None:
    """Write hub index, per-language results tables, and violin plots."""
    # Lazy import: reports pulls matplotlib (heavy / optional in some envs).
    from .reports import (
        generate_language_results_pages,
        generate_markdown_summary,
        generate_violin_plots,
    )

    plots_dir = str(publish_root / "plots" / "violin")
    lang_sources = {k: v for k, v in lang_paths.items() if v}
    violin_images = generate_violin_plots(
        plots_dir,
        multi_lang_records=all_records,
        lang_sources=lang_sources,
    )

    summary_path = str(publish_root / "BENCHMARK_SUMMARY.md")
    generate_markdown_summary(
        summary_path,
        multi_lang_stats=all_stats,
        multi_lang_records=all_records,
    )

    docs_root = str(docs_dir) if docs_dir.is_dir() else str(reports_root)
    generate_language_results_pages(
        multi_lang_stats=all_stats,
        violin_images=violin_images,
        docs_root=docs_root,
    )


def main():
    logs_root = _default_logs_root()
    reports_root = _default_reports_root()
    defaults = _discover_logs(logs_root)

    parser = argparse.ArgumentParser(
        description=(
            "Analyze serializer benchmarks and publish site artifacts "
            "(results tables + violin plots)."
        ),
        epilog=(
            "By default, loads the latest timestamped CSV per language and writes:\n"
            "  docs/analysis/BENCHMARK_SUMMARY.md\n"
            "  docs/<lang>/results.md\n"
            "  docs/analysis/plots/violin/<lang>_*.png\n"
            "\n"
            "Examples:\n"
            "  analyze-benchmarks\n"
            "  analyze-benchmarks -l python\n"
            "  analyze-benchmarks --language rust --language c\n"
            "  analyze-benchmarks --python-logs python/logs/python\n"
            "  analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument("--logs-root", default=str(logs_root), help="Root logs directory")
    parser.add_argument(
        "-l",
        "--language",
        action="append",
        dest="languages",
        metavar="LANG",
        help=(
            "Only load/generate artifacts for this language "
            f"({', '.join(_KNOWN_LANGS)}; aliases: py, cs, js). "
            "Repeatable. Default: all languages with logs."
        ),
    )
    parser.add_argument(
        "--csharp-logs",
        default=defaults.get("csharp"),
        help="C# result CSV, directory, or shorthand (e.g. csharp:2026-06-12)",
    )
    parser.add_argument(
        "--python-logs",
        default=defaults.get("python"),
        help="Python result CSV, directory, or shorthand",
    )
    parser.add_argument(
        "--rust-logs",
        default=defaults.get("rust"),
        help="Rust result CSV, directory, or shorthand",
    )
    parser.add_argument(
        "--c-logs",
        default=defaults.get("c"),
        help="C result CSV, directory, or shorthand",
    )
    parser.add_argument(
        "--javascript-logs",
        default=defaults.get("javascript"),
        help="JavaScript result CSV, directory, or shorthand",
    )
    parser.add_argument(
        "--extra-logs",
        action="append",
        default=[],
        help="Extra lang=path pairs, e.g. go=logs/go or go=logs/go/2026-06-12-123415.csv",
    )
    parser.add_argument(
        "--skip-generate",
        action="store_true",
        help="Do not write docs/plots (use with --compare-a/--check-regression/--save-baseline only)",
    )
    parser.add_argument("--check-regression", action="store_true", help="Check for regressions")
    parser.add_argument(
        "--regression-threshold",
        type=float,
        default=10.0,
        help="Regression threshold percent",
    )
    parser.add_argument(
        "--baseline-file",
        default=str(reports_root / "baseline.json"),
        help="Baseline file path",
    )
    parser.add_argument("--save-baseline", action="store_true", help="Save current as baseline")
    parser.add_argument(
        "--compare-a",
        default=None,
        help="Version A: CSV path, directory, or shorthand (e.g. rust:2026-06-11)",
    )
    parser.add_argument(
        "--compare-b",
        default=None,
        help="Version B: CSV path, directory, or shorthand (e.g. rust:2026-06-12)",
    )
    parser.add_argument("--config", default=None, help="Path to benchmark_config.yaml")
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available result files per language and exit",
    )

    args = parser.parse_args()

    stats_cfg = load_stats_config(args.config)

    if args.list:
        print("Available result files (latest marked with *):")
        lr = Path(args.logs_root)
        if not lr.is_dir():
            print(f"  (logs root {lr} not found)")
            return
        lang_dirs = sorted((d for d in lr.iterdir() if d.is_dir()), key=lambda p: p.name)
        if args.languages:
            wanted = {_normalize_language(x) for x in args.languages}
            lang_dirs = [d for d in lang_dirs if d.name in wanted]
        for lang_dir in lang_dirs:
            ts_files = sorted(
                [p for p in lang_dir.iterdir() if p.is_file() and _is_timestamped_result(p.name)],
                key=lambda p: p.name,
                reverse=True,
            )
            if not ts_files:
                print(f"\n{lang_dir.name}/  (no timestamped results)")
                continue
            latest = ts_files[0]
            print(f"\n{lang_dir.name}/")
            for f in ts_files[:10]:
                marker = " *" if f == latest else ""
                print(f"  {f.name}{marker}")
            if len(ts_files) > 10:
                print(f"  ... ({len(ts_files)} total)")
        return

    # Build language → CSV path map
    lang_paths: Dict[str, Optional[str]] = {
        "csharp": args.csharp_logs,
        "python": args.python_logs,
        "rust": args.rust_logs,
        "c": args.c_logs,
        "javascript": args.javascript_logs,
    }
    # Resolve any that need it (directories / shorthands passed explicitly)
    for lang in list(lang_paths):
        val = lang_paths[lang]
        if val and not Path(val).is_file():
            lang_paths[lang] = _resolve_log_spec(val)

    for item in args.extra_logs or []:
        if "=" in item:
            k, v = item.split("=", 1)
            resolved = _resolve_log_spec(v.strip())
            lang_paths[k.strip()] = resolved

    lang_paths = _filter_lang_paths(lang_paths, args.languages)
    if args.languages and not lang_paths:
        print("No languages matched the --language filter.")
        sys.exit(1)

    all_records: Dict[str, List[Dict]] = {}
    all_stats: Dict = {}
    total_loaded = 0
    for lang, path in lang_paths.items():
        if not path or not os.path.isfile(path):
            all_records[lang] = []
            continue
        recs, skipped = parse_csv_file(path, language_hint=lang)
        all_records[lang] = recs
        total_loaded += len(recs)
        if recs:
            st = compute_statistics(recs, config=stats_cfg, language_hint=lang)
            all_stats.update(st)
            print(
                f"Loaded {len(recs)} {lang} records from {os.path.basename(path)} "
                f"-> {len(st)} stat groups (skipped {skipped})"
            )

    print(f"Total: {total_loaded} records, {len(all_stats)} stat groups")

    os.makedirs(str(reports_root), exist_ok=True)

    repo_root = _repo_root()
    docs_dir = repo_root / "docs"
    docs_analysis = docs_dir / "analysis"
    # Prefer docs/analysis for published plots/summary when present
    publish_root = docs_analysis if docs_analysis.is_dir() else reports_root

    # Default action: write all site artifacts (tables + plots). No split flags.
    if not args.skip_generate:
        if total_loaded == 0:
            print("No records loaded; skipping artifact generation.")
        else:
            _generate_artifacts(
                all_records=all_records,
                all_stats=all_stats,
                lang_paths=lang_paths,
                publish_root=publish_root,
                docs_dir=docs_dir,
                reports_root=reports_root,
            )

    if args.compare_a and args.compare_b:
        ca = _resolve_log_spec(args.compare_a)
        cb = _resolve_log_spec(args.compare_b)
        if not ca or not os.path.isfile(ca):
            print(f"Error: cannot resolve --compare-a '{args.compare_a}'")
            sys.exit(1)
        if not cb or not os.path.isfile(cb):
            print(f"Error: cannot resolve --compare-b '{args.compare_b}'")
            sys.exit(1)

        hint_a = _infer_language_from_path(ca)
        hint_b = _infer_language_from_path(cb)
        rec_a, _ = parse_csv_file(ca, language_hint=hint_a)
        rec_b, _ = parse_csv_file(cb, language_hint=hint_b)
        sa = compute_statistics(rec_a, config=stats_cfg, language_hint=hint_a)
        sb = compute_statistics(rec_b, config=stats_cfg, language_hint=hint_b)
        comps = compare_versions(sa, sb, config=stats_cfg)
        out_path = str(reports_root / "VERSION_COMPARE.md")
        with open(out_path, "w", encoding="utf-8") as f:
            f.write("# Serializer Version Comparison (A vs B)\n\n")
            f.write(f"**A:** `{ca}`\n\n")
            f.write(f"**B:** `{cb}`\n\n")
            f.write(
                "| Serializer | Data | Mode | Mean A (ns) | Mean B (ns) | Δ% | "
                "Cliff's δ | Hedges' g | p (Holm) | Sig |\n"
            )
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
        print(f"  A = {ca}")
        print(f"  B = {cb}")
    elif args.compare_a or args.compare_b:
        print("Error: --compare-a and --compare-b must be used together")
        sys.exit(1)

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
            # Intentionally do NOT save baseline here even if --save-baseline
            # was passed. Saving regressed data would defeat the regression gate.
            if args.save_baseline:
                print("Note: --save-baseline skipped because a regression was detected.")
            sys.exit(1)

    if args.save_baseline:
        save_baseline(all_stats, args.baseline_file)
        print(f"Saved baseline to {args.baseline_file}")


if __name__ == "__main__":
    main()
