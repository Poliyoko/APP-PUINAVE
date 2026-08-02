"""Servicio semántico de SPT-007B."""

from __future__ import annotations

from .models import SearchQuery
from .normalizer import normalize_text, similarity
from .relations import SemanticRelationRepository
from .search import LexicalSearchEngine
from .semantic_index import SemanticLexicalIndex
from .semantic_models import SemanticHit, SemanticSearchResponse
from .semantic_ranking import hybrid_score, relation_weight
from .suggestions import suggest_terms


class SemanticLexicalService:
    def __init__(
        self,
        lexical_engine: LexicalSearchEngine,
        index: SemanticLexicalIndex,
        relations: SemanticRelationRepository,
    ) -> None:
        self.lexical_engine = lexical_engine
        self.index = index
        self.relations = relations

    def search(
        self,
        query: str,
        limit: int = 20,
        validated_relations_only: bool = True,
    ) -> SemanticSearchResponse:
        normalized = normalize_text(query)

        lexical = self.lexical_engine.search(
            SearchQuery(
                text=query,
                limit=max(limit, 50),
                fuzzy=True,
            )
        )

        by_id = {
            hit.entry.entry_id: hit
            for hit in lexical.hits
        }

        candidate_ids: set[str] = set(by_id)
        direct_ids = set(self.index.candidates((normalized,)))
        candidate_ids.update(direct_ids)

        relation_map: dict[str, list] = {}

        for source_id in tuple(sorted(candidate_ids)):
            for relation in self.relations.outgoing(
                source_id,
                validated_only=validated_relations_only,
            ):
                candidate_ids.add(relation.target_id)
                relation_map.setdefault(
                    relation.target_id,
                    [],
                ).append(relation)

        hits = []

        for entry_id in sorted(candidate_ids):
            entry = self.index.get(entry_id)

            if entry is None:
                continue

            lexical_hit = by_id.get(entry_id)
            lexical_score = (
                lexical_hit.score
                if lexical_hit is not None
                else 0.0
            )

            text_scores = [
                similarity(normalized, text)
                for text in entry.text_by_language().values()
                if text
            ]
            semantic_score = (
                max(text_scores, default=0.0) * 100.0
            )

            related = relation_map.get(entry_id, [])
            relation_score = (
                max(
                    (
                        relation_weight(item.relation_type)
                        * item.weight
                        * 100.0
                    )
                    for item in related
                )
                if related
                else 0.0
            )

            final = hybrid_score(
                lexical_score=lexical_score,
                semantic_score=semantic_score,
                relation_score=relation_score,
                validated=entry.validated,
            )

            if final <= 0.0:
                continue

            matched_terms = tuple(
                sorted(
                    {
                        lexical_hit.matched_text
                        if lexical_hit is not None
                        else "",
                        *(
                            text
                            for text in entry.text_by_language().values()
                            if normalize_text(text) == normalized
                        ),
                    }
                    - {""}
                )
            )

            relation_types = tuple(
                sorted({item.relation_type for item in related})
            )

            explanation = []

            if lexical_hit is not None:
                explanation.append(
                    f"coincidencia:{lexical_hit.match_type}"
                )

            if relation_types:
                explanation.append(
                    "relaciones:" + ",".join(relation_types)
                )

            hits.append(
                SemanticHit(
                    entry_id=entry_id,
                    lexical_score=round(lexical_score, 6),
                    semantic_score=round(semantic_score, 6),
                    relation_score=round(relation_score, 6),
                    final_score=final,
                    matched_terms=matched_terms,
                    relation_types=relation_types,
                    explanation=tuple(explanation),
                )
            )

        ordered = tuple(
            sorted(
                hits,
                key=lambda item: (
                    -item.final_score,
                    item.entry_id,
                ),
            )[: max(1, limit)]
        )

        suggestions = suggest_terms(
            query,
            self.index,
            limit=5,
        )

        return SemanticSearchResponse(
            query=query,
            normalized_query=normalized,
            total=len(ordered),
            hits=ordered,
            suggestions=suggestions,
            no_invention=True,
        )

    def to_dict(
        self,
        response: SemanticSearchResponse,
    ) -> dict:
        results = []

        for hit in response.hits:
            entry = self.index.get(hit.entry_id)

            if entry is None:
                continue

            results.append(
                {
                    "entry_id": hit.entry_id,
                    "final_score": hit.final_score,
                    "lexical_score": hit.lexical_score,
                    "semantic_score": hit.semantic_score,
                    "relation_score": hit.relation_score,
                    "matched_terms": list(hit.matched_terms),
                    "relation_types": list(hit.relation_types),
                    "explanation": list(hit.explanation),
                    "puinave": entry.puinave,
                    "spanish": entry.spanish,
                    "english_us": entry.english_us,
                    "italian": entry.italian,
                    "category": entry.category,
                    "validated": entry.validated,
                    "cultural_status": entry.cultural_status,
                }
            )

        return {
            "query": response.query,
            "normalized_query": response.normalized_query,
            "total": response.total,
            "suggestions": list(response.suggestions),
            "no_invention": response.no_invention,
            "results": results,
        }