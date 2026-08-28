"""Run config / environment capture for benchmark reproducibility.

Writes a ``*.configs.json`` sidecar beside the result CSV:

- ``environment`` — hardware, OS, runtimes, git (preferred)
- ``dataset`` — optional: seed, fixtures, repetitions (best-effort)
- ``serializers`` — optional: names from the run (best-effort)
- ``run`` — optional: mode, metrics profile, timestamp

Legacy ``*.environment.json`` files are still loaded (treated as the
``environment`` block).

Usage::

    from benchmark_analysis.environment import capture_environment
    capture_environment("logs/python/2026-06-12-123415.csv")

Or::

    python -m benchmark_analysis.environment logs/rust/2026-06-12-123415.csv
"""

from __future__ import annotations

import hashlib
import json
import os
import platform
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional


def _safe_run(cmd: list[str], **kwargs) -> str:
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=5, **kwargs)
        out = (r.stdout or "").strip()
        if out:
            return out
        # Some tools (e.g. java -version) print only to stderr.
        return (r.stderr or "").strip()
    except Exception:
        return ""


def _cpu_info() -> Dict[str, Any]:
    info: Dict[str, Any] = {
        "architecture": platform.machine(),
        "logical_cores": os.cpu_count(),
    }
    try:
        with open("/proc/cpuinfo") as f:
            for line in f:
                if line.startswith("model name"):
                    info["model"] = line.split(":", 1)[1].strip()
                    break
    except OSError:
        pass
    nproc = _safe_run(["nproc", "--all"])
    if nproc:
        info["cpu_count"] = int(nproc)
        if not info.get("logical_cores"):
            info["logical_cores"] = int(nproc)
    if "model" not in info:
        model = _safe_run(["sysctl", "-n", "machdep.cpu.brand_string"])
        if model:
            info["model"] = model
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq") as f:
            khz = int(f.read().strip())
            info["max_freq_mhz"] = khz // 1000
    except (OSError, ValueError):
        pass
    try:
        with open("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor") as f:
            info["governor"] = f.read().strip()
    except OSError:
        pass
    return info


def _memory_info() -> Dict[str, Any]:
    info: Dict[str, Any] = {}
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemTotal:"):
                    kb = int(line.split()[1])
                    info["total_bytes"] = kb * 1024
                    break
    except OSError:
        val = _safe_run(["sysctl", "-n", "hw.memsize"])
        if val:
            info["total_bytes"] = int(val)
    return info


def _runtime_versions() -> Dict[str, str]:
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
    gxx = _safe_run(["g++", "--version"])
    if gxx:
        versions["g++"] = gxx.split("\n")[0]
    java = _safe_run(["java", "-version"])
    # java -version writes to stderr; _safe_run may capture either stream
    if java:
        versions["java"] = java.split("\n")[0]
    go = _safe_run(["go", "version"])
    if go:
        versions["go"] = go
    return versions


def _git_info() -> Dict[str, str]:
    info: Dict[str, Any] = {}
    commit = _safe_run(["git", "rev-parse", "--short", "HEAD"])
    if commit:
        info["commit"] = commit
    dirty = _safe_run(["git", "status", "--porcelain"])
    if dirty is not None:
        info["dirty"] = bool(dirty)
    return info


def _resolve_benchmark_ts(result_csv_path: Optional[str] = None) -> str:
    env_ts = (os.environ.get("BENCHMARK_TS") or "").strip()
    if env_ts:
        return env_ts
    if result_csv_path:
        stem = Path(result_csv_path).stem
        if len(stem) == 17 and stem[4] == "-" and stem[7] == "-" and stem[10] == "-":
            date_part, time_part = stem[:10], stem[11:]
            if time_part.isdigit() and len(time_part) == 6:
                try:
                    datetime.strptime(date_part, "%Y-%m-%d")
                    return stem
                except ValueError:
                    pass
    return ""


def _infer_language(result_csv_path: Optional[str]) -> str:
    if not result_csv_path:
        return (os.environ.get("BENCHMARK_LANGUAGE") or "").strip()
    low = str(result_csv_path).replace("\\", "/").lower()
    # Longer ids first so /logs/cpp/ is not mistaken for bare c.
    for token in ("csharp", "python", "rust", "javascript", "kotlin", "java", "php", "cpp", "swift", "zig", "go"):
        if f"/{token}/" in low:
            return token
    parts = [p for p in low.split("/") if p]
    if "cpp" in parts or "c++" in parts or "cxx" in parts:
        return "cpp"
    if "kotlin" in parts:
        return "kotlin"
    if "java" in parts:
        return "java"
    if "swift" in parts:
        return "swift"
    if "c" in parts:
        return "c"
    return (os.environ.get("BENCHMARK_LANGUAGE") or "").strip()


