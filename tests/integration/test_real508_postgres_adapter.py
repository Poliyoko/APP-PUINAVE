from __future__ import annotations

from pathlib import Path

import pytest

from sgoda.integration.real508_postgres_adapter import (
    REAL508_SOURCE_FILE,
    REAL508_SOURCE_SCHEMA,
    REAL508_SOURCE_SHEET,
    iter_real508_registros,
    persist_real508_registros,
    real508_entry_to_registro_lexico,
)
from sgoda.lexical_engine.models import (
    LexicalEntry,
    MultimediaResource,
)
from sgoda.rlb.models import RegistroLexico
from sgoda.rlb.postgres import registro_to_params


def _entry(
    *,
    entry_id: str = "000001",
    puinave: str = "A",
    spanish: str = "Mí",
    escritura: str = "(a)",
    lote: str = "1",
    fila: int = 2,
) -> LexicalEntry:
    return LexicalEntry(
        entry_id=entry_id,
        puinave=puinave,
        spanish=spanish,
        validated=True,
        multimedia=(
            MultimediaResource(
                resource_type="audio",
                language="pu",
                path=Path(
                    "Audacity/audio_individual/"
                    f"{entry_id}.mp3"
                ),
                validated=True,
            ),
        ),
        metadata={
            "fila_excel": fila,
            "escritura_puinave": escritura,
            "lote_audio_puinave": lote,
            "fuente_lexica": "EXCEL_CERTIFICADO",
            "grafia_puinave_autoritativa": True,
            "preservar_texto_exacto": True,
            "normalizar_puinave": False,
            "corregir_automaticamente_puinave": False,
            "reinterpretar_puinave": False,
        },
    )


def test_real508_maps_to_registro_lexico() -> None:
    registro = real508_entry_to_registro_lexico(_entry())

    assert isinstance(registro, RegistroLexico)
    assert registro.identificador == "000001"
    assert registro.palabra_puinave == "A"
    assert registro.traduccion_espanol == "Mí"
    assert registro.audio_puinave.endswith("000001.mp3")
    assert registro.estado_validacion == "validado"


def test_real508_preserves_exact_puinave_text() -> None:
    registro = real508_entry_to_registro_lexico(
        _entry(
            entry_id="000002",
            puinave=" AYOT",
            spanish="Mi  perro",
            escritura="ayot",
            fila=3,
        )
    )

    assert registro.palabra_puinave == " AYOT"
    assert registro.traduccion_espanol == "Mi  perro"


def test_real508_preserves_exact_escritura_whitespace() -> None:
    escritura = " (ibìsokpöngìn) "

    registro = real508_entry_to_registro_lexico(
        _entry(
            entry_id="000508",
            puinave="IWINSOGPÖNJIN",
            spanish="Mezquinoso-a",
            escritura=escritura,
            lote="23",
            fila=509,
        )
    )

    assert registro.extensiones["escritura_puinave"] == escritura


def test_real508_origin_is_certified_excel() -> None:
    registro = real508_entry_to_registro_lexico(_entry())

    assert registro.origen is not None
    assert registro.origen.archivo == REAL508_SOURCE_FILE
    assert registro.origen.hoja == REAL508_SOURCE_SHEET
    assert registro.origen.fila == 2
    assert registro.origen.version_esquema == REAL508_SOURCE_SCHEMA


def test_real508_policy_metadata_is_preserved() -> None:
    registro = real508_entry_to_registro_lexico(_entry())

    assert registro.extensiones["fuente_lexica"] == "EXCEL_CERTIFICADO"
    assert registro.extensiones["grafia_puinave_autoritativa"] is True
    assert registro.extensiones["preservar_texto_exacto"] is True
    assert registro.extensiones["normalizar_puinave"] is False
    assert registro.extensiones["corregir_automaticamente_puinave"] is False
    assert registro.extensiones["reinterpretar_puinave"] is False


def test_registro_is_accepted_by_existing_rlb_contract() -> None:
    registro = real508_entry_to_registro_lexico(_entry())

    params = registro_to_params(registro)

    assert isinstance(params, tuple)
    assert params[0] == "000001"
    assert params[1] == "A"
    assert params[2] == "Mí"


def test_iter_real508_registros() -> None:
    registros = tuple(
        iter_real508_registros(
            (
                _entry(entry_id="000001", fila=2),
                _entry(entry_id="000002", fila=3),
            )
        )
    )

    assert len(registros) == 2
    assert registros[0].identificador == "000001"
    assert registros[1].identificador == "000002"


class _FakeCursor:
    def __init__(self) -> None:
        self.executions: list[tuple[str, tuple]] = []
        self._pk = 0

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, sql, params):
        self.executions.append((sql, params))
        self._pk += 1

    def fetchone(self):
        return (self._pk,)


class _FakeConnection:
    def __init__(self) -> None:
        self.cursor_instance = _FakeCursor()

    def cursor(self):
        return self.cursor_instance


def test_persist_uses_existing_idempotent_rlb_upsert() -> None:
    connection = _FakeConnection()

    count = persist_real508_registros(
        connection,
        (
            _entry(entry_id="000001", fila=2),
            _entry(entry_id="000002", fila=3),
        ),
    )

    assert count == 2
    assert len(connection.cursor_instance.executions) == 2

    for sql, _ in connection.cursor_instance.executions:
        assert "ON CONFLICT (identificador)" in sql


def test_adapter_does_not_commit_or_manage_transaction() -> None:
    class ConnectionWithoutCommit(_FakeConnection):
        pass

    connection = ConnectionWithoutCommit()

    assert persist_real508_registros(
        connection,
        (_entry(),),
    ) == 1


def test_missing_excel_row_is_rejected() -> None:
    entry = _entry()
    entry.metadata.pop("fila_excel")

    with pytest.raises(ValueError, match="fila_excel"):
        real508_entry_to_registro_lexico(entry)
