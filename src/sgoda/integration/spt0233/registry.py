from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable


def _canonical_json(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _fingerprint(version: int, categories: Iterable[dict[str, Any]]) -> str:
    payload = {
        "version": int(version),
        "categories": list(categories),
    }
    return hashlib.sha256(_canonical_json(payload)).hexdigest().upper()


@dataclass(frozen=True)
class CatalogSnapshot:
    version: int
    categories: tuple[dict[str, Any], ...]
    sha256: str

    def to_dict(self) -> dict[str, Any]:
        return {
            "schema_version": "1.0.0",
            "version": self.version,
            "sha256": self.sha256,
            "categories": [dict(item) for item in self.categories],
        }


class CategoryRegistryStore:
    """Persistencia institucional del catÃ¡logo con validaciÃ³n jerÃ¡rquica."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    @staticmethod
    def validate(categories: Iterable[dict[str, Any]]) -> tuple[dict[str, Any], ...]:
        normalized: list[dict[str, Any]] = []
        ids: set[str] = set()
        names: set[str] = set()

        for raw in categories:
            if not isinstance(raw, dict):
                raise TypeError("Each category must be a dictionary.")

            category_id = str(raw.get("id") or raw.get("category_id") or "").strip()
            name = str(raw.get("name") or raw.get("nombre") or "").strip()

            if not category_id or not name:
                raise ValueError("Each category requires id and name.")
            if category_id in ids:
                raise ValueError(f"Duplicate category id: {category_id}")

            normalized_name = name.casefold()
            if normalized_name in names:
                raise ValueError(f"Duplicate category name: {name}")

            ids.add(category_id)
            names.add(normalized_name)

            item = dict(raw)
            item["id"] = category_id
            item["name"] = name
            item.setdefault("aliases", [])
            item.setdefault("keywords", [])
            item.setdefault("metadata", {})
            normalized.append(item)

        by_id = {item["id"]: item for item in normalized}

        for item in normalized:
            metadata = dict(item.get("metadata") or {})
            parent_id = str(metadata.get("parent_id") or "").strip() or None
            if parent_id and parent_id not in by_id:
                raise ValueError(
                    f"Unknown parent category {parent_id!r} for {item['id']!r}"
                )
            if parent_id == item["id"]:
                raise ValueError(f"Category {item['id']!r} cannot parent itself")
            metadata["parent_id"] = parent_id
            item["metadata"] = metadata

        parent = {
            item["id"]: item["metadata"].get("parent_id")
            for item in normalized
        }

        for category_id in by_id:
            seen: set[str] = set()
            current: str | None = category_id
            while current is not None:
                if current in seen:
                    raise ValueError(
                        f"Category hierarchy cycle detected at {current!r}"
                    )
                seen.add(current)
                current = parent.get(current)

        return tuple(normalized)

    def load(self) -> CatalogSnapshot:
        if not self.path.exists():
            return CatalogSnapshot(
                version=0,
                categories=(),
                sha256=_fingerprint(0, ()),
            )

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported category registry schema_version.")

        version = int(data.get("version", 0))
        categories = self.validate(data.get("categories", []))
        expected = _fingerprint(version, categories)
        recorded = str(data.get("sha256") or "").upper()

        if recorded != expected:
            raise ValueError("Category registry SHA-256 does not match content.")

        return CatalogSnapshot(
            version=version,
            categories=categories,
            sha256=expected,
        )

    def save(
        self,
        *,
        version: int,
        categories: Iterable[dict[str, Any]],
    ) -> CatalogSnapshot:
        if int(version) < 1:
            raise ValueError("Registry version must be >= 1.")

        validated = self.validate(categories)
        digest = _fingerprint(int(version), validated)
        snapshot = CatalogSnapshot(
            version=int(version),
            categories=validated,
            sha256=digest,
        )

        self.path.parent.mkdir(parents=True, exist_ok=True)
        temp = self.path.with_name(self.path.name + ".tmp")
        temp.write_text(
            json.dumps(
                snapshot.to_dict(),
                ensure_ascii=False,
                indent=2,
                sort_keys=True,
            )
            + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(temp, self.path)
        return snapshot
