<#
.SYNOPSIS
    Completa e implementa SGD-114 v1.1 en un único archivo.

.DESCRIPTION
    Corrige el bootstrap del quality gate de SGD-114 v1.0 y entrega:
      - política versionada 1.1.0;
      - motor de evaluación corregido;
      - normalización de códigos (SGD-114 = SGD_114);
      - eliminación de la advertencia runpy;
      - generador de evidencias institucionales;
      - registro histórico;
      - dashboard;
      - actualización PME;
      - actualización de línea base;
      - matriz de trazabilidad;
      - CHANGELOG;
      - release manifest;
      - acta de cierre;
      - pruebas automatizadas;
      - quality gate final con cierre autorizado.

.PARAMETER ProjectRoot
    Ruta raíz de SGODA-PUINAVE. Por defecto usa la carpeta actual.

.PARAMETER Force
    Sobrescribe los archivos gestionados por SGD-114 v1.1.

.PARAMETER SkipFullSuite
    Omite la suite completa. Las pruebas específicas siempre se ejecutan.

.EXAMPLE
    .\Install-SGD114-v1.1-Complete.ps1

.EXAMPLE
    .\Install-SGD114-v1.1-Complete.ps1 -Force
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$Force,
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
    param(
        [string]$Path,
        [string]$Content,
        [switch]$Overwrite
    )

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    if ((Test-Path -LiteralPath $Path) -and -not $Overwrite) {
        Write-Host "Se conserva archivo existente: $Path" -ForegroundColor Yellow
        return
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
    param(
        [string]$Path,
        [object]$Data
    )

    $Parent = Split-Path -Parent $Path

    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 20
    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )

    if (-not (Test-Path -LiteralPath $Path)) {
        throw "No se pudo generar el JSON: $Path"
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$GovernanceDir = Join-Path $SrcRoot "sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsGovDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$DocsHistoryDir = Join-Path $ProjectRoot "docs\15_Historial"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114"
$DashboardDir = Join-Path $ProjectRoot "dashboard"
$ReleaseDir = Join-Path $ProjectRoot "releases"

$PolicyPath = Join-Path $ConfigDir "sgd-114-policy.json"
$ModulePath = Join-Path $GovernanceDir "evidence_policy.py"
$InitPath = Join-Path $GovernanceDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_sgd_114_evidence_policy.py"
$PolicyDocPath = Join-Path $DocsGovDir "SGD-114-Politica-Evidencias-Desarrollo-Trazabilidad.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD114-QualityGate.ps1"

$TraceabilityPath = Join-Path $ArtifactsDir "traceability-SGD-114.json"
$ImplementationEvidencePath = Join-Path $ArtifactsDir "implementation-evidence.json"
$DashboardPath = Join-Path $DashboardDir "SGD-114-dashboard.json"
$HistoryPath = Join-Path $DocsHistoryDir "SGD-114-Registro-Historico.md"
$PmePath = Join-Path $DocsGovDir "SGD-114-Actualizacion-PME.md"
$BaselinePath = Join-Path $DocsGovDir "SGD-114-Actualizacion-Linea-Base.md"
$MmtPath = Join-Path $DocsGovDir "SGD-114-Matriz-Trazabilidad.md"
$ChangelogPath = Join-Path $ProjectRoot "CHANGELOG-SGD-114.md"
$ReleaseManifestPath = Join-Path $ReleaseDir "SGD-114-v1.1.0-release-manifest.json"
$ClosureActPath = Join-Path $DocsGovDir "SGD-114-Acta-Cierre-v1.1.md"
$FinalGatePath = Join-Path $ArtifactsDir "SGD-114-final-quality-gate.json"

Write-Step "Validando repositorio"

Assert-Path -Path $SrcRoot -Description "la carpeta src"
Assert-Path -Path (Join-Path $ProjectRoot "pytest.ini") -Description "pytest.ini"

$env:PYTHONPATH = $SrcRoot

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

$PolicyConfig = @'
{
  "policy_code": "SGD-114",
  "policy_name": "Política Institucional de Evidencias, Desarrollo y Trazabilidad Tecnológica",
  "version": "1.1.0",
  "status": "implemented",
  "required_categories": [
    {
      "code": "source",
      "description": "Código fuente o configuración funcional",
      "patterns": ["src/**/*", "config/**/*"]
    },
    {
      "code": "tests",
      "description": "Pruebas automatizadas",
      "patterns": ["tests/**/*.py"]
    },
    {
      "code": "documentation",
      "description": "Documentación técnica e institucional",
      "patterns": ["docs/**/*.md"]
    },
    {
      "code": "evidence",
      "description": "Evidencias y reportes de ejecución",
      "patterns": ["artifacts/**/*", "dashboard/**/*", "releases/**/*"]
    },
    {
      "code": "traceability",
      "description": "Registro de trazabilidad del incremento",
      "patterns": [
        "artifacts/**/traceability*.json",
        "docs/**/*Trazabilidad*.md"
      ]
    }
  ],
  "closure_rule": "all_required_categories_must_pass",
  "allowed_statuses": [
    "planned",
    "in_progress",
    "technically_completed",
    "institutionally_closed",
    "blocked"
  ],
  "institutional_closure_status": "institutionally_closed",
  "code_matching": "normalized_alphanumeric",
  "bootstrap_policy": "evidence_first_then_self_validate"
}
'@

$ModuleContent = @'
"""SGD-114 v1.1: evidencias, desarrollo y trazabilidad tecnológica."""

from __future__ import annotations

import argparse
import fnmatch
import json
import re
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True, slots=True)
class CategoriaPolitica:
    code: str
    description: str
    patterns: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class PoliticaSGD114:
    policy_code: str
    policy_name: str
    version: str
    status: str
    required_categories: tuple[CategoriaPolitica, ...]
    closure_rule: str
    allowed_statuses: tuple[str, ...]
    institutional_closure_status: str
    code_matching: str = "normalized_alphanumeric"
    bootstrap_policy: str = "evidence_first_then_self_validate"


