from __future__ import annotations

from pathlib import Path

import psycopg


EXPECTED_IDS = tuple(
    f"PU-{number:06d}"
    for number in range(1, 26)
)


class PostgresPilot25Repository:
    """Read-only REAL-25 repository backed by PostgreSQL."""

    def __init__(
        self,
        dsn: str,
        drive_root: str | Path,
    ) -> None:
        if not dsn or not dsn.strip():
            raise ValueError("PostgreSQL DSN is required.")

        self.dsn = dsn
        self.drive_root = Path(drive_root)

        if not self.drive_root.is_dir():
            raise FileNotFoundError(
                f"Drive root unavailable: {self.drive_root}"
            )

    def _query_records(self) -> tuple[dict, ...]:
        with psycopg.connect(
            self.dsn,
            connect_timeout=5,
        ) as connection:
            with connection.cursor() as cursor:
                cursor.execute(
                    """
                    SELECT
                        identificador,
                        palabra_puinave,
                        traduccion_espanol,
                        audio_puinave,
                        extensiones
                    FROM public.rlb_registro_lexico
                    WHERE identificador LIKE 'PU-%'
                    ORDER BY identificador
                    """
                )

                rows = cursor.fetchall()

        records = tuple(
            self._normalize(row)
            for row in rows
        )

        ids = tuple(
            record["lexical_id"]
            for record in records
        )

        if ids != EXPECTED_IDS:
            raise ValueError(
                "PostgreSQL REAL-25 IDs are not "
                "PU-000001..PU-000025 in order."
            )

        return records

    @staticmethod
    def _normalize(row: tuple) -> dict:
        (
            lexical_id,
            puinave,
            spanish,
            audio_filename,
            extensions,
        ) = row

        extensions = (
            extensions
            if isinstance(extensions, dict)
            else {}
        )

        real25 = extensions.get("real25", {})

        if not isinstance(real25, dict):
            real25 = {}

        return {
            "lexical_id": str(lexical_id or "").strip(),
            "position": real25.get("position"),
            "batch_id": str(
                real25.get("batch_id") or ""
            ).strip(),
            "puinave": str(puinave or "").strip(),
            "pronunciation": str(
                real25.get("native_pronunciation") or ""
            ).strip(),
            "spanish": str(spanish or "").strip(),
            "audio_filename": str(
                audio_filename or ""
            ).strip(),
            "wav_exists_certified": (
                real25.get("wav_exists") is True
            ),
            "mp3_exists_certified": (
                real25.get("mp3_exists") is True
            ),
        }

    def list(self) -> tuple[dict, ...]:
        return self._query_records()

    def get(
        self,
        lexical_id: str,
    ) -> dict | None:
        target = lexical_id.strip().upper()

        for record in self._query_records():
            if record["lexical_id"] == target:
                return record

        return None

    def audio_path(
        self,
        lexical_id: str,
    ) -> Path | None:
        record = self.get(lexical_id)

        if record is None:
            return None

        filename = (
            record["audio_filename"]
            or f"{record['lexical_id']}_pu.mp3"
        )

        candidates = (
            self.drive_root / "MP3" / filename,
            self.drive_root / filename,
        )

        for path in candidates:
            if path.is_file():
                return path

        hits = tuple(
            self.drive_root.rglob(filename)
        )

        return hits[0] if hits else None

    def public_record(
        self,
        record: dict,
    ) -> dict:
        lexical_id = record["lexical_id"]
        audio = self.audio_path(lexical_id)

        return {
            **record,
            "audio_available": audio is not None,
            "audio_url": (
                f"/api/demo/pilot25/{lexical_id}/audio"
                if audio is not None
                else None
            ),
        }

    def summary(self) -> dict:
        records = self._query_records()

        lexical_complete = sum(
            1
            for item in records
            if item["puinave"] and item["spanish"]
        )

        audio_complete = sum(
            1
            for item in records
            if self.audio_path(
                item["lexical_id"]
            ) is not None
        )

        return {
            "pilot": "PILOTO_25",
            "records": len(records),
            "expected_records": 25,
            "lexical_complete": lexical_complete,
            "audio_complete": audio_complete,
            "ready": (
                len(records) == 25
                and lexical_complete == 25
                and audio_complete == 25
            ),
            "data_source": "postgresql",
        }
