"""Adding a language block must not force a full bench of every language."""

from __future__ import annotations

import importlib.util
from pathlib import Path

_SCRIPT = (
    Path(__file__).resolve().parents[2]
    / ".grok"
    / "skills"
    / "prepare-pr"
    / "scripts"
    / "config_lang_delta.py"
)


def _classify():
    spec = importlib.util.spec_from_file_location("config_lang_delta", _SCRIPT)
    assert spec and spec.loader
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod.classify


classify = _classify()


def _base() -> dict:
    return {
        "modes": {"smoke": {"repetitions": 2}},
        "reproducibility": {"random_seed": 42},
        "languages": {
            "c": {"enabled": True, "serializers": [{"name": "cJSON"}]},
            "zig": {"enabled": True, "serializers": [{"name": "serde.json"}]},
        },
    }


def test_added_language_is_not_force_all():
    old = _base()
    new = _base()
    new["languages"] = {
        **old["languages"],
        "fortran": {"enabled": True, "serializers": [{"name": "json-fortran"}]},
    }
    assert classify(old, new) == ["fortran"]


def test_identical_documents_add_nothing():
    old = _base()
    assert classify(old, dict(old)) == []


def test_shared_key_forces_all():
    old = _base()
    new = _base()
    new["reproducibility"] = {"random_seed": 7}
    assert classify(old, new) is None


def test_existing_language_edit_forces_all():
    old = _base()
    new = _base()
    new["languages"] = dict(old["languages"])
    new["languages"]["c"] = {"enabled": True, "serializers": [{"name": "yyjson"}]}
    assert classify(old, new) is None


def test_removed_language_forces_all():
    old = _base()
    new = _base()
    new["languages"] = {"c": old["languages"]["c"]}
    assert classify(old, new) is None


def test_unreadable_documents_force_all():
    assert classify(None, _base()) is None
    assert classify(_base(), ["not", "a", "map"]) is None


def test_new_language_log_dir_is_not_force_all():
    old = _base()
    old["paths"] = {"language_log_dirs": {"c": "logs/c", "zig": "logs/zig"}}
    new = _base()
    new["languages"] = {
        **old["languages"],
        "fortran": {"enabled": True, "serializers": [{"name": "json-fortran"}]},
    }
    new["paths"] = {
        "language_log_dirs": {
            "c": "logs/c",
            "zig": "logs/zig",
            "fortran": "logs/fortran",
        }
    }
    assert classify(old, new) == ["fortran"]


def test_existing_log_dir_edit_forces_all():
    old = _base()
    old["paths"] = {"language_log_dirs": {"c": "logs/c"}}
    new = _base()
    new["paths"] = {"language_log_dirs": {"c": "logs/c-moved"}}
    assert classify(old, new) is None


def test_log_dir_for_unknown_language_forces_all():
    old = _base()
    old["paths"] = {"language_log_dirs": {"c": "logs/c"}}
    new = _base()
    new["paths"] = {"language_log_dirs": {"c": "logs/c", "fortran": "logs/fortran"}}
    assert classify(old, new) is None
