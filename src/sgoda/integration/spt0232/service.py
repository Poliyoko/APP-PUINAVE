"""Servicio adaptador de validacion semantica SPT-023.2."""

from __future__ import annotations

from typing import Any

from sgoda.lexical_engine.semantic_service import SemanticLexicalService

from .models import SemanticValidationResult
from .validator import detector_metadata, validate_detector_word


class Spt0232SemanticValidationService:
    """Consume detecciones SPT-023.1 y reutiliza SPT-007B.

    La capa no crea significados, relaciones ni categorias.
    Cuando no existe evidencia semantica suficiente, deriva el
    elemento a revision institucional.
    """

    def __init__(
        self,
        semantic_service: SemanticLexicalService,
        limit: int = 10,
    ) -> None:
        self.semantic_service = semantic_service
        self.limit = max(1, int(limit))

    def analyze_word(
        self,
        word: dict[str, Any],
    ) -> SemanticValidationResult:
        errors = validate_detector_word(word)

        source_index = int(word.get("source_index") or 0)
        puinave = str(word.get("puinave") or "").strip()
        normalized = str(
            word.get("normalized_puinave") or ""
        ).strip()
        lexical_hash = str(
            word.get("lexical_hash") or ""
        ).strip()
        input_status = str(
            word.get("status") or ""
        ).strip().upper()
        metadata = detector_metadata(word)

        if input_status != "NEW":
            return SemanticValidationResult(
                source_index=source_index,
                puinave=puinave,
                normalized_puinave=normalized,
                lexical_hash=lexical_hash,
                input_status=input_status,
                validation_status="SKIPPED",
                semantic_status="NOT_APPLICABLE",
                semantic_query=puinave,
                errors=errors,
                no_invention=True,
                downstream_allowed=False,
                metadata=metadata,
            )

        if errors:
            return SemanticValidationResult(
                source_index=source_index,
                puinave=puinave,
                normalized_puinave=normalized,
                lexical_hash=lexical_hash,
                input_status=input_status,
                validation_status="INVALID",
                semantic_status="NOT_EXECUTED",
                semantic_query=puinave,
                errors=errors,
                no_invention=True,
                downstream_allowed=False,
                metadata=metadata,
            )

        response = self.semantic_service.search(
            puinave,
            limit=self.limit,
            validated_relations_only=True,
        )

        semantic_payload = self.semantic_service.to_dict(
            response
        )

        candidates = tuple(
            dict(item)
            for item in semantic_payload.get("results", [])
            if isinstance(item, dict)
        )

        suggestions = tuple(
            str(item)
            for item in semantic_payload.get("suggestions", [])
            if str(item).strip()
        )

        no_invention = bool(
            semantic_payload.get("no_invention", True)
        )

        if candidates:
            semantic_status = "MATCHED"
            validation_status = "VALIDATED"
            downstream_allowed = True
        else:
            semantic_status = "REVIEW_REQUIRED"
            validation_status = "VALIDATED_NO_MATCH"
            downstream_allowed = False

        return SemanticValidationResult(
            source_index=source_index,
            puinave=puinave,
            normalized_puinave=normalized,
            lexical_hash=lexical_hash,
            input_status=input_status,
            validation_status=validation_status,
            semantic_status=semantic_status,
            semantic_query=puinave,
            errors=(),
            semantic_candidates=candidates,
            suggestions=suggestions,
            no_invention=no_invention,
            downstream_allowed=downstream_allowed,
            metadata=metadata,
        )

    def analyze_batch(
        self,
        batch: dict[str, Any],
    ) -> dict[str, Any]:
        words = batch.get("words")

        if not isinstance(words, list):
            raise ValueError(
                "SPT-023.1 batch debe contener words como lista."
            )

        results = tuple(
            self.analyze_word(item)
            for item in words
            if isinstance(item, dict)
        )

        matched = sum(
            item.semantic_status == "MATCHED"
            for item in results
        )
        review_required = sum(
            item.semantic_status == "REVIEW_REQUIRED"
            for item in results
        )
        invalid = sum(
            item.validation_status == "INVALID"
            for item in results
        )
        skipped = sum(
            item.validation_status == "SKIPPED"
            for item in results
        )

        return {
            "component": "SPT-023.2",
            "source_component": "SPT-023.1",
            "source": batch.get("source"),
            "source_batch_hash": batch.get("batch_hash"),
            "records_received": len(words),
            "records_processed": len(results),
            "semantic_matches": matched,
            "review_required": review_required,
            "invalid": invalid,
            "skipped": skipped,
            "no_invention": all(
                item.no_invention
                for item in results
            ),
            "next_component": "SPT-023.3",
            "results": [
                item.to_dict()
                for item in results
            ],
        }