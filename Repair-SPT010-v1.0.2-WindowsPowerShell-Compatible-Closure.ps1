<#
.SYNOPSIS
    Corrige y cierra institucionalmente SPT-010 v1.0.2.

.DESCRIPTION
    Correctivo único para el error JSONDecodeError producido durante la
    demostración integrada de SPT-010.

    El script:
      - valida que se ejecute desde la raíz del repositorio;
      - crea respaldo de los archivos afectados;
      - reemplaza src/sgoda/platform/cli.py por una versión corregida;
      - agrega pruebas específicas de compatibilidad del payload;
      - crea payload JSON en archivo, evitando problemas de comillas;
      - compila el código;
      - ejecuta pruebas específicas;
      - ejecuta la suite completa;
      - ejecuta la demostración integrada;
      - regenera SGD-116;
      - evalúa SPT-010 mediante SGD-114C;
      - regenera SGD-115;
      - genera evidencia del correctivo;
      - actualiza el release SPT-010;
      - conserva el documento técnico dentro del repositorio.

.PARAMETER ProjectRoot
    Raíz del repositorio. Por defecto, la carpeta actual.

.PARAMETER SkipFullSuite
    Omite la suite completa. No recomendado para cierre institucional.

.PARAMETER SkipInstitutionalClosure
    Omite SGD-116, SGD-114C, SGD-115 y release. Solo para diagnóstico.
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite,
    [switch]$SkipInstitutionalClosure
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Write-Step {
    param([Parameter(Mandatory)][string]$Message)

    Write-Host ""
    Write-Host "==> $Message" -ForegroundColor Cyan
}

function Require-File {
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "No se encontró el archivo requerido: $Path"
    }
}

function Write-Utf8 {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Content
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    [System.IO.File]::WriteAllText(
        $Path,
        $Content,
        [System.Text.UTF8Encoding]::new($false)
    )

    $Info = Get-Item -LiteralPath $Path

    if ($Info.Length -le 0) {
        throw "El archivo quedó vacío: $Path"
    }

    Write-Host "Creado/actualizado: $Path ($($Info.Length) bytes)" `
        -ForegroundColor Green
}

function Write-Json {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][object]$Value
    )

    $Parent = Split-Path -Parent $Path

    if ($Parent) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Value | ConvertTo-Json -Depth 100

    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory)][string]$Description,
        [Parameter(Mandatory)][scriptblock]$Action
    )

    Write-Step $Description

    $global:LASTEXITCODE = 0
    & $Action

    if ($LASTEXITCODE -ne 0) {
        throw "$Description terminó con errores. Código: $LASTEXITCODE"
    }
}

function Copy-Backup {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$BackupDirectory
    )

    if (Test-Path -LiteralPath $Source -PathType Leaf) {
        $RelativeName = $Source.Replace($ProjectRoot, "")
        $RelativeName = $RelativeName.TrimStart(
            [char[]]@([char]92, [char]47)
        )
        $RelativeName = $RelativeName.Replace(
            [string][char]92,
            "__"
        )
        $RelativeName = $RelativeName.Replace("/", "__")

        Copy-Item `
            -LiteralPath $Source `
            -Destination (Join-Path $BackupDirectory $RelativeName) `
            -Force
    }
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$CliPath = Join-Path $ProjectRoot "src\sgoda\platform\cli.py"
$TestPath = Join-Path `
    $ProjectRoot `
    "tests\platform\test_SPT_010_payload_compatibility.py"

$DocumentPath = Join-Path `
    $ProjectRoot `
    "docs\06_Fase_Tecnologica_II\SPT-010\SPT-010-Solucion-Errores-Demostracion-Integrada.md"

$DemoGraphPath = Join-Path `
    $ProjectRoot `
    "artifacts\platform\SPT-010\demo-platform-graph.json"

$DemoPayloadPath = Join-Path `
    $ProjectRoot `
    "artifacts\platform\SPT-010\demo-platform-payload.json"

$DemoResultPath = Join-Path `
    $ProjectRoot `
    "artifacts\platform\SPT-010\demo-platform-result-v1.0.1.json"

$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-010"
$ReleaseDir = Join-Path $ProjectRoot "releases\SPT-010-v1.0.1"

$GateJson = Join-Path $PmoDir "SPT-010-v1.0.1-policy-result.json"
$GateMd = Join-Path $PmoDir "SPT-010-v1.0.1-policy-result.md"
$EvidencePath = Join-Path `
    $PmoDir `
    "SPT-010-v1.0.1-correction-evidence.json"

$BackupDir = Join-Path `
    $PmoDir `
    ("backups\pre-SPT010-v1.0.1-" + (Get-Date -Format "yyyyMMdd-HHmmss"))

Write-Step "Validando línea base"

