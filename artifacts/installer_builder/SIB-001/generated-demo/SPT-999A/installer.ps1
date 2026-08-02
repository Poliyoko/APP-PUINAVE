<#
.SYNOPSIS
    Instalador institucional generado para SPT-999A.
#>
[CmdletBinding()]
param(
    [string]$ProjectRoot = (Get-Location).Path,
    [switch]$SkipFullSuite
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$ProjectRoot = [System.IO.Path]::GetFullPath($ProjectRoot)
Set-Location -LiteralPath $ProjectRoot
$env:PYTHONPATH = Join-Path $ProjectRoot "src"
if (-not (Test-Path -LiteralPath ".git")) {
    throw "Ejecute desde la raÃ­z del repositorio."
}
# TODO: implementar SPT-999A â€” Incremento Institucional Demostrativo.
& python -m py_compile "src/sgoda/<module>/module.py"
if ($LASTEXITCODE -ne 0) { throw "La sintaxis fallÃ³." }
& python -m pytest "tests/<module>/test_SPT_999A.py" -q
if ($LASTEXITCODE -ne 0) { throw "Las pruebas especÃ­ficas fallaron." }
if (-not $SkipFullSuite) {
    & python -m pytest
    if ($LASTEXITCODE -ne 0) { throw "La suite completa fallÃ³." }
}
& python -m sgoda.governance.evidence_policy `
    --root "$ProjectRoot" `
    --policy "config/governance/sgd-114-policy.json" `
    --increment "SPT-999A" `
    --status "technically_completed" `
    --output "artifacts/pmo/SPT-999A/SPT-999A-quality-gate.json"
if ($LASTEXITCODE -ne 0) { throw "El quality gate fallÃ³." }
& python -m sgoda.documentation.master_docs `
    --root "$ProjectRoot" `
    --output "artifacts/documentation/SGD-115"
if ($LASTEXITCODE -ne 0) { throw "SGD-115 fallÃ³." }
Write-Host "SPT-999A instalado y validado." -ForegroundColor Green
