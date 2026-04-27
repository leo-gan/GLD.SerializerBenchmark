"""Benchmark analysis package for serializer performance data."""

from .parser import parse_csv_file
from .stats import compute_statistics
from .reports import generate_markdown_summary, generate_html_dashboard
from .regression import check_regression, save_baseline

__version__ = "0.1.0"
__all__ = [
    "parse_csv_file",
    "compute_statistics",
    "generate_markdown_summary",
    "generate_html_dashboard",
    "check_regression",
    "save_baseline",
]
