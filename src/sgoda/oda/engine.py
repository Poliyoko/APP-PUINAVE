"""SPT-002: motor funcional de generación ODA."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from dataclasses import asdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from .models import (
    ObjetoDigitalAprendizaje,
    RecursoMultimediaODA,
    ResultadoGeneracionODA,
    TrazabilidadODA,
)


ENGINE_VERSION = "0.1.0"
SOURCE_RELEASE = "SPT-001B-v1.0.0"


def _read_json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el artefacto requerido: {path}"
        )

    try:
        return json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as error:
        raise ValueError(
            f"JSON inválido en {path}: {error}"
        ) from error


def _write_json(path: Path, data: Any) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(
            data,
            ensure_ascii=False,
            indent=2,
            default=str,
        )
        + "\n",
        encoding="utf-8",
    )

    if not path.is_file() or path.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo generar el artefacto: {path}"
        )

    return path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(
            lambda: stream.read(1024 * 1024),
            b"",
        ):
            digest.update(chunk)

    return digest.hexdigest()


def _normalize(value: Any) -> str:
    text = "" if value is None else str(value)
    decomposed = unicodedata.normalize("NFKD", text)
    without_accents = "".join(
        char
        for char in decomposed
        if not unicodedata.combining(char)
    )
    lowered = without_accents.casefold()
    cleaned = re.sub(r"[^a-z0-9]+", "-", lowered)
    return cleaned.strip("-")


def _oda_id(canonical_id: str) -> str:
    normalized = _normalize(canonical_id).upper()

    if normalized:
        return f"ODA-{normalized}"

    digest = hashlib.sha256(
        canonical_id.encode("utf-8")
    ).hexdigest()[:16].upper()

    return f"ODA-{digest}"


def _first_value(
    record: dict[str, Any],
    *names: str,
) -> Any:
    for name in names:
        value = record.get(name)

        if value not in (None, ""):
            return value

    return None


def _known_fields() -> set[str]:
    return {
        "canonical_id",
        "canonical_position",
        "lexical_key_sha256",
        "identificador",
        "palabra_puinave",
        "traduccion_espanol",
        "traduccion_ingles",
        "categoria_gramatical",
        "tema_cultural",
        "contexto_etnografico",
        "definicion",
        "ejemplo_uso",
        "origen",
        "campos_desconocidos",
    }


def _media_slots() -> list[RecursoMultimediaODA]:
    return [
        RecursoMultimediaODA(
            tipo="imagen_ilustrativa",
            estado="pendiente_generacion_ia",
        ),
        RecursoMultimediaODA(
            tipo="audio_puinave",
            estado="pendiente_grabacion_nativa",
        ),
        RecursoMultimediaODA(
            tipo="audio_espanol",
            estado="pendiente_tts",
        ),
        RecursoMultimediaODA(
            tipo="audio_ingles",
            estado="pendiente_tts",
        ),
    ]


def generar_oda(
    *,
    record: dict[str, Any],
    source_schema: str,
    source_repository_sha256: str,
) -> ObjetoDigitalAprendizaje:
    """Transforma un registro canónico en un ODA validable."""

    canonical_id = str(
        record.get("canonical_id") or ""
    ).strip()
    palabra = str(
        record.get("palabra_puinave") or ""
    ).strip()

    validations: list[str] = []

    if not canonical_id:
        validations.append("canonical_id_obligatorio")

    if not palabra:
        validations.append("palabra_puinave_obligatoria")

    extensible = {
        key: value
        for key, value in record.items()
        if key not in _known_fields()
    }

    unknown = record.get("campos_desconocidos")

    if unknown:
        extensible["campos_desconocidos"] = unknown

    status = (
        "borrador_valido"
        if not validations
        else "bloqueado_por_validacion"
    )

    return ObjetoDigitalAprendizaje(
        oda_id=_oda_id(canonical_id),
        canonical_id=canonical_id,
        version="1.0.0",
        estado=status,
        palabra_puinave=palabra,
        traduccion_espanol=_first_value(
            record,
            "traduccion_espanol",
            "espanol",
        ),
        traduccion_ingles=_first_value(
            record,
            "traduccion_ingles",
            "ingles",
        ),
        categoria_gramatical=_first_value(
            record,
            "categoria_gramatical",
            "clase_gramatical",
        ),
        tema_cultural=_first_value(
            record,
            "tema_cultural",
            "categoria_cultural",
        ),
        contexto_etnografico=_first_value(
            record,
            "contexto_etnografico",
            "contexto_cultural",
        ),
        definicion=_first_value(
            record,
            "definicion",
            "significado",
        ),
        ejemplo_uso=_first_value(
            record,
            "ejemplo_uso",
            "ejemplo",
        ),
        recursos=_media_slots(),
        campos_extensibles=extensible,
        trazabilidad=TrazabilidadODA(
            canonical_id=canonical_id,
            source_release=SOURCE_RELEASE,
            source_schema=source_schema,
            source_repository_sha256=source_repository_sha256,
            generator="sgoda.oda.engine",
            generator_version=ENGINE_VERSION,
        ),
        validaciones=validations,
    )


def generar_repositorio_oda(
    *,
    canonical_repository: str | Path,
    active_schema: str | Path,
) -> ResultadoGeneracionODA:
    """Genera todos los ODA y calcula controles de calidad."""

    repository_path = Path(canonical_repository)
    schema_pointer_path = Path(active_schema)

    repository = _read_json(repository_path)
    schema_pointer = _read_json(schema_pointer_path)

    records = repository.get("registros")

    if not isinstance(records, list) or not records:
        raise ValueError(
            "El repositorio canónico no contiene registros."
        )

    source_schema = str(
        schema_pointer.get("active_schema") or ""
    )

    if not source_schema:
        raise ValueError(
            "active-schema.json no declara active_schema."
        )

    repository_sha = _sha256(repository_path)

    objects: list[ObjetoDigitalAprendizaje] = []
    errors: list[dict[str, Any]] = []
    warnings: list[dict[str, Any]] = []

    ids: list[str] = []

    for position, record in enumerate(records, start=1):
        if not isinstance(record, dict):
            errors.append(
                {
                    "position": position,
                    "code": "record_not_object",
                }
            )
            continue

        oda = generar_oda(
            record=record,
            source_schema=source_schema,
            source_repository_sha256=repository_sha,
        )
        objects.append(oda)
        ids.append(oda.oda_id)

        if oda.validaciones:
            errors.append(
                {
                    "position": position,
                    "canonical_id": oda.canonical_id,
                    "oda_id": oda.oda_id,
                    "codes": oda.validaciones,
                }
            )

    duplicate_ids = sorted(
        value
        for value in set(ids)
        if ids.count(value) > 1
    )

    if duplicate_ids:
        raise ValueError(
            "Existen oda_id duplicados: "
            + ", ".join(duplicate_ids)
        )

    total = len(objects)
    valid = sum(
        1
        for item in objects
        if item.estado == "borrador_valido"
    )

    media_slots = sum(
        len(item.recursos)
        for item in objects
    )

    statistics = {
        "total_oda": total,
        "oda_validos": valid,
        "oda_bloqueados": total - valid,
        "oda_id_unicos": len(set(ids)),
        "media_slots_total": media_slots,
        "imagenes_pendientes": sum(
            1
            for item in objects
            for resource in item.recursos
            if resource.tipo == "imagen_ilustrativa"
            and resource.estado != "disponible"
        ),
        "audios_puinave_pendientes": sum(
            1
            for item in objects
            for resource in item.recursos
            if resource.tipo == "audio_puinave"
            and resource.estado != "disponible"
        ),
        "audios_espanol_pendientes": sum(
            1
            for item in objects
            for resource in item.recursos
            if resource.tipo == "audio_espanol"
            and resource.estado != "disponible"
        ),
        "audios_ingles_pendientes": sum(
            1
            for item in objects
            for resource in item.recursos
            if resource.tipo == "audio_ingles"
            and resource.estado != "disponible"
        ),
        "quality_percentage": (
            round((valid / total) * 100, 2)
            if total
            else 0.0
        ),
        "duplicate_oda_ids": len(duplicate_ids),
    }

    if not errors and statistics["quality_percentage"] == 100.0:
        warnings.append(
            {
                "code": "MULTIMEDIA_PENDING",
                "message": (
                    "Los ODA son válidos, pero sus recursos "
                    "multimedia aún están pendientes."
                ),
            }
        )

    return ResultadoGeneracionODA(
        objetos=objects,
        errores=errors,
        advertencias=warnings,
        estadisticas=statistics,
    )


def publicar_repositorio_oda(
    *,
    resultado: ResultadoGeneracionODA,
    output_dir: str | Path,
    canonical_repository: str | Path,
) -> dict[str, Path]:
    """Publica repositorio ODA, estadísticas, validación y evento."""

    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    generated_at = datetime.now(timezone.utc).isoformat()
    canonical_path = Path(canonical_repository)

    repository_payload = {
        "metadata": {
            "sistema": "SGODA-PUINAVE",
            "entregable": "SPT-002",
            "version_motor": ENGINE_VERSION,
            "generated_at_utc": generated_at,
            "source_release": SOURCE_RELEASE,
            "source_repository": canonical_path.as_posix(),
            "source_repository_sha256": _sha256(
                canonical_path
            ),
            "total_oda": len(resultado.objetos),
        },
        "objetos_digitales_aprendizaje": [
            asdict(item)
            for item in resultado.objetos
        ],
    }

    validation_payload = {
        "increment": "SPT-002",
        "generated_at_utc": generated_at,
        "passed": not resultado.errores,
        "errors": resultado.errores,
        "warnings": resultado.advertencias,
        "checks": {
            "objects_present": bool(resultado.objetos),
            "zero_validation_errors": not resultado.errores,
            "unique_oda_ids": (
                resultado.estadisticas[
                    "duplicate_oda_ids"
                ]
                == 0
            ),
            "all_have_four_media_slots": all(
                len(item.recursos) == 4
                for item in resultado.objetos
            ),
            "all_have_traceability": all(
                item.trazabilidad is not None
                for item in resultado.objetos
            ),
        },
    }

    validation_payload["passed"] = all(
        validation_payload["checks"].values()
    )

    repository_path = _write_json(
        output / "oda-repository-v0.1.0.json",
        repository_payload,
    )
    statistics_path = _write_json(
        output / "oda-statistics.json",
        resultado.estadisticas,
    )
    validation_path = _write_json(
        output / "oda-validation.json",
        validation_payload,
    )

    event = {
        "event_id": hashlib.sha256(
            (
                _sha256(repository_path)
                + generated_at
            ).encode("utf-8")
        ).hexdigest(),
        "event_type": "OdaRepositoryGenerated",
        "occurred_at_utc": generated_at,
        "source": "sgoda.oda.engine",
        "increment": "SPT-002",
        "total_oda": resultado.estadisticas["total_oda"],
        "valid_oda": resultado.estadisticas["oda_validos"],
        "blocked_oda": resultado.estadisticas["oda_bloqueados"],
        "repository": repository_path.as_posix(),
        "repository_sha256": _sha256(repository_path),
    }

    event_path = _write_json(
        output / "oda-generation-event.json",
        event,
    )

    manifest = {
        "release": "SPT-002-v0.1.0",
        "generated_at_utc": generated_at,
        "artifacts": [
            {
                "path": path.as_posix(),
                "sha256": _sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in (
                repository_path,
                statistics_path,
                validation_path,
                event_path,
            )
        ],
    }

    manifest_path = _write_json(
        output / "oda-baseline-manifest.json",
        manifest,
    )

    return {
        "repository": repository_path,
        "statistics": statistics_path,
        "validation": validation_path,
        "event": event_path,
        "manifest": manifest_path,
    }


def ejecutar_motor_oda(
    *,
    canonical_repository: str | Path,
    active_schema: str | Path,
    output_dir: str | Path,
) -> dict[str, Any]:
    """Ejecuta generación, validación y publicación ODA."""

    result = generar_repositorio_oda(
        canonical_repository=canonical_repository,
        active_schema=active_schema,
    )

    artifacts = publicar_repositorio_oda(
        resultado=result,
        output_dir=output_dir,
        canonical_repository=canonical_repository,
    )

    return {
        "resultado": result,
        "artefactos": artifacts,
    }


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Genera el repositorio ODA desde la línea base canónica."
        )
    )
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P08/"
            "canonical-repository-v1.0.0.json"
        ),
    )
    parser.add_argument(
        "--active-schema",
        default="config/rlb/active-schema.json",
    )
    parser.add_argument(
        "--output",
        default="artifacts/oda/SPT-002",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    execution = ejecutar_motor_oda(
        canonical_repository=args.canonical,
        active_schema=args.active_schema,
        output_dir=args.output,
    )

    result = execution["resultado"]

    print("SPT-002 ejecutado correctamente.")
    print(f"ODA generados: {result.estadisticas['total_oda']}")
    print(f"ODA válidos: {result.estadisticas['oda_validos']}")
    print(
        "ODA bloqueados: "
        f"{result.estadisticas['oda_bloqueados']}"
    )
    print(
        "Calidad: "
        f"{result.estadisticas['quality_percentage']}%"
    )
    print(
        "Repositorio: "
        f"{execution['artefactos']['repository']}"
    )

    return 0 if not result.errores else 2


if __name__ == "__main__":
    raise SystemExit(main())