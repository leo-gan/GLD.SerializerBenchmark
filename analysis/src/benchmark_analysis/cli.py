"""Command-line interface for benchmark analysis."""

from __future__ import annotations

import argparse
import os
import re
import sys
from pathlib import Path
from typing import Dict, List, Optional, Sequence, Tuple

from .parser import parse_csv_file
from .stats import (
    compute_statistics,
    compare_versions,
    load_stats_config,
    prepare_analysis_records,
)
from .regression import check_regression, load_regression_config, save_baseline


# Matches result filename format: 2026-06-12-123415.csv
_TS_PATTERN = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")

def _KNOWN_LANGS() -> tuple:
    """Language ids from master config (fallback if config unreadable)."""
    try:
        from .config_loader import known_language_ids

        return known_language_ids()
    except Exception:
        return ("rust", "python", "csharp", "c", "javascript", "go", "java", "cpp", "swift")


def _LANG_ALIASES() -> dict:
    try:
        from .config_loader import language_aliases

        return language_aliases()
    except Exception:
        return {
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
            "go": "go",
            "golang": "go",
            "java": "java",
            "jdk": "java",
            "jvm": "java",
            "cpp": "cpp",
            "c++": "cpp",
            "cxx": "cpp",
            "cplusplus": "cpp",
        }


def _is_timestamped_result(name: str) -> bool:
    return bool(_TS_PATTERN.match(name))


def _repo_root() -> Path:
    """Walk up from this file to find the repo root (has config/ or logs/)."""
    try:
        from .config_loader import repo_root as _cfg_repo_root

        return _cfg_repo_root()
    except Exception:
        here = Path(__file__).resolve()
        for p in here.parents:
            if (p / "config" / "benchmark_config.yaml").exists() or (p / "logs").exists():
                return p
        return Path(".")


def _default_logs_root() -> Path:
    try:
        from .config_loader import logs_root

        return logs_root()
    except Exception:
        return _repo_root() / "logs"


def _default_reports_root() -> Path:
    try:
        from .config_loader import reports_root

        return reports_root()
    except Exception:
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


def _resolve_log_spec(spec: str, *, logs_root: Optional[Path] = None) -> Optional[str]:
    """Resolve a log spec to a concrete CSV path.

    Supports:
    - Direct file path:  logs/rust/2026-06-12-123415.csv
    - Directory path:    logs/rust  (picks latest timestamped file)
    - Shorthand:         rust:2026-06-12  (partial timestamp match under logs_root)
    - Shorthand:         rust:latest  (latest timestamped file)
    - Shorthand:         rust  (same as rust:latest)
    """
    root = logs_root or _default_logs_root()

    # Try shorthand first: "lang:qualifier" or bare "lang"
    if ":" in spec and not os.path.exists(spec):
        lang, qualifier = spec.split(":", 1)
        lang_dir = root / lang
        if lang_dir.is_dir():
            if qualifier == "latest":
                latest = find_latest_csv(lang_dir)
                return str(latest) if latest else None
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
        lang_dir = root / spec
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
    aliases = _LANG_ALIASES()
    if key not in aliases:
        known = ", ".join(_KNOWN_LANGS())
        raise SystemExit(
            f"Unknown language '{name}'. Use one of: {known} "
            f"(aliases: py, cs, c#, c-sharp, js, node)."
        )
    return aliases[key]


def _try_normalize_language(name: str) -> Optional[str]:
    key = name.strip().lower()
    return _LANG_ALIASES().get(key)


def _infer_language_from_path(filepath: str) -> Optional[str]:
    """Try to extract a language hint from the file path (e.g. /logs/rust/ → 'rust')."""
    norm = filepath.replace("\\", "/")
    for lang in sorted(_KNOWN_LANGS(), key=len, reverse=True):
        if f"/{lang}/" in norm:
            return lang
    return None


def _discover_logs(logs_root: Path) -> Dict[str, str]:
    """Auto-discover the latest timestamped result CSV under logs/<lang>/."""
    found: Dict[str, str] = {}
    if not logs_root.is_dir():
        return found
    known = set(_KNOWN_LANGS())
    for child in sorted(logs_root.iterdir()):
        if not child.is_dir():
            continue
        # Skip backups / non-language dirs (e.g. python.root-docker-backup)
        if child.name not in known and _try_normalize_language(child.name) is None:
            continue
        lang_id = _try_normalize_language(child.name) or child.name
        latest = find_latest_csv(child)
        if latest:
            found[lang_id] = str(latest)
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


