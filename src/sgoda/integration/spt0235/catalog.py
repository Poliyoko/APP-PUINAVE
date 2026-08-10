from __future__ import annotations

import json
import os
from pathlib import Path
from typing import Any


class PublishedObjectCatalog:
    """CatÃ¡logo institucional local de objetos FLD/ODA publicados."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return {
                "schema_version": "1.0.0",
                "component": "SPT-023.5",
                "catalog_type": "PUBLISHED_FLD_ODA",
                "entries": {},
            }

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported published catalog schema_version.")
        if data.get("catalog_type") != "PUBLISHED_FLD_ODA":
            raise ValueError("Invalid published catalog type.")
        if not isinstance(data.get("entries"), dict):
            raise ValueError("Published catalog entries must be an object.")
        return data

    def publish(self, manifest: dict[str, Any]) -> dict[str, Any]:
        if manifest.get("publication_status") != "READY_FOR_INSTITUTIONAL_REGISTRY":
            raise ValueError("Manifest is not ready for institutional registry.")

        lexical_id = str(manifest.get("lexical_id") or "").strip()
        version = int(manifest.get("version", 0))
        manifest_sha = str(manifest.get("publication_manifest_sha256") or "").strip()

        if not lexical_id or version < 1 or not manifest_sha:
            raise ValueError("Publication manifest identity is incomplete.")

        data = self.load()
        entries = dict(data["entries"])
        existing = list(entries.get(lexical_id) or [])

        duplicate = [
            item
            for item in existing
            if int(item.get("version", 0)) == version
        ]
        if duplicate:
            if str(duplicate[0].get("publication_manifest_sha256")) == manifest_sha:
                result = dict(duplicate[0])
                result["reused"] = True
                return result
            raise ValueError("Conflicting publication already exists for lexical version.")

        record = dict(manifest)
        record["reused"] = False
        existing.append(record)
        existing.sort(key=lambda item: int(item["version"]))
        entries[lexical_id] = existing
        data["entries"] = entries

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)
        return record

    def get(self, lexical_id: str, version: int | None = None) -> dict[str, Any] | None:
        entries = self.load()["entries"].get(str(lexical_id))
        if not entries:
            return None

        if version is None:
            return dict(entries[-1])

        for item in entries:
            if int(item["version"]) == int(version):
                return dict(item)
        return None
