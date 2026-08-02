<#
.SYNOPSIS
    Implementa SPT-002 — Motor funcional del Repositorio Canónico
    y generación de Objetos Digitales de Aprendizaje (ODA).

.DESCRIPTION
    Instala en una sola ejecución:
      - modelos ODA;
      - motor de generación determinística;
      - validación y estadísticas;
      - CLI;
      - evento OdaRepositoryGenerated;
      - pruebas automatizadas;
      - documentación;
      - evidencias;
      - trazabilidad;
      - dashboard;
      - quality gate SGD-114.

    Consume la línea base cerrada:
      artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SPT002-ODA-Engine-Institutional.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([string]$Message)
    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Assert-Path {
    param([string]$Path, [string]$Description)

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se encontró $Description en: $Path"
    }
}

function Write-Utf8NoBom {
    param([string]$Path, [string]$Content)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo crear: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 40

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo generar: $Path"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$OdaDir = Join-Path $SrcRoot "sgoda\oda"
$TestsDir = Join-Path $ProjectRoot "tests\oda"
$ConfigDir = Join-Path $ProjectRoot "config\oda"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-002"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\oda\SPT-002"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-002"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-002-v0.1.0"

$CanonicalInput = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P08\canonical-repository-v1.0.0.json"
$CanonicalManifest = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P08\canonical-baseline-manifest.json"
$ActiveSchema = Join-Path $ProjectRoot "config\rlb\active-schema.json"

$ModelsPath = Join-Path $OdaDir "models.py"
$EnginePath = Join-Path $OdaDir "engine.py"
$CliPath = Join-Path $OdaDir "cli.py"
$InitPath = Join-Path $OdaDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_SPT_002_oda_engine.py"
$ConfigPath = Join-Path $ConfigDir "SPT-002-component.json"
$PolicyPath = Join-Path $ConfigDir "oda-generation-policy.json"
$DocPath = Join-Path $DocsDir "SPT-002-Motor-Funcional-ODA.md"
$ArchitecturePath = Join-Path $DocsDir "SPT-002-Arquitectura-ODA.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT002-ODAEngine.ps1"
$TracePath = Join-Path $PmoDir "traceability-SPT-002.json"
$EvidencePath = Join-Path $PmoDir "implementation-evidence.json"
$GatePath = Join-Path $PmoDir "SPT-002-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-002-dashboard.json"

Write-Step "Validando línea base institucional"

foreach ($Required in @(
    $CanonicalInput,
    $CanonicalManifest,
    $ActiveSchema,
    (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json"),
    (Join-Path $ProjectRoot "artifacts\pmo\SPT-001B\SPT-001B-final-quality-gate.json"),
    (Join-Path $ProjectRoot "pytest.ini")
)) {
    Assert-Path -Path $Required -Description $Required
}

$ClosureGate = Get-Content `
    -LiteralPath (Join-Path $ProjectRoot "artifacts\pmo\SPT-001B\SPT-001B-final-quality-gate.json") `
    -Raw |
    ConvertFrom-Json

if (-not $ClosureGate.passed -or -not $ClosureGate.closure_authorized) {
    throw "SPT-001B no está cerrado institucionalmente."
}

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

$ModelsContent = @'
"""Modelos institucionales de Objetos Digitales de Aprendizaje."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class RecursoMultimediaODA:
    """Referencia extensible a un recurso multimedia."""

    tipo: str
    estado: str = "pendiente"
    uri: str | None = None
    proveedor: str | None = None
    checksum_sha256: str | None = None
    metadatos: dict[str, Any] = field(default_factory=dict)


@dataclass(slots=True)
class TrazabilidadODA:
    """Origen y versionado de un ODA."""

    canonical_id: str
    source_release: str
    source_schema: str
    source_repository_sha256: str
    generator: str
    generator_version: str


@dataclass(slots=True)
class ObjetoDigitalAprendizaje:
    """Unidad funcional de aprendizaje derivada del repositorio canónico."""

    oda_id: str
    canonical_id: str
    version: str
    estado: str
    palabra_puinave: str
    traduccion_espanol: str | None = None
    traduccion_ingles: str | None = None
    categoria_gramatical: str | None = None
    tema_cultural: str | None = None
    contexto_etnografico: str | None = None
    definicion: str | None = None
    ejemplo_uso: str | None = None
    recursos: list[RecursoMultimediaODA] = field(default_factory=list)
    campos_extensibles: dict[str, Any] = field(default_factory=dict)
    trazabilidad: TrazabilidadODA | None = None
    validaciones: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultadoGeneracionODA:
    """Resultado integral de una generación del repositorio ODA."""

    objetos: list[ObjetoDigitalAprendizaje]
    errores: list[dict[str, Any]]
    advertencias: list[dict[str, Any]]
    estadisticas: dict[str, Any]
'@

$EngineContent = @'
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
'@

$CliContent = @'
"""CLI pública de SPT-002."""

from .engine import main


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Motor de Objetos Digitales de Aprendizaje SGODA-PUINAVE."""

from .engine import (
    ejecutar_motor_oda,
    generar_oda,
    generar_repositorio_oda,
    publicar_repositorio_oda,
)
from .models import (
    ObjetoDigitalAprendizaje,
    RecursoMultimediaODA,
    ResultadoGeneracionODA,
    TrazabilidadODA,
)

__all__ = [
    "ObjetoDigitalAprendizaje",
    "RecursoMultimediaODA",
    "ResultadoGeneracionODA",
    "TrazabilidadODA",
    "ejecutar_motor_oda",
    "generar_oda",
    "generar_repositorio_oda",
    "publicar_repositorio_oda",
]
'@

$TestContent = @'
"""Pruebas funcionales SPT-002 del motor ODA."""

import json
import subprocess
import sys
from pathlib import Path

from sgoda.oda.engine import (
    ejecutar_motor_oda,
    generar_oda,
    generar_repositorio_oda,
)


def _write(path: Path, data: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False),
        encoding="utf-8",
    )
    return path


def _fixture(tmp_path: Path) -> tuple[Path, Path]:
    canonical = {
        "metadata": {
            "release": "SPT-001B-v1.0.0",
        },
        "registros": [
            {
                "canonical_id": "LEX-0001",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "traduccion_ingles": "example",
                "tema_cultural": "vida cotidiana",
            },
            {
                "canonical_id": "LEX-0002",
                "palabra_puinave": "BETA",
                "traduccion_espanol": "segundo",
            },
        ],
    }

    active_schema = {
        "active_schema": "config/rlb/schema-v1.1.json",
        "version": "1.1.0",
    }

    return (
        _write(tmp_path / "canonical.json", canonical),
        _write(tmp_path / "active-schema.json", active_schema),
    )


def test_SPT_002_genera_oda_deterministico() -> None:
    record = {
        "canonical_id": "LEX-0001",
        "palabra_puinave": "AMDA",
    }

    first = generar_oda(
        record=record,
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="a" * 64,
    )
    second = generar_oda(
        record=record,
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="a" * 64,
    )

    assert first.oda_id == "ODA-LEX-0001"
    assert first.oda_id == second.oda_id
    assert first.estado == "borrador_valido"


def test_SPT_002_crea_cuatro_slots_multimedia() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "LEX-0001",
            "palabra_puinave": "AMDA",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="b" * 64,
    )

    assert len(oda.recursos) == 4
    assert {
        item.tipo
        for item in oda.recursos
    } == {
        "imagen_ilustrativa",
        "audio_puinave",
        "audio_espanol",
        "audio_ingles",
    }