def _split_logs_spec(spec: str) -> Tuple[Optional[str], str]:
    """Parse ``lang=path`` or bare ``path`` into (lang_or_None, path_spec).

    ``lang`` may be a known alias (normalized) or any simple id for future
    languages (e.g. ``go=logs/go``).
    """
    if "=" not in spec:
        return None, spec.strip()
    left, right = spec.split("=", 1)
    left = left.strip()
    right = right.strip()
    # Simple language token: known alias or [A-Za-z][A-Za-z0-9_-]*
    if re.fullmatch(r"[A-Za-z][A-Za-z0-9_-]*", left):
        return _try_normalize_language(left) or left.lower(), right
    # Path itself may contain '=' — treat whole string as path.
    return None, spec.strip()


def _resolve_logs_assignment(
    spec: str,
    *,
    languages: Optional[Sequence[str]],
    logs_root: Path,
) -> Tuple[str, str]:
    """Resolve one ``--logs`` value to ``(language_id, csv_path)``."""
    lang, path_spec = _split_logs_spec(spec)
    resolved = _resolve_log_spec(path_spec, logs_root=logs_root)

    if lang is None:
        # Infer from resolved path, raw path, or single -l filter.
        probe = resolved or path_spec
        lang = _infer_language_from_path(probe)
        if lang is None and languages and len(languages) == 1:
            lang = _normalize_language(languages[0])

    if lang is None:
        raise SystemExit(
            f"Cannot determine language for --logs {spec!r}. "
            f"Use --logs LANG=PATH (e.g. python=python/logs/python) "
            f"or pair a bare path with a single -l LANG."
        )

    if not resolved or not os.path.isfile(resolved):
        raise SystemExit(
            f"Cannot resolve log path for language '{lang}' from {path_spec!r}"
        )
    return lang, resolved


def _generate_artifacts(
    *,
    all_records: Dict[str, List[Dict]],
    all_stats: Dict,
    lang_paths: Dict[str, Optional[str]],
    publish_root: Path,
    docs_dir: Path,
    reports_root: Path,
    stats_config: Optional[Dict] = None,
    pre_sanitized: bool = True,
) -> None:
    """Write hub index, per-language results tables, and latency distributions.

    ``all_records`` should be the *same* sanitized population used to build
    ``all_stats`` (see :func:`prepare_analysis_records`) so plots and tables
    cannot diverge.
    """
    # Lazy import: reports pulls matplotlib (heavy / optional in some envs).
    from .reports import generate_language_results_pages, generate_violin_plots

    plots_dir = str(publish_root / "plots" / "violin")
    lang_sources = {k: v for k, v in lang_paths.items() if v}
    violin_images = generate_violin_plots(
        plots_dir,
        multi_lang_records=all_records,
        lang_sources=lang_sources,
        stats_config=stats_config,
        pre_sanitized=pre_sanitized,
    )

    # docs/analysis/BENCHMARK_SUMMARY.md is a static hub — do not regenerate it.
    docs_root = str(docs_dir) if docs_dir.is_dir() else str(reports_root)
    metrics_profile = (
        os.environ.get("BENCHMARK_METRICS_PROFILE")
        or (stats_config or {}).get("_metrics_profile")
        or "multi_way"
    )
    generate_language_results_pages(
        multi_lang_stats=all_stats,
        violin_images=violin_images,
        docs_root=docs_root,
        lang_sources=lang_sources,
        metrics_profile=str(metrics_profile),
    )


