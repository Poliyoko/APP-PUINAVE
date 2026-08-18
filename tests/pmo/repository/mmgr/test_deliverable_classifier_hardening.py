import json
from pathlib import Path

from sgoda.pmo.repository.mmgr.deliverable_classifier import (
    DeliverableClassification,
    DeliverableClassifier,
)
from sgoda.pmo.repository.mmgr.repository_discovery import (
    DiscoveredDeliverable,
)


def item(
    code: str,
    family: str,
    *paths: str,
) -> DiscoveredDeliverable:
    return DiscoveredDeliverable(
        code=code,
        family=family,
        source_paths=tuple(paths),
        discovery_sources=("CONTENT",),
    )


def test_parent_does_not_inherit_child_closure(
    tmp_path: Path,
) -> None:
    path = tmp_path / "docs" / "SPT-024.10-Cierre.md"
    path.parent.mkdir(parents=True)
    path.write_text(
        "SPT-024.10 CLOSED",
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "SPT-024",
            "SPT",
            "docs/SPT-024.10-Cierre.md",
        )
    )

    assert (
        result.classification
        is not DeliverableClassification.CLOSED_VERIFIED
    )


def test_child_exact_code_can_close(
    tmp_path: Path,
) -> None:
    path = tmp_path / "docs" / "SPT-024.10-Cierre.md"
    path.parent.mkdir(parents=True)
    path.write_text(
        "SPT-024.10 CLOSED",
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "SPT-024.10",
            "SPT",
            "docs/SPT-024.10-Cierre.md",
        )
    )

    assert (
        result.classification
        is DeliverableClassification.CLOSED_VERIFIED
    )


def test_unrelated_closure_does_not_close_code(
    tmp_path: Path,
) -> None:
    path = tmp_path / "docs" / "history.md"
    path.parent.mkdir(parents=True)
    path.write_text(
        "SPT-022 reference\nSPT-024 CLOSED\n",
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "SPT-022",
            "SPT",
            "docs/history.md",
        )
    )

    assert (
        result.classification
        is DeliverableClassification.DOCUMENT_ONLY
    )


def test_tag_alone_does_not_close(
    tmp_path: Path,
) -> None:
    result = DeliverableClassifier(tmp_path).classify(
        item("SGODA-AUDIO", "AUDIO"),
        tag_names=("sgoda-audio-manager-v0.2.0",),
    )

    assert (
        result.classification
        is DeliverableClassification.UNKNOWN
    )


def test_structured_ready_status_closes(
    tmp_path: Path,
) -> None:
    path = (
        tmp_path
        / "evidence"
        / "REAL-25"
        / "summary.json"
    )
    path.parent.mkdir(parents=True)

    path.write_text(
        json.dumps(
            {
                "status": "READY",
                "summary": {
                    "total_records": 25,
                    "ready": 25,
                    "missing_wav": 0,
                    "missing_mp3": 0,
                },
            }
        ),
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "REAL-25",
            "REAL",
            "evidence/REAL-25/summary.json",
        )
    )

    assert (
        result.classification
        is DeliverableClassification.CLOSED_VERIFIED
    )
    assert result.confidence == 90


def test_structured_counts_can_close(
    tmp_path: Path,
) -> None:
    path = (
        tmp_path
        / "evidence"
        / "REAL-5"
        / "REAL-5-SUMMARY.json"
    )
    path.parent.mkdir(parents=True)

    path.write_text(
        json.dumps(
            {
                "real_5": {
                    "records": 5,
                    "processed": 5,
                    "ready": 5,
                    "errors": 0,
                }
            }
        ),
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "REAL-5",
            "REAL",
            "evidence/REAL-5/REAL-5-SUMMARY.json",
        )
    )

    assert (
        result.classification
        is DeliverableClassification.CLOSED_VERIFIED
    )
    assert result.confidence == 90


def test_structured_negative_counts_do_not_close(
    tmp_path: Path,
) -> None:
    path = (
        tmp_path
        / "evidence"
        / "REAL-25"
        / "summary.json"
    )
    path.parent.mkdir(parents=True)

    path.write_text(
        json.dumps(
            {
                "summary": {
                    "total_records": 25,
                    "ready": 24,
                    "not_ready": 1,
                }
            }
        ),
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "REAL-25",
            "REAL",
            "evidence/REAL-25/summary.json",
        )
    )

    assert (
        result.classification
        is not DeliverableClassification.CLOSED_VERIFIED
    )


def test_subdeliverable_suffix_not_parent_match(
    tmp_path: Path,
) -> None:
    path = tmp_path / "docs" / "SPT-001B-Cierre.md"
    path.parent.mkdir(parents=True)

    path.write_text(
        "SPT-001B CLOSED",
        encoding="utf-8",
    )

    result = DeliverableClassifier(tmp_path).classify(
        item(
            "SPT-001",
            "SPT",
            "docs/SPT-001B-Cierre.md",
        )
    )

    assert (
        result.classification
        is not DeliverableClassification.CLOSED_VERIFIED
    )