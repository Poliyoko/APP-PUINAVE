from __future__ import annotations

import json
from typing import Any


class PostgreSQLOperationalRepository:
    """Repositorio operacional de solo lectura respaldado por PostgreSQL."""

    def __init__(self, connection: Any) -> None:
        self._connection = connection

    @staticmethod
    def _decode_json(value: Any) -> Any:
        if value is None:
            return {}

        if isinstance(value, (dict, list)):
            return value

        if isinstance(value, str):
            try:
                return json.loads(value)
            except (TypeError, ValueError):
                return {}

        return {}

    @classmethod
    def _record_from_row(
        cls,
        row: tuple[Any, ...],
    ) -> dict[str, Any]:
        (
            identificador,
            palabra_puinave,
            traduccion_espanol,
            audio_puinave,
            origen,
            extensiones,
            estado_validacion,
        ) = row

        metadata = cls._decode_json(extensiones)
        origin = cls._decode_json(origen)

        if not isinstance(metadata, dict):
            metadata = {}

        if isinstance(origin, dict):
            metadata = dict(metadata)
            metadata.setdefault("origen", origin)

        return {
            "entry_id": str(identificador),
            "puinave": palabra_puinave or "",
            "spanish": traduccion_espanol or "",
            "english_us": "",
            "italian": "",
            "validated": bool(estado_validacion),
            "category": "",
            "metadata": metadata,
        }

    @classmethod
    def _media_from_row(
        cls,
        row: tuple[Any, ...],
    ) -> tuple[dict[str, Any], ...]:
        audio_puinave = row[0]

        if not audio_puinave:
            return ()

        return (
            {
                "resource_type": "audio",
                "language": "pu",
                "path": str(audio_puinave),
                "validated": True,
                "autoplay": False,
                "metadata": {},
            },
        )

    def get_entry(
        self,
        entry_id: str,
    ) -> dict[str, Any] | None:
        with self._connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    identificador,
                    palabra_puinave,
                    traduccion_espanol,
                    audio_puinave,
                    origen,
                    extensiones,
                    estado_validacion
                FROM public.rlb_registro_lexico
                WHERE identificador = %s
                """,
                (str(entry_id),),
            )
            row = cursor.fetchone()

        if row is None:
            return None

        return self._record_from_row(row)

    def all_entries(self) -> tuple[dict[str, Any], ...]:
        with self._connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT
                    identificador,
                    palabra_puinave,
                    traduccion_espanol,
                    audio_puinave,
                    origen,
                    extensiones,
                    estado_validacion
                FROM public.rlb_registro_lexico
                ORDER BY identificador
                """
            )
            rows = cursor.fetchall()

        return tuple(
            self._record_from_row(row)
            for row in rows
        )

    def media_for(
        self,
        entry_id: str,
    ) -> tuple[dict[str, Any], ...]:
        with self._connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT audio_puinave
                FROM public.rlb_registro_lexico
                WHERE identificador = %s
                """,
                (str(entry_id),),
            )
            row = cursor.fetchone()

        if row is None:
            return ()

        return self._media_from_row(row)

    def count(self) -> int:
        with self._connection.cursor() as cursor:
            cursor.execute(
                """
                SELECT COUNT(*)
                FROM public.rlb_registro_lexico
                """
            )
            row = cursor.fetchone()

        return int(row[0]) if row else 0
