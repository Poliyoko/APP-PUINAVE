from copy import deepcopy
from pathlib import Path

import pytest

from sgoda.integration.spt0232.evidence import (
    Spt0232EvidenceStore,
)
from sgoda.integration.spt0232.pipeline_service import (
    Spt0232ProductionPipeline,
)
from sgoda.integration.spt0232.production_contract import (
    to_detector_batch,
    validate_production_request,
)


class FakeIntelligenceService:
    def analyze_batch(self, batch):
        return {
            "component": "SPT-023.2",
            "source_component": "SPT-023.1",
            "source": batch["source"],
            "source_batch_hash": batch[
                "batch_hash"
            ],
            "records_received": len(
                batch["words"]
            ),
            "records_processed": len(
                batch["words"]
            ),
            "ready_for_category": 1,
            "duplicate_blocked": 0,
            "human_review_required": 0,
            "policy": {
                "no_invention": True,
            },
            "results": [
                {
                    "lexical_hash": "LEX-001",
                    "institutional_decision": (
                        "READY_FOR_CATEGORY"
                    ),
                    "downstream_allowed": True,
                }
            ],
        }


def request_payload():
    return {
        "source": "dictionary.xlsx",
        "batch_hash": "BATCH-CAPA4",
        "words": [
            {
                "source_index": 1,
                "puinave": "AMDA",
                "normalized_puinave": "amda",
                "lexical_hash": "LEX-001",
                "status": "NEW",
                "metadata": {},
            }
        ],
    }


def test_production_contract_accepts_valid_request():
    request = validate_production_request(
        request_payload()
    )

    assert request.source == "dictionary.xlsx"
    assert request.batch_hash == "BATCH-CAPA4"
    assert len(request.words) == 1


def test_production_contract_rejects_missing_source():
    payload = request_payload()
    payload["source"] = ""

    with pytest.raises(
        ValueError,
        match="source",
    ):
        validate_production_request(payload)


def test_production_contract_rejects_missing_hash():
    payload = request_payload()
    payload["batch_hash"] = ""

    with pytest.raises(
        ValueError,
        match="batch_hash",
    ):
        validate_production_request(payload)


def test_production_contract_rejects_invalid_words():
    payload = request_payload()
    payload["words"] = "invalid"

    with pytest.raises(
        ValueError,
        match="words",
    ):
        validate_production_request(payload)


def test_detector_batch_is_copy():
    payload = request_payload()

    request = validate_production_request(
        payload
    )

    batch = to_detector_batch(request)

    batch["words"][0]["puinave"] = "CHANGED"

    assert payload["words"][0]["puinave"] == (
        "AMDA"
    )


def test_productive_pipeline_persists_evidence(
    tmp_path,
):
    pipeline = Spt0232ProductionPipeline(
        FakeIntelligenceService(),
        Spt0232EvidenceStore(tmp_path),
    )

    result = pipeline.process(
        request_payload(),
        run_id="RUN-CAPA4",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    assert result["status"] == "PROCESSED"
    assert result["component"] == "SPT-023.2"
    assert result["layer"] == "CAPA_4"
    assert result["ready_for_category"] == 1
    assert result["no_invention"] is True

    run_dir = Path(
        result["evidence"]["run_dir"]
    )

    assert (
        run_dir / "analysis.json"
    ).exists()

    assert (
        run_dir / "traceability.json"
    ).exists()

    assert (
        run_dir / "manifest.json"
    ).exists()


def test_productive_pipeline_preserves_input(
    tmp_path,
):
    payload = request_payload()
    original = deepcopy(payload)

    pipeline = Spt0232ProductionPipeline(
        FakeIntelligenceService(),
        Spt0232EvidenceStore(tmp_path),
    )

    pipeline.process(
        payload,
        run_id="RUN-IMMUTABLE",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    assert payload == original


def test_next_component_remains_unresolved_until_reconciliation(
    tmp_path,
):
    pipeline = Spt0232ProductionPipeline(
        FakeIntelligenceService(),
        Spt0232EvidenceStore(tmp_path),
    )

    result = pipeline.process(
        request_payload(),
        run_id="RUN-NEXT",
        generated_at="2026-08-09T00:00:00+00:00",
    )

    assert result["next_component"] == (
        "CATEGORY_ENGINE_PENDING_RECONCILIATION"
    )