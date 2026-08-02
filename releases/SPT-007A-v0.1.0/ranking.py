"""Ranking determinista del Motor Léxico Inteligente."""

from __future__ import annotations

from .models import SearchHit


MATCH_WEIGHTS = {
    "exact": 100.0,
    "prefix": 85.0,
    "token": 75.0,
    "contains": 65.0,
    "fuzzy": 50.0,
}


LANGUAGE_WEIGHTS = {
    "pu": 4.0,
    "es": 3.0,
    "en-US": 2.0,
    "it": 1.0,
}


def calculate_score(
    match_type: str,
    language: str,
    similarity_score: float,
    validated: bool,
    multimedia_count: int,
) -> float:
    score = MATCH_WEIGHTS.get(match_type, 0.0)
    score += LANGUAGE_WEIGHTS.get(language, 0.0)
    score += max(0.0, min(1.0, similarity_score)) * 10.0
    score += 2.0 if validated else 0.0
    score += min(multimedia_count, 5) * 0.25
    return round(score, 6)


def sort_hits(hits: list[SearchHit]) -> tuple[SearchHit, ...]:
    return tuple(
        sorted(
            hits,
            key=lambda hit: (
                -hit.score,
                hit.entry.entry_id,
                hit.matched_language,
                hit.matched_text.casefold(),
            ),
        )
    )