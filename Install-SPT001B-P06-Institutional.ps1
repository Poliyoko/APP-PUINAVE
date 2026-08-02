<#
.SYNOPSIS
    Implementa SPT-001B-P06 como paquete institucional completo.

.DESCRIPTION
    Integra lector, exportador, pipeline, CLI, eventos PMO, pruebas,
    documentación, evidencias, trazabilidad y quality gate SGD-114.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.PARAMETER OfficialExcelPath
    Ruta opcional al Repositorio Léxico Base oficial. Si se omite,
    el instalador intenta localizar un .xlsx en la raíz.

.PARAMETER Force
    Sobrescribe archivos gestionados por P06.

.PARAMETER SkipFullSuite
    Omite la suite completa, pero no las pruebas específicas.

.PARAMETER SkipOfficialRun
    Instala y prueba P06 sin procesar el Excel oficial.

.EXAMPLE
    .\Install-SPT001B-P06-Institutional.ps1

.EXAMPLE
    .\Install-SPT001B-P06-Institutional.ps1 `
        -OfficialExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [string]$OfficialExcelPath = "",
    [switch]$Force,
    [switch]$SkipFullSuite,
    [switch]$SkipOfficialRun
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
    param([string]$Path, [object]$Data)

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
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot

$SrcRoot = Join-Path $ProjectRoot "src"
$RlbDir = Join-Path $SrcRoot "sgoda\rlb"
$TestsDir = Join-Path $ProjectRoot "tests\rlb"
$DocsDir = Join-Path $ProjectRoot "docs\05_Fase_Tecnologica\SPT-001"
$ScriptsDir = Join-Path $ProjectRoot "scripts"
$ArtifactsDir = Join-Path $ProjectRoot "artifacts\rlb\SPT-001B-P06"
$PmoDir = Join-Path $ProjectRoot "artifacts\pmo\SPT-001B-P06"
$DashboardDir = Join-Path $ProjectRoot "dashboard"

$EventsPath = Join-Path $RlbDir "events.py"
$PipelinePath = Join-Path $RlbDir "pipeline.py"
$CliPath = Join-Path $RlbDir "cli.py"
$InitPath = Join-Path $RlbDir "__init__.py"
$TestPath = Join-Path $TestsDir "test_pipeline_p06.py"
$DocPath = Join-Path $DocsDir "SPT-001B-P06-Pipeline-Institucional-RLB.md"
$InvokePath = Join-Path $ScriptsDir "Invoke-SPT001B-P06.ps1"
$TracePath = Join-Path $PmoDir "traceability-SPT-001B-P06.json"
$ManifestPath = Join-Path $PmoDir "implementation-evidence.json"
$DashboardPath = Join-Path $DashboardDir "SPT-001B-P06-dashboard.json"
$GatePath = Join-Path $PmoDir "SPT-001B-P06-quality-gate.json"

Write-Step "Validando línea base"

foreach ($Required in @(
    "schema.py",
    "models.py",
    "schema_loader.py",
    "profile_models.py",
    "excel_reader.py",
    "exporter.py"
)) {
    Assert-Path `
        -Path (Join-Path $RlbDir $Required) `
        -Description $Required
}

Assert-Path `
    -Path (Join-Path $ProjectRoot "config\rlb\schema-v1.json") `
    -Description "schema-v1.json"

Assert-Path `
    -Path (Join-Path $ProjectRoot "config\governance\sgd-114-policy.json") `
    -Description "SGD-114 v1.1"

Assert-Path `
    -Path (Join-Path $ProjectRoot "pytest.ini") `
    -Description "pytest.ini"

$env:PYTHONPATH = $SrcRoot

& python --version
if ($LASTEXITCODE -ne 0) {
    throw "Python no está disponible."
}

& python -c "import openpyxl; print('openpyxl', openpyxl.__version__)"
if ($LASTEXITCODE -ne 0) {
    throw "openpyxl no está disponible."
}

$EventsContent = @'
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
'@

$PipelineContent = @'
"""Pipeline institucional SPT-001B-P06."""

from __future__ import annotations

import hashlib
import json
from dataclasses import asdict, dataclass
from datetime import datetime, timezone
from pathlib import Path

from .events import (
    EventoRepositorioImportado,
    publicar_evento_jsonl,
)
from .excel_reader import LectorExcelRLB, ResultadoLecturaRLB
from .exporter import exportar_resultado
from .schema_loader import cargar_esquema


@dataclass(slots=True)
class ResultadoPipelineRLB:
    """Resultado integral y auditable del pipeline."""

    lectura: ResultadoLecturaRLB
    archivos_generados: dict[str, Path]
    evento: EventoRepositorioImportado
    historial_eventos: Path
    resumen_ejecucion: Path


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()

    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)

    return digest.hexdigest()


def _escribir_resumen(
    *,
    excel: Path,
    lectura: ResultadoLecturaRLB,
    archivos: dict[str, Path],
    evento: EventoRepositorioImportado,
    destino: Path,
) -> Path:
    if lectura.perfil is None:
        raise RuntimeError(
            "No existe perfil para generar el resumen."
        )

    contenido = {
        "sistema": "SGODA-PUINAVE",
        "incremento": "SPT-001B-P06",
        "generado_en_utc": datetime.now(timezone.utc).isoformat(),
        "archivo_origen": {
            "nombre": excel.name,
            "ruta": str(excel.resolve()),
            "sha256": _sha256(excel),
            "tamano_bytes": excel.stat().st_size,
        },
        "resultado": {
            "total_hojas": lectura.perfil.total_hojas,
            "total_registros": lectura.perfil.total_registros,
            "registros_validos": (
                lectura.perfil.total_registros_validos
            ),
            "registros_con_errores": (
                lectura.perfil.total_registros_con_errores
            ),
        },
        "artefactos": {
            name: {
                "ruta": str(path),
                "sha256": _sha256(path),
                "tamano_bytes": path.stat().st_size,
            }
            for name, path in archivos.items()
        },
        "evento": asdict(evento),
    }

    destino.parent.mkdir(parents=True, exist_ok=True)
    destino.write_text(
        json.dumps(
            contenido,
            ensure_ascii=False,
            indent=2,
        )
        + "\n",
        encoding="utf-8",
    )

    return destino


def ejecutar_pipeline(
    *,
    excel: str | Path,
    esquema: str | Path,
    salida: str | Path,
    historial_eventos: str | Path,
) -> ResultadoPipelineRLB:
    """Ejecuta lectura, perfilado, exportación, evento y resumen."""

    excel_path = Path(excel)

    if not excel_path.is_file():
        raise FileNotFoundError(
            f"No se encontró el Excel institucional: {excel_path}"
        )

    contrato = cargar_esquema(esquema)
    lectura = LectorExcelRLB(contrato).leer(excel_path)

    if lectura.perfil is None:
        raise RuntimeError(
            "La lectura no generó perfil institucional."
        )

    archivos = exportar_resultado(
        lectura,
        salida,
    )

    evento = EventoRepositorioImportado.crear(
        archivo=lectura.perfil.archivo,
        version_esquema=lectura.perfil.version_esquema,
        total_hojas=lectura.perfil.total_hojas,
        total_registros=lectura.perfil.total_registros,
        registros_validos=(
            lectura.perfil.total_registros_validos
        ),
        registros_con_errores=(
            lectura.perfil.total_registros_con_errores
        ),
        artefactos_generados=tuple(
            sorted(path.name for path in archivos.values())
        ),
    )

    historial = publicar_evento_jsonl(
        evento,
        historial_eventos,
    )

    resumen = _escribir_resumen(
        excel=excel_path,
        lectura=lectura,
        archivos=archivos,
        evento=evento,
        destino=Path(salida) / "resumen-ejecucion.json",
    )

    return ResultadoPipelineRLB(
        lectura=lectura,
        archivos_generados=archivos,
        evento=evento,
        historial_eventos=historial,
        resumen_ejecucion=resumen,
    )
'@

$CliContent = @'
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
'@

$InitContent = @'
"""Repositorio Léxico Base del ecosistema SGODA-PUINAVE.

Los módulos ejecutables se importan desde sus rutas concretas para
evitar cargas anticipadas al usar ``python -m``.
"""
'@

$TestContent = @'
"""Pruebas integrales SPT-001B-P06."""

import json
import subprocess
import sys
from pathlib import Path

from openpyxl import Workbook

from sgoda.rlb.pipeline import ejecutar_pipeline


def _crear_excel(tmp_path: Path) -> Path:
    path = tmp_path / "RLB-P06.xlsx"
    workbook = Workbook()
    sheet = workbook.active
    sheet.title = "Diccionario"
    sheet.append(
        ["ID", "Puinave", "Español", "Campo futuro"]
    )
    sheet.append(
        ["LEX-0001", "AMDA", "ejemplo", "conservar"]
    )
    sheet.append(
        ["LEX-0002", "", "sin palabra", None]
    )
    workbook.save(path)
    workbook.close()
    return path


def test_pipeline_genera_artefactos_evento_y_resumen(
    tmp_path: Path,
) -> None:
    result = ejecutar_pipeline(
        excel=_crear_excel(tmp_path),
        esquema="config/rlb/schema-v1.json",
        salida=tmp_path / "salida",
        historial_eventos=tmp_path / "eventos.jsonl",
    )

    assert result.evento.event_type == "RepositoryImported"
    assert result.evento.total_registros == 2
    assert result.evento.registros_validos == 1
    assert result.evento.registros_con_errores == 1

    assert result.historial_eventos.is_file()
    assert result.resumen_ejecucion.is_file()

    for path in result.archivos_generados.values():
        assert path.is_file()
        assert path.stat().st_size > 0

    summary = json.loads(
        result.resumen_ejecucion.read_text(encoding="utf-8")
    )

    assert summary["incremento"] == "SPT-001B-P06"
    assert len(summary["archivo_origen"]["sha256"]) == 64
    assert summary["resultado"]["total_registros"] == 2
    assert "canonico" in summary["artefactos"]


def test_cli_ejecuta_sin_advertencias(
    tmp_path: Path,
) -> None:
    excel = _crear_excel(tmp_path)
    output = tmp_path / "cli-output"
    events = tmp_path / "cli-events.jsonl"

    process = subprocess.run(
        [
            sys.executable,
            "-m",
            "sgoda.rlb.cli",
            "--excel",
            str(excel),
            "--schema",
            "config/rlb/schema-v1.json",
            "--output",
            str(output),
            "--events",
            str(events),
        ],
        capture_output=True,
        text=True,
        check=False,
    )

    assert process.returncode == 0
    assert "RuntimeWarning" not in process.stderr
    assert "SPT-001B-P06 ejecutado correctamente." in process.stdout
    assert (output / "palabras-canonicas.json").is_file()
    assert (output / "perfil-rlb.json").is_file()
    assert (output / "errores-importacion.json").is_file()
    assert (output / "resumen-ejecucion.json").is_file()
    assert events.is_file()


def test_pipeline_rechaza_excel_inexistente(
    tmp_path: Path,
) -> None:
    try:
        ejecutar_pipeline(
            excel=tmp_path / "inexistente.xlsx",
            esquema="config/rlb/schema-v1.json",
            salida=tmp_path / "salida",
            historial_eventos=tmp_path / "eventos.jsonl",
        )
    except FileNotFoundError as error:
        assert "Excel institucional" in str(error)
    else:
        raise AssertionError(
            "Debía rechazarse un Excel inexistente."
        )
'@

$DocContent = @'
# SPT-001B-P06 — Pipeline institucional del Repositorio Léxico Base

## Estado

Implementado como paquete institucional completo.

## Objetivo

Integrar el lector, el perfilador y el exportador del RLB en una única
operación reproducible, generando datos canónicos, evidencias, eventos,
resumen criptográfico y trazabilidad para el PMO Digital.

## Flujo funcional

1. Verificación del archivo Excel.
2. Carga del esquema RLB v1.0.0.
3. Lectura y detección de hojas y encabezados.
4. Mapeo y validación de registros.
5. Preservación de campos desconocidos.
6. Exportación de JSON canónico, perfil y errores.
7. Generación del evento `RepositoryImported`.
8. Generación del resumen con SHA-256.
9. Actualización de evidencia y dashboard.
10. Evaluación mediante SGD-114.

## Artefactos

- `palabras-canonicas.json`
- `perfil-rlb.json`
- `errores-importacion.json`
- `resumen-ejecucion.json`
- `repository-events.jsonl`
- `implementation-evidence.json`
- `traceability-SPT-001B-P06.json`
- `SPT-001B-P06-dashboard.json`

## CLI

```powershell
.\scripts\Invoke-SPT001B-P06.ps1 `
    -ExcelPath ".\Repositorio LExico Base (Excel)-1.xlsx"
```

