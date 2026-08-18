from pathlib import Path

from sgoda.pmo.repository.mmgr.deliverable_classifier import (
    DeliverableClassification,
    DeliverableClassifier,
)
from sgoda.pmo.repository.mmgr.repository_discovery import (
    DiscoveredDeliverable,
)


def item(*paths: str) -> DiscoveredDeliverable:
    return DiscoveredDeliverable(
        code="SPT-022",
        family="SPT",
        source_paths=tuple(paths),
        discovery_sources=("CONTENT",),
    )


def test_explicit_closure_document_is_closed(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    docs.mkdir()

    path = docs / "SPT-022.md"
    path.write_text("SPT-022 OFFICIALLY PUBLISHED", encoding="utf-8")

    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(item("docs/SPT-022.md"))

    assert result.classification is DeliverableClassification.CLOSED_VERIFIED
    assert result.confidence == 95


def test_closure_plus_tag_is_strong_closed(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    docs.mkdir()

    path = docs / "SPT-022.md"
    path.write_text("SPT-022 CLOSED", encoding="utf-8")

    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(
        item("docs/SPT-022.md"),
        tag_names=("SPT-022-v1.0.0",),
    )

    assert result.classification is DeliverableClassification.CLOSED_VERIFIED
    assert result.confidence == 100


def test_reference_count_does_not_imply_closure(tmp_path: Path) -> None:
    docs = tmp_path / "docs"
    docs.mkdir()

    path = docs / "history.md"
    path.write_text(
        "SPT-022\nSPT-022\nSPT-022\n",
        encoding="utf-8",
    )

    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(item("docs/history.md"))

    assert result.classification is DeliverableClassification.DOCUMENT_ONLY


def test_code_tests_evidence_is_implemented(tmp_path: Path) -> None:
    for relative in (
        "src/x.py",
        "tests/test_x.py",
        "artifacts/pmo/SPT-022/result.json",
    ):
        path = tmp_path / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text("SPT-022", encoding="utf-8")

    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(
        item(
            "src/x.py",
            "tests/test_x.py",
            "artifacts/pmo/SPT-022/result.json",
        )
    )

    assert (
        result.classification
        is DeliverableClassification.IMPLEMENTED_NOT_CLOSED
    )
    assert result.confidence == 80


def test_evidence_only_is_historical_reference(tmp_path: Path) -> None:
    path = tmp_path / "artifacts/pmo/SPT-022/result.json"
    path.parent.mkdir(parents=True)
    path.write_text("SPT-022 evidence", encoding="utf-8")

    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(
        item("artifacts/pmo/SPT-022/result.json")
    )

    assert (
        result.classification
        is DeliverableClassification.HISTORICAL_REFERENCE
    )


def test_unknown_when_no_paths(tmp_path: Path) -> None:
    classifier = DeliverableClassifier(tmp_path)

    result = classifier.classify(item())

    assert result.classification is DeliverableClassification.UNKNOWN
    assert result.confidence == 0