#!/usr/bin/env python3
import os
import sys
import argparse
import glob

def main():
    parser = argparse.ArgumentParser(description="Prune old benchmark run files (CSVs, configs, errors) in the logs/ folder.")
    parser.add_argument(
        "--leave-last-n", 
        type=int, 
        default=1, 
        help="Number of latest runs to keep per language. (default: 1)"
    )
    parser.add_argument(
        "--dry-run", 
        action="store_true", 
        help="Simulate the cleanup and print files that would be deleted without actually deleting them."
    )
    parser.add_argument(
        "--lang", 
        type=str, 
        default=None, 
        help="Only clean up logs for the specified language ID (e.g. csharp, python)."
    )
    args = parser.parse_args()

    if args.leave_last_n < 1:
        print("Error: --leave-last-n must be at least 1.", file=sys.stderr)
        sys.exit(1)

    # Resolve logs/ directory
    script_dir = os.path.dirname(os.path.realpath(__file__))
    project_root = os.path.dirname(script_dir)
    logs_root = os.path.join(project_root, "logs")

    if not os.path.isdir(logs_root):
        print(f"Error: logs folder not found at '{logs_root}'.", file=sys.stderr)
        sys.exit(1)

    print(f"Scanning for logs to clean under: {logs_root}")
    if args.dry_run:
        print("=== DRY RUN MODE: No files will be deleted ===")

    total_deleted = 0
    total_kept = 0

    # Each folder in logs/ is a language folder
    lang_folders = [f for f in os.listdir(logs_root) if os.path.isdir(os.path.join(logs_root, f))]

    for lang in sorted(lang_folders):
        if args.lang and lang.lower() != args.lang.lower():
            continue
        lang_dir = os.path.join(logs_root, lang)
        
        # Discover all CSV files to identify run IDs, ignoring .errors.csv
        all_csvs = glob.glob(os.path.join(lang_dir, "*.csv"))
        csv_files = [f for f in all_csvs if not f.endswith(".errors.csv")]
        if not csv_files:
            continue

        # Extract run IDs (stems of main CSV files)
        run_ids = sorted([os.path.splitext(os.path.basename(f))[0] for f in csv_files])
        
        # Determine runs to keep and delete
        runs_to_keep = run_ids[-args.leave_last_n:]
        runs_to_delete = run_ids[:-args.leave_last_n]

        print(f"\nLanguage: {lang}")
        print(f"  Total runs found: {len(run_ids)}")
        print(f"  Keeping runs: {', '.join(runs_to_keep) if runs_to_keep else 'None'}")
        
        if not runs_to_delete:
            print("  No old runs to clean.")
            total_kept += len(runs_to_keep)
            continue

        print(f"  Pruning {len(runs_to_delete)} old run(s)...")

        for run_id in runs_to_delete:
            # Files to delete for this run (main data, error CSV, configs JSON, errors JSON)
            patterns = [
                os.path.join(lang_dir, f"{run_id}.csv"),
                os.path.join(lang_dir, f"{run_id}.errors.csv"),
                os.path.join(lang_dir, f"{run_id}_configs.json"),
                os.path.join(lang_dir, f"{run_id}_errors.json")
            ]

            for file_path in patterns:
                if os.path.isfile(file_path):
                    if args.dry_run:
                        print(f"    [Dry-run] Would delete: {os.path.basename(file_path)}")
                    else:
                        try:
                            os.remove(file_path)
                            print(f"    Deleted: {os.path.basename(file_path)}")
                        except Exception as e:
                            print(f"    Error deleting {os.path.basename(file_path)}: {e}", file=sys.stderr)
                    total_deleted += 1
        
        total_kept += len(runs_to_keep)

    print("\n=============================================")
    if args.dry_run:
        print(f"Dry run complete. Would delete {total_deleted} files. Kept {total_kept} runs.")
    else:
        print(f"Cleanup complete. Deleted {total_deleted} files. Kept {total_kept} runs.")
    print("=============================================")

if __name__ == "__main__":
    main()
