"""Ranking híbrido léxico-semántico."""

from __future__ import annotations


RELATION_WEIGHTS = {
    "synonym": 1.0,
    "variant": 0.95,
    "family": 0.85,
    "related": 0.70,
    "cultural": 0.75,
    "broader": 0.60,
    "narrower": 0.60,
    "antonym": 0.35,
}


def relation_weight(relation_type: str) -> float:
    return RELATION_WEIGHTS.get(relation_type, 0.0)


def hybrid_score(
    lexical_score: float,
    semantic_score: float,
    relation_score: float,
    validated: bool,
) -> float:
    score = (
        lexical_score * 0.55
        + semantic_score * 0.25
        + relation_score * 0.20
    )

    if validated:
        score += 2.0

    return round(score, 6)