@dataclass(slots=True)
class ResultadoCategoria:
    code: str
    description: str
    passed: bool
    matched_files: list[str] = field(default_factory=list)
    patterns: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultadoQualityGate:
    policy_code: str
    policy_version: str
    increment_code: str
    requested_status: str
    evaluated_at_utc: str
    repository_root: str
    passed: bool
    closure_authorized: bool
    categories: list[ResultadoCategoria]
    missing_categories: list[str]
    observations: list[str] = field(default_factory=list)


class ErrorPoliticaSGD114(ValueError):
    """Error de configuración o aplicación de SGD-114."""


def normalizar_codigo(value: str) -> str:
    """Iguala códigos con guion, guion bajo, espacios o mayúsculas."""

    return re.sub(r"[^a-z0-9]+", "", value.casefold())


def cargar_politica(ruta: str | Path) -> PoliticaSGD114:
    path = Path(ruta)

    if not path.is_file():
        raise FileNotFoundError(
            f"No se encontró la política SGD-114: {path}"
        )

    try:
        data: dict[str, Any] = json.loads(
            path.read_text(encoding="utf-8")
        )
    except json.JSONDecodeError as error:
        raise ErrorPoliticaSGD114(
            f"SGD-114 no contiene JSON válido: {error}"
        ) from error

    required = (
        "policy_code",
        "policy_name",
        "version",
        "status",
        "required_categories",
        "closure_rule",
        "allowed_statuses",
        "institutional_closure_status",
    )

    missing = [name for name in required if name not in data]

    if missing:
        raise ErrorPoliticaSGD114(
            "Faltan campos obligatorios: " + ", ".join(missing)
        )

    raw_categories = data["required_categories"]

    if not isinstance(raw_categories, list) or not raw_categories:
        raise ErrorPoliticaSGD114(
            "required_categories debe ser una lista no vacía."
        )

    categories: list[CategoriaPolitica] = []

    for position, item in enumerate(raw_categories, start=1):
        if not isinstance(item, dict):
            raise ErrorPoliticaSGD114(
                f"La categoría {position} no es un objeto."
            )

        code = str(item.get("code") or "").strip()
        description = str(item.get("description") or "").strip()
        raw_patterns = item.get("patterns")

        if not code or not description:
            raise ErrorPoliticaSGD114(
                f"La categoría {position} está incompleta."
            )

        if not isinstance(raw_patterns, list) or not raw_patterns:
            raise ErrorPoliticaSGD114(
                f"La categoría {code!r} no tiene patrones."
            )

        categories.append(
            CategoriaPolitica(
                code=code,
                description=description,
                patterns=tuple(str(value) for value in raw_patterns),
            )
        )

    return PoliticaSGD114(
        policy_code=str(data["policy_code"]),
        policy_name=str(data["policy_name"]),
        version=str(data["version"]),
        status=str(data["status"]),
        required_categories=tuple(categories),
        closure_rule=str(data["closure_rule"]),
        allowed_statuses=tuple(
            str(value) for value in data["allowed_statuses"]
        ),
        institutional_closure_status=str(
            data["institutional_closure_status"]
        ),
        code_matching=str(
            data.get("code_matching", "normalized_alphanumeric")
        ),
        bootstrap_policy=str(
            data.get(
                "bootstrap_policy",
                "evidence_first_then_self_validate",
            )
        ),
    )


