[CmdletBinding()]
param(
    [string]$Output = "artifacts/roadmap/SGD-116"
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.roadmap.cli `
    --root "." `
    --output $Output

if ($LASTEXITCODE -ne 0) {
    throw "SGD-116B terminó con errores."
}

$ValidationPath = Join-Path $Root "$Output\validation.json"
$Validation = Get-Content `
    -LiteralPath $ValidationPath `
    -Raw `
    -Encoding UTF8 |
    ConvertFrom-Json

if (-not $Validation.passed) {
    throw "La validación institucional SGD-116B no fue aprobada."
}

Write-Host "SGD-116B ejecutado correctamente." -ForegroundColor Green
Write-Host "Dependencias faltantes: $(@($Validation.missing_dependencies).Count)"
Write-Host "Alias resueltos: $(@($Validation.resolved_aliases).Count)"
Write-Host "Dependencias históricas: $(@($Validation.historical_dependencies).Count)"