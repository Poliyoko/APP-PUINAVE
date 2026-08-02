[CmdletBinding()]
param(
    [switch]$ValidateOnly
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

$Arguments = @(
    "-m",
    "sgoda.documentation.master_docs",
    "--root",
    $Root,
    "--output",
    "artifacts/documentation/SGD-115"
)

if ($ValidateOnly) {
    $Arguments += "--validate-only"
}

& python @Arguments

if ($LASTEXITCODE -ne 0) {
    throw "SGD-115 terminó con errores."
}