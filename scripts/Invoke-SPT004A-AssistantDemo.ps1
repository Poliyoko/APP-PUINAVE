[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Question
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

& python -m sgoda.assistant.cli $Question

if ($LASTEXITCODE -ne 0) {
    throw "SPT-004A terminó con errores."
}