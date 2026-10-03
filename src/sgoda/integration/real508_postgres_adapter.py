"""Adaptador REAL-508 -> RegistroLexico para persistencia RLB PostgreSQL.

Este módulo no abre conexiones PostgreSQL y no ejecuta DDL/DML.
Reutiliza exclusivamente el contrato RLB existente.
"""

from __future__ import annotations

from pathlib import Path
from typing import Any, Iterable

from sgoda.lexical_engine.models import LexicalEntry
from sgoda.rlb.models import OrigenRLB, RegistroLexico
from sgoda.rlb.postgres import upsert_registro


REAL508_SOURCE_FILE = "Repositorio lexico base 508.xlsx"
REAL508_SOURCE_SHEET = "hoja1"
REAL508_SOURCE_SCHEMA = "REAL508_R27_CERTIFIED"


def _metadata(entry: LexicalEntry) -> dict[str, Any]:
    value = entry.metadata
    if isinstance(value, dict):
        return dict(value)
    return {}


def _puinave_audio_path(entry: LexicalEntry) -> str | None:
    """Obtiene el audio Puinave sin alterar ni transformar su ruta."""

    for resource in entry.multimedia:
        if (
            resource.resource_type == "audio"
            and resource.language == "pu"
        ):
            return str(resource.path)

    return None


def real508_entry_to_registro_lexico(
    entry: LexicalEntry,
) -> RegistroLexico:
    """Convierte una entrada REAL-508 al contrato canónico RLB."""

    entry_id = str(entry.entry_id)

    if not entry_id:
        raise ValueError("REAL-508 requiere entry_id.")

    # No aplicar strip() a palabra_puinave:
    # los espacios forman parte del texto certificado.
    if entry.puinave is None or entry.puinave == "":
        raise ValueError(
            f"REAL-508 {entry_id}: palabra_puinave vacía."
        )

    metadata = _metadata(entry)

    fila_excel = metadata.get("fila_excel")

    if fila_excel is None:
        raise ValueError(
            f"REAL-508 {entry_id}: falta metadata.fila_excel."
        )

    try:
        fila_excel = int(fila_excel)
    except (TypeError, ValueError) as exc:
        raise ValueError(
            f"REAL-508 {entry_id}: fila_excel inválida."
        ) from exc

    extensiones = {
        "escritura_puinave":
            metadata.get("escritura_puinave"),

        "lote_audio_puinave":
            metadata.get("lote_audio_puinave"),

        "fuente_lexica":
            metadata.get(
                "fuente_lexica",
                "EXCEL_CERTIFICADO",
            ),

        "grafia_puinave_autoritativa":
            metadata.get(
                "grafia_puinave_autoritativa",
                True,
            ),

        "preservar_texto_exacto":
            metadata.get(
                "preservar_texto_exacto",
                True,
            ),

        "normalizar_puinave":
            metadata.get(
                "normalizar_puinave",
                False,
            ),

        "corregir_automaticamente_puinave":
            metadata.get(
                "corregir_automaticamente_puinave",
                False,
            ),

        "reinterpretar_puinave":
            metadata.get(
                "reinterpretar_puinave",
                False,
            ),
    }

    return RegistroLexico(
        identificador=entry_id,
        palabra_puinave=entry.puinave,
        traduccion_espanol=entry.spanish or None,
        audio_puinave=_puinave_audio_path(entry),

        estado_validacion=(
            "validado"
            if entry.validated
            else "pendiente"
        ),

        origen=OrigenRLB(
            archivo=REAL508_SOURCE_FILE,
            hoja=REAL508_SOURCE_SHEET,
            fila=fila_excel,
            version_esquema=REAL508_SOURCE_SCHEMA,
        ),

        extensiones=extensiones,
    )


def iter_real508_registros(
    entries: Iterable[LexicalEntry],
) -> Iterable[RegistroLexico]:
    """Transforma incrementalmente LexicalEntry -> RegistroLexico."""

    for entry in entries:
        yield real508_entry_to_registro_lexico(entry)


def persist_real508_registros(
    connection: Any,
    entries: Iterable[LexicalEntry],
) -> int:
    """Persiste REAL-508 usando el UPSERT idempotente oficial del RLB.

    La transacción pertenece al llamador. Esta función no hace commit,
    rollback, conexión ni ensure_schema.
    """

    count = 0

    for entry in entries:
        registro = real508_entry_to_registro_lexico(entry)
        upsert_registro(connection, registro)
        count += 1

    return count
