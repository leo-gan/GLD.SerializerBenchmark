#!/usr/bin/env python3
import os
import sys
import json
import gzip
import glob
import re

def find_latest_run(lang_logs_dir):
    """Find the most recent run based on timestamped CSV files."""
    if not os.path.isdir(lang_logs_dir):
        return None
    # Match YYYY-MM-DD-HHMMSS.csv
    pattern = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")
    runs = []
    for f in os.listdir(lang_logs_dir):
        match = pattern.match(f)
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
    pattern = re.compile(r"^(\d{4}-\d{2}-\d{2}-\d{6})\.csv$")
    runs = set()
    for f in os.listdir(lang_logs_dir):
        match = pattern.match(f)
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

    languages = ["csharp", "rust", "go", "python", "javascript", "c", "java", "cpp", "swift"]
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

        # Multi-policy stats as gzip only (schema 2.2; recommendation A).
        # Dashboard prefers stats_<lang>_latest.json.gz over plain JSON.
        dest_stats_path = os.path.join(target_data_dir, f"stats_{lang}_latest.json")
        dest_stats_gz_path = os.path.join(target_data_dir, f"stats_{lang}_latest.json.gz")
        if stats_data:
            stats_bytes = json.dumps(stats_data, indent=None, separators=(",", ":")).encode(
                "utf-8"
            )
            print(f"Writing gzipped stats to: {dest_stats_gz_path} ({len(stats_bytes)} raw bytes)")
            with gzip.open(dest_stats_gz_path, "wb", compresslevel=9) as f:
                f.write(stats_bytes)
            # Remove plain JSON if present (avoid double storage in git)
            if os.path.exists(dest_stats_path):
                print(f"Removing plain stats file: {dest_stats_path}")
                os.remove(dest_stats_path)
        else:
            for p in (dest_stats_path, dest_stats_gz_path):
                if os.path.exists(p):
                    print(f"Removing stale stats file: {p}")
                    os.remove(p)

        # Assemble compact payload.
        # Omit full CSV by default (multi-MB); set DASHBOARD_INCLUDE_CSV=1 to embed.
        include_csv = os.environ.get("DASHBOARD_INCLUDE_CSV", "").strip() in ("1", "true", "yes")
        payload = {
            "language": lang,
            "run_id": latest_run,
            "stats": stats_data,
            "configs": configs_data,
            "errors": errors_data,
        }
        if include_csv:
            payload["csv_data"] = csv_data
        elif csv_data:
            payload["csv_omitted"] = True
            payload["csv_bytes"] = len(csv_data.encode("utf-8"))

        # Write as gzip-compressed JSON
        dest_gzip_path = os.path.join(target_data_dir, f"{lang}_latest.json.gz")
        print(f"Saving compressed payload to: {dest_gzip_path}")
        
        json_bytes = json.dumps(payload, indent=None).encode("utf-8")
        with gzip.open(dest_gzip_path, "wb") as f:
            f.write(json_bytes)

    # 3. Write baseline.json if it exists
    baseline_src = os.path.join(source_reports_dir, "baseline.json")
    if os.path.exists(baseline_src):
        baseline_dest = os.path.join(target_data_dir, "baseline.json")
        import shutil
        print(f"Copying baseline.json to target...")
        shutil.copy2(baseline_src, baseline_dest)

    # 4. Save metadata of available runs
    available_runs_path = os.path.join(target_data_dir, "available_runs.json")
    print(f"Saving available runs list to: {available_runs_path}")
    with open(available_runs_path, "w", encoding="utf-8") as f:
        json.dump(available_runs, f, indent=2)

    # 5. Create symlink for logs in public directory for historical downloads
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