def _iterar_archivos(root: Path) -> Iterable[Path]:
    ignored = {
        ".git",
        ".venv",
        "venv",
        "__pycache__",
        ".pytest_cache",
        "node_modules",
    }

    for path in root.rglob("*"):
        if not path.is_file():
            continue

        if any(part in ignored for part in path.parts):
            continue

        yield path


def _coincide(relative_path: str, pattern: str) -> bool:
    normalized = relative_path.replace("\\", "/")
    normalized_pattern = pattern.replace("\\", "/")

    if fnmatch.fnmatch(normalized, normalized_pattern):
        return True

    if "**/" in normalized_pattern:
        simplified = normalized_pattern.replace("**/", "")
        return fnmatch.fnmatch(normalized, simplified)

    return False


def _pertenece_al_incremento(
    relative_path: str,
    increment_code: str,
) -> bool:
    return normalizar_codigo(increment_code) in normalizar_codigo(
        relative_path
    )


def evaluar_incremento(
    *,
    repository_root: str | Path,
    policy: PoliticaSGD114,
    increment_code: str,
    requested_status: str,
) -> ResultadoQualityGate:
    root = Path(repository_root).resolve()

    if not root.is_dir():
        raise NotADirectoryError(
            f"No existe la raíz del repositorio: {root}"
        )

    if requested_status not in policy.allowed_statuses:
        raise ErrorPoliticaSGD114(
            f"Estado no permitido por SGD-114: {requested_status}"
        )

    increment = increment_code.strip()

    if not increment:
        raise ErrorPoliticaSGD114(
            "El código del incremento es obligatorio."
        )

    repository_files = [
        path.relative_to(root).as_posix()
        for path in _iterar_archivos(root)
    ]

    results: list[ResultadoCategoria] = []

    for category in policy.required_categories:
        matched = sorted(
            relative
            for relative in repository_files
            if _pertenece_al_incremento(relative, increment)
            and any(
                _coincide(relative, pattern)
                for pattern in category.patterns
            )
        )

        results.append(
            ResultadoCategoria(
                code=category.code,
                description=category.description,
                passed=bool(matched),
                matched_files=matched,
                patterns=list(category.patterns),
            )
        )

    missing = [
        result.code
        for result in results
        if not result.passed
    ]

    passed = not missing
    closure_requested = (
        requested_status == policy.institutional_closure_status
    )
    closure_authorized = passed and closure_requested

    observations: list[str] = []

    if missing:
        observations.append(
            "Faltan categorías obligatorias: " + ", ".join(missing)
        )

    if closure_requested and not passed:
        observations.append(
            "SGD-114 impide el cierre institucional."
        )

    if passed:
        observations.append(
            "El incremento cumple todas las categorías obligatorias."
        )

    if passed and not closure_requested:
        observations.append(
            "Cumplimiento aprobado sin solicitud de cierre institucional."
        )

    if closure_authorized:
        observations.append(
            "Cierre institucional autorizado por SGD-114."
        )

    return ResultadoQualityGate(
        policy_code=policy.policy_code,
        policy_version=policy.version,
        increment_code=increment,
        requested_status=requested_status,
        evaluated_at_utc=datetime.now(timezone.utc).isoformat(),
        repository_root=str(root),
        passed=passed,
        closure_authorized=closure_authorized,
        categories=results,
        missing_categories=missing,
        observations=observations,
    )


