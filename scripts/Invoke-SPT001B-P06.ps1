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