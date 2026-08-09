from copy import deepcopy

from sgoda.integration.spt0232.analysis_service import (
    Spt0232IntelligenceService,
)
from sgoda.integration.spt0232.confidence import (
    assess_confidence,
)
from sgoda.integration.spt0232.context import assess_context
from sgoda.integration.spt0232.duplicates import (
    assess_duplicate,
    build_batch_counts,
)


class FakeSemanticValidationService:
    def __init__(self, results):
        self.results = results

    def analyze_batch(self, detector_batch):
        return {
            "component": "SPT-023.2",
            "source_component": "SPT-023.1",
            "source": detector_batch.get("source"),
            "source_batch_hash": detector_batch.get(
                "batch_hash"
            ),
            "records_received": len(
                detector_batch.get("words", [])
            ),
            "records_processed": len(self.results),
            "semantic_matches": sum(
                item.get("semantic_status") == "MATCHED"
                for item in self.results
            ),
            "review_required": 0,
            "invalid": 0,
            "skipped": 0,
            "no_invention": True,
            "next_component": "SPT-023.3",
            "results": deepcopy(self.results),
        }


def result(
    normalized="amda",
    score=95.0,
    puinave="AMDA",
    metadata=None,
):
    return {
        "source_index": 1,
        "puinave": puinave,
        "normalized_puinave": normalized,
        "lexical_hash": "hash-001",
        "input_status": "NEW",
        "validation_status": "VALIDATED",
        "semantic_status": "MATCHED",
        "semantic_query": puinave,
        "errors": [],
        "semantic_candidates": [
            {
                "entry_id": "LEX-OTHER",
                "puinave": "OTHER",
                "final_score": score,
                "validated": True,
            }
        ],
        "suggestions": [],
        "no_invention": True,
        "downstream_allowed": True,
        "metadata": (
            {
                "spanish": "ejemplo",
                "english": "example",
                "italian": "esempio",
                "definition": "test definition",
            }
            if metadata is None
            else metadata
        ),
    }


def test_batch_duplicate_is_blocked():
    items = [
        result(normalized="amda"),
        result(normalized="amda"),
    ]

    counts = build_batch_counts(items)

    assessment = assess_duplicate(
        items[0],
        counts,
    )

    assert assessment.duplicate is True
    assert assessment.duplicate_type == "BATCH_DUPLICATE"
    assert assessment.blocked is True


def test_exact_lexical_existing_is_blocked():
    item = result()
    item["semantic_candidates"][0]["puinave"] = "AMDA"
    item["semantic_candidates"][0]["entry_id"] = "PU-000001"

    assessment = assess_duplicate(
        item,
        {"amda": 1},
    )

    assert assessment.duplicate is True
    assert assessment.duplicate_type == "LEXICAL_EXISTING"
    assert "PU-000001" in assessment.references


def test_context_coverage_is_deterministic():
    item = result(
        metadata={
            "spanish": "ejemplo",
            "english": "example",
            "italian": "esempio",
        }
    )

    assessment = assess_context(item)

    assert assessment.evidence_count == 3
    assert assessment.coverage == 0.5
    assert assessment.status == "SUFFICIENT"


def test_absent_context_does_not_invent_data():
    item = result(metadata={})

    assessment = assess_context(item)

    assert assessment.coverage == 0.0
    assert assessment.status == "ABSENT"
    assert assessment.available_fields == ()


def test_confidence_penalizes_duplicate():
    item = result(score=100.0)
    context = assess_context(item)

    clean = assess_duplicate(
        item,
        {"amda": 1},
    )

    duplicate_item = deepcopy(item)
    duplicate_item["semantic_candidates"][0]["puinave"] = "AMDA"

    blocked = assess_duplicate(
        duplicate_item,
        {"amda": 1},
    )

    clean_score = assess_confidence(
        item,
        clean,
        context,
    ).score

    blocked_score = assess_confidence(
        duplicate_item,
        blocked,
        context,
    ).score

    assert blocked_score < clean_score


def test_ready_item_moves_to_category_gate():
    item = result(score=98.0)

    service = Spt0232IntelligenceService(
        FakeSemanticValidationService([item]),
        confidence_threshold=0.70,
    )

    batch = {
        "source": "test",
        "batch_hash": "batch-001",
        "words": [{}],
    }

    output = service.analyze_batch(batch)

    enriched = output["results"][0]

    assert enriched["institutional_decision"] == (
        "READY_FOR_CATEGORY"
    )
    assert enriched["downstream_allowed"] is True
    assert output["ready_for_category"] == 1
    assert output["policy"]["no_invention"] is True


def test_duplicate_never_moves_downstream():
    item = result(score=100.0)
    item["semantic_candidates"][0]["puinave"] = "AMDA"

    service = Spt0232IntelligenceService(
        FakeSemanticValidationService([item])
    )

    output = service.analyze_batch(
        {
            "source": "test",
            "batch_hash": "batch-002",
            "words": [{}],
        }
    )

    enriched = output["results"][0]

    assert enriched["institutional_decision"] == (
        "DUPLICATE_BLOCKED"
    )
    assert enriched["downstream_allowed"] is False
    assert enriched["requires_human_validation"] is True


def test_capa2_does_not_mutate_capa1_payload():
    item = result()
    original = deepcopy(item)

    service = Spt0232IntelligenceService(
        FakeSemanticValidationService([item])
    )

    service.analyze_batch(
        {
            "source": "test",
            "batch_hash": "batch-003",
            "words": [{}],
        }
    )

    assert item == original


def test_low_confidence_requires_human_review():
    item = result(
        score=10.0,
        metadata={},
    )

    service = Spt0232IntelligenceService(
        FakeSemanticValidationService([item]),
        confidence_threshold=0.70,
    )

    output = service.analyze_batch(
        {
            "source": "test",
            "batch_hash": "batch-004",
            "words": [{}],
        }
    )

    enriched = output["results"][0]

    assert enriched["institutional_decision"] == (
        "HUMAN_REVIEW_REQUIRED"
    )
    assert enriched["downstream_allowed"] is False