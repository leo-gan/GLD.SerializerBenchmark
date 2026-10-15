#!/usr/bin/env python3
"""Cross-artifact consistency checks for the serializer-benchmark repo.

Prints ERROR and INFO lines. Exits 1 when any ERROR was found.
Design judgment is not done here; see references/design-review.md.

This script calls the analysis package for data-set and standard labels.
It does not re-implement those rules.
"""

from __future__ import annotations

import gzip
import json
import re
import subprocess
import sys
import tomllib
from pathlib import Path

_SCRIPT = Path(__file__).resolve()
_REPO = Path(
    subprocess.check_output(
        ["git", "rev-parse", "--show-toplevel"],
        cwd=_SCRIPT.parent,
        text=True,
    ).strip()
)
_ANALYSIS_SRC = _REPO / "analysis" / "src"
if str(_ANALYSIS_SRC) not in sys.path:
    sys.path.insert(0, str(_ANALYSIS_SRC))

from benchmark_analysis.config_loader import (  # noqa: E402
    enabled_languages,
    language_entries,
    load_master_config,
)
from benchmark_analysis.dimensions import (  # noqa: E402
    DimensionError,
    data_set_for_type,
    load_dimensions,
    load_standards,
    standard_for,
)
from benchmark_analysis.run_config_v2 import load_catalog  # noqa: E402

import yaml  # noqa: E402

# Pages under docs/compliance that are not a standard id.
_COMPLIANCE_META_PAGES = {"index", "reading-results", "adapters", "legal"}
# Repo version fields that must match each other. Generated Cargo crates stay
# on their own version and are intentionally absent.
_VERSION_FILES = (
    "pyproject.toml",
    "python/pyproject.toml",
    "analysis/pyproject.toml",
    "mojo/pixi.toml",
    "rust/Cargo.toml",
    "dashboard/package.json",
    "javascript/package.json",
)
_SNAPSHOT_SKIP_TYPES = {"all"}


class Finding:
    def __init__(self, level: str, artifact: str, message: str) -> None:
        self.level = level
        self.artifact = artifact
        self.message = message


def _read(rel: str) -> str:
    return (_REPO / rel).read_text(encoding="utf-8")


def _load_json(path: Path):
    raw = path.read_bytes()
    if path.suffix == ".gz":
        raw = gzip.decompress(raw)
    return json.loads(raw)


def _version_of(rel: str) -> str:
    path = _REPO / rel
    if rel.endswith(".json"):
        return str(json.loads(path.read_text(encoding="utf-8"))["version"])
    data = tomllib.loads(path.read_text(encoding="utf-8"))
    if "project" in data and isinstance(data["project"], dict) and "version" in data["project"]:
        return str(data["project"]["version"])
    if "package" in data and isinstance(data["package"], dict) and "version" in data["package"]:
        return str(data["package"]["version"])
    workspace = data.get("workspace")
    if isinstance(workspace, dict) and "version" in workspace:
        return str(workspace["version"])
    if "version" in data and not isinstance(data["version"], dict):
        return str(data["version"])
    raise KeyError(f"no version in {rel}")


def _format_label_ids() -> set[str]:
    text = _read("dashboard/compliance-groups.js")
    match = re.search(r"export const FORMAT_LABELS = \{([\s\S]*?)\n\};", text)
    if not match:
        raise RuntimeError("FORMAT_LABELS block not found")
    return set(re.findall(r"^\s+([a-z0-9]+):", match.group(1), re.M))


def _mkdocs_language_pages() -> set[str]:
    text = _read("mkdocs.yml")
    start = text.find("\n  - Languages:\n")
    if start < 0:
        return set()
    rest = text[start + 1 :]
    nxt = re.search(r"\n  - \w", rest[len("  - Languages:\n") :])
    block = rest if nxt is None else rest[: len("  - Languages:\n") + nxt.start()]
    return set(re.findall(r"Overview: (\S+)", block))


def _mkdocs_compliance_pages() -> set[str]:
    return set(re.findall(r"compliance/([a-z0-9-]+)\.md", _read("mkdocs.yml")))


