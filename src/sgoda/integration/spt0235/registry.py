from __future__ import annotations

import hashlib
import json
import os
from dataclasses import dataclass
from pathlib import Path
from typing import Any


def _canonical(value: object) -> bytes:
    return json.dumps(
        value,
        ensure_ascii=False,
        sort_keys=True,
        separators=(",", ":"),
    ).encode("utf-8")


def _sha256(value: object) -> str:
    return hashlib.sha256(_canonical(value)).hexdigest().upper()


@dataclass(frozen=True)
class StoredObject:
    lexical_id: str
    object_type: str
    version: int
    object_sha256: str
    content: dict[str, Any]

    def to_dict(self) -> dict[str, Any]:
        return {
            "lexical_id": self.lexical_id,
            "object_type": self.object_type,
            "version": self.version,
            "object_sha256": self.object_sha256,
            "content": dict(self.content),
        }


class FldOdaRegistry:
    """Registro institucional local, versionado y atÃ³mico para FLD/ODA."""

    def __init__(self, path: str | Path) -> None:
        self.path = Path(path)

    def _empty(self) -> dict[str, Any]:
        return {
            "schema_version": "1.0.0",
            "component": "SPT-023.5",
            "registry_type": "FLD_ODA_MASTER",
            "entries": {},
        }

    def load(self) -> dict[str, Any]:
        if not self.path.exists():
            return self._empty()

        data = json.loads(self.path.read_text(encoding="utf-8"))
        if str(data.get("schema_version")) != "1.0.0":
            raise ValueError("Unsupported FLD/ODA registry schema_version.")
        if data.get("registry_type") != "FLD_ODA_MASTER":
            raise ValueError("Invalid FLD/ODA registry_type.")
        if not isinstance(data.get("entries"), dict):
            raise ValueError("Registry entries must be an object.")

        self.verify(data)
        return data

    @staticmethod
    def verify(data: dict[str, Any]) -> bool:
        entries = data.get("entries")
        if not isinstance(entries, dict):
            raise ValueError("Registry entries must be an object.")

        for lexical_id, record in entries.items():
            if str(record.get("lexical_id") or "") != lexical_id:
                raise ValueError("Registry lexical_id mismatch.")

            versions = record.get("versions")
            if not isinstance(versions, list) or not versions:
                raise ValueError("Registry record requires versions.")

            expected_version = 1
            for item in versions:
                if int(item.get("version", 0)) != expected_version:
                    raise ValueError("Registry versions must be contiguous.")

                fld = dict(item.get("fld") or {})
                oda = dict(item.get("oda") or {})
                if fld.get("object_type") != "FLD":
                    raise ValueError("Stored FLD object_type is invalid.")
                if oda.get("object_type") != "ODA":
                    raise ValueError("Stored ODA object_type is invalid.")

                fld_sha = str(fld.get("fld_sha256") or "")
                oda_sha = str(oda.get("oda_sha256") or "")
                if not fld_sha or not oda_sha:
                    raise ValueError("Stored FLD/ODA hashes are required.")

                body = {
                    "version": expected_version,
                    "fld_sha256": fld_sha,
                    "oda_sha256": oda_sha,
                    "source_multimedia_manifest_sha256": str(
                        item.get("source_multimedia_manifest_sha256") or ""
                    ),
                }
                if str(item.get("version_sha256") or "") != _sha256(body):
                    raise ValueError("Registry version SHA-256 mismatch.")

                expected_version += 1

            if int(record.get("latest_version", 0)) != len(versions):
                raise ValueError("Registry latest_version mismatch.")

        return True

    def save_entry(
        self,
        *,
        lexical_id: str,
        fld: dict[str, Any],
        oda: dict[str, Any],
    ) -> dict[str, Any]:
        lexical_id = str(lexical_id or "").strip()
        if not lexical_id:
            raise ValueError("lexical_id is required.")

        if fld.get("object_type") != "FLD":
            raise ValueError("FLD object is required.")
        if oda.get("object_type") != "ODA":
            raise ValueError("ODA object is required.")
        if str(fld.get("lexical_id") or "") != lexical_id:
            raise ValueError("FLD lexical_id mismatch.")
        if str(oda.get("lexical_id") or "") != lexical_id:
            raise ValueError("ODA lexical_id mismatch.")
        if str(oda.get("source_fld_sha256") or "") != str(fld.get("fld_sha256") or ""):
            raise ValueError("ODA must reference the stored FLD hash.")

        data = self.load()
        entries = dict(data["entries"])
        existing = dict(entries.get(lexical_id) or {})
        versions = list(existing.get("versions") or [])

        next_version = len(versions) + 1
        body = {
            "version": next_version,
            "fld_sha256": str(fld["fld_sha256"]),
            "oda_sha256": str(oda["oda_sha256"]),
            "source_multimedia_manifest_sha256": str(
                fld.get("multimedia_manifest_sha256") or ""
            ),
        }

        version_record = {
            "version": next_version,
            "fld": dict(fld),
            "oda": dict(oda),
            "source_multimedia_manifest_sha256": body[
                "source_multimedia_manifest_sha256"
            ],
            "version_sha256": _sha256(body),
        }
        versions.append(version_record)

        entries[lexical_id] = {
            "lexical_id": lexical_id,
            "latest_version": next_version,
            "versions": versions,
        }
        data["entries"] = entries

        self.path.parent.mkdir(parents=True, exist_ok=True)
        tmp = self.path.with_name(self.path.name + ".tmp")
        tmp.write_text(
            json.dumps(data, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
            newline="\n",
        )
        os.replace(tmp, self.path)

        self.verify(data)
        return dict(version_record)

    def get(self, lexical_id: str, version: int | None = None) -> dict[str, Any] | None:
        data = self.load()
        record = data["entries"].get(str(lexical_id))
        if record is None:
            return None

        versions = record["versions"]
        if version is None:
            return dict(versions[-1])

        version = int(version)
        for item in versions:
            if int(item["version"]) == version:
                return dict(item)
        return None
