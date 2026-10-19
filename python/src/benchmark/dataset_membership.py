"""Which data sets the Python runner times for each serializer.

Membership is ``serializer_data_sets`` in ``config/benchmark_config.yaml``.
A name that is absent is suite only. This check is exact. The runner's
comma filter is still a substring match, so it cannot express the map:
``dagr-frozen`` would also select ``dagr-frozen-packed``.
"""

from __future__ import annotations

import sys
from pathlib import Path


def dataset_allows(name: str, type_id: str) -> bool:
    """True when ``name`` is measured on the data set that owns ``type_id``."""
    try:
        from benchmark_analysis.serializer_data_sets import measures_type
    except ImportError:
        root = Path(__file__).resolve().parents[3]
        src = str(root / "analysis" / "src")
        if src not in sys.path:
            sys.path.insert(0, src)
        from benchmark_analysis.serializer_data_sets import measures_type
    return bool(measures_type("python", name, type_id))
