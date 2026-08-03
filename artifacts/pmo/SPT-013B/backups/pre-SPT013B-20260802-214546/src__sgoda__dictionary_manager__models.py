"""Modelos institucionales de SPT-013B."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(frozen=True, slots=True)
class LexicalExample:
    language: str
    text: str
    translation: str | None = None


@dataclass(frozen=True, slots=True)
class LexicalEntry:
    entry_id: str
    puinave: str
    spanish: str
    english_us: str = ""
    italian: str = ""
    grammatical_category: str = ""
    lexical_family: str = ""
    dialectal_variants: tuple[str, ...] = ()
    synonyms: tuple[str, ...] = ()
    antonyms: tuple[str, ...] = ()
    examples: tuple[LexicalExample, ...] = ()
    validated: bool = False
    cultural_validation_required: bool = True
    metadata: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DictionaryCommand:
    operation: str
    payload: dict[str, Any] = field(default_factory=dict)


@dataclass(frozen=True, slots=True)
class DictionaryResult:
    operation: str
    status: str
    data: dict[str, Any]
    warnings: tuple[str, ...] = ()
    no_invention: bool = True