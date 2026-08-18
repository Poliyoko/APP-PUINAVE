import csv
import json
from pathlib import Path

import pytest

from sgoda.pmo.repository.mmgr.deliverable_classifier import (
    ClassifiedDeliverable,
    ClassificationSignals,
    DeliverableClassification,
)
from sgoda.pmo.repository.mmgr.master_matrix_generator import (
    MasterMatrixGenerator,
)
from sgoda.pmo.repository.mmgr.source_traceability import (
    DeliverableTraceability,
    SourceTrace,
)


def classified(
    code: str,
    family: str = "SPT",
    *paths: str,
) -> ClassifiedDeliverable:
    return ClassifiedDeliverable(
        code=code,
        family=family,
        classification=DeliverableClassification.CLOSED_VERIFIED,
        confidence=95,
        reasons=("explicit_closure_evidence",),
        source_paths=tuple(paths),
        signals=ClassificationSignals(),
    )


def traced(
    code: str,
    family: str = "SPT",
    *paths: str,
) -> DeliverableTraceability:
    return DeliverableTraceability(
        code=code,
        family=family,
        classification="CLOSED_VERIFIED",
        confidence=95,
        traces=tuple(
            SourceTrace(
                path=path,
                source_type="DOCUMENTATION",
                tracked=True,
                exists=True,
            )
            for path in paths
        ),
    )


def test_build_rows(tmp_path: Path) -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (
            classified(
                "SPT-022",
                "SPT",
                "docs/SPT-022.md",
            ),
        ),
        (
            traced(
                "SPT-022",
                "SPT",
                "docs/SPT-022.md",
            ),
        ),
    )

    assert len(rows) == 1
    assert rows[0].code == "SPT-022"
    assert rows[0].source_path_count == 1
    assert rows[0].tracked_source_count == 1


def test_rows_are_sorted() -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (
            classified("SPT-024"),
            classified("SPB-003.2", "SPB"),
        ),
        (
            traced("SPT-024"),
            traced("SPB-003.2", "SPB"),
        ),
    )

    assert [row.code for row in rows] == [
        "SPB-003.2",
        "SPT-024",
    ]


def test_missing_traceability_fails() -> None:
    generator = MasterMatrixGenerator()

    with pytest.raises(ValueError):
        generator.build_rows(
            (classified("SPT-022"),),
            (),
        )


def test_family_mismatch_fails() -> None:
    generator = MasterMatrixGenerator()

    with pytest.raises(ValueError):
        generator.build_rows(
            (classified("SPT-022", "SPT"),),
            (traced("SPT-022", "SPB"),),
        )


def test_json_output(tmp_path: Path) -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (classified("SPT-022"),),
        (traced("SPT-022"),),
    )

    path = generator.write_json(
        rows,
        tmp_path / "matrix.json",
    )

    payload = json.loads(
        path.read_text(encoding="utf-8")
    )

    assert payload["schema_version"] == "1.0.0"
    assert payload["record_count"] == 1
    assert payload["records"][0]["code"] == "SPT-022"


def test_csv_output(tmp_path: Path) -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (classified("SPT-022"),),
        (traced("SPT-022"),),
    )

    path = generator.write_csv(
        rows,
        tmp_path / "matrix.csv",
    )

    with path.open(
        encoding="utf-8",
        newline="",
    ) as handle:
        records = list(csv.DictReader(handle))

    assert len(records) == 1
    assert records[0]["code"] == "SPT-022"


def test_markdown_output(tmp_path: Path) -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (classified("SPT-022"),),
        (traced("SPT-022"),),
    )

    path = generator.write_markdown(
        rows,
        tmp_path / "matrix.md",
    )

    text = path.read_text(encoding="utf-8")

    assert "Matriz Maestra de Entregables" in text
    assert "SPT-022" in text


def test_outputs_do_not_invent_progress_fields(tmp_path: Path) -> None:
    generator = MasterMatrixGenerator()

    rows = generator.build_rows(
        (classified("SPT-022"),),
        (traced("SPT-022"),),
    )

    path = generator.write_json(
        rows,
        tmp_path / "matrix.json",
    )

    payload = json.loads(
        path.read_text(encoding="utf-8")
    )

    record = payload["records"][0]

    assert "progress_percent" not in record
    assert "weight" not in record