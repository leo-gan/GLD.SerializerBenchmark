"""Environment capture for benchmark reproducibility.

Writes an environment.json sidecar beside the result CSV, recording the
hardware, OS, and runtime context of a benchmark run.

Usage from any language harness (Python example):

    from benchmark_analysis.environment import capture_environment
    capture_environment("logs/python/2026-06-12-123415.csv")

Or standalone (called from shell scripts):

    python -m benchmark_analysis.environment logs/rust/2026-06-12-123415.csv
"""

from __future__ import annotations

import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Optional


def _safe_run(cmd: list[str], **kwargs) -> str:
    """Run a command and return stripped stdout, or '' on failure."""
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=5, **kwargs)
        return r.stdout.strip()
    except Exception:
        return ""


def _cpu_info() -> Dict[str, Any]:
    """Gather CPU metadata (best-effort, cross-platform)."""
    info: Dict[str, Any] = {
        "architecture": platform.machine(),
        "logical_cores": os.cpu_count(),
    }

    # Linux: /proc/cpuinfo
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    info["model"] = line.split(":", 1)[1].strip()
                    break
    except OSError:
        pass

    # Linux: physical cores
    phys = _safe_run(["nproc", "--all"])
    if phys:
        info["physical_cores"] = int(phys)

    # macOS fallback
    if "model" not in info:
        model = _safe_run(["sysctl", "-n", "machdep.cpu.brand_string"])
        if model:
            info["model"] = model

    # CPU frequency (Linux)
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq") as f:
            khz = int(f.read().strip())
            info["max_freq_mhz"] = khz // 1000
    except (OSError, ValueError):
        pass

    # CPU governor (Linux)
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
            info["governor"] = f.read().strip()
    except OSError:
        pass

    return info


def _memory_info() -> Dict[str, Any]:
    """Total system RAM in bytes (best-effort)."""
    info: Dict[str, Any] = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    info["total_bytes"] = kb * 1024
                    break
    except OSError:
        # macOS
        val = _safe_run(["sysctl", "-n", "hw.memsize"])
        if val:
            info["total_bytes"] = int(val)
    return info


def _runtime_versions() -> Dict[str, str]:
    """Detect available language runtime versions."""
    versions: Dict[str, str] = {}

    versions["python"] = platform.python_version()

    node = _safe_run(["node", "--version"])
    if node:
        versions["node"] = node.lstrip("v")

    dotnet = _safe_run(["dotnet", "--version"])
    if dotnet:
        versions["dotnet"] = dotnet

    rustc = _safe_run(["rustc", "--version"])
    if rustc:
        versions["rustc"] = rustc

    gcc = _safe_run(["gcc", "--version"])
    if gcc:
        versions["gcc"] = gcc.split("\n")[0]

    return versions


def _git_info() -> Dict[str, str]:
    """Current git commit and dirty status."""
    info: Dict[str, str] = {}
    commit = _safe_run(["git", "rev-parse", "--short", "HEAD"])
    if commit:
        info["commit"] = commit
    dirty = _safe_run(["git", "status", "--porcelain"])
    if dirty is not None:
        info["dirty"] = bool(dirty)
    return info


def capture_environment(
    result_csv_path: Optional[str] = None,
    output_path: Optional[str] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Capture environment metadata and write environment.json.

    Args:
        result_csv_path: Path to the benchmark result CSV. The environment.json
            is written as a sibling (same directory, same stem + .environment.json).
        output_path: Explicit output path (overrides result_csv_path derivation).
        extra: Additional key-value pairs to include.

    Returns:
        The environment dict that was written.
    """
    env: Dict[str, Any] = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "benchmark_ts": os.environ.get("BENCHMARK_TS", ""),
        "os": {
            "system": platform.system(),
            "release": platform.release(),
            "version": platform.version(),
            "architecture": platform.machine(),
        },
        "cpu": _cpu_info(),
        "memory": _memory_info(),
        "runtimes": _runtime_versions(),
        "git": _git_info(),
        "process": {
            "pid": os.getpid(),
            "cwd": os.getcwd(),
        },
    }

    if extra:
        env.update(extra)

    # Determine output path
    if output_path is None and result_csv_path:
        p = Path(result_csv_path)
        output_path = str(p.with_suffix(".environment.json"))
    elif output_path is None:
        output_path = "environment.json"

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(env, f, indent=2, default=str)

    return env


def load_environment(result_csv_path: str) -> Optional[Dict[str, Any]]:
    """Load environment.json sidecar for a result CSV, if it exists."""
    p = Path(result_csv_path)
    env_path = p.with_suffix(".environment.json")
    if env_path.is_file():
        with open(env_path, encoding="utf-8") as f:
            return json.load(f)
    return None


# CLI entry point: python -m benchmark_analysis.environment <result.csv>
if __name__ == "__main__":
    csv_path = sys.argv[1] if len(sys.argv) > 1 else None
    env = capture_environment(csv_path)
    out = csv_path and str(Path(csv_path).with_suffix(".environment.json")) or "environment.json"
    print(f"Environment captured -> {out}")
    print(json.dumps(env, indent=2, default=str))
