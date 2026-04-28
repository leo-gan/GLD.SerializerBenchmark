"""CSV parsing utilities for benchmark data."""

import csv
from typing import Dict, List


def parse_csv_file(filepath: str) -> List[Dict]:
    """Parse benchmark CSV file and return list of records."""
    records = []
    if not filepath or not __import__('os').path.exists(filepath):
        return records

    with open(filepath, 'r') as f:
        reader = csv.DictReader(f)
        for row in reader:
            try:
                record = {
                    'StringOrStream': row.get('StringOrStream', ''),
                    'TestDataName': row.get('TestDataName', ''),
                    'Repetitions': int(row.get('Repetitions', 0)),
                    'RepetitionIndex': int(row.get('RepetitionIndex', 0)),
                    'SerializerName': row.get('SerializerName', ''),
                    'TimeSer': int(row.get('TimeSer', 0)),
                    'TimeDeser': int(row.get('TimeDeser', 0)),
                    'Size': int(row.get('Size', 0)),
                    'TimeSerAndDeser': int(row.get('TimeSerAndDeser', 0)),
                    'OpPerSecSer': float(row.get('OpPerSecSer', 0)),
                    'OpPerSecDeser': float(row.get('OpPerSecDeser', 0)),
                    'OpPerSecSerAndDeser': float(row.get('OpPerSecSerAndDeser', 0)),
                }
                records.append(record)
            except (ValueError, KeyError) as e:
                print(f"Warning: Skipping malformed row: {row}, error: {e}")
    return records
