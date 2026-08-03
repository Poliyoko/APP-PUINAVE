"""Repositorio institucional del diccionario."""

from __future__ import annotations

from dataclasses import replace

from .models import LexicalEntry


class DictionaryRepository:
    def __init__(self) -> None:
        self._entries: dict[str, LexicalEntry] = {}

    def add(self, entry: LexicalEntry) -> LexicalEntry:
        if entry.entry_id in self._entries:
            raise ValueError(
                f"La entrada ya existe: {entry.entry_id}"
            )

        self._entries[entry.entry_id] = entry
        return entry

    def upsert(self, entry: LexicalEntry) -> LexicalEntry:
        self._entries[entry.entry_id] = entry
        return entry

    def get(self, entry_id: str) -> LexicalEntry | None:
        return self._entries.get(str(entry_id or "").strip())

    def all(self) -> tuple[LexicalEntry, ...]:
        return tuple(
            self._entries[key]
            for key in sorted(self._entries)
        )

    def update(
        self,
        entry_id: str,
        **changes,
    ) -> LexicalEntry:
        current = self.get(entry_id)

        if current is None:
            raise KeyError(entry_id)

        updated = replace(current, **changes)
        self._entries[entry_id] = updated
        return updated

    def search(self, query: str) -> tuple[LexicalEntry, ...]:
        needle = str(query or "").strip().casefold()

        if not needle:
            return self.all()

        results = []

        for entry in self.all():
            haystack = " ".join(
                [
                    entry.puinave,
                    entry.spanish,
                    entry.english_us,
                    entry.italian,
                    entry.grammatical_category,
                    entry.lexical_family,
                    " ".join(entry.dialectal_variants),
                    " ".join(entry.synonyms),
                    " ".join(entry.antonyms),
                ]
            ).casefold()

            if needle in haystack:
                results.append(entry)

        return tuple(results)