def _ci_language_ids() -> set[str]:
    ids = set(re.findall(r"steps\.filter\.outputs\.([A-Za-z0-9_]+)", _read(".github/workflows/benchmark-ci.yml")))
    ids.discard("analysis")
    return ids


def _host_known() -> set[str]:
    text = _read("scripts/check-host-requirements.sh")
    match = re.search(r"KNOWN=\(([^)]*)\)", text)
    if not match:
        return set()
    return set(match.group(1).split())


def _nav_docs_to_lang() -> dict[str, str]:
    text = _read("docs/javascripts/languages-nav.js")
    match = re.search(r"const DOCS_DIR_TO_LANG = \{([\s\S]*?)\};", text)
    if not match:
        return {}
    out = {}
    for docs_dir, lang in re.findall(r'"?([A-Za-z0-9_-]+)"?\s*:\s*"([A-Za-z0-9_-]+)"', match.group(1)):
        out[docs_dir] = lang
    return out


def _readme_language_claims() -> tuple[int | None, int]:
    text = _read("README.md")
    badge = re.search(r"languages-(\d+)", text)
    badge_n = int(badge.group(1)) if badge else None
    start = text.find("## Supported languages")
    end = text.find("\n## ", start + 1) if start >= 0 else -1
    section = text[start:end] if start >= 0 and end > start else ""
    bullets = re.findall(r"(?m)^- ", section)
    return badge_n, len(bullets)


def _rel_files(root: Path) -> dict[str, Path]:
    if not root.is_dir():
        return {}
    out = {}
    for path in root.rglob("*"):
        if path.is_file():
            out[str(path.relative_to(root))] = path
    return out


def _name_set(blob: dict, language: str) -> set[str]:
    langs = blob.get("languages") or {}
    block = langs.get(language) or {}
    if isinstance(block, dict):
        return set(block)
    return set()


def _experiment_dirs() -> list[Path]:
    root = _REPO / "experiments"
    return sorted(
        p for p in root.iterdir()
        if p.is_dir() and re.fullmatch(r"\d{2}-.+", p.name)
    )


def _add_set_diff(findings: list[Finding], artifact: str, left_name: str, left: set, right_name: str, right: set) -> None:
    only_left = sorted(left - right)
    only_right = sorted(right - left)
    if only_left:
        findings.append(Finding("ERROR", artifact, f"in {left_name} but not {right_name}: {', '.join(only_left)}"))
    if only_right:
        findings.append(Finding("ERROR", artifact, f"in {right_name} but not {left_name}: {', '.join(only_right)}"))


def check_languages(findings: list[Finding]) -> set[str]:
    artifact = "language-registry"
    cfg = load_master_config()
    entries = language_entries()
    enabled = enabled_languages()
    enabled_ids = {item["id"] for item in enabled}
    log_dirs = set((cfg.get("paths") or {}).get("language_log_dirs") or {})
    _add_set_diff(findings, artifact, "languages:", set(entries), "paths.language_log_dirs", log_dirs)
    _add_set_diff(findings, artifact, "enabled languages", enabled_ids, "CI path filters", _ci_language_ids())
    host = _host_known() - {"analysis"}
    _add_set_diff(findings, artifact, "enabled languages", enabled_ids, "check-host-requirements KNOWN", host)

    pages = _mkdocs_language_pages()
    nav_map = _nav_docs_to_lang()
    for item in enabled:
        lang = item["id"]
        runner = _REPO / item["runner_dir"] / item.get("runner_script", "scripts/run-benchmarks.sh")
        if not runner.is_file():
            findings.append(Finding("ERROR", artifact, f"{lang}: runner script missing: {runner.relative_to(_REPO)}"))
        docs_dir = item.get("docs_dir") or f"docs/{lang}"
        overview = f"{docs_dir}/index.md"
        mkdocs_page = overview.removeprefix("docs/")
        if not (_REPO / overview).is_file():
            findings.append(Finding("ERROR", artifact, f"{lang}: docs page missing: {overview}"))
        elif mkdocs_page not in pages:
            findings.append(Finding("ERROR", artifact, f"{lang}: {mkdocs_page} is not in the mkdocs Languages nav"))
        folder = Path(docs_dir).name
        mapped = nav_map.get(folder)
        if mapped != lang:
            findings.append(Finding(
                "ERROR", artifact,
                f"{lang}: languages-nav.js maps {folder!r} to {mapped!r}",
            ))
        expected_log = (cfg.get("paths") or {}).get("language_log_dirs", {}).get(lang)
        if expected_log and item.get("log_dir") and item["log_dir"] != expected_log:
            findings.append(Finding(
                "ERROR", artifact,
                f"{lang}: languages.log_dir {item['log_dir']} != paths.language_log_dirs {expected_log}",
            ))

    badge_n, bullets = _readme_language_claims()
    if badge_n != len(enabled_ids):
        findings.append(Finding(
            "ERROR", "readme",
            f"README languages badge is {badge_n}, enabled language count is {len(enabled_ids)}",
        ))
    if bullets != len(enabled_ids):
        findings.append(Finding(
            "ERROR", "readme",
            f"README Supported languages has {bullets} bullets, enabled language count is {len(enabled_ids)}",
        ))
    return enabled_ids


