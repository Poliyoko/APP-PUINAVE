from pathlib import Path

from sgoda.automation.spt022.platform import (
    AutomationPlatform,
    OperationStatus,
)


def platform(tmp_path: Path) -> AutomationPlatform:
    return AutomationPlatform(tmp_path)


def test_default_operations_are_registered(tmp_path):
    p = platform(tmp_path)
    assert set(p.workflow_ids()) == {
        "data-intake",
        "master-book-update",
        "repository-prepare",
        "repository-publish",
        "repository-audit",
    }


def test_publish_requires_approval(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-publish")
    assert item.approval_required is True
    assert item.status == OperationStatus.REQUIRES_APPROVAL


def test_data_intake_requires_input(tmp_path):
    p = platform(tmp_path)
    assert p.get("data-intake").status == OperationStatus.REQUIRES_INPUT


def test_master_book_reuses_spt0213(tmp_path):
    p = platform(tmp_path)
    assert p.get("master-book-update").source_component == "SPT-021.3"


def test_prepare_reuses_publication_engine(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-prepare")
    assert "SPT-021.0.1" in item.source_component


def test_catalog_serializes(tmp_path):
    p = platform(tmp_path)
    rows = p.as_dicts()
    assert len(rows) == 5
    assert all("operation_id" in row for row in rows)


def test_operation_ids_unique(tmp_path):
    p = platform(tmp_path)
    ids = list(p.workflow_ids())
    assert len(ids) == len(set(ids))


def test_no_automatic_publish(tmp_path):
    p = platform(tmp_path)
    item = p.get("repository-publish")
    assert item.status != OperationStatus.READY


def test_unknown_operation_raises_key_error(tmp_path):
    p = platform(tmp_path)
    try:
        p.get("does-not-exist")
    except KeyError:
        pass
    else:
        raise AssertionError("KeyError expected")


def test_paths_validation_returns_all_operations(tmp_path):
    p = platform(tmp_path)
    status = p.validate_paths()
    assert set(status) == set(p.workflow_ids())