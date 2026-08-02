"""Ontología mínima institucional de SPT-007C."""

from __future__ import annotations


ALLOWED_NODE_TYPES = {
    "lexical_entry",
    "concept",
    "cultural_practice",
    "place",
    "person",
    "animal",
    "plant",
    "object",
    "story",
    "media",
    "oda",
    "category",
}


ALLOWED_RELATION_TYPES = {
    "is_a",
    "part_of",
    "related_to",
    "synonym_of",
    "variant_of",
    "family_of",
    "used_in",
    "located_in",
    "appears_in",
    "has_media",
    "has_oda",
    "teaches",
    "broader_than",
    "narrower_than",
    "cultural_relation",
}


TRANSITIVE_RELATIONS = {
    "is_a",
    "part_of",
    "broader_than",
    "narrower_than",
}


SYMMETRIC_RELATIONS = {
    "related_to",
    "synonym_of",
    "family_of",
    "cultural_relation",
}


def is_allowed_node_type(value: str) -> bool:
    return str(value).strip().casefold() in ALLOWED_NODE_TYPES


def is_allowed_relation_type(value: str) -> bool:
    return str(value).strip().casefold() in ALLOWED_RELATION_TYPES