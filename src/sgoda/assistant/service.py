"""Servicio principal del Asistente Inteligente Institucional."""

from __future__ import annotations

import json
import re
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .faq import FaqRepository
from .intent_classifier import classify_intent, normalize_text
from .knowledge_repository import KnowledgeRepository
from .models import (
    ConsultaAsistente,
    FuenteRespuesta,
    RespuestaAsistente,
)


SAFE_FALLBACK = (
    "No encontré una respuesta validada para esta consulta. "
    "La pregunta quedó registrada para revisión lingüística, "
    "educativa o cultural."
)


class InstitutionalAssistant:
    def __init__(
        self,
        *,
        repository: KnowledgeRepository,
        faq: FaqRepository,
        unresolved_path: str | Path,
        display_name: str = "Asistente Virtual SGODA",
    ) -> None:
        self.repository = repository
        self.faq = faq
        self.unresolved_path = Path(unresolved_path)
        self.display_name = display_name

    @staticmethod
    def _extract_search_term(question: str) -> str:
        normalized = normalize_text(question)
        patterns = (
            r"como se dice\s+(.+?)(?:\s+en puinave)?$",
            r"que significa\s+(.+)$",
            r"traduccion de\s+(.+)$",
            r"palabra\s+(.+)$",
        )

        for pattern in patterns:
            match = re.search(pattern, normalized)
            if match:
                return match.group(1).strip(" ?¿!¡.")

        return question.strip(" ?¿!¡.")

    def _record_unresolved(
        self,
        query: ConsultaAsistente,
        intent: str,
    ) -> None:
        self.unresolved_path.parent.mkdir(
            parents=True,
            exist_ok=True,
        )

        record = {
            "occurred_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "question": query.question,
            "language": query.language,
            "user_role": query.user_role,
            "session_id": query.session_id,
            "intent": intent,
            "status": "pending_human_review",
        }

        with self.unresolved_path.open(
            "a",
            encoding="utf-8",
        ) as stream:
            stream.write(
                json.dumps(record, ensure_ascii=False) + "\n"
            )

    def answer(
        self,
        query: ConsultaAsistente,
    ) -> RespuestaAsistente:
        question = query.question.strip()

        if not question:
            return RespuestaAsistente(
                answer="Escribe una pregunta para poder ayudarte.",
                intent="empty",
                confidence=1.0,
                validated=True,
                found=False,
            )

        intent, confidence = classify_intent(question)

        if intent in {"platform_help", "project_information"}:
            faq_item = self.faq.search(question)
            if faq_item is not None:
                return RespuestaAsistente(
                    answer=str(faq_item["answer"]),
                    intent=intent,
                    confidence=confidence,
                    validated=True,
                    found=True,
                    sources=[
                        FuenteRespuesta(
                            source_type="institutional_faq",
                            source_id=str(faq_item["id"]),
                            label="Preguntas frecuentes institucionales",
                            path="config/assistant/SPT-004A-faq.json",
                        )
                    ],
                    suggestions=list(
                        faq_item.get("suggestions", [])
                    ),
                )

        if intent in {
            "lexical_search",
            "category_search",
            "learning_activity",
        }:
            term = self._extract_search_term(question)
            results = self.repository.search_lexical(
                term,
                limit=10 if intent == "category_search" else 5,
            )

            if results:
                first = results[0]
                puinave = first.get("puinave") or "No registrada"
                spanish = first.get("spanish") or "No registrada"
                english = first.get("english") or "No registrada"
                canonical_id = str(
                    first.get("canonical_id") or "sin-id"
                )

                oda = self.repository.find_oda(
                    first.get("canonical_id")
                )

                if len(results) == 1:
                    answer = (
                        f"Encontré una entrada validada. "
                        f"Puinave: «{puinave}». "
                        f"Español: «{spanish}». "
                        f"Inglés: «{english}»."
                    )
                else:
                    preview = "; ".join(
                        str(item.get("puinave") or item.get("spanish"))
                        for item in results[:5]
                    )
                    answer = (
                        f"Encontré {len(results)} entradas relacionadas: "
                        f"{preview}."
                    )

                sources = [
                    FuenteRespuesta(
                        source_type="canonical_lexical_repository",
                        source_id=canonical_id,
                        label="Repositorio Léxico Canónico",
                        path=(
                            "artifacts/rlb/SPT-001B-P08/"
                            "canonical-repository-v1.0.0.json"
                        ),
                    )
                ]

                if oda is not None:
                    oda_id = str(
                        oda.get("oda_id")
                        or oda.get("id")
                        or canonical_id
                    )
                    sources.append(
                        FuenteRespuesta(
                            source_type="oda_repository",
                            source_id=oda_id,
                            label="Repositorio de ODA",
                            path=(
                                "artifacts/oda/SPT-002/"
                                "oda-repository-v0.1.0.json"
                            ),
                        )
                    )

                return RespuestaAsistente(
                    answer=answer,
                    intent=intent,
                    confidence=confidence,
                    validated=True,
                    found=True,
                    sources=sources,
                    suggestions=[
                        "Escuchar pronunciación",
                        "Ver imagen",
                        "Practicar esta palabra",
                    ],
                    data={
                        "matches": results,
                        "oda": oda,
                    },
                )

        self._record_unresolved(query, intent)

        return RespuestaAsistente(
            answer=SAFE_FALLBACK,
            intent=intent,
            confidence=confidence,
            validated=False,
            found=False,
            sources=[],
            suggestions=[
                "Buscar una palabra",
                "Cómo usar la plataforma",
                "Conocer el proyecto",
            ],
            requires_human_review=True,
        )