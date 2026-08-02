"""Eventos institucionales del Repositorio Léxico Base."""

from __future__ import annotations

import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path
from uuid import uuid4


@dataclass(frozen=True, slots=True)
class EventoRepositorioImportado:
    """Evento emitido al finalizar una importación del RLB."""

    event_id: str
    event_type: str
    occurred_at_utc: str
    source: str
    sprint: str
    archivo: str
    version_esquema: str
    total_hojas: int
    total_registros: int
    registros_validos: int
    registros_con_errores: int
    artefactos_generados: tuple[str, ...]

    @classmethod
    def crear(
        cls,
        *,
        archivo: str,
        version_esquema: str,
        total_hojas: int,
        total_registros: int,
        registros_validos: int,
        registros_con_errores: int,
        artefactos_generados: tuple[str, ...],
    ) -> "EventoRepositorioImportado":
        return cls(
            event_id=str(uuid4()),
            event_type="RepositoryImported",
            occurred_at_utc=datetime.now(
                timezone.utc
            ).isoformat(),
            source="sgoda.rlb",
            sprint="SPT-001B-P06",
            archivo=archivo,
            version_esquema=version_esquema,
            total_hojas=total_hojas,
            total_registros=total_registros,
            registros_validos=registros_validos,
            registros_con_errores=registros_con_errores,
            artefactos_generados=artefactos_generados,
        )


def publicar_evento_jsonl(
    evento: EventoRepositorioImportado,
    ruta: str | Path,
) -> Path:
    """Publica el evento como una línea JSON UTF-8."""

    destino = Path(ruta)
    destino.parent.mkdir(parents=True, exist_ok=True)

    with destino.open(
        "a",
        encoding="utf-8",
        newline="\n",
    ) as archivo:
        archivo.write(
            json.dumps(
                asdict(evento),
                ensure_ascii=False,
            )
            + "\n"
        )

    if not destino.is_file() or destino.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo publicar el evento: {destino}"
        )

    return destino