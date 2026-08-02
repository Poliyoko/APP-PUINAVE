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
    throw "SGD-116 terminó con errores."
}