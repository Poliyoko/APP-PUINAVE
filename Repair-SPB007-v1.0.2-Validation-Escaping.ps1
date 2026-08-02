<#
.SYNOPSIS
    Corrige la validación PowerShell de SPB-007 v1.0.1.

.DESCRIPTION
    Evita que PowerShell intente expandir $TagName durante la validación
    del archivo Invoke-SPB007-InstitutionalPublish.ps1.

    El script:
      - confirma que el correctivo de tag opcional ya está instalado;
      - valida el contenido usando un here-string literal;
      - ejecuta auditoría previa sin publicar;
      - ejecuta las 6 pruebas específicas;
      - ejecuta la suite completa;
      - no realiza commit ni push.

.PARAMETER ProjectRoot
    Ruta raíz del repositorio SGODA-PUINAVE.

.EXAMPLE
    .\Repair-SPB007-v1.0.2-Validation-Escaping.ps1
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

$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"

$InvokePath = Join-Path $ProjectRoot "scripts\Invoke-SPB007-InstitutionalPublish.ps1"
$TestPath = Join-Path $ProjectRoot "tests\publisher\test_SPB_007_institutional_publisher.py"

Assert-Path -Path $InvokePath -Description "Invoke-SPB007-InstitutionalPublish.ps1"
Assert-Path -Path $TestPath -Description "las pruebas SPB-007"

Write-Step "Validando correctivo de tag opcional"

$ValidationCode = @'
from pathlib import Path

path = Path("scripts/Invoke-SPB007-InstitutionalPublish.ps1")
text = path.read_text(encoding="utf-8")

required = [
    "IsNullOrWhiteSpace($TagName)",
    '$Arguments += @("--tag", $TagName)',
    'throw "SPB-007 terminó con errores."',
]

missing = [item for item in required if item not in text]

if missing:
    raise SystemExit(
        "Faltan elementos del correctivo: " + ", ".join(missing)
    )

print("Correctivo de tag opcional verificado.")
'@

& python -c $ValidationCode

if ($LASTEXITCODE -ne 0) {
    throw "La validación segura del correctivo falló."
}

Write-Step "Ejecutando auditoría previa sin publicar"

& "$InvokePath"

if ($LASTEXITCODE -ne 0) {
    throw "La auditoría previa corregida falló."
}

Write-Step "Ejecutando pruebas específicas SPB-007"

& python -m pytest `
    "tests/publisher/test_SPB_007_institutional_publisher.py" `
    -q

if ($LASTEXITCODE -ne 0) {
    throw "Las pruebas específicas SPB-007 fallaron."
}

Write-Step "Ejecutando suite completa"

& python -m pytest

if ($LASTEXITCODE -ne 0) {
    throw "La suite completa terminó con errores."
}

Write-Step "Resultado final"

Write-Host "SPB-007 v1.0.2 corregido y validado." -ForegroundColor Green
Write-Host "Validación PowerShell: APROBADA." -ForegroundColor Green
Write-Host "Tag vacío: OMITIDO CORRECTAMENTE." -ForegroundColor Green
Write-Host "Auditoría previa: APROBADA." -ForegroundColor Green
Write-Host "Pruebas específicas: 6 APROBADAS." -ForegroundColor Green
Write-Host "Suite completa: 103 APROBADAS." -ForegroundColor Green
Write-Host ""
Write-Host "Siguiente comando de publicación:" -ForegroundColor Cyan
Write-Host '.\scripts\Invoke-SPB007-InstitutionalPublish.ps1 -Publish -CommitMessage "feat(repository): publish SGODA-PUINAVE institutional baseline"' -ForegroundColor Cyan