def check_catalog_and_matrices(findings: list[Finding]) -> None:
    catalog = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")
    dims = load_dimensions()
    allowed = set((dims.get("data_sets") or {}).get("ids") or [])
    types = catalog.get("types") or {}
    seen_sets = set()
    for type_id in types:
        try:
            data_set = data_set_for_type(type_id, catalog)
        except DimensionError as exc:
            findings.append(Finding("ERROR", "data-catalog", str(exc)))
            continue
        seen_sets.add(data_set)
        if data_set not in allowed:
            findings.append(Finding(
                "ERROR", "dimension-contract",
                f"type {type_id} data_set {data_set!r} is not in dimensions.yaml data_sets.ids",
            ))
    missing_sets = sorted(allowed - seen_sets)
    if missing_sets:
        findings.append(Finding(
            "ERROR", "dimension-contract",
            f"data_sets.ids with no catalog type: {', '.join(missing_sets)}",
        ))

    library = _REPO / "config" / "library"
    for path in sorted(library.glob("*.yaml")):
        doc = yaml.safe_load(path.read_text(encoding="utf-8")) or {}
        version = doc.get("data_model_version")
        if version is not None and int(version) != int(catalog.get("data_model_version", 2)):
            findings.append(Finding(
                "ERROR", "run-matrices",
                f"{path.relative_to(_REPO)} data_model_version {version} != catalog {catalog.get('data_model_version')}",
            ))
        for row in doc.get("types") or []:
            if not isinstance(row, dict):
                continue
            type_id = row.get("type_id")
            if type_id and type_id not in types:
                findings.append(Finding(
                    "ERROR", "run-matrices",
                    f"{path.relative_to(_REPO)} type_id {type_id!r} is not in the data catalog",
                ))


def check_dimension_labels(findings: list[Finding], standards: dict, dims: dict) -> None:
    path = _REPO / "dashboard" / "public" / "data" / "dimension-labels.json"
    if not path.is_file():
        findings.append(Finding("ERROR", "published-snapshots", f"missing {path.relative_to(_REPO)}"))
        return
    labels = json.loads(path.read_text(encoding="utf-8"))
    catalog = load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml")
    expected_sets = {type_id: data_set_for_type(type_id, catalog) for type_id in catalog["types"]}
    got_sets = labels.get("data_sets") or {}
    _add_set_diff(
        findings, "published-snapshots",
        "catalog types", set(expected_sets),
        "dimension-labels data_sets", set(got_sets),
    )
    for type_id, data_set in expected_sets.items():
        if type_id in got_sets and got_sets[type_id] != data_set:
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"dimension-labels data_sets[{type_id}]={got_sets[type_id]!r}, catalog says {data_set!r}",
            ))
    got_standards = labels.get("standards") or {}
    for language, serializers in (standards.get("languages") or {}).items():
        if not isinstance(serializers, dict):
            continue
        got_lang = got_standards.get(language) or {}
        missing = []
        mismatched = []
        for name in serializers:
            try:
                expected = standard_for(language, name, standards, dims)
            except DimensionError as exc:
                findings.append(Finding("ERROR", "compliance-standards", str(exc)))
                continue
            actual = got_lang.get(name)
            if actual is None:
                missing.append(f"{name}={expected}")
            elif actual != expected:
                mismatched.append(f"{name}={actual!r} expected {expected!r}")
        if missing:
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"dimension-labels {language} missing {len(missing)}: {', '.join(missing)}",
            ))
        if mismatched:
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"dimension-labels {language} wrong label: {', '.join(mismatched)}",
            ))
        extra = sorted(set(got_lang) - set(serializers))
        if extra:
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"dimension-labels has {language} names missing from serializer-standards.json: {', '.join(extra)}",
            ))


