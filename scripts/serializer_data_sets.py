#!/usr/bin/env python3
"""Print the default serializer filter for one language and run config.

Suite run configs print ``SKIP``: the caller keeps its own filter.
A specialized set prints a comma-separated exact allow-list, or
``__none__`` when that language has no row on the set.

Runners that do not treat a comma list as exact names also get ``SKIP``.
Python applies the map in-process. C, Mojo, PHP, Swift, and Zig treat the
whole filter as one substring, so a comma list would select nothing.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

_REPO = Path(__file__).resolve().parent.parent
_ANALYSIS_SRC = _REPO / "analysis" / "src"
if str(_ANALYSIS_SRC) not in sys.path:
    sys.path.insert(0, str(_ANALYSIS_SRC))

from benchmark_analysis.serializer_data_sets import (  # noqa: E402
    SerializerDataSetError,
    default_filter,
    uses_exact_comma_filter,
)


def main(argv: list[str] | None = None) -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument("--lang", required=True, help="Language id, such as python or csharp")
    ap.add_argument("--run-config", type=Path, help="Library run config YAML")
    ap.add_argument(
        "--exact-comma-filter",
        action="store_true",
        help="Print yes when this language's comma filter is exact names",
    )
    args = ap.parse_args(argv)
    try:
        if args.exact_comma_filter:
            print("yes" if uses_exact_comma_filter(args.lang) else "no")
            return 0
        if args.run_config is None:
            ap.error("--run-config is required unless --exact-comma-filter is set")
        print(default_filter(args.lang, args.run_config))
    except SerializerDataSetError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
