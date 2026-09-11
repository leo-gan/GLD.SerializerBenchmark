"""RFC / spec compliance runner for serialization formats.

The corpus lives under repo-root ``compliance/data/`` so it is not a
Python package dependency. Adapters call libraries already used by the
Python benchmark runner.
"""

from .catalog import corpus_root, load_all_suites, repo_root
from .models import Case, Suite
from .report import Report
from .runner import run_suites

__all__ = [
    "Case",
    "Report",
    "Suite",
    "corpus_root",
    "load_all_suites",
    "repo_root",
    "run_suites",
]