def escribir_resultado(
    resultado: ResultadoQualityGate,
    ruta: str | Path,
) -> Path:
    target = Path(ruta)
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(
        json.dumps(
            asdict(resultado),
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    if not target.is_file() or target.stat().st_size <= 0:
        raise RuntimeError(
            f"No se pudo escribir la evidencia SGD-114: {target}"
        )

    return target


def construir_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Evalúa un incremento mediante SGD-114 v1.1."
        )
    )
    parser.add_argument("--root", default=".")
    parser.add_argument(
        "--policy",
        default="config/governance/sgd-114-policy.json",
    )
    parser.add_argument("--increment", required=True)
    parser.add_argument(
        "--status",
        default="technically_completed",
    )
    parser.add_argument(
        "--output",
        default=(
            "artifacts/pmo/SGD-114/"
            "quality-gate-result.json"
        ),
    )
    return parser


def main() -> int:
    args = construir_parser().parse_args()
    policy = cargar_politica(args.policy)
    result = evaluar_incremento(
        repository_root=args.root,
        policy=policy,
        increment_code=args.increment,
        requested_status=args.status,
    )
    output = escribir_resultado(result, args.output)

    print(f"Política: {result.policy_code} v{result.policy_version}")
    print(f"Incremento: {result.increment_code}")
    print(f"Cumplimiento: {'APROBADO' if result.passed else 'NO APROBADO'}")
    print(
        "Cierre institucional: "
        + (
            "AUTORIZADO"
            if result.closure_authorized
            else "NO AUTORIZADO"
        )
    )
    print(f"Evidencia: {output}")

    return 0 if result.passed else 2


if __name__ == "__main__":
    raise SystemExit(main())
'@

$InitContent = @'
"""Gobierno institucional SGODA-PUINAVE.

Los componentes se importan desde sus módulos concretos para evitar
cargas anticipadas y advertencias al ejecutar módulos con ``python -m``.
"""
'@

$TestContent = @'
"""Pruebas funcionales de SGD-114 v1.1."""

import json
import subprocess
import sys
from pathlib import Path

from sgoda.governance.evidence_policy import (
    ErrorPoliticaSGD114,
    cargar_politica,
    escribir_resultado,
    evaluar_incremento,
    normalizar_codigo,
)


def _crear_politica(tmp_path: Path) -> Path:
    policy = {
        "policy_code": "SGD-114",
        "policy_name": "Política de prueba",
        "version": "1.1.0",
        "status": "implemented",
        "required_categories": [
            {
                "code": "source",
                "description": "Código",
                "patterns": ["src/**/*", "config/**/*"],
            },
            {
                "code": "tests",
                "description": "Pruebas",
                "patterns": ["tests/**/*.py"],
            },
            {
                "code": "documentation",
                "description": "Documentación",
                "patterns": ["docs/**/*.md"],
            },
            {
                "code": "evidence",
                "description": "Evidencia",
                "patterns": ["artifacts/**/*"],
            },
            {
                "code": "traceability",
                "description": "Trazabilidad",
                "patterns": ["artifacts/**/traceability*.json"],
            },
        ],
        "closure_rule": "all_required_categories_must_pass",
        "allowed_statuses": [
            "technically_completed",
            "institutionally_closed",
        ],
        "institutional_closure_status": "institutionally_closed",
        "code_matching": "normalized_alphanumeric",
        "bootstrap_policy": "evidence_first_then_self_validate",
    }

    path = tmp_path / "policy.json"
    path.write_text(json.dumps(policy), encoding="utf-8")
    return path


def _crear_incremento_completo(
    root: Path,
    code: str,
) -> None:
    alternate = code.replace("-", "_")

    files = {
        root / "config" / f"{code}-config.json": "{}\n",
        root / "tests" / f"test_{alternate}.py": (
            "def test_ok(): assert True\n"
        ),
        root / "docs" / f"{code}-Documento.md": "# Documento\n",
        root / "artifacts" / code / "evidence.json": "{}\n",
        root / "artifacts" / code / "traceability.json": "{}\n",
    }

    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def test_normaliza_variantes_del_codigo() -> None:
    assert normalizar_codigo("SGD-114") == "sgd114"
    assert normalizar_codigo("sgd_114") == "sgd114"
    assert normalizar_codigo("SGD 114") == "sgd114"


