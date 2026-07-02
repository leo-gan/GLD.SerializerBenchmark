"""Regression detection and baseline management."""

import json
import os
from typing import Dict, List, Tuple


def check_regression(
    current_stats: Dict,
    baseline_path: str,
    threshold_percent: float
) -> Tuple[bool, List[str]]:
    """Check for performance regressions against baseline.

    Uses both a practical percentage threshold on the mean *and* the
    bootstrap confidence interval already computed by the stats pipeline.
    If the current 95% CI lower bound is still above the regression
    threshold relative to baseline, we have a statistically supported
    regression (not just noise).
    """
    if not os.path.exists(baseline_path):
        print(f"Warning: Baseline file not found: {baseline_path}")
        return False, []

    with open(baseline_path, "r", encoding="utf-8") as f:
        baseline = json.load(f)

    regressions = []
    has_regression = False

    factor = 1.0 + (threshold_percent / 100.0)

    for key, current in current_stats.items():
        key_str = f"{current.get('language','unknown')}|{current['serializer']}|{current['test_data']}|{current['mode']}"
        if key_str in baseline:
            baseline_time = baseline[key_str].get('avg_time_total_ns', 0)
            current_time = current['avg_time_total_ns']
            ci_low = current.get('total_ci_low_ns', current_time)

            if baseline_time > 0:
                increase_pct = ((current_time - baseline_time) / baseline_time) * 100
                # Practical threshold
                practical = increase_pct > threshold_percent
                # Statistical support: even the *lower* end of CI shows meaningful regression
                statistical = ci_low > (baseline_time * factor)

                if practical or statistical:
                    has_regression = True
                    how = " (CI-supported)" if statistical and not practical else ""
                    regressions.append(
                        f"REGRESSION: {current['serializer']} on {current['test_data']} "
                        f"({current['mode']}) - "
                        f"{increase_pct:.1f}% slower{how} "
                        f"({baseline_time:,.0f}ns → {current_time:,.0f}ns, "
                        f"CI low {ci_low:,.0f}ns)"
                    )

    return has_regression, regressions


def save_baseline(stats: Dict, output_path: str) -> None:
    """Save current stats as baseline for future regression checks."""
    baseline = {}
    for key, stat in stats.items():
        key_str = f"{stat.get('language','unknown')}|{stat['serializer']}|{stat['test_data']}|{stat['mode']}"
        baseline[key_str] = {
            'avg_time_total_ns': stat['avg_time_total_ns'],
            'avg_ops_per_sec': stat['avg_ops_per_sec'],
            'median_size_bytes': stat['median_size_bytes']
        }

    out_dir = os.path.dirname(output_path) or "."
    os.makedirs(out_dir, exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(baseline, f, indent=2)

    print(f"Baseline saved to: {output_path}")
