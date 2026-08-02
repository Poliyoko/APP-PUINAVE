<#
.SYNOPSIS
    Implementa SGD-114 — Política Institucional de Evidencias,
    Desarrollo y Trazabilidad Tecnológica para SGODA-PUINAVE.

.DESCRIPTION
    El paquete instala:
      - política formal SGD-114;
      - configuración institucional JSON;
      - motor Python de verificación;
      - quality gate por incremento;
      - CLI;
      - script operativo PowerShell;
      - pruebas automatizadas;
      - evidencia inicial;
      - documentación técnica.

    El motor comprueba que un incremento tenga código, pruebas,
    documentación, evidencias y trazabilidad antes de declararlo cerrado.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER Force
    Sobrescribe archivos existentes de SGD-114.

.PARAMETER SkipFullSuite
    Ejecuta las pruebas específicas, pero omite la suite general.

.EXAMPLE
    .\Install-SGD114-Evidence-Traceability-Policy.ps1

.EXAMPLE
    .\Install-SGD114-Evidence-Traceability-Policy.ps1 -Force
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
    param(
        [string]$Path,
        [string]$Description
    )

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
        throw "No se pudo crear el archivo: $Path"
    }

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$GovernanceDir = Join-Path $SrcRoot "sgoda\governance"
$TestsDir = Join-Path $ProjectRoot "tests\governance"
$ConfigDir = Join-Path $ProjectRoot "config\governance"
$DocsDir = Join-Path $ProjectRoot "docs\01_Gobierno"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\pmo\SGD-114"

$ModulePath = Join-Path $GovernanceDir "evidence_policy.py"
$InitPath = Join-Path $GovernanceDir "__init__.py"
$ConfigPath = Join-Path $ConfigDir "sgd-114-policy.json"
$TestPath = Join-Path $TestsDir "test_sgd_114_evidence_policy.py"
$DocPath = Join-Path $DocsDir "SGD-114-Politica-Evidencias-Desarrollo-Trazabilidad.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SGD114-QualityGate.ps1"
$EvidencePath = Join-Path $ArtifactsDir "implementation-evidence.json"

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
  "version": "1.0.0",
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
      "patterns": ["artifacts/**/*"]
    },
    {
      "code": "traceability",
      "description": "Registro de trazabilidad del incremento",
      "patterns": ["artifacts/**/traceability*.json", "docs/**/*Trazabilidad*.md"]
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
  "institutional_closure_status": "institutionally_closed"
}
'@

$ModuleContent = @'
"""SGD-114: política institucional de evidencias y trazabilidad."""

from __future__ import annotations

import argparse
import fnmatch
import json
from dataclasses import asdict, dataclass, field
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable


@dataclass(frozen=True, slots=True)
class CategoriaPolitica:
    """Categoría obligatoria definida por la política."""

    code: str
    description: str
    patterns: tuple[str, ...]


@dataclass(frozen=True, slots=True)
class PoliticaSGD114:
    """Contrato institucional versionado de SGD-114."""

    policy_code: str
    policy_name: str
    version: str
    status: str
    required_categories: tuple[CategoriaPolitica, ...]
    closure_rule: str
    allowed_statuses: tuple[str, ...]
    institutional_closure_status: str


@dataclass(slots=True)
class ResultadoCategoria:
    """Resultado de cumplimiento de una categoría."""

    code: str
    description: str
    passed: bool
    matched_files: list[str] = field(default_factory=list)
    patterns: list[str] = field(default_factory=list)


@dataclass(slots=True)
class ResultadoQualityGate:
    """Resultado integral del quality gate institucional."""

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