foreach ($Required in @(
    (Join-Path $ProjectRoot "pytest.ini"),
    $CliPath,
    (Join-Path $ProjectRoot "src\sgoda\platform\runtime.py"),
    (Join-Path $ProjectRoot "src\sgoda\platform\facade.py"),
    (Join-Path $ProjectRoot "src\sgoda\platform\models.py"),
    (Join-Path $ProjectRoot "src\sgoda\governance\policy_cli.py"),
    (Join-Path $ProjectRoot "config\governance\SGD-114C-policy.json"),
    (Join-Path $ProjectRoot "src\sgoda\documentation\master_docs.py"),
    (Join-Path $ProjectRoot "src\sgoda\roadmap\cli.py")
)) {
    Require-File -Path $Required
}

if (-not (Test-Path -LiteralPath $DocumentPath -PathType Leaf)) {
    Write-Warning (
        "El documento técnico todavía no está en el repositorio: " +
        $DocumentPath
    )
}

Write-Step "Creando respaldo institucional"

New-Item -ItemType Directory -Path $BackupDir -Force | Out-Null

foreach ($Affected in @(
    $CliPath,
    $TestPath,
    $DemoPayloadPath,
    $DemoResultPath,
    $EvidencePath,
    $GateJson,
    $GateMd
)) {
    Copy-Backup `
        -Source $Affected `
        -BackupDirectory $BackupDir
}

$CorrectedCli = @'
"""CLI robusta de SPT-010.

Compatible con Windows PowerShell, PowerShell 7, Linux y CI/CD.
"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from .health import repository_health
from .models import PlatformRequest
from .runtime import build_runtime


def _load_payload(
    raw_payload: str,
    payload_file: str | None = None,
) -> dict[str, Any]:
    """Carga un payload JSON desde texto o archivo.

    Se prefiere payload_file porque evita alteraciones de comillas
    producidas por el shell. La reparación de comillas se conserva
    únicamente como compatibilidad defensiva.
    """

    if payload_file:
        payload_path = Path(payload_file)

        if not payload_path.is_file():
            raise ValueError(
                f"No se encontró el archivo de payload: {payload_path}"
            )

        raw_payload = payload_path.read_text(
            encoding="utf-8-sig"
        )

    raw_payload = str(raw_payload or "{}").strip()

    candidates = (
        raw_payload,
        raw_payload.replace('\\"', '"'),
        raw_payload.replace("'", '"'),
        raw_payload.replace('\\"', '"').replace("'", '"'),
    )

    last_error: json.JSONDecodeError | None = None

    for candidate in dict.fromkeys(candidates):
        try:
            payload = json.loads(candidate)

        except json.JSONDecodeError as error:
            last_error = error
            continue

        if not isinstance(payload, dict):
            raise ValueError(
                "El payload debe ser un objeto JSON."
            )

        return payload

    raise ValueError(
        "El payload no contiene JSON válido."
    ) from last_error


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--graph", required=True)
    parser.add_argument("--operation", required=True)
    parser.add_argument("--payload", default="{}")
    parser.add_argument("--payload-file")
    parser.add_argument("--session", default="anonymous")
    parser.add_argument("--language", default="es")
    parser.add_argument("--node")
    parser.add_argument("--output")
    parser.add_argument("--root", default=".")
    args = parser.parse_args()

    payload = _load_payload(
        args.payload,
        args.payload_file,
    )
    runtime = build_runtime(args.graph)

    response = runtime.execute(
        PlatformRequest(
            operation=args.operation,
            payload=payload,
            session_id=args.session,
            language=args.language,
            context_node_id=args.node,
        )
    )

    result = {
        "operation": response.operation,
        "status": response.status,
        "data": response.data,
        "sources": list(response.sources),
        "warnings": list(response.warnings),
        "no_invention": response.no_invention,
        "health": repository_health(args.root),
    }

    serialized = json.dumps(
        result,
        indent=2,
        ensure_ascii=False,
    )

    if args.output:
        target = Path(args.output)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(
            serialized + "\n",
            encoding="utf-8",
        )
    else:
        print(serialized)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
'@

$CompatibilityTests = @'
"""Pruebas del correctivo SPT-010 v1.0.2."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from sgoda.platform.cli import _load_payload


def test_SPT_010_loads_standard_json_payload() -> None:
    assert _load_payload(
        '{"message":"Quiero aprender"}'
    ) == {
        "message": "Quiero aprender",
    }


def test_SPT_010_repairs_single_quoted_payload() -> None:
    assert _load_payload(
        "{'message':'Quiero aprender'}"
    ) == {
        "message": "Quiero aprender",
    }


def test_SPT_010_repairs_escaped_quotes() -> None:
    assert _load_payload(
        '{\\"message\\":\\"AMDA\\"}'
    ) == {
        "message": "AMDA",
    }


