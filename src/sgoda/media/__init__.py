"""Repositorio Multimedia Relacional de SGODA-PUINAVE."""

from .migration import (
    migrar_oda_a_rmr,
    publicar_evidencias_rmr,
)
from .models import (
    ConsultaRecursosRMR,
    RecursoMultimediaRMR,
    ResultadoMigracionRMR,
)
from .repository import (
    RepositorioMultimediaRMR,
    deterministic_resource_id,
)

__all__ = [
    "ConsultaRecursosRMR",
    "RecursoMultimediaRMR",
    "RepositorioMultimediaRMR",
    "ResultadoMigracionRMR",
    "deterministic_resource_id",
    "migrar_oda_a_rmr",
    "publicar_evidencias_rmr",
]