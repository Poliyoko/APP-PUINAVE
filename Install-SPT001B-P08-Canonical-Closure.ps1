<#
.SYNOPSIS
    Implementa SPT-001B-P08 y cierra institucionalmente SPT-001B.

.DESCRIPTION
    Consolida el Repositorio Canónico validado por P07, promueve el
    esquema normalizado, genera identificadores determinísticos,
    estadísticas, controles de duplicados, manifiestos SHA-256,
    línea base, documentación, release, dashboard y quality gates.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER Force
    Regenera los artefactos gestionados por P08.

.EXAMPLE
    .\Install-SPT001B-P08-Canonical-Closure.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Force
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
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$env:PYTHONPATH = $SrcRoot

$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$TestsDir = Join-Path $ProjectRoot "tests\rlb"
$ConfigDir = Join-Path $ProjectRoot "config\rlb"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-001"
$GovDocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$HistoryDir = Join-Path $ProjectRoot "docs\15_Historial"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$P07Dir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P07"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P08"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P08"
$ClosurePmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-001B-v1.0.0"

$ConsolidatorPath = Join-Path $RlbDir "canonical_consolidator.py"
$TestPath = Join-Path $TestsDir "test_SPT_001B_P08_canonical_closure.py"
$ComponentPath = Join-Path $ConfigDir "SPT-001B-P08-component.json"
$PromotedSchemaPath = Join-Path $ConfigDir "schema-v1.1.json"
$ActiveSchemaPath = Join-Path $ConfigDir "active-schema.json"
$DocPath = Join-Path $DocsDir "SPT-001B-P08-Consolidacion-Cierre.md"
$ClosureActPath = Join-Path $GovDocsDir "SPT-001B-Acta-Cierre-Institucional.md"
$HistoryPath = Join-Path $HistoryDir "SPT-001B-Registro-Historico-Cierre.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT001B-P08.ps1"
$TracePath = Join-Path $PmoDir "traceability-SPT-001B-P08.json"
$ManifestPath = Join-Path $PmoDir "implementation-evidence.json"
$GateP08Path = Join-Path $PmoDir "SPT-001B-P08-quality-gate.json"
$ClosureGatePath = Join-Path $ClosurePmoDir "SPT-001B-final-quality-gate.json"
$DashboardPath = Join-Path $DashboardDir "SPT-001B-dashboard.json"

Write-Step "Validando línea base P07"

foreach ($Required in @(
    "artifacts\rlb\SPT-001B-P07\schema-p07-normalized.json",
    "artifacts\rlb\SPT-001B-P07\normalization-summary.json",
    "artifacts\rlb\SPT-001B-P07\reprocessed\palabras-canonicas.json",
    "artifacts\rlb\SPT-001B-P07\reprocessed\perfil-rlb.json",
    "artifacts\rlb\SPT-001B-P07\reprocessed\errores-importacion.json",
    "artifacts\pmo\SPT-001B-P07\SPT-001B-P07-quality-gate.json",
    "config\governance\sgd-114-policy.json",
    "pytest.ini"
)) {
    Assert-Path `
        -Path (Join-Path $ProjectRoot $Required) `
        -Description $Required
}

$P07Summary = Get-Content `
    -LiteralPath (Join-Path $P07Dir "normalization-summary.json") `
    -Raw |
    ConvertFrom-Json

if ([int]$P07Summary.total_records -le 0) {
    throw "P07 no contiene registros para consolidar."
}

if ([int]$P07Summary.invalid_records -ne 0) {
    throw (
        "P08 exige cero errores residuales. P07 reporta: " +
        $P07Summary.invalid_records
    )
}

if ([int]$P07Summary.valid_records -ne [int]$P07Summary.total_records) {
    throw "P07 no tiene todos sus registros en estado válido."
}

