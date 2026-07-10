"""Benchmark entrypoint — Data Model v2 fixtures only. All serializers preserved."""

from __future__ import annotations

import sys

from .runner_v2 import (
    ALL_SERIALIZERS,
    _default_log_dir,
    _repo_root,
    main as main_v2,
    run_v2,
)

__all__ = [
    "ALL_SERIALIZERS",
    "main",
    "run_v2",
    "_default_log_dir",
    "_repo_root",
]


def main() -> None:
    args = sys.argv[1:]
    cleaned: list[str] = []
    i = 0
    while i < len(args):
        if args[i] == "--data-model":
            i += 2
            continue
        cleaned.append(args[i])
        i += 1
    sys.argv = [sys.argv[0]] + cleaned
    main_v2()


if __name__ == "__main__":
    main()
