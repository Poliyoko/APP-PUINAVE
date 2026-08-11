from __future__ import annotations
import hashlib
import json
from typing import Iterable, Mapping


def canonical_bytes(payload: Mapping) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def hash_event(payload: Mapping, previous_hash: str = "") -> str:
    h = hashlib.sha256()
    h.update(previous_hash.encode("ascii"))
    h.update(canonical_bytes(payload))
    return h.hexdigest()


def build_hash_chain(events: Iterable[Mapping]) -> list:
    chain = []
    previous = ""
    for index, event in enumerate(events, 1):
        digest = hash_event(event, previous)
        chain.append({
            "index": index,
            "previous_hash": previous,
            "sha256": digest,
        })
        previous = digest
    return chain
