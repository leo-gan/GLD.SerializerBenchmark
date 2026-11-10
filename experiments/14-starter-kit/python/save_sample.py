#!/usr/bin/env python3
"""Build the shared experiment record from this folder's experiment.yaml."""

from __future__ import annotations

import sys
from pathlib import Path

EXPERIMENT = Path(__file__).resolve().parents[1]
LIB = EXPERIMENT.parents[0] / "lib"
if str(LIB) not in sys.path:
    sys.path.insert(0, str(LIB))

from save_sample import save_experiment_sample


def main(argv: list[str] | None = None) -> int:
    return save_experiment_sample(EXPERIMENT, argv,
        about=(
            "This is the shared Experiment 14 record (one order-like value). "
            "It was built from experiment.yaml with the same builder and "
            "seed as the benchmark. Do not edit by hand. If experiment.yaml "
            "changes, run python/save_sample.py again."
        ),
    )


if __name__ == "__main__":
    raise SystemExit(main())
