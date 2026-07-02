"""Benchmark analysis package for serializer performance data."""

__version__ = "0.1.0"

__all__ = [
    "parse_csv_file",
    "compute_statistics",
    "generate_violin_plots",
    "generate_language_results_pages",
    "check_regression",
    "save_baseline",
    "capture_environment",
    "load_environment",
]


def __getattr__(name: str):
    """Lazy-load submodules so light tools (e.g. environment capture) need no numpy/matplotlib."""
    if name == "parse_csv_file":
        from .parser import parse_csv_file
        return parse_csv_file
    if name == "compute_statistics":
        from .stats import compute_statistics
        return compute_statistics
    if name in ("check_regression", "save_baseline"):
        from . import regression as _regression
        return getattr(_regression, name)
    if name in ("capture_environment", "load_environment"):
        from . import environment as _environment
        return getattr(_environment, name)
    if name in (
        "generate_violin_plots",
        "generate_language_results_pages",
    ):
        from . import reports as _reports
        return getattr(_reports, name)
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")
