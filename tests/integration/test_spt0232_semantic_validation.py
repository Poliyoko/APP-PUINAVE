from copy import deepcopy

from sgoda.integration.spt0232.service import (
    Spt0232SemanticValidationService,
)


class FakeResponse:
    pass


class FakeSemanticService:
    def __init__(self, results=None, suggestions=None):
        self.results = list(results or [])
        self.suggestions = list(suggestions or [])
        self.calls = []

    def search(
        self,
        query,
        limit=20,
        validated_relations_only=True,
    ):
        self.calls.append(
            {
                "query": query,
                "limit": limit,
                "validated_relations_only": validated_relations_only,
            }
        )
        return FakeResponse()

    def to_dict(self, response):
        return {
            "query": "",
            "normalized_query": "",
            "total": len(self.results),
            "suggestions": self.suggestions,
            "no_invention": True,
            "results": self.results,
        }


def new_word():
    return {
        "source_index": 1,
        "puinave": "AMDA",
        "normalized_puinave": "amda",
        "lexical_hash": "abc123",
        "status": "NEW",
        "validation_required": True,
        "metadata": {
            "spanish": "ejemplo",
        },
    }


def test_new_word_with_semantic_match_allows_downstream():
    semantic = FakeSemanticService(
        results=[
            {
                "entry_id": "LEX-001",
                "final_score": 95.0,
                "puinave": "AMDA",
                "spanish": "ejemplo",
                "validated": True,
            }
        ]
    )
    service = Spt0232SemanticValidationService(semantic)

    result = service.analyze_word(new_word())

    assert result.validation_status == "VALIDATED"
    assert result.semantic_status == "MATCHED"
    assert result.downstream_allowed is True
    assert result.no_invention is True
    assert len(result.semantic_candidates) == 1
    assert semantic.calls[0]["validated_relations_only"] is True


def test_new_word_without_semantic_match_requires_review():
    semantic = FakeSemanticService()
    service = Spt0232SemanticValidationService(semantic)

    result = service.analyze_word(new_word())

    assert result.validation_status == "VALIDATED_NO_MATCH"
    assert result.semantic_status == "REVIEW_REQUIRED"
    assert result.downstream_allowed is False
    assert result.no_invention is True


def test_existing_word_is_not_reprocessed():
    semantic = FakeSemanticService()
    service = Spt0232SemanticValidationService(semantic)
    word = new_word()
    word["status"] = "EXISTING"

    result = service.analyze_word(word)

    assert result.validation_status == "SKIPPED"
    assert result.semantic_status == "NOT_APPLICABLE"
    assert result.downstream_allowed is False
    assert semantic.calls == []


def test_invalid_new_word_does_not_call_semantic_engine():
    semantic = FakeSemanticService()
    service = Spt0232SemanticValidationService(semantic)
    word = new_word()
    word["puinave"] = ""

    result = service.analyze_word(word)

    assert result.validation_status == "INVALID"
    assert result.semantic_status == "NOT_EXECUTED"
    assert "PUINAVE_REQUIRED" in result.errors
    assert semantic.calls == []


def test_batch_preserves_pipeline_contract():
    semantic = FakeSemanticService(
        results=[
            {
                "entry_id": "LEX-001",
                "final_score": 90.0,
                "validated": True,
            }
        ]
    )
    service = Spt0232SemanticValidationService(semantic)

    batch = {
        "source": "dictionary.json",
        "batch_hash": "batch-001",
        "words": [new_word()],
    }

    result = service.analyze_batch(batch)

    assert result["component"] == "SPT-023.2"
    assert result["source_component"] == "SPT-023.1"
    assert result["next_component"] == "SPT-023.3"
    assert result["semantic_matches"] == 1
    assert result["review_required"] == 0
    assert result["no_invention"] is True


def test_input_payload_is_not_mutated():
    semantic = FakeSemanticService()
    service = Spt0232SemanticValidationService(semantic)
    word = new_word()
    original = deepcopy(word)

    service.analyze_word(word)

    assert word == original


def test_batch_counts_skipped_and_review_required():
    semantic = FakeSemanticService()
    service = Spt0232SemanticValidationService(semantic)

    existing = new_word()
    existing["source_index"] = 2
    existing["status"] = "EXISTING"

    batch = {
        "source": "dictionary.json",
        "batch_hash": "batch-002",
        "words": [
            new_word(),
            existing,
        ],
    }

    result = service.analyze_batch(batch)

    assert result["records_received"] == 2
    assert result["records_processed"] == 2
    assert result["review_required"] == 1
    assert result["skipped"] == 1