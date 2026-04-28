"""Regression detection and baseline management."""

import json
import os
from typing import Dict, List, Tuple


def check_regression(
    current_stats: Dict,
    baseline_path: str,
    threshold_percent: float
) -> Tuple[bool, List[str]]:
    """Check for performance regressions against baseline."""
    if not os.path.exists(baseline_path):
        print(f"Warning: Baseline file not found: {baseline_path}")
        return False, []

    with open(baseline_path, 'r') as f:
        baseline = json.load(f)

    regressions = []
    has_regression = False

    for key, current in current_stats.items():
        key_str = f"{current['serializer']}|{current['test_data']}|{current['mode']}"
        if key_str in baseline:
            baseline_time = baseline[key_str].get('avg_time_total_ns', 0)
            current_time = current['avg_time_total_ns']

            if baseline_time > 0:
                increase_pct = ((current_time - baseline_time) / baseline_time) * 100
                if increase_pct > threshold_percent:
                    has_regression = True
                    regressions.append(
                        f"REGRESSION: {current['serializer']} on {current['test_data']} "
                        f"({current['mode']}) - "
                        f"{increase_pct:.1f}% slower "
                        f"({baseline_time:,.0f}ns → {current_time:,.0f}ns)"
                    )

    return has_regression, regressions


def save_baseline(stats: Dict, output_path: str) -> None:
    """Save current stats as baseline for future regression checks."""
    baseline = {}
    for key, stat in stats.items():
        key_str = f"{stat['serializer']}|{stat['test_data']}|{stat['mode']}"
        baseline[key_str] = {
            'avg_time_total_ns': stat['avg_time_total_ns'],
            'avg_ops_per_sec': stat['avg_ops_per_sec'],
            'median_size_bytes': stat['median_size_bytes']
        }

    with open(output_path, 'w') as f:
        json.dump(baseline, f, indent=2)

    print(f"Baseline saved to: {output_path}")