def main():
    # Defaults from master config (overridable by flags after parse).
    try:
        from .config_loader import baseline_path, regression_threshold

        _default_threshold = regression_threshold()
        _default_baseline = str(baseline_path())
    except Exception:
        _default_threshold = 10.0
        _default_baseline = str(_default_reports_root() / "baseline.json")

    logs_root_default = _default_logs_root()
    reports_root = _default_reports_root()

    parser = argparse.ArgumentParser(
        description=(
            "Analyze serializer benchmarks and publish site artifacts "
            "(results tables + latency distributions)."
        ),
        epilog=(
            "By default, loads the latest timestamped CSV under logs/<lang>/ and writes:\n"
            "  docs/<lang>/results.md\n"
            "  docs/analysis/plots/violin/<lang>_*.png\n"
            "(docs/analysis/BENCHMARK_SUMMARY.md is a static hub and is not overwritten.)\n"
            "\n"
            "Examples:\n"
            "  analyze-benchmarks\n"
            "  analyze-benchmarks -l python\n"
            "  analyze-benchmarks -l python --logs python/logs/python\n"
            "  analyze-benchmarks --logs python=python/logs/python --logs rust=logs/rust\n"
            "  analyze-benchmarks --logs rust:2026-06-12\n"
            "  analyze-benchmarks --compare-a rust:185249 --compare-b rust:191316\n"
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--logs-root",
        default=str(logs_root_default),
        help="Root directory with per-language subdirs (default: repo logs/)",
    )
    parser.add_argument(
        "-l",
        "--language",
        action="append",
        dest="languages",
        metavar="LANG",
        help=(
            "Only load/generate artifacts for this language "
            f"({', '.join(_KNOWN_LANGS())}; aliases: py, cs, js, golang, jdk, c++, cxx). "
            "Repeatable. Default: all languages with logs."
        ),
    )
    parser.add_argument(
        "--logs",
        action="append",
        default=[],
        metavar="SPEC",
        help=(
            "Log source override (repeatable). Forms: "
            "LANG=PATH (e.g. python=python/logs/python), "
            "PATH (with a single -l LANG, or when language is in the path), "
            "or shorthand LANG / LANG:stamp under --logs-root."
        ),
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
        default=_default_threshold,
        help="Regression threshold percent (default: regression.threshold_percent in config)",
    )
    parser.add_argument(
        "--regression-combine",
        choices=["and", "or", "practical_only", "statistical_only"],
        default=None,
        help="How to combine practical %% and CI arms (default: regression.combine in config, usually and)",
    )
    parser.add_argument(
        "--baseline-file",
        default=_default_baseline,
        help="Baseline file path (default: paths.baseline_filename in config)",
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
        "--metrics-profile",
        choices=("multi_way", "pairwise", "full"),
        default=None,
        help=(
            "Publication metric tier: multi_way (default, high-importance only), "
            "pairwise (A/B full set), or full. See docs/analysis/METRICS.md."
        ),
    )
    parser.add_argument(
        "--list",
        action="store_true",
        help="List available result files per language and exit",
    )

    args = parser.parse_args()

    stats_cfg = load_stats_config(args.config)
    if args.metrics_profile:
        stats_cfg["_metrics_profile"] = args.metrics_profile
        os.environ["BENCHMARK_METRICS_PROFILE"] = args.metrics_profile
    logs_root = Path(args.logs_root)

    if args.list:
        print("Available result files (latest marked with *):")
        if not logs_root.is_dir():
            print(f"  (logs root {logs_root} not found)")
            return
        lang_dirs = sorted((d for d in logs_root.iterdir() if d.is_dir()), key=lambda p: p.name)
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

    # Start from auto-discovery under --logs-root, then apply --logs overrides.
    lang_paths: Dict[str, Optional[str]] = {
        k: v for k, v in _discover_logs(logs_root).items()
    }

    for spec in args.logs or []:
        lang, path = _resolve_logs_assignment(
            spec,
            languages=args.languages,
            logs_root=logs_root,
        )
        lang_paths[lang] = path

    # Resolve any remaining unresolved shorthands (should already be files from discover)
    for lang in list(lang_paths):
        val = lang_paths[lang]
        if val and not Path(val).is_file():
            lang_paths[lang] = _resolve_log_spec(val, logs_root=logs_root)

    lang_paths = _filter_lang_paths(lang_paths, args.languages)
    if args.languages and not any(lang_paths.values()):
        print("No log files found for the requested --language filter.")
        sys.exit(1)

    all_records: Dict[str, List[Dict]] = {}
    all_stats: Dict = {}
    total_loaded = 0
    total_sanitized = 0
    for lang, path in lang_paths.items():
        if not path or not os.path.isfile(path):
            all_records[lang] = []
            continue
        recs, skipped = parse_csv_file(path, language_hint=lang)
        total_loaded += len(recs)
        if recs:
            # One sanitize pass → same population for tables and latency distributions.
            clean, meta = prepare_analysis_records(
                recs, config=stats_cfg, language_hint=lang
            )
            all_records[lang] = clean
            total_sanitized += len(clean)
            st = compute_statistics(
                clean,
                config=stats_cfg,
                language_hint=lang,
                pre_sanitized=True,
                group_meta=meta,
            )
            all_stats.update(st)
            
            # Export to machine-readable JSON: reports/stats_<lang>_latest.json
            try:
                import json
                import datetime
                os.makedirs(str(reports_root), exist_ok=True)
                groups_list = []
                for entry in st.values():
                    # Strip private helper keys (like _times_total_filtered)
                    clean_entry = {k: v for k, v in entry.items() if not k.startswith("_")}
                    groups_list.append(clean_entry)
                
                # Dynamic Pareto front computation
                pareto_front = []
                workloads = {}
                for g in groups_list:
                    wkey = (g["test_data"], g["mode"])
                    workloads.setdefault(wkey, []).append(g)
                for wkey, items in workloads.items():
                    for item in items:
                        dominated = False
                        for other in items:
                            if other == item:
                                continue
                            if ((other["avg_time_total_ns"] <= item["avg_time_total_ns"] and other["median_size_bytes"] < item["median_size_bytes"]) or
                                (other["avg_time_total_ns"] < item["avg_time_total_ns"] and other["median_size_bytes"] <= item["median_size_bytes"])):
                                dominated = True
                                break
                        if not dominated:
                            pareto_front.append({
                                "serializer": item["serializer"],
                                "test_data": item["test_data"],
                                "mode": item["mode"],
                                "time": item["avg_time_total_ns"],
                                "size": item["median_size_bytes"]
                            })

                export_data = {
                    "schema_version": "2.0",
                    "generated": datetime.datetime.now().isoformat(),
                    "language": lang,
                    "questions": {
                        "Q1": "How fast?",
                        "Q2": "How compact?",
                        "Q3": "How stable?",
                        "Q4": "Under which workloads does it win?"
                    },
                    "groups": groups_list,
                    "pareto_front": pareto_front
                }
                latest_json_path = reports_root / f"stats_{lang}_latest.json"
                with open(latest_json_path, "w", encoding="utf-8") as f:
                    json.dump(export_data, f, indent=2)
            except Exception as e:
                print(f"Warning: Failed to export stats JSON for {lang}: {e}")

            print(
                f"Loaded {len(recs)} {lang} records from {os.path.basename(path)} "
                f"-> {len(clean)} after sanitize, {len(st)} stat groups "
                f"(parse-skipped {skipped})"
            )
        else:
            all_records[lang] = []

    print(
        f"Total: {total_loaded} raw records, {total_sanitized} sanitized, "
        f"{len(all_stats)} stat groups"
    )

    os.makedirs(str(reports_root), exist_ok=True)

    repo_root = _repo_root()
    docs_dir = repo_root / "docs"
    docs_analysis = docs_dir / "analysis"
    publish_root = docs_analysis if docs_analysis.is_dir() else reports_root

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
                stats_config=stats_cfg,
                pre_sanitized=True,
            )

    if args.compare_a and args.compare_b:
        ca = _resolve_log_spec(args.compare_a, logs_root=logs_root)
        cb = _resolve_log_spec(args.compare_b, logs_root=logs_root)
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

    # Regression gate: never save a degraded baseline when a regression is detected.
    # --save-baseline only runs after a clean check (or when check is not requested).
    if args.check_regression:
        reg_cfg = load_regression_config()
        if args.regression_combine:
            reg_cfg["combine"] = args.regression_combine
        has_regression, regressions = check_regression(
            all_stats,
            args.baseline_file,
            args.regression_threshold,
            config=reg_cfg,
        )
        details = getattr(check_regression, "last_details", []) or []
        # Summary counts
        from collections import Counter

        counts = Counter(d.get("classification") for d in details)
        print(
            "Regression check "
            f"(combine={reg_cfg.get('combine')}, threshold={args.regression_threshold}%): "
            f"regression={counts.get('regression', 0)} "
            f"unclear={counts.get('unclear', 0)} "
            f"equivalent={counts.get('equivalent', 0)} "
            f"improvement={counts.get('improvement', 0)} "
            f"ok={counts.get('ok', 0)}"
        )
        # Machine-readable report
        try:
            import json
            import datetime

            report_path = Path(args.baseline_file).resolve().parent / "regression_report.json"
            report_path.parent.mkdir(parents=True, exist_ok=True)
            with open(report_path, "w", encoding="utf-8") as rf:
                json.dump(
                    {
                        "generated": datetime.datetime.now().isoformat(),
                        "baseline_file": args.baseline_file,
                        "combine": reg_cfg.get("combine"),
                        "threshold_percent": args.regression_threshold,
                        "metric": reg_cfg.get("metric"),
                        "counts": dict(counts),
                        "has_regression": has_regression,
                        "messages": regressions,
                        "details": details,
                    },
                    rf,
                    indent=2,
                )
            print(f"Regression report: {report_path}")
        except Exception as exc:
            print(f"Warning: could not write regression_report.json: {exc}")

        if has_regression:
            print(f"REGRESSION: {counts.get('regression', 0)} entries failed the gate")
            for r in regressions[:20]:
                if r.startswith("REGRESSION"):
                    print(f"  {r}")
            if args.save_baseline:
                print(
                    "Note: --save-baseline skipped because a regression was detected "
                    "(baseline must not be overwritten with degraded performance)."
                )
            sys.exit(1)

    if args.save_baseline:
        reg_cfg = load_regression_config()
        save_baseline(all_stats, args.baseline_file, config=reg_cfg)
        print(f"Saved baseline to {args.baseline_file}")


if __name__ == "__main__":
    main()
