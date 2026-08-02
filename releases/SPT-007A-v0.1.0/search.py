"""Búsqueda exacta, parcial y tolerante."""

from __future__ import annotations

from .models import SearchHit, SearchQuery, SearchResponse
from .normalizer import normalize_text, similarity, tokenize
from .ranking import calculate_score, sort_hits
from .repository import LexicalRepository


class LexicalSearchEngine:
    def __init__(
        self,
        repository: LexicalRepository,
        fuzzy_threshold: float = 0.72,
    ) -> None:
        self.repository = repository
        self.fuzzy_threshold = fuzzy_threshold

    def search(self, query: SearchQuery) -> SearchResponse:
        normalized_query = normalize_text(query.text)

        if not normalized_query:
            return SearchResponse(
                query=query,
                total=0,
                hits=(),
            )

        hits: list[SearchHit] = []

        for entry in self.repository.all():
            if (
                not query.include_unvalidated
                and not entry.validated
            ):
                continue

            if query.category and (
                normalize_text(entry.category)
                != normalize_text(query.category)
            ):
                continue

            best: SearchHit | None = None

            for language, original_text in entry.text_by_language().items():
                if language not in query.languages:
                    continue

                if not original_text:
                    continue

                normalized_text = normalize_text(original_text)
                match_type = ""
                similarity_score = 0.0

                if normalized_text == normalized_query:
                    match_type = "exact"
                    similarity_score = 1.0
                elif normalized_text.startswith(normalized_query):
                    match_type = "prefix"
                    similarity_score = (
                        len(normalized_query)
                        / max(len(normalized_text), 1)
                    )
                elif normalized_query in tokenize(normalized_text):
                    match_type = "token"
                    similarity_score = 0.9
                elif normalized_query in normalized_text:
                    match_type = "contains"
                    similarity_score = (
                        len(normalized_query)
                        / max(len(normalized_text), 1)
                    )
                elif query.fuzzy:
                    similarity_score = similarity(
                        normalized_query,
                        normalized_text,
                    )

                    if similarity_score >= self.fuzzy_threshold:
                        match_type = "fuzzy"

                if not match_type:
                    continue

                score = calculate_score(
                    match_type=match_type,
                    language=language,
                    similarity_score=similarity_score,
                    validated=entry.validated,
                    multimedia_count=len(entry.multimedia),
                )

                candidate = SearchHit(
                    entry=entry,
                    score=score,
                    match_type=match_type,
                    matched_language=language,
                    matched_text=original_text,
                    normalized_query=normalized_query,
                    normalized_text=normalized_text,
                )

                if best is None or candidate.score > best.score:
                    best = candidate

            if best is not None:
                hits.append(best)

        ordered = sort_hits(hits)
        limited = ordered[: max(1, query.limit)]

        return SearchResponse(
            query=query,
            total=len(ordered),
            hits=limited,
        )