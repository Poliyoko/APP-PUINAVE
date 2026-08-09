"""SPT-023.2 - persistencia deterministica de resultados."""

from __future__ import annotations

import hashlib
import json
from pathlib import Path
from typing import Any


def canonical_json_bytes(
    payload: Any,
) -> bytes:
    """Serializa JSON de forma estable para hashing institucional."""
    text = json.dumps(
        payload,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
        allow_nan=False,
    )
    return text.encode("utf-8")


def sha256_payload(
    payload: Any,
) -> str:
    return hashlib.sha256(
        canonical_json_bytes(payload)
    ).hexdigest()


def write_json_atomic(
    path: str | Path,
    payload: Any,
) -> dict[str, Any]:
    """Escribe JSON UTF-8 mediante reemplazo atomico local."""
    destination = Path(path)
    destination.parent.mkdir(
        parents=True,
        exist_ok=True,
    )

    content = canonical_json_bytes(payload)
    temporary = destination.with_name(
        destination.name + ".tmp"
    )

    temporary.write_bytes(content)
    temporary.replace(destination)

    digest = hashlib.sha256(content).hexdigest()

    return {
        "path": destination.as_posix(),
        "sha256": digest,
        "bytes": len(content),
    }


def read_json_verified(
    path: str | Path,
    expected_sha256: str | None = None,
) -> Any:
    source = Path(path)
    content = source.read_bytes()

    digest = hashlib.sha256(content).hexdigest()

    if (
        expected_sha256 is not None
        and digest != expected_sha256
    ):
        raise ValueError(
            "SHA256 mismatch for persisted SPT-023.2 artifact"
        )

    return json.loads(
        content.decode("utf-8")
    )