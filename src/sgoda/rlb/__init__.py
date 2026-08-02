"""Repositorio Léxico Base del ecosistema SGODA-PUINAVE.

Este módulo conserva la API pública histórica del RLB. El módulo CLI
no se importa aquí para evitar cargas anticipadas al ejecutar
``python -m sgoda.rlb.cli``.
"""

from .events import (
    EventoRepositorioImportado,
    publicar_evento_jsonl,
)
from .excel_reader import (
    ErrorFilaRLB,
    LectorExcelRLB,
    ResultadoLecturaRLB,
)
from .exporter import exportar_resultado
from .models import (
    CampoDesconocido,
    OrigenRLB,
    RegistroLexico,
)
from .pipeline import (
    ResultadoPipelineRLB,
    ejecutar_pipeline,
)
from .profile_models import (
    PerfilHojaRLB,
    PerfilRepositorioRLB,
)
from .schema import (
    CampoEsquema,
    EsquemaRLB,
    ResultadoMapeo,
)
from .schema_loader import (
    ErrorEsquemaRLB,
    cargar_esquema,
)

__all__ = [
    "CampoDesconocido",
    "CampoEsquema",
    "ErrorEsquemaRLB",
    "ErrorFilaRLB",
    "EsquemaRLB",
    "EventoRepositorioImportado",
    "LectorExcelRLB",
    "OrigenRLB",
    "PerfilHojaRLB",
    "PerfilRepositorioRLB",
    "RegistroLexico",
    "ResultadoLecturaRLB",
    "ResultadoMapeo",
    "ResultadoPipelineRLB",
    "cargar_esquema",
    "ejecutar_pipeline",
    "exportar_resultado",
    "publicar_evento_jsonl",
]