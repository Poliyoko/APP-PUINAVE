[CmdletBinding()]
param(
    [ValidateRange(1, 1000)]
    [int]$Limit = 20
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.enrichment.cli --limit $Limit

if ($LASTEXITCODE -ne 0) {
    throw "SPT-006 terminó con errores."
}