def cargar_politica(ruta: str | Path) -> PoliticaSGD114:
    """Carga y valida la configuración institucional SGD-114."""

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

    missing = [
        field_name
        for field_name in required
        if field_name not in data
    ]

    if missing:
        raise ErrorPoliticaSGD114(
            "Faltan campos obligatorios: " + ", ".join(missing)
        )

    categories_raw = data["required_categories"]

    if not isinstance(categories_raw, list) or not categories_raw:
        raise ErrorPoliticaSGD114(
            "required_categories debe ser una lista no vacía."
        )

    categories: list[CategoriaPolitica] = []

    for position, item in enumerate(categories_raw, start=1):
        if not isinstance(item, dict):
            raise ErrorPoliticaSGD114(
                f"La categoría {position} no es un objeto."
            )

        code = str(item.get("code") or "").strip()
        description = str(item.get("description") or "").strip()
        patterns_raw = item.get("patterns")

        if not code or not description:
            raise ErrorPoliticaSGD114(
                f"La categoría {position} está incompleta."
            )

        if not isinstance(patterns_raw, list) or not patterns_raw:
            raise ErrorPoliticaSGD114(
                f"La categoría {code!r} no tiene patrones."
            )

        categories.append(
            CategoriaPolitica(
                code=code,
                description=description,
                patterns=tuple(str(value) for value in patterns_raw),
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
    )


def _iterar_archivos(root: Path) -> Iterable[Path]:
    """Itera archivos del repositorio ignorando áreas no institucionales."""

    ignored_parts = {
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

        if any(part in ignored_parts for part in path.parts):
            continue

        yield path


def _coincide(relative_path: str, pattern: str) -> bool:
    """Evalúa patrones glob de forma portable."""

    normalized = relative_path.replace("\\", "/")
    normalized_pattern = pattern.replace("\\", "/")

    if fnmatch.fnmatch(normalized, normalized_pattern):
        return True

    if "**/" in normalized_pattern:
        simplified = normalized_pattern.replace("**/", "")
        return fnmatch.fnmatch(normalized, simplified)

    return False


def evaluar_incremento(
    *,
    repository_root: str | Path,
    policy: PoliticaSGD114,
    increment_code: str,
    requested_status: str,
) -> ResultadoQualityGate:
    """Evalúa el cumplimiento documental y técnico de un incremento."""

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

    increment_lower = increment.lower()
    results: list[ResultadoCategoria] = []

    for category in policy.required_categories:
        matched = sorted(
            relative
            for relative in repository_files
            if increment_lower in relative.lower()
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
    closure_authorized = passed if closure_requested else False

    observations: list[str] = []

    if missing:
        observations.append(
            "Faltan categorías obligatorias: " + ", ".join(missing)
        )

    if closure_requested and not passed:
        observations.append(
            "SGD-114 impide el cierre institucional del incremento."
        )

    if passed:
        observations.append(
            "El incremento cumple todas las categorías obligatorias."
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
    """Persiste la evidencia del quality gate en JSON UTF-8."""

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
    """Construye la interfaz CLI de SGD-114."""

    parser = argparse.ArgumentParser(
        description=(
            "Evalúa un incremento mediante SGD-114 y genera "
            "evidencia institucional en JSON."
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
    """Ejecuta el quality gate desde la línea de comandos."""

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
"""Gobierno institucional SGODA-PUINAVE."""

from .evidence_policy import (
    CategoriaPolitica,
    ErrorPoliticaSGD114,
    PoliticaSGD114,
    ResultadoCategoria,
    ResultadoQualityGate,
    cargar_politica,
    escribir_resultado,
    evaluar_incremento,
)

__all__ = [
    "CategoriaPolitica",
    "ErrorPoliticaSGD114",
    "PoliticaSGD114",
    "ResultadoCategoria",
    "ResultadoQualityGate",
    "cargar_politica",
    "escribir_resultado",
    "evaluar_incremento",
]
'@

$TestContent = @'
"""Pruebas funcionales de SGD-114."""

import json
from pathlib import Path

from sgoda.governance.evidence_policy import (
    ErrorPoliticaSGD114,
    cargar_politica,
    escribir_resultado,
    evaluar_incremento,
)


def _crear_politica(tmp_path: Path) -> Path:
    policy = {
        "policy_code": "SGD-114",
        "policy_name": "Política de prueba",
        "version": "1.0.0",
        "status": "implemented",
        "required_categories": [
            {
                "code": "source",
                "description": "Código",
                "patterns": ["src/**/*"],
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
    }

    path = tmp_path / "policy.json"
    path.write_text(
        json.dumps(policy),
        encoding="utf-8",
    )
    return path


def _crear_incremento_completo(
    root: Path,
    code: str,
) -> None:
    files = {
        root / "src" / f"{code}-module.py": "VALUE = 1\n",
        root / "tests" / f"test_{code}.py": "def test_ok(): assert True\n",
        root / "docs" / f"{code}-Documento.md": "# Documento\n",
        root / "artifacts" / code / "evidence.json": "{}\n",
        root / "artifacts" / code / "traceability.json": "{}\n",
    }

    for path, content in files.items():
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")


def test_autoriza_cierre_con_evidencias_completas(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))
    _crear_incremento_completo(tmp_path, "SPT-900")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SPT-900",
        requested_status="institutionally_closed",
    )

    assert result.passed is True
    assert result.closure_authorized is True
    assert result.missing_categories == []


def test_bloquea_cierre_si_faltan_evidencias(
    tmp_path: Path,
) -> None:
    policy = cargar_politica(_crear_politica(tmp_path))

    source = tmp_path / "src" / "SPT-901-module.py"
    source.parent.mkdir(parents=True)
    source.write_text("VALUE = 1\n", encoding="utf-8")

    result = evaluar_incremento(
        repository_root=tmp_path,
        policy=policy,
        increment_code="SPT-901",
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


def test_genera_evidencia_json_del_quality_gate(
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

    assert data["policy_code"] == "SGD-114"
    assert data["increment_code"] == "SPT-902"
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
'@

$DocContent = @'
# SGD-114 — Política Institucional de Evidencias, Desarrollo y Trazabilidad Tecnológica

## 1. Identificación

- **Código:** SGD-114
- **Versión:** 1.0.0
- **Clasificación:** Gobierno tecnológico y gestión documental
- **Estado:** Implementada
- **Aplicación:** Obligatoria para SPT, SPB, SGD, componentes y releases

## 2. Propósito

Establecer y automatizar los requisitos mínimos de evidencia que debe
cumplir cualquier incremento del Proyecto SGODA-PUINAVE antes de ser
declarado institucionalmente cerrado.

## 3. Principio rector

> Ningún incremento se considera cerrado hasta que su código,
> pruebas, documentación, evidencias y trazabilidad estén incorporados
> y verificables dentro del repositorio oficial.

## 4. Categorías obligatorias

1. **Código o configuración funcional.**
2. **Pruebas automatizadas.**
3. **Documentación técnica e institucional.**
4. **Evidencias y reportes.**
5. **Trazabilidad del incremento.**

## 5. Estados institucionales

- `planned`
- `in_progress`
- `technically_completed`
- `institutionally_closed`
- `blocked`

La finalización técnica no equivale al cierre institucional.

## 6. Quality gate

El motor `sgoda.governance.evidence_policy` inspecciona el repositorio,
clasifica las evidencias por categoría y genera un resultado JSON.

El cierre institucional solamente se autoriza cuando todas las
categorías obligatorias se encuentran conformes.

## 7. Evidencia generada

Ruta predeterminada:

`artifacts/pmo/SGD-114/quality-gate-result.json`

## 8. Ejecución

```powershell
.\scripts\Invoke-SGD114-QualityGate.ps1 `
    -IncrementCode "SPT-001B" `
    -RequestedStatus "technically_completed"
```

Para solicitar cierre institucional:

```powershell
.\scripts\Invoke-SGD114-QualityGate.ps1 `
    -IncrementCode "SPT-001B" `
    -RequestedStatus "institutionally_closed"
```

## 9. Interpretación

- Código de salida `0`: cumplimiento aprobado.
- Código de salida `2`: incumplimiento de la política.
- Otro código: error técnico o de configuración.

## 10. Integración

SGD-114 se integra progresivamente con:

- PMO Digital Inteligente;
- Dashboard de gobierno;
- RMI;
- MMT;
- Auditor del Repositorio;
- GitHub Actions;
- n8n;
- actas de cierre;
- releases institucionales.

## 11. Criterios de aceptación

- Política versionada en JSON.
- Motor funcional importable.
- CLI ejecutable.
- Quality gate reproducible.
- Evidencia JSON persistente.
- Pruebas automatizadas aprobadas.
- Documentación presente en el repositorio.
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
    throw "La ejecución SGD-114 terminó con código $ExitCode."
}

exit $ExitCode
'@

$InitialEvidence = @'
{
  "policy_code": "SGD-114",
  "policy_version": "1.0.0",
  "implementation_status": "implemented",
  "components": [
    "config/governance/sgd-114-policy.json",
    "src/sgoda/governance/evidence_policy.py",
    "src/sgoda/governance/__init__.py",
    "tests/governance/test_sgd_114_evidence_policy.py",
    "docs/01_Gobierno/SGD-114-Politica-Evidencias-Desarrollo-Trazabilidad.md",
    "scripts/Invoke-SGD114-QualityGate.ps1"
  ],
  "evidence_type": "implementation_manifest",
  "generated_by": "Install-SGD114-Evidence-Traceability-Policy.ps1"
}
'@

Write-Step "Instalando configuración SGD-114"
Write-Utf8NoBom -Path $ConfigPath -Content $PolicyConfig -Overwrite:$Force

Write-Step "Instalando motor funcional"
Write-Utf8NoBom -Path $ModulePath -Content $ModuleContent -Overwrite:$Force
Write-Utf8NoBom -Path $InitPath -Content $InitContent -Overwrite:$Force

Write-Step "Instalando pruebas automatizadas"
Write-Utf8NoBom -Path $TestPath -Content $TestContent -Overwrite:$Force

Write-Step "Instalando documentación institucional"
Write-Utf8NoBom -Path $DocPath -Content $DocContent -Overwrite:$Force

Write-Step "Instalando script operativo"
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent -Overwrite:$Force

Write-Step "Generando evidencia inicial"
Write-Utf8NoBom -Path $EvidencePath -Content $InitialEvidence -Overwrite:$Force

Write-Step "Validando configuración e importaciones"

& python -c "from sgoda.governance.evidence_policy import cargar_politica; p=cargar_politica(r'config/governance/sgd-114-policy.json'); print(p.policy_code, p.version, len(p.required_categories))"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la validación de la política SGD-114."
}

Write-Step "Ejecutando pruebas específicas SGD-114"

& python -m pytest "tests/governance/test_sgd_114_evidence_policy.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-114 terminaron con errores."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest
    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}
else {
    Write-Host "Suite completa omitida por parámetro." -ForegroundColor Yellow
}

Write-Step "Ejecutando quality gate sobre SGD-114"

$GateOutput = Join-Path $ArtifactsDir "SGD-114-quality-gate.json"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "$ConfigPath" `
    --increment "SGD-114" `
    --status "technically_completed" `
    --output "$GateOutput"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate inicial de SGD-114 no fue aprobado."
}

Write-Step "Resultado"

Write-Host "SGD-114 implementado y validado correctamente." -ForegroundColor Green
Write-Host "Política: $DocPath" -ForegroundColor Green
Write-Host "Motor: $ModulePath" -ForegroundColor Green
Write-Host "Pruebas: $TestPath" -ForegroundColor Green
Write-Host "Evidencia: $GateOutput" -ForegroundColor Green
Write-Host "Pruebas nuevas esperadas: 4." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 59: 63 pruebas." -ForegroundColor Cyan