## Criterios de aceptación

- Pruebas específicas aprobadas.
- Suite general sin regresiones.
- CLI sin advertencias.
- Artefactos JSON válidos.
- Evento PMO generado.
- Evidencia y trazabilidad presentes.
- Quality gate SGD-114 aprobado.
'@

$InvokeContent = @'
[CmdletBinding()]
param(
    [string]$ExcelPath = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ([string]::IsNullOrWhiteSpace($ExcelPath)) {
    $Excel = Get-ChildItem `
        -LiteralPath $Root `
        -File `
        -Filter "*.xlsx" |
        Where-Object { $_.Name -notlike "~`$*" } |
        Sort-Object Name |
        Select-Object -First 1

    if ($null -eq $Excel) {
        throw "No se encontró un archivo .xlsx en la raíz."
    }

    $ExcelPath = $Excel.FullName
}

if (-not (Test-Path -LiteralPath $ExcelPath)) {
    throw "No existe el Excel indicado: $ExcelPath"
}

python -m sgoda.rlb.cli `
    --excel "$ExcelPath" `
    --schema "config/rlb/schema-v1.json" `
    --output "artifacts/rlb/SPT-001B-P06" `
    --events "artifacts/pmo/SPT-001B-P06/repository-events.jsonl"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-001B-P06 terminó con errores."
}
'@

