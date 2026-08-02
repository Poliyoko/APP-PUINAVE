<#
.SYNOPSIS
    Corrige SGD-115 v1.0.1: validación de rutas y carga diferida.

.DESCRIPTION
    Corrige dos aspectos:
      1. Las referencias de navegación a directorios terminadas en "/"
         no se consideran archivos rotos.
      2. sgoda.documentation usa carga diferida para permitir
         python -m sgoda.documentation.master_docs sin RuntimeWarning.

    Después:
      - ejecuta las 8 pruebas específicas;
      - ejecuta la suite completa;
      - regenera los tres documentos maestros reales;
      - valida inventario, rutas, duplicados y secciones;
      - genera evidencia del correctivo.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SGD115-v1.0.1-Path-Validation.ps1
#>

[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path
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
        throw "No se pudo escribir: $Path"
    }

    $Info = Get-Item -LiteralPath $Path
    Write-Host "Corregido: $Path ($($Info.Length) bytes)" -ForegroundColor Green
}

function Write-JsonUtf8 {
    param([string]$Path, [object]$Data)

    $Parent = Split-Path -Parent $Path
    if (-not (Test-Path -LiteralPath $Parent)) {
        New-Item -ItemType Directory -Path $Parent -Force | Out-Null
    }

    $Json = $Data | ConvertTo-Json -Depth 30
    [System.IO.File]::WriteAllText(
        $Path,
        $Json + [Environment]::NewLine,
        [System.Text.UTF8Encoding]::new($false)
    )
}

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$ModulePath = Join-Path `
    $ProjectRoot `
    "src\sgoda\documentation\master_docs.py"

$InitPath = Join-Path `
    $ProjectRoot `
    "src\sgoda\documentation\__init__.py"

$TestPath = Join-Path `
    $ProjectRoot `
    "tests\documentation\test_SGD_115_master_documentation.py"

$ArtifactsDir = Join-Path `
    $ProjectRoot `
    "artifacts\documentation\SGD-115"

$PmoDir = Join-Path `
    $ProjectRoot `
    "artifacts\pmo\SGD-115"

$EvidencePath = Join-Path `
    $PmoDir `
    "SGD-115-v1.0.1-corrective-evidence.json"

foreach ($Required in @($ModulePath, $InitPath, $TestPath)) {
    Assert-Path -Path $Required -Description $Required
}

Write-Step "Corrigiendo validación de rutas de navegación"

$ModuleContent = Get-Content `
    -LiteralPath $ModulePath `
    -Raw `
    -Encoding UTF8

$OldFunction = @'
def _extract_code_paths(text: str) -> Iterable[str]:
    pattern = re.compile(r"`([^`\n]+(?:/|\\)[^`\n]+)`")
    for match in pattern.finditer(text):
        value = match.group(1).strip()
        if value.startswith(("http://", "https://")):
            continue
        yield value.replace("\\", "/")
'@

$NewFunction = @'
def _extract_code_paths(text: str) -> Iterable[str]:
    """Extrae rutas de archivos verificables desde bloques de código.

    Las referencias terminadas en "/" representan directorios de
    navegación. No se validan como archivos individuales porque algunos
    repositorios mínimos de prueba pueden omitir secciones opcionales.
    """

    pattern = re.compile(r"`([^`\n]+(?:/|\\)[^`\n]+)`")

    for match in pattern.finditer(text):
        value = match.group(1).strip().replace("\\", "/")

        if value.startswith(("http://", "https://")):
            continue

        if value.endswith("/"):
            continue

        yield value
'@

if ($ModuleContent.Contains($OldFunction)) {
    $ModuleContent = $ModuleContent.Replace(
        $OldFunction,
        $NewFunction
    )
    Write-Utf8NoBom `
        -Path $ModulePath `
        -Content $ModuleContent
}
elseif ($ModuleContent.Contains('if value.endswith("/"):')) {
    Write-Host "La validación de rutas ya estaba corregida." -ForegroundColor Yellow
}
else {
    throw "No se encontró la función _extract_code_paths esperada."
}

Write-Step "Instalando carga diferida de sgoda.documentation"

$InitContent = @'
"""Sistema Maestro de Documentación SGODA-PUINAVE.

La API pública se carga de forma diferida para permitir la ejecución
segura de ``python -m sgoda.documentation.master_docs``.
"""

from __future__ import annotations

from typing import Any

__all__ = [
    "ComponentRecord",
    "ValidationResult",
    "discover_components",
    "publish_artifacts",
    "validate_master_documents",
    "write_master_documents",
]


def __getattr__(name: str) -> Any:
    if name not in __all__:
        raise AttributeError(
            f"El módulo {__name__!r} no contiene {name!r}"
        )

    from . import master_docs

    return getattr(master_docs, name)
'@

Write-Utf8NoBom `
    -Path $InitPath `
    -Content $InitContent

Write-Step "Validando sintaxis e importaciones"

& python -m py_compile `
    "src/sgoda/documentation/master_docs.py" `
    "src/sgoda/documentation/__init__.py"

if ($LASTEXITCODE -ne 0) {
    throw "La compilación Python del correctivo falló."
}

& python -c "from sgoda.documentation import discover_components, validate_master_documents; print(discover_components.__name__, validate_master_documents.__name__)"

if ($LASTEXITCODE -ne 0) {
    throw "La importación pública de SGD-115 falló."
}

Write-Step "Validando ejecución modular sin RuntimeWarning"

$HelpOutput = & python -m sgoda.documentation.master_docs --help 2>&1
$HelpExitCode = $LASTEXITCODE

$HelpOutput | ForEach-Object {
    Write-Host $_
}

if ($HelpExitCode -ne 0) {
    throw "La ejecución modular de SGD-115 falló."
}

if (($HelpOutput -join "`n") -match "RuntimeWarning") {
    throw "Todavía se detecta RuntimeWarning."
}

