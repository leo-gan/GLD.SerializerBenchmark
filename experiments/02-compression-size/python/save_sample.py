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
    return save_experiment_sample(EXPERIMENT, argv)


if __name__ == "__main__":
    raise SystemExit(main())
