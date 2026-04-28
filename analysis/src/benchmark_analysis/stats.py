"""Statistics computation for benchmark data."""

from collections import defaultdict
from typing import Dict, List, Tuple

import numpy as np


def _detect_time_unit(time_value: int) -> float:
    """Auto-detect time unit and return multiplier to nanoseconds.

    C# uses ticks (100ns) - values typically > 1,000,000
    Python uses nanoseconds - values typically < 100,000
    """
    if time_value > 1_000_000:
        return 100.0  # Ticks -> nanoseconds (C#)
    return 1.0  # Already nanoseconds (Python)


def _filter_outliers(values: List[float]) -> Tuple[List[float], int]:
    """Remove outliers per group using Tukey's IQR fences.

    Values outside [Q1 - 1.5*IQR, Q3 + 1.5*IQR] are discarded.
    For groups with < 10 measurements no filtering is applied.
    Returns (filtered_values, removed_count).
    """
    if len(values) < 10:
        return values, 0

    arr = np.array(values, dtype=float)
    q1 = np.percentile(arr, 25)
    q3 = np.percentile(arr, 75)
    iqr = q3 - q1
    lower = q1 - 1.5 * iqr
    upper = q3 + 1.5 * iqr
    mask = (arr >= lower) & (arr <= upper)

    # If IQR is 0 (all identical) or filtering removed everything, keep all
    if iqr == 0 or not mask.any():
        return values, 0

    filtered = arr[mask].tolist()
    removed = len(values) - len(filtered)
    return filtered, removed


def compute_statistics(records: List[Dict]) -> Dict:
    """Compute aggregate statistics by serializer and test data."""
    stats = defaultdict(lambda: {
        'times_ser': [],
        'times_deser': [],
        'times_total': [],
        'sizes': [],
        'test_data': set(),
        'modes': set(),
        'warmup_skipped': 0
    })

    for r in records:
        key = (r['SerializerName'], r['TestDataName'], r['StringOrStream'])

        # Skip warmup runs (RepetitionIndex 0) before any processing
        if r.get('RepetitionIndex', 0) == 0:
            stats[key]['warmup_skipped'] += 1
            continue

        # Auto-detect time units and normalize to nanoseconds
        multiplier = _detect_time_unit(r['TimeSer'])
        time_ser_ns = r['TimeSer'] * multiplier
        time_deser_ns = r['TimeDeser'] * multiplier
        time_total_ns = r['TimeSerAndDeser'] * multiplier

        stats[key]['times_ser'].append(time_ser_ns)
        stats[key]['times_deser'].append(time_deser_ns)
        stats[key]['times_total'].append(time_total_ns)
        stats[key]['sizes'].append(r['Size'])
        stats[key]['test_data'].add(r['TestDataName'])
        stats[key]['modes'].add(r['StringOrStream'])

    # Compute aggregates after outlier filtering
    total_outliers = 0
    results = {}
    for key, data in stats.items():
        times_total, removed_total = _filter_outliers(data['times_total'])
        times_ser, removed_ser = _filter_outliers(data['times_ser'])
        times_deser, removed_deser = _filter_outliers(data['times_deser'])
        total_outliers += removed_total

        avg_time_total_ns = np.mean(times_total) if times_total else 0
        # Recalculate Ops/Sec consistently: 1e9 / ns
        avg_ops_per_sec = 1e9 / avg_time_total_ns if avg_time_total_ns > 0 else 0
        min_ops_per_sec = 1e9 / np.max(times_total) if times_total else 0
        max_ops_per_sec = 1e9 / np.min(times_total) if times_total else 0

        results[key] = {
            'serializer': key[0],
            'test_data': key[1],
            'mode': key[2],
            'avg_time_ser_ns': np.mean(times_ser) if times_ser else 0,
            'avg_time_deser_ns': np.mean(times_deser) if times_deser else 0,
            'avg_time_total_ns': avg_time_total_ns,
            'median_size_bytes': np.median(data['sizes']) if data['sizes'] else 0,
            'avg_ops_per_sec': avg_ops_per_sec,
            'min_ops_per_sec': min_ops_per_sec,
            'max_ops_per_sec': max_ops_per_sec,
            'runs': len(times_total),
            'runs_raw': len(data['times_total']) + data['warmup_skipped'],
            'warmup_skipped': data['warmup_skipped'],
            'outliers_removed': removed_total
        }

    total_warmup = sum(data['warmup_skipped'] for data in stats.values())
    if total_warmup:
        print(f"Skipped {total_warmup} warmup measurements (RepetitionIndex 0)")
    if total_outliers:
        print(f"Removed {total_outliers} outlier measurements (IQR filter)")
    return results