$ConsolidatorContent = @'
"""SPT-001B-P08: consolidación y cierre del Repositorio Canónico."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import unicodedata
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


@dataclass(frozen=True, slots=True)
class ResultadoConsolidacion:
    repository_path: Path
    statistics_path: Path
    validation_path: Path
    manifest_path: Path
    total_records: int
    duplicate_canonical_ids: int
    duplicate_lexical_keys: int


def _json(path: Path) -> dict[str, Any]:
    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró el artefacto requerido: {path}"
        )

    return json.loads(path.read_text(encoding="utf-8"))


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
    cleaned = re.sub(r"[^a-z0-9]+", " ", lowered)
    return " ".join(cleaned.split())


def _source_identity(record: dict[str, Any], position: int) -> str:
    origin = record.get("origen") or {}

    components = [
        str(record.get("identificador") or ""),
        str(origin.get("archivo") or ""),
        str(origin.get("hoja") or ""),
        str(origin.get("fila") or ""),
        str(record.get("palabra_puinave") or ""),
        str(position),
    ]

    return "|".join(components)


def _canonical_id(
    record: dict[str, Any],
    position: int,
) -> str:
    existing = str(
        record.get("identificador") or ""
    ).strip()

    if existing:
        normalized = re.sub(
            r"[^A-Za-z0-9_.-]+",
            "-",
            existing,
        ).strip("-")

        if normalized:
            return normalized

    digest = hashlib.sha256(
        _source_identity(record, position).encode("utf-8")
    ).hexdigest()[:16].upper()

    return f"RLB-{digest}"


def _lexical_key(record: dict[str, Any]) -> str:
    values = [
        record.get("palabra_puinave"),
        record.get("traduccion_espanol"),
        record.get("traduccion_ingles"),
    ]
    return "|".join(_normalize(value) for value in values)


def consolidar_repositorio(
    *,
    canonical_input: str | Path,
    profile_input: str | Path,
    errors_input: str | Path,
    schema_input: str | Path,
    output_dir: str | Path,
) -> ResultadoConsolidacion:
    """Consolida la línea base canónica sin modificar P07."""

    canonical_path = Path(canonical_input)
    profile_path = Path(profile_input)
    errors_path = Path(errors_input)
    schema_path = Path(schema_input)
    output = Path(output_dir)
    output.mkdir(parents=True, exist_ok=True)

    canonical = _json(canonical_path)
    profile = _json(profile_path)
    errors = _json(errors_path)
    schema = _json(schema_path)

    records = canonical.get("registros")

    if not isinstance(records, list) or not records:
        raise ValueError(
            "El repositorio P07 no contiene registros."
        )

    error_items = errors.get("errores", [])

    if error_items:
        raise ValueError(
            "No se puede consolidar con errores residuales."
        )

    consolidated: list[dict[str, Any]] = []
    canonical_ids: list[str] = []
    lexical_keys: list[str] = []

    for position, original in enumerate(records, start=1):
        if not isinstance(original, dict):
            raise ValueError(
                f"El registro {position} no es un objeto."
            )

        record = dict(original)
        canonical_id = _canonical_id(record, position)
        lexical_key = _lexical_key(record)

        canonical_ids.append(canonical_id)
        lexical_keys.append(lexical_key)

        record["canonical_id"] = canonical_id
        record["canonical_position"] = position
        record["lexical_key_sha256"] = hashlib.sha256(
            lexical_key.encode("utf-8")
        ).hexdigest()

        consolidated.append(record)

    duplicate_ids = sorted(
        value
        for value in set(canonical_ids)
        if canonical_ids.count(value) > 1
    )
    duplicate_keys = sorted(
        value
        for value in set(lexical_keys)
        if value and lexical_keys.count(value) > 1
    )

    if duplicate_ids:
        raise ValueError(
            "Existen identificadores canónicos duplicados: "
            + ", ".join(duplicate_ids)
        )

    generated_at = datetime.now(timezone.utc).isoformat()

    repository = {
        "metadata": {
            "sistema": "SGODA-PUINAVE",
            "entregable": "SPT-001B-P08",
            "release": "SPT-001B-v1.0.0",
            "generated_at_utc": generated_at,
            "schema_version": schema.get("version"),
            "total_records": len(consolidated),
            "source_artifact": canonical_path.as_posix(),
            "source_sha256": _sha256(canonical_path),
            "profile_sha256": _sha256(profile_path),
            "schema_sha256": _sha256(schema_path),
        },
        "registros": consolidated,
    }

    repository_path = _write_json(
        output / "canonical-repository-v1.0.0.json",
        repository,
    )

    statistics = {
        "increment": "SPT-001B-P08",
        "generated_at_utc": generated_at,
        "total_records": len(consolidated),
        "valid_records": profile.get(
            "total_registros_validos",
            len(consolidated),
        ),
        "invalid_records": profile.get(
            "total_registros_con_errores",
            0,
        ),
        "unique_canonical_ids": len(set(canonical_ids)),
        "duplicate_canonical_ids": len(duplicate_ids),
        "duplicate_lexical_keys": len(duplicate_keys),
        "duplicate_lexical_key_values": duplicate_keys,
        "quality_percentage": (
            100.0
            if not error_items
            else round(
                (
                    (len(consolidated) - len(error_items))
                    / len(consolidated)
                )
                * 100,
                2,
            )
        ),
    }

    statistics_path = _write_json(
        output / "canonical-statistics.json",
        statistics,
    )

    validation = {
        "increment": "SPT-001B-P08",
        "generated_at_utc": generated_at,
        "checks": {
            "records_present": bool(consolidated),
            "zero_residual_errors": not error_items,
            "canonical_ids_unique": not duplicate_ids,
            "all_records_have_canonical_id": all(
                bool(item.get("canonical_id"))
                for item in consolidated
            ),
            "source_profile_consistent": (
                int(
                    profile.get(
                        "total_registros",
                        len(consolidated),
                    )
                )
                == len(consolidated)
            ),
        },
        "warnings": (
            [
                {
                    "code": "DUPLICATE_LEXICAL_KEY",
                    "count": len(duplicate_keys),
                    "note": (
                        "Se preservan para revisión lingüística; "
                        "no duplican el identificador canónico."
                    ),
                }
            ]
            if duplicate_keys
            else []
        ),
    }

    validation["passed"] = all(
        validation["checks"].values()
    )

    if not validation["passed"]:
        raise ValueError(
            "La validación final del repositorio no fue aprobada."
        )

    validation_path = _write_json(
        output / "canonical-validation.json",
        validation,
    )

    artifact_paths = [
        repository_path,
        statistics_path,
        validation_path,
        schema_path,
        profile_path,
        errors_path,
    ]

    manifest = {
        "release": "SPT-001B-v1.0.0",
        "generated_at_utc": generated_at,
        "artifacts": [
            {
                "path": path.as_posix(),
                "sha256": _sha256(path),
                "size_bytes": path.stat().st_size,
            }
            for path in artifact_paths
        ],
    }

    manifest_path = _write_json(
        output / "canonical-baseline-manifest.json",
        manifest,
    )

    return ResultadoConsolidacion(
        repository_path=repository_path,
        statistics_path=statistics_path,
        validation_path=validation_path,
        manifest_path=manifest_path,
        total_records=len(consolidated),
        duplicate_canonical_ids=len(duplicate_ids),
        duplicate_lexical_keys=len(duplicate_keys),
    )


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Consolida y valida la línea base canónica SPT-001B."
        )
    )
    parser.add_argument(
        "--canonical",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "palabras-canonicas.json"
        ),
    )
    parser.add_argument(
        "--profile",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "perfil-rlb.json"
        ),
    )
    parser.add_argument(
        "--errors",
        default=(
            "artifacts/rlb/SPT-001B-P07/reprocessed/"
            "errores-importacion.json"
        ),
    )
    parser.add_argument(
        "--schema",
        default=(
            "artifacts/rlb/SPT-001B-P07/"
            "schema-p07-normalized.json"
        ),
    )
    parser.add_argument(
        "--output",
        default="artifacts/rlb/SPT-001B-P08",
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()

    result = consolidar_repositorio(
        canonical_input=args.canonical,
        profile_input=args.profile,
        errors_input=args.errors,
        schema_input=args.schema,
        output_dir=args.output,
    )

    print("SPT-001B-P08 ejecutado correctamente.")
    print(f"Registros consolidados: {result.total_records}")
    print(
        "IDs canónicos duplicados: "
        f"{result.duplicate_canonical_ids}"
    )
    print(
        "Claves léxicas duplicadas: "
        f"{result.duplicate_lexical_keys}"
    )
    print(f"Repositorio: {result.repository_path}")
    print(f"Manifiesto: {result.manifest_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$TestContent = @'
"""Pruebas SPT-001B-P08 de consolidación y cierre."""

import hashlib
import json
from pathlib import Path

from sgoda.rlb.canonical_consolidator import (
    consolidar_repositorio,
)


def _write(path: Path, data: object) -> Path:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False),
        encoding="utf-8",
    )
    return path


def _inputs(tmp_path: Path) -> dict[str, Path]:
    canonical = {
        "metadata": {
            "version_esquema": "1.0.0-p07-normalized",
        },
        "registros": [
            {
                "identificador": "LEX-0001",
                "palabra_puinave": "AMDA",
                "traduccion_espanol": "ejemplo",
                "origen": {
                    "archivo": "RLB.xlsx",
                    "hoja": "Diccionario",
                    "fila": 2,
                },
            },
            {
                "identificador": None,
                "palabra_puinave": "BETA",
                "traduccion_espanol": "segundo",
                "origen": {
                    "archivo": "RLB.xlsx",
                    "hoja": "Diccionario",
                    "fila": 3,
                },
            },
        ],
    }

    profile = {
        "total_registros": 2,
        "total_registros_validos": 2,
        "total_registros_con_errores": 0,
    }

    errors = {
        "metadata": {"total": 0},
        "errores": [],
    }

    schema = {
        "version": "1.1.0",
        "fields": [{"name": "palabra_puinave"}],
    }

    return {
        "canonical": _write(
            tmp_path / "canonical.json",
            canonical,
        ),
        "profile": _write(
            tmp_path / "profile.json",
            profile,
        ),
        "errors": _write(
            tmp_path / "errors.json",
            errors,
        ),
        "schema": _write(
            tmp_path / "schema.json",
            schema,
        ),
    }


def test_SPT_001B_P08_consolida_linea_base(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    assert result.total_records == 2
    assert result.duplicate_canonical_ids == 0
    assert result.repository_path.is_file()
    assert result.statistics_path.is_file()
    assert result.validation_path.is_file()
    assert result.manifest_path.is_file()


def test_SPT_001B_P08_genera_id_deterministico(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    first = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "first",
    )
    second = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "second",
    )

    data_first = json.loads(
        first.repository_path.read_text(encoding="utf-8")
    )
    data_second = json.loads(
        second.repository_path.read_text(encoding="utf-8")
    )

    id_first = data_first["registros"][1]["canonical_id"]
    id_second = data_second["registros"][1]["canonical_id"]

    assert id_first == id_second
    assert id_first.startswith("RLB-")


def test_SPT_001B_P08_rechaza_errores_residuales(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    _write(
        paths["errors"],
        {
            "metadata": {"total": 1},
            "errores": [{"fila": 2}],
        },
    )

    try:
        consolidar_repositorio(
            canonical_input=paths["canonical"],
            profile_input=paths["profile"],
            errors_input=paths["errors"],
            schema_input=paths["schema"],
            output_dir=tmp_path / "output",
        )
    except ValueError as error:
        assert "errores residuales" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un repositorio con errores."
        )


def test_SPT_001B_P08_manifiesto_contiene_hashes(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    manifest = json.loads(
        result.manifest_path.read_text(encoding="utf-8")
    )

    assert manifest["release"] == "SPT-001B-v1.0.0"
    assert manifest["artifacts"]

    for item in manifest["artifacts"]:
        assert len(item["sha256"]) == 64
        int(item["sha256"], 16)
        assert item["size_bytes"] > 0


def test_SPT_001B_P08_validacion_final_aprobada(
    tmp_path: Path,
) -> None:
    paths = _inputs(tmp_path)

    result = consolidar_repositorio(
        canonical_input=paths["canonical"],
        profile_input=paths["profile"],
        errors_input=paths["errors"],
        schema_input=paths["schema"],
        output_dir=tmp_path / "output",
    )

    validation = json.loads(
        result.validation_path.read_text(encoding="utf-8")
    )

    assert validation["passed"] is True
    assert all(validation["checks"].values())
'@

$ComponentConfig = @'
{
  "increment_code": "SPT-001B-P08",
  "parent_deliverable": "SPT-001B",
  "component_type": "canonical_repository_closure",
  "version": "1.0.0",
  "status": "institutionally_closed",
  "entrypoint": "sgoda.rlb.canonical_consolidator",
  "source": [
    "src/sgoda/rlb/canonical_consolidator.py"
  ],
  "tests": [
    "tests/rlb/test_SPT_001B_P08_canonical_closure.py"
  ],
  "governed_by": "SGD-114"
}
'@

$DocContent = @'
# SPT-001B-P08 — Consolidación del Repositorio Canónico y cierre

## Objetivo

Consolidar la salida validada de P07 como línea base canónica oficial
del Repositorio Léxico Base y completar el cierre institucional de
SPT-001B.

## Controles

- Cero errores residuales.
- Todos los registros válidos.
- Identificadores canónicos presentes y únicos.
- Identificadores determinísticos para registros sin ID de origen.
- Detección de claves léxicas repetidas.
- Preservación de posibles duplicados lingüísticos como advertencias.
- Manifiesto SHA-256 de la línea base.
- Promoción versionada del esquema normalizado.
- Quality gate institucional SGD-114.

## Línea base resultante

- `canonical-repository-v1.0.0.json`
- `canonical-statistics.json`
- `canonical-validation.json`
- `canonical-baseline-manifest.json`
- `config/rlb/schema-v1.1.json`
- `config/rlb/active-schema.json`

El esquema original permanece conservado.
'@

$ClosureActContent = @'
# SPT-001B — Acta de Cierre Institucional

## Entregable

**SPT-001B — Importación, perfilado, normalización y consolidación del
Repositorio Léxico Base.**

## Incrementos integrados

- P01: cargador del esquema.
- P02: modelos de perfil.
- P03: lector institucional.
- P04: prueba integral de lectura.
- P05: exportación JSON.
- P06: pipeline, CLI y evento.
- P07: normalización de encabezados.
- P08: consolidación, línea base y cierre.

## Evidencias de aceptación

- Excel oficial procesado.
- 20 registros válidos.
- 0 errores residuales.
- Suite automatizada completa aprobada.
- Repositorio canónico versionado.
- Manifiesto SHA-256.
- Trazabilidad y dashboard.
- Quality gate SGD-114 del incremento.
- Quality gate SGD-114 de cierre de SPT-001B.

## Decisión

El cierre es válido exclusivamente cuando:

`artifacts/pmo/SPT-001B/SPT-001B-final-quality-gate.json`

contiene:

- `passed: true`
- `closure_authorized: true`
'@

$HistoryContent = @'
# SPT-001B — Registro Histórico de Cierre

| Incremento | Resultado |
|---|---|
| P01–P03 | Infraestructura de lectura instalada |
| P04 | Primera prueba Excel, 57 pruebas acumuladas |
| P05 | Exportación JSON, 59 pruebas acumuladas |
| SGD-114 | Gobierno de evidencias, 65 pruebas acumuladas |
| P06 | Pipeline real; diagnóstico inicial 0/20 válidos |
| P07 | Normalización; resultado 20/20 válidos |
| P08 | Consolidación canónica y cierre institucional |

La evolución preserva todos los hallazgos y correctivos como evidencia
histórica del proyecto.
'@

$InvokeContent = @'
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

python -m sgoda.rlb.canonical_consolidator `
    --canonical "artifacts/rlb/SPT-001B-P07/reprocessed/palabras-canonicas.json" `
    --profile "artifacts/rlb/SPT-001B-P07/reprocessed/perfil-rlb.json" `
    --errors "artifacts/rlb/SPT-001B-P07/reprocessed/errores-importacion.json" `
    --schema "artifacts/rlb/SPT-001B-P07/schema-p07-normalized.json" `
    --output "artifacts/rlb/SPT-001B-P08"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-001B-P08 terminó con errores."
}
'@

Write-Step "Instalando componentes P08"

Write-Utf8NoBom -Path $ConsolidatorPath -Content $ConsolidatorContent
Write-Utf8NoBom -Path $TestPath -Content $TestContent
Write-Utf8NoBom -Path $ComponentPath -Content $ComponentConfig
Write-Utf8NoBom -Path $DocPath -Content $DocContent
Write-Utf8NoBom -Path $ClosureActPath -Content $ClosureActContent
Write-Utf8NoBom -Path $HistoryPath -Content $HistoryContent
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent

Write-Step "Promoviendo esquema normalizado"

$NormalizedSchema = Get-Content `
    -LiteralPath (Join-Path $P07Dir "schema-p07-normalized.json") `
    -Raw |
    ConvertFrom-Json

$NormalizedSchema.version = "1.1.0"
$NormalizedSchema | Add-Member `
    -NotePropertyName promoted_by `
    -NotePropertyValue "SPT-001B-P08" `
    -Force
$NormalizedSchema | Add-Member `
    -NotePropertyName promoted_at_utc `
    -NotePropertyValue ([DateTime]::UtcNow.ToString("o")) `
    -Force

Write-JsonUtf8 -Path $PromotedSchemaPath -Data $NormalizedSchema

$ActiveSchema = [ordered]@{
    active_schema = "config/rlb/schema-v1.1.json"
    version = "1.1.0"
    previous_schema = "config/rlb/schema-v1.json"
    activated_by = "SPT-001B-P08"
    activated_at_utc = [DateTime]::UtcNow.ToString("o")
}
Write-JsonUtf8 -Path $ActiveSchemaPath -Data $ActiveSchema

Write-Step "Generando evidencias iniciales"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Manifest = [ordered]@{
    increment_code = "SPT-001B-P08"
    parent_deliverable = "SPT-001B"
    version = "1.0.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    components = @(
        "src/sgoda/rlb/canonical_consolidator.py",
        "tests/rlb/test_SPT_001B_P08_canonical_closure.py",
        "config/rlb/SPT-001B-P08-component.json",
        "config/rlb/schema-v1.1.json",
        "config/rlb/active-schema.json",
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P08-Consolidacion-Cierre.md",
        "docs/01_Gobierno/SPT-001B-Acta-Cierre-Institucional.md"
    )
}
Write-JsonUtf8 -Path $ManifestPath -Data $Manifest

$Trace = [ordered]@{
    increment_code = "SPT-001B-P08"
    parent_deliverable = "SPT-001B"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/rlb/canonical_consolidator.py",
        "config/rlb/SPT-001B-P08-component.json",
        "config/rlb/schema-v1.1.json"
    )
    tests = @(
        "tests/rlb/test_SPT_001B_P08_canonical_closure.py"
    )
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P08-Consolidacion-Cierre.md",
        "docs/01_Gobierno/SPT-001B-Acta-Cierre-Institucional.md",
        "docs/15_Historial/SPT-001B-Registro-Historico-Cierre.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-001B-P08/implementation-evidence.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Validando importación"

& python -c "from sgoda.rlb.canonical_consolidator import consolidar_repositorio; print(consolidar_repositorio.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de P08."
}

Write-Step "Ejecutando pruebas específicas P08"

& python -m pytest `
    "tests/rlb/test_SPT_001B_P08_canonical_closure.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas P08 terminaron con errores."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Consolidando repositorio canónico real"

& python -m sgoda.rlb.canonical_consolidator `
    --canonical "artifacts/rlb/SPT-001B-P07/reprocessed/palabras-canonicas.json" `
    --profile "artifacts/rlb/SPT-001B-P07/reprocessed/perfil-rlb.json" `
    --errors "artifacts/rlb/SPT-001B-P07/reprocessed/errores-importacion.json" `
    --schema "config/rlb/schema-v1.1.json" `
    --output "artifacts/rlb/SPT-001B-P08"

if ($LASTEXITCODE -ne 0) {
    throw "Falló la consolidación canónica real."
}

foreach ($Artifact in @(
    "canonical-repository-v1.0.0.json",
    "canonical-statistics.json",
    "canonical-validation.json",
    "canonical-baseline-manifest.json"
)) {
    Assert-Path `
        -Path (Join-Path $ArtifactsDir $Artifact) `
        -Description $Artifact
}

$Statistics = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-statistics.json") `
    -Raw |
    ConvertFrom-Json

$Validation = Get-Content `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-validation.json") `
    -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación canónica real no fue aprobada."
}

if ([int]$Statistics.duplicate_canonical_ids -ne 0) {
    throw "Existen identificadores canónicos duplicados."
}

Write-Step "Publicando release institucional"

if (-not (Test-Path -LiteralPath $ReleaseDir)) {
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null
}

Copy-Item `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-repository-v1.0.0.json") `
    -Destination (Join-Path $ReleaseDir "canonical-repository-v1.0.0.json") `
    -Force

Copy-Item `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-statistics.json") `
    -Destination (Join-Path $ReleaseDir "canonical-statistics.json") `
    -Force

Copy-Item `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-validation.json") `
    -Destination (Join-Path $ReleaseDir "canonical-validation.json") `
    -Force

Copy-Item `
    -LiteralPath (Join-Path $ArtifactsDir "canonical-baseline-manifest.json") `
    -Destination (Join-Path $ReleaseDir "canonical-baseline-manifest.json") `
    -Force

Copy-Item `
    -LiteralPath $PromotedSchemaPath `
    -Destination (Join-Path $ReleaseDir "schema-v1.1.json") `
    -Force

$Trace.evidence = @(
    "artifacts/pmo/SPT-001B-P08/implementation-evidence.json",
    "artifacts/rlb/SPT-001B-P08/canonical-repository-v1.0.0.json",
    "artifacts/rlb/SPT-001B-P08/canonical-statistics.json",
    "artifacts/rlb/SPT-001B-P08/canonical-validation.json",
    "artifacts/rlb/SPT-001B-P08/canonical-baseline-manifest.json",
    "releases/SPT-001B-v1.0.0/"
)
Write-JsonUtf8 -Path $TracePath -Data $Trace

Write-Step "Ejecutando quality gate P08"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P08" `
    --status "institutionally_closed" `
    --output "$GateP08Path"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $GateP08Path -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Quality gate P08 no aprobado. Faltan: $Missing"
}

$GateP08 = Get-Content -LiteralPath $GateP08Path -Raw |
    ConvertFrom-Json

if (-not $GateP08.passed -or -not $GateP08.closure_authorized) {
    throw "P08 no obtuvo autorización de cierre."
}

Write-Step "Ejecutando cierre institucional de SPT-001B"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B" `
    --status "institutionally_closed" `
    --output "$ClosureGatePath"

if ($LASTEXITCODE -ne 0) {
    $Failure = Get-Content -LiteralPath $ClosureGatePath -Raw |
        ConvertFrom-Json
    $Missing = $Failure.missing_categories -join ", "
    throw "Cierre SPT-001B no aprobado. Faltan: $Missing"
}

$ClosureGate = Get-Content `
    -LiteralPath $ClosureGatePath `
    -Raw |
    ConvertFrom-Json

if (-not $ClosureGate.passed) {
    throw "El cierre SPT-001B no tiene passed=true."
}

if (-not $ClosureGate.closure_authorized) {
    throw "SGD-114 no autorizó el cierre de SPT-001B."
}

$Dashboard = [ordered]@{
    deliverable = "SPT-001B"
    release = "SPT-001B-v1.0.0"
    status = "institutionally_closed"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    total_records = $Statistics.total_records
    valid_records = $Statistics.valid_records
    invalid_records = $Statistics.invalid_records
    quality_percentage = $Statistics.quality_percentage
    unique_canonical_ids = $Statistics.unique_canonical_ids
    duplicate_canonical_ids = $Statistics.duplicate_canonical_ids
    duplicate_lexical_keys = $Statistics.duplicate_lexical_keys
    schema_version = "1.1.0"
    specific_tests = "approved"
    full_suite = "approved"
    p08_quality_gate = "authorized"
    SPT_001B_closure_gate = "authorized"
    next_phase = "SPT-002"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SPT-001B-P08 implementado y cerrado." -ForegroundColor Green
Write-Host "SPT-001B: CERRADO INSTITUCIONALMENTE." -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 5 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 73: 78 pruebas." -ForegroundColor Cyan
Write-Host "Registros canónicos: $($Statistics.total_records)" -ForegroundColor Cyan
Write-Host "Calidad: $($Statistics.quality_percentage)%" -ForegroundColor Green
Write-Host "IDs canónicos duplicados: $($Statistics.duplicate_canonical_ids)" -ForegroundColor Green
Write-Host "Claves léxicas repetidas: $($Statistics.duplicate_lexical_keys)" -ForegroundColor Yellow
Write-Host "Esquema activo: config\rlb\schema-v1.1.json" -ForegroundColor Cyan
Write-Host "Release: releases\SPT-001B-v1.0.0" -ForegroundColor Cyan
Write-Host "Cierre: $ClosureGatePath" -ForegroundColor Green