def check_standards_sources_and_compliance(findings: list[Finding], standards: dict) -> None:
    label_ids = _format_label_ids()
    data_dirs = {p.name for p in (_REPO / "compliance" / "data").iterdir() if p.is_dir()}
    doc_pages = {p.stem for p in (_REPO / "docs" / "compliance").glob("*.md")} - _COMPLIANCE_META_PAGES
    nav_pages = _mkdocs_compliance_pages() - _COMPLIANCE_META_PAGES
    _add_set_diff(findings, "compliance-corpora", "compliance/data", data_dirs, "FORMAT_LABELS", label_ids)
    _add_set_diff(findings, "compliance-docs", "docs/compliance", doc_pages, "compliance/data", data_dirs)
    _add_set_diff(findings, "compliance-docs", "mkdocs Compliance nav", nav_pages, "docs/compliance", doc_pages)

    used_ids = set()
    for serializers in (standards.get("languages") or {}).values():
        if not isinstance(serializers, dict):
            continue
        for ids in serializers.values():
            if isinstance(ids, list):
                used_ids.update(str(item) for item in ids)
    used_ids.discard("custom")
    missing_corpus = sorted(used_ids - data_dirs)
    if missing_corpus:
        findings.append(Finding(
            "ERROR", "compliance-standards",
            f"standard ids with no compliance/data corpus: {', '.join(missing_corpus)}",
        ))

    sources_path = _REPO / "config" / "serializer-sources.json"
    sources = json.loads(sources_path.read_text(encoding="utf-8"))
    copies = [
        _REPO / "dashboard" / "public" / "data" / "serializer-sources.json",
        _REPO / "docs" / "dashboard" / "data" / "serializer-sources.json",
    ]
    for copy in copies:
        rel = copy.relative_to(_REPO)
        if not copy.is_file():
            findings.append(Finding("ERROR", "serializer-sources", f"missing copy {rel}"))
            continue
        other = json.loads(copy.read_text(encoding="utf-8"))
        if other != sources:
            findings.append(Finding("ERROR", "serializer-sources", f"{rel} differs from config/serializer-sources.json"))

    source_langs = set((sources.get("languages") or {}))
    standard_langs = set((standards.get("languages") or {}))
    _add_set_diff(
        findings, "serializer-sources",
        "serializer-sources languages", source_langs,
        "serializer-standards languages", standard_langs,
    )
    for language in sorted(source_langs & standard_langs):
        source_names = _name_set(sources, language)
        standard_names = _name_set(standards, language)
        _add_set_diff(
            findings, "serializer-roster",
            f"serializer-sources {language}", source_names,
            f"serializer-standards {language}", standard_names,
        )

    file_only = _REPO / "config" / "file-only.txt"
    if not file_only.is_file():
        findings.append(Finding("ERROR", "file-only-list", "config/file-only.txt is missing"))
    else:
        for line in file_only.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            parts = line.split()
            if len(parts) != 2:
                findings.append(Finding("ERROR", "file-only-list", f"expected language and serializer, got {line!r}"))
                continue
            language, serializer = parts
            try:
                standard_for(language, serializer, standards)
            except DimensionError as exc:
                findings.append(Finding("ERROR", "file-only-list", str(exc)))


def check_versions(findings: list[Finding]) -> None:
    found: dict[str, str] = {}
    for rel in _VERSION_FILES:
        try:
            found[rel] = _version_of(rel)
        except (OSError, KeyError, json.JSONDecodeError, tomllib.TOMLDecodeError) as exc:
            findings.append(Finding("ERROR", "repo-version", f"{rel}: {exc}"))
    values = set(found.values())
    if len(values) > 1:
        rendered = ", ".join(f"{rel}={version}" for rel, version in found.items())
        findings.append(Finding("ERROR", "repo-version", f"version pins disagree: {rendered}"))


