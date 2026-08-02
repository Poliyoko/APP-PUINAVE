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
        throw "No se encontró ningún Excel en la raíz."
    }

    $ExcelPath = $Excel.FullName
}
elseif (-not [System.IO.Path]::IsPathRooted($ExcelPath)) {
    $ExcelPath = [System.IO.Path]::GetFullPath(
        (Join-Path $Root $ExcelPath)
    )
}

python -m sgoda.rlb.header_normalizer `
    --excel "$ExcelPath" `
    --schema "config/rlb/schema-v1.json" `
    --output "artifacts/rlb/SPT-001B-P07"

if ($LASTEXITCODE -ne 0) {
    throw "SPT-001B-P07 terminó con errores."
}