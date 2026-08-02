[CmdletBinding()]
param(
    [ValidateSet("diagnostic", "approved-models")]
    [string]$Command = "diagnostic",

    [ValidateSet("", "translation", "tts")]
    [string]$Purpose = "",

    [ValidateSet("", "es-CO", "en-US", "it-IT")]
    [string]$Locale = ""
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$Root = Split-Path -Parent $PSScriptRoot
Set-Location -LiteralPath $Root
$env:PYTHONPATH = Join-Path $Root "src"

if ($Command -eq "diagnostic") {
    & python -m sgoda.language_engine.cli diagnostic
}
else {
    $Arguments = @(
        "-m",
        "sgoda.language_engine.cli",
        "approved-models"
    )

    if ($Purpose) {
        $Arguments += @("--purpose", $Purpose)
    }

    if ($Locale) {
        $Arguments += @("--locale", $Locale)
    }

    & python @Arguments
}

if ($LASTEXITCODE -ne 0) {
    throw "SPT-006A terminó con errores."
}