def test_SPT_002_preserva_campos_extensibles() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "LEX-0001",
            "palabra_puinave": "AMDA",
            "nuevo_campo_cultural": "valor",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="c" * 64,
    )

    assert oda.campos_extensibles[
        "nuevo_campo_cultural"
    ] == "valor"


def test_SPT_002_bloquea_registro_incompleto() -> None:
    oda = generar_oda(
        record={
            "canonical_id": "",
            "palabra_puinave": "",
        },
        source_schema="config/rlb/schema-v1.1.json",
        source_repository_sha256="d" * 64,
    )

    assert oda.estado == "bloqueado_por_validacion"
    assert "canonical_id_obligatorio" in oda.validaciones
    assert "palabra_puinave_obligatoria" in oda.validaciones


def test_SPT_002_publica_repositorio_y_manifiesto(
    tmp_path: Path,
) -> None:
    canonical, active_schema = _fixture(tmp_path)

    execution = ejecutar_motor_oda(
        canonical_repository=canonical,
        active_schema=active_schema,
        output_dir=tmp_path / "output",
    )

    result = execution["resultado"]
    artifacts = execution["artefactos"]

    assert result.estadisticas["total_oda"] == 2
    assert result.estadisticas["oda_validos"] == 2
    assert result.estadisticas["quality_percentage"] == 100.0

    for path in artifacts.values():
        assert path.is_file()
        assert path.stat().st_size > 0

    validation = json.loads(
        artifacts["validation"].read_text(encoding="utf-8")
    )
    manifest = json.loads(
        artifacts["manifest"].read_text(encoding="utf-8")
    )

    assert validation["passed"] is True
    assert manifest["release"] == "SPT-002-v0.1.0"

    for item in manifest["artifacts"]:
        assert len(item["sha256"]) == 64