def test_SPT_010_loads_payload_file(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload.json"
    path.write_text(
        '{"message":"AMDA"}',
        encoding="utf-8",
    )

    assert _load_payload(
        "{}",
        str(path),
    ) == {
        "message": "AMDA",
    }


def test_SPT_010_reads_utf8_bom_payload_file(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload-bom.json"
    path.write_text(
        '{"message":"Puinave"}',
        encoding="utf-8-sig",
    )

    assert _load_payload(
        "{}",
        str(path),
    ) == {
        "message": "Puinave",
    }


def test_SPT_010_payload_file_has_priority(
    tmp_path: Path,
) -> None:
    path = tmp_path / "payload.json"
    path.write_text(
        '{"message":"Archivo"}',
        encoding="utf-8",
    )

    assert _load_payload(
        '{"message":"Texto"}',
        str(path),
    ) == {
        "message": "Archivo",
    }


def test_SPT_010_rejects_non_object_payload() -> None:
    with pytest.raises(
        ValueError,
        match="objeto JSON",
    ):
        _load_payload("[1, 2, 3]")


def test_SPT_010_rejects_invalid_payload() -> None:
    with pytest.raises(
        ValueError,
        match="JSON válido",
    ):
        _load_payload("{invalid}")


def test_SPT_010_rejects_missing_payload_file(
    tmp_path: Path,
) -> None:
    with pytest.raises(
        ValueError,
        match="No se encontró",
    ):
        _load_payload(
            "{}",
            str(tmp_path / "missing.json"),
        )


def test_SPT_010_empty_payload_defaults_to_object() -> None:
    assert _load_payload("") == {}


def test_SPT_010_payload_is_deterministic() -> None:
    raw = '{"message":"AMDA","language":"pu"}'

    assert _load_payload(raw) == _load_payload(raw)


def test_SPT_010_payload_preserves_unicode() -> None:
    payload = {
        "message": "Quiero aprender Puinave",
        "language": "pu",
    }
    raw = json.dumps(
        payload,
        ensure_ascii=False,
    )

    assert _load_payload(raw) == payload
'@

Write-Step "Aplicando corrección completa"

Write-Utf8 `
    -Path $CliPath `
    -Content $CorrectedCli

Write-Utf8 `
    -Path $TestPath `
    -Content $CompatibilityTests

Write-Json `
    -Path $DemoPayloadPath `
    -Value ([ordered]@{
        message = "Quiero aprender esta palabra"
    })

Invoke-Checked "Validando sintaxis Python" {
    python -m py_compile `
        "src/sgoda/platform/cli.py" `
        "tests/platform/test_SPT_010_payload_compatibility.py"
}

Invoke-Checked "Ejecutando 12 pruebas del correctivo" {
    python -m pytest `
        "tests/platform/test_SPT_010_payload_compatibility.py" `
        -q
}

Invoke-Checked "Ejecutando pruebas completas de SPT-010" {
    python -m pytest `
        "tests/platform/test_SPT_010_integrated_digital_platform.py" `
        "tests/platform/test_SPT_010_payload_compatibility.py" `
        -q
}

if (-not $SkipFullSuite) {
    Invoke-Checked "Ejecutando suite completa del repositorio" {
        python -m pytest
    }
}

Write-Step "Ejecutando demostración integrada corregida"

Require-File -Path $DemoGraphPath

Invoke-Checked "Consultando la Plataforma Digital Integrada" {
    python -m sgoda.platform.cli `
        --graph "$DemoGraphPath" `
        --operation "conversation" `
        --payload "{}" `
        --payload-file "$DemoPayloadPath" `
        --session "DEMO-SPT010-v1.0.1" `
        --language "es" `
        --node "LEX-001" `
        --output "$DemoResultPath" `
        --root "$ProjectRoot"
}

$Demo = Get-Content `
    -LiteralPath $DemoResultPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if ($Demo.operation -ne "conversation") {
    throw "La demostración devolvió una operación inesperada."
}

if ($Demo.status -ne "ok") {
    throw "La demostración integrada no fue aprobada. Estado: $($Demo.status)"
}

if (-not [bool]$Demo.no_invention) {
    throw "La demostración no respetó no_invention=true."
}

if ($Demo.data.intent -ne "tutor") {
    throw "La demostración no fue enrutada al Tutor Inteligente."
}

if (-not $SkipInstitutionalClosure) {
    Write-Step "Regenerando Roadmap Maestro SGD-116"

    Invoke-Checked "Actualizando SGD-116" {
        python -m sgoda.roadmap.cli `
            --root "$ProjectRoot" `
            --output "artifacts/roadmap/SGD-116"
    }

    $RoadmapValidationPath = Join-Path `
        $ProjectRoot `
        "artifacts\roadmap\SGD-116\validation.json"

    Require-File -Path $RoadmapValidationPath

    $RoadmapValidation = Get-Content `
        -LiteralPath $RoadmapValidationPath `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if (-not [bool]$RoadmapValidation.passed) {
        throw "SGD-116 no aprobó el correctivo SPT-010 v1.0.2."
    }

    Write-Step "Evaluando SPT-010 mediante SGD-114C"

    New-Item -ItemType Directory -Path $PmoDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ReleaseDir -Force | Out-Null

    & python -m sgoda.governance.policy_cli `
        --root "$ProjectRoot" `
        --policy "config/governance/SGD-114C-policy.json" `
        --increment "SPT-010" `
        --output-json "$GateJson" `
        --output-md "$GateMd"

    $GateExitCode = $LASTEXITCODE

    Require-File -Path $GateJson
    Require-File -Path $GateMd

    $Gate = Get-Content `
        -LiteralPath $GateJson `
        -Raw `
        -Encoding UTF8 |
        ConvertFrom-Json

    if ($GateExitCode -ne 0 -or -not [bool]$Gate.approved) {
        @($Gate.results) |
            Where-Object { $_.blocking } |
            Format-Table rule, name, message, remediation -AutoSize

        throw "SGD-114C no aprobó SPT-010 v1.0.1."
    }

    Write-Step "Regenerando Documentación Maestra SGD-115"

    Invoke-Checked "Actualizando SGD-115" {
        python -m sgoda.documentation.master_docs `
            --root "$ProjectRoot" `
            --output "artifacts/documentation/SGD-115"
    }

    Write-Step "Generando evidencia y release"

    Write-Json `
        -Path $EvidencePath `
        -Value ([ordered]@{
            increment_code = "SPT-010"
            correction_version = "1.0.1"
            correction_code = "SPT-010-COR-JSON-PAYLOAD"
            status = "corrected_and_validated"
            generated_at_utc = [DateTime]::UtcNow.ToString("o")
            root_cause = "JSON payload altered by PowerShell argument transport"
            corrected_file = "src/sgoda/platform/cli.py"
            compatibility_test_file = (
                "tests/platform/" +
                "test_SPT_010_payload_compatibility.py"
            )
            payload_file = (
                "artifacts/platform/SPT-010/" +
                "demo-platform-payload.json"
            )
            demo_result = (
                "artifacts/platform/SPT-010/" +
                "demo-platform-result-v1.0.1.json"
            )
            correction_tests = 12
            full_suite_executed = (-not $SkipFullSuite)
            demo_status = $Demo.status
            demo_intent = $Demo.data.intent
            no_invention = [bool]$Demo.no_invention
            roadmap_approved = [bool]$RoadmapValidation.passed
            policy_approved = [bool]$Gate.approved
            policy_exit_code = $Gate.exit_code
            documentation_in_repository = (
                Test-Path -LiteralPath $DocumentPath
            )
            backup = $BackupDir
        })

    foreach ($ReleaseFile in @(
        $CliPath,
        $TestPath,
        $DocumentPath,
        $DemoPayloadPath,
        $DemoResultPath,
        $EvidencePath,
        $GateJson,
        $GateMd
    )) {
        if (Test-Path -LiteralPath $ReleaseFile -PathType Leaf) {
            Copy-Item `
                -LiteralPath $ReleaseFile `
                -Destination (
                    Join-Path $ReleaseDir (Split-Path $ReleaseFile -Leaf)
                ) `
                -Force
        }
    }
}

