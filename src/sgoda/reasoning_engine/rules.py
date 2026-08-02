from __future__ import annotations

from dataclasses import dataclass


@dataclass(frozen=True, slots=True)
class ReasoningRule:
    code: str
    relation_type: str
    transitive: bool
    explanation_template: str


DEFAULT_RULES = (
    ReasoningRule(
        "SPT007D-R001",
        "is_a",
        True,
        "{subject} pertenece indirectamente a {object}.",
    ),
    ReasoningRule(
        "SPT007D-R002",
        "part_of",
        True,
        "{subject} forma parte indirectamente de {object}.",
    ),
    ReasoningRule(
        "SPT007D-R003",
        "located_in",
        True,
        "{subject} está relacionado territorialmente con {object}.",
    ),
)


def rule_for_relation(relation_type: str) -> ReasoningRule | None:
    normalized = relation_type.strip().casefold()
    return next(
        (
            rule
            for rule in DEFAULT_RULES
            if rule.relation_type == normalized
        ),
        None,
    )