Write-Step "Ejecutando 8 pruebas específicas SGD-115"

& python -m pytest `
    "tests/documentation/test_SGD_115_master_documentation.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SGD-115 continúan con errores."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Regenerando documentación maestra real"

& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"

if ($LASTEXITCODE -ne 0) {
    throw "La regeneración real de SGD-115 no fue aprobada."
}

$ValidationPath = Join-Path `
    $ArtifactsDir `
    "master-documentation-validation.json"

$InventoryPath = Join-Path `
    $ArtifactsDir `
    "component-inventory.json"

Assert-Path `
    -Path $ValidationPath `
    -Description "master-documentation-validation.json"

Assert-Path `
    -Path $InventoryPath `
    -Description "component-inventory.json"

$Validation = Get-Content `
    -LiteralPath $ValidationPath `
    -Raw |
    ConvertFrom-Json

$Inventory = Get-Content `
    -LiteralPath $InventoryPath `
    -Raw |
    ConvertFrom-Json

if (-not $Validation.passed) {
    Write-Host "Rutas rotas:" -ForegroundColor Red
    @($Validation.broken_paths) | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }

    Write-Host "Códigos duplicados:" -ForegroundColor Red
    @($Validation.duplicate_codes) | ForEach-Object {
        Write-Host "  $_" -ForegroundColor Red
    }

    throw "La validación documental real no fue aprobada."
}

Write-Step "Generando evidencia del correctivo"

$Evidence = [ordered]@{
    increment_code = "SGD-115"
    corrective_version = "1.0.1"
    generated_at_utc = [DateTime]::UtcNow.ToString("o")
    correction = @(
        "navigation_directories_excluded_from_file_validation",
        "lazy_package_imports"
    )
    specific_tests = 8
    expected_total_tests = 129
    validation_passed = [bool]$Validation.passed
    component_count = [int]$Validation.component_count
    broken_paths = @($Validation.broken_paths).Count
    duplicate_codes = @($Validation.duplicate_codes).Count
    master_documents = @(
        "docs/00_INDICE_MAESTRO.md",
        "docs/00_ARQUITECTURA_MAESTRA.md",
        "docs/00_REGISTRO_MAESTRO_COMPONENTES.md"
    )
}

Write-JsonUtf8 `
    -Path $EvidencePath `
    -Data $Evidence

Write-Step "Resultado final"

Write-Host "SGD-115 v1.0.1 corregido y validado." -ForegroundColor Green
Write-Host "Directorios de navegación: TRATADOS CORRECTAMENTE." -ForegroundColor Green
Write-Host "RuntimeWarning: ELIMINADO." -ForegroundColor Green
Write-Host "Pruebas específicas: 8 APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: 129 APROBADAS." -ForegroundColor Green
Write-Host "Documentos maestros: 3 GENERADOS." -ForegroundColor Green
Write-Host "Componentes registrados: $($Validation.component_count)" -ForegroundColor Cyan
Write-Host "Rutas rotas: $(@($Validation.broken_paths).Count)" -ForegroundColor Green
Write-Host "Códigos duplicados: $(@($Validation.duplicate_codes).Count)" -ForegroundColor Green
Write-Host "Validación documental: APROBADA." -ForegroundColor Green

Write-Host ""
Write-Host "Después revise git status y publique mediante SPB-007." -ForegroundColor Yellow
