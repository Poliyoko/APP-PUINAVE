"""Pruebas SPT-004A del Asistente Inteligente Institucional."""

import json
from pathlib import Path

from sgoda.assistant.faq import FaqRepository
from sgoda.assistant.intent_classifier import classify_intent
from sgoda.assistant.knowledge_repository import KnowledgeRepository
from sgoda.assistant.models import ConsultaAsistente
from sgoda.assistant.service import InstitutionalAssistant


def _files(tmp_path: Path) -> tuple[Path, Path, Path]:
    canonical = tmp_path / "canonical.json"
    oda = tmp_path / "oda.json"
    faq = tmp_path / "faq.json"

    canonical.write_text(
        json.dumps(
            {
                "records": [
                    {
                        "canonical_id": "LEX-001",
                        "puinave": "AMDA",
                        "espanol": "ejemplo",
                        "ingles": "example",
                        "categoria": "aprendizaje",
                    },
                    {
                        "canonical_id": "LEX-002",
                        "puinave": "WAI",
                        "espanol": "agua",
                        "ingles": "water",
                        "categoria": "naturaleza",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    oda.write_text(
        json.dumps(
            {
                "objetos_digitales_aprendizaje": [
                    {
                        "oda_id": "ODA-001",
                        "canonical_id": "LEX-001",
                        "title": "AMDA",
                    }
                ]
            }
        ),
        encoding="utf-8",
    )

    faq.write_text(
        json.dumps(
            {
                "items": [
                    {
                        "id": "FAQ-001",
                        "keywords": ["como buscar", "buscar palabra"],
                        "answer": "Usa el buscador principal.",
                        "suggestions": ["Buscar una palabra"],
                    },
                    {
                        "id": "FAQ-002",
                        "keywords": ["que es sgoda"],
                        "answer": "SGODA preserva y enseña la lengua Puinave.",
                    },
                ]
            }
        ),
        encoding="utf-8",
    )

    return canonical, oda, faq


def _assistant(tmp_path: Path) -> InstitutionalAssistant:
    canonical, oda, faq = _files(tmp_path)
    return InstitutionalAssistant(
        repository=KnowledgeRepository(
            canonical_path=canonical,
            oda_path=oda,
        ),
        faq=FaqRepository(faq),
        unresolved_path=tmp_path / "unresolved.jsonl",
    )


def test_SPT_004A_clasifica_busqueda_lexica() -> None:
    intent, confidence = classify_intent(
        "¿Cómo se dice agua en Puinave?"
    )
    assert intent == "lexical_search"
    assert confidence > 0.8


def test_SPT_004A_clasifica_ayuda() -> None:
    intent, _ = classify_intent(
        "¿Cómo buscar una palabra?"
    )
    assert intent == "platform_help"


def test_SPT_004A_busca_repositorio_canonico(
    tmp_path: Path,
) -> None:
    canonical, oda, _ = _files(tmp_path)
    repository = KnowledgeRepository(
        canonical_path=canonical,
        oda_path=oda,
    )

    results = repository.search_lexical("agua")

    assert len(results) == 1
    assert results[0]["puinave"] == "WAI"


def test_SPT_004A_relaciona_oda(tmp_path: Path) -> None:
    canonical, oda, _ = _files(tmp_path)
    repository = KnowledgeRepository(
        canonical_path=canonical,
        oda_path=oda,
    )

    result = repository.find_oda("LEX-001")

    assert result is not None
    assert result["oda_id"] == "ODA-001"


def test_SPT_004A_responde_con_fuente_validada(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cómo se dice agua en Puinave?"
        )
    )

    assert response.found is True
    assert response.validated is True
    assert "WAI" in response.answer
    assert response.sources[0].source_type == (
        "canonical_lexical_repository"
    )


def test_SPT_004A_responde_pregunta_frecuente(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cómo buscar una palabra?"
        )
    )

    assert response.found is True
    assert "buscador principal" in response.answer
    assert response.intent == "platform_help"


def test_SPT_004A_no_inventa_respuesta(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(
            question="¿Cuál es la traducción de una palabra inexistente?"
        )
    )

    assert response.found is False
    assert response.validated is False
    assert response.requires_human_review is True
    assert "No encontré una respuesta validada" in response.answer


def test_SPT_004A_registra_pregunta_no_resuelta(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)
    unresolved = tmp_path / "unresolved.jsonl"

    assistant.answer(
        ConsultaAsistente(
            question="Pregunta completamente desconocida",
            session_id="session-test",
        )
    )

    assert unresolved.is_file()
    payload = json.loads(
        unresolved.read_text(encoding="utf-8").strip()
    )
    assert payload["status"] == "pending_human_review"
    assert payload["session_id"] == "session-test"


def test_SPT_004A_rechaza_pregunta_vacia(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(question="   ")
    )

    assert response.intent == "empty"
    assert response.found is False
    assert response.validated is True


def test_SPT_004A_fuentes_no_vacias_en_respuesta_lexica(
    tmp_path: Path,
) -> None:
    assistant = _assistant(tmp_path)

    response = assistant.answer(
        ConsultaAsistente(question="AMDA")
    )

    assert response.found is True
    assert len(response.sources) >= 1
    assert all(source.validated for source in response.sources)