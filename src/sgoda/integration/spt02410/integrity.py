from __future__ import annotations
import hashlib
import hmac
import json
from typing import Iterable, Mapping


def canonical_bytes(payload: Mapping) -> bytes:
    return json.dumps(
        payload,
        sort_keys=True,
        separators=(",", ":"),
        ensure_ascii=False,
    ).encode("utf-8")


def sha256_digest(payload: Mapping) -> str:
    return hashlib.sha256(canonical_bytes(payload)).hexdigest()


def hmac_sha256(payload: Mapping, key: bytes) -> str:
    return hmac.new(key, canonical_bytes(payload), hashlib.sha256).hexdigest()


def verify_hmac_sha256(payload: Mapping, key: bytes, expected: str) -> bool:
    return hmac.compare_digest(hmac_sha256(payload, key), expected)


def build_hash_chain(records: Iterable[Mapping]) -> list:
    previous = ""
    chain = []

    for index, record in enumerate(records, 1):
        digest = hashlib.sha256(
            previous.encode("ascii") + canonical_bytes(record)
        ).hexdigest()

        chain.append({
            "index": index,
            "previous_hash": previous,
            "sha256": digest,
        })
        previous = digest

    return chain
