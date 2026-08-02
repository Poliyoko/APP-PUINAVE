"""Almacenamiento local gobernado y actualización del RMR."""

from __future__ import annotations

import hashlib
import json
import sqlite3
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .contracts import ResultadoPersistencia


class AlmacenamientoLocalRMR:
    def __init__(
        self,
        *,
        root: str | Path,
        rmr_database: str | Path | None = None,
    ) -> None:
        self.root = Path(root)
        self.rmr_database = (
            Path(rmr_database)
            if rmr_database is not None
            else None
        )

    @staticmethod
    def _extension(media_type: str) -> str:
        mapping = {
            "image/png": ".png",
            "image/jpeg": ".jpg",
            "audio/wav": ".wav",
            "audio/mpeg": ".mp3",
            "video/mp4": ".mp4",
        }
        return mapping.get(media_type, ".bin")

    def store(
        self,
        *,
        resource_id: str,
        media_bytes: bytes,
        media_type: str,
        metadata: dict[str, Any],
    ) -> ResultadoPersistencia:
        if not media_bytes:
            raise ValueError("No se puede almacenar contenido vacío.")

        digest = hashlib.sha256(media_bytes).hexdigest()
        extension = self._extension(media_type)
        relative = Path(resource_id[:2]) / f"{resource_id}{extension}"
        target = self.root / relative
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(media_bytes)

        metadata_path = target.with_suffix(
            target.suffix + ".metadata.json"
        )
        metadata_payload = {
            "resource_id": resource_id,
            "sha256": digest,
            "size_bytes": len(media_bytes),
            "media_type": media_type,
            "stored_at_utc": datetime.now(
                timezone.utc
            ).isoformat(),
            "metadata": metadata,
        }
        metadata_path.write_text(
            json.dumps(
                metadata_payload,
                ensure_ascii=False,
                indent=2,
            ) + "\n",
            encoding="utf-8",
        )

        uri = target.as_posix()

        if self.rmr_database is not None:
            self._update_rmr(
                resource_id=resource_id,
                uri=uri,
                sha256=digest,
                size_bytes=len(media_bytes),
                media_type=media_type,
            )

        return ResultadoPersistencia(
            resource_id=resource_id,
            uri=uri,
            sha256=digest,
            size_bytes=len(media_bytes),
            media_type=media_type,
            metadata=metadata,
        )

    def _update_rmr(
        self,
        *,
        resource_id: str,
        uri: str,
        sha256: str,
        size_bytes: int,
        media_type: str,
    ) -> None:
        connection = sqlite3.connect(self.rmr_database)
        try:
            columns = {
                row[1]
                for row in connection.execute(
                    "PRAGMA table_info(media_resources)"
                ).fetchall()
            }

            updates: list[str] = []
            values: list[Any] = []

            candidates = {
                "uri": uri,
                "storage_uri": uri,
                "sha256": sha256,
                "size_bytes": size_bytes,
                "media_type": media_type,
                "status": "available",
            }

            for column, value in candidates.items():
                if column in columns:
                    updates.append(f"{column}=?")
                    values.append(value)

            if updates:
                values.append(resource_id)
                connection.execute(
                    f"""
                    UPDATE media_resources
                    SET {", ".join(updates)}
                    WHERE resource_id=?
                    """,
                    values,
                )
                connection.commit()
        finally:
            connection.close()