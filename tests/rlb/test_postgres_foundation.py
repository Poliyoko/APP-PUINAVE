from __future__ import annotations

import json

import pytest

from sgoda.rlb.models import CampoDesconocido, OrigenRLB, RegistroLexico
from sgoda.rlb.postgres import (
    DDL,
    INSERT_SQL,
    RLB_SCHEMA_VERSION,
    TABLE_NAME,
    registro_to_params,
    upsert_registro,
)


def test_postgres_foundation_contract() -> None:
    assert TABLE_NAME == "rlb_registro_lexico"
    assert RLB_SCHEMA_VERSION == "1.1.0"

    ddl = DDL.lower()

    assert "create table if not exists rlb_registro_lexico" in ddl
    assert "identificador text unique" in ddl
    assert "palabra_puinave text not null" in ddl
    assert "idx_rlb_registro_lexico_identificador" not in ddl
    assert "autorizacion_publicacion boolean" in ddl
    assert "origen jsonb" in ddl
    assert "extensiones jsonb" in ddl
    assert "campos_desconocidos jsonb" in ddl
    assert "rlb_schema_version text not null" in ddl


def test_insert_is_parameterized_and_idempotent() -> None:
    sql = INSERT_SQL.lower()

    assert "%s" in INSERT_SQL
    assert "on conflict (identificador) do update" in sql
    assert "updated_at = current_timestamp" in sql
    assert "returning pk" in sql


def test_registro_to_params_preserves_contract() -> None:
    registro = RegistroLexico(
        identificador="PU-000001",
        palabra_puinave="AMDA",
        traduccion_espanol="Huérfana",
        nivel_acceso="pendiente_clasificacion",
        autorizacion_publicacion=False,
        estado_validacion="pendiente",
        origen=OrigenRLB(
            archivo="diccionario.xlsx",
            hoja="Hoja1",
            fila=2,
            version_esquema="1.1.0",
        ),
        extensiones={"idiomas_auxiliares": ["es"]},
        campos_desconocidos=[
            CampoDesconocido(
                columna_original="CAMPO EXTRA",
                valor="valor",
            )
        ],
    )

    params = registro_to_params(registro)

    assert len(params) == 23
    assert params[0] == "PU-000001"
    assert params[1] == "AMDA"
    assert params[2] == "Huérfana"
    assert params[16] == "pendiente_clasificacion"
    assert params[17] is False
    assert params[18] == "pendiente"

    origen = json.loads(params[19])
    extensiones = json.loads(params[20])
    desconocidos = json.loads(params[21])

    assert origen["fila"] == 2
    assert extensiones["idiomas_auxiliares"] == ["es"]
    assert desconocidos[0]["columna_original"] == "CAMPO EXTRA"
    assert params[22] == "1.1.0"


def test_registro_to_params_rejects_blank_word() -> None:
    registro = RegistroLexico(
        identificador=None,
        palabra_puinave="   ",
    )

    with pytest.raises(ValueError):
        registro_to_params(registro)

class _FakeCursor:
    def __init__(self) -> None:
        self.sql = None
        self.params = None

    def __enter__(self):
        return self

    def __exit__(self, exc_type, exc, tb):
        return False

    def execute(self, sql, params) -> None:
        self.sql = sql
        self.params = params

    def fetchone(self):
        return (42,)


class _FakeConnection:
    def __init__(self) -> None:
        self.cursor_instance = _FakeCursor()

    def cursor(self):
        return self.cursor_instance


def test_upsert_registro_uses_stable_identifier() -> None:
    registro = RegistroLexico(
        identificador="PU-000001",
        palabra_puinave="AMDA",
    )
    connection = _FakeConnection()

    pk = upsert_registro(connection, registro)

    assert pk == 42
    assert connection.cursor_instance.sql == INSERT_SQL
    assert connection.cursor_instance.params[0] == "PU-000001"


@pytest.mark.parametrize(
    "identificador",
    [None, "", "   "],
)
def test_upsert_registro_rejects_missing_identifier(
    identificador,
) -> None:
    registro = RegistroLexico(
        identificador=identificador,
        palabra_puinave="AMDA",
    )
    connection = _FakeConnection()

    with pytest.raises(
        ValueError,
        match="identificador es obligatorio",
    ):
        upsert_registro(connection, registro)

    assert connection.cursor_instance.sql is None