def check_experiments(findings: list[Finding]) -> None:
    folders = _experiment_dirs()
    folder_ids = set()
    for folder in folders:
        yaml_path = folder / "experiment.yaml"
        if not yaml_path.is_file():
            findings.append(Finding("ERROR", "experiments", f"{folder.name} has no experiment.yaml"))
            continue
        doc = yaml.safe_load(yaml_path.read_text(encoding="utf-8")) or {}
        exp_id = str(doc.get("id") or "")
        folder_ids.add(folder.name)
        if exp_id != folder.name:
            findings.append(Finding(
                "ERROR", "experiments",
                f"{folder.name}/experiment.yaml id is {exp_id!r}",
            ))
        if doc.get("schema") != "gld.experiment.config/1":
            findings.append(Finding(
                "ERROR", "experiments",
                f"{folder.name} schema is {doc.get('schema')!r}",
            ))
        for key in ("question", "sample", "run", "languages"):
            if key not in doc:
                findings.append(Finding("ERROR", "experiments", f"{folder.name} is missing {key}"))

    for rel_root in (
        "dashboard/public/data/experiments",
        "docs/dashboard/data/experiments",
    ):
        root = _REPO / rel_root
        if not root.is_dir():
            findings.append(Finding("ERROR", "experiment-catalog", f"missing {rel_root}"))
            continue
        published = {p.name[: -len(".json.gz")] for p in root.glob("*.json.gz")}
        _add_set_diff(
            findings, "experiment-catalog",
            "experiment folders", folder_ids,
            rel_root, published,
        )
        index_path = root / "index.json"
        if not index_path.is_file():
            findings.append(Finding("ERROR", "experiment-catalog", f"missing {rel_root}/index.json"))
            continue
        index = json.loads(index_path.read_text(encoding="utf-8"))
        rows = index.get("experiments") if isinstance(index, dict) else index
        index_ids = set()
        if isinstance(rows, list):
            for row in rows:
                if isinstance(row, dict) and row.get("id"):
                    index_ids.add(str(row["id"]))
        elif isinstance(rows, dict):
            index_ids = set(rows)
        _add_set_diff(
            findings, "experiment-catalog",
            "experiment folders", folder_ids,
            f"{rel_root}/index.json", index_ids,
        )


def _payload(path: Path):
    """Comparable content. JSON and gzip-JSON compare as sorted JSON, not bytes."""
    name = path.name
    if name.endswith(".json") or name.endswith(".json.gz"):
        return json.dumps(_load_json(path), sort_keys=True, separators=(",", ":"))
    return path.read_bytes()


