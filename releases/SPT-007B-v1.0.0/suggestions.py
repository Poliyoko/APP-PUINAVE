"""Sugerencias deterministas sin generación inventada."""

from __future__ import annotations

from .normalizer import normalize_text, similarity
from .semantic_index import SemanticLexicalIndex


def suggest_terms(
    query: str,
    index: SemanticLexicalIndex,
    limit: int = 5,
    threshold: float = 0.45,
) -> tuple[str, ...]:
    normalized = normalize_text(query)
    candidates = []

    for term in index.vocabulary():
        if term == normalized:
            continue

        score = similarity(normalized, term)

        if score >= threshold:
            candidates.append((score, term))

    return tuple(
        term
        for _, term in sorted(
            candidates,
            key=lambda item: (-item[0], item[1]),
        )[: max(0, limit)]
    )