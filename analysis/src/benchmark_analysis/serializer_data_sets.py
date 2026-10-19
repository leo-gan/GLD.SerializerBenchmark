"""Serializer → data set membership from ``benchmark_config.yaml``.

One serializer may be measured on several data sets. A name that is absent
from ``serializer_data_sets`` is measured on ``suite`` only. Specialized
sets stay listed; they are not the default.

Suite runs do not turn this map into a serializer filter. The suite matrix
is every registered serializer whose own ``supports`` accepts those types.
Specialized runs use the names listed here.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any

from benchmark_analysis.config_loader import language_entries, load_master_config
from benchmark_analysis.dimensions import data_set_for_type, data_set_membership

# Runners whose comma-separated filter is case-insensitive exact names.
# A comma list must not be pushed at runners that treat the whole argument
# as one substring (C, Mojo, PHP, Swift, Zig) or that still substring-match
# each token (Python). Python applies the map in the runner instead.
EXACT_COMMA_FILTER_LANGS = frozenset(
    {
        "csharp",
        "cpp",
        "fortran",
        "go",
        "java",
        "javascript",
        "kotlin",
        "rust",
    }
)

SKIP_FILTER = "SKIP"
NONE_FILTER = "__none__"
_DEFAULT = ("suite",)


class SerializerDataSetError(ValueError):
    """The serializer → data set map is missing or inconsistent."""


def parse_serializer_data_sets(
    raw: Any,
    *,
    known_sets: set[str],
    known_langs: set[str],
) -> dict[str, dict[str, tuple[str, ...]]]:
    """Validate ``serializer_data_sets`` and return language → name → sets."""
    if raw is None:
        return {}
    if not isinstance(raw, dict):
        raise SerializerDataSetError("serializer_data_sets must be a map of language ids")
    out: dict[str, dict[str, tuple[str, ...]]] = {}
    for lang, block in raw.items():
        if not isinstance(lang, str) or not lang:
            raise SerializerDataSetError(f"language id must be a non-empty string, got {lang!r}")
        if lang not in known_langs:
            raise SerializerDataSetError(f"unknown language id in serializer_data_sets: {lang!r}")
        if not isinstance(block, dict):
            raise SerializerDataSetError(f"{lang}: serializer_data_sets entry must be a map of names")
        names: dict[str, tuple[str, ...]] = {}
        for name, sets in block.items():
            if not isinstance(name, str) or not name:
                raise SerializerDataSetError(f"{lang}: serializer name must be a non-empty string")
            if name in names:
                raise SerializerDataSetError(f"{lang}: duplicate serializer {name!r}")
            if not isinstance(sets, list) or not sets:
                raise SerializerDataSetError(f"{lang} {name}: data sets must be a non-empty list")
            cleaned: list[str] = []
            for set_id in sets:
                if not isinstance(set_id, str) or set_id not in known_sets:
                    raise SerializerDataSetError(
                        f"{lang} {name}: unknown data set {set_id!r}"
                    )
                if set_id in cleaned:
                    raise SerializerDataSetError(f"{lang} {name}: repeated data set {set_id!r}")
                cleaned.append(set_id)
            names[name] = tuple(cleaned)
        out[lang] = names
    return out


def load_serializer_data_sets(
    config_path: str | Path | None = None,
) -> dict[str, dict[str, tuple[str, ...]]]:
    """Parsed membership. Absent languages have no exceptions."""
    cfg = load_master_config(config_path)
    known_sets = {row.get("id") for row in (cfg.get("data_sets") or []) if isinstance(row, dict)}
    known_sets = {str(s) for s in known_sets if isinstance(s, str) and s}
    if not known_sets:
        raise SerializerDataSetError("benchmark_config.yaml has no data_sets")
    return parse_serializer_data_sets(
        cfg.get("serializer_data_sets"),
        known_sets=known_sets,
        known_langs=set(language_entries(config_path)),
    )


def data_sets_for_serializer(
    language: str,
    name: str,
    config_path: str | Path | None = None,
) -> tuple[str, ...]:
    """Data sets this serializer is measured on. Absent names are suite only."""
    block = load_serializer_data_sets(config_path).get(language) or {}
    found = block.get(name)
    if found is None:
        return _DEFAULT
    return found


def measures_data_set(
    language: str,
    name: str,
    data_set: str,
    config_path: str | Path | None = None,
) -> bool:
    return data_set in data_sets_for_serializer(language, name, config_path)


def measures_type(
    language: str,
    name: str,
    type_id: str,
    config_path: str | Path | None = None,
) -> bool:
    """True when this serializer is measured on the parent set of ``type_id``."""
    return measures_data_set(
        language,
        name,
        data_set_for_type(type_id),
        config_path,
    )


def allow_list(
    language: str,
    data_set: str,
    config_path: str | Path | None = None,
) -> list[str]:
    """Names measured on ``data_set``, in config order.

    Suite is not enumerated. Callers keep the runner's own serializer list
    for suite, because an absent name means suite.
    """
    if data_set == "suite":
        raise SerializerDataSetError("suite has no allow-list; absent names are included")
    block = load_serializer_data_sets(config_path).get(language) or {}
    return [name for name, sets in block.items() if data_set in sets]


def data_set_for_run_config(path: str | Path) -> str:
    """The single data set measured by a library run config."""
    import yaml

    raw = yaml.safe_load(Path(path).read_text(encoding="utf-8"))
    if not isinstance(raw, dict):
        raise SerializerDataSetError(f"{path} is not a run config")
    rows = raw.get("types") or []
    if not isinstance(rows, list) or not rows:
        raise SerializerDataSetError(f"{path} has no types")
    membership = data_set_membership()
    found: list[str] = []
    for row in rows:
        if not isinstance(row, dict) or not row.get("type_id"):
            raise SerializerDataSetError(f"{path} has a type row without type_id")
        type_id = str(row["type_id"])
        set_id = membership.get(type_id)
        if set_id is None:
            raise SerializerDataSetError(f"{path} type {type_id!r} is not in a data set")
        if set_id not in found:
            found.append(set_id)
    if len(found) != 1:
        raise SerializerDataSetError(f"{path} spans data sets {found}")
    return found[0]


def default_filter(language: str, run_config: str | Path, config_path: str | Path | None = None) -> str:
    """Filter string for an empty serializer argument.

    ``SKIP`` means leave the caller's filter alone (suite, or a runner that
    does not treat commas as exact names). ``__none__`` means the language
    has no row on that specialized set.
    """
    if language not in EXACT_COMMA_FILTER_LANGS:
        return SKIP_FILTER
    data_set = data_set_for_run_config(run_config)
    if data_set == "suite":
        return SKIP_FILTER
    names = allow_list(language, data_set, config_path)
    if not names:
        return NONE_FILTER
    return ",".join(names)


def uses_exact_comma_filter(language: str) -> bool:
    return language in EXACT_COMMA_FILTER_LANGS