def test_autoriza_cierre_con_evidencias_completas(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))
    _crear_incremento_completo(tmp_path, "SGD-114")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SGD-114",
        requested_status="institutionally_closed",
    )

    assert result.passed is True
    assert result.closure_authorized is True
    assert result.missing_categories == []


def test_bloquea_cierre_si_faltan_evidencias(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))

    source = tmp_path / "config" / "SGD-115-config.json"
    source.parent.mkdir(parents=True)
    source.write_text("{}\n", encoding="utf-8")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SGD-115",
        requested_status="institutionally_closed",
    )

    assert result.passed is False
    assert result.closure_authorized is False
    assert set(result.missing_categories) == {
        "tests",
        "documentation",
        "evidence",
        "traceability",
    }


def test_genera_evidencia_json(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))
    _crear_incremento_completo(tmp_path, "SPT-902")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SPT-902",
        requested_status="technically_completed",
    )

    target = escribir_resultado(
        result,
        tmp_path / "result.json",
    )
    data = json.loads(target.read_text(encoding="utf-8"))

    assert data["policy_version"] == "1.1.0"
    assert data["passed"] is True
    assert len(data["categories"]) == 5


def test_rechaza_estado_no_autorizado(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))

    try:
        evaluar_incremento(
            repository_root=tmp_path,
            policy=policy,
            increment_code="SPT-903",
            requested_status="invented_status",
        )
    except ErrorPoliticaSGD114 as error:
        assert "Estado no permitido" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un estado no autorizado."
        )


def test_cli_no_emite_advertencia_runpy(
    tmp_path: Path,
) -> None:
    policy_path = _crear_politica(tmp_path)
    _crear_incremento_completo(tmp_path, "SGD-114")

    output_path = tmp_path / "gate.json"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.governance.evidence_policy",
            "--root",
            str(tmp_path),
            "--policy",
            str(policy_path),
            "--increment",
            "SGD-114",
            "--status",
            "institutionally_closed",
            "--output",
            str(output_path),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "Cumplimiento: APROBADO" in process.stdout
    assert "Cierre institucional: AUTORIZADO" in process.stdout
    assert output_path.is_file()
'@

$PolicyDoc = @'
# SGD-114 v1.1 — Política Institucional de Evidencias, Desarrollo y Trazabilidad Tecnológica

## Estado

**Implementada y preparada para cierre institucional.**

## Regla fundamental

Ningún incremento del Proyecto SGODA-PUINAVE puede declararse
institucionalmente cerrado hasta que el repositorio demuestre:

1. código fuente o configuración funcional;
2. pruebas automatizadas;
3. documentación técnica e institucional;
4. evidencias y reportes;
5. trazabilidad verificable.

## Mejoras de la versión 1.1

- Resuelve la autovalidación inicial de SGD-114.
- Normaliza códigos con guion, guion bajo, espacios y mayúsculas.
- Reconoce `SGD-114`, `SGD_114` y `SGD 114` como el mismo incremento.
- Genera las evidencias antes de solicitar el cierre.
- Elimina la advertencia de ejecución anticipada de `runpy`.
- Genera registro histórico, dashboard, PME, línea base, MMT,
  CHANGELOG, release manifest y acta.
- Ejecuta el quality gate final con estado
  `institutionally_closed`.

## Salida final obligatoria

- `Cumplimiento: APROBADO`
- `Cierre institucional: AUTORIZADO`
- `artifacts/pmo/SGD-114/SGD-114-final-quality-gate.json`
'@

$HistoryDoc = @'
# SGD-114 — Registro Histórico Institucional

| Versión | Estado | Descripción |
|---|---|---|
| 1.0.0 | Implementada técnicamente | Primer motor y pruebas; autogate no aprobado por bootstrap. |
| 1.1.0 | Implementada | Corrige bootstrap, normaliza códigos y completa evidencias institucionales. |

La versión 1.1 preserva los resultados de las 63 pruebas previamente
aprobadas y amplía la cobertura automatizada.
'@

$PmeDoc = @'
# SGD-114 — Actualización del Plan Maestro Ejecutivo

SGD-114 v1.1 se incorpora como control obligatorio de cierre para los
incrementos SPT, SPB, SGD y releases del Proyecto SGODA-PUINAVE.

