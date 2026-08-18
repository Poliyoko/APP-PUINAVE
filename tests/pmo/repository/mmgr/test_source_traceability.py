from pathlib import Path
import subprocess

from sgoda.pmo.repository.mmgr.deliverable_classifier import (
    DeliverableClassification,
    ClassifiedDeliverable,
    ClassificationSignals,
)
from sgoda.pmo.repository.mmgr.source_traceability import (
    SourceTraceabilityResolver,
)


def classified(*paths: str) -> ClassifiedDeliverable:
    return ClassifiedDeliverable(
        code="SPT-022",
        family="SPT",
        classification=DeliverableClassification.CLOSED_VERIFIED,
        confidence=95,
        reasons=("explicit_closure_evidence",),
        source_paths=tuple(paths),
        signals=ClassificationSignals(),
    )


def init_repo(root: Path) -> None:
    subprocess.run(["git", "init"], cwd=root, check=True, capture_output=True)


def test_source_type_mapping(tmp_path: Path) -> None:
    resolver = SourceTraceabilityResolver(tmp_path)

    assert resolver.source_type("releases/x.md") == "RELEASE"
    assert resolver.source_type("artifacts/pmo/x.json") == "PMO_EVIDENCE"
    assert resolver.source_type("docs/x.md") == "DOCUMENTATION"
    assert resolver.source_type("tests/test_x.py") == "TEST"
    assert resolver.source_type("src/x.py") == "CODE"
    assert resolver.source_type("tools/x.ps1") == "TOOL"


def test_resolve_marks_tracked_and_existing(tmp_path: Path) -> None:
    init_repo(tmp_path)

    path = tmp_path / "docs" / "SPT-022.md"
    path.parent.mkdir()
    path.write_text("SPT-022 CLOSED", encoding="utf-8")

    subprocess.run(
        ["git", "add", "docs/SPT-022.md"],
        cwd=tmp_path,
        check=True,
        capture_output=True,
    )

    resolver = SourceTraceabilityResolver(tmp_path)

    result = resolver.resolve(
        classified("docs/SPT-022.md")
    )

    assert result.tracked_source_count == 1
    assert result.missing_source_count == 0
    assert result.traces[0].tracked is True
    assert result.traces[0].exists is True


def test_resolve_detects_untracked(tmp_path: Path) -> None:
    init_repo(tmp_path)

    path = tmp_path / "docs" / "SPT-022.md"
    path.parent.mkdir()
    path.write_text("SPT-022", encoding="utf-8")

    resolver = SourceTraceabilityResolver(tmp_path)

    result = resolver.resolve(
        classified("docs/SPT-022.md")
    )

    assert result.tracked_source_count == 0
    assert result.traces[0].tracked is False


def test_resolve_detects_missing_source(tmp_path: Path) -> None:
    init_repo(tmp_path)

    resolver = SourceTraceabilityResolver(tmp_path)

    result = resolver.resolve(
        classified("docs/missing.md")
    )

    assert result.missing_source_count == 1
    assert result.traces[0].exists is False


def test_resolve_many_is_sorted(tmp_path: Path) -> None:
    init_repo(tmp_path)

    first = ClassifiedDeliverable(
        code="SPT-024",
        family="SPT",
        classification=DeliverableClassification.DOCUMENT_ONLY,
        confidence=40,
        reasons=("repository_reference_only",),
        source_paths=(),
        signals=ClassificationSignals(),
    )

    second = ClassifiedDeliverable(
        code="SPB-003.2",
        family="SPB",
        classification=DeliverableClassification.CLOSED_VERIFIED,
        confidence=95,
        reasons=("explicit_closure_evidence",),
        source_paths=(),
        signals=ClassificationSignals(),
    )

    resolver = SourceTraceabilityResolver(tmp_path)

    result = resolver.resolve_many((first, second))

    assert [item.code for item in result] == [
        "SPB-003.2",
        "SPT-024",
    ]