def _dataset_block() -> Dict[str, Any]:
    """Optional dataset generation / workload snapshot from master config + env."""
    block: Dict[str, Any] = {
        "seed": os.environ.get("BENCHMARK_SEED"),
        "mode": os.environ.get("BENCHMARK_MODE") or os.environ.get("MODE"),
        "repetitions": os.environ.get("BENCHMARK_REPETITIONS"),
    }
    try:
        from .config_loader import dig, load_master_config

        cfg = load_master_config()
        block["config_path"] = "config/benchmark_config.yaml"
        # Catalog is normative for suite fixtures.
        block["catalog_file"] = dig(
            cfg, "test_data.catalog_file",
            dig(cfg, "data_model_v2.catalog_file", "schemas/data_catalog_v2.yaml"),
        )
        # Legacy key kept for older readers of configs.json sidecars.
        block["test_data_config"] = block["catalog_file"]
        types = dig(cfg, "test_data.types") or []
        if isinstance(types, list) and types:
            block["fixtures"] = [
                {
                    "name": t.get("name"),
                    "category": t.get("category"),
                    "supports_circular": t.get("supports_circular"),
                }
                for t in types
                if isinstance(t, dict)
            ]
        block["warmup_repetitions"] = dig(cfg, "reproducibility.warmup_repetitions", 1)
        block["exclude_warmup_in_analysis"] = dig(cfg, "statistics.exclude_warmup", True)
        modes = cfg.get("modes") or {}
        if isinstance(modes, dict) and block.get("mode") in modes:
            block["mode_repetitions_config"] = (modes[block["mode"]] or {}).get("repetitions")
    except Exception as exc:
        block["config_error"] = str(exc)
    # Drop empty keys
    return {k: v for k, v in block.items() if v not in (None, "", [])}


def _serializers_block_from_csv(result_csv_path: Optional[str]) -> Dict[str, Any]:
    """Optional serializer inventory scraped from the result CSV (best-effort)."""
    if not result_csv_path or not Path(result_csv_path).is_file():
        return {}
    try:
        import csv

        names: Dict[str, str] = {}
        with open(result_csv_path, encoding="utf-8") as f:
            reader = csv.DictReader(f)
            for row in reader:
                n = (row.get("SerializerName") or "").strip()
                if not n:
                    continue
                ver = (row.get("SerializerVersion") or "").strip()
                # Prefer first non-empty version seen
                if n not in names or (ver and not names[n]):
                    names[n] = ver
        if not names:
            return {}
        return {
            "count": len(names),
            "items": [{"name": k, "version": v} for k, v in sorted(names.items())],
        }
    except Exception as exc:
        return {"error": str(exc)}


def _public_cwd(cwd: Optional[str] = None) -> str:
    """Return cwd as a repo-relative public path (no private absolute prefix).

    Format: ``<repo-dirname>[/<path-inside-repo>]``, e.g.
    ``seriailizer-benchmark/swift`` or ``seriailizer-benchmark`` when at root.

    This keeps ``*.configs.json`` sidecars free of host home-directory paths.
    """
    cwd_path = Path(cwd or os.getcwd()).resolve()
    try:
        from .config_loader import repo_root

        root = repo_root().resolve()
    except Exception:
        root = None
        for p in [cwd_path, *cwd_path.parents]:
            if (p / "config" / "benchmark_config.yaml").is_file():
                root = p
                break
    if root is None:
        # Outside monorepo: never emit a full home path; last component only.
        return cwd_path.name or "."

    repo_name = root.name
    try:
        rel = cwd_path.relative_to(root)
    except ValueError:
        return repo_name
    rel_s = rel.as_posix()
    if rel_s in (".", ""):
        return repo_name
    return f"{repo_name}/{rel_s}"


def _cpu_governor() -> Optional[str]:
    """Best-effort CPU frequency governor (Linux); None if unavailable."""
    # Prefer cpu0; do not require root.
    path = Path("/sys/devices/system/cpu/cpu0/cpufreq/scaling_governor")
    try:
        if path.is_file():
            return path.read_text(encoding="utf-8").strip() or None
    except OSError:
        pass
    return None


