"""Load and query the monorepo master config: config/benchmark_config.yaml.

This is the preferred source of truth for modes, languages, paths, statistics,
regression gates, and reproducibility settings. Callers should prefer helpers
here over hard-coded language lists or repetition counts.
"""

from __future__ import annotations

from functools import lru_cache
from pathlib import Path
from typing import Any, Dict, List, Optional, Tuple

# Built-in aliases always available even if config is missing.
_BUILTIN_ALIASES: Dict[str, str] = {
    "py": "python",
    "cs": "csharp",
    "c#": "csharp",
    "c-sharp": "csharp",
    "js": "javascript",
    "node": "javascript",
    "golang": "go",
}


def repo_root(start: Optional[Path] = None) -> Path:
    """Walk up from *start* (or this file) to the directory that owns the master config."""
    here = (start or Path(__file__)).resolve()
    for p in [here, *here.parents]:
        if (p / "config" / "benchmark_config.yaml").is_file():
            return p
    return Path(".").resolve()


def default_config_path(start: Optional[Path] = None) -> Path:
    return repo_root(start) / "config" / "benchmark_config.yaml"


@lru_cache(maxsize=4)
def _load_raw(path_str: str) -> Dict[str, Any]:
    path = Path(path_str)
    if not path.is_file():
        return {}
    try:
        import yaml  # type: ignore
    except ImportError:
        return {}
    with open(path, encoding="utf-8") as f:
        data = yaml.safe_load(f) or {}
    return data if isinstance(data, dict) else {}


def load_master_config(config_path: Optional[str | Path] = None) -> Dict[str, Any]:
    """Return the full master YAML as a dict (empty if missing / unreadable)."""
    path = Path(config_path) if config_path else default_config_path()
    return dict(_load_raw(str(path.resolve())))


def clear_config_cache() -> None:
    """Test helper: drop cached YAML loads."""
    _load_raw.cache_clear()


def dig(data: Dict[str, Any], dotted: str, default: Any = None) -> Any:
    """Resolve a dotted key path, e.g. ``modes.smoke.repetitions``."""
    cur: Any = data
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return default
        cur = cur[part]
    return cur


def mode_repetitions(mode: str, config_path: Optional[str | Path] = None) -> int:
    """Repetitions for a named run mode (smoke | all-single | full | research)."""
    cfg = load_master_config(config_path)
    reps = dig(cfg, f"modes.{mode}.repetitions")
    if reps is None:
        # Fallback defaults matching historical hard-coded values
        return {"smoke": 2, "all-single": 10, "full": 100, "research": 500}.get(mode, 10)
    return int(reps)


def random_seed(config_path: Optional[str | Path] = None) -> int:
    cfg = load_master_config(config_path)
    seed = dig(cfg, "reproducibility.random_seed", 42)
    return int(seed)


def logs_root(config_path: Optional[str | Path] = None) -> Path:
    cfg = load_master_config(config_path)
    root = repo_root()
    rel = dig(cfg, "paths.logs_root", "logs")
    p = Path(rel)
    return p if p.is_absolute() else root / p


def reports_root(config_path: Optional[str | Path] = None) -> Path:
    cfg = load_master_config(config_path)
    root = repo_root()
    rel = dig(cfg, "paths.reports_root", "reports")
    p = Path(rel)
    return p if p.is_absolute() else root / p


def baseline_path(config_path: Optional[str | Path] = None) -> Path:
    cfg = load_master_config(config_path)
    root = repo_root()
    rel = dig(cfg, "paths.baseline_filename", "reports/baseline.json")
    p = Path(rel)
    return p if p.is_absolute() else root / p


def regression_threshold(config_path: Optional[str | Path] = None) -> float:
    cfg = load_master_config(config_path)
    return float(dig(cfg, "regression.threshold_percent", 10.0))


def language_entries(config_path: Optional[str | Path] = None) -> Dict[str, Dict[str, Any]]:
    """Map language id -> language block from ``languages:``."""
    cfg = load_master_config(config_path)
    langs = cfg.get("languages") or {}
    return {str(k): (v if isinstance(v, dict) else {}) for k, v in langs.items()}


def known_language_ids(config_path: Optional[str | Path] = None) -> Tuple[str, ...]:
    """All language ids registered under ``languages:`` (enabled or not)."""
    entries = language_entries(config_path)
    if entries:
        return tuple(sorted(entries.keys()))
    return ("csharp", "python", "rust", "c", "javascript", "go")


def enabled_languages(config_path: Optional[str | Path] = None) -> List[Dict[str, Any]]:
    """Enabled language harness descriptors for orchestration.

    Each item: ``{id, display_name, runner_dir, runner_script, log_dir, ...}``.
    """
    out: List[Dict[str, Any]] = []
    for lang_id, block in language_entries(config_path).items():
        if not block.get("enabled", True):
            continue
        item = dict(block)
        item["id"] = lang_id
        item.setdefault("runner_dir", lang_id)
        item.setdefault("runner_script", "scripts/run-benchmarks.sh")
        item.setdefault("log_dir", f"logs/{lang_id}")
        item.setdefault("display_name", lang_id)
        out.append(item)
    # Stable order: prefer paths.language_log_dirs key order if present, else alpha
    cfg = load_master_config(config_path)
    order = list((cfg.get("paths") or {}).get("language_log_dirs") or {})
    if order:
        rank = {k: i for i, k in enumerate(order)}
        out.sort(key=lambda x: (rank.get(x["id"], 999), x["id"]))
    else:
        out.sort(key=lambda x: x["id"])
    return out


def language_aliases(config_path: Optional[str | Path] = None) -> Dict[str, str]:
    """Map alias / id -> canonical language id."""
    aliases = dict(_BUILTIN_ALIASES)
    for lang_id in known_language_ids(config_path):
        aliases[lang_id] = lang_id
        aliases[lang_id.lower()] = lang_id
        # display_name lowercased without spaces as weak alias
        block = language_entries(config_path).get(lang_id) or {}
        dn = str(block.get("display_name") or "").strip().lower()
        if dn:
            aliases[dn] = lang_id
            aliases[dn.replace(" ", "")] = lang_id
            aliases[dn.replace(" ", "-")] = lang_id
    return aliases


def language_log_dir(lang_id: str, config_path: Optional[str | Path] = None) -> Path:
    """Absolute path to a language's log directory."""
    cfg = load_master_config(config_path)
    root = repo_root()
    mapped = (cfg.get("paths") or {}).get("language_log_dirs") or {}
    if lang_id in mapped:
        rel = mapped[lang_id]
    else:
        block = language_entries(config_path).get(lang_id) or {}
        rel = block.get("log_dir", f"logs/{lang_id}")
    p = Path(rel)
    return p if p.is_absolute() else root / p


def language_docs_dir(lang_id: str, config_path: Optional[str | Path] = None) -> str:
    """Docs folder name under docs/ (may differ from lang id, e.g. csharp -> c-sharp)."""
    block = language_entries(config_path).get(lang_id) or {}
    docs = block.get("docs_dir")
    if docs:
        return str(docs).replace("docs/", "").strip("/")
    return lang_id


def language_display_name(lang_id: str, config_path: Optional[str | Path] = None) -> str:
    block = language_entries(config_path).get(lang_id) or {}
    return str(block.get("display_name") or lang_id)


def lang_order(config_path: Optional[str | Path] = None) -> List[str]:
    """Preferred display / orchestration order for languages."""
    cfg = load_master_config(config_path)
    order = list((cfg.get("paths") or {}).get("language_log_dirs") or {})
    if order:
        return order
    return list(known_language_ids(config_path))
