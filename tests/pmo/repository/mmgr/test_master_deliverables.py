import json
import sys
from dataclasses import FrozenInstanceError
from pathlib import Path

import pytest

sys.path.insert(0, str(Path(__file__).parent))

from sgoda.pmo.repository.mmgr.master_deliverables import (
    ArchitectureMapping,
    DeliverableIdentity,
    MasterDeliverable,
    Progress,
)


def build_deliverable() -> MasterDeliverable:
    return MasterDeliverable(
        identity=DeliverableIdentity(
            code="SPT-022.1",
            name="Publicacion Institucional",
            family="SPT",
        ),
        architecture=ArchitectureMapping(
            subsystems=("API", "DMP"),
            dmp_component="Calidad",
        ),
        progress=Progress(
            current_status="CLOSED",
            status_history=(
                "IMPLEMENTED",
                "VALIDATED",
                "CLOSED",
            ),
            progress_percent=100,
            weight=1,
        ),
    )


def test_master_deliverable_valid() -> None:
    item = build_deliverable()

    assert item.identity.code == "SPT-022.1"
    assert item.progress.progress_percent == 100.0


def test_subsystem_validation() -> None:
    with pytest.raises(ValueError):
        ArchitectureMapping(
            subsystems=("INVALID",)
        )


def test_dmp_component_requires_dmp() -> None:
    with pytest.raises(ValueError):
        ArchitectureMapping(
            subsystems=("API",),
            dmp_component="Calidad",
        )


def test_progress_range() -> None:
    with pytest.raises(ValueError):
        Progress(
            current_status="OPEN",
            progress_percent=101,
        )


def test_round_trip() -> None:
    original = build_deliverable()

    payload = original.to_dict()

    restored = MasterDeliverable.from_dict(payload)

    assert restored == original


def test_json_compatible() -> None:
    payload = build_deliverable().to_dict()

    json.dumps(payload)


def test_model_is_immutable() -> None:
    item = build_deliverable()

    with pytest.raises(FrozenInstanceError):
        item.identity.code = "SPT-999"
