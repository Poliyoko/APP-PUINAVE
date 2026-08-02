[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Code,
    [Parameter(Mandatory = $true)]
    [string]$Name,
    [string]$ComponentType = "technology_increment",
    [string]$Version = "0.1.0",
    [string]$Description = "",
    [string]$Output = "generated/installers",
    [switch]$Preview,
    [switch]$Force
)
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"
$Arguments = @(
    "-m", "sgoda.installer_builder.cli", "new",
    "--code", $Code,
    "--name", $Name,
    "--type", $ComponentType,
    "--version", $Version,
    "--description", $Description,
    "--output", $Output
)
if ($Preview) { $Arguments += "--preview" }
if ($Force) { $Arguments += "--force" }
& python @Arguments
if ($LASTEXITCODE -ne 0) { throw "SIB-001 terminÃ³ con errores." }