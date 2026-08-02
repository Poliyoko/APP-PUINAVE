import json
from pathlib import Path

from sgoda.lexical_engine.relations import (
    SemanticRelationRepository,
)
from sgoda.lexical_engine.repository import LexicalRepository
from sgoda.lexical_engine.search import LexicalSearchEngine
from sgoda.lexical_engine.semantic_index import SemanticLexicalIndex
from sgoda.lexical_engine.semantic_service import (
    SemanticLexicalService,
)
from sgoda.lexical_engine.suggestions import suggest_terms


def _repository() -> LexicalRepository:
    return LexicalRepository.from_records(
        [
            {
                "id": "LEX-001",
                "puinave": "AMDA",
                "spanish": "casa",
                "english_us": "house",
                "italian": "casa",
                "validated": True,
                "category": "sustantivo",
                "variants": ["amdaa"],
            },
            {
                "id": "LEX-002",
                "puinave": "AMDA-KU",
                "spanish": "hogar",
                "english_us": "home",
                "italian": "dimora",
                "validated": True,
                "category": "sustantivo",
            },
            {
                "id": "LEX-003",
                "puinave": "DAPA",
                "spanish": "agua",
                "english_us": "water",
                "italian": "acqua",
                "validated": True,
                "category": "sustantivo",
            },
        ]
    )


def _relations() -> SemanticRelationRepository:
    return SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-002",
                "relation_type": "synonym",
                "weight": 1.0,
                "validated": True,
            },
            {
                "source_id": "LEX-002",
                "target_id": "LEX-001",
                "relation_type": "family",
                "weight": 0.8,
                "validated": True,
            },
        ]
    )


def _service() -> SemanticLexicalService:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        variants = tuple(entry.metadata.get("variants", []))
        index.add_entry(entry, variants=variants)

    return SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        _relations(),
    )


def test_SPT_007B_builds_multilingual_index() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    assert index.exact("house") == ("LEX-001",)
    assert index.exact("agua") == ("LEX-003",)
    assert index.token("casa") == ("LEX-001",)


def test_SPT_007B_indexes_explicit_variants() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()
    entry = repository.all()[0]
    index.add_entry(entry, variants=("amdaa",))

    assert index.variant("amdaa") == ("LEX-001",)


def test_SPT_007B_reads_relations() -> None:
    relations = _relations()
    outgoing = relations.outgoing("LEX-001")

    assert len(outgoing) == 1
    assert outgoing[0].relation_type == "synonym"
    assert outgoing[0].target_id == "LEX-002"


def test_SPT_007B_expands_results_by_relation() -> None:
    response = _service().search("casa")

    ids = {item.entry_id for item in response.hits}
    assert "LEX-001" in ids
    assert "LEX-002" in ids


def test_SPT_007B_hybrid_ranking_is_deterministic() -> None:
    service = _service()

    first = service.search("casa")
    second = service.search("casa")

    assert first.hits == second.hits
    assert first.hits[0].entry_id == "LEX-001"


def test_SPT_007B_reports_relation_explanation() -> None:
    response = _service().search("casa")
    related = next(
        item
        for item in response.hits
        if item.entry_id == "LEX-002"
    )

    assert "synonym" in related.relation_types
    assert related.relation_score > 0


def test_SPT_007B_generates_safe_suggestions() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    suggestions = suggest_terms(
        "hous",
        index,
        threshold=0.40,
    )

    assert "house" in suggestions


def test_SPT_007B_no_invention_contract() -> None:
    response = _service().search("zzzz inexistente")

    assert response.no_invention is True
    assert all(
        _service().index.get(item.entry_id) is not None
        for item in response.hits
    )


def test_SPT_007B_serializes_multilingual_result() -> None:
    service = _service()
    payload = service.to_dict(service.search("house"))

    assert payload["results"][0]["puinave"] == "AMDA"
    assert payload["results"][0]["english_us"] == "house"
    assert payload["no_invention"] is True


def test_SPT_007B_reads_json_relations(tmp_path: Path) -> None:
    path = tmp_path / "relations.json"
    path.write_text(
        json.dumps(
            {
                "relations": [
                    {
                        "source_id": "LEX-001",
                        "target_id": "LEX-002",
                        "relation_type": "related",
                        "validated": True,
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    repository = SemanticRelationRepository.from_json(path)

    assert repository.outgoing("LEX-001")[0].target_id == "LEX-002"


def test_SPT_007B_rejects_unknown_relation_types() -> None:
    repository = SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-002",
                "relation_type": "invented_relation",
            }
        ]
    )

    assert repository.outgoing("LEX-001") == ()


def test_SPT_007B_only_uses_validated_relations_by_default() -> None:
    repository = _repository()
    index = SemanticLexicalIndex()

    for entry in repository.all():
        index.add_entry(entry)

    relations = SemanticRelationRepository.from_records(
        [
            {
                "source_id": "LEX-001",
                "target_id": "LEX-003",
                "relation_type": "related",
                "validated": False,
            }
        ]
    )

    service = SemanticLexicalService(
        LexicalSearchEngine(repository),
        index,
        relations,
    )
    response = service.search("casa")

    related = [
        item
        for item in response.hits
        if item.entry_id == "LEX-003"
    ]
    assert related == []