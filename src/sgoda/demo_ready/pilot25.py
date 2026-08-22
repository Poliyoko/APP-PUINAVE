from __future__ import annotations

import json
from pathlib import Path


EXPECTED_IDS = tuple(
    f"PU-{number:06d}"
    for number in range(1, 26)
)


class Pilot25Repository:
    """Read-only binding for the certified SGODA REAL-25 dataset."""

    def __init__(
        self,
        records_json: str | Path,
        drive_root: str | Path,
    ) -> None:
        self.records_json = Path(records_json).resolve()
        self.drive_root = Path(drive_root)

        if not self.records_json.is_file():
            raise FileNotFoundError(
                f"REAL-25 records not found: {self.records_json}"
            )

        if not self.drive_root.is_dir():
            raise FileNotFoundError(
                f"Drive root unavailable: {self.drive_root}"
            )

        payload = json.loads(
            self.records_json.read_text(
                encoding="utf-8-sig"
            )
        )

        if not isinstance(payload, list):
            raise ValueError(
                "REAL-25 records.json must be a JSON array."
            )

        if len(payload) != 25:
            raise ValueError(
                f"REAL-25 expected 25 records; found {len(payload)}."
            )

        self._records = tuple(
            self._normalize(item)
            for item in payload
        )

        ids = tuple(
            record["lexical_id"]
            for record in self._records
        )

        if ids != EXPECTED_IDS:
            raise ValueError(
                "REAL-25 IDs are not PU-000001..PU-000025 in order."
            )

    @staticmethod
    def _normalize(item: dict) -> dict:
        return {
            "lexical_id": str(
                item.get("lexical_id", "")
            ).strip(),
            "position": item.get("position"),
            "batch_id": str(
                item.get("batch_id", "")
            ).strip(),
            "puinave": str(
                item.get("native_word", "")
            ).strip(),
            "pronunciation": str(
                item.get("native_pronunciation", "")
            ).strip(),
            "spanish": str(
                item.get("primary_translation", "")
            ).strip(),
            "audio_filename": str(
                item.get("native_audio_source", "")
            ).strip(),
            "wav_exists_certified": bool(
                item.get("wav_exists", False)
            ),
            "mp3_exists_certified": bool(
                item.get("mp3_exists", False)
            ),
        }

    def list(self) -> tuple[dict, ...]:
        return self._records

    def get(self, lexical_id: str) -> dict | None:
        target = lexical_id.strip().upper()

        for record in self._records:
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

    def public_record(self, record: dict) -> dict:
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
        lexical_complete = sum(
            1
            for item in self._records
            if item["puinave"] and item["spanish"]
        )

        audio_complete = sum(
            1
            for item in self._records
            if self.audio_path(item["lexical_id"]) is not None
        )

        return {
            "pilot": "PILOTO_25",
            "records": len(self._records),
            "expected_records": 25,
            "lexical_complete": lexical_complete,
            "audio_complete": audio_complete,
            "ready": (
                len(self._records) == 25
                and lexical_complete == 25
                and audio_complete == 25
            ),
        }