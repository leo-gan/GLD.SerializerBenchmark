"""Dashboard explanations live in the configs, and the published JSON matches."""

from __future__ import annotations

import json
import re
from pathlib import Path

from benchmark_analysis.config_loader import data_sets, repo_root
from benchmark_analysis.dimensions import load_dimensions, load_standards
from benchmark_analysis.explanations import load_dashboard_explanations, load_standard_definitions
from benchmark_analysis.run_config_v2 import DEFAULT_CATALOG, load_catalog

_REPO = repo_root()
_LABELS = _REPO / "dashboard" / "public" / "data" / "dimension-labels.json"
_GROUPS = _REPO / "dashboard" / "compliance-groups.js"


def _format_label_ids() -> set[str]:
    text = _GROUPS.read_text(encoding="utf-8")
    match = re.search(r"export const FORMAT_LABELS = \{([\s\S]*?)\n\};", text)
    assert match, "FORMAT_LABELS block missing"
    ids = set(re.findall(r"^\s*([A-Za-z0-9_]+)\s*:", match.group(1), re.M))
    ids.discard("NO_SPEC")
    # Overview uses custom for the same bucket Compliance calls no-spec.
    ids.discard("no-spec")
    return ids


def test_every_definition_has_an_explanation():
    explained = load_dashboard_explanations()
    catalog_ids = set(load_catalog(DEFAULT_CATALOG)["types"])
    assert set(explained["data_types"]) == catalog_ids
    assert all(explained["data_types"].values())
    set_ids = [row["id"] for row in data_sets()]
    assert list(explained["data_sets"]) == set_ids
    assert all(explained["data_sets"].values())
    assert set(explained["views"]) == {"batch", "batch_compound", "all_n", "all_all"}
    assert all(explained["views"].values())
    for key in ("n", "nA", "nB"):
        assert "{" + key + "}" in explained["views"][
            {"n": "batch", "nA": "batch_compound", "nB": "batch_compound"}[key]
        ]


def test_menu_standards_match_the_definition_file():
    defs = load_standard_definitions()
    menu = _format_label_ids() | {"all", "custom"}
    assert set(defs) == menu
    assert all(row["explanation"] and row["label"] for row in defs.values())
    assert defs["all"]["label"] == "All"
    assert defs["custom"]["label"] == "No public spec"
    used = set()
    for lang in (load_standards().get("languages") or {}).values():
        for ids in lang.values():
            used.update(ids)
    assert used <= set(defs)
    assert (load_dimensions().get("standards") or {}).get("definitions") == "config/standards.yaml"


def test_published_dimension_labels_match_the_configs():
    on_disk = json.loads(_LABELS.read_text(encoding="utf-8"))
    assert on_disk["explanations"] == load_dashboard_explanations()
