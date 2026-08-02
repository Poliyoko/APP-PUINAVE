"""Migración de slots ODA al Repositorio Multimedia Relacional."""

from __future__ import annotations

import argparse
import hashlib
import json
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import (
    RecursoMultimediaRMR,
    ResultadoMigracionRMR,
)
from .repository import (
    RepositorioMultimediaRMR,
    deterministic_resource_id,
)


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el repositorio ODA: {path}"
        )

    return json.loads(path.read_text(encoding="utf-8"))


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def _language_from_type(
    resource_type: str,
) -> str | None:
    mapping = {
        "audio_puinave": "pui",
        "audio_espanol": "es",
        "audio_ingles": "en",
    }
    return mapping.get(resource_type)


def _resources_from_oda(
    oda: dict[str, Any],
) -> list[RecursoMultimediaRMR]:
    oda_id = str(oda.get("oda_id") or "").strip()
    canonical_id = str(
        oda.get("canonical_id") or ""
    ).strip()

    if not oda_id or not canonical_id:
        raise ValueError(
            "El ODA no contiene oda_id/canonical_id."
        )

    slots = oda.get("recursos") or []

    if not isinstance(slots, list):
        raise ValueError(
            f"Los recursos de {oda_id} no son una lista."
        )

    result: list[RecursoMultimediaRMR] = []

    for slot in slots:
        if not isinstance(slot, dict):
            continue

        resource_type = str(
            slot.get("tipo") or "recurso_desconocido"
        ).strip()

        subtype = str(
            slot.get("subtipo") or "principal"
        ).strip()

        language = (
            slot.get("idioma")
            or _language_from_type(resource_type)
        )

        variant = slot.get("variante")
        version = str(
            slot.get("version") or "1.0.0"
        )

        resource_id = deterministic_resource_id(
            oda_id=oda_id,
            resource_type=resource_type,
            subtype=subtype,
            language=language,
            variant=variant,
            version=version,
        )

        result.append(
            RecursoMultimediaRMR(
                resource_id=resource_id,
                oda_id=oda_id,
                canonical_id=canonical_id,
                resource_type=resource_type,
                subtype=subtype,
                language=language,
                variant=variant,
                provider=slot.get("proveedor"),
                version=version,
                media_format=slot.get("formato"),
                uri=slot.get("uri"),
                checksum_sha256=slot.get(
                    "checksum_sha256"
                ),
                status=str(
                    slot.get("estado") or "pendiente"
                ),
                metadata=dict(
                    slot.get("metadatos") or {}
                ),
            )
        )

    return result


def migrar_oda_a_rmr(
    *,
    oda_repository_path: str | Path,
    database_path: str | Path,
) -> ResultadoMigracionRMR:
    """Migra slots existentes de forma idempotente."""

    source_path = Path(oda_repository_path)
    payload = _read_json(source_path)
    objects = payload.get(
        "objetos_digitales_aprendizaje"
    )

    if not isinstance(objects, list) or not objects:
        raise ValueError(
            "El repositorio ODA no contiene objetos."
        )

    repository = RepositorioMultimediaRMR(
        database_path
    )
    repository.initialize()

    resources: list[RecursoMultimediaRMR] = []
    errors: list[dict[str, Any]] = []

    for position, oda in enumerate(objects, start=1):
        if not isinstance(oda, dict):
            errors.append(
                {
                    "position": position,
                    "code": "oda_not_object",
                }
            )
            continue

        try:
            resources.extend(
                _resources_from_oda(oda)
            )
        except ValueError as error:
            errors.append(
                {
                    "position": position,
                    "code": "invalid_oda",
                    "message": str(error),
                }
            )

    before = repository.count()
    processed = repository.bulk_upsert(resources)
    after = repository.count()

    inserted = max(after - before, 0)
    updated = processed - inserted

    return ResultadoMigracionRMR(
        total_oda=len(objects),
        total_resources=len(resources),
        inserted=inserted,
        updated=updated,
        errors=errors,
    )


def publicar_evidencias_rmr(
    *,
    repository: RepositorioMultimediaRMR,
    migration: ResultadoMigracionRMR,
    oda_repository_path: str | Path,
    output_dir: str | Path,
) -> dict[str, Path]:
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(
        timezone.utc
    ).isoformat()

    stats = repository.statistics()
    validation = repository.validate_repository()

    migration_path = output / "rmr-migration-result.json"
    migration_path.write_text(
        json.dumps(
            asdict(migration),
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    stats_path = output / "rmr-statistics.json"
    stats_path.write_text(
        json.dumps(
            stats,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    validation_path = output / "rmr-validation.json"
    validation_path.write_text(
        json.dumps(
            validation,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    jsonl_path = repository.export_jsonl(
        output / "rmr-resources.jsonl"
    )

    event = {
        "event_type": "MediaRepositoryInitialized",
        "occurred_at_utc": generated_at,
        "source": "sgoda.media",
        "architecture_decision": "ADR-010",
        "database": repository.database_path.as_posix(),
        "total_resources": stats["total_resources"],
        "unique_oda": stats["unique_oda"],
        "source_oda_repository": (
            Path(oda_repository_path).as_posix()
        ),
        "source_oda_sha256": _sha256(
            Path(oda_repository_path)
        ),
    }

    event_path = output / "rmr-initialized-event.json"
    event_path.write_text(
        json.dumps(
            event,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    artifact_paths = [
        repository.database_path,
        migration_path,
        stats_path,
        validation_path,
        jsonl_path,
        event_path,
    ]

    manifest = {
        "release": "ADR-010-v1.0.0",
        "generated_at_utc": generated_at,
        "capacity_target_resources": 120000,
        "artifacts": [
            {
                "path": path.as_posix(),
                "sha256": _sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in artifact_paths
        ],
    }

    manifest_path = output / "rmr-baseline-manifest.json"
    manifest_path.write_text(
        json.dumps(
            manifest,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return {
        "migration": migration_path,
        "statistics": stats_path,
        "validation": validation_path,
        "jsonl": jsonl_path,
        "event": event_path,
        "manifest": manifest_path,
    }


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Inicializa el Repositorio Multimedia Relacional ADR-010."
        )
    )
    parser.add_argument(
        "--oda-repository",
        default=(
            "artifacts/oda/SPT-002/"
            "oda-repository-v0.1.0.json"
        ),
    )
    parser.add_argument(
        "--database",
        default="artifacts/media/ADR-010/rmr.sqlite3",
    )
    parser.add_argument(
        "--output",
        default="artifacts/media/ADR-010",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    migration = migrar_oda_a_rmr(
        oda_repository_path=args.oda_repository,
        database_path=args.database,
    )

    repository = RepositorioMultimediaRMR(
        args.database
    )

    artifacts = publicar_evidencias_rmr(
        repository=repository,
        migration=migration,
        oda_repository_path=args.oda_repository,
        output_dir=args.output,
    )

    validation = json.loads(
        artifacts["validation"].read_text(
            encoding="utf-8"
        )
    )

    print("ADR-010 RMR ejecutado correctamente.")
    print(f"ODA migrados: {migration.total_oda}")
    print(
        "Recursos migrados: "
        f"{migration.total_resources}"
    )
    print(
        "Recursos en repositorio: "
        f"{repository.count()}"
    )
    print(
        "Validación: "
        f"{'APROBADA' if validation['passed'] else 'NO APROBADA'}"
    )
    print(f"Base de datos: {repository.database_path}")

    return 0 if validation["passed"] else 2


if __name__ == "__main__":
    raise SystemExit(main())