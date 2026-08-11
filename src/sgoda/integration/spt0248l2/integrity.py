from __future__ import annotations
import hashlib
import json
from typing import Iterable, Mapping


def _canonical(payload: Mapping) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def build_chain(records: Iterable[Mapping]) -> list:
    previous = ""
    chain = []

    for index, record in enumerate(records, 1):
        h = hashlib.sha256()
        h.update(previous.encode("ascii"))
        h.update(_canonical(record))
        digest = h.hexdigest()

        chain.append({
            "index": index,
            "previous_hash": previous,
            "sha256": digest,
        })

        previous = digest

    return chain