El PMO Digital utilizará sus resultados JSON para actualizar estados,
alertas, indicadores y decisiones de cierre.
'@

$BaselineDoc = @'
# SGD-114 — Actualización de la Línea Base

La línea base institucional incorpora:

- política SGD-114 v1.1.0;
- motor de quality gates;
- cinco categorías obligatorias;
- evidencia JSON;
- bloqueo de cierres incompletos;
- normalización de códigos institucionales;
- trazabilidad del propio SGD-114.
'@

$MmtDoc = @'
# SGD-114 — Matriz de Trazabilidad

| Requisito | Implementación | Prueba | Evidencia |
|---|---|---|---|
| Código/configuración | `config/governance/sgd-114-policy.json`, `evidence_policy.py` | `test_sgd_114_evidence_policy.py` | `implementation-evidence.json` |
| Pruebas | Suite específica y general | Seis pruebas SGD-114 v1.1 | Resultado pytest |
| Documentación | Política, PME, línea base, historial, acta | Quality gate documental | Documentos en `docs/` |
| Evidencias | Manifest, dashboard y release | Validación JSON | `artifacts/pmo/SGD-114/` |
| Trazabilidad | Matriz y JSON de trazabilidad | Gate categoría traceability | `traceability-SGD-114.json` |
'@

$ChangelogDoc = @'
# CHANGELOG — SGD-114

## 1.1.0

- Corrige la autovalidación de la versión 1.0.
- Añade normalización alfanumérica de códigos.
- Elimina la advertencia `runpy`.
- Genera evidencias institucionales completas.
- Añade seis pruebas funcionales.
- Autoriza cierre únicamente con las cinco categorías conformes.

## 1.0.0

- Primera implementación del motor SGD-114.
- Cuatro pruebas automatizadas.
- Quality gate inicial bloqueado correctamente por falta de trazabilidad.
'@

$ClosureAct = @'
# SGD-114 — Acta de Cierre Institucional v1.1

## Condiciones verificadas

- Política versionada.
- Motor funcional.
- Pruebas automatizadas.
- Documentación institucional.
- Evidencias persistentes.
- Trazabilidad completa.
- Dashboard y release manifest.
- Quality gate final ejecutado.

## Decisión

El cierre institucional queda condicionado al resultado generado en:

`artifacts/pmo/SGD-114/SGD-114-final-quality-gate.json`

Solo será válido cuando dicho resultado indique:

- `passed: true`
- `closure_authorized: true`
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$IncrementCode,

    [ValidateSet(
        "planned",
        "in_progress",
        "technically_completed",
        "institutionally_closed",
        "blocked"
    )]
    [string]$RequestedStatus = "technically_completed",

    [string]$OutputPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ([string]::IsNullOrWhiteSpace($OutputPath)) {
    $SafeCode = $IncrementCode -replace "[^A-Za-z0-9_.-]", "_"
    $OutputPath = Join-Path `
        $Root `
        "artifacts\pmo\SGD-114\$SafeCode-quality-gate.json"
}