def test_SPT_002_cli_sin_advertencias(
    tmp_path: Path,
) -> None:
    canonical, active_schema = _fixture(tmp_path)
    output = tmp_path / "cli-output"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.oda.cli",
            "--canonical",
            str(canonical),
            "--active-schema",
            str(active_schema),
            "--output",
            str(output),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "SPT-002 ejecutado correctamente." in process.stdout
    assert (output / "oda-repository-v0.1.0.json").is_file()
    assert (output / "oda-statistics.json").is_file()
    assert (output / "oda-validation.json").is_file()
    assert (output / "oda-generation-event.json").is_file()
    assert (output / "oda-baseline-manifest.json").is_file()
'@

$ComponentConfig = @'
{
  "increment_code": "SPT-002",
  "component_type": "oda_functional_engine",
  "version": "0.1.0",
  "status": "technically_completed",
  "entrypoint": "sgoda.oda.cli",
  "source_repository": "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json",
  "source": [
    "src/sgoda/oda/models.py",
    "src/sgoda/oda/engine.py",
    "src/sgoda/oda/cli.py"
  ],
  "tests": [
    "tests/oda/test_SPT_002_oda_engine.py"
  ],
  "governed_by": "SGD-114"
}
'@

$GenerationPolicy = @'
{
  "policy_code": "SPT-002-ODA-GENERATION",
  "version": "0.1.0",
  "oda_version": "1.0.0",
  "required_fields": [
    "canonical_id",
    "palabra_puinave"
  ],
  "media_slots": [
    "imagen_ilustrativa",
    "audio_puinave",
    "audio_espanol",
    "audio_ingles"
  ],
  "default_status": "borrador_valido",
  "invalid_status": "bloqueado_por_validacion",
  "preserve_unknown_fields": true,
  "deterministic_ids": true,
  "source_release": "SPT-001B-v1.0.0"
}
'@

$DocContent = @'
# SPT-002 — Motor funcional del Repositorio Canónico y generación ODA

## Objetivo

Transformar cada registro del Repositorio Léxico Canónico en un Objeto
Digital de Aprendizaje versionado, trazable, extensible y preparado para
los futuros pipelines de imágenes, audios, API, portal web y Flutter.

## Funcionalidad

- Generación determinística de `oda_id`.
- Preservación del `canonical_id`.
- Validación de campos obligatorios.
- Estado `borrador_valido` o `bloqueado_por_validacion`.
- Cuatro espacios multimedia por ODA.
- Conservación de campos futuros.
- Trazabilidad hacia release, esquema y hash del repositorio fuente.
- Estadísticas, validación, evento y manifiesto SHA-256.
- CLI reproducible.
- Gobierno mediante SGD-114.

## Artefactos

- `oda-repository-v0.1.0.json`
- `oda-statistics.json`
- `oda-validation.json`
- `oda-generation-event.json`
- `oda-baseline-manifest.json`

## Alcance de esta versión

SPT-002 v0.1 genera la estructura funcional ODA. Los recursos de imagen
y audio quedan deliberadamente en estado pendiente para ser atendidos
por los siguientes incrementos de IA, TTS y grabación nativa.
'@

$ArchitectureContent = @'
# SPT-002 — Arquitectura del motor ODA

```text
Repositorio Canónico SPT-001B
            |
            v
      Motor SPT-002
            |
     +------+------+
     |             |
Validación     Mapeo ODA
     |             |
     +------+------+
            |
            v
Repositorio ODA v0.1.0
            |
   +--------+---------+---------+---------+
   |                  |         |         |
Imágenes IA      Audio PU   TTS ES/EN   API/Apps
```

El motor no modifica el repositorio canónico. Toda salida se genera como
una línea base derivada, con hash y trazabilidad hacia la fuente.
'@