Write-Step "Resultado final"

Write-Host "SPT-010 v1.0.2 corregido." -ForegroundColor Green
Write-Host "JSON payload: CORREGIDO." -ForegroundColor Green
Write-Host "Compatibilidad PowerShell: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Carga mediante --payload-file: IMPLEMENTADA." -ForegroundColor Green
Write-Host "Pruebas del correctivo: 12 APROBADAS." -ForegroundColor Green
Write-Host "Pruebas completas SPT-010: APROBADAS." -ForegroundColor Green

if (-not $SkipFullSuite) {
    Write-Host "Suite completa: APROBADA." -ForegroundColor Green
}

Write-Host "Demostración integrada: APROBADA." -ForegroundColor Green
Write-Host "Intención conversacional: TUTOR." -ForegroundColor Green
Write-Host "No invención Puinave: APROBADA." -ForegroundColor Green

if (-not $SkipInstitutionalClosure) {
    Write-Host "SGD-116: APROBADO." -ForegroundColor Green
    Write-Host "SGD-114C: APROBADO." -ForegroundColor Green
    Write-Host "SGD-115: ACTUALIZADO." -ForegroundColor Green
    Write-Host "Release: releases\SPT-010-v1.0.1" -ForegroundColor Cyan
    Write-Host "Evidencia: $EvidencePath" -ForegroundColor Cyan
}

Write-Host "Respaldo: $BackupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "Revise git status y publique mediante SPB-007." `
    -ForegroundColor Yellow