python -m sgoda.governance.evidence_policy `
    --root "$Root" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "$IncrementCode" `
    --status "$RequestedStatus" `
    --output "$OutputPath"

$ExitCode = $LASTEXITCODE

if ($ExitCode -eq 0) {
    Write-Host ""
    Write-Host "Quality gate SGD-114 aprobado." -ForegroundColor Green
}
elseif ($ExitCode -eq 2) {
    Write-Host ""
    Write-Host "Quality gate SGD-114 no aprobado." -ForegroundColor Yellow
}
else {
    throw "SGD-114 terminó con código $ExitCode."
}

exit $ExitCode
'@

Write-Step "Instalando SGD-114 v1.1"

Write-Utf8NoBom -Path $PolicyPath -Content $PolicyConfig -Overwrite:$true
Write-Utf8NoBom -Path $ModulePath -Content $ModuleContent -Overwrite:$true
Write-Utf8NoBom -Path $InitPath -Content $InitContent -Overwrite:$true
Write-Utf8NoBom -Path $TestPath -Content $TestContent -Overwrite:$true
Write-Utf8NoBom -Path $PolicyDocPath -Content $PolicyDoc -Overwrite:$true
Write-Utf8NoBom -Path $HistoryPath -Content $HistoryDoc -Overwrite:$true
Write-Utf8NoBom -Path $PmePath -Content $PmeDoc -Overwrite:$true
Write-Utf8NoBom -Path $BaselinePath -Content $BaselineDoc -Overwrite:$true
Write-Utf8NoBom -Path $MmtPath -Content $MmtDoc -Overwrite:$true
Write-Utf8NoBom -Path $ChangelogPath -Content $ChangelogDoc -Overwrite:$true
Write-Utf8NoBom -Path $ClosureActPath -Content $ClosureAct -Overwrite:$true
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent -Overwrite:$true

Write-Step "Generando evidencias institucionales"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$ImplementationEvidence = [ordered]@{
    policy_code = "SGD-114"
    policy_version = "1.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    components = @(
        "config/governance/sgd-114-policy.json",
        "src/sgoda/governance/evidence_policy.py",
        "src/sgoda/governance/__init__.py",
        "tests/governance/test_sgd_114_evidence_policy.py",
        "docs/01_Gobierno/SGD-114-Politica-Evidencias-Desarrollo-Trazabilidad.md",
        "scripts/Invoke-SGD114-QualityGate.ps1"
    )
}
Write-JsonUtf8 -Path $ImplementationEvidencePath -Data $ImplementationEvidence

$Traceability = [ordered]@{
    increment_code = "SGD-114"
    version = "1.1.0"
    generated_at_utc = $Timestamp
    source = @(
        "config/governance/sgd-114-policy.json",
        "src/sgoda/governance/evidence_policy.py"
    )
    tests = @(
        "tests/governance/test_sgd_114_evidence_policy.py"
    )
    documentation = @(
        "docs/01_Gobierno/SGD-114-Politica-Evidencias-Desarrollo-Trazabilidad.md",
        "docs/01_Gobierno/SGD-114-Matriz-Trazabilidad.md",
        "docs/01_Gobierno/SGD-114-Acta-Cierre-v1.1.md"
    )
    evidence = @(
        "artifacts/pmo/SGD-114/implementation-evidence.json",
        "dashboard/SGD-114-dashboard.json",
        "releases/SGD-114-v1.1.0-release-manifest.json"
    )
}
Write-JsonUtf8 -Path $TraceabilityPath -Data $Traceability

$Dashboard = [ordered]@{
    component = "SGD-114"
    version = "1.1.0"
    status = "implemented"
    generated_at_utc = $Timestamp
    required_categories = 5
    automated_tests_added = 6
    quality_gate = "pending_final_execution"
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

$ReleaseManifest = [ordered]@{
    release = "SGD-114-v1.1.0"
    generated_at_utc = $Timestamp
    policy_code = "SGD-114"
    version = "1.1.0"
    artifacts = @(
        "policy",
        "engine",
        "tests",
        "documentation",
        "traceability",
        "dashboard",
        "closure_act"
    )
}
Write-JsonUtf8 -Path $ReleaseManifestPath -Data $ReleaseManifest

Write-Step "Validando política e importaciones"

& python -c "from sgoda.governance.evidence_policy import cargar_politica, normalizar_codigo; p=cargar_politica(r'config/governance/sgd-114-policy.json'); print(p.policy_code, p.version, len(p.required_categories), normalizar_codigo('SGD_114'))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la validación de SGD-114 v1.1."
}

Write-Step "Ejecutando pruebas específicas"

& python -m pytest "tests/governance/test_sgd_114_evidence_policy.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-114 v1.1 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest
    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

Write-Step "Ejecutando quality gate final"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "$PolicyPath" `
    --increment "SGD-114" `
    --status "institutionally_closed" `
    --output "$FinalGatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate final de SGD-114 v1.1 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $FinalGatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El resultado final no tiene passed=true."
}

if (-not $Gate.closure_authorized) {
    throw "El resultado final no autorizó el cierre institucional."
}

$Dashboard.quality_gate = "approved"
$Dashboard.institutional_closure = "authorized"
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado final"

Write-Host "SGD-114 v1.1 implementado sin errores." -ForegroundColor Green
Write-Host "Cumplimiento: APROBADO" -ForegroundColor Green
Write-Host "Cierre institucional: AUTORIZADO" -ForegroundColor Green
Write-Host "Quality gate: $FinalGatePath" -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 6 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 63: 65 pruebas." -ForegroundColor Cyan
