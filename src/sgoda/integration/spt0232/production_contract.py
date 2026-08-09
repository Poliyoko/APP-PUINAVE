"""SPT-023.2 - contrato productivo institucional."""

from __future__ import annotations

from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True, slots=True)
class ProductionRequest:
    source: str
    batch_hash: str
    words: tuple[dict[str, Any], ...]


def validate_production_request(
    payload: dict[str, Any],
) -> ProductionRequest:
    if not isinstance(payload, dict):
        raise TypeError(
            "SPT-023.2 production payload debe ser dict."
        )

    source = str(
        payload.get("source") or ""
    ).strip()

    batch_hash = str(
        payload.get("batch_hash") or ""
    ).strip()

    words = payload.get("words")

    if not source:
        raise ValueError(
            "SPT-023.2 source es obligatorio."
        )

    if not batch_hash:
        raise ValueError(
            "SPT-023.2 batch_hash es obligatorio."
        )

    if not isinstance(words, list):
        raise ValueError(
            "SPT-023.2 words debe ser una lista."
        )

    normalized_words: list[dict[str, Any]] = []

    for index, item in enumerate(words):

        if not isinstance(item, dict):
            raise ValueError(
                "SPT-023.2 word "
                f"{index} debe ser dict."
            )

        normalized_words.append(
            dict(item)
        )

    return ProductionRequest(
        source=source,
        batch_hash=batch_hash,
        words=tuple(normalized_words),
    )


def to_detector_batch(
    request: ProductionRequest,
) -> dict[str, Any]:
    return {
        "source": request.source,
        "batch_hash": request.batch_hash,
        "words": [
            dict(item)
            for item in request.words
        ],
    }