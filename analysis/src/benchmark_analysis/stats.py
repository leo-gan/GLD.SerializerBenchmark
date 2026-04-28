"""Statistics computation for benchmark data."""

from collections import defaultdict
from typing import Dict, List

import numpy as np


def _detect_time_unit(time_value: int) -> float:
    """Auto-detect time unit and return multiplier to nanoseconds.
    
    C# uses ticks (100ns) - values typically > 1,000,000
    Python uses nanoseconds - values typically < 100,000
    """
    if time_value > 1_000_000:
        return 100.0  # Ticks -> nanoseconds (C#)
    return 1.0  # Already nanoseconds (Python)


def compute_statistics(records: List[Dict]) -> Dict:
    """Compute aggregate statistics by serializer and test data."""
    stats = defaultdict(lambda: {
        'times_ser': [],
        'times_deser': [],
        'times_total': [],
        'sizes': [],
        'test_data': set(),
        'modes': set()
    })

    for r in records:
        key = (r['SerializerName'], r['TestDataName'], r['StringOrStream'])
        
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

    # Compute aggregates
    results = {}
    for key, data in stats.items():
        avg_time_total_ns = np.mean(data['times_total']) if data['times_total'] else 0
        # Recalculate Ops/Sec consistently: 1e9 / ns
        avg_ops_per_sec = 1e9 / avg_time_total_ns if avg_time_total_ns > 0 else 0
        min_ops_per_sec = 1e9 / np.max(data['times_total']) if data['times_total'] else 0
        max_ops_per_sec = 1e9 / np.min(data['times_total']) if data['times_total'] else 0

        results[key] = {
            'serializer': key[0],
            'test_data': key[1],
            'mode': key[2],
            'avg_time_ser_ns': np.mean(data['times_ser']) if data['times_ser'] else 0,
            'avg_time_deser_ns': np.mean(data['times_deser']) if data['times_deser'] else 0,
            'avg_time_total_ns': avg_time_total_ns,
            'median_size_bytes': np.median(data['sizes']) if data['sizes'] else 0,
            'avg_ops_per_sec': avg_ops_per_sec,
            'min_ops_per_sec': min_ops_per_sec,
            'max_ops_per_sec': max_ops_per_sec,
            'runs': len(data['times_ser'])
        }
    return results
