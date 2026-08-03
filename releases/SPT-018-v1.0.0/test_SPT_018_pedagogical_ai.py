
from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.pedagogical_ai.models import (
    LearnerProfile,
    PedagogicalContext,
)
from sgoda.pedagogical_ai.service import PedagogicalAIService


def _service(tmp_path: Path) -> PedagogicalAIService:
    service = PedagogicalAIService(
        tmp_path / "knowledge.json"
    )
    service.knowledge_center.ingest_dictionary_entry(
        {
            "id": "AMDA",
            "word": "AMDA",
            "meaning": "Entrada demostrativa.",
            "language": "pui",
            "tags": ["diccionario"],
        }
    )
    return service


def test_health_is_native_and_open(
    tmp_path: Path,
) -> None:
    health = _service(tmp_path).health()

    assert health["component"] == "SPT-018"
    assert health["status"] == "operational"
    assert health["native_ecosystem"] is True
    assert health["mandatory_proprietary_dependencies"] == []
    assert health["knowledge_source"] == "SPT-017"


def test_recommendation_uses_knowledge_center(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-001",
            needs=("vocabulario",),
            recent_scores=(0.60, 0.70),
        ),
        PedagogicalContext(
            objective="Aprender AMDA",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["content_ids"] == ["lex:AMDA"]
    assert payload["strategy"] == "contextual_lexical_practice"
    assert payload["difficulty"] == "guided"


def test_low_scores_trigger_reinforcement(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-002",
            recent_scores=(0.20, 0.40),
        ),
        PedagogicalContext(
            objective="Reforzar",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["difficulty"] == "reinforcement"


def test_high_scores_trigger_challenge(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-003",
            recent_scores=(0.90, 0.95),
        ),
        PedagogicalContext(
            objective="Profundizar",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert payload["difficulty"] == "challenge"


def test_pronunciation_need_selects_multimedia(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(
            learner_id="L-004",
            needs=("pronunciación",),
        ),
        PedagogicalContext(
            objective="Pronunciar AMDA",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    assert (
        payload["strategy"]
        == "multimedia_pronunciation_practice"
    )


def test_sensitive_domain_is_blocked_without_permission(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-005"),
        PedagogicalContext(
            objective="Consultar contenido ceremonial",
            knowledge_query="ceremonia",
            cultural_domain="ceremonial",
        ),
    )

    assert payload["status"] == "blocked"
    assert payload["strategy"] == "human_cultural_review"
    assert "community_authorization_required" in payload["safeguards"]


def test_sensitive_domain_can_be_authorized(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    service.knowledge_center.ingest_cultural_record(
        {
            "id": "CER-001",
            "title": "Registro autorizado",
            "summary": "Contenido autorizado.",
            "cultural_domain": "ceremonial",
        }
    )

    payload = service.recommend(
        LearnerProfile(learner_id="L-006"),
        PedagogicalContext(
            objective="Actividad autorizada",
            knowledge_query="autorizado",
            cultural_domain="ceremonial",
        ),
        permissions=("community_authorized",),
    )

    assert payload["status"] == "proposed"
    assert payload["content_ids"] == ["culture:CER-001"]


def test_recommendation_is_explainable(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-007"),
        PedagogicalContext(
            objective="Aprender",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    evidence = payload["metadata"]["decision_evidence"]

    assert evidence["explainable"] is True
    assert evidence["source_components"] == [
        "SPT-017",
        "SPT-016",
        "SPT-015",
    ]
    assert payload["explanation"]


def test_recommendation_id_is_deterministic(
    tmp_path: Path,
) -> None:
    service = _service(tmp_path)
    profile = LearnerProfile(learner_id="L-008")
    context = PedagogicalContext(
        objective="Aprender",
        knowledge_query="AMDA",
        cultural_domain="language",
    )

    first = service.recommend(profile, context)
    second = service.recommend(profile, context)

    assert first["recommendation_id"] == second["recommendation_id"]


def test_invalid_learner_is_rejected(
    tmp_path: Path,
) -> None:
    with pytest.raises(ValueError):
        _service(tmp_path).recommend(
            LearnerProfile(learner_id=""),
            PedagogicalContext(
                objective="Aprender",
                knowledge_query="AMDA",
            ),
        )


def test_result_is_json_serializable(
    tmp_path: Path,
) -> None:
    payload = _service(tmp_path).recommend(
        LearnerProfile(learner_id="L-009"),
        PedagogicalContext(
            objective="Aprender",
            knowledge_query="AMDA",
            cultural_domain="language",
        ),
    )

    json.dumps(payload, ensure_ascii=False)


def test_existing_tutor_is_importable() -> None:
    import sgoda.tutor as tutor

    assert tutor is not None
