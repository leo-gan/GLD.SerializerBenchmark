#!/usr/bin/env python3
import os
import sys
import json
import glob
import re

from snapshot_io import load_json_gz, write_json_gz
from splice_rows import (
    carry_spliced_groups as _carry_spliced_groups,
    refuse_splice_loss as _refuse_splice_loss,
)

# Timestamped benchmark logs: YYYY-MM-DD-HHMMSS.csv
# Columnar, Dagr, graph, array, and tensor publication CSVs use non-timestamped
# stems so they are NOT selected here; splice-*-stats.py appends those groups
# and splice_rows.py guards them against accidental removal.
_RUN_CSV = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")


def find_latest_run(lang_logs_dir):
    """Find the most recent run based on timestamped CSV files."""
    if not os.path.isdir(lang_logs_dir):
        return None
    runs = []
    for f in os.listdir(lang_logs_dir):
        match = _RUN_CSV.match(f)
        if match:
            runs.append(match.group(1))
    if not runs:
        return None
    runs.sort(reverse=True)
    return runs[0]

def list_all_runs(lang_logs_dir):
    """List all timestamped runs for a language."""
    if not os.path.isdir(lang_logs_dir):
        return []
    runs = set()
    for f in os.listdir(lang_logs_dir):
        match = _RUN_CSV.match(f)
        if match:
            runs.add(match.group(1))
    return sorted(list(runs), reverse=True)

