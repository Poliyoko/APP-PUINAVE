"""Expansión determinista de consultas."""

from __future__ import annotations

from .normalizer import normalize_text, tokenize
from .relations import SemanticRelationRepository
from .semantic_index import SemanticLexicalIndex
from .semantic_models import QueryExpansion


def expand_query(
    query: str,
    index: SemanticLexicalIndex,
    relations: SemanticRelationRepository,
    explicit_variants: tuple[str, ...] = (),
) -> QueryExpansion:
    normalized = normalize_text(query)
    terms = tokenize(normalized)

    direct_ids: set[str] = set()

    for term in (normalized, *terms, *explicit_variants):
        direct_ids.update(index.exact(term))
        direct_ids.update(index.token(term))
        direct_ids.update(index.variant(term))

    related = relations.related_ids(
        tuple(sorted(direct_ids)),
        validated_only=True,
    )

    variants = tuple(
        sorted(
            {
                normalize_text(item)
                for item in explicit_variants
                if normalize_text(item)
            }
        )
    )

    return QueryExpansion(
        original=query,
        normalized=normalized,
        terms=terms,
        variants=variants,
        related_entry_ids=related,
    )