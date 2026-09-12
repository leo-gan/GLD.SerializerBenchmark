"""CLI used by ``./scripts/run-compliance.sh``.

Library deviations are printed with spec URLs. Exit 0 unless the catalog
itself is unreadable.
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

from .report import format_detailed, format_summary, write_json
from .runner import run_suites


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(
        description=(
            "Run serialization compliance suites (spec quality). "
            "Library deviations are reported, not treated as a process failure."
        )
    )
    parser.add_argument(
        "--format",
        dest="formats",
        action="append",
        metavar="NAME",
        help="Limit to a format (repeatable): json, yaml, toml, cbor, msgpack",
    )
    parser.add_argument(
        "--serializer",
        "--adapter",
        dest="serializers",
        action="append",
        metavar="NAME",
        help="Limit to a serializer (repeatable): json, orjson, msgspec, yaml, …",
    )
    parser.add_argument(
        "--json-out",
        type=Path,
        default=None,
        help="Write a machine-readable report to this path",
    )
    parser.add_argument(
        "--detailed",
        action="store_true",
        help="Print every case, not only the summary and failures",
    )
    args = parser.parse_args(argv)

    report = run_suites(formats=args.formats, adapter_names=args.serializers)
    text = format_detailed(report) if args.detailed else format_summary(report)
    print(text)
    if args.json_out:
        write_json(report, args.json_out)
        print(f"\nWrote {args.json_out}")

    if report.catalog_errors:
        return 2
    return 0


if __name__ == "__main__":
    sys.exit(main())
