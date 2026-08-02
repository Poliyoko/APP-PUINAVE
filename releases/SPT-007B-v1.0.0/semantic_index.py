"""Índice invertido multilingüe local."""

from __future__ import annotations

from collections import defaultdict

from .models import LexicalEntry
from .normalizer import normalize_text, tokenize


class SemanticLexicalIndex:
    def __init__(self) -> None:
        self._entries: dict[str, LexicalEntry] = {}
        self._token_to_ids: dict[str, set[str]] = defaultdict(set)
        self._term_to_ids: dict[str, set[str]] = defaultdict(set)
        self._category_to_ids: dict[str, set[str]] = defaultdict(set)
        self._variants: dict[str, set[str]] = defaultdict(set)

    def add_entry(
        self,
        entry: LexicalEntry,
        variants: tuple[str, ...] = (),
    ) -> None:
        self._entries[entry.entry_id] = entry

        for text in entry.text_by_language().values():
            normalized = normalize_text(text)

            if not normalized:
                continue

            self._term_to_ids[normalized].add(entry.entry_id)

            for token in tokenize(normalized):
                self._token_to_ids[token].add(entry.entry_id)

        category = normalize_text(entry.category)

        if category:
            self._category_to_ids[category].add(entry.entry_id)

        for variant in variants:
            normalized_variant = normalize_text(variant)

            if normalized_variant:
                self._variants[normalized_variant].add(entry.entry_id)

    def get(self, entry_id: str) -> LexicalEntry | None:
        return self._entries.get(entry_id)

    def entry_ids(self) -> tuple[str, ...]:
        return tuple(sorted(self._entries))

    def exact(self, term: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._term_to_ids.get(normalize_text(term), set()))
        )

    def token(self, token: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._token_to_ids.get(normalize_text(token), set()))
        )

    def variant(self, variant: str) -> tuple[str, ...]:
        return tuple(
            sorted(self._variants.get(normalize_text(variant), set()))
        )

    def candidates(self, terms: tuple[str, ...]) -> tuple[str, ...]:
        found: set[str] = set()

        for term in terms:
            normalized = normalize_text(term)
            found.update(self._term_to_ids.get(normalized, set()))
            found.update(self._token_to_ids.get(normalized, set()))
            found.update(self._variants.get(normalized, set()))

        return tuple(sorted(found))

    def vocabulary(self) -> tuple[str, ...]:
        return tuple(
            sorted(
                set(self._term_to_ids)
                | set(self._token_to_ids)
                | set(self._variants)
            )
        )