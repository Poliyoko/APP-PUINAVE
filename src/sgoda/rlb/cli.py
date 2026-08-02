"""CLI institucional del pipeline RLB."""

from __future__ import annotations

import argparse
from pathlib import Path

from .pipeline import ejecutar_pipeline


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Procesa el Repositorio Léxico Base y genera "
            "artefactos institucionales."
        )
    )
    parser.add_argument("--excel", required=True)
    parser.add_argument(
        "--schema",
        default="config/rlb/schema-v1.json",
    )
    parser.add_argument(
        "--output",
        default="artifacts/rlb/SPT-001B-P06",
    )
    parser.add_argument(
        "--events",
        default=(
            "artifacts/pmo/SPT-001B-P06/"
            "repository-events.jsonl"
        ),
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    result = ejecutar_pipeline(
        excel=Path(args.excel),
        esquema=Path(args.schema),
        salida=Path(args.output),
        historial_eventos=Path(args.events),
    )

    profile = result.lectura.perfil

    if profile is None:
        print("No se generó perfil institucional.")
        return 1

    print("SPT-001B-P06 ejecutado correctamente.")
    print(f"Archivo: {profile.archivo}")
    print(f"Hojas: {profile.total_hojas}")
    print(f"Registros: {profile.total_registros}")
    print(f"Válidos: {profile.total_registros_validos}")
    print(
        "Con errores: "
        f"{profile.total_registros_con_errores}"
    )
    print(f"Evento: {result.evento.event_type}")
    print(f"Resumen: {result.resumen_ejecucion}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())