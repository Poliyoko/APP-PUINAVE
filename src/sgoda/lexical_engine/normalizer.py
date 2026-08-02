"""Normalización Unicode y lingüística segura."""

from __future__ import annotations

import re
import unicodedata


_WHITESPACE = re.compile(r"\s+")
_NON_WORD = re.compile(r"[^\w\s-]", re.UNICODE)


def normalize_text(value: str) -> str:
    text = unicodedata.normalize("NFKC", str(value or ""))
    text = text.casefold().strip()
    text = _NON_WORD.sub(" ", text)
    text = _WHITESPACE.sub(" ", text)
    return text


def compact_text(value: str) -> str:
    return normalize_text(value).replace(" ", "")


def tokenize(value: str) -> tuple[str, ...]:
    normalized = normalize_text(value)
    return tuple(token for token in normalized.split(" ") if token)


def levenshtein_distance(left: str, right: str) -> int:
    a = normalize_text(left)
    b = normalize_text(right)

    if a == b:
        return 0
    if not a:
        return len(b)
    if not b:
        return len(a)

    previous = list(range(len(b) + 1))

    for index_a, char_a in enumerate(a, start=1):
        current = [index_a]

        for index_b, char_b in enumerate(b, start=1):
            insert_cost = current[index_b - 1] + 1
            delete_cost = previous[index_b] + 1
            replace_cost = previous[index_b - 1] + (
                0 if char_a == char_b else 1
            )

            current.append(
                min(insert_cost, delete_cost, replace_cost)
            )

        previous = current

    return previous[-1]


def similarity(left: str, right: str) -> float:
    a = normalize_text(left)
    b = normalize_text(right)

    if not a and not b:
        return 1.0
    if not a or not b:
        return 0.0

    distance = levenshtein_distance(a, b)
    maximum = max(len(a), len(b))
    return max(0.0, 1.0 - (distance / maximum))