def _machine_id(cpu: Dict[str, Any], os_block: Dict[str, Any]) -> str:
    """Stable short fingerprint for multi-machine claims.

    Not a security identifier — only enough to tell “same host class” apart
    across sessions without storing the raw hostname in public docs by default.
    """
    parts = [
        str(cpu.get("model") or ""),
        str(cpu.get("architecture") or platform.machine() or ""),
        str(os_block.get("system") or platform.system() or ""),
        str(os_block.get("release") or ""),
        str(cpu.get("logical_cores") or os.cpu_count() or ""),
    ]
    # Optional: include hostname only in the hash material (not exported raw)
    # so two identical VMs on different hosts still differ when hostnames do.
    host = platform.node() or ""
    raw = "|".join(parts + [host])
    return hashlib.sha256(raw.encode("utf-8")).hexdigest()[:16]


def _gather_environment() -> Dict[str, Any]:
    cpu = _cpu_info()
    os_block = {
        "system": platform.system(),
        "release": platform.release(),
        "version": platform.version(),
        "architecture": platform.machine(),
    }
    gov = _cpu_governor()
    env: Dict[str, Any] = {
        "captured_at": datetime.now(timezone.utc).isoformat(),
        "os": os_block,
        "cpu": cpu,
        "memory": _memory_info(),
        "runtimes": _runtime_versions(),
        "git": _git_info(),
        "process": {
            "pid": os.getpid(),
            "cwd": _public_cwd(),
        },
        # Claim scoping (single-session default; multi-session uses machine_id)
        "machine_id": _machine_id(cpu, os_block),
        "claim_level_hint": "L1_single_session",
    }
    if gov is not None:
        env["cpu_governor"] = gov
    return env


def configs_path_for_csv(result_csv_path: str) -> Path:
    return Path(result_csv_path).with_suffix(".configs.json")


def legacy_environment_path_for_csv(result_csv_path: str) -> Path:
    return Path(result_csv_path).with_suffix(".environment.json")


def capture_environment(
    result_csv_path: Optional[str] = None,
    output_path: Optional[str] = None,
    extra: Optional[Dict[str, Any]] = None,
) -> Dict[str, Any]:
    """Capture run config / environment and write ``*.configs.json``.

    Returns the full sidecar document (schema_version 1).
    """
    include_env = True
    include_dataset = True
    include_serializers = True
    try:
        from .config_loader import dig, load_master_config

        cfg = load_master_config()
        include_env = bool(dig(cfg, "run_sidecar.include_environment", True))
        include_dataset = bool(dig(cfg, "run_sidecar.include_dataset", True))
        include_serializers = bool(dig(cfg, "run_sidecar.include_serializers", True))
    except Exception:
        pass

    ts = _resolve_benchmark_ts(result_csv_path)
    lang = _infer_language(result_csv_path)
    doc: Dict[str, Any] = {
        "schema_version": 1,
        "benchmark_ts": ts,
        "language": lang or None,
    }
    if include_env:
        doc["environment"] = _gather_environment()
        doc["environment"]["benchmark_ts"] = ts

    if include_dataset:
        ds = _dataset_block()
        if ds:
            doc["dataset"] = ds

    run_block: Dict[str, Any] = {
        "benchmark_ts": ts,
        "seed": os.environ.get("BENCHMARK_SEED"),
        "mode": os.environ.get("BENCHMARK_MODE") or os.environ.get("MODE"),
        "metrics_profile": os.environ.get("BENCHMARK_METRICS_PROFILE") or "multi_way",
    }
    run_block = {k: v for k, v in run_block.items() if v not in (None, "")}
    if run_block:
        doc["run"] = run_block

    # Serializers: prefer CSV scrape after file exists; allow extra override
    if include_serializers and result_csv_path:
        ser = _serializers_block_from_csv(result_csv_path)
        if ser:
            doc["serializers"] = ser

    if extra:
        for k, v in extra.items():
            if k in doc and isinstance(doc[k], dict) and isinstance(v, dict):
                merged = dict(doc[k])
                merged.update(v)
                doc[k] = merged
            else:
                doc[k] = v

    if output_path is None and result_csv_path:
        output_path = str(configs_path_for_csv(result_csv_path))
    elif output_path is None:
        output_path = "run.configs.json"

    os.makedirs(os.path.dirname(output_path) or ".", exist_ok=True)
    with open(output_path, "w", encoding="utf-8") as f:
        json.dump(doc, f, indent=2, default=str)

    return doc