def main():
    script_dir = os.path.dirname(os.path.abspath(__file__))
    project_root = os.path.dirname(script_dir) # dashboard dir
    repo_root = os.path.dirname(project_root)  # repository root

    source_reports_dir = os.path.join(repo_root, "reports")
    source_logs_dir = os.path.join(repo_root, "logs")
    target_data_dir = os.path.join(project_root, "public", "data")
    
    print(f"Project root: {project_root}")
    print(f"Repo root: {repo_root}")

    # Ensure target directory exists
    os.makedirs(target_data_dir, exist_ok=True)

    sources_src = os.path.join(repo_root, "config", "serializer-sources.json")
    sources_dst = os.path.join(target_data_dir, "serializer-sources.json")
    if os.path.isfile(sources_src):
        import shutil
        shutil.copy2(sources_src, sources_dst)
        print(f"Copied serializer-sources.json → {sources_dst}")

    languages = ["csharp", "rust", "go", "python", "javascript", "c", "java", "kotlin", "php", "cpp", "swift", "zig", "mojo", "fortran"]
    available_runs = {}

    for lang in languages:
        lang_logs_dir = os.path.join(source_logs_dir, lang)
        
        # 1. Discover all historical runs for this language
        runs = list_all_runs(lang_logs_dir)
        available_runs[lang] = runs
        
        # 2. Package latest run
        latest_run = find_latest_run(lang_logs_dir)
        if not latest_run:
            print(f"No runs found for language: {lang}")
            continue

        print(f"Processing latest run for {lang}: {latest_run}")
        
        csv_file = os.path.join(lang_logs_dir, f"{latest_run}.csv")
        config_file = os.path.join(lang_logs_dir, f"{latest_run}.configs.json")
        if not os.path.exists(config_file):
            config_file = os.path.join(lang_logs_dir, f"{latest_run}.environment.json")
            
        error_file = os.path.join(lang_logs_dir, f"{latest_run}.errors.csv")
        stats_file = os.path.join(source_reports_dir, f"stats_{lang}_latest.json")
        
        # Load contents
        csv_data = ""
        if os.path.exists(csv_file):
            with open(csv_file, "r", encoding="utf-8") as f:
                csv_data = f.read()

        configs_data = {}
        if os.path.exists(config_file):
            try:
                with open(config_file, "r", encoding="utf-8") as f:
                    configs_data = json.load(f)
            except Exception as e:
                print(f"Error loading configs JSON: {e}")

        errors_data = ""
        if os.path.exists(error_file):
            with open(error_file, "r", encoding="utf-8") as f:
                errors_data = f.read()

        stats_data = {}
        if os.path.exists(stats_file):
            try:
                with open(stats_file, "r", encoding="utf-8") as f:
                    stats_data = json.load(f)
            except Exception as e:
                print(f"Error loading stats JSON: {e}")

        if stats_data.get("groups"):
            src = os.path.join(repo_root, "analysis", "src")
            if src not in sys.path:
                sys.path.insert(0, src)
            from benchmark_analysis.dimensions import label_stats_document
            labeled = label_stats_document(stats_data)
            print(f"Labeled {labeled} {lang} groups with standard and data_set")

        # Multi-policy stats as gzip only (schema 2.2; recommendation A).
        # Dashboard prefers stats_<lang>_latest.json.gz over plain JSON.
        dest_stats_path = os.path.join(target_data_dir, f"stats_{lang}_latest.json")
        dest_stats_gz_path = os.path.join(target_data_dir, f"stats_{lang}_latest.json.gz")
        existing_stats = {}
        if os.path.exists(dest_stats_gz_path):
            existing_stats = load_json_gz(dest_stats_gz_path)
        _carry_spliced_groups(lang, existing_stats, stats_data)
        _refuse_splice_loss(lang, existing_stats, stats_data)
        if stats_data:
            print(f"Writing gzipped stats to: {dest_stats_gz_path}")
            write_json_gz(dest_stats_gz_path, stats_data)
            # Remove plain JSON if present (avoid double storage in git)
            if os.path.exists(dest_stats_path):
                print(f"Removing plain stats file: {dest_stats_path}")
                os.remove(dest_stats_path)
        else:
            removed = False
            for p in (dest_stats_path, dest_stats_gz_path):
                if os.path.exists(p):
                    print(f"Removing stale stats file: {p}")
                    os.remove(p)
                    removed = True
            if removed:
                from bench_versions import save_language_versions
                save_language_versions(target_data_dir, lang, None)

        # Run metadata only. The stats document is stats_<lang>_latest.json.gz.
        # Omit full CSV by default (multi-MB); set DASHBOARD_INCLUDE_CSV=1 to embed.
        include_csv = os.environ.get("DASHBOARD_INCLUDE_CSV", "").strip() in ("1", "true", "yes")
        payload = {
            "language": lang,
            "run_id": latest_run,
            "configs": configs_data,
            "errors": errors_data,
        }
        if include_csv:
            payload["csv_data"] = csv_data
        elif csv_data:
            payload["csv_omitted"] = True
            payload["csv_bytes"] = len(csv_data.encode("utf-8"))

        dest_gzip_path = os.path.join(target_data_dir, f"{lang}_latest.json.gz")
        print(f"Saving compressed payload to: {dest_gzip_path}")
        write_json_gz(dest_gzip_path, payload)

    # Regression baselines stay in reports/baseline.json (gitignored).
    # The dashboard does not read that file.

    # 3. Save metadata of available runs
    available_runs_path = os.path.join(target_data_dir, "available_runs.json")
    print(f"Saving available runs list to: {available_runs_path}")
    with open(available_runs_path, "w", encoding="utf-8") as f:
        json.dump(available_runs, f, indent=2)

    # 4. Create symlink for logs in public directory for historical downloads
    public_logs_symlink = os.path.join(project_root, "public", "logs")
    if not os.path.exists(public_logs_symlink):
        try:
            print(f"Creating symlink: {public_logs_symlink} -> {source_logs_dir}")
            os.symlink(source_logs_dir, public_logs_symlink)
        except Exception as e:
            print(f"Warning: Could not create symlink (might require admin or filesystem support): {e}")
            print("Historical run download fallback: Please make sure logs folder is accessible.")
    else:
        print("Symlink to logs directory already exists.")

    print("Sync complete.")

    # Experiment catalog is independent of language-latest payloads.
    exp_script = os.path.join(script_dir, "sync-experiments.py")
    if os.path.isfile(exp_script):
        import subprocess
        print("Syncing experiment catalog...")
        subprocess.check_call([sys.executable, exp_script])

if __name__ == "__main__":
    main()
