"""Unpublished reports go under reports/, not docs/."""
from __future__ import annotations

from pathlib import Path

import pytest

from benchmark_analysis.cli import _generate_artifacts
from benchmark_analysis.reports import generate_language_results_pages


def _stat(lang: str, serializer: str = "json") -> dict:
    return {
        f"{lang}|{serializer}|document|bytes|1": {
            "language": lang,
            "serializer": serializer,
            "test_data": "document",
            "mode": "bytes",
            "data_type_instance_count": 1,
            "avg_ops_per_sec": 1000.0,
            "avg_time_total_ns": 2000.0,
            "mean_ser_ns": 1000.0,
            "mean_deser_ns": 1000.0,
        }
    }


def test_generate_language_results_pages_writes_reports_not_docs(tmp_path: Path):
    reports_root = tmp_path / "reports"
    docs_js = tmp_path / "docs" / "javascript" / "results.md"
    docs_js.parent.mkdir(parents=True)
    docs_js.write_text("PUBLISHED\n")

    written = generate_language_results_pages(
        multi_lang_stats=_stat("javascript", "JSON.stringify"),
        violin_images={},
        docs_root=str(reports_root),
    )

    unpublished = reports_root / "javascript" / "results.md"
    assert unpublished.is_file()
    assert any(Path(p) == unpublished for p in written)
    body = unpublished.read_text()
    assert "docs/analysis/plots/violin" not in body
    assert "](../analysis/plots/violin/" not in body
    assert docs_js.read_text() == "PUBLISHED\n"


def test_generate_language_results_pages_maps_csharp_to_c_sharp(tmp_path: Path):
    reports_root = tmp_path / "reports"
    written = generate_language_results_pages(
        multi_lang_stats=_stat("csharp", "System.Text.Json"),
        violin_images={},
        docs_root=str(reports_root),
    )
    unpublished = reports_root / "c-sharp" / "results.md"
    assert unpublished.is_file()
    assert any(Path(p) == unpublished for p in written)
    assert not (reports_root / "csharp" / "results.md").exists()


def test_generate_artifacts_does_not_write_docs_results(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    reports_root = tmp_path / "reports"
    docs_js = tmp_path / "docs" / "javascript" / "results.md"
    docs_js.parent.mkdir(parents=True)
    docs_js.write_text("PUBLISHED\n")

    def boom(*_args, **_kwargs):
        raise AssertionError("generate_violin_plots must not run unless --violins")

    import benchmark_analysis.reports as reports

    monkeypatch.setattr(reports, "generate_violin_plots", boom)

    _generate_artifacts(
        all_records={"javascript": []},
        all_stats=_stat("javascript", "JSON.stringify"),
        lang_paths={"javascript": str(tmp_path / "fake.csv")},
        reports_root=reports_root,
        stats_config={},
        pre_sanitized=True,
        write_markdown=True,
        write_violins=False,
    )

    unpublished = reports_root / "javascript" / "results.md"
    assert unpublished.is_file()
    assert docs_js.read_text() == "PUBLISHED\n"
    assert not (reports_root / "docs").exists()
    assert not list(reports_root.glob("plots/violin/*"))


def test_generate_artifacts_violins_opt_in_under_reports(
    tmp_path: Path, monkeypatch: pytest.MonkeyPatch
):
    reports_root = tmp_path / "reports"
    seen: dict = {}

    def fake_violins(output_dir, **_kwargs):
        seen["output_dir"] = output_dir
        return {}

    import benchmark_analysis.reports as reports

    monkeypatch.setattr(reports, "generate_violin_plots", fake_violins)

    _generate_artifacts(
        all_records={"javascript": []},
        all_stats=_stat("javascript", "JSON.stringify"),
        lang_paths={"javascript": str(tmp_path / "fake.csv")},
        reports_root=reports_root,
        write_markdown=False,
        write_violins=True,
    )

    assert seen["output_dir"] == str(reports_root / "plots" / "violin")
    assert not (tmp_path / "docs").exists()
    assert not list(tmp_path.glob("**/docs/**/results.md"))