$InvokeContent = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.oda.cli `
    --canonical "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json" `
    --active-schema "config/rlb/active-schema.json" `
    --output "artifacts/oda/SPT-002"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-002 terminó con errores."
}
'@

Write-Step "Instalando motor SPT-002"

Write-Utf8NoBom -Path $ModelsPath -Content $ModelsContent
Write-Utf8NoBom -Path $EnginePath -Content $EngineContent
Write-Utf8NoBom -Path $CliPath -Content $CliContent
Write-Utf8NoBom -Path $InitPath -Content $InitContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $ConfigPath -Content $ComponentConfig
Write-Utf8NoBom -Path $PolicyPath -Content $GenerationPolicy
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ArchitecturePath -Content $ArchitectureContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Generando evidencias y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Evidence = [ordered]@{
    increment_code = "SPT-002"
    version = "0.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    source_release = "SPT-001B-v1.0.0"
    components = @(
        "src/sgoda/oda/models.py",
        "src/sgoda/oda/engine.py",
        "src/sgoda/oda/cli.py",
        "tests/oda/test_SPT_002_oda_engine.py",
        "config/oda/SPT-002-component.json",
        "config/oda/oda-generation-policy.json",
        "docs/05_Fase_Tecnologica/SPT-002/SPT-002-Motor-Funcional-ODA.md",
        "docs/05_Fase_Tecnologica/SPT-002/SPT-002-Arquitectura-ODA.md",
        "scripts/Invoke-SPT002-ODAEngine.ps1"
    )
}
Write-JsonUtf8 -Path $EvidencePath -Data $Evidence

$Trace = [ordered]@{
    increment_code = "SPT-002"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/oda/models.py",
        "src/sgoda/oda/engine.py",
        "src/sgoda/oda/cli.py",
        "config/oda/SPT-002-component.json",
        "config/oda/oda-generation-policy.json"
    )
    tests = @(
        "tests/oda/test_SPT_002_oda_engine.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-002/SPT-002-Motor-Funcional-ODA.md",
        "docs/05_Fase_Tecnologica/SPT-002/SPT-002-Arquitectura-ODA.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-002/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importaciones"

& python -c "from sgoda.oda import ejecutar_motor_oda, ObjetoDigitalAprendizaje; print(ejecutar_motor_oda.__name__, ObjetoDigitalAprendizaje.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de SPT-002."
}

Write-Step "Ejecutando pruebas específicas SPT-002"

& python -m pytest `
    "tests/oda/test_SPT_002_oda_engine.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPT-002 terminaron con errores."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest

    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Generando repositorio ODA real"

& python -m sgoda.oda.cli `
    --canonical "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json" `
    --active-schema "config/rlb/active-schema.json" `
    --output "artifacts/oda/SPT-002"

if ($LASTEXITCODE -ne 0) {
    throw "La generación real de ODA terminó con errores."
}

foreach ($Artifact in @(
    "oda-repository-v0.1.0.json",
    "oda-statistics.json",
    "oda-validation.json",
    "oda-generation-event.json",
    "oda-baseline-manifest.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

$Statistics = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "oda-statistics.json") `
    -Raw |
    ConvertFrom-Json

$Validation = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "oda-validation.json") `
    -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación real del repositorio ODA no fue aprobada."
}

if ([int]$Statistics.oda_bloqueados -ne 0) {
    throw "Existen ODA bloqueados por validación."
}

Write-Step "Publicando release técnico"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

foreach ($Artifact in @(
    "oda-repository-v0.1.0.json",
    "oda-statistics.json",
    "oda-validation.json",
    "oda-generation-event.json",
    "oda-baseline-manifest.json"
)) {
    Copy-Item `
        -LiteralPath (Join-Path $ArtifactsDir $Artifact) `
        -Destination (Join-Path $ReleaseDir $Artifact) `
        -Force
}

$Trace.evidence = @(
    "artifacts/pmo/SPT-002/implementation-evidence.json",
    "artifacts/oda/SPT-002/oda-repository-v0.1.0.json",
    "artifacts/oda/SPT-002/oda-statistics.json",
    "artifacts/oda/SPT-002/oda-validation.json",
    "artifacts/oda/SPT-002/oda-generation-event.json",
    "artifacts/oda/SPT-002/oda-baseline-manifest.json",
    "releases/SPT-002-v0.1.0/"
)
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-002" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate SPT-002 no aprobado. Faltan: $Missing"
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate SPT-002 no contiene passed=true."
}

$Dashboard = [ordered]@{
    increment_code = "SPT-002"
    version = "0.1.0"
    status = "technically_completed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    source_release = "SPT-001B-v1.0.0"
    total_oda = $Statistics.total_oda
    oda_validos = $Statistics.oda_validos
    oda_bloqueados = $Statistics.oda_bloqueados
    quality_percentage = $Statistics.quality_percentage
    media_slots_total = $Statistics.media_slots_total
    imagenes_pendientes = $Statistics.imagenes_pendientes
    audios_puinave_pendientes = $Statistics.audios_puinave_pendientes
    audios_espanol_pendientes = $Statistics.audios_espanol_pendientes
    audios_ingles_pendientes = $Statistics.audios_ingles_pendientes
    tests = "approved"
    validation = "approved"
    quality_gate = "approved"
    release = "SPT-002-v0.1.0"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-002 implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 6 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 78: 84 pruebas." -ForegroundColor Cyan
Write-Host "ODA generados: $($Statistics.total_oda)" -ForegroundColor Cyan
Write-Host "ODA válidos: $($Statistics.oda_validos)" -ForegroundColor Green
Write-Host "ODA bloqueados: $($Statistics.oda_bloqueados)" -ForegroundColor Green
Write-Host "Calidad: $($Statistics.quality_percentage)%" -ForegroundColor Green
Write-Host "Slots multimedia: $($Statistics.media_slots_total)" -ForegroundColor Cyan
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Release: releases\SPT-002-v0.1.0" -ForegroundColor Cyan
