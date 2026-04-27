"""Statistics computation for benchmark data."""

from collections import defaultdict
from typing import Dict, List

import numpy as np


def compute_statistics(records: List[Dict]) -> Dict:
    """Compute aggregate statistics by serializer and test data."""
    stats = defaultdict(lambda: {
        'times_ser': [],
        'times_deser': [],
        'times_total': [],
        'sizes': [],
        'ops_per_sec': [],
        'test_data': set(),
        'modes': set()
    })

    for r in records:
        key = (r['SerializerName'], r['TestDataName'], r['StringOrStream'])
        stats[key]['times_ser'].append(r['TimeSer'])
        stats[key]['times_deser'].append(r['TimeDeser'])
        stats[key]['times_total'].append(r['TimeSerAndDeser'])
        stats[key]['sizes'].append(r['Size'])
        stats[key]['ops_per_sec'].append(r['OpPerSecSerAndDeser'])
        stats[key]['test_data'].add(r['TestDataName'])
        stats[key]['modes'].add(r['StringOrStream'])

    # Compute aggregates
    results = {}
    for key, data in stats.items():
        results[key] = {
            'serializer': key[0],
            'test_data': key[1],
            'mode': key[2],
            'avg_time_ser_ns': np.mean(data['times_ser']) * 100 if data['times_ser'] else 0,
            'avg_time_deser_ns': np.mean(data['times_deser']) * 100 if data['times_deser'] else 0,
            'avg_time_total_ns': np.mean(data['times_total']) * 100 if data['times_total'] else 0,
            'median_size_bytes': np.median(data['sizes']) if data['sizes'] else 0,
            'avg_ops_per_sec': np.mean(data['ops_per_sec']) if data['ops_per_sec'] else 0,
            'min_ops_per_sec': np.min(data['ops_per_sec']) if data['ops_per_sec'] else 0,
            'max_ops_per_sec': np.max(data['ops_per_sec']) if data['ops_per_sec'] else 0,
            'runs': len(data['times_ser'])
        }
    return results
