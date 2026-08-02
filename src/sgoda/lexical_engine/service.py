"""Servicio de aplicación para SPT-007A."""

from __future__ import annotations

from .models import SearchQuery
from .multimedia import playback_manifest
from .repository import LexicalRepository
from .search import LexicalSearchEngine


class IntelligentLexicalService:
    def __init__(
        self,
        repository: LexicalRepository,
        fuzzy_threshold: float = 0.72,
    ) -> None:
        self.repository = repository
        self.engine = LexicalSearchEngine(
            repository,
            fuzzy_threshold=fuzzy_threshold,
        )

    def search(
        self,
        text: str,
        languages: tuple[str, ...] = (
            "pu",
            "es",
            "en-US",
            "it",
        ),
        limit: int = 20,
        include_unvalidated: bool = True,
        category: str | None = None,
        fuzzy: bool = True,
    ) -> dict:
        response = self.engine.search(
            SearchQuery(
                text=text,
                languages=languages,
                limit=limit,
                include_unvalidated=include_unvalidated,
                category=category,
                fuzzy=fuzzy,
            )
        )

        return {
            "query": response.query.text,
            "languages": list(response.query.languages),
            "total": response.total,
            "no_invention": response.no_invention,
            "results": [
                {
                    "entry_id": hit.entry.entry_id,
                    "score": hit.score,
                    "match_type": hit.match_type,
                    "matched_language": hit.matched_language,
                    "matched_text": hit.matched_text,
                    "puinave": hit.entry.puinave,
                    "spanish": hit.entry.spanish,
                    "english_us": hit.entry.english_us,
                    "italian": hit.entry.italian,
                    "category": hit.entry.category,
                    "validated": hit.entry.validated,
                    "cultural_status": hit.entry.cultural_status,
                    "playback": playback_manifest(hit.entry),
                }
                for hit in response.hits
            ],
        }