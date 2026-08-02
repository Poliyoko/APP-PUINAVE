"""Repositorio gobernado de relaciones semánticas."""

from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path
from typing import Any

from .semantic_models import SemanticRelation


ALLOWED_RELATIONS = {
    "synonym",
    "related",
    "family",
    "variant",
    "broader",
    "narrower",
    "cultural",
    "antonym",
}


class SemanticRelationRepository:
    def __init__(
        self,
        relations: list[SemanticRelation],
    ) -> None:
        self._relations = tuple(relations)
        self._outgoing: dict[str, list[SemanticRelation]] = defaultdict(list)

        for relation in self._relations:
            self._outgoing[relation.source_id].append(relation)

    @classmethod
    def from_records(
        cls,
        records: list[dict[str, Any]],
    ) -> "SemanticRelationRepository":
        relations = []

        for item in records:
            relation_type = str(
                item.get("relation_type")
                or item.get("type")
                or ""
            ).strip().casefold()

            if relation_type not in ALLOWED_RELATIONS:
                continue

            source_id = str(item.get("source_id") or "").strip()
            target_id = str(item.get("target_id") or "").strip()

            if not source_id or not target_id or source_id == target_id:
                continue

            relations.append(
                SemanticRelation(
                    source_id=source_id,
                    target_id=target_id,
                    relation_type=relation_type,
                    weight=max(
                        0.0,
                        min(1.0, float(item.get("weight", 1.0))),
                    ),
                    validated=bool(item.get("validated", False)),
                    cultural=bool(item.get("cultural", False)),
                    metadata={
                        key: value
                        for key, value in item.items()
                        if key
                        not in {
                            "source_id",
                            "target_id",
                            "relation_type",
                            "type",
                            "weight",
                            "validated",
                            "cultural",
                        }
                    },
                )
            )

        return cls(relations)

    @classmethod
    def from_json(
        cls,
        path: str | Path,
    ) -> "SemanticRelationRepository":
        payload = json.loads(
            Path(path).read_text(encoding="utf-8-sig")
        )

        if isinstance(payload, dict):
            records = payload.get("relations", [])
        else:
            records = payload

        if not isinstance(records, list):
            raise ValueError("relations debe ser una lista.")

        return cls.from_records(
            [item for item in records if isinstance(item, dict)]
        )

    def outgoing(
        self,
        source_id: str,
        validated_only: bool = False,
    ) -> tuple[SemanticRelation, ...]:
        relations = self._outgoing.get(source_id, [])

        if validated_only:
            relations = [
                item for item in relations if item.validated
            ]

        return tuple(
            sorted(
                relations,
                key=lambda item: (
                    item.relation_type,
                    item.target_id,
                ),
            )
        )

    def related_ids(
        self,
        source_ids: tuple[str, ...],
        validated_only: bool = False,
    ) -> tuple[str, ...]:
        result: set[str] = set()

        for source_id in source_ids:
            for relation in self.outgoing(
                source_id,
                validated_only=validated_only,
            ):
                result.add(relation.target_id)

        return tuple(sorted(result))