Write-Step "Instalando componentes funcionales"

Write-Utf8NoBom -Path $EventsPath -Content $EventsContent -Overwrite:$true
Write-Utf8NoBom -Path $PipelinePath -Content $PipelineContent -Overwrite:$true
Write-Utf8NoBom -Path $CliPath -Content $CliContent -Overwrite:$true
Write-Utf8NoBom -Path $InitPath -Content $InitContent -Overwrite:$true
Write-Utf8NoBom -Path $TestPath -Content $TestContent -Overwrite:$true
Write-Utf8NoBom -Path $DocPath -Content $DocContent -Overwrite:$true
Write-Utf8NoBom -Path $InvokePath -Content $InvokeContent -Overwrite:$true

Write-Step "Generando evidencias y trazabilidad"

$Timestamp = [DateTime]::UtcNow.ToString("o")

$Manifest = [ordered]@{
    increment_code = "SPT-001B-P06"
    status = "implemented"
    generated_at_utc = $Timestamp
    components = @(
        "src/sgoda/rlb/events.py",
        "src/sgoda/rlb/pipeline.py",
        "src/sgoda/rlb/cli.py",
        "tests/rlb/test_pipeline_p06.py",
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P06-Pipeline-Institucional-RLB.md",
        "scripts/Invoke-SPT001B-P06.ps1"
    )
}
Write-JsonUtf8 -Path $ManifestPath -Data $Manifest

$Trace = [ordered]@{
    increment_code = "SPT-001B-P06"
    generated_at_utc = $Timestamp
    source = @(
        "src/sgoda/rlb/events.py",
        "src/sgoda/rlb/pipeline.py",
        "src/sgoda/rlb/cli.py"
    )
    tests = @("tests/rlb/test_pipeline_p06.py")
    documentation = @(
        "docs/05_Fase_Tecnologica/SPT-001/SPT-001B-P06-Pipeline-Institucional-RLB.md"
    )
    evidence = @(
        "artifacts/pmo/SPT-001B-P06/implementation-evidence.json",
        "dashboard/SPT-001B-P06-dashboard.json"
    )
}
Write-JsonUtf8 -Path $TracePath -Data $Trace

$Dashboard = [ordered]@{
    increment_code = "SPT-001B-P06"
    status = "implemented"
    generated_at_utc = $Timestamp
    specific_tests = 3
    quality_gate = "pending"
    official_repository_processed = $false
}
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Validando importaciones"

& python -c "from sgoda.rlb.pipeline import ejecutar_pipeline; from sgoda.rlb.events import EventoRepositorioImportado; print(ejecutar_pipeline.__name__, EventoRepositorioImportado.__name__)"
if ($LASTEXITCODE -ne 0) {
    throw "Falló la importación de P06."
}

Write-Step "Ejecutando pruebas específicas"

& python -m pytest "tests/rlb/test_pipeline_p06.py" -q
if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas P06 fallaron."
}

if (-not $SkipFullSuite) {
    Write-Step "Ejecutando suite completa"

    & python -m pytest
    if ($LASTEXITCODE -ne 0) {
        throw "La suite completa terminó con errores."
    }
}

if (-not $SkipOfficialRun) {
    Write-Step "Localizando y procesando el Excel oficial"

    if ([string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
        $Candidate = Get-ChildItem `
            -LiteralPath $ProjectRoot `
            -File `
            -Filter "*.xlsx" |
            Where-Object { $_.Name -notlike "~`$*" } |
            Sort-Object Name |
            Select-Object -First 1

        if ($null -ne $Candidate) {
            $OfficialExcelPath = $Candidate.FullName
        }
    }

    if ([string]::IsNullOrWhiteSpace($OfficialExcelPath)) {
        Write-Host "No se encontró Excel oficial; se omite ejecución real." -ForegroundColor Yellow
    }
    else {
        $OfficialExcelPath = [System.IO.Path]::GetFullPath($OfficialExcelPath)
        Assert-Path -Path $OfficialExcelPath -Description "el Excel oficial"

        & python -m sgoda.rlb.cli `
            --excel "$OfficialExcelPath" `
            --schema "config/rlb/schema-v1.json" `
            --output "artifacts/rlb/SPT-001B-P06" `
            --events "artifacts/pmo/SPT-001B-P06/repository-events.jsonl"

        if ($LASTEXITCODE -ne 0) {
            throw "Falló el procesamiento del Excel oficial."
        }

        $Dashboard.official_repository_processed = $true
        $Dashboard.official_excel = $OfficialExcelPath
    }
}

Write-Step "Ejecutando quality gate SGD-114"

& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-001B-P06" `
    --status "technically_completed" `
    --output "$GatePath"

if ($LASTEXITCODE -ne 0) {
    throw "El quality gate SGD-114 de P06 no fue aprobado."
}

$Gate = Get-Content -LiteralPath $GatePath -Raw |
    ConvertFrom-Json

if (-not $Gate.passed) {
    throw "El quality gate no contiene passed=true."
}

$Dashboard.quality_gate = "approved"
Write-JsonUtf8 -Path $DashboardPath -Data $Dashboard

Write-Step "Resultado"

Write-Host "SPT-001B-P06 implementado y validado." -ForegroundColor Green
Write-Host "Pruebas específicas esperadas: 3 aprobadas." -ForegroundColor Cyan
Write-Host "Suite total esperada desde 65: 68 pruebas." -ForegroundColor Cyan
Write-Host "Quality gate SGD-114: APROBADO." -ForegroundColor Green
Write-Host "Documento: $DocPath" -ForegroundColor Green
Write-Host "Evidencia: $GatePath" -ForegroundColor Green