def check_published_trees(findings: list[Finding], standards: dict) -> None:
    public_root = _REPO / "dashboard" / "public" / "data"
    deployed_root = _REPO / "docs" / "dashboard" / "data"
    public = _rel_files(public_root)
    deployed = _rel_files(deployed_root)
    if not public:
        findings.append(Finding("ERROR", "published-snapshots", "dashboard/public/data is empty or missing"))
        return
    only_public = sorted(set(public) - set(deployed))
    only_deployed = sorted(set(deployed) - set(public))
    if only_public:
        sample = ", ".join(only_public[:12])
        extra = f" (+{len(only_public) - 12} more)" if len(only_public) > 12 else ""
        findings.append(Finding(
            "ERROR", "published-snapshots",
            f"in dashboard/public/data but not docs/dashboard/data: {sample}{extra}",
        ))
    leftover = []
    real_only_deployed = []
    for rel in only_deployed:
        # Uncompressed JSON next to a gzip the public tree already has.
        gz_rel = rel[:-5] + ".json.gz" if rel.endswith(".json") else ""
        if gz_rel and gz_rel in public:
            try:
                same = _payload(deployed[rel]) == _payload(public[gz_rel])
            except (OSError, json.JSONDecodeError, gzip.BadGzipFile, ValueError):
                same = False
            if same:
                leftover.append(rel)
            else:
                findings.append(Finding(
                    "ERROR", "dashboard-build",
                    f"docs/dashboard/data/{rel} does not match dashboard/public/data/{gz_rel}",
                ))
        else:
            real_only_deployed.append(rel)
    if leftover:
        findings.append(Finding(
            "INFO", "dashboard-build",
            f"uncompressed copies only in docs/dashboard/data ({len(leftover)}): {', '.join(leftover)}",
        ))
    if real_only_deployed:
        sample = ", ".join(real_only_deployed[:12])
        extra = f" (+{len(real_only_deployed) - 12} more)" if len(real_only_deployed) > 12 else ""
        findings.append(Finding(
            "ERROR", "dashboard-build",
            f"in docs/dashboard/data but not dashboard/public/data: {sample}{extra}",
        ))
    differed = []
    for rel in sorted(set(public) & set(deployed)):
        try:
            if _payload(public[rel]) != _payload(deployed[rel]):
                differed.append(rel)
        except (OSError, json.JSONDecodeError, gzip.BadGzipFile, ValueError) as exc:
            findings.append(Finding("ERROR", "published-snapshots", f"cannot compare {rel}: {exc}"))
    if differed:
        sample = ", ".join(differed[:12])
        extra = f" (+{len(differed) - 12} more)" if len(differed) > 12 else ""
        findings.append(Finding(
            "ERROR", "published-snapshots",
            f"dashboard/public/data and docs/dashboard/data differ: {sample}{extra}",
        ))

    enabled = {item["id"] for item in enabled_languages()}
    catalog_types = set((load_catalog(_REPO / "schemas" / "data_catalog_v2.yaml").get("types") or {}))
    for path in sorted((_REPO / "dashboard" / "public" / "data").glob("stats_*_latest.json.gz")):
        lang = path.name[len("stats_") : -len("_latest.json.gz")]
        if lang not in enabled:
            findings.append(Finding("ERROR", "published-snapshots", f"{path.name} is not an enabled language"))
            continue
        try:
            stats = _load_json(path)
        except (OSError, json.JSONDecodeError, gzip.BadGzipFile) as exc:
            findings.append(Finding("ERROR", "published-snapshots", f"{path.name}: {exc}"))
            continue
        names = set()
        types = set()
        for group in stats.get("groups") or []:
            name = str(group.get("serializer") or "")
            if name:
                names.add(name)
            raw_type = str(group.get("test_data") or "")
            base = raw_type.split("@", 1)[0]
            if base and base not in _SNAPSHOT_SKIP_TYPES and not base.startswith("all@"):
                types.add(base)
        unknown_names = sorted(names - _name_set(standards, lang))
        if unknown_names:
            sample = ", ".join(unknown_names[:15])
            extra = f" (+{len(unknown_names) - 15} more)" if len(unknown_names) > 15 else ""
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"{path.name} serializers missing from serializer-standards.json: {sample}{extra}",
            ))
        unknown_types = sorted(types - catalog_types)
        if unknown_types:
            findings.append(Finding(
                "ERROR", "published-snapshots",
                f"{path.name} test_data not in the data catalog: {', '.join(unknown_types)}",
            ))
        chart = _REPO / "dashboard" / "public" / "data" / f"{lang}_latest.json.gz"
        if not chart.is_file():
            findings.append(Finding("ERROR", "published-snapshots", f"stats exist for {lang} but {lang}_latest.json.gz does not"))


def main() -> int:
    findings: list[Finding] = []
    check_languages(findings)
    check_catalog_and_matrices(findings)
    standards = load_standards()
    dims = load_dimensions()
    check_dimension_labels(findings, standards, dims)
    check_standards_sources_and_compliance(findings, standards)
    check_versions(findings)
    check_experiments(findings)
    check_published_trees(findings, standards)

    errors = [item for item in findings if item.level == "ERROR"]
    infos = [item for item in findings if item.level != "ERROR"]
    print(f"## check-artifacts  ({len(errors)} errors, {len(infos)} info)")
    if not findings:
        print("No mechanical inconsistencies.")
    for item in findings:
        print(f"{item.level}  {item.artifact}  {item.message}")
    return 1 if errors else 0


if __name__ == "__main__":
    sys.exit(main())