def load_environment(result_csv_path: str) -> Optional[Dict[str, Any]]:
    """Load run config for a result CSV.

    Prefer ``*.configs.json``. Fall back to legacy ``*.environment.json``
    (returned as a full document with ``environment`` key when legacy is flat).
    """
    return load_run_config(result_csv_path)


def load_run_config(result_csv_path: str) -> Optional[Dict[str, Any]]:
    p = Path(result_csv_path)
    for path in (configs_path_for_csv(str(p)), legacy_environment_path_for_csv(str(p))):
        if not path.is_file():
            continue
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        if not isinstance(data, dict):
            return None
        # Legacy flat environment.json (no schema_version / nested environment)
        if "schema_version" not in data and "environment" not in data and "os" in data:
            return {
                "schema_version": 0,
                "benchmark_ts": data.get("benchmark_ts") or p.stem,
                "environment": data,
            }
        return data
    return None


def important_config_summary(doc: Optional[Dict[str, Any]]) -> List[str]:
    """Human-readable lines for Results pages / plot provenance."""
    if not doc:
        return []
    lines: List[str] = []
    env = doc.get("environment") if isinstance(doc.get("environment"), dict) else doc
    if not isinstance(env, dict):
        env = {}
    ts = doc.get("benchmark_ts") or env.get("benchmark_ts")
    if ts:
        lines.append(f"run={ts}")
    lang = doc.get("language")
    if lang:
        lines.append(f"language={lang}")
    os_b = env.get("os") if isinstance(env.get("os"), dict) else {}
    cpu = env.get("cpu") if isinstance(env.get("cpu"), dict) else {}
    mem = env.get("memory") if isinstance(env.get("memory"), dict) else {}
    if os_b.get("system"):
        rel = os_b.get("release") or ""
        lines.append(f"os={os_b.get('system')} {rel}".strip())
    if cpu.get("model"):
        cores = cpu.get("logical_cores") or cpu.get("cpu_count") or ""
        lines.append(f"cpu={cpu['model']}" + (f" ({cores} threads)" if cores else ""))
    if mem.get("total_bytes"):
        gib = float(mem["total_bytes"]) / (1024**3)
        lines.append(f"ram={gib:.1f} GiB")
    runtimes = env.get("runtimes") if isinstance(env.get("runtimes"), dict) else {}
    if runtimes:
        # Prefer the language runtime if known
        prefer = []
        lang_l = (lang or "").lower()
        key_map = {
            "python": "python",
            "csharp": "dotnet",
            "javascript": "node",
            "rust": "rustc",
            "go": "go",
            "c": "gcc",
            "cpp": "g++",
            "java": "java",
            "kotlin": "java",
            "swift": "swift",  # may be absent until runtime capture adds it
        }
        k = key_map.get(lang_l)
        if k and runtimes.get(k):
            prefer.append(f"{k}={runtimes[k]}")
        for rk, rv in list(runtimes.items())[:4]:
            if k and rk == k:
                continue
            prefer.append(f"{rk}={rv}")
        if prefer:
            lines.append("runtimes: " + ", ".join(prefer[:3]))
    git = env.get("git") if isinstance(env.get("git"), dict) else {}
    if git.get("commit"):
        dirty = " dirty" if git.get("dirty") else ""
        lines.append(f"git={git['commit']}{dirty}")
    ds = doc.get("dataset") if isinstance(doc.get("dataset"), dict) else {}
    if ds.get("seed"):
        lines.append(f"seed={ds['seed']}")
    if ds.get("mode"):
        lines.append(f"mode={ds['mode']}")
    if ds.get("warmup_repetitions") is not None:
        lines.append(f"warmup_reps={ds['warmup_repetitions']}")
    ser = doc.get("serializers") if isinstance(doc.get("serializers"), dict) else {}
    if ser.get("count"):
        lines.append(f"serializers={ser['count']}")
    run = doc.get("run") if isinstance(doc.get("run"), dict) else {}
    if run.get("metrics_profile"):
        lines.append(f"metrics_profile={run['metrics_profile']}")
    return lines


# CLI entry point
if __name__ == "__main__":
    csv_path = sys.argv[1] if len(sys.argv) > 1 else None
    doc = capture_environment(csv_path)
    out = (
        str(configs_path_for_csv(csv_path))
        if csv_path
        else "run.configs.json"
    )
    print(f"Run config captured -> {out}")
    print(json.dumps(doc, indent